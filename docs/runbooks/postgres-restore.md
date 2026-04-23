# PostgreSQL 복구 런북

**대상**: `postgres` Deployment (senior-album 네임스페이스), PV 기반
**관련**: T-045, 장애 시 복구
**예상 소요**: 10~30분 (DB 크기 따라)
**다운타임**: 복구 전 구간. 백엔드는 DB 없이 동작 불가 — 재시작 필수.

---

## 0. 언제 이 런북을 따르는가

- PV 손상 / 파일시스템 오류로 postgres 파드 기동 실패
- 의도치 않은 데이터 삭제 / corruption
- 마이그레이션 실패 후 전체 롤백 필요
- 맥미니 디스크 장애로 새 PV 에서 재시작

> **데이터 손실 범위**: 가장 최근 pg_dump 시점부터 장애 시점까지. T-043 (pg_dump 일 1회) 미구현 시 복구 가능 데이터 없음 → 선결 이슈.

---

## 1. 사전 확인

### 1-1. 백업 파일 존재 확인

```bash
# 백업 저장 위치 (T-043 구현 후 경로 확정). 현재 임시 경로 가정
ls -lh /Users/thekim123/backups/senior_album/*.sql.gz
# 또는 R2/MinIO 외부 백업
```

백업 없으면 §5 '백업 없이 재초기화' 로.

### 1-2. 현재 장애 상태 확인

```bash
kubectl -n senior-album get pods -l app=postgres
kubectl -n senior-album describe pod <postgres-pod>
kubectl -n senior-album logs <postgres-pod> --tail=100
```

---

## 2. 백엔드 중지 (DB 에 쓰기 차단)

```bash
kubectl -n senior-album scale deploy/backend --replicas=0
kubectl -n senior-album scale deploy/photo-worker --replicas=0 2>/dev/null || true
kubectl -n senior-album get pods -l 'app in (backend,photo-worker)'
# → 0 개
```

---

## 3. 복구 경로 A: 같은 PV, DB 초기화 후 dump 복원

### 3-1. 현재 DB 드롭 + 재생성

```bash
POSTGRES_POD=$(kubectl -n senior-album get pod -l app=postgres -o name | head -1)

kubectl -n senior-album exec -it $POSTGRES_POD -- psql -U postgres -c \
  "DROP DATABASE IF EXISTS senior_album;"
kubectl -n senior-album exec -it $POSTGRES_POD -- psql -U postgres -c \
  "CREATE DATABASE senior_album;"
```

### 3-2. dump 파일 복원

```bash
# 로컬 파일을 파드로 복사 후 restore
kubectl -n senior-album cp /Users/thekim123/backups/senior_album/latest.sql.gz \
  senior-album/$(basename $POSTGRES_POD):/tmp/restore.sql.gz

kubectl -n senior-album exec -it $POSTGRES_POD -- bash -c \
  "gunzip -c /tmp/restore.sql.gz | psql -U postgres -d senior_album"

kubectl -n senior-album exec -it $POSTGRES_POD -- rm /tmp/restore.sql.gz
```

### 3-3. 검증

```bash
kubectl -n senior-album exec -it $POSTGRES_POD -- psql -U postgres -d senior_album -c \
  "SELECT COUNT(*) FROM facilities; SELECT COUNT(*) FROM residents; SELECT COUNT(*) FROM photos;"
```

복원 기준선(백업 시점) 의 row 수와 대충 일치해야 함.

---

## 4. 복구 경로 B: PV 자체 손상 — 새 PV 로 시작

### 4-1. 기존 PVC 삭제 (위험: 남은 데이터 영구 손실)

```bash
# 먼저 PV 의 retainPolicy 확인 — Retain 이면 data 는 살아있음
kubectl get pv -o wide | grep postgres

kubectl -n senior-album delete pod -l app=postgres
kubectl -n senior-album delete pvc postgres-pvc
```

### 4-2. postgres 파드 재생성 → 새 PVC 자동 bind

```bash
kubectl -n senior-album rollout restart deploy/postgres
# 또는 manifest 재적용
kubectl apply -f ~/workspace/senior-album/album-deploy/k8s/postgres.yaml

kubectl -n senior-album wait --for=condition=Ready pod -l app=postgres --timeout=120s
```

### 4-3. §3-1 부터 동일

---

## 5. 백업 없이 재초기화 (최후 수단)

T-043 미구현 상태에서 데이터 전체 유실 시 - 새 DB 로 서비스 재기동.

```bash
# 4-1, 4-2 수행 후 3-1 까지만 (restore 없음)
# backend 가 기동되면 DDL_AUTO 또는 Alembic(T-120 후) 으로 스키마 재생성
```

**영향**: 시설/입소자/사진/보호자 모든 데이터 소실. 운영 시작 전 단계에서만 허용.

---

## 6. 백엔드 재시작

```bash
kubectl -n senior-album scale deploy/backend --replicas=1
kubectl -n senior-album scale deploy/photo-worker --replicas=1 2>/dev/null || true
kubectl -n senior-album rollout status deploy/backend --timeout=120s
```

---

## 7. Smoke test

```bash
# DB 연결
kubectl -n senior-album logs deploy/backend --tail=30 | grep -iE "database|postgres|connection"

# API
curl https://thekim123.info/api/health
# → 200

# 데이터 조회
# 브라우저 로그인 → 시설 목록, 보호자 목록, 사진 목록 표시 확인
```

---

## 8. OpenSearch 재인덱싱 (필요 시)

DB 복원 결과로 photo/face 상태가 OpenSearch 와 불일치할 수 있음 (예: 복원 시점 이후 인덱싱된 face 들).

```bash
# 관리자 API 로 전체 reclassify 트리거 (관리자 권한 필요)
# - album-backend 의 관리자 엔드포인트 사용 (정확한 경로는 README 참조)
```

재인덱싱은 비동기 Job, 수 분 ~ 수십 분.

---

## 9. 백업 파일 정리

복원 성공 후 임시 복사본 삭제:

```bash
# 파드 내 /tmp 는 재시작 시 삭제되지만 명시적으로
# 로컬 다운로드한 파일은 보관 정책에 따라 유지/삭제
```

---

## 10. 완료 처리

- [ ] smoke test 통과
- [ ] backend/worker replica 원복
- [ ] OpenSearch 재인덱싱 완료 (필요 시)
- [ ] 장애 root cause 메모 (재발 방지)
- [ ] 선행 이슈 (T-043 pg_dump 자동화) 가 미완이면 우선순위 상향
