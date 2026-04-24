# PostgreSQL `postgres` 사용자 비밀번호 회전 런북

**대상 키**: `POSTGRES_PASSWORD` (`backend-secret`)
**관련 이슈**: #87 Secret 값 회전 — 2026-04-22 대화 로그 노출 건 대응
**예상 소요**: 15~20분 (smoke test 포함)
**다운타임**: backend rollout 동안 수~수십 초 + ALTER USER 와 rollout 사이 새 DB 연결 실패 (alpha 단계 사용자 0명이라 사실상 무시 가능)

Kakao / MinIO 런북과 동일 골격. 차이점:
- 외부 서비스 콘솔이 아니라 **DB 자체 (psql ALTER USER)** 가 회전 주체
- backend + `postgres-backup` CronJob 두 곳이 같은 Secret 키를 참조 — 갱신 한 번으로 둘 다 자동 반영
- `DATABASE_URL` 평문이 아니라 부분 env 조립 구조 전제 (#55, album-deploy#8 머지 후에만 실행 가능)

---

## 0. 사전 확인

```bash
kubectl config current-context
kubectl -n senior-album get deploy backend -o name
kubectl -n senior-album get cronjob postgres-backup -o name

# kubeseal controller 의 정확한 이름/네임스페이스 확인 — §2 에서 그대로 씀
kubectl get deploy -A | grep -i sealed
# 기대 출력 예: kube-system   sealed-secrets-controller   1/1 ...
# `sealed-secrets` 가 아닌 `sealed-secrets-controller` 인 클러스터 많음 (#87 회전 시 1회 실패)

cd /Users/thekim123/workspace/senior-album/album-deploy && git status && git pull --rebase
```

`SEALED_CONTROLLER_NAME` / `SEALED_CONTROLLER_NS` 를 위 출력값으로 셸 변수에 박아두면 §2 에서 오타 위험 줄어듦:
```bash
SEALED_CONTROLLER_NAME=sealed-secrets-controller   # 위 grep 결과로 교체
SEALED_CONTROLLER_NS=kube-system
```

**필수 선행**:
- [x] `album-backend#55` 머지 + 새 이미지 rollout 완료
- [x] `album-deploy#8` 머지 + 실 ConfigMap 에 `POSTGRES_HOST/PORT/USER/DB` 적용 완료
- [x] `kubectl -n senior-album get configmap backend-config -o yaml | grep -E 'POSTGRES_|DATABASE_URL'` — `POSTGRES_HOST/PORT/USER/DB` 만 보이고 `DATABASE_URL` 은 없어야 함

위 조건이 안 맞으면 회전 후 backend 가 옛 DATABASE_URL fallback 으로 옛 비밀번호로 접속 시도 → 실패. 반드시 확인.

MinIO 런북 §11 의 일반 체크리스트 (.gitignore, 미마이그레이션 env, git sync) 도 훑는다.

---

## 1. 새 비밀번호 생성

```bash
NEW_PG_PASSWORD=$(openssl rand -base64 32 | tr -d '+/=' | head -c 40)
echo "length=${#NEW_PG_PASSWORD}"   # 40

# 확인용으로만 1회 출력. 절대 LLM/Slack/외부 서비스에 붙여넣지 않음 (#87 의 원인).
```

`tr -d '+/='` — base64 의 특수문자가 connection string URL-encoding 시 시그널이 되어 파싱 사고를 유발할 수 있음. 영숫자만 남긴다.

---

## 2. SealedSecret 사전 갱신 (rollout 전)

비밀번호를 먼저 SealedSecret 에 박아둔다. controller 가 Secret 을 업데이트하지만, **backend pod 는 envFrom 으로 받은 env 가 메모리에 박혀있어 재시작 전까지 옛 값 그대로 사용**. 즉 Secret 갱신만으로는 다운타임 없음.

```bash
cd /Users/thekim123/workspace/senior-album/album-deploy

kubectl -n senior-album create secret generic backend-secret \
  --from-literal=POSTGRES_PASSWORD="${NEW_PG_PASSWORD}" \
  --dry-run=client -o yaml | \
  kubeseal --controller-namespace "$SEALED_CONTROLLER_NS" \
           --controller-name "$SEALED_CONTROLLER_NAME" \
           --format yaml --merge-into k8s/sealed/backend-secret.yaml

git diff k8s/sealed/backend-secret.yaml   # POSTGRES_PASSWORD 라인만 바뀌어야 함
git add k8s/sealed/backend-secret.yaml
git commit -m "security: rotate POSTGRES_PASSWORD in backend SealedSecret (roadmap#87)"
git push

# ArgoCD sync 기다리지 말고 즉시 적용 (반드시 — sync 지연으로 §3 시점까지 옛 값이 cluster 에 남아있으면 §4 rollout 후 새 pod 가 옛 값으로 인증 시도 → 실패)
kubectl apply -f k8s/sealed/backend-secret.yaml
```

controller 가 SealedSecret 을 디코드해서 Secret `backend-secret` 의 `POSTGRES_PASSWORD` 키만 새 값으로 갱신할 때까지 ~10초. **반드시 일치 확인 후 §3 진행** (#87 회전 시 이 검증 스킵해서 30분 디버깅):

```bash
sleep 10
APPLIED=$(kubectl -n senior-album get secret backend-secret -o jsonpath='{.data.POSTGRES_PASSWORD}' | base64 -d)
echo "match: $([[ "$APPLIED" == "$NEW_PG_PASSWORD" ]] && echo YES || echo NO)"
echo "applied_len=${#APPLIED}  newpw_len=${#NEW_PG_PASSWORD}"
# 반드시 match: YES + 두 길이 일치. NO 면 절대 §3 진행 금지 — kubeseal 단계 재시도
```

---

## 3. PostgreSQL 에서 ALTER USER

이 시점부터 **새 DB 연결은 옛 비밀번호로 인증 실패**. backend 는 NullPool (커넥션 풀 없음 — 매 request 새 연결) 이라 즉시 영향 받음. §4 rollout 까지 새 요청이 실패할 수 있는 짧은 윈도우.

```bash
PG_POD=$(kubectl -n senior-album get pod -l app=postgres -o jsonpath='{.items[0].metadata.name}')

kubectl -n senior-album exec -it "$PG_POD" -- \
  psql -U postgres -d senior_album \
       -c "ALTER USER postgres PASSWORD '${NEW_PG_PASSWORD}';"
# → ALTER ROLE
```

> **주의**: `-c` 인자에 비밀번호가 들어감. shell history 에 남는다 — `unset HISTFILE` 또는 직후 `history -d $(history 1 | awk '{print $1}')` 로 정리. 더 안전한 방식: `psql` 안에서 `\password postgres` (대화형 — 화면 입력).

---

## 4. backend rollout

```bash
kubectl -n senior-album rollout restart deployment/backend
kubectl -n senior-album rollout status deployment/backend --timeout=120s
```

새 pod 가 SealedSecret 에서 디코드된 새 `POSTGRES_PASSWORD` 를 envFrom 으로 받음 → `config.py` 의 `database_url` computed property 가 `postgresql+asyncpg://postgres:NEW_PASSWORD@postgres:5432/senior_album` 으로 조립 → DB 인증 성공.

> **주의 — envFrom 캐시**: `envFrom` 으로 받은 env 는 **pod 생성 시점에 fixed**. Secret 만 갱신하고 pod 재시작 안 하면 옛 값 그대로 사용. `rollout restart` 면 보통 충분하지만, 옛 pod 가 CrashLoopBackOff 상태로 남아있으면 강제 삭제 필요:
> ```bash
> kubectl -n senior-album delete pod -l app=backend --force --grace-period=0
> ```

`postgres-backup` CronJob 은 다음 스케줄 (18:00 UTC) 에 자동으로 새 Secret 값을 받아 동작. 별도 조치 불필요.

---

## 5. Smoke test

```bash
# 5-1. backend 로그에 인증 에러 없는지
kubectl -n senior-album logs deployment/backend --tail=200 | \
  grep -iE "password authentication failed|FATAL.*role|connection refused" || echo "clean"

# 5-2. 헬스체크
kubectl -n senior-album exec deployment/backend -- \
  curl -s localhost:8000/health
# → {"status":"healthy"}

# 5-3. 실제 DB 쿼리 (브라우저)
#   - 로그인 → 사진 리스트 정상 표시
#   - 사진 1장 업로드 → DB INSERT 성공 확인

# 5-4. 백업 CronJob 사전 검증 (다음 스케줄까지 기다리지 않고)
kubectl -n senior-album create job postgres-backup-rotation-test \
  --from=cronjob/postgres-backup
kubectl -n senior-album logs job/postgres-backup-rotation-test --follow
# → "[backup] done ..." 으로 끝나야 성공. pg_dump 가 새 비밀번호로 인증 성공한 것.
kubectl -n senior-album delete job postgres-backup-rotation-test
```

5-4 가 실패하면 backup 만 깨진 상태로 다음 18:00 까지 모르고 지나갈 수 있음 — 회전 직후 반드시 수동 트리거.

실패 시 §7 롤백.

---

## 6. 백업 / 흔적 정리

```bash
unset NEW_PG_PASSWORD
history -c                                   # zsh/bash session history 비우기
# 또는 specific entry: history -d <line>
```

git history 의 SealedSecret 커밋은 암호화돼 있어 노출 위험 없음 — 그대로 둔다.

---

## 7. 롤백 절차

회전 직후 일정 시간은 옛 비밀번호도 안다 (생성 → ALTER 사이). 그 이후엔 옛 값 복구 불가 — 또 새 비밀번호 만들어 §1~§4 재수행.

### 7-1. SealedSecret 만 갱신했고 ALTER USER 전이라면
- git revert 로 SealedSecret 되돌리기 + 그대로 둠 (Secret 자체는 controller 가 다시 옛 값으로 회복)

### 7-2. ALTER USER 까지 했는데 rollout 이후 backend 가 인증 실패한다면
원인은 셋 중 하나:
1. SealedSecret 에 박힌 값과 ALTER USER 한 값이 불일치 (오타)
2. ConfigMap 의 `POSTGRES_*` 가 아직 옛 `DATABASE_URL` 인 상태 (사전 확인 §0 누락)
3. backend 이미지가 #55 머지 전 옛 이미지 (DATABASE_URL fallback 로 옛 값 사용)

진단 (세 값 모두 일치해야 함):
```bash
# 1) SealedSecret 디코드 값 vs NEW_PG_PASSWORD
APPLIED=$(kubectl -n senior-album get secret backend-secret -o jsonpath='{.data.POSTGRES_PASSWORD}' | base64 -d)
echo "secret_match: $([[ "$APPLIED" == "$NEW_PG_PASSWORD" ]] && echo YES || echo NO)"

# 2) backend pod 의 env 가 가진 POSTGRES_PASSWORD (해시 비교 — 평문 출력 금지)
NEW_POD=$(kubectl -n senior-album get pod -l app=backend -o jsonpath='{.items[0].metadata.name}')
echo "pod_env_sha:    $(kubectl -n senior-album exec "$NEW_POD" -- sh -c 'echo -n "$POSTGRES_PASSWORD" | sha256sum' | cut -c1-16)"
echo "newpw_sha:     $(echo -n "$NEW_PG_PASSWORD" | sha256sum | cut -c1-16)"

# 3) DB 가 받아들이는 값 — **반드시 네트워크 경유 (다른 pod) 로 검증**
#    `kubectl exec $PG_POD -- psql -U postgres` 는 로컬 socket peer auth 라
#    비밀번호 검증 없이 통과 → 헛 검증 (#87 회전 시 1시간 헤맨 원인)
kubectl -n senior-album run dbtest --rm -it --restart=Never \
  --image=postgres:15-alpine --labels=app=backend \
  --env=PGPASSWORD="$NEW_PG_PASSWORD" \
  -- sh -c 'psql -h postgres -U postgres -d senior_album -c "SELECT '\''auth_ok'\'' AS r;"'
# → "auth_ok" 출력되면 DB 는 NEW_PG_PASSWORD 받아들이는 상태.
# `--labels=app=backend` 필수 — NetworkPolicy 가 임의 라벨 pod 의 postgres 접근 차단.
```

위 세 결과로 진단:
- 1) NO → kubeseal 단계 다시. 흔한 원인: controller 이름 오타 (§0 의 grep 결과 다시 확인)
- 1) YES + 2) sha 다름 → pod env 캐시 stale → §4 의 force delete 박스 참조
- 1) YES + 2) sha 일치 + 3) password fail → ALTER USER 가 다른 값으로 됐음. ALTER USER 재실행 후 다시 검증
- 모두 OK 면 backend 코드 / NetworkPolicy / pg_hba.conf 쪽으로 의심 이동

### 7-3. 영속적 실패: 임시로 옛 비밀번호 패턴으로 ALTER USER 다시 (긴급용)
서비스 복구 우선이라면, 직전 알려진 비밀번호로 다시 ALTER USER 후 SealedSecret 도 그 값으로 되돌림. 단 노출된 값으로 되돌리는 거라 회전 효과는 사라짐 — **#87 관점에서는 미완료 처리**.

---

## 8. 완료 처리

- [ ] 이슈 #87 에 체크리스트 업데이트 (POSTGRES 항목 ✅)
- [ ] album-deploy SealedSecret PR 머지 확인
- [ ] 다음날 18:00 UTC 정기 백업 성공 여부 재확인 (수동 테스트가 통과해도 환경 차이로 정기 실행만 실패하는 케이스 있음)
- [ ] 프로젝트 보드 #87 → `Done`

> **zsh 사용자**: §6 의 `history -c` 는 bash 전용. zsh 에서는:
> ```bash
> fc -W && sed -i '' -E '/NEW_PG_PASSWORD|PGPASSWORD|ALTER USER/d' ~/.zsh_history && fc -R
> ```
> 또는 솔로 머신이면 새 터미널 열기만으로도 충분 (현재 세션 변수는 unset 으로 이미 정리).

---

## 9. 다음 회전 시점

회전 트리거:
- 비밀번호 노출 의심 (대화 로그, 스크린샷, 백업 dump 유출 등)
- 정기 회전 정책 수립 시 (현재 미수립 — 알파 종료 후 결정)
- 직원 퇴사 / 권한 변경 시 (현재 솔로 — 미해당)

연관 변경:
- `DATABASE_URL` 을 다시 도입할 일이 생기면 (read replica 등) 본 런북 §0 사전 확인 항목 갱신 필요
- postgres pod 의 `POSTGRES_PASSWORD` env (initdb 용) 는 PV 가 이미 초기화돼 있어 무시됨 — 회전 후에도 그대로 둬도 무방. 다만 PV 재초기화 시나리오 (`postgres-restore.md`) 에서는 **현재 SealedSecret 값과 일치시켜야** 새 클러스터에서 동일 비밀번호로 init 됨.
