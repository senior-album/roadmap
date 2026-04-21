#!/usr/bin/env bash
# Senior Album Roadmap — GitHub 라벨 10종 일괄 생성
# 사용: REPO=senior-album/roadmap bash scripts/create_labels.sh
# 필요: gh CLI (https://cli.github.com) 인증 상태 + 레포 쓰기 권한

set -euo pipefail
REPO="${REPO:-senior-album/roadmap}"

echo "→ Target repo: $REPO"

create() {
  local name="$1" color="$2" desc="$3"
  gh label create "$name" --color "$color" --description "$desc" --repo "$REPO" --force
}

# 우선순위 (4)
create "priority:P0" "b60205" "Critical — 베타 오픈 전 필수 (1~2주)"
create "priority:P1" "d93f0b" "High — Closed Beta 운영 기반 (2주~2개월)"
create "priority:P2" "fbca04" "Medium — Paid Beta → GA (2~6개월)"
create "priority:P3" "0e8a16" "Low — Scale·인증·조직 (6~12개월)"

# 영역 (6)
create "area:security" "5319e7" "보안·인증·암호화·규제 취약점"
create "area:ops"      "0052cc" "인프라·배포·모니터링·DB·테스트"
create "area:product"  "006b75" "기능·UI·UX"
create "area:biz"      "c2e0c6" "영업·마케팅·계약·결제"
create "area:legal"    "c5def5" "약관·개인정보·위탁계약·인증"
create "area:funding"  "bfdadc" "정부지원·엔젤·TIPS·채용"

echo "✅ 라벨 10종 생성 완료"
