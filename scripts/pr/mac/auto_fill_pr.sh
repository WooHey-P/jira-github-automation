#!/bin/bash

# PR 템플릿 자동 채우기 스크립트
# Gemini API를 사용하여 커밋 메시지를 기반으로 PR 제목과 내용을 생성

set -e

# 공통 환경변수 로드
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$script_dir/../.." && pwd)"
source "$REPO_ROOT/scripts/common/common.sh"
load_env
set_defaults

# 사용자 확인
echo -e "${BLUE}🚀 PR 템플릿을 AI로 자동 생성하시겠습니까?${NC}"
echo -e "${YELLOW}현재 브랜치의 커밋 메시지를 분석하여 PR 제목과 본문을 생성합니다.${NC}"
read -p "계속하시겠습니까? (Y/n): " -n 1 -r
echo
if [[ $REPLY =~ ^[Nn]$ ]]; then
    echo -e "${YELLOW}취소되었습니다.${NC}"
    exit 0
fi

# 현재 디렉토리가 git 레포인지 확인
if [ ! -d ".git" ]; then
    echo -e "${RED}Error: 현재 디렉토리가 git 레포지토리가 아닙니다.${NC}"
    exit 1
fi

# GEMINI_API_KEY 환경변수 확인
if [ -z "$GEMINI_API_KEY" ]; then
    echo -e "${RED}Error: GEMINI_API_KEY 환경변수가 설정되지 않았습니다.${NC}"
    echo -e "${YELLOW}.env 파일을 생성하거나 환경변수를 설정해주세요: export GEMINI_API_KEY='your_api_key'${NC}"
    exit 1
fi

# 현재 브랜치 확인
CURRENT_BRANCH=$(git branch --show-current)
echo -e "${BLUE}현재 브랜치: ${CURRENT_BRANCH}${NC}"

# release 브랜치 찾기 (최신 release/x.x.x 형태)
RELEASE_BRANCH=$(git branch -r | grep -E 'origin/release/[0-9]+\.[0-9]+\.[0-9]+' | sort -V | tail -1 | sed 's/origin\///' | xargs)

if [ -z "$RELEASE_BRANCH" ]; then
    echo -e "${YELLOW}Warning: release/x.x.x 형태의 브랜치를 찾을 수 없습니다. ${DEFAULT_BASE_BRANCH} 브랜치를 기준으로 사용합니다.${NC}"
    RELEASE_BRANCH="$DEFAULT_BASE_BRANCH"
fi

echo -e "${BLUE}기준 브랜치: ${RELEASE_BRANCH}${NC}"

# 커밋 메시지 수집 (현재 브랜치와 release 브랜치 간의 차이)
echo -e "${BLUE}커밋 메시지를 수집하는 중...${NC}"
COMMIT_MESSAGES=$(git log --oneline ${RELEASE_BRANCH}..${CURRENT_BRANCH} --pretty=format:"- %s" 2>/dev/null || echo "커밋 메시지를 가져올 수 없습니다.")

if [ -z "$COMMIT_MESSAGES" ] || [ "$COMMIT_MESSAGES" = "커밋 메시지를 가져올 수 없습니다." ]; then
    echo -e "${YELLOW}Warning: 커밋 메시지를 찾을 수 없습니다. 현재 브랜치의 최근 10개 커밋을 사용합니다.${NC}"
    COMMIT_MESSAGES=$(git log --oneline -10 --pretty=format:"- %s")
fi

echo -e "${GREEN}수집된 커밋 메시지:${NC}"
echo "$COMMIT_MESSAGES"

# Gemini API 호출을 위한 프롬프트 생성
generate_pr_content() {
    local type=$1  # "title" 또는 "body"

    if [ "$type" = "title" ]; then
        PROMPT="다음 커밋 메시지들을 분석하여 간결하고 명확한 PR 제목을 한 줄로 생성해주세요.
커밋 메시지 컨벤션(feat:, fix:, refactor: 등)을 포함하여 작성해주세요.

커밋 메시지들:
$COMMIT_MESSAGES

현재 예시 형태: 'fix: 이메일 중복 체크 오류 해결'
위 형태와 유사하게 작성해주세요. 오직 제목만 반환하고 다른 설명은 포함하지 마세요."
    else
        PROMPT="다음 커밋 메시지들을 분석하여 PR 본문을 마크다운 형식으로 생성해주세요.

커밋 메시지들:
$COMMIT_MESSAGES

다음 템플릿 형식을 유지하면서 내용을 채워주세요:

### 변경사항 요약
- (커밋 메시지를 기반으로 한 변경사항들을 요약)

### 관련 이슈
- JIRA: (적절한 이슈 번호가 있다면 포함, 없으면 TODO로 표시)

### 검토 요청사항
- [ ] (변경사항에 따른 적절한 테스트 항목들)

위 형식을 정확히 유지하면서 커밋 메시지 내용을 반영하여 작성해주세요."
    fi

    # JSON 이스케이프 처리
    ESCAPED_PROMPT=$(echo "$PROMPT" | sed 's/"/\\"/g' | tr '\n' ' ')

    # Gemini API 호출
    local response=$(curl -s -X POST \
        -H "Content-Type: application/json" \
        -H "x-goog-api-key: $GEMINI_API_KEY" \
        -d "{
            \"contents\": [{
                \"parts\": [{
                    \"text\": \"$ESCAPED_PROMPT\"
                }]
            }]
        }" \
        "$GEMINI_API_URL")

    # 응답에서 텍스트 추출
    local result=$(echo "$response" | jq -r '.candidates[0].content.parts[0].text' 2>/dev/null)

    if [ "$result" = "null" ] || [ -z "$result" ]; then
        # 에러 메시지 확인
        local error=$(echo "$response" | jq -r '.error.message' 2>/dev/null)
        if [ "$error" != "null" ] && [ -n "$error" ]; then
            echo -e "${RED}API Error: $error${NC}" >&2
        fi
        echo ""
    else
        # 디버깅 출력 제거하고 결과만 반환
        echo "$result"
    fi
}

# PR 제목 생성
echo -e "\n${BLUE}PR 제목을 생성하는 중...${NC}"
PR_TITLE=$(generate_pr_content "title")

if [ -z "$PR_TITLE" ] || [ "$PR_TITLE" = "null" ]; then
    echo -e "${RED}Error: PR 제목 생성에 실패했습니다.${NC}"
    exit 1
fi

# PR 본문 생성
echo -e "${BLUE}PR 본문을 생성하는 중...${NC}"
PR_BODY=$(generate_pr_content "body")

if [ -z "$PR_BODY" ] || [ "$PR_BODY" = "null" ]; then
    echo -e "${RED}Error: PR 본문 생성에 실패했습니다.${NC}"
    exit 1
fi

# 템플릿 파일 업데이트
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
PR_TEMPLATES_DIR="$REPO_ROOT/scripts/templates"

echo -e "\n${GREEN}생성된 PR 제목:${NC}"
echo "$PR_TITLE"

echo -e "\n${GREEN}생성된 PR 본문:${NC}"
echo "$PR_BODY"

# 파일에 저장
echo "$PR_TITLE" > "$PR_TEMPLATES_DIR/pr_title.txt"
echo "$PR_BODY" > "$PR_TEMPLATES_DIR/pr_body.md"

echo -e "\n${GREEN}✅ PR 템플릿이 성공적으로 업데이트되었습니다!${NC}"
echo -e "${BLUE}📁 파일 위치:${NC}"
echo -e "  - 제목: $PR_TEMPLATES_DIR/pr_title.txt"
echo -e "  - 본문: $PR_TEMPLATES_DIR/pr_body.md"

# 생성된 파일 내용 자동 출력
echo -e "\n${YELLOW}=== PR 제목 파일 ====${NC}"
cat "$PR_TEMPLATES_DIR/pr_title.txt"
echo -e "\n${YELLOW}=== PR 본문 파일 ====${NC}"
cat "$PR_TEMPLATES_DIR/pr_body.md"
