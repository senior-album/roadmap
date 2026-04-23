# 맥미니 재부팅 런북

**대상**: 전체 senior-album 운영 스택이 돌아가는 맥미니 (k3d/k3s 호스트)
**관련**: T-045, 운영 기본 인프라 복구
**예상 소요**: 5~10분 (정상 케이스)
**다운타임**: 재부팅 시작 ~ 모든 파드 Ready 까지. Cloudflare Tunnel 재연결 포함 통상 5분.

---

## 0. 재부팅 전 (예정된 경우)

```bash
# 1) 진행 중 작업 확인
kubectl -n senior-album get pods
kubectl -n senior-album get jobs -o wide | head

# 2) 오래 걸리는 Job (예: face 재분류 backfill) 있으면 완료 대기 or 취소
# 3) 현재 이미지 태그 기록 (롤백 기준선)
kubectl -n senior-album get deploy -o=jsonpath='{range .items[*]}{.metadata.name}{" "}{.spec.template.spec.containers[0].image}{"\n"}{end}'
```

긴급 재부팅(전원 문제 등) 인 경우 이 단계 생략 → §2 부터.

---

## 1. 재부팅 실행

```bash
sudo shutdown -r now
```

---

## 2. 부팅 후 클러스터 상태 확인

맥미니 로그인 후:

```bash
# k3d 클러스터 인식
kubectl config current-context
kubectl get nodes   # STATUS=Ready

# 시스템 네임스페이스
kubectl -n kube-system get pods
kubectl -n sealed-secrets get pods   # SealedSecrets controller 확인
```

- **Node NotReady**: `systemctl status k3s` 또는 Docker Desktop 기동 확인 (k3d 사용 시 Docker 기동이 선결)
- **시스템 파드 CrashLoopBackOff**: 재부팅 직후엔 순차 기동 중일 수 있음, 2~3분 대기 후 재확인

---

## 3. 애플리케이션 파드 상태

```bash
kubectl -n senior-album get pods
# 기대 상태: postgres / redis / opensearch / minio / backend / frontend 모두 Running + Ready
```

흔한 이슈:

- **postgres CrashLoopBackOff** — PV mount 문제. `kubectl -n senior-album describe pod <postgres-pod>` 로 이벤트 확인. 해결 안 되면 §4 DB 복구 런북.
- **opensearch 기동 실패** — JVM heap 부족 (맥미니 RAM 상황). `kubectl -n senior-album logs <opensearch-pod>` 확인.
- **backend CrashLoopBackOff** — 의존 서비스 (postgres/redis/opensearch) 가 아직 안 올라왔을 가능성. 재기동 대기.

```bash
# 여전히 Ready 안 되면 파드 재시작
kubectl -n senior-album delete pod -l app=<서비스명>
```

---

## 4. Cloudflare Tunnel 재연결

```bash
kubectl -n senior-album get pods -l app=cloudflared
kubectl -n senior-album logs -l app=cloudflared --tail=30
# → "Registered tunnel connection" 라인 확인
```

`Connection refused` 가 반복되면 tunnel token 확인 필요 (SealedSecret `cloudflared-token`).

---

## 5. 외부 도메인 검증

```bash
# thekim123.info 응답 확인 (프런트 엔드)
curl -I https://thekim123.info/

# /api 프록시 경로 (백엔드 health)
curl https://thekim123.info/api/health
# → {"status":"ok"} 기대
```

---

## 6. 실행 완료

- [ ] 모든 senior-album 파드 Ready
- [ ] Cloudflare Tunnel 재연결 확인
- [ ] 외부 도메인 200 응답
- [ ] 애플리케이션 레벨 smoke (로그인, 사진 1장 업로드) 1회

---

## 7. 흔한 사후 이슈

- **첫 얼굴 인식 요청이 느림** — InsightFace 모델 워밍업 필요. 수 초~수십 초 후 정상.
- **Albumentations 버전 체크로 liveness timeout** — Dockerfile 에 `ENV NO_ALBUMENTATIONS_UPDATE=1` 박혀있는지 확인 (PR album-backend#21 이후 해결됨).
- **백엔드가 qemu 에뮬 중** — `kubectl -n senior-album exec deploy/backend -- uname -m` → `aarch64` 여야 정상 (PR #19 이후). `x86_64` 면 옛 이미지 사용 중, 이미지 태그 확인.
