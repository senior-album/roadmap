# Senior Album — 칸반보드

**98개 할일** · P0(12) · P1(28) · P2(40) · P3(18)
근거: `reports/01_security_analysis.md`, `02_market_viability.md`, `03_operations_playbook.md`

> 체크박스를 클릭해 진척을 표시하거나, GitHub Projects 칸반 뷰로 드래그하세요.

---

## 🔴 P0 — Critical (1~2주, 베타 오픈 전 필수)

### security (11)

- [x] **T-001** JWT_SECRET 기본값 제거 → `.env` 필수화, 시크릿 재생성 `[area:security]`
- [x] **T-002** `cloudflared.yaml` TUNNEL_TOKEN 매니페스트에서 제거 + 과거 git 히스토리 purge `[area:security]`
- [x] **T-003** Resident PII (`name`, `birth_date`, `medical_notes`) envelope encryption (KEK + 행별 DEK + AES-256-GCM) + name blind index. 5 서브이슈 분할 진행. `User.phone` 등 phone 도메인 PII 는 T-320 으로 분리. `[area:security]`
- [x] **T-004** OpenSearch 얼굴 임베딩 인덱스 전송·저장 암호화 옵션 적용 `[area:security]`
- [x] **T-005** 파일 업로드 검증 강화: 20MB 크기 + python-magic MIME + 확장자 화이트리스트 + Pillow 디코딩 확인 `[area:security]`
- [x] **T-006** 카카오 OAuth `state` 파라미터 생성·검증 (CSRF 방어) `[area:security]`
- [x] **T-007** 업로드·공유링크·얼굴매칭 엔드포인트 rate limit 추가 `[area:security]`
- [x] **T-008** 공유 링크 토큰 `secrets.token_urlsafe(32)` 통일 + 만료 검증 감사 `[area:security]`
- [x] **T-009** JWT_EXPIRE_MINUTES 60 축소 + refresh 토큰 구조 설계 `[area:security]`
- [x] **T-010** CORS `allow_methods`/`allow_headers` 명시적 화이트리스트 `[area:security]`
- [x] **T-011** Presigned URL(1h) vs `share_expires_at`(72h) 정책 통일 — 접근 시 매회 재발급 `[area:security]`
- [ ] **T-320** phone 도메인 PII envelope encryption + blind-index — T-003 후속, 확장 스코프. 대상 4 컬럼: `User.phone` (UNIQUE → bi 이전), `Facility.phone`, `Invitation.phone` (T-149), `PhoneClaimReport.claimed_phone`. KEK 는 `RESIDENT_PII_KEK` 재사용, blind-index 키는 `USER_PHONE_HMAC_KEY` 신규. 5 서브이슈 분할 진행 (T-320-1 인프라 → -2 마이그+모델 → -3 lookup 흐름 → -4 외부 발송/어드민 → -5 정리·테스트). 마이그는 `User.phone` UNIQUE 이전 시 ROW_NUMBER dedup 동반. `[area:security]` (roadmap#167, roadmap#256, roadmap#257, roadmap#258, roadmap#259, roadmap#260)

---

## 🟠 P1 — High (2주~2개월, Closed Beta 운영 기반)

### legal (5) — GA 전 필수

- [x] **T-020** 보호자 가입 UI에 이용약관·개인정보처리방침·민감정보 3단 동의 + 동의 로그 DB 기록 `[area:legal]`
- [x] **T-021** 이용약관 2종 초안 (시설 유료 / 보호자 무료) `[area:legal]`
- [x] **T-022** 개인정보처리방침 + `/privacy` 페이지 + 푸터 링크 `[area:legal]`
- [x] **T-023** 개인정보 처리 위탁 계약서 템플릿 (Senior Album = 수탁자) `[area:legal]`
- [x] **T-024** 민감정보(얼굴·건강정보) 별도 처리 동의서 `[area:legal]`

### product (3)

- [x] **T-030** 입소자 CSV 엑셀 일괄 import (100명 단위, 주민번호 뒷자리 생략 템플릿) `[area:product]`
- [x] **T-031** 시설장 관리자 대시보드 강화 — 초대 현황, 미연결 어르신, 미처리 사진, 얼굴 미등록 경고 `[area:product]`
- [x] **T-032** 보호자 초대 QR 포스터 PDF 자동 생성 `[area:product]`

### ops (7)

- [x] **T-040** Uptime Kuma 셀프호스트 + 4개 서비스 ping (frontend/backend/argocd/cloudflared) `[area:ops]`
- [x] **T-041** Discord 웹훅 장애 알림 연결 (Uptime Kuma + 백엔드 photo_worker 영구 실패) `[area:ops]`
- [x] **T-042** Loki + Grafana 로그 수집 + 일 1회 S3/R2 export 7일 보관 `[area:ops]`
- [x] **T-043** PostgreSQL `pg_dump` 일 1회 CronJob → Cloudflare R2 업로드 `[area:ops]`
- [x] **T-044** MinIO 업로드 사진 `mc mirror` CronJob 백업 `[area:ops]`
- [x] **T-045** 런북 4종 작성 (맥미니 재부팅 / DB 복구 / 빌드 실패 롤백 / 인증서 만료) `[area:ops]`
- [x] **T-046** SLO 내부 문서화 (가동률 99.0%, 응답 <500ms, RTO 4h, RPO 24h) `[area:ops]`

### security (7)

- [x] **T-050** Sealed Secrets controller 설치 + 모든 secret 매니페스트 마이그레이션 `[area:security]`
- [x] **T-051** 이미지 재인코딩 파이프라인 — thumbnail 생성 시 metadata strip `[area:security]`
- [x] **T-052** NetworkPolicy 기본 deny + 허용 서비스만 allow `[area:security]` (album-deploy#10)
  - [ ] ~~**T-052-1** k3d CNI 교체 (flannel → Calico)~~ `[deferred]` — 클라우드 이관 (T-220) 시 일괄 처리. k3d 단일 노드 재생성 30–60분 다운타임 vs NetworkPolicy enforce ROI 부족. runbook 은 보존: album-deploy `docs/CNI_MIGRATION.md`. (roadmap#158)
- [x] **T-053** Dockerfile 베이스 이미지 digest pin (`python:3.11.9-slim-bookworm@sha256:…`) `[area:security]`
- [x] **T-054** bcrypt rounds=12 명시 + 로그인 시 점진 재해싱 `[area:security]`
- [x] **T-055** JWT_SECRET Sealed Secrets 또는 SOPS+age 관리 + rolling key 구조 `[area:security]` (album-backend#123, album-deploy#32)
- [x] **T-056** 직원 가입 승인 게이트 — register_staff 자동 활성화 차단, 시설장(또는 `facility:staff:approve` 위임) 승인 필요. 거부는 soft delete (재신청 차단) `[area:security]` (album-backend#118, album-frontend#58)

### biz (7)

- [ ] **T-060** 개인사업자 등록 (매출 8천만원 시 일반과세자 전환 계획) `[area:biz]`
- [ ] ~~**T-061** 카카오톡 비즈니스 채널 개설 + 알림톡 연동~~ `[area:biz]` `[wontfix]` — 비즈채널 운영 부담 + 대행사 계약 (NHN Cloud 등) 비용 vs T-304 manual_share UX (deeplink) + T-307 CoolSMS 자동 발송 으로 충분. 알림톡 템플릿 검수 단계 생략. 시설 수 대폭 확장 시 재검토 (별도 티켓).
- [ ] **T-062** 부모님 시설 케이스 스터디 영상 제작 (시설장 인터뷰) `[area:biz]`
- [ ] **T-063** 주변 요양시설 10곳 리스트업 + 개별 콜드 메시지 `[area:biz]`
- [ ] **T-064** 15분 데모 방문 5회 이상 `[area:biz]`
- [ ] **T-065** 지자체 스마트요양 시범사업 1건 신청 `[area:biz]` `[area:funding]`
- [ ] **T-066** 요양뉴스/실버경제 기고 또는 보도자료 1건 `[area:biz]`

---

## 🟡 P2 — Medium (2~6개월, Paid Beta → GA, MRR 200만)

### security (8)

- [x] **T-100** 업로드 경로 Path Traversal 방지 (`storage.py::upload_file`에서 `facility_id` sanitize) `[area:security]`
- [x] **T-101** PhotoAuditLog 범위 확대 — 조회·다운로드·공유링크 사용 `[area:security]`
- [x] **T-102** 관리자 특권 행위 감사 로그 (보호자 승인, 입소자 삭제) `[area:security]`
- [x] **T-103** 로그에서 PII(email·resident name) 마스킹 `[area:security]`
- [x] **T-104** 500 에러 응답 스택트레이스 누출 방지 + DEBUG 프로덕션 off `[area:security]`
- [x] **T-105** `verify_facility_access` JWT만 신뢰 X, DB 실시간 재검증 `[area:security]`
- [x] **T-106** 얼굴 인식 워커 job queue 길이 제한 `[area:security]`
- [x] **T-107** OpenSearch kNN 쿼리 `size` 상한 + 페이지네이션 `[area:security]`

### ops (12)

- [x] **T-120** Alembic 도입 → `DDL_AUTO=create` / `_add_missing_columns` 제거 + CI `alembic upgrade head` `[area:ops]`
- [ ] **T-121** 백업 복구 리허설 분기 1회 `[area:ops]`
- [x] **T-122** OpenTelemetry 자동 계측 + 셀프호스트 Tempo (traces only; metrics/Prometheus 는 후속). 외부 SaaS 가입 회피 — 기존 맥미니 Grafana/Loki 인프라 재사용. backend SDK 가 endpoint 미설정 시 silent no-op 이라 두 PR 안전 분리. trace_id 가 JSON 로그에도 주입돼 Loki↔Tempo 양방향 점프. `[area:ops]` (album-backend#138, album-deploy#38)
- [x] **T-123** 구조화 로그 (JSON logging) 전환 `[area:ops]`
- [x] **T-124** 핵심 로직 테스트 커버리지 70% (JWT, face_recognition, 업로드 플로우) `[area:ops]`
- [x] **T-125** Dependabot 의존성 업데이트 + pip-audit `[area:ops]`
- [x] **T-126** 업로드 스토리지 PV 전환 (`emptyDir` 제거) `[area:ops]`
- [x] **T-127** Loki/Grafana 운영 가시성 개선 (대시보드 + 레벨 파싱 + 노이즈 필터) `[area:ops]`
- [x] **T-128** 테스트 envvar 캐싱 회귀 — `RESIDENT_PII_KEK` setdefault 값 표준화 (base64 32B) + `_kek()` lru_cache 우회 fixture `[area:ops]` (album-backend#115)
- [x] **T-129** ArgoCD Notifications → Discord 푸시 (sync started/succeeded/failed, OutOfSync 5min, Degraded). T-041 따라가는 follow-up — Kuma 의 HTTP up/down 으론 sync 결과 검증 불가. `[area:ops]` (album-deploy#24, album-deploy#26)
- [x] **T-130** backup CronJob (`minio-backup` / `postgres-backup`) 의 `mc mb --ignore-existing` 호출 제거 — R2 object-only 토큰이라 Access Denied 로 5일째 매일 backup 실패. T-129 가 처음 노출시킨 사고. T-043/T-044 follow-up. `[area:ops]` (album-deploy#28)
- [x] **T-131** `cloudflared-secret` SealedSecret 재봉인 — 셋업 당시 평문 Secret 이 SealedSecret 보다 늦게 apply 돼서 ownership 못 잡혔고, unseal 결과가 cluster 실사용 token 과 달라 cloudflared pod 재시작 시 사이트 다운 위험. 백업 token 재봉인. T-130 검증 중 발견. `[area:ops]` `[area:security]` (album-deploy#31)

### product (11)

- [x] **T-140** 시설 관리자 모바일 앱 경량 버전 (현장 업로드) `[area:product]` (album-frontend#61, #64, #66, #67, #68, #70)
- [x] **T-141** 온보딩 체크리스트 자동화 (시설 코드 발급, 브랜딩, 직원 계정) `[area:product]` (album-frontend#60)
- [ ] **T-142** CSAT/NPS 수집 — Google Form 지원티켓 종료 시 자동 발송 `[area:product]`
- [x] **T-143** 시설 사용 지표 트렌드 그래프 페이지 (월별 업로드/매칭률/보호자 활동, T-150 권한 게이트) `[area:product]` (album-backend#114, album-frontend#55, album-frontend#57)
- [x] **T-144** 운영자 어드민 — 전체 유저 관리 (목록/필터/`is_active`·`is_admin`·`is_operator` 토글, `facility_id` 변경, AdminAuditLog 기록) `[area:product]`
- [x] **T-145** 운영자 어드민 — 전체 시설 관리 (목록 + 직원/입소자/사진 수, 시설 생성·수정. hard delete 미포함) `[area:product]`
- [x] **T-146** 운영자 어드민 — 보호자 승인 현황 전체 시설 across 뷰 (시설/상태 필터) `[area:product]`
- [x] **T-147** 운영자 어드민 — 사진 처리 큐 모니터링 (PhotoProcessingJob 상태/실패 retry) `[area:product]`
- [x] **T-148** 운영자 어드민 — 통계 대시보드 (시설/유저/사진/매칭률 카드 + 최근 가입·업로드 추세) `[area:product]`
- [x] **T-149** 보호자 초대 채널 정비 — "전화번호" → "문자메시지" 라벨 변경 + "가입 회원 초대" 신설 (회원 검색 → 인앱 알림 → 자동 Guardian 등록) `[area:product]`
- [x] **T-150** 시설 직원 메뉴 권한 위임 인프라 — UserPermission 모델 + permission_key 카탈로그 + 시설장 토글 UI + `require_permission` 의존성 `[area:product]` (album-backend#111, album-backend#113, album-frontend#54)

### biz (6)

- [ ] **T-160** 결제 연동 (나이스페이먼츠 / 아임포트) `[area:biz]`
- [ ] **T-161** 세금계산서 발행 자동화 `[area:biz]`
- [ ] **T-162** 가격 티어 확정 (Starter 9.9만 / Standard 19.9만 / Pro 29.9만 / Enterprise 협의) `[area:biz]`
- [ ] **T-163** Closed Beta 3~5개 시설 계약 (무료, 피드백 조건) `[area:biz]`
- [ ] **T-164** 상표 "Senior Album" 출원 (20~30만원) `[area:biz]` `[area:legal]`
- [ ] **T-165** 과기정통부 SaaS 전환 지원 신청 (최대 5천만원) `[area:biz]` `[area:funding]`

### legal (3)

- [ ] **T-180** 계약 종료 시 데이터 파기 요청 처리 플로우 `[area:legal]`
- [ ] **T-181** 개인정보 유출 72시간 신고 절차 문서화 `[area:legal]`
- [x] **T-182** 로그 보관 기간 정책 + 자동 파기 CronJob `[area:legal]` `[area:ops]` (album-backend#121, album-deploy#27, roadmap#211)

---

## 🟢 P3 — Low (6~12개월, 스케일·인증·조직)

### security (4)

- [ ] **T-200** etcd encryption at rest (RKE2 등 전환 검토) `[area:security]`
- [x] **T-201** Trivy 이미지 스캐너 CI + gitleaks 시크릿 감지 (truffleHog 는 gitleaks 와 중복으로 생략) `[area:security]` (album-backend a402e93 도입 + #35 strict, album-frontend 51584c0 도입). 도입 초기 Trivy 는 step-level soft-fail (`continue-on-error: true`), `.trivyignore` 정리 후 strict 전환은 별도 후속.
- [ ] **T-202** 침투 테스트 외주 (고객 2~3곳 확보 후) `[area:security]`
- [ ] **T-203** SSL/TLS 등급 A+ (Qualys SSL Labs) `[area:security]`

### ops (1)

- [ ] **T-220** 맥미니 → 클라우드 이관 검토 (AWS Lightsail / GCP / NHN Cloud) `[area:ops]`

### product (5)

- [ ] **T-240** 다국어 지원 (외국인 보호자) `[area:product]`
- [x] **T-241** 입소자 안부 일지 (거동·식사) `[area:product]` (album-backend#109, album-frontend#53)
- [ ] ~~**T-242** 보호자 간 메시지 기능~~ `[area:product]` `[wontfix]` — 외부 메신저(카톡 등)로 대체 가능, WS/푸시 인프라 ROI 부족
- [x] **T-243** 이벤트 캘린더 (생신·외출, 면회 제외) `[area:product]` (album-backend#119, album-frontend#59, album-backend#120, album-deploy#22)
  - [x] **T-243-4** 캘린더 birthday event 연중 표시 + D-7 알림 별도 dedup — D-7 게이트 뒤에 묶여 캘린더에 미래 생신이 안 보이던 UX 버그 수정. `events.birthday_notified_at` 컬럼 추가 (014). `[area:product]` (album-backend#127)
- [ ] **T-244** 이지케어·케어포 API 연동 제휴 `[area:product]` `[area:biz]`

### funding / hiring (4)

- [ ] **T-260** 엔젤 컨택 (Primer, Mashup Angels, Sopoong, Bonangels) `[area:funding]`
- [ ] **T-261** 법인 전환 (유료 고객 3개 초과 시) `[area:biz]`
- [ ] **T-262** TIPS R&D 신청 (엔젤 선투자 후, 최대 5억) `[area:funding]`
- [ ] **T-263** 첫 채용 — 공동창업자 or 파트타임 CS·마케팅 `[area:funding]`

### legal / 인증 (4)

- [ ] **T-280** SOC 2 Type I 준비 `[area:legal]`
- [ ] **T-281** ISMS-P 인증 (대형 요양병원 수주 가산점) `[area:legal]`
- [ ] **T-282** KMS 도입 (HashiCorp Vault / AWS KMS) `[area:security]` `[area:legal]`
- [ ] **T-283** PIA 개인정보 영향평가 (규모 확대 시) `[area:legal]`

---

## 🛠️ 운영 중 추가 — Live Issues (T-300+)

근거: 운영 중 발견된 버그·UX 개선·작은 enhancement. 보고서 기반 90개 외 트랙으로
관리하며, 통계표에는 포함하지 않는다.

### product (3)

- [x] **T-301** 보호자 갤러리 사진 확대보기(라이트박스) — 좌우 키/버튼 + 줌 + ESC `[area:product]` (album-frontend#51)
- [x] **T-302** 보호자 라이트박스 마우스 휠로 이전/다음 사진 이동 `[area:product]` (album-frontend#52)
- [x] **T-311** 사진 업로드 — 선택 즉시 업로드 (확정 버튼 제거). PhotoUploader 의 "선택된 파일" 미리보기 그리드 + "N개 사진 업로드" 버튼 제거. 업로드된 사진은 어차피 `is_public=false` 비공개로 들어가서 직원 publish 토글 전엔 노출 안 됨 → 확정 단계 마찰만 있음. 진행률은 dropzone 자체에 노출. 원래 T-310 으로 채번했으나 동일 시점 backend T-310 (birth_date 버그) 과 번호 충돌 — sweep PR (roadmap#239) 가 backend 만 정리하면서 본 항목이 누락. KANBAN 에서만 T-311 로 재정리, 코드 PR 의 commit 메시지/제목은 T-310 그대로 유지. `[area:frontend]` `[ux]` (roadmap#237, roadmap#238, album-frontend#69)
- [x] **T-312** 사진 업로드 진행 중 취소 — 100장 드래그 후 중단 수단 부재. T-311 즉시 업로드 + T-308 chunk 분할 (8장/40MB) 적용 후, `apiClient.uploadPhotos` 가 한 번 시작되면 모든 chunk 가 끝날 때까지 약 1분+ 진행 → 사용자가 잘못 끌었거나 자리 비울 때 정상 종료 못 함. `AbortController`/`AbortSignal` 을 axios chunk 호출에 전파해 즉시 abort, PhotoUploader 진행 표시 옆에 "취소" 버튼 노출. 취소 시 직전까지 업로드된 chunk 사진은 그대로 둠 (백엔드 호출 완료분) — 남은 파일은 "M장 건너뜀" 안내. `[area:frontend]` `[ux]` (album-frontend#73)
- [x] **T-313** 사진 관리 상세보기 라이트박스 + 태그 패널 통합 — PhotosPage 의 tagModal (자체 모달 + 작은 미리보기 + 태그 편집) 은 좌우 사진 이동 / ESC 닫기 / 콘텐츠 스크롤 부재로 보호자 갤러리 라이트박스 (T-301/T-302) 대비 동선이 끊김. `PhotoLightbox` 에 `sidebar` slot 추가 (md+ 우측 360px, 모바일 하단 50vh fill, 자체 overflow-y-auto + 휠 stopPropagation), tagModal 을 그 sidebar 로 이전. 좌우 키 / ESC / 휠 / 줌·팬 / 인덱스 내비는 라이트박스 기본 동작 그대로 활용. 사이드바엔 태그 추가/제거 + 공개·비공개 토글 (기존엔 그리드 호버 버튼에만 있던 것) + 사진 삭제. 사용자 보고. `[area:frontend]` `[ux]` (roadmap#243, album-frontend#74)

### bug (10)

- [x] **T-303** 이벤트 캘린더 메뉴 진입 시 500 에러 — T-243 후속. 사용자 재현 보고. `[area:backend]` `[bug]` (roadmap#218, album-backend#125)
- [x] **T-304** 보호자 초대 — 문자메시지/이메일 발송 실패 — T-149 후속. 자동 발송 코드 mock/미구현 → manual_share UX (직원이 invite_url 을 본인 SMS/메일/메신저 앱 deeplink 로 직접 공유). T-061 폐기와 함께 처리. `[area:product]` `[bug]` (album-backend#124, album-frontend#62)
- [x] **T-308** 사진 다중 업로드 batch 분할 — 30장+ 드래그 시 frontend nginx `client_max_body_size 50M` 초과로 413. `PhotoUploader` 가 선택 파일 전체를 한 multipart 요청으로 보냄 → 5~10장 chunk 로 분할 + 진행률 + 부분 실패 재시도. nginx 한도는 그대로 둠 (CF Tunnel 100MB / 백엔드 메모리 보호). 사용자 재현 보고. `[area:frontend]` `[bug]` (roadmap#232, album-frontend#65)
- [x] **T-309** prod 캘린더에 birthday backfill 미반영 — T-243-4 머지에도 cron 이 옛 코드로 동작. 원인: `album-backend/.github/workflows/ci.yml` 의 image-bump sed 가 `k8s/backend.yaml` 만 갱신, `k8s/backend-birthday-cron.yaml` / `k8s/backend-log-purge-cron.yaml` 의 hardcoded SHA (`d6eb948`, T-182 시점) 는 오래 전부터 stale. ci.yml 자동화를 `k8s/` 안의 album-backend 이미지 참조 일괄 갱신으로 확장 (재발 차단). prod 검증: ArgoCD sync + 1회 backfill job 으로 활성 입소자 birthday event 2건 생성 — 사용자 보고된 10/28 김강남 어르신 캘린더 표시 확인. `[area:ops]` `[area:product]` `[bug]` (album-backend#130, roadmap#234)
- [x] **T-310** 입소자 `birth_date` 빈 문자열이 그대로 envelope encrypt — 단건 `POST/PUT /residents` 가 `birth_date=""` 를 받으면 `_apply_pii_encryption` 의 `is not None` 가드를 통과해 빈 평문이 AES-GCM 으로 암호화돼 저장 (length=28 = nonce 12 + tag 16 + 0). cron 이 매일 `Invalid isoformat string: ''` decrypt error 띄움 (T-041 Discord 노이즈 위험). prod 활성 입소자 47명 중 3명 영향. fix: `ResidentBase` / `ResidentUpdate` 에 Pydantic `field_validator(mode='before')` 추가해 빈 문자열 → None normalize, `ResidentBase.name` 은 422 거부. prod DB cleanup 3 row 적용 + cron 재실행 `decrypt_errors: 0` 검증. T-309 검증 중 발견. `[area:backend]` `[area:security]` `[bug]` (album-backend#131, roadmap#236)
- [x] **T-314** 사진 삭제 항상 500 — `_delete_photo` 가 `PhotoResident / PhotoFace / PhotoLike / PhotoShare` 만 cleanup. `photo_audit_logs.photo_id` / `photo_processing_jobs.photo_id` 는 NOT NULL + ON DELETE 옵션 미지정 (RESTRICT 동작), `notifications.photo_id` 는 NULLABLE 이지만 동일. 업로드 시 `PhotoProcessingJob` 행이 항상 추가되므로 단건 (`DELETE /photos/{id}`) / 다중 (`POST /photos/bulk-delete`) 모두 FK violation → IntegrityError → 500. 사용자 보고 ("사진 다중 선택 후 삭제하면 '삭제 중 오류가 발생했습니다' alert"). fix: `_delete_photo` 의 cleanup 목록에 `PhotoAuditLog`, `PhotoProcessingJob` 추가 (hard delete) + `Notification.photo_id` 는 NULL update. 새 `PhotoAuditLog(action="delete")` INSERT 줄 제거 (어차피 같은 photo 가 곧 삭제돼 의미 없음 + 같은 transaction FK 위반). audit 보존 정책은 별도 (정답은 photo_id nullable + SET NULL 마이그). `[area:backend]` `[bug]` (album-backend#137, roadmap#245)
- [x] **T-316** backend pod startup Postgres race — backend Deployment 가 새 image 로 rollout 될 때마다 첫 컨테이너가 `Database.initialize()` 의 첫 asyncpg connect 에서 `ConnectionRefusedError [Errno 111]` 로 죽고 K8s 가 자동 재시작 → 두 번째에서 정상. `restartCount=1` 이 매 배포마다 박히고 ArgoCD OutOfSync 5min false positive 알람 발화 (T-243-4 album-backend#127 rollout 에서 진단 trigger). 영향: 매 backend rollout ~30초 API 응답 안 함 + Discord 알람 노이즈. fix 방향: backend Deployment 에 `initContainer` 추가 — `nc -z postgres 5432` 가 성공할 때까지 retry (image 변경 X, manifest only). `k3s_netpol_cron_pattern.md` 동일 패턴. **채번 메모: 원래 [T-308] 로 OPEN 됐으나 약 4시간 40분 뒤 다른 세션이 사진 chunk 분할 작업을 같은 T-308 로 채번 (roadmap#232, roadmap#233 신설 PR 머지) → KANBAN T-308 = chunk 분할 유지, 본 항목 T-316 으로 재번호.** T-243-4 검증 중 발견. `[area:ops]` `[bug]` (roadmap#229, album-deploy#37)
- [x] **T-317** `argocd.thekim123.info` 외부 접근 502 — cloudflared pod 로그에 `dial tcp 10.43.1.143:80: connect: connection refused` (originService=`http://argocd-server.argocd.svc.cluster.local:80`). ArgoCD pod / Service / Endpoints 자체는 정상 (같은 cluster 의 임시 busybox pod 에서 같은 DNS 호출 시 `/healthz` ok). 원인: `cloudflared` NetworkPolicy egress 가 frontend / minio / 외부 (Cloudflare edge) 만 명시, argocd-server 가 빠져 kube-router 가 enforce 차단. T-052 기본 deny 도입 시 누락된 것으로 추정 (그 전엔 동작했다는 사용자 보고). fix: cloudflared egress 에 namespaceSelector(`kubernetes.io/metadata.name=argocd`) + podSelector(`app.kubernetes.io/name=argocd-server`) AND, port TCP 8080 (Service 80 → pod 8080 DNAT 후 실제 포트). T-122 prod 검증 중 발견. `[area:ops]` `[bug]` (album-deploy#41)
- [x] **T-318** backend uvicorn access log 가 traceback 으로 stderr dump — `KeyError: 'otelTraceID'`. T-122 (album-backend#138) 에서 jsonlogger `rename_fields` 에 `otelTraceID -> trace_id` 매핑 추가. python-json-logger 2.0.7 의 `add_fields` 는 `merge_record_extra` 가 extras 의 rename 을 이미 적용해 `log_record["trace_id"]` 로 옮긴 뒤 `_perform_rename_log_fields` 가 다시 `log_record["otelTraceID"]` 직접 접근 → KeyError (rename 두 번 시도). 결과: 모든 access log 가 `StreamHandler.handleError` 로 traceback dump → Loki 인덱싱 깨짐 + log↔trace 양방향 점프 미작동. 사용자 응답성 영향 0 (요청은 200). 진단 3번 틀리고 4번째 commit 에서 진짜 fix — `_JSON_FORMAT` 에 `%(otelTraceID)s %(otelSpanID)s` placeholder 추가해서 두 키가 `_required_fields` 로 들어가게 하면 `add_fields` 첫 루프가 `log_record[field] = record.__dict__.get(field)` 로 채워 rename 단계 안전. `OtelTraceContextFilter` 는 보조 — None 대신 빈 문자열로 채워 Loki 쿼리 일관성. T-122 prod 검증 중 발견. `[area:backend]` `[area:ops]` `[bug]` (album-backend#139)
- [x] **T-319** 운영자 (`is_operator`) 어드민 화면 진입 동선 부재 — T-144~T-148 + T-022 의 6개 `/admin/...` 페이지가 라우트는 살아있지만 Layout sidebar `navItems` 에 `is_operator` 분기 자체가 없어 URL 직접 입력 외 진입 불가. + bootstrap promote (`_bootstrap_operators` lifespan 1회) 가 user 가입 시점 뒤면 누락. T-122 prod 검증 중 사용자 보고 ("운영자 계정 메일은 있는데 화면에 어떻게 가지"). 즉시 처리: DB UPDATE 로 누락 사용자 promote. 본 PR: Layout sidebar 끝에 `is_operator` 분기로 6 항목 (전체 유저/시설/보호자 승인/사진 처리 큐/통계/약관·방침) 노출. label prefix "운영 · " 로 시설 메뉴와 시각적 구분. bootstrap 누락 자체는 별도 검토 (user 등록 hook 에서도 promote 호출 vs OPERATOR_EMAIL 정책 폐기 + admin UI 토글). `[area:frontend]` `[area:product]` `[bug]` (album-frontend#75)

### infra (5)

- [x] **T-305** Brevo 이메일 인프라 — `notification_service.send_email_notification` 스텁 채움. Brevo HTTP API v3 (영구 무료 일 300통 / 월 ~9000). DNS SPF/DKIM 1회 셋업. 비밀번호 재설정 (T-306) prerequisite. `[area:ops]` `[area:product]` (album-backend#128) — 운영 활성화는 별도 (Brevo 계정 + DNS + SealedSecret)
- [x] **T-306** 비밀번호 재설정 (이메일 + SMS) — 사용자 본인 시작 흐름 (`/forgot-password` → 채널 선택 → 토큰 → 새 비번). `PasswordResetToken` 모델 (hash 저장, 30분 TTL, 1회용). T-305 의존. `[area:security]` `[area:product]` (album-backend#129, album-frontend#63)
- [x] **T-307** 보호자 초대 SMS 자동 발송 (CoolSMS) — T-304 manual_share 위에 자동 발송 레이어. CoolSMS (가입 OTP 와 동일 provider) 가 SMS 채널에서 자동 발송, 실패/미설정 시 manual_share fallback. dead code `biztalk_service.py` 및 `BIZZTALK_*` config / SealedSecret 제거. T-304 follow-up. `[area:backend]` `[area:ops]` (album-backend#126)
- [x] **T-315** ArgoCD `reconciledAt` lag 알람 — `argocd-repo-server` git polling 이 조용히 멈추는 사고가 4일 새 두 번 (2026-05-06 frontend bundle stale, 2026-05-10 T-303 backend bump 후 ~55분 stale). ArgoCD app 은 `Synced/Healthy` 거짓 보고 + Uptime Kuma ping (T-040/T-041) 은 origin pod image 차이를 못 잡음. k8s CronJob 으로 5분마다 `kubectl get application -o json` 의 `reconciledAt` 들 긁어 lag>10min warn / lag>30min critical Discord 발송 (T-041 웹훅 재사용, Prometheus 도입 회피). T-129 (ArgoCD Notifications) follow-up. **채번 메모: 원래 [T-309] 로 OPEN 됐으나 같은 시점 다른 세션이 cron image SHA stale 사고를 같은 번호로 채번 (roadmap#234 merged) → 본 항목 T-315 로 재번호. T-314 는 사진 삭제 FK cleanup (roadmap#245 진행 중) 에서 선점.** `[area:ops]` (roadmap#227, album-deploy#36)
- [x] **T-321** ArgoCD lag 워치독 auto-refresh — T-315 후속. ArgoCD v3.x informer pipeline regression ([argo-cd#27192](https://github.com/argoproj/argo-cd/issues/27192)) 로 일부 Application 의 `reconciledAt` 이 timer/watch 양쪽 다 정지 → lag-alert 가 알림만 보내고 회복은 수동 annotate 필요. `check.sh` 의 WARN/CRIT 분기에서 `argocd.argoproj.io/refresh=normal` annotate 를 자동 발사하도록 확장 (Role 에 `applications` patch verb 추가, 모든 Application 대상). 본 cluster Application 대부분 `syncPolicy.automated` 라 reconcile 후 drift 발견 시 auto-sync 동반 = 사실상 자가 회복. canvan-helper-bot 의 별도 refresh CronJob (`*/4`) 은 cluster-wide 솔루션으로 대체되며 검증 후 제거 (별도 repo PR). 업스트림 fix 머지되면 본 분기도 제거. `[area:ops]` (album-deploy#43)

---

## 통계

| 영역 | P0 | P1 | P2 | P3 | 합계 |
|---|---:|---:|---:|---:|---:|
| security | 11 | 6 | 8 | 4 | **29** |
| ops | 0 | 7 | 12 | 1 | **20** |
| product | 0 | 3 | 11 | 5 | **19** |
| biz | 0 | 7 | 6 | 0 | **13** |
| legal | 0 | 5 | 3 | 4 | **12** |
| funding/hiring | 0 | 0 | 0 | 4 | **4** |
| **합계** | **11** | **28** | **40** | **18** | **97** |

---

## 이 칸반을 GitHub Projects로 띄우기

1. 레포 `Projects` 탭 → **New project** → `Board` 선택 → 이름 `Senior Album Roadmap`
2. 컬럼: `Backlog` / `This Sprint` / `In Progress` / `Review` / `Done`
3. `scripts/create_issues.sh` 실행 → 이슈 85개 자동 생성
4. Project 오른쪽 상단 `+ Add items` → 이슈 전부 끌어오기
5. 매 스프린트(2주) 시작 시 P0→P1 순으로 5~8개 `This Sprint`로 드래그
