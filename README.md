# Jira-GitHub Automation Scripts

Jira 이슈 키 기반 브랜치 생성부터 AI 기반 PR 자동화까지, 개발 워크플로우를 완전 자동화하는 스크립트 모음입니다.

## 🚀 주요 기능

### 1. Jira 기반 브랜치 자동 생성 (`scripts/branch/*/create_branches.sh`)
- **정규 배포**: `feature/JIRA-123` 형태의 브랜치 생성
- **핫픽스**: `fix/JIRA-456` 형태의 브랜치 생성
- Jira 이슈 키 검증 및 자동 브랜치명 생성

### 2. AI 기반 PR 템플릿 자동화 (`scripts/pr/*/auto_fill_pr.sh`)
- **Gemini AI** 활용하여 커밋 메시지 분석
- PR 제목과 본문 자동 생성
- 기존 PR 템플릿과 연동

### 3. GitHub PR 자동 생성 (`scripts/pr/*/create_pr.sh`)
- GitHub CLI 기반 PR 생성
- 템플릿 기반 PR 본문 자동 적용
- Release 브랜치 자동 감지

### 4. PR 템플릿 (`scripts/templates/`)
- 일관된 PR 형식 제공
- 제목 및 본문 템플릿

## 📋 워크플로우

```
Jira 이슈 생성 → 브랜치 생성 → 개발 → AI PR 생성 → GitHub PR
    ↓              ↓           ↓         ↓         ↓
  JIRA-123   feature/JIRA-123  커밋   AI 분석   자동 PR
```

## 🛠 설치 및 사용법

### Git 서브모듈로 추가
```bash
# 프로젝트 루트에서 실행
git submodule add https://github.com/YOUR_USERNAME/jira-github-automation.git scripts

# 서브모듈 초기화
git submodule update --init --recursive
```

### 개별 스크립트 사용
```bash
# macOS (bash)
# 1. Jira 이슈 기반 브랜치 생성
./scripts/branch/mac/create_branches.sh

# 2. AI 기반 PR 템플릿 생성
./scripts/pr/mac/auto_fill_pr.sh

# 3. GitHub PR 생성
./scripts/pr/mac/create_pr.sh

# Windows (PowerShell)
# 1. Jira 이슈 기반 브랜치 생성
powershell -ExecutionPolicy Bypass -File .\scripts\branch\win\create_branches.ps1

# 2. AI 기반 PR 템플릿 생성
powershell -ExecutionPolicy Bypass -File .\scripts\pr\win\auto_fill_pr.ps1

# 3. GitHub PR 생성
powershell -ExecutionPolicy Bypass -File .\scripts\pr\win\create_pr.ps1
```

## ⚙️ 필수 설정

### 환경변수 설정
```bash
# 1. .env 파일 생성 (.env.example을 복사)
cp .env.example .env

# 2. .env 파일 편집
vim .env
```

### .env 파일 설정 예시
```bash
# Gemini AI API Configuration
GEMINI_API_KEY=your_actual_gemini_api_key_here
GEMINI_API_URL=https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent

# Git Configuration
DEFAULT_BASE_BRANCH=main
GITHUB_USERNAME=your_github_username

# Branch Naming Configuration
FEATURE_BRANCH_PREFIX=story/
HOTFIX_BRANCH_PREFIX=fix/

# Jira Configuration
JIRA_BASE_URL=https://your-company.atlassian.net/browse/
```

### 필수 도구
- **GitHub CLI** (`gh`)
- **Git**
- **jq** (JSON 파싱)
- **curl**

### GitHub CLI 설정
```bash
# GitHub CLI 설치 및 인증
brew install gh
gh auth login
```

## 📝 사용 예시

### 1. 정규 개발 플로우
```bash
# JIRA-1234 이슈로 feature 브랜치 생성
./scripts/branch/mac/create_branches.sh
# → 입력: 1 (정규), JIRA-1234
# → 결과: feature/JIRA-1234 브랜치 생성

# 개발 후 AI 기반 PR 생성
./scripts/pr/mac/auto_fill_pr.sh
# → AI가 커밋 메시지 분석하여 PR 템플릿 생성

# GitHub PR 생성
./scripts/pr/mac/create_pr.sh
```

### 2. 핫픽스 플로우
```bash
# 긴급 수정을 위한 hotfix 브랜치 생성
./scripts/branch/mac/create_branches.sh
# → 입력: 2 (핫픽스), SIGN-5678
# → 결과: fix/SIGN-5678 브랜치 생성
```

## 🔄 서브모듈 업데이트

```bash
# 최신 스크립트로 업데이트
git submodule update --remote scripts

# 변경사항 커밋
git add scripts
git commit -m "Update automation scripts"
```

## 🤝 기여하기

1. Fork this repository
2. Create feature branch (`git checkout -b feature/amazing-feature`)
3. Commit changes (`git commit -m 'Add amazing feature'`)
4. Push to branch (`git push origin feature/amazing-feature`)
5. Open Pull Request

## 📄 라이선스

MIT License - 자유롭게 사용하세요!
