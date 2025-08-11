#!/bin/bash

# 공통 환경변수 로드 함수
load_env() {
    # 현재 디렉토리 또는 스크립트 디렉토리에서 .env 파일 찾기
    local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    local env_file=""

    # 프로젝트 루트(.git이 있는 최상위 디렉토리)의 .env 를 우선 사용하도록 변경
    # 1) git이 있는 레포 루트의 .env를 사용 (존재하면 무조건 우선)
    repo_root="$(git rev-parse --show-toplevel 2>/dev/null || true)"
    if [ -n "$repo_root" ] && [ -f "$repo_root/.env" ]; then
        env_file="$repo_root/.env"
    # 2) git 레포 루트에 .env가 없거나 git이 없을 경우, 현재 작업 디렉토리의 .env만 사용
    elif [ -f ".env" ]; then
        env_file=".env"
    else
        # 명시적으로 루트 .env만 사용하도록 간소화: 다른 위치(fallback)는 더 이상 자동으로 참조하지 않습니다.
        env_file=""
    fi

    if [ -n "$env_file" ]; then
        echo "Loading environment variables from: $env_file"
        export $(grep -v '^#' "$env_file" | xargs)
    else
        echo "Warning: .env file not found. Using default values or environment variables."
    fi
}

# 기본값 설정
set_defaults() {
    export GEMINI_API_URL="${GEMINI_API_URL:-https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent}"
    export DEFAULT_BASE_BRANCH="${DEFAULT_BASE_BRANCH:-main}"
    export HOTFIX_BRANCH_PREFIX="${HOTFIX_BRANCH_PREFIX:-fix/}"
    export JIRA_BASE_URL="${JIRA_BASE_URL:-https://your-company.atlassian.net/browse/}"
}

# 색상 정의
export RED='\033[0;31m'
export GREEN='\033[0;32m'
export YELLOW='\033[1;33m'
export BLUE='\033[0;34m'
export NC='\033[0m' # No Color
