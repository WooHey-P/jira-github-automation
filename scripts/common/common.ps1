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

    # 현재 디렉토리 우선, 스크립트 디렉토리, 상위 디렉토리 순으로 검색
    if (Test-Path ".\.env") {
        $envFile = ".\.env"
    } elseif (Test-Path (Join-Path $scriptDir ".env")) {
        $envFile = (Join-Path $scriptDir ".env")
    } elseif (Test-Path (Join-Path $scriptDir "..\.env")) {
        $envFile = (Join-Path $scriptDir "..\.env")
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
