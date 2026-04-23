# 빌드/배포 실패 롤백 런북

**대상**: `backend` / `frontend` Deployment 가 새 이미지로 전환 후 CrashLoop / 오동작 시
**관련**: T-045
**예상 소요**: 2~5분
**다운타임**: 롤백 rollout 시간 (초 단위)

---

## 0. 언제 이 런북을 따르는가

- 새 이미지 빌드 후 자동 배포된 파드가 CrashLoopBackOff / readiness 실패
- 새 이미지는 Ready 가 됐으나 실기능이 깨짐 (500 에러, 로그인 불가, 업로드 실패 등)
- CI 의 update-deploy job 이 k8s manifest 태그를 잘못 갱신

**선결**: 문제가 secret/config/env 원인인지 이미지 원인인지 먼저 구분. env/secret 문제면 §6 참조.

---

## 1. 현재/이전 이미지 태그 확인

```bash
# 현재 쓰이는 이미지
kubectl -n senior-album get deploy backend -o=jsonpath='{.spec.template.spec.containers[0].image}'
echo
kubectl -n senior-album get deploy frontend -o=jsonpath='{.spec.template.spec.containers[0].image}'
echo

# rollout 이력 (revision 과 그에 대응하는 이미지)
kubectl -n senior-album rollout history deploy/backend
kubectl -n senior-album rollout history deploy/frontend

# 특정 revision 의 이미지 확인
kubectl -n senior-album rollout history deploy/backend --revision=<N>
```

직전 정상 동작한 revision 번호 확인.

---

## 2. 롤백 실행 (Kubernetes 수준)

```bash
# 직전 revision 으로
kubectl -n senior-album rollout undo deploy/backend

# 특정 revision 지정
kubectl -n senior-album rollout undo deploy/backend --to-revision=<N>

kubectl -n senior-album rollout status deploy/backend --timeout=120s
```

frontend 도 동일 패턴.

> `rollout undo` 는 `replicaset history` 에 있는 template 으로 돌아감. revision limit (기본 10) 을 넘어 삭제된 replicaset 은 복원 불가 → §3.

---

## 3. rollout history 에 없는 옛 이미지로 돌리기

manifest 의 image 태그를 직접 수정:

```bash
# 특정 known-good 태그로 고정
kubectl -n senior-album set image deploy/backend \
  backend=ghcr.io/senior-album/album-backend:<known-good-sha>

kubectl -n senior-album rollout status deploy/backend --timeout=120s
```

**album-deploy 리포의 GitOps 소스도 같이 고정** — 안 그러면 다음 동기화 때 망가진 태그로 다시 덮어씌워짐:

```bash
cd ~/workspace/senior-album/album-deploy
# k8s/backend.yaml 의 image: 라인 수정
git diff k8s/backend.yaml
git add k8s/backend.yaml
git commit -m "ops: pin backend to <sha> due to <issue>"
git push
```

---

## 4. 실패한 PR/커밋 원복 (선택)

롤백은 응급 조치, 근본 수정은 다음 중 하나:

- (A) 문제 PR revert → 재배포
- (B) 문제 PR 을 고쳐서 후속 PR 머지 → 재배포
- (C) feature flag/env 토글로 기능만 off (코드 유지)

롤백 중인 동안 CI 의 update-deploy job 이 다시 새 태그로 덮을 가능성 있음 — pin 해둔 GitOps 소스가 우선하는지 확인.

---

## 5. 검증

```bash
kubectl -n senior-album get pods -l 'app in (backend,frontend)'
# → Running + 1/1 Ready

kubectl -n senior-album logs deploy/backend --tail=50 | grep -iE "error|exception" | head
curl https://thekim123.info/api/health
curl -I https://thekim123.info/
```

브라우저 수준 smoke: 로그인 → 사진 목록 → 한 장 업로드.

---

## 6. 원인이 secret/env 인 경우 (롤백 아니어도 됨)

실제로 이미지는 정상이고 새로 추가된 필수 env 가 SealedSecret 에 없는 케이스 — MinIO 런북 §10-2 참조.

증상: Pydantic ValidationError, `Field required`

대응:
```bash
# SealedSecret 에 누락 key 추가
kubectl -n senior-album create secret generic backend-secret \
  --from-literal=<NEW_KEY>="<value>" \
  --dry-run=client -o yaml | \
  kubeseal --controller-namespace kube-system --format yaml \
           --merge-into ~/workspace/senior-album/album-deploy/k8s/sealed/backend-secret.yaml

cd ~/workspace/senior-album/album-deploy
git add k8s/sealed/backend-secret.yaml
git commit -m "ops: add <NEW_KEY> to backend-secret"
git push

kubectl apply -f k8s/sealed/backend-secret.yaml
kubectl -n senior-album rollout restart deploy/backend
```

이 경우 **이미지 롤백은 오히려 문제를 감출 뿐** — 다음 배포 때 같은 증상 재발.

---

## 7. 완료 처리

- [ ] 서비스 정상 동작 확인
- [ ] 원인 이슈 등록 (임시 pin 이면 해제 조건 명시)
- [ ] album-deploy 의 GitOps 소스가 현재 실제 태그와 일치하는지 확인
- [ ] 릴리스 체크리스트에 이번 실패 패턴 추가 (재발 방지)

---

## 8. 관련 장애 패턴 (참고)

- **album-backend#21**: Albumentations 기동 시 HTTP 호출로 liveness timeout → `NO_ALBUMENTATIONS_UPDATE=1` 누락
- **roadmap#90**: 이미지 amd64-only → arm64 노드에서 qemu 에뮬로 느림 (CrashLoop 은 아니었으나 실기능 저하)
- **roadmap#87 §10-2**: 이미지가 신규 필수 env 요구하는데 SealedSecret 미마이그레이션 → §6 케이스
