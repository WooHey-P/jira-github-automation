# PowerShell 버전: create_branches.ps1
# 목적: 기존 create_branches.sh 와 동일한 기능을 Windows(Windows PowerShell / PowerShell Core)에서 동작하도록 포팅한 스크립트
# 사용법: PowerShell에서 실행 (실행 정책에 따라 `.\create_branches.ps1` 전에 실행 정책을 허용해야 할 수 있음)
#   예: powershell -ExecutionPolicy Bypass -File .\create_branches.ps1

# ---------------------------
# 유틸: .env 파일 로딩 & 기본값 설정
# ---------------------------
function Load-Env {
    # PSScriptRoot: 스크립트가 실행되는 디렉토리 (스크립트를 dot-sourcing 하지 않고 실행할 때 사용 가능)
    $scriptDir = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Definition }
    $envFile = $null

    if (Test-Path ".\.env") {
        $envFile = ".\.env"
    } elseif (Test-Path "$scriptDir\.env") {
        $envFile = "$scriptDir\.env"
    } elseif (Test-Path "$scriptDir\..\ .env".Replace("..\ .env","..\ .env")) {
        # (fallback) 상위 폴더의 .env 검사 - 윈도우 경로 처리
        $parentEnv = Join-Path $scriptDir "..\.env"
        if (Test-Path $parentEnv) { $envFile = $parentEnv }
    }

    if ($envFile) {
        Write-Host "Loading environment variables from: $envFile"
        Get-Content $envFile | ForEach-Object {
            $line = $_.Trim()
            if ($line -eq "" -or $line -match '^\s*#') { return }
            if ($line -match '^\s*([^=]+)=(.*)$') {
                $name = $matches[1].Trim()
                $value = $matches[2].Trim()
                # 따옴표로 둘러싸인 값에서 따옴표 제거
                if ($value -match '^"(.*)"$' ) { $value = $matches[1] }
                if ($value -match "^'(.*)'$" ) { $value = $matches[1] }
                Set-Item -Path "Env:$name" -Value $value
            }
        }
    } else {
        Write-Host "Warning: .env 파일을 찾을 수 없습니다. 환경 변수 또는 기본값 사용."
    }
}

function Set-Defaults {
    if (-not $env:GEMINI_API_URL) { $env:GEMINI_API_URL = "https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent" }
    if (-not $env:DEFAULT_BASE_BRANCH) { $env:DEFAULT_BASE_BRANCH = "main" }
    if (-not $env:FEATURE_BRANCH_PREFIX) { $env:FEATURE_BRANCH_PREFIX = "story/" }
    if (-not $env:HOTFIX_BRANCH_PREFIX) { $env:HOTFIX_BRANCH_PREFIX = "fix/" }
    if (-not $env:JIRA_BASE_URL) { $env:JIRA_BASE_URL = "https://your-company.atlassian.net/browse/" }
}

# 로드 및 기본값 설정
Load-Env
Set-Defaults

# 색상 출력을 위한 도움 함수
function Info([string]$msg) { Write-Host $msg -ForegroundColor Cyan }
function Success([string]$msg) { Write-Host $msg -ForegroundColor Green }
function Warn([string]$msg) { Write-Host $msg -ForegroundColor Yellow }
function ErrorMsg([string]$msg) { Write-Host $msg -ForegroundColor Red }

# ---------------------------
# 배포 타입 선택
# ---------------------------
Info "🚀 정규 배포 작업인지, 긴급 배포(핫픽스) 작업인지 선택하세요:"
Write-Host "┌──────────────────────┐"
Write-Host "│ 1) 정규              │"
Write-Host "│ 2) 핫픽스            │"
Write-Host "└──────────────────────┘"
$TYPE_INPUT = Read-Host "👉 번호 입력 (1 또는 2)"

if ($TYPE_INPUT -eq "1") {
    $IS_HOTFIX = $false
} elseif ($TYPE_INPUT -eq "2") {
    $IS_HOTFIX = $true
} else {
    ErrorMsg "❌ 잘못된 입력입니다. 1 또는 2만 입력해주세요."
    exit 1
}

# ---------------------------
# base branch 선택
# ---------------------------
function Prompt-BaseBranch {
    Write-Host ""
    Write-Host "┌──────────────────────────────────────────────┐"
    Write-Host "│ 생성 기준이 될 base branch를 선택하세요:"
    Write-Host "│ 1) main (기본)"
    Write-Host "│ 2) master"
    Write-Host "│ 3) 직접 입력 (영문자+숫자만 허용)"
    Write-Host "└──────────────────────────────────────────────┘"
    $BASE_CHOICE = Read-Host "👉 번호 입력 (1,2 또는 3)"

    if ([string]::IsNullOrWhiteSpace($BASE_CHOICE) -or $BASE_CHOICE -eq "1") {
        $BASE_BRANCH = "main"
    } elseif ($BASE_CHOICE -eq "2") {
        $BASE_BRANCH = "master"
    } elseif ($BASE_CHOICE -eq "3") {
        $CUSTOM_BASE = Read-Host "🔤 직접 입력 (영문자+숫자만)"
        if ($CUSTOM_BASE -notmatch '^[A-Za-z0-9]+$') {
            ErrorMsg "❌ 브랜치 이름은 영문자와 숫자만 허용됩니다."
            exit 1
        }
        $BASE_BRANCH = $CUSTOM_BASE
    } else {
        ErrorMsg "❌ 잘못된 입력입니다. 1, 2 또는 3 중 하나를 입력하세요."
        exit 1
    }
    Success "✅ 선택된 base branch: origin/$BASE_BRANCH"
    return $BASE_BRANCH
}

$BASE_BRANCH = Prompt-BaseBranch

# ---------------------------
# 핫픽스 분기
# ---------------------------
if ($IS_HOTFIX) {
    Write-Host ""
    Write-Host "┌───────────────────────────────────────────┐"
    $ISSUE_KEY = Read-Host "│ 🔧 Hotfix 이슈 키 입력 (예: SIGN-1234)"
    Write-Host "└───────────────────────────────────────────┘"

    if ($ISSUE_KEY -notmatch '^[A-Za-z]+-[0-9]+$') {
        ErrorMsg "❌ 이슈 키 형식이 올바르지 않습니다. 예: SIGN-123"
        exit 1
    }

    $BRANCH_NAME = "$($env:HOTFIX_BRANCH_PREFIX)$ISSUE_KEY"
    Write-Host ""
    Write-Host "📋 생성될 브랜치: $BRANCH_NAME (base: origin/$BASE_BRANCH)"
    $CONFIRM = Read-Host "✅ 위 브랜치를 생성하시겠습니까? (y/n)"

    if ($CONFIRM -notin @("y","Y")) {
        Write-Host "🚫 작업이 취소되었습니다."
        exit 0
    }

    git fetch origin
    if ($LASTEXITCODE -ne 0) { ErrorMsg "git fetch 실패"; exit 1 }

    # 원격에 브랜치 존재 여부 확인
    git ls-remote --exit-code --heads origin $BRANCH_NAME > $null 2>&1
    if ($LASTEXITCODE -eq 0) {
        Warn "⚠️ 브랜치 $BRANCH_NAME 가 이미 존재합니다. 작업을 중단합니다."
        exit 0
    }

    git checkout "origin/$BASE_BRANCH"
    if ($LASTEXITCODE -ne 0) { ErrorMsg "git checkout origin/$BASE_BRANCH 실패"; exit 1 }
    git checkout -b $BRANCH_NAME
    if ($LASTEXITCODE -ne 0) { ErrorMsg "git checkout -b $BRANCH_NAME 실패"; exit 1 }
    git push -u origin $BRANCH_NAME
    if ($LASTEXITCODE -ne 0) { ErrorMsg "git push 실패"; exit 1 }

    Write-Host ""
    Success "✅ hotfix 브랜치 생성 완료: $BRANCH_NAME"
    Write-Host "🔗 Jira: $($env:JIRA_BASE_URL)$ISSUE_KEY"
    exit 0
}

# ---------------------------
# 정규 배포 (Story/Feature) 분기
# ---------------------------

Write-Host ""
Write-Host "┌──────────────────────────────────────────────┐"
$STORY_KEY = Read-Host "│ 📘 상위 Story 키 입력 (예: SIGN-1000)"
Write-Host "└──────────────────────────────────────────────┘"
if ($STORY_KEY -notmatch '^[A-Za-z]+-[0-9]+$') {
    ErrorMsg "❌ Story 키 형식이 올바르지 않습니다."
    exit 1
}

Write-Host "┌──────────────────────────────────────────────┐"
$FEATURE_KEY = Read-Host "│ 📗 하위 Feature 키 입력 (예: SIGN-1001)"
Write-Host "└──────────────────────────────────────────────┘"
if ($FEATURE_KEY -notmatch '^[A-Za-z]+-[0-9]+$') {
    ErrorMsg "❌ Feature 키 형식이 올바르지 않습니다."
    exit 1
}

Write-Host "┌──────────────────────────────────────────────┐"
$DESC_INPUT = Read-Host "│ 📝 간단한 설명 입력 (예: email check)"
Write-Host "└──────────────────────────────────────────────┘"

$ORIGINAL_DESC = $DESC_INPUT

# 1) 공백 -> 하이픈, 2) 소문자화, 3) 연속 하이픈 축소, 4) 앞/뒤 하이픈 제거
$DESC = $DESC_INPUT -replace '\s+', '-'
$DESC = $DESC.ToLower()
$DESC = $DESC -replace '-{2,}', '-'
# Trim leading/trailing hyphens
$DESC = $DESC.Trim('-')

if ($ORIGINAL_DESC -ne $DESC) {
    Write-Host "🔄 자동 변환됨: '$ORIGINAL_DESC' → '$DESC'"
}

if ([string]::IsNullOrWhiteSpace($DESC)) {
    ErrorMsg "❌ 설명이 비어있습니다."
    exit 1
}

if ($DESC -notmatch '^[a-z0-9-]+$') {
    ErrorMsg "❌ 설명에 허용되지 않는 문자가 포함되어 있습니다."
    Write-Host "   허용: 영문, 숫자, 하이픈(-)"
    Write-Host "   변환된 값: $DESC"
    exit 1
}

Success "✅ 최종 설명: $DESC"

Write-Host "┌──────────────────────────────────────────────┐"
$VERSION = Read-Host "│ 🔧 생성할 버전 입력 (형식: x.y.z)"
Write-Host "└──────────────────────────────────────────────┘"
if ($VERSION -notmatch '^[0-9]+\.[0-9]+\.[0-9]+$') {
    ErrorMsg "❌ 버전 형식이 올바르지 않습니다. 예: 1.2.3"
    exit 1
}

$RELEASE_BRANCH = "release/$VERSION"
$DEVELOP_BRANCH = "develop/$VERSION"
$FEATURE_BRANCH = "$($env:FEATURE_BRANCH_PREFIX)$VERSION/$STORY_KEY/feature/$FEATURE_KEY/$DESC"

Write-Host ""
Write-Host "📋 생성될 브랜치 목록:"
Write-Host "   🔹 $RELEASE_BRANCH (base: origin/$BASE_BRANCH)"
Write-Host "   🔹 $DEVELOP_BRANCH (base: $RELEASE_BRANCH)"
Write-Host "   🔹 $FEATURE_BRANCH (base: $RELEASE_BRANCH)"
Write-Host ""

$CONFIRM = Read-Host "✅ 위 브랜치를 생성하시겠습니까? (y/n)"
if ($CONFIRM -notin @("y","Y")) {
    Write-Host "🚫 작업이 취소되었습니다."
    exit 0
}

git fetch origin
if ($LASTEXITCODE -ne 0) { ErrorMsg "git fetch 실패"; exit 1 }

# release 브랜치 생성(원격 체크)
git ls-remote --exit-code --heads origin $RELEASE_BRANCH > $null 2>&1
if ($LASTEXITCODE -eq 0) {
    Write-Host "🔄 $RELEASE_BRANCH 이미 존재. 건너뜁니다."
} else {
    Write-Host "🌱 $RELEASE_BRANCH 생성 중..."
    git checkout "origin/$BASE_BRANCH"
    if ($LASTEXITCODE -ne 0) { ErrorMsg "git checkout origin/$BASE_BRANCH 실패"; exit 1 }
    git checkout -b $RELEASE_BRANCH
    if ($LASTEXITCODE -ne 0) { ErrorMsg "git checkout -b $RELEASE_BRANCH 실패"; exit 1 }
    git push -u origin $RELEASE_BRANCH
    if ($LASTEXITCODE -ne 0) { ErrorMsg "git push 실패"; exit 1 }
}

# develop 브랜치 생성(원격 체크)
git ls-remote --exit-code --heads origin $DEVELOP_BRANCH > $null 2>&1
if ($LASTEXITCODE -eq 0) {
    Write-Host "🔄 $DEVELOP_BRANCH 이미 존재. 건너뜁니다."
} else {
    Write-Host "🌱 $DEVELOP_BRANCH 생성 중..."
    git checkout $RELEASE_BRANCH
    if ($LASTEXITCODE -ne 0) { ErrorMsg "git checkout $RELEASE_BRANCH 실패"; exit 1 }
    git checkout -b $DEVELOP_BRANCH
    if ($LASTEXITCODE -ne 0) { ErrorMsg "git checkout -b $DEVELOP_BRANCH 실패"; exit 1 }
    git push -u origin $DEVELOP_BRANCH
    if ($LASTEXITCODE -ne 0) { ErrorMsg "git push 실패"; exit 1 }
}

# feature 브랜치 (로컬만 생성)
# 로컬 브랜치 존재 여부 체크
git show-ref --verify --quiet "refs/heads/$FEATURE_BRANCH"
if ($LASTEXITCODE -eq 0) {
    Warn "⚠️ $FEATURE_BRANCH 로컬에 이미 존재합니다. 생성을 건너뜁니다."
} else {
    Write-Host "🌱 $FEATURE_BRANCH 생성 중...(로컬)"
    git checkout $RELEASE_BRANCH
    if ($LASTEXITCODE -ne 0) { ErrorMsg "git checkout $RELEASE_BRANCH 실패"; exit 1 }
    git checkout -b $FEATURE_BRANCH
    if ($LASTEXITCODE -ne 0) { ErrorMsg "git checkout -b $FEATURE_BRANCH 실패"; exit 1 }
}

Write-Host ""
Success "✅ 브랜치 생성 완료!"
Write-Host "   🔹 $RELEASE_BRANCH (푸시됨)"
Write-Host "   🔹 $DEVELOP_BRANCH (푸시됨)"
Write-Host "   🔹 $FEATURE_BRANCH (로컬만 생성됨)"
Write-Host ""
Write-Host "🔗 Jira 이슈 바로가기: $($env:JIRA_BASE_URL)$FEATURE_KEY"
