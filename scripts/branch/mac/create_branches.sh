#!/bin/bash

# 공통 환경변수 로드
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$script_dir/../.." && pwd)"
source "$REPO_ROOT/scripts/common/common.sh"
load_env
set_defaults

echo "🚀 정규 배포 작업인지, 긴급 배포(핫픽스) 작업인지 선택하세요:"
echo "┌──────────────────────┐"
echo "│ 1) 정규              │"
echo "│ 2) 핫픽스            │"
echo "└──────────────────────┘"
read -p "👉 번호 입력 (1 또는 2): " TYPE_INPUT

if [[ "$TYPE_INPUT" == "1" ]]; then
  IS_HOTFIX=false
elif [[ "$TYPE_INPUT" == "2" ]]; then
  IS_HOTFIX=true
else
  echo "❌ 잘못된 입력입니다. 1 또는 2만 입력해주세요."
  exit 1
fi

# base branch 선택 추가
prompt_base_branch() {
  echo ""
  echo "┌──────────────────────────────────────────────┐"
  echo "│ 생성 기준이 될 base branch를 선택하세요:"
  echo "│ 1) main (기본)"
  echo "│ 2) master"
  echo "│ 3) 직접 입력 (영문자+숫자만 허용)"
  echo "└──────────────────────────────────────────────┘"
  read -p "👉 번호 입력 (1,2 또는 3): " BASE_CHOICE

  if [[ -z "$BASE_CHOICE" || "$BASE_CHOICE" == "1" ]]; then
    BASE_BRANCH="main"
  elif [[ "$BASE_CHOICE" == "2" ]]; then
    BASE_BRANCH="master"
  elif [[ "$BASE_CHOICE" == "3" ]]; then
    read -p "🔤 직접 입력 (영문자+숫자만): " CUSTOM_BASE
    if [[ ! "$CUSTOM_BASE" =~ ^[A-Za-z0-9]+$ ]]; then
      echo "❌ 브랜치 이름은 영문자와 숫자만 허용됩니다."
      exit 1
    fi
    BASE_BRANCH="$CUSTOM_BASE"
  else
    echo "❌ 잘못된 입력입니다. 1, 2 또는 3 중 하나를 입력하세요."
    exit 1
  fi
  echo "✅ 선택된 base branch: origin/$BASE_BRANCH"
}

# base branch 선택 실행
prompt_base_branch

# ✅ 핫픽스 분기
if [ "$IS_HOTFIX" = true ]; then
  echo ""
  echo "┌───────────────────────────────────────────┐"
  read -p "│ 🔧 Hotfix 이슈 키 입력 (예: SIGN-1234): " ISSUE_KEY
  echo "└───────────────────────────────────────────┘"
  if [[ ! "$ISSUE_KEY" =~ ^[A-Za-z]+-[0-9]+$ ]]; then
    echo "❌ 이슈 키 형식이 올바르지 않습니다. 예: SIGN-123"
    exit 1
  fi

  BRANCH_NAME="${HOTFIX_BRANCH_PREFIX}${ISSUE_KEY}"
  echo ""
  echo "📋 생성될 브랜치: $BRANCH_NAME (base: origin/$BASE_BRANCH)"
  read -p "✅ 위 브랜치를 생성하시겠습니까? (y/n): " CONFIRM
  if [[ "$CONFIRM" != "y" && "$CONFIRM" != "Y" ]]; then
    echo "🚫 작업이 취소되었습니다."
    exit 0
  fi

  git fetch origin

  if git ls-remote --exit-code --heads origin "$BRANCH_NAME" > /dev/null; then
    echo "⚠️ 브랜치 $BRANCH_NAME 가 이미 존재합니다. 작업을 중단합니다."
    exit 0
  fi

  git checkout origin/"$BASE_BRANCH" || exit 1
  git checkout -b "$BRANCH_NAME" || exit 1
  git push -u origin "$BRANCH_NAME"

  echo ""
  echo "✅ hotfix 브랜치 생성 완료: $BRANCH_NAME"
  echo "🔗 Jira: ${JIRA_BASE_URL}$ISSUE_KEY"
  exit 0
fi

# ✅ 정규 배포 작업
echo ""
echo "┌──────────────────────────────────────────────┐"
read -p "│ 📘 상위 Story 키 입력 (예: SIGN-1000): " STORY_KEY
echo "└──────────────────────────────────────────────┘"
if [[ ! "$STORY_KEY" =~ ^[A-Za-z]+-[0-9]+$ ]]; then
  echo "❌ Story 키 형식이 올바르지 않습니다."
  exit 1
fi

echo "┌──────────────────────────────────────────────┐"
read -p "│ 📗 하위 Feature 키 입력 (예: SIGN-1001): " FEATURE_KEY
echo "└──────────────────────────────────────────────┘"
if [[ ! "$FEATURE_KEY" =~ ^[A-Za-z]+-[0-9]+$ ]]; then
  echo "❌ Feature 키 형식이 올바르지 않습니다."
  exit 1
fi

echo "┌──────────────────────────────────────────────┐"
read -p "│ 📝 간단한 설명 입력 (예: email check): " DESC_INPUT
echo "└──────────────────────────────────────────────┘"

# 원본 보존
ORIGINAL_DESC="$DESC_INPUT"

# 1. 띄어쓰기를 하이픈으로 변환
DESC=$(echo "$DESC_INPUT" | tr ' ' '-')

# 2. 소문자로 변환
DESC=$(echo "$DESC" | tr '[:upper:]' '[:lower:]')

# 3. 연속된 하이픈 제거 (예: "hello  world" -> "hello--world" -> "hello-world")
DESC=$(echo "$DESC" | sed 's/--*/-/g')

# 4. 앞뒤 하이픈 제거
DESC=$(echo "$DESC" | sed 's/^-\|-$//g')

# 변환 과정 표시
if [[ "$ORIGINAL_DESC" != "$DESC" ]]; then
  echo "🔄 자동 변환됨: '$ORIGINAL_DESC' → '$DESC'"
fi

# 빈 문자열 검사
if [[ -z "$DESC" ]]; then
  echo "❌ 설명이 비어있습니다."
  exit 1
fi

# 유효성 검사
if [[ ! "$DESC" =~ ^[a-z0-9-]+$ ]]; then
  echo "❌ 설명에 허용되지 않는 문자가 포함되어 있습니다."
  echo "   허용: 영문, 숫자, 하이픈(-)"
  echo "   변환된 값: $DESC"
  exit 1
fi

echo "✅ 최종 설명: $DESC"

echo "┌──────────────────────────────────────────────┐"
read -p "│ 🔧 생성할 버전 입력 (형식: x.y.z): " VERSION
echo "└──────────────────────────────────────────────┘"
if [[ ! "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "❌ 버전 형식이 올바르지 않습니다. 예: 1.2.3"
  exit 1
fi

RELEASE_BRANCH="release/$VERSION"
DEVELOP_BRANCH="develop/$VERSION"
FEATURE_BRANCH="${FEATURE_BRANCH_PREFIX}$VERSION/$STORY_KEY/feature/$FEATURE_KEY/$DESC"

echo ""
echo "📋 생성될 브랜치 목록:"
echo "   🔹 $RELEASE_BRANCH (base: origin/$BASE_BRANCH)"
echo "   🔹 $DEVELOP_BRANCH (base: $RELEASE_BRANCH)"
echo "   🔹 $FEATURE_BRANCH (base: $RELEASE_BRANCH)"
echo ""

read -p "✅ 위 브랜치를 생성하시겠습니까? (y/n): " CONFIRM
if [[ "$CONFIRM" != "y" && "$CONFIRM" != "Y" ]]; then
  echo "🚫 작업이 취소되었습니다."
  exit 0
fi

git fetch origin

# ✅ release 브랜치
if git ls-remote --exit-code --heads origin "$RELEASE_BRANCH" > /dev/null; then
  echo "🔄 $RELEASE_BRANCH 이미 존재. 건너뜁니다."
else
  echo "🌱 $RELEASE_BRANCH 생성 중..."
  git checkout origin/"$BASE_BRANCH" || exit 1
  git checkout -b "$RELEASE_BRANCH" || exit 1
  git push -u origin "$RELEASE_BRANCH"
fi

# ✅ develop 브랜치
if git ls-remote --exit-code --heads origin "$DEVELOP_BRANCH" > /dev/null; then
  echo "🔄 $DEVELOP_BRANCH 이미 존재. 건너뜁니다."
else
  echo "🌱 $DEVELOP_BRANCH 생성 중..."
  git checkout "$RELEASE_BRANCH" || exit 1
  git checkout -b "$DEVELOP_BRANCH" || exit 1
  git push -u origin "$DEVELOP_BRANCH"
fi

# ✅ feature 브랜치 (로컬만 생성)
if git show-ref --verify --quiet refs/heads/"$FEATURE_BRANCH"; then
  echo "⚠️ $FEATURE_BRANCH 로컬에 이미 존재합니다. 생성을 건너뜁니다."
else
  echo "🌱 $FEATURE_BRANCH 생성 중...(로컬)"
  git checkout "$RELEASE_BRANCH" || exit 1
  git checkout -b "$FEATURE_BRANCH" || exit 1
fi

echo ""
echo "✅ 브랜치 생성 완료!"
echo "   🔹 $RELEASE_BRANCH (푸시됨)"
echo "   🔹 $DEVELOP_BRANCH (푸시됨)"
echo "   🔹 $FEATURE_BRANCH (로컬만 생성됨)"
echo ""
echo "🔗 Jira 이슈 바로가기: ${JIRA_BASE_URL}$FEATURE_KEY"
