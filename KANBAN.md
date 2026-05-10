# Senior Album — 칸반보드

**97개 할일** · P0(11) · P1(28) · P2(40) · P3(18)
근거: `reports/01_security_analysis.md`, `02_market_viability.md`, `03_operations_playbook.md`

> 체크박스를 클릭해 진척을 표시하거나, GitHub Projects 칸반 뷰로 드래그하세요.

---

## 🔴 P0 — Critical (1~2주, 베타 오픈 전 필수)

### security (11)

- [x] **T-001** JWT_SECRET 기본값 제거 → `.env` 필수화, 시크릿 재생성 `[area:security]`
- [x] **T-002** `cloudflared.yaml` TUNNEL_TOKEN 매니페스트에서 제거 + 과거 git 히스토리 purge `[area:security]`
- [x] **T-003** Resident PII (`name`, `birth_date`, `medical_notes`) envelope encryption (KEK + 행별 DEK + AES-256-GCM) + name blind index. 5 서브이슈 분할 진행. User.phone 은 별도 후속 이슈. `[area:security]`
- [x] **T-004** OpenSearch 얼굴 임베딩 인덱스 전송·저장 암호화 옵션 적용 `[area:security]`
- [x] **T-005** 파일 업로드 검증 강화: 20MB 크기 + python-magic MIME + 확장자 화이트리스트 + Pillow 디코딩 확인 `[area:security]`
- [x] **T-006** 카카오 OAuth `state` 파라미터 생성·검증 (CSRF 방어) `[area:security]`
- [x] **T-007** 업로드·공유링크·얼굴매칭 엔드포인트 rate limit 추가 `[area:security]`
- [x] **T-008** 공유 링크 토큰 `secrets.token_urlsafe(32)` 통일 + 만료 검증 감사 `[area:security]`
- [x] **T-009** JWT_EXPIRE_MINUTES 60 축소 + refresh 토큰 구조 설계 `[area:security]`
- [x] **T-010** CORS `allow_methods`/`allow_headers` 명시적 화이트리스트 `[area:security]`
- [x] **T-011** Presigned URL(1h) vs `share_expires_at`(72h) 정책 통일 — 접근 시 매회 재발급 `[area:security]`

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
- [ ] **T-061** 카카오톡 비즈니스 채널 개설 + 알림톡 연동 `[area:biz]`
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
- [ ] **T-122** OpenTelemetry 자동 계측 + Grafana Cloud 무료 티어 `[area:ops]`
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

- [ ] **T-140** 시설 관리자 모바일 앱 경량 버전 (현장 업로드) `[area:product]`
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
- [ ] **T-201** Trivy 이미지 스캐너 CI + gitleaks·truffleHog 시크릿 감지 `[area:security]`
- [ ] **T-202** 침투 테스트 외주 (고객 2~3곳 확보 후) `[area:security]`
- [ ] **T-203** SSL/TLS 등급 A+ (Qualys SSL Labs) `[area:security]`

### ops (1)

- [ ] **T-220** 맥미니 → 클라우드 이관 검토 (AWS Lightsail / GCP / NHN Cloud) `[area:ops]`

### product (5)

- [ ] **T-240** 다국어 지원 (외국인 보호자) `[area:product]`
- [x] **T-241** 입소자 안부 일지 (거동·식사) `[area:product]` (album-backend#109, album-frontend#53)
- [ ] ~~**T-242** 보호자 간 메시지 기능~~ `[area:product]` `[wontfix]` — 외부 메신저(카톡 등)로 대체 가능, WS/푸시 인프라 ROI 부족
- [x] **T-243** 이벤트 캘린더 (생신·외출, 면회 제외) `[area:product]` (album-backend#119, album-frontend#59, album-backend#120, album-deploy#22)
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

### product (2)

- [x] **T-301** 보호자 갤러리 사진 확대보기(라이트박스) — 좌우 키/버튼 + 줌 + ESC `[area:product]` (album-frontend#51)
- [x] **T-302** 보호자 라이트박스 마우스 휠로 이전/다음 사진 이동 `[area:product]` (album-frontend#52)

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
