# T-004 OpenSearch 얼굴 임베딩 인덱스 암호화 — 설계 스펙

**상태**: 결정 완료 (2026-04-27). Phase 1+2+3 풀 채택 + 결합공격 차단 (`hashed_resident_id`) 추가. (b), (c) 는 후속 작업으로 분리.
**이슈**: roadmap#4
**위협**: I-01 — 생체정보 평문 저장. 얼굴 임베딩(512-dim float 벡터) 은 개인정보보호법 §23 민감정보 중 **생체인식정보** 에 해당.
**관련**: T-003 (DB 평문 PII) 와 함께 "저장 시 암호화" 보강 작업군.

---

## 1. 현 상태

- 인덱스: `face_embeddings` (kNN vector index)
- 저장 필드: `embedding: [512 floats]`, `photo_id`, `resident_id`, `facility_id`
- Transport: **plain HTTP** (`use_ssl=False`), backend ↔ opensearch k8s 클러스터 내부 통신
- Node 수: 1 (single-node)
- 인증: 없음 (`http_auth` 미설정)
- 백업: 해당 없음 (현재)

**노출 가능 경로:**
1. 클러스터 내 임의 파드 → OpenSearch 직접 조회 (NetworkPolicy 없음; T-052 에서 대응 예정)
2. OpenSearch PV 디스크 탈취 (맥미니 물리 접근) → Lucene segment 파일 평문
3. 백업 (미구현) 시 snapshot 평문 유출
4. kubectl exec / port-forward 권한자 → 인덱스 전체 dump

---

## 2. 암호화 옵션 매트릭스

### 옵션 A: Transport 암호화 (HTTPS + basic auth)

- OpenSearch Security 플러그인 활성화 → TLS + 사용자 인증
- backend `use_ssl=True`, cert 검증, `http_auth=(user, password)` 추가
- **+** 네트워크 sniff, 임의 파드 직접 조회 차단 (경로 1 대응)
- **−** 디스크 평문은 그대로 (경로 2, 3)
- **구현 부담**: 중 (cert 발급, secret 배포, 재시작)

### 옵션 B: At-rest 디스크 암호화 (PV 레벨)

- 기반: LUKS (리눅스 dm-crypt) 또는 파일시스템 수준 암호화
- 맥미니에서는 **FileVault** (APFS 기반) 가 사실상 등가
- **+** 물리 탈취 시 디스크 암호화됨 (경로 2 대응)
- **−** 노드 기동 후에는 평문으로 마운트 — 런타임 권한 escalation 엔 무력
- **−** k3d/k3s 내부 PV 가 호스트 파일시스템 상에 있으므로 호스트 암호화에 의존
- **구현 부담**: 저 (FileVault 확인 한 번)

### 옵션 C: 필드 레벨 암호화 (application-level)

- backend 가 embedding 벡터를 암호화해서 저장, 검색 시 복호화
- **치명적 문제**: **kNN 유사도 검색 깨짐**. 암호화된 float 벡터 간 cosine/L2 거리는 의미 없음.
- 우회: HE (Homomorphic Encryption) / SMPC — 프로토타입 단계 기술, 성능 prohibitive
- **결론**: **불가**. embedding 은 저장 목적 자체가 벡터 연산이므로 필드 레벨 암호화와 본질적 충돌.

### 옵션 D: 임베딩 비저장 / on-demand 재계산

- 원본 사진만 저장, embedding 은 매 검색 시 재계산
- **−** 성능 prohibitive. "보호자가 사진 찾기" 요청마다 전체 사진 재계산 = 초 단위가 분 단위.
- **결론**: **불가** (성능상).

### 옵션 E: OpenSearch **Field Masking** + 접근 제어

- Security 플러그인의 field-level security + role-based 마스킹
- 평문 저장이지만 낮은 권한자 쿼리 결과에서 embedding 필드를 0 으로 반환
- **+** 운영 쿼리 (디버깅, admin) 로부터 유출 방어
- **−** 디스크 평문 (경로 2), PV dump (경로 3) 엔 무력
- 옵션 A 와 보완적 (같이 할 수 있음)

---

## 3. 권장 조합

**A + B + E** 순서로 단계 도입:

1. **Phase 1 (즉시, 단독 PR)**: FileVault 확인. 맥미니 시스템 설정에서 ON 여부 체크. OFF 면 ON + 재부팅 (유일한 일회성 작업). PV 가 위치한 디스크 경로 확인 (`/var/lib/rancher/k3s/...`).
2. **Phase 2 (큰 작업, 별도 PR)**: OpenSearch Security 플러그인 활성화
   - admin/backend 두 사용자만 생성
   - self-signed CA + cert → SealedSecret 으로 backend 에 마운트
   - backend `opensearch_service.py` 에서 `use_ssl=True`, `http_auth`, `ca_certs` 설정
   - Field masking role 은 향후 운영 단계에서 (현재 admin=backend 만 있어 의미 약함)
3. **Phase 3 (조건부)**: Snapshot 백업 도입 시 (T-043 과 맞물림) repository 에 암호화된 대상(R2 SSE-S3, MinIO SSE) 지정

---

## 4. Phase 2 상세 (OpenSearch Security)

### 4-1. 활성화 방법

현재 `mac-deploy/k8s/opensearch.yaml` 에 `plugins.security.disabled: true` 가 있을 가능성이 높음 (확인 필요). 이 플래그 제거 + `OPENSEARCH_INITIAL_ADMIN_PASSWORD` env 주입.

### 4-2. 필요 Secret (SealedSecret 에 추가)

- `OPENSEARCH_ADMIN_PASSWORD` — admin 초기 비밀번호
- `OPENSEARCH_BACKEND_USER` / `OPENSEARCH_BACKEND_PASSWORD` — backend 전용 최소 권한 계정
- `OPENSEARCH_CA_CERT` — self-signed CA 인증서 (verify 용)

### 4-3. backend 코드 변경

```python
# opensearch_service.py
client = OpenSearch(
    hosts=[{"host": settings.OPENSEARCH_HOST, "port": settings.OPENSEARCH_PORT}],
    http_auth=(settings.OPENSEARCH_BACKEND_USER, settings.OPENSEARCH_BACKEND_PASSWORD),
    use_ssl=True,
    verify_certs=True,
    ca_certs=settings.OPENSEARCH_CA_CERT_PATH,
    ssl_show_warn=False,
)
```

### 4-4. Role 설계

backend 계정 권한: `face_embeddings` 인덱스에 read/write/delete. 다른 인덱스 접근 불가. 관리자 API 접근 불가.

---

## 5. 결정 포인트

1. **Phase 1 FileVault 상태 확인** — 지금 맥미니가 FileVault ON 인가? (user 만 답할 수 있음)
   - **결정**: 미확정. T-004 구현 첫 스텝으로 확인. OFF 면 ON + 재부팅 (일회성).
2. **Phase 2 인증 체계**: self-signed CA + 내부 계정 분리로 충분? / 외부 IdP 연동까지 가야 하는가?
   - **결정**: self-signed CA + 백엔드 전용 계정. 외부 IdP 는 운영 규모 확대 시 (현재 admin = 1 명).
3. **Snapshot 백업을 이 스펙 안에 포함 (Phase 3) 시킬지, T-043 (pg_dump + MinIO 백업) 과 병행 이슈로 분리할지**
   - **결정**: 이 스펙에 포함 (T-004 후속 PR). T-043 백업은 이미 머지됐으니 그쪽 yaml 수정 PR 형태로. **R2 는 SSE-S3 가 default ON** 이라 확인만으로 끝날 가능성.
4. **기존 인덱스 데이터 재인덱싱 필요 여부**: Security 활성화 자체는 재인덱싱 불필요. TLS 활성화도 disk layout 변경 없음. → 사실 무손실 마이그레이션 가능.
   - **결정**: Security/TLS 자체는 재인덱싱 불필요. **단 §8 의 `hashed_resident_id` 도입은 reindex 1 회 필요** (Phase 2 작업과 같이 진행하면 자연스러움).

---

## 6. 범위 (이슈 분할 제안)

- roadmap#4 본체 → 설계 합의 (이 문서)
- 서브 이슈 a: FileVault 확인 + 문서화 (단순)
- 서브 이슈 b: OpenSearch Security 플러그인 활성화 + 계정 생성 + k8s yaml 업데이트
- 서브 이슈 c: backend `opensearch_service.py` SSL/auth 적용 + SealedSecret 추가
- 서브 이슈 d: 기존 인덱스 smoke test (재인덱싱 불필요한지 확인)
- 서브 이슈 e: `hashed_resident_id` 마이그레이션 (§8) — 인덱스 reindex 1 회 + backend 인덱싱/조회 코드 hash 적용 + `opensearch_link_key` SealedSecret 신규 추가
- 서브 이슈 f: R2 SSE 활성화 확인 (default ON 가정, 명시적 검증 1 회) — Phase 3

---

## 7. 비포함 사항 (의도적)

- **필드 레벨 암호화 (옵션 C)** — kNN 검색과 본질적 충돌, 채택 안 함.
- **HE/SMPC** — 프로토타입 단계 기술, 서비스 운영 단계 부적합.
- **embedding 비저장 (옵션 D)** — 성능상 불가.

이 셋은 "고려했으나 채택하지 않음" 으로 명시해서, 나중에 "왜 안 했지?" 재논의 방지.

---

## 8. 결합공격 차단 — `hashed_resident_id` 도입

Phase 1+2+3 만으론 **OpenSearch 단독 dump 가 유출됐을 때** "어떤 vector 가 누구 얼굴인지" 가 그대로 노출된다. vector 자체는 평문이지만 *식별 연결고리* 는 더 끊을 수 있다.

### 8-1. 변경 내용

현재 `face_embeddings` 인덱스:
- `embedding`: [512 floats]
- `photo_id`: int
- `resident_id`: int  ← **DB 의 PK 그대로**
- `facility_id`: int

변경 후:
- `embedding`: [512 floats]
- `photo_id`: int
- `resident_id_hash`: str  ← `HMAC-SHA256(opensearch_link_key, resident_id)`
- `facility_id`: int

`opensearch_link_key` 는 별도 SealedSecret 에 두고 backend 만 보유.

### 8-2. 효과

- **OpenSearch 단독 침해 시**: vector 와 hash 만 보여서 "누구 얼굴인지" 알 수 없음. 역추적엔 backend DB 까지 추가 침해 + key 까지 필요.
- **컴플라이언스 항변 강화**: 필드 레벨 암호화 = 기술적 불가능 (kNN 깨짐), 그러나 **결합공격 차단** 으로 등가 보호 달성. KISA 안전성 확보조치 해설서의 "compensating controls" 원칙에 부합.

### 8-3. 구현 부담

- backend 인덱싱 코드: `resident_id` → `hash_resident_id(rid)` 한 줄 변경
- backend 조회 코드: kNN 결과의 `resident_id_hash` 를 받아 동일 hash 함수로 매칭 (또는 hash → resident_id 역매핑 테이블)
- 마이그레이션: 기존 인덱스 reindex 1 회 (Phase 2 작업과 같이 진행)
- SealedSecret 추가: `opensearch_link_key`

### 8-4. 키 관리

| 키                    | 저장 위치             | 회전 주기 | 회전 시 영향                    |
|-----------------------|------------------------|-----------|----------------------------------|
| `opensearch_link_key` | SealedSecret (별도)    | 24 개월+  | 회전 시 전체 인덱스 reindex 필요 |

회전 빈도가 낮은 이유: hash 만 깨질 뿐 vector 는 영향 없으나 reindex 비용이 있어 신중하게.

---

## 9. 후속 작업 (launch 후, 별도 이슈로 분할)

본 스펙에 포함하지 않고 별도 이슈로 진행할 추가 방어층. Compliance 항변 단단해지지만 launch blocker 는 아님.

### (b) 임베딩 라이프사이클 정책

- 모델 업데이트 시 전체 임베딩 재생성, 옛 임베딩 즉시 삭제
- resident 삭제 시 임베딩 즉시 삭제 (현 구현 확인 필요)
- 분기 1 회 orphan 임베딩 (참조하는 photo/resident 없는 것) 클린업 CronJob
- **목적**: derived data 의 라이프사이클 관리 흔적 — 컴플라이언스 시 "민감정보 보유 기간 정책" 입증
- **실행 시점**: 운영 6 개월 후 또는 모델 업데이트 발생 시점

### (c) OpenSearch 인덱스 namespace 격리

- 현재 `senior-album` 네임스페이스에 OpenSearch 가 다른 stateful 서비스 (postgres, minio 등) 와 함께 있음
- 별도 ns (예: `senior-album-bio`) 로 분리, NetworkPolicy 로 backend 만 접근 가능하게 강제
- **효과**: 민감정보 격리 입증 + RBAC 분리 (admin 권한 작업 시 폭발 반경 축소)
- **선행 의존**: T-053 (CNI Calico 전환 — NetworkPolicy 가 실제로 작동하게)
- **실행 시점**: T-053 완료 후. 클러스터 재생성 작업과 자연스럽게 묶임.

---

## 결정 요약 (확정 — 2026-04-27)

1. **맥미니 FileVault 현재 상태**: T-004 구현 첫 스텝에서 확인. OFF 면 ON + 재부팅 (일회성).
2. **Phase 2 규모**: self-signed CA + OpenSearch Security + backend 전용 계정. 서브 이슈 b/c/d 로 분할 후 구현.
3. **Phase 3 (snapshot 암호화)**: 이 스펙에 포함 (서브 이슈 f). R2 SSE-S3 가 default ON 이라 확인만으로 끝날 가능성.
4. **`hashed_resident_id` 도입 (§8)**: T-004 본체에 포함 (서브 이슈 e). Phase 2 작업 시 reindex 1 회 필요.
5. **(b) 임베딩 라이프사이클, (c) namespace 격리 (§9)**: 후속 작업. launch 후 별도 이슈로.

서브 이슈 분할 후 구현 착수.
