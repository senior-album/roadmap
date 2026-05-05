# T-041 — Uptime Kuma + 백엔드 → Discord 운영 알림 셋업

senior-album 운영 채널 (Discord) 로 장애/이상 이벤트를 푸시하기 위한 셋업 절차.

```
┌──────────────────┐       ┌──────────────────┐
│  Uptime Kuma     │  HTTP │   Discord        │
│  (T-040)         │ ────→ │   #ops 채널      │
│  외형 모니터      │ webhook                  │
└──────────────────┘       └──────────────────┘
                              ↑
                              │ webhook
                              │
┌──────────────────┐          │
│  album-backend   │ ─────────┘
│  photo_worker    │ (DISCORD_OPS_WEBHOOK_URL)
│  영구 실패 알림   │
└──────────────────┘
```

두 컴포넌트가 같은 웹훅 URL 을 공유한다:
- **Uptime Kuma** — 외형 monitor 다운/cert 만료 등 (T-040 의 4 모니터)
- **album-backend** — 사진 처리 작업 retry 소진, 운영자 test-alert 엔드포인트

## 0. 사전 준비

- Discord 서버 + 운영 알림 채널 (예: `#senior-album-ops`) 생성 — 사용자 본인 작업
- 클러스터에 `kubeseal` 가 설치되어 있고 controller public cert 가 fetch 가능
  (기존 SealedSecret 들이 동작 중이면 OK)

## 1. Discord 웹훅 URL 발급 (수동)

1. 디스코드 데스크톱/웹에서 운영 알림용 채널 → 톱니 아이콘 (채널 편집)
2. **연동 (Integrations)** → **웹후크 (Webhooks)** → **새 웹후크 (New Webhook)**
3. 이름: `Senior Album Ops` 정도, 아바타는 선택
4. **웹후크 URL 복사 (Copy Webhook URL)** — 이 URL **자체가 시크릿** (path 마지막에
   토큰이 들어있음). 슬랙·문서·티켓·Git 어디에도 평문으로 붙이지 말 것

> ⚠️  URL 노출 시 누구나 그 채널에 메시지를 쏠 수 있다. 노출됐다고 의심되면
> 즉시 디스코드 UI 에서 해당 웹훅을 삭제하고 새로 만든 뒤 SealedSecret 재봉인.

## 2. SealedSecret 봉인 + 커밋

`backend-secret` 의 `encryptedData.DISCORD_OPS_WEBHOOK_URL` 필드만 추가하는
방식. 다른 키들은 그대로 둔다 (`kubeseal --raw` 는 단일 값을 봉인).

### 2-1. URL 을 봉인된 블롭으로 변환

로컬 머신 (kubeseal 가 클러스터의 controller public cert 를 fetch 할 수 있는
환경) 에서:

```bash
# URL 을 변수에 넣고 (히스토리에 남기지 않으려면 read -s 사용)
read -rs DISCORD_URL
# 웹후크 URL 붙여넣기 + Enter

# kubeseal --raw 로 단일 값 봉인.
# --name 은 SealedSecret 의 metadata.name, --namespace 는 namespace.
echo -n "$DISCORD_URL" | kubeseal \
  --raw \
  --namespace senior-album \
  --name backend-secret \
  --controller-name sealed-secrets-controller \
  --controller-namespace kube-system

# 표준출력으로 base64 봉인 블롭 (AgB... 로 시작) 1줄 출력됨.
unset DISCORD_URL
```

> Windows PowerShell 의 경우 `read -rs` 대신 `$DISCORD_URL = Read-Host -AsSecureString`
> 후 평문 변환 → echo 파이프 패턴이 필요. mac/Linux 에서 봉인하는 게 편하다.

### 2-2. backend-secret.yaml 에 한 줄 추가

`album-deploy/k8s/sealed/backend-secret.yaml` 의 `spec.encryptedData` 아래에
알파벳 순서를 유지하며 추가:

```yaml
spec:
  encryptedData:
    COOLSMS_API_KEY: AgAN...
    COOLSMS_API_SECRET: AgAG...
    COOLSMS_FROM_NUMBER: AgCw...
    DISCORD_OPS_WEBHOOK_URL: AgB...   # ← 2-1 결과 붙여넣기
    JWT_REFRESH_SECRET: AgCB...
    ...
```

### 2-3. 커밋 + 머지

```
chore(secrets): T-041 — backend-secret 에 DISCORD_OPS_WEBHOOK_URL 추가
```

머지 후 ArgoCD sync — 기존 backend pod 는 envvar 가 부착돼야 의미 있으므로
rollout (이미지 변경 없으면 `kubectl rollout restart deploy/backend -n senior-album`).

## 3. Uptime Kuma UI 에서 알림 채널 등록

Kuma 는 알림 설정을 SQLite (`/app/data/kuma.db`) 에 저장한다 — k8s 매니페스트
로 바인딩 불가, **UI 에서 한 번** 등록한다.

### 3-1. Kuma UI 접속

```bash
kubectl -n senior-album port-forward svc/uptime-kuma 3001:3001
# 브라우저: http://localhost:3001
```

### 3-2. Notification 추가

좌측 사이드바 → **Settings** → **Notifications** → **Setup Notification**
(또는 모니터 편집 화면에서도 추가 가능)

| 필드 | 값 |
|---|---|
| Notification Type | **Discord** |
| Friendly Name | `Discord #senior-album-ops` |
| Discord Webhook URL | (1 단계에서 발급한 URL — Kuma DB 에만 저장됨, 외부 노출 X) |
| Bot Display Name | `Uptime Kuma` (기본값 OK) |
| Default enabled | ✅ (모든 모니터에 기본 적용) |
| Apply on all existing monitors | ✅ |

**Test** 버튼으로 채널에 테스트 핑이 도착하는지 확인 → **Save**.

### 3-3. 모니터별 적용 확인 (기존 4개)

T-040 에서 만든 frontend / backend / argocd / cloudflared 모니터 각각에
"Discord #senior-album-ops" 채널이 체크되어 있어야 한다. 3-2 에서 "Apply on
all existing monitors" 를 켰으면 자동 적용됨.

## 4. 백엔드 알림 동작 검증

### 4-1. test-alert 엔드포인트 (운영자 전용)

운영자 계정으로 로그인 후:

```bash
curl -X POST https://<API_HOST>/api/admin/ops/test-alert \
  -b "access_token=$ACCESS_TOKEN" \
  -H "Accept: application/json"
```

기대 응답:

```json
{ "configured": true, "sent": true }
```

Discord 채널에는 `Senior Album ops alert — test` 제목의 info-color (파랑)
embed 가 도착한다. 송출 자체와 별개로 `AdminAuditLog` 에
`action=ops_test_alert` 로 호출 이력 1 row 가 적힌다 (`configured` /`sent` 결과는
detail 에 기록).

### 4-2. photo_worker 영구 실패 알림 (자연 발생)

다음 시나리오에서 Discord 채널에 error-color (빨강) 알림이 자동 발송된다:

- `PhotoProcessingJob` 의 `photo_id` 가 dangling (e.g. 사진이 삭제됨) — `Photo not found`
- 얼굴 인식 모델 미가용 (모델 파일 누락/로드 실패) — `model not available`
- 업로드 후 처리 중 예외가 `max_retries` 회 재시도까지 지속 — `retry exhausted (N/M)`

알림 payload 의 `fields` 에 `job_id` / `photo_id` / `facility_id` / `retry_count`
/ `reason` 이 들어가므로 채널에서 바로 grep 추적 가능. 평문 PII (입소자 이름
등) 는 포함되지 않는다.

## 5. 운영 시 주의

### 알림 폭주 (Discord rate limit)
- 디스코드 웹훅은 채널당 ~30/분 정도에서 429 를 친다.
- `discord_notifier` 는 429 의 `Retry-After` 를 honor + 3 회까지 재시도, 그 후
  swallow (알림 실패가 비즈니스 로직을 막지 않게).
- 100+ photo 가 동시에 영구 실패하는 시나리오 (예: 모델 파일 통째로 사라짐)
  에서는 일부 알림이 누락될 수 있음 — 동일 사고면 첫 알림만 잡혀도 충분.

### URL rotation
- Discord 웹훅은 만료가 없지만, 실수로 PR/로그/티켓에 노출 → 즉시 폐기 후
  재발급. 절차는 1 → 2-1 → 2-2 → 2-3 → 3-2 (Notification 재설정).
- backend-secret 의 다른 키를 건드리지 않도록 주의 (특히 `RESIDENT_PII_KEK` /
  `RESIDENT_NAME_HMAC_KEY` 는 절대 재생성 X — 기존 암호화된 데이터가 모두
  복호 불가능해짐).

### 채널 분리 (운영 vs 정보)
- 현재는 단일 웹훅에 error / warning / info 레벨이 모두 들어간다 (embed 색상으로
  구분). 정보성 알림이 너무 많아지면 별도 채널 + 별도 SealedSecret 키
  (`DISCORD_OPS_WEBHOOK_URL_INFO` 등) 분리를 검토.

## 관련 자산

- `album-deploy/k8s/uptime-kuma.yaml` — Kuma Deployment + PVC (T-040)
- `album-deploy/k8s/sealed/backend-secret.yaml` — DISCORD_OPS_WEBHOOK_URL 봉인 위치
- `src/backend/app/services/discord_notifier.py` — 백엔드 송출 모듈
- `src/backend/app/services/photo_worker.py::_notify_job_failed` — 자동 알림 호출
- `src/backend/app/api/admin.py` — `/admin/ops/test-alert` 엔드포인트
- `roadmap/docs/slo.md` — 알림 채널 row (T-041)
