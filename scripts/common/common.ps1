# PowerShell 공통 유틸리티 (win/common.ps1)
# - .env 로드 함수: Load-Env
# - 기본값 설정: Set-Defaults
# - 색상 출력 헬퍼: Write-Info / Write-Success / Write-Warn / Write-ErrorMsg
# 사용: 다른 .ps1 스크립트에서 dot-source 하여 사용하세요.
# 예: . "$PSScriptRoot\common.ps1"

function Load-Env {
    param()

    $scriptDir = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Definition }
    $envFile = $null

    # 프로젝트 루트(.git이 있는 최상위 디렉토리)의 .env 를 우선 사용하도록 간소화
    # 1) scriptDir에서 위로 올라가며 .git 폴더가 있는 최상위(레포 루트)를 찾음
    $dir = $scriptDir
    while ($dir -and -not (Test-Path (Join-Path $dir ".git"))) {
        $parent = Split-Path $dir -Parent
        if ($parent -eq $dir) { break }
        $dir = $parent
    }
    # 2) 레포 루트의 .env가 있으면 사용, 없으면 현재 작업 디렉토리의 .env만 사용
    if ($dir -and (Test-Path (Join-Path $dir ".env"))) {
        $envFile = (Join-Path $dir ".env")
    } elseif (Test-Path ".\.env") {
        $envFile = ".\.env"
    } else {
        $envFile = $null
    }

    if ($envFile) {
        Write-Host "Loading environment variables from: $envFile"
        Get-Content $envFile | ForEach-Object {
            $line = $_.Trim()
            if ($line -eq "" -or $line -match '^\s*#') { return }
            if ($line -match '^\s*([^=]+)=(.*)$') {
                $name = $matches[1].Trim()
                $value = $matches[2].Trim()
                # 따옴표 제거
                if ($value -match '^"(.*)"$') { $value = $value -replace '^"(.*)"$','$1' }
                if ($value -match "^'(.*)'$") { $value = $value -replace "^'(.*)'$","$1" }
                Set-Item -Path ("Env:" + $name) -Value $value -Force
            }
        }
    } else {
        Write-Host "Warning: .env 파일을 찾을 수 없습니다. 환경 변수 또는 기본값 사용."
    }
}

function Set-Defaults {
    param()

    if (-not $env:GEMINI_API_URL) { $env:GEMINI_API_URL = "https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent" }
    if (-not $env:DEFAULT_BASE_BRANCH) { $env:DEFAULT_BASE_BRANCH = "main" }
    if (-not $env:FEATURE_BRANCH_PREFIX) { $env:FEATURE_BRANCH_PREFIX = "story/" }
    if (-not $env:HOTFIX_BRANCH_PREFIX) { $env:HOTFIX_BRANCH_PREFIX = "fix/" }
    if (-not $env:JIRA_BASE_URL) { $env:JIRA_BASE_URL = "https://your-company.atlassian.net/browse/" }
}

# 색상 출력 헬퍼
function Write-Info([string]$msg)    { Write-Host $msg -ForegroundColor Cyan }
function Write-Success([string]$msg) { Write-Host $msg -ForegroundColor Green }
function Write-Warn([string]$msg)    { Write-Host $msg -ForegroundColor Yellow }
function Write-ErrorMsg([string]$msg){ Write-Host $msg -ForegroundColor Red }

# 모듈처럼 dot-source 후 바로 사용 가능하도록 반환값 없음
