#!/bin/bash

# 템플릿 경로
TITLE_FILE="scripts/pr_templates/pr_title.txt"
BODY_FILE="scripts/pr_templates/pr_body.md"

if [[ ! -f "$TITLE_FILE" || ! -f "$BODY_FILE" ]]; then
  echo "❌ 템플릿 파일이 존재하지 않습니다. $TITLE_FILE / $BODY_FILE"
  exit 1
fi

echo "🚀 PR을 생성할 대상 브랜치를 선택하세요:"
echo "┌────────────────────────────┐"
echo "│ 1) develop 브랜치          │"
echo "│ 2) release 브랜치          │"
echo "└────────────────────────────┘"
read -p "👉 번호 입력 (1 또는 2): " TARGET_INPUT

if [[ "$TARGET_INPUT" == "1" ]]; then
  BASE_PREFIX="develop"
elif [[ "$TARGET_INPUT" == "2" ]]; then
  BASE_PREFIX="release"
else
  echo "❌ 잘못된 입력입니다. 1 또는 2만 입력해주세요."
  exit 1
fi

echo "┌────────────────────────────────────────┐"
read -p "│ 📦 대상 버전 입력 (예: 1.2.3): " VERSION
echo "└────────────────────────────────────────┘"

BASE_BRANCH="${BASE_PREFIX}/${VERSION}"

CURRENT_BRANCH=$(git symbolic-ref --short HEAD)
echo ""
echo "📋 현재 브랜치: $CURRENT_BRANCH"
echo "🔁 병합 대상 브랜치: $BASE_BRANCH"
echo ""

echo "┌──────────────────────────────────────────────┐"
read -p "│ ✅ 위 브랜치로 PR을 생성할까요? (y/n): " CONFIRM
echo "└──────────────────────────────────────────────┘"
if [[ "$CONFIRM" != "y" && "$CONFIRM" != "Y" ]]; then
  echo "🚫 작업이 취소되었습니다."
  exit 0
fi

gh pr create \
  --title "$(cat $TITLE_FILE)" \
  --body "$(cat $BODY_FILE)" \
  --base "$BASE_BRANCH" \
  --head "$CURRENT_BRANCH" \
  --web
