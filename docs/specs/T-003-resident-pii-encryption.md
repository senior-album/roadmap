# T-003 Resident PII 컬럼 암호화 — 설계 스펙

**상태**: 설계 초안. 결정 대기 중.
**이슈**: roadmap#3
**위협**: I-02 — 개인정보보호법상 민감정보 평문 저장 (`medical_notes` 는 건강정보로 '민감정보' 카테고리, §23).
**선행 의존**: T-120 (Alembic) — 현재 DDL_AUTO 상태라 구조적 migration 수단이 없음. T-120 완료 후 진행 권장.

---

## 1. 대상 컬럼 식별

`app/models/models.py::Resident` 의 PII 후보:

| 컬럼           | 유형      | 분류           | 검색 필요성                             | 암호화 우선순위 |
|----------------|-----------|----------------|-----------------------------------------|-----------------|
| `name`         | 일반 PII  | 개인정보       | **O** (시설 내 검색, 보호자 매칭)       | 중 (blind index 필요)  |
| `birth_date`   | 일반 PII  | 개인정보       | X (표시만)                              | 중              |
| `gender`       | 일반 PII  | 개인정보       | X                                       | 저 (재식별 위험 낮음)  |
| `room_number`  | 준식별자  | 운영 정보      | △ (시설 내 열람)                        | 저 (단독으론 식별 불가)  |
| `medical_notes`| **민감정보** | 건강정보    | X                                       | **최상** (§23 대상)  |

**결정 #1**: 어디까지 암호화할 것인가?
- (A) `medical_notes` 만 — 최소 범위, 법적 의무 대응
- (B) `medical_notes` + `birth_date` + `name` — 일반 PII 포함 권장 범위
- (C) 모든 후보 — 과잉 방어, `name` 검색 깨짐 ✕
- **추천**: (B). `name` 은 blind index 로 동등 검색은 유지.

---

## 2. 암호화 방식 선택

### 옵션 2-A: PostgreSQL `pgcrypto` (Server-side)

```sql
-- 저장
INSERT INTO residents (name_enc) VALUES (pgp_sym_encrypt('홍길동', :key));
-- 조회
SELECT pgp_sym_decrypt(name_enc, :key) FROM residents;
```

- **+** DB 툴(psql, DBeaver) 에서도 복호화 가능 (키 알면)
- **+** 구현 단순, 라이브러리 추가 無
- **−** **키가 DB 서버에 노출** — DB dump, pg_stat_statements log, prepared statement 에 평문 키 흔적 남음
- **−** DB compromise = 키 + 암호문 동시 유출
- **−** CPU 부하가 DB 에 쏠림 (수천 row 조회 시 체감)

### 옵션 2-B: 애플리케이션 레벨 Envelope encryption (권장)

- **KEK** (Key Encryption Key): 고정, SealedSecret 에 저장. 회전은 드물게.
- **DEK** (Data Encryption Key): row 당 혹은 테이블 당 하나. KEK 로 암호화해서 DB 에 저장.
- 실 데이터 암/복호화는 DEK 로, AES-256-GCM 권장.

```python
# 저장 시
dek = random.bytes(32)
ciphertext, nonce, tag = aes_gcm_encrypt(dek, plaintext)
dek_wrapped = aes_gcm_encrypt(kek, dek)
# row 에 저장: ciphertext, nonce, tag, dek_wrapped
```

- **+** DB 서버 compromise 만으론 복호화 불가 (KEK 는 backend 메모리에만)
- **+** DB dump 유출 시 단독으론 무력
- **+** 나중에 KMS (AWS KMS, HashiCorp Vault) 로 KEK 만 위임 확장 용이
- **−** 라이브러리: `cryptography` (이미 requirements.txt 에 있음)
- **−** row 당 nonce/tag/wrapped_dek 컬럼 추가 — 스키마 복잡도 ↑
- **−** 검색 불가. equality 가 필요한 `name` 은 **blind index** 별도 컬럼 필요

**결정 #2**: 2-A vs 2-B?
- **추천**: **2-B**. 이유 — 공격 모델 상 "DB 만 털릴 확률" > "DB+backend 둘 다 털릴 확률". KEK-DEK 분리의 값이 여기서 나옴. pgcrypto 는 DB 만 털려도 끝.

---

## 3. Blind Index (name 동등 검색용)

암호문은 결정론적이지 않으므로 (AES-GCM 은 nonce 랜덤) `WHERE name_enc = '...'` 불가. 대체:

```python
blind = hmac_sha256(name_search_key, normalize(name))  # 동일 입력 = 동일 출력
# 별도 컬럼 name_bidx 에 저장, INDEX 생성
```

- **검색 가능**: `WHERE name_bidx = hmac(query)`
- **부분 일치 (LIKE) 는 여전히 불가** — n-gram blind index 로 확장 가능하나 과도.
- **key 분리 원칙**: `name_search_key` 는 KEK 와 **별도**. blind index 키가 유출돼도 암호문은 무사.

**결정 #3**: 부분 일치 검색 포기 OK?
- **추천**: **OK**. 실사용자 0 인 현재 단계에서 n-gram 도입은 과투자. 운영 중 필요해지면 나중에.

---

## 4. 마이그레이션 전략

### 4-A. 사전 조건 (블로커)

- **T-120 (Alembic) 완료 필수**. 현재 DDL_AUTO 로는 기존 컬럼 제거/추가를 안전하게 수행 불가. 이 스펙 실행 전 T-120 먼저 착수.

### 4-B. 마이그레이션 단계 (T-120 완료 후)

1. **스키마 변경 (Alembic migration)**:
   - 추가 컬럼: `name_enc`, `name_nonce`, `name_tag`, `name_dek_wrapped`, `name_bidx`
   - 같은 패턴으로 `birth_date`, `medical_notes`
   - 기존 `name`/`birth_date`/`medical_notes` 컬럼은 **유지** (단계적 전환)
2. **Dual-write 구간**:
   - application 코드가 쓸 때는 평문 + 암호문 둘 다 작성
   - 읽을 때는 암호문 우선, 없으면 평문 fallback
3. **Backfill**:
   - 배치 스크립트로 기존 row 암호화. 수가 적으니 단발성 스크립트 충분.
4. **암호문 단독 읽기로 전환**:
   - 코드에서 fallback 제거
5. **평문 컬럼 DROP** (Alembic migration):
   - pg_stat, WAL 에 남을 수 있어 `VACUUM FULL` 권장

### 4-C. 롤백 경로

- 단계 4 전까지는 평문 컬럼이 살아있으므로 언제든 되돌릴 수 있음
- 단계 5 이후 롤백은 backup 복원 필요

---

## 5. 키 관리

| 키                | 저장 위치                   | 회전 주기  | 회전 시 영향                                |
|-------------------|-----------------------------|------------|---------------------------------------------|
| KEK               | SealedSecret (backend-secret) | 12개월  | 모든 DEK 재래핑 (online 가능)               |
| DEK               | DB row (wrapped by KEK)     | 해당 없음 | row별 독립                                  |
| name_search_key   | SealedSecret (별도 키)      | 24개월+    | 회전 시 모든 blind index 재계산 필요        |

**결정 #4**: KEK 를 `backend-secret` 에 둘지, 별도 `pii-encryption-keys` SealedSecret 에 둘지?
- **추천**: **별도**. 권한 분리 (RBAC 으로 PII 접근 필요 서비스만 마운트). 현재 backend 단일 서비스지만 향후 analytics/export 등 분리 가능성.

---

## 6. 성능 영향

- 암호화 컬럼 3개, AES-GCM → row 당 ~5μs (무시 가능)
- Blind index 조회: 인덱스 룩업 O(log n), 평문 인덱스와 동등
- **우려 지점**: 리스트 API (예: `GET /residents?facility_id=...`) 에서 N row 복호화. 현재 시설당 resident 수 작으니 괜찮으나, 페이지네이션 + LIMIT 필수 (이미 있는지 확인 필요).

---

## 7. 예상 범위 (이슈 분할 제안)

현재 scope 이 크므로 실행 단계에서 세분화:

- roadmap#3 본체 → 설계 합의 (이 문서)
- 서브 이슈 a: Alembic 마이그레이션 스크립트 + 컬럼 추가
- 서브 이슈 b: 암호화 유틸 (KEK/DEK/GCM 래퍼) + 단위 테스트
- 서브 이슈 c: Resident CRUD 경로에 dual-write 적용
- 서브 이슈 d: Backfill 스크립트 + 실행
- 서브 이슈 e: 평문 컬럼 DROP

---

## 결정 요약 (user 에게 질문)

1. **범위**: (A)최소 / **(B)권장** / (C)전부 — `medical_notes` 외에 `name`, `birth_date` 까지 포함?
2. **방식**: pgcrypto(2-A) / **Envelope(2-B)** — backend 메모리에 KEK 두는 방식 OK?
3. **blind index**: 동등 검색만 지원으로 충분? (LIKE 는 포기)
4. **키 분리**: `backend-secret` 에 KEK 통합? / **별도 `pii-encryption-keys` SealedSecret**?
5. **T-120 (Alembic) 먼저 착수 후 이 스펙 진행** — 순서 OK?

결정 나면 이 문서를 최종화하고 서브 이슈 분할해서 구현 시작.
