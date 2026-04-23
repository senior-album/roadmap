# MinIO 루트 자격증명 회전 런북

**대상 키**: `MINIO_ACCESS_KEY`, `MINIO_SECRET_KEY` (`backend-secret`)
**관련 이슈**: #87 Secret 값 회전 — 2026-04-22 대화 로그 노출 건 대응
**예상 소요**: 15~25분 (smoke test 포함)
**다운타임**: 파드 재시작 순간 수~수십 초 (업로드/presigned URL 순간 실패 가능)

---

## 0. 사전 확인

이 런북은 맥미니 `~/album-deploy/` 작업 디렉터리에서 실행한다고 가정한다.

```bash
# 현재 컨텍스트가 senior-album k3s 클러스터인지 확인
kubectl config current-context
kubectl -n senior-album get deploy minio backend -o name

# album-deploy 로컬 최신화
cd ~/album-deploy && git status && git pull --rebase
```

### MinIO가 참조되는 지점 (영향 범위)

- **MinIO 서버 자체**: Deployment `minio`의 `MINIO_ROOT_USER`/`MINIO_ROOT_PASSWORD` 가 `backend-secret` 의 `MINIO_ACCESS_KEY`/`MINIO_SECRET_KEY` 로 주입됨 → 이 두 키를 바꾸면 **MinIO root 자격증명 자체가 바뀜**
- **backend**: `src/backend/app/core/storage.py` 가 같은 두 키로 S3 API 접속
- → **두 파드 모두 재시작해야 정상화.** 기존 오브젝트/버킷은 그대로 유지됨

### album-deploy 의 현재 secret 관리 방식 확인

```bash
# 후보 경로에서 backend-secret 매니페스트 찾기
grep -rln "name: backend-secret" ~/album-deploy || true
grep -rln "kind: SealedSecret" ~/album-deploy || true
```

- `kind: Secret` (stringData / data) → **Path A: 평문 base64 매니페스트** 를 따름
- `kind: SealedSecret` → **Path B: Sealed Secrets** 를 따름 (T-050 완료 상태)

둘 다 있으면 Sealed 쪽을 신뢰하고 구 `Secret` 매니페스트는 삭제 대상.

---

## 1. 새 credential 생성 (맥미니 로컬에서만)

> 생성된 값은 **절대 외부 SaaS (Claude, 브라우저 검색창, Slack 등) 에 붙여넣지 않는다**. 터미널 + 파일시스템에만 머물게 한다. #87 의 원인이 이 규칙 위반이었다.

```bash
# 20자 이상, URL-safe. MinIO access key는 최소 3자, secret은 8자 이상 권장
NEW_ACCESS_KEY="$(openssl rand -hex 12)"          # 24자 hex
NEW_SECRET_KEY="$(openssl rand -base64 32 | tr -d '/+=' | cut -c1-40)"  # 40자 URL-safe

# 확인 (값이 화면에 찍히니 주변 사람 주의)
echo "ACCESS=$NEW_ACCESS_KEY"
echo "SECRET=$NEW_SECRET_KEY"
```

---

## 2. 클러스터 Secret 갱신

`kubectl apply` 는 `last-applied-configuration` annotation 에 평문을 박아 노출의 원인이 되므로 **`kubectl patch` 를 사용한다** (프로젝트 메모리 원칙).

```bash
# 현재 값 백업 (롤백용, 잠깐만 보관하고 지운다)
kubectl -n senior-album get secret backend-secret -o yaml > /tmp/backend-secret.backup.$(date +%s).yaml
chmod 600 /tmp/backend-secret.backup.*.yaml

# stringData patch — data 필드가 아니라 stringData 로 넣어야 kube-apiserver 가 base64 인코딩
kubectl -n senior-album patch secret backend-secret \
  --type=merge \
  -p "$(cat <<EOF
{"stringData": {"MINIO_ACCESS_KEY": "${NEW_ACCESS_KEY}", "MINIO_SECRET_KEY": "${NEW_SECRET_KEY}"}}
EOF
)"

# 적용 확인 (base64 디코드)
kubectl -n senior-album get secret backend-secret \
  -o jsonpath='{.data.MINIO_ACCESS_KEY}' | base64 -d; echo
# → $NEW_ACCESS_KEY 와 일치해야 한다
```

### ⚠️ `last-applied-configuration` annotation 점검

과거에 `kubectl apply -f secret.yaml` 이 한 번이라도 실행된 이력이 있으면 해당 annotation 에 **옛 평문** 이 남아 있다. #87 의 직접 원인이었으므로 제거한다.

```bash
kubectl -n senior-album get secret backend-secret \
  -o jsonpath='{.metadata.annotations}' | grep -q last-applied && \
  kubectl -n senior-album annotate secret backend-secret \
    kubectl.kubernetes.io/last-applied-configuration- || \
  echo "annotation 없음, skip"
```

---

## 3. album-deploy GitOps 소스 갱신

이 단계를 안 하면 다음 동기화(ArgoCD auto-sync 또는 수동 `kubectl apply`) 때 **옛 값으로 덮어씌워진다**.

### Path A: 평문 base64 매니페스트 (Sealed Secrets 미도입 상태)

평문 base64 도 git history 에 남으면 private 여도 노출로 간주한다(#87 의 전제). 두 가지 선택:

- **A-1 (권장, 임시)**: 매니페스트에서 `MINIO_ACCESS_KEY` / `MINIO_SECRET_KEY` 필드 **제거** 하고 "수동 관리" 주석을 남긴다. 값은 클러스터에만 존재
- **A-2 (비권장, 기존 방식 유지)**: 새 base64 값으로 갱신. 추후 T-050 완료 시 전체 재생성 필요

예시 (A-1):

```bash
cd ~/album-deploy
# backend-secret.yaml 위치는 실제 경로에 맞게
$EDITOR k8s/backend-secret.yaml
# → 아래 두 줄 삭제하고 주석 추가
#   MINIO_ACCESS_KEY: <base64>
#   MINIO_SECRET_KEY: <base64>
# + # MINIO_* keys managed out-of-band after 2026-04-23 rotation; see roadmap#87

git diff k8s/backend-secret.yaml
git add k8s/backend-secret.yaml
git commit -m "security: remove MINIO_* from backend-secret manifest (rotated 2026-04-23, roadmap#87)"
git push
```

### Path B: Sealed Secrets (T-050 완료 상태)

```bash
cd ~/album-deploy

# 1) 기존 SealedSecret 에 새 값만 패치 — kubeseal 의 merge 모드
# secret.yaml 임시 파일을 거치지 말고 stdin 파이프로만 처리한다
kubectl -n senior-album create secret generic backend-secret \
  --from-literal=MINIO_ACCESS_KEY="${NEW_ACCESS_KEY}" \
  --from-literal=MINIO_SECRET_KEY="${NEW_SECRET_KEY}" \
  --dry-run=client -o yaml | \
  kubeseal --controller-namespace kube-system --controller-name sealed-secrets \
           --format yaml --merge-into k8s/backend-sealedsecret.yaml

git diff k8s/backend-sealedsecret.yaml
git add k8s/backend-sealedsecret.yaml
git commit -m "security: rotate MINIO_* in backend SealedSecret (roadmap#87)"
git push
```

> 실제 SealedSecret 파일 경로/controller name/namespace 는 현재 album-deploy 설정에 맞춰 교체.

---

## 4. 파드 재시작

MinIO 는 root 자격증명을 **시작 시 env 로 고정 로드**하므로 `rollout restart` 가 필요하다. backend 도 `get_settings()` 가 프로세스 기동 시 캐시되므로 재시작 필수.

```bash
kubectl -n senior-album rollout restart deployment/minio
kubectl -n senior-album rollout status deployment/minio --timeout=120s

kubectl -n senior-album rollout restart deployment/backend
kubectl -n senior-album rollout status deployment/backend --timeout=120s
```

> **순서 주의**: MinIO 를 먼저 재시작해야 backend 재기동 후 첫 연결에서 바로 새 credential 이 유효하다. 역순이면 backend 가 옛 credential 로 붙었다가 401 을 몇 번 관찰하게 됨.

---

## 5. Smoke test

```bash
# 5-1. MinIO 로그에 auth 실패 없는지
kubectl -n senior-album logs deployment/minio --tail=50 | grep -iE "error|denied" || echo "clean"

# 5-2. backend 로그에 S3/boto 에러 없는지
kubectl -n senior-album logs deployment/backend --tail=100 | \
  grep -iE "accessdenied|invalidaccesskey|signaturedoesnotmatch|s3" || echo "clean"

# 5-3. 버킷 존재 확인 (backend 가 기동하면 _ensure_bucket 이 돌았을 것)
kubectl -n senior-album exec deployment/minio -- \
  mc alias set local http://localhost:9000 "${NEW_ACCESS_KEY}" "${NEW_SECRET_KEY}" && \
  kubectl -n senior-album exec deployment/minio -- mc ls local/senior-album-photos | head

# 5-4. 앱 레벨 — 브라우저에서
#   로그인 → 사진 업로드 → 리스트 표시 → presigned URL 로 썸네일 로드
#   (실사용자 0이므로 본인 계정으로 충분)
```

모두 통과하면 회전 완료. 실패 시 §8 롤백.

---

## 6. `minio-init` Job 처리 (선택)

`mac-deploy/k8s/minio.yaml` 의 `minio-init` Job 에 `mc alias set myminio http://minio:9000 minioadmin minioadmin` 이 **하드코드**되어 있다. 현재 이 Job 은 초기 배포 시 1회만 실행되므로 회전 자체엔 영향 없음. 단, 버킷을 재생성해야 하는 상황(재해복구 등) 에서 깨지므로 이 기회에 고치는 것을 권장:

```yaml
# mac-deploy/k8s/minio.yaml (minio-init Job 의 mc 컨테이너)
env:
  - name: ACCESS_KEY
    valueFrom: { secretKeyRef: { name: backend-secret, key: MINIO_ACCESS_KEY } }
  - name: SECRET_KEY
    valueFrom: { secretKeyRef: { name: backend-secret, key: MINIO_SECRET_KEY } }
command:
  - /bin/sh
  - -c
  - |
    mc alias set myminio http://minio:9000 "$ACCESS_KEY" "$SECRET_KEY"
    mc mb myminio/senior-album-photos --ignore-existing
    mc anonymous set download myminio/senior-album-photos
```

별도 PR 로 처리해도 됨 (회전 자체와 분리 가능).

---

## 7. 백업 파일 정리

```bash
# 5분 이상 이상무면 백업 삭제
shred -u /tmp/backend-secret.backup.*.yaml 2>/dev/null || rm -f /tmp/backend-secret.backup.*.yaml
```

---

## 8. 롤백 절차

smoke test 에서 MinIO/backend 가 정상화되지 않을 경우:

```bash
# 백업으로 secret 복원
kubectl -n senior-album replace -f /tmp/backend-secret.backup.<timestamp>.yaml

# 파드 재시작
kubectl -n senior-album rollout restart deployment/minio deployment/backend
```

롤백 후엔 §2 부터 다시, 오타/복붙 오류 확인.

---

## 9. 완료 처리

- [ ] 이슈 #87 에 체크리스트 업데이트 (MINIO 항목 체크)
- [ ] album-deploy PR 머지 확인
- [ ] 프로젝트 보드 #87 상태 유지 (`In progress`) — KAKAO/POSTGRES 남음

다음 단계: `KAKAO_CLIENT_SECRET` 회전 (카카오 개발자 콘솔에서 재발급 후 동일 절차).
