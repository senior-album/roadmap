# Senior Album — 내부 SLO 문서

**상태**: 초안 v1. 실사용자가 생기기 전의 방어적 기준선.
**관련 이슈**: T-046 (roadmap#26)
**갱신 주기**: 분기. 실사용 트래픽 확보 후 숫자 재조정.

---

## 0. 이 문서의 목적

외부 고객 약정(SLA) 아님. 내부 개발/운영이 **"무엇을 잴 것이고 언제 알림이 울려야 하는가"** 를 합의하기 위한 기준선. SLO 숫자는 현재 인프라(맥미니 단일 k3d) 특성을 반영한 **보수적** 값이며, Closed Beta (roadmap#62) 이후 실트래픽으로 재보정.

### 용어
- **SLI** (Service Level Indicator): 실제 측정하는 신호
- **SLO** (Service Level Objective): SLI 가 충족해야 할 목표
- **Error budget**: `100% - SLO`. 이 예산 범위 내 장애는 용인 — 개발 속도와 안정성의 트레이드오프 완충지.

---

## 1. 서비스 인벤토리

현재 운영 중인 구성요소:

| 서비스       | 유형        | Deployment                   | 외부 노출                            |
|--------------|-------------|------------------------------|--------------------------------------|
| backend      | FastAPI API | `deploy/backend`             | `https://thekim123.info/api/*`       |
| frontend     | Vite+nginx  | `deploy/frontend`            | `https://thekim123.info/*`           |
| postgres     | 내부 DB     | `deploy/postgres`            | 내부 전용                            |
| minio        | S3 API      | `deploy/minio`               | 내부 전용 (presigned URL 은 외부 체인) |
| opensearch   | kNN 검색    | `deploy/opensearch`          | 내부 전용                            |
| redis        | 캐시/rate   | `deploy/redis`               | 내부 전용                            |
| cloudflared  | 터널        | `deploy/cloudflared`         | Cloudflare ↔ 맥미니 브리지            |

관찰 주체: 현재는 수동 + 로그. **T-040 (Uptime Kuma)** 머지되면 UI 기반 가시화. **T-042 (Loki+Grafana)** 이후 로그 기반 SLI 자동 집계.

---

## 2. SLO 매트릭스

### 2-1. backend API (사용자 대면 최우선)

| SLI                  | 측정 방식                                         | SLO (30일)        | Error budget |
|----------------------|---------------------------------------------------|--------------------|--------------|
| **가용성**           | `/api/health` 2xx 응답률 (external check)          | **99.0%**          | 7.2시간/월   |
| **읽기 지연**        | `GET /api/photos?...` p95 latency                  | **< 500ms**        | 1.5%         |
| **쓰기 지연**        | `POST /api/photos` p95 latency (업로드 제외 본체)  | **< 1.5s**         | 1.5%         |
| **쓰기 성공률**      | `POST /api/photos` 2xx 응답률 (4xx 는 제외)        | **99.5%**          | 3.6시간/월   |
| **얼굴 분류 성공**   | register-face / reclassify 비동기 Job 성공률       | **98%**            | 14.4시간/월  |

**왜 99.0% 가용성인가:**
- 맥미니 단일 호스트 + 가정용 인터넷. 전원/네트워크 장애 1~2회/월 발생 가능. 99.9%는 비현실적.
- Closed Beta (<10 시설) 단계에서 99.0% 로도 비즈니스 영향 제한적.
- 클라우드 이관 (T-220) 이후 99.9% 재검토.

### 2-2. frontend (정적 자산 + SPA)

| SLI          | 측정                                      | SLO         |
|--------------|-------------------------------------------|-------------|
| 가용성       | `https://thekim123.info/` 2xx (Cloudflare + origin) | **99.5%**   |
| 로드 시간    | `index.html` TTFB p95 (Cloudflare edge)   | **< 300ms** |

Cloudflare edge 캐시 덕에 origin 장애 중에도 일부 응답 가능 — backend 보다 SLO 여유.

### 2-3. 비동기 작업

| 작업                     | SLO                                       |
|--------------------------|-------------------------------------------|
| 사진 업로드→얼굴 인식 완료 | p95 < 5분 (register-face 큐)              |
| reclassify_unmatched     | 전체 풀 1회 처리 p95 < 30분               |

현재 `photo-worker` 단일 인스턴스 기반. 큐 밀림이 이 SLI 의 주 위반 요인.

### 2-4. 내부 데이터 저장소

| 저장소     | SLI                               | SLO           |
|------------|-----------------------------------|---------------|
| postgres   | backend→postgres 쿼리 p95         | **< 100ms**   |
| opensearch | kNN 유사도 검색 p95               | **< 800ms**   |
| minio      | presigned URL GET (backend 관점)  | **< 200ms**   |

### 2-5. 데이터 복구성 (RPO / RTO)

| 지표                     | 목표                                                           |
|--------------------------|----------------------------------------------------------------|
| RPO (데이터 손실 허용)   | **< 24시간** (일 1회 백업: T-043 pg, T-044 MinIO 이미 도입)    |
| RTO (복구까지 소요 시간) | **< 2시간** (runbook `postgres-restore.md` 기반)               |

---

## 3. 알림(페이징) 기준

"알림 = SLO 소진 페이스가 비정상" 에 한정. 매 장애마다 울리지 않음.

### 3-1. 즉시(Page)

- backend `/api/health` 가 5분 연속 2xx 아님
- 60분 에러 예산 소진 속도가 14.4x 이상 (1시간에 월 예산 소진 페이스)
- postgres / opensearch 파드 CrashLoopBackOff 지속

### 3-2. 디지털(티켓/채팅)

- 월 에러 예산 50% 소진
- backoff pattern (같은 에러 반복) 감지
- 인증서 만료 < 14일 (T-040 Uptime Kuma 로 감시)

---

## 4. 관측 스택 구현 로드맵 (현재 → 목표)

| 항목                 | 현재              | 다음 단계                             | 참조 이슈 |
|----------------------|-------------------|---------------------------------------|-----------|
| 외형 HTTP 모니터     | 없음              | Uptime Kuma 4개 모니터                | T-040     |
| 로그 수집            | `kubectl logs` 만 | Loki + Promtail                       | T-042     |
| 메트릭 / APM         | 없음              | OpenTelemetry + Grafana Cloud         | T-122     |
| 알림 채널            | ✅ Discord 웹훅   | (Uptime Kuma 외형 + 백엔드 영구 실패) | T-041     |
| 구조화 로그          | ✅ (T-123)        | Loki json stage 로 label 추출          | (완료)    |

위 중 어느 하나라도 미구현 상태에선 해당 SLI 를 "수동 관측" 으로 취급. 자동 위반 감지 전까진 이 SLO 는 운영 체크리스트 수준.

---

## 5. 재평가 트리거

다음 중 하나 발생 시 이 문서 재검토:

- Closed Beta (roadmap#62) 개시
- 첫 유료 고객 계약
- 맥미니 → 클라우드 이관 (T-220)
- 분기 1회 정기 검토
- 같은 SLI 로 월 2회 이상 알림 페이지

---

## 6. 의도적으로 포함하지 않은 것

- **RTO < 15분** 수준의 고가용성 목표 — 현 인프라로 비현실적, 과도한 비용
- **사용자별 latency** (per-user SLI) — 사용자 수 적어 의미 없음
- **외부 의존성** (카카오 OAuth, Cloudflare) SLI — Cloudflare 대시보드 + 카카오 공개 status 참조로 충분
- **Frontend JS error rate** — Sentry 등 도입 전까진 잴 수단 없음

이 항목들은 "고려했으나 현 단계 안 함" 으로 박아둬서 후속 논의에서 "왜 안 했지?" 재개가 없도록.
