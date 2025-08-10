#!/bin/bash

# 공통 환경변수 로드 함수
load_env() {
    # 현재 디렉토리 또는 스크립트 디렉토리에서 .env 파일 찾기
    local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    local env_file=""

    # 현재 디렉토리에서 .env 파일 확인
    if [ -f ".env" ]; then
        env_file=".env"
    # 스크립트 디렉토리에서 .env 파일 확인
    elif [ -f "$script_dir/.env" ]; then
        env_file="$script_dir/.env"
    # 프로젝트 루트에서 .env 파일 확인 (스크립트가 하위 폴더에 있는 경우)
    elif [ -f "$script_dir/../.env" ]; then
        env_file="$script_dir/../.env"
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
    export FEATURE_BRANCH_PREFIX="${FEATURE_BRANCH_PREFIX:-story/}"
    export HOTFIX_BRANCH_PREFIX="${HOTFIX_BRANCH_PREFIX:-fix/}"
    export JIRA_BASE_URL="${JIRA_BASE_URL:-https://your-company.atlassian.net/browse/}"
}

# 색상 정의
export RED='\033[0;31m'
export GREEN='\033[0;32m'
export YELLOW='\033[1;33m'
export BLUE='\033[0;34m'
export NC='\033[0m' # No Color
