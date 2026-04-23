# Kakao OAuth Client Secret 회전 런북

**대상 키**: `KAKAO_CLIENT_SECRET` (`backend-secret`)
**관련 이슈**: #87 Secret 값 회전 — 2026-04-22 대화 로그 노출 건 대응
**예상 소요**: 10~15분 (smoke test 포함)
**다운타임**: backend 재시작 순간 수~수십 초. 재시작 중 진행 중인 카카오 로그인 플로우는 실패 가능

MinIO 런북(`minio-key-rotation.md`) 과 동일 패턴. 차이점:
- 영향 범위가 **backend 단독** (`minio` 배포 없음)
- 외부 서비스(카카오 개발자 콘솔) 에서 재발급 → 구값 즉시 무효화되므로 **재발급 직후 클러스터 갱신까지 브레이크 없이 진행**
- `KAKAO_CLIENT_ID` 는 공개 식별자라 회전 불필요 — secret 만 교체

---

## 0. 사전 확인

```bash
kubectl config current-context
kubectl -n senior-album get deploy backend -o name
cd /Users/thekim123/workspace/senior-album/album-deploy && git status && git pull --rebase
```

MinIO 런북 §11 의 체크리스트도 훑어본다 (.gitignore, 미마이그레이션 env, git sync).

---

## 1. 카카오 개발자 콘솔에서 재발급

1. https://developers.kakao.com 접속 → 내 애플리케이션 → 해당 앱
2. **앱 설정 > 보안** 탭
3. **Client Secret** 섹션 → **코드 생성** (또는 **재발급**) 버튼
4. **활성화 상태 = ON** 확인 (OFF 상태면 backend 가 client_secret 을 요청해도 카카오가 무시)
5. 값 복사 — **터미널 + 파일시스템에만 머물게**. 브라우저 다른 탭, Slack, LLM 입력창에 절대 붙여넣지 않음 (#87 의 원인)

```bash
# 맥 로컬 쉘 변수로만 보관
NEW_KAKAO_SECRET="<콘솔에서 복사한 값>"
echo "length=${#NEW_KAKAO_SECRET}"   # 32자 hex 정도 예상
```

> 이 시점부터 **옛 client_secret 은 무효**. 바로 §2~§4 를 끊김 없이 실행한다.

---

## 2. 클러스터 Secret 갱신

```bash
# 백업
kubectl -n senior-album get secret backend-secret -o yaml > /tmp/backend-secret.backup.$(date +%s).yaml
chmod 600 /tmp/backend-secret.backup.*.yaml

# patch (apply 아님 — last-applied-configuration 에 평문 박히는 이슈 회피)
kubectl -n senior-album patch secret backend-secret \
  --type=merge \
  -p "$(cat <<EOF
{"stringData": {"KAKAO_CLIENT_SECRET": "${NEW_KAKAO_SECRET}"}}
EOF
)"

# 적용 확인
kubectl -n senior-album get secret backend-secret \
  -o jsonpath='{.data.KAKAO_CLIENT_SECRET}' | base64 -d; echo
# → $NEW_KAKAO_SECRET 와 일치
```

---

## 3. album-deploy SealedSecret 갱신

```bash
cd /Users/thekim123/workspace/senior-album/album-deploy

kubectl -n senior-album create secret generic backend-secret \
  --from-literal=KAKAO_CLIENT_SECRET="${NEW_KAKAO_SECRET}" \
  --dry-run=client -o yaml | \
  kubeseal --controller-namespace kube-system --controller-name sealed-secrets \
           --format yaml --merge-into k8s/sealed/backend-secret.yaml

git diff k8s/sealed/backend-secret.yaml   # KAKAO_CLIENT_SECRET 라인만 바뀌어야 함
git add k8s/sealed/backend-secret.yaml
git commit -m "security: rotate KAKAO_CLIENT_SECRET in backend SealedSecret (roadmap#87)"
git push
```

> controller name 이 `sealed-secrets-controller` 인 클러스터도 있음 (MinIO §10-2 사례). `kubeseal --fetch-cert` 가 실패하면 실제 controller 이름을 `kubectl -n kube-system get deploy` 로 확인 후 교체.

---

## 4. backend 재시작

```bash
kubectl -n senior-album rollout restart deployment/backend
kubectl -n senior-album rollout status deployment/backend --timeout=120s
```

MinIO 와 달리 재시작 대상은 backend 하나. `get_settings()` 캐시 초기화 목적.

---

## 5. Smoke test

```bash
# 5-1. backend 로그에 카카오 OAuth 에러 없는지
kubectl -n senior-album logs deployment/backend --tail=100 | \
  grep -iE "kakao|invalid_client|invalid_grant|unauthorized_client" || echo "clean"

# 5-2. 실제 로그인 플로우 (브라우저)
#   - 현재 로그인 세션 로그아웃
#   - /auth/kakao/login 진입 → 카카오 계정 로그인 → 콜백 → 토큰 발급
#   - 사진 리스트 정상 로드 확인
```

실패 시 §7 롤백.

---

## 6. 백업 파일 정리

```bash
shred -u /tmp/backend-secret.backup.*.yaml 2>/dev/null || rm -f /tmp/backend-secret.backup.*.yaml
unset NEW_KAKAO_SECRET
```

---

## 7. 롤백 절차

카카오 재발급은 콘솔 UI 에서 "**코드 생성**" 을 다시 누르면 또 새로운 값이 나오는데, 이 경우 이전 값은 복구 불가. 롤백 ≠ 옛 값 복원이 아니라 **또 새로 발급받고 §2~§4 재수행**.

만약 §5 smoke test 실패 원인이 secret 자체가 아니라면 (예: 앱 레벨 설정, callback URL 불일치 등):

```bash
# 백업으로 복원 — 단, 옛 client_secret 은 이미 무효. 로그인은 여전히 실패.
kubectl -n senior-album replace -f /tmp/backend-secret.backup.<timestamp>.yaml
kubectl -n senior-album rollout restart deployment/backend
```

즉 롤백은 "설정 되돌리기" 용도일 뿐, 카카오 로그인 복구 효과는 없다. 재발급은 **되돌릴 수 없는 변경**이므로 §1 실행 전에 §0 체크리스트를 반드시 완료.

---

## 8. 완료 처리

- [ ] 이슈 #87 에 체크리스트 업데이트 (KAKAO 항목 체크)
- [ ] album-deploy PR 머지 확인
- [ ] 프로젝트 보드 #87 상태 유지 (`In progress`) — POSTGRES 남음

다음 단계: `POSTGRES_PASSWORD` 회전 — 현재 구조 제약 때문에 런북 이전에 **구조 변경 선행** 필요 (`DATABASE_URL` 이 ConfigMap 평문에 박혀있고, postgres PV 데이터는 init env 를 무시). 별도 설계 + PR 작업으로 분리.
