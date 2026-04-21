# 제품 마일스톤

`03_operations_playbook.md`의 90일 플랜 + `02_market_viability.md`의 단계별 롤아웃 결합.

## 타임라인

```
2026-04  ─── 2026-05 ─── 2026-06 ─── 2026-07 ─── 2026-08 ─── ... ─── 2027-04
  │            │            │            │            │                   │
  Alpha      Beta         Closed      Closed      Paid Beta         GA + 10 유료
  (부모님)    Oven        Beta 3곳    Beta 5곳     시작
```

## Milestone 1 — Beta Oven (2026-04 ~ 05)

**목표**: 현 제품을 "운영 가능한 SaaS"로 전환

- P0 11개 완료
- P1 `ops(7)` 완료 — Uptime Kuma, 백업, 런북, SLO
- P1 `legal(5)` 완료 — 약관 3종 + 동의 UI
- P1 `product(3)` 완료 — CSV import, 대시보드, QR 포스터

**Exit criteria**: 모의 보호자 계정 5개로 1주일 무장애 운영 + 첫 백업 복구 리허설 성공

## Milestone 2 — Closed Beta 3 sites (2026-06)

**목표**: 부모님 시설 외 2곳 무료 운영

- P1 `biz(7)` 완료 — 개인사업자 등록, 카카오 비즈 채널, 콜드 아웃리치 10, 데모 5
- P1 `security(6)` 완료 — Sealed Secrets, NetworkPolicy, bcrypt 등

**Exit criteria**: 3개 시설 × 월간 가동률 99.0% + NPS 설문 회수 각 시설 10명 이상

## Milestone 3 — Closed Beta 5 sites (2026-07 ~ 08)

**목표**: 5개 시설, 유료 전환 준비

- P2 `security(8)` 완료 — 감사 로그, PII 마스킹, verify_facility_access DB 재검증
- P2 `ops(7)` 완료 — Alembic, OpenTelemetry, 테스트 70%

**Exit criteria**: 시설 1개 이상 유료 전환 의향 표명 + 결제 연동 데모

## Milestone 4 — Paid Beta (2026-09 ~ 11)

**목표**: 첫 유료 1~2개, 가격 검증

- P2 `biz(6)` 완료 — 결제, 세금계산서, 가격 티어, 상표, SaaS 전환 지원 신청
- P2 `product(4)` 완료 — 모바일 앱, 온보딩 자동화, CSAT/NPS, 월간 메일
- P2 `legal(3)` 완료 — 파기 플로우, 유출 절차, 로그 파기

**Exit criteria**: MRR 50만원 + 유료 시설 2개

## Milestone 5 — General Availability (2026-12 ~ 2027-01)

**목표**: 일반 출시, 10개 유료 시설

- P3 `security(4)` 중 2건 — Trivy CI, SSL A+
- P3 `product(5)` 중 2건 — 다국어 또는 이벤트 캘린더
- 정부 지원사업 결과 + 엔젤 컨택 시작

**Exit criteria**: MRR 200만원 + NPS +20 + 유료 시설 10개

## Milestone 6 — Scale (2027-02 ~ 04)

**목표**: 투자 유치 + 첫 채용

- P3 `funding(4)` — 엔젤 마감, 법인 전환, TIPS 신청, CS 1명 채용
- P3 `legal(4)` 중 2건 — SOC 2 또는 KMS 도입

**Exit criteria**: 유료 25개 시설 + 첫 투자 유치 or TIPS 통과

## 분기별 체크인

매 3개월 말 `KANBAN.md`의 체크박스 진척도·통계 테이블 업데이트.
Milestone 미달 시 해당 P 항목을 상위 우선순위로 재배치.
