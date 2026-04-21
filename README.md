# Senior Album Roadmap

Senior Album B2B SaaS 제품의 **보안·운영·시장 진출 할일을 통합 추적**하는 레포다.
보고서 3종(`reports/01_security_analysis.md`, `02_market_viability.md`, `03_operations_playbook.md`)에서 뽑은 할일을 우선순위화해 한곳에서 본다.

## 칸반보드 보는 법

두 가지 방식 중 하나:

1. **`KANBAN.md` 체크리스트** — 이 레포 루트의 [`KANBAN.md`](./KANBAN.md). GitHub이 checkbox를 렌더링해 실시간 진척을 볼 수 있다.
2. **GitHub Projects (권장)** — [Projects 탭](../../projects) → `Senior Album Roadmap`. 컬럼 `Backlog → This Sprint → In Progress → Review → Done`로 드래그.

## 구조

```
roadmap/
├── README.md                   # 이 파일
├── KANBAN.md                   # 85개 할일 체크리스트 (단일 진실 소스)
├── docs/
│   ├── 01_priority_breakdown.md   # P0~P3 결정 근거
│   ├── 02_milestones.md           # 제품 마일스톤 (베타/GA/Scale)
│   └── 03_source_reports.md       # 원본 보고서 요약
├── scripts/
│   ├── create_labels.sh        # 라벨 10종 일괄 생성 (gh CLI)
│   └── create_issues.sh        # 이슈 85개 일괄 생성 (gh CLI)
└── .github/ISSUE_TEMPLATE/     # P0/P1/P2/P3 템플릿
```

## 우선순위 정의

| 레벨 | 기간 | 설명 |
|---|---|---|
| 🔴 **P0 Critical** | 1~2주 | 베타 오픈 전 반드시. 하나라도 미해결이면 보호자 5명 이상 공개 금지. |
| 🟠 **P1 High** | 2주~2개월 | Closed Beta 5개 시설 운영 가능 상태. 규제·운영·초기 영업 기반. |
| 🟡 **P2 Medium** | 2~6개월 | Paid Beta → GA. MRR 200만원 마일스톤. |
| 🟢 **P3 Low** | 6~12개월 | 유료 25개 시설 / 첫 투자 준비 / 해외·인증. |

## 영역 라벨

- `area:security` — 보안·인증·암호화·규제 취약점
- `area:ops` — 인프라·배포·모니터링·DB·테스트
- `area:product` — 기능·UI·UX·사용자 경험
- `area:biz` — 영업·마케팅·계약·결제
- `area:legal` — 약관·개인정보·위탁계약·인증 (SOC2/ISMS-P)
- `area:funding` — 정부지원·엔젤·TIPS·채용

## 진행 방식

1. 스프린트 주기: 2주
2. 각 스프린트 시작 시 `This Sprint` 컬럼에 P0 → P1 순으로 5~8개 이슈 당김
3. 주간 회고: `Done` 컬럼 비우고 메트릭 갱신 (`docs/02_milestones.md`)
4. 월간 리뷰: `KANBAN.md`의 통계 표 업데이트, P3 재평가

## 메트릭 (12개월 목표)

| 지표 | 최소 | 이상적 |
|---|---|---|
| MRR | 200만원 | 500만원 |
| 유료 시설 | 10개 | 25개 |
| 활성 보호자 | 300명 | 800명 |
| 가동률 | 99.0% | 99.5% |
| NPS | +20 | +40 |
| 개인정보 사고 | 0건 | 0건 |

---

생성: 2026-04-21 · 근거 보고서 3종 기반 · 85개 할일
