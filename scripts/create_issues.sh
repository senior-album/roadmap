#!/usr/bin/env bash
# Senior Album Roadmap — 이슈 85개 일괄 생성
# 사용: REPO=senior-album/roadmap bash scripts/create_issues.sh
# 선행: bash scripts/create_labels.sh 실행으로 라벨 생성 완료 상태
# 필요: gh CLI

set -euo pipefail
REPO="${REPO:-senior-album/roadmap}"
echo "→ Target repo: $REPO"

issue() {
  # $1=id  $2=title  $3=priority  $4=areas(comma)  $5=body
  local id="$1" title="$2" prio="$3" areas="$4" body="$5"
  local labels="priority:${prio}"
  IFS=',' read -ra arr <<< "$areas"
  for a in "${arr[@]}"; do labels+=",area:${a}"; done
  gh issue create --repo "$REPO" \
    --title "[${id}] ${title}" \
    --label "$labels" \
    --body "$body"
}

# ─────────────────────── P0 Critical (11) ───────────────────────
issue "T-001" "JWT_SECRET 기본값 제거 → .env 필수화" "P0" "security" \
"**위치**: \`app/core/config.py\`
**위협**: S-02 — 기본값 \`your-secret-key-change-in-production\` 사용 시 JWT 위조 가능
**작업**: 기본값 제거, \`JWT_SECRET: str = Field(...)\`로 기동 실패 강제, 실제 시크릿 재생성
**검증**: .env 미설정 시 앱 기동 실패 확인"

issue "T-002" "cloudflared.yaml TUNNEL_TOKEN 제거 + git 히스토리 purge" "P0" "security,ops" \
"**위치**: \`mac-deploy/k8s/cloudflared.yaml\`
**위협**: E-01 — 매니페스트 평문 base64, git에 커밋됨
**작업**: 매니페스트에서 토큰 제거, kubectl로 별도 secret 주입, \`git filter-repo\`로 히스토리 purge, 토큰 재발급"

issue "T-003" "Resident PII 컬럼 pgcrypto AES-256 암호화" "P0" "security" \
"**위치**: \`app/models/models.py::Resident\` (\`birth_date\`, \`phone\`, \`medical_notes\`)
**위협**: I-02 — 개인정보보호법상 민감정보 평문 저장
**작업**: pgcrypto 또는 애플리케이션 envelope encryption + blind index(\`phone_hash\`)"

issue "T-004" "OpenSearch 얼굴 임베딩 인덱스 암호화" "P0" "security" \
"**위치**: \`app/services/face_recognition.py\`, OpenSearch 설정
**위협**: I-01 — 생체정보 평문 저장
**작업**: 인덱스 전송·저장 암호화 옵션 적용"

issue "T-005" "파일 업로드 검증 강화" "P0" "security" \
"**위치**: \`app/api/photos.py\` 업로드 핸들러
**위협**: T-01/T-02 — 확장자만 신뢰, 크기 무제한
**작업**: 20MB 크기 제한 + python-magic MIME + 확장자 화이트리스트 + Pillow 디코딩 확인"

issue "T-006" "카카오 OAuth state 파라미터 도입" "P0" "security" \
"**위치**: \`app/api/kakao_auth.py\`
**위협**: S-01 — CSRF로 공격자 카카오 계정과 피해자 세션 연결
**작업**: \`state = secrets.token_urlsafe(32)\` 발급·검증, OIDC면 nonce까지"

issue "T-007" "업로드·공유링크·얼굴매칭 rate limit" "P0" "security" \
"**위협**: D-01 — 인증된 사용자의 DoS 가능
**작업**: 엔드포인트별 \`@rate_limit\` 데코레이터 (예: 10/min, 1GB/hour)"

issue "T-008" "공유 링크 토큰 엔트로피 강화 + 만료 검증 감사" "P0" "security" \
"**위치**: \`models.py::Photo.share_token\`, \`get_shared_photo\` 엔드포인트
**위협**: I-03
**작업**: \`secrets.token_urlsafe(32)\` 통일, expires_at 비교 누락 여부 감사"

issue "T-009" "JWT 만료 60분 + refresh 토큰 구조" "P0" "security" \
"**현재**: JWT_EXPIRE_MINUTES=10080 (7일)
**작업**: access 60분 + refresh 토큰 구조 설계 시작"

issue "T-010" "CORS 화이트리스트화" "P0" "security" \
"**위치**: \`app/main.py\` CORS 미들웨어
**위협**: I-05 — allow_methods/allow_headers = *
**작업**: 필요한 method·header만 명시"

issue "T-011" "Presigned URL vs share_expires_at 정책 통일" "P0" "security" \
"**위협**: I-04 — URL 1h vs DB 72h 불일치
**작업**: 공유 접근 시 URL 매회 재발급 플로우 확인·보정"

# ─────────────────────── P1 High (28) ───────────────────────
issue "T-020" "보호자 가입 3단 동의 UI + 동의 로그" "P1" "legal,product" \
"이용약관·개인정보처리방침·민감정보(얼굴·건강) 3단 동의 체크박스, 동의 내역 DB 기록 (누가 언제 어떤 조항)"

issue "T-021" "이용약관 2종 초안" "P1" "legal" "시설(유료 가입자)용 + 보호자(무료)용"
issue "T-022" "개인정보처리방침 + /privacy 페이지" "P1" "legal" "공개 페이지 + 푸터 링크"
issue "T-023" "개인정보 처리 위탁 계약서 템플릿" "P1" "legal" "Senior Album = 수탁자. 시설과 체결. 법정 기재사항 포함"
issue "T-024" "민감정보 처리 동의서" "P1" "legal" "얼굴·건강정보 별도 동의"

issue "T-030" "입소자 CSV 일괄 import" "P1" "product" "100명 단위 엑셀 업로드. 주민번호 뒷자리 생략 템플릿"
issue "T-031" "시설장 관리자 대시보드 강화" "P1" "product" "보호자 초대 현황, 미연결 어르신, 미처리 사진, 얼굴 미등록 경고"
issue "T-032" "보호자 초대 QR 포스터 PDF 자동 생성" "P1" "product" "시설 게시판용"

issue "T-040" "Uptime Kuma 셀프호스트 + 4개 서비스 ping" "P1" "ops" "frontend/backend/argocd/cloudflared"
issue "T-041" "Telegram/카카오 봇 장애 알림" "P1" "ops" "본인 휴대폰으로 푸시"
issue "T-042" "Loki + Grafana 로그 수집" "P1" "ops" "일 1회 S3/R2 export 7일 보관"
issue "T-043" "PostgreSQL pg_dump 일 1회 → R2" "P1" "ops" "Cloudflare R2 무료 티어 10GB 활용"
issue "T-044" "MinIO mc mirror CronJob 백업" "P1" "ops" "업로드 사진 주기적 mirror"
issue "T-045" "런북 4종 작성" "P1" "ops" "맥미니 재부팅 / DB 복구 / 빌드 실패 롤백 / 인증서 만료"
issue "T-046" "SLO 내부 문서화" "P1" "ops" "가동률 99.0%, 응답 <500ms, RTO 4h, RPO 24h"

issue "T-050" "Sealed Secrets controller 도입" "P1" "security,ops" "모든 secret 매니페스트 마이그레이션"
issue "T-051" "이미지 재인코딩 파이프라인" "P1" "security" "thumbnail 생성 시 metadata strip"
issue "T-052" "NetworkPolicy 기본 deny" "P1" "security,ops" "허용된 서비스만 allow"
issue "T-053" "Dockerfile 베이스 이미지 digest pin" "P1" "security,ops" "python:3.11.9-slim-bookworm@sha256:..."
issue "T-054" "bcrypt rounds=12 명시" "P1" "security" "로그인 시 점진 재해싱"
issue "T-055" "JWT rolling key 구조" "P1" "security" "Sealed Secrets 또는 SOPS+age 관리"

issue "T-060" "개인사업자 등록" "P1" "biz" "매출 8천만원 초과 시 일반과세자 전환 계획 포함"
issue "T-061" "카카오톡 비즈 채널 + 알림톡" "P1" "biz,product" "사진 업로드·초대 발송 채널"
issue "T-062" "부모님 시설 케이스 스터디 영상" "P1" "biz" "시설장 인터뷰 포함. 다른 시설 설득용"
issue "T-063" "주변 요양시설 10곳 리스트업 + 개별 메시지" "P1" "biz" "콜드 아웃리치"
issue "T-064" "15분 데모 방문 5회 이상" "P1" "biz" "맥북+갤럭시탭 휴대 방문 영업"
issue "T-065" "지자체 스마트요양 시범사업 1건 신청" "P1" "biz,funding" "레퍼런스+자금"
issue "T-066" "요양뉴스/실버경제 기고 1건" "P1" "biz" "보도자료 또는 기고"

# ─────────────────────── P2 Medium (28) ───────────────────────
issue "T-100" "Path Traversal 방지" "P2" "security" "storage.py::upload_file에서 facility_id sanitize"
issue "T-101" "PhotoAuditLog 범위 확대" "P2" "security" "조회·다운로드·공유링크 사용 이력"
issue "T-102" "관리자 특권 행위 감사 로그" "P2" "security" "보호자 승인, 입소자 삭제"
issue "T-103" "PII 로깅 마스킹" "P2" "security" "email·resident name 마스킹"
issue "T-104" "500 에러 스택트레이스 차단" "P2" "security" "DEBUG 프로덕션 off"
issue "T-105" "verify_facility_access DB 재검증" "P2" "security" "JWT만 신뢰 X"
issue "T-106" "얼굴 인식 워커 queue 길이 제한" "P2" "security" "D-02 완화"
issue "T-107" "OpenSearch kNN size 상한" "P2" "security" "대량 사진 시설 비용 방어"

issue "T-120" "Alembic 도입, DDL_AUTO 제거" "P2" "ops" "CI alembic upgrade head"
issue "T-121" "백업 복구 리허설 분기 1회" "P2" "ops" "복구 안 되는 백업은 백업이 아님"
issue "T-122" "OpenTelemetry + Grafana Cloud" "P2" "ops" "업로드 성공률, 얼굴 매칭 지연, 공유 링크 응답"
issue "T-123" "구조화 로그 (JSON)" "P2" "ops" "Loki 파싱 효율화"
issue "T-124" "핵심 로직 테스트 커버리지 70%" "P2" "ops" "JWT, face_recognition, 업로드 플로우"
issue "T-125" "Dependabot + pip-audit" "P2" "ops" "의존성 업데이트 자동화"
issue "T-126" "업로드 스토리지 PV 전환" "P2" "ops" "emptyDir 제거"

issue "T-140" "시설 관리자 모바일 앱 경량 버전" "P2" "product" "현장 사진 즉시 업로드"
issue "T-141" "온보딩 체크리스트 자동화" "P2" "product" "시설 코드 발급, 브랜딩, 직원 계정"
issue "T-142" "CSAT/NPS 자동 수집" "P2" "product" "Google Form 지원티켓 종료 시 발송"
issue "T-143" "월간 시설별 사용 지표 메일" "P2" "product" "자동 발송"

issue "T-160" "결제 연동" "P2" "biz" "나이스페이먼츠 또는 아임포트"
issue "T-161" "세금계산서 발행 자동화" "P2" "biz" ""
issue "T-162" "가격 티어 확정" "P2" "biz" "Starter 9.9만 / Standard 19.9만 / Pro 29.9만 / Enterprise 협의"
issue "T-163" "Closed Beta 3~5개 시설 계약" "P2" "biz" "무료, 피드백·인터뷰 동의 조건"
issue "T-164" "상표 \"Senior Album\" 출원" "P2" "biz,legal" "20~30만원"
issue "T-165" "과기정통부 SaaS 전환 지원 신청" "P2" "biz,funding" "최대 5천만원"

issue "T-180" "데이터 파기 요청 처리 플로우" "P2" "legal" "계약 종료 시 자동 파기"
issue "T-181" "유출 72시간 신고 절차 문서화" "P2" "legal" "개인정보보호위원회 신고 체계"
issue "T-182" "로그 보관 기간 정책 + 자동 파기" "P2" "legal,ops" "CronJob으로 만료 로그 삭제"

# ─────────────────────── P3 Low (18) ───────────────────────
issue "T-200" "etcd encryption at rest" "P3" "security" "RKE2 등 전환 검토"
issue "T-201" "Trivy + gitleaks CI" "P3" "security" "이미지 스캔 + 시크릿 감지"
issue "T-202" "침투 테스트 외주" "P3" "security" "고객 2~3곳 확보 후"
issue "T-203" "SSL A+ 등급" "P3" "security" "Qualys SSL Labs"

issue "T-220" "맥미니 → 클라우드 이관 검토" "P3" "ops" "AWS Lightsail / GCP / NHN"

issue "T-240" "다국어 지원" "P3" "product" "외국인 보호자"
issue "T-241" "입소자 안부 일지" "P3" "product" "거동·식사 기록"
issue "T-242" "보호자 간 메시지" "P3" "product" ""
issue "T-243" "이벤트 캘린더" "P3" "product" "생신·외출·면회"
issue "T-244" "이지케어/케어포 API 연동 제휴" "P3" "product,biz" ""

issue "T-260" "엔젤 컨택" "P3" "funding" "Primer, Mashup Angels, Sopoong, Bonangels"
issue "T-261" "법인 전환" "P3" "biz" "유료 고객 3개 초과 시"
issue "T-262" "TIPS R&D 신청" "P3" "funding" "엔젤 선투자 후 최대 5억"
issue "T-263" "첫 채용" "P3" "funding" "공동창업자 or 파트타임 CS·마케팅"

issue "T-280" "SOC 2 Type I 준비" "P3" "legal" "해외 진출 대비"
issue "T-281" "ISMS-P 인증" "P3" "legal" "대형 요양병원 수주 가산점"
issue "T-282" "KMS 도입" "P3" "security,legal" "HashiCorp Vault / AWS KMS"
issue "T-283" "PIA 개인정보 영향평가" "P3" "legal" "규모 확대 시"

echo "✅ 이슈 85개 생성 완료"
