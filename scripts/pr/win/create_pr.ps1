# PowerShell: create_pr.ps1 (win/create_pr.ps1)
# 목적: create_pr.sh 와 동일 동작을 수행하는 PowerShell 포팅본
# 사용: powershell -ExecutionPolicy Bypass -File .\create_pr.ps1

# 공통 유틸 로드
$scriptDir = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Definition }
$commonPath = Join-Path $scriptDir "common.ps1"
if (-not (Test-Path $commonPath)) {
    $alt = Join-Path $scriptDir "..\win\common.ps1"
    if (Test-Path $alt) { $commonPath = $alt }
}
if (Test-Path $commonPath) { . $commonPath } else {
    Write-Host "Error: common.ps1 를 찾을 수 없습니다. ($commonPath)" -ForegroundColor Red
    exit 1
}

# 가능한 PR 템플릿 위치들 (원래 create_pr.sh 과 유사 동작을 맞추기 위해 여러 경로 체크)
$possibleTitlePaths = @(
    (Join-Path $scriptDir "pr_templates\pr_title.txt"),
    (Join-Path $scriptDir "..\pr_templates\pr_title.txt"),
    (Join-Path $scriptDir "..\scripts\pr_templates\pr_title.txt"),
    (Join-Path $scriptDir "..\..\pr_templates\pr_title.txt")
)
$possibleBodyPaths = $possibleTitlePaths -replace 'pr_title.txt','pr_body.md'

$TITLE_FILE = $null
$BODY_FILE = $null
foreach ($p in $possibleTitlePaths) {
    if (Test-Path $p) { $TITLE_FILE = (Resolve-Path $p).Path; break }
}
foreach ($p in $possibleBodyPaths) {
    if (Test-Path $p) { $BODY_FILE = (Resolve-Path $p).Path; break }
}

if (-not $TITLE_FILE -or -not $BODY_FILE) {
    Write-ErrorMsg "❌ 템플릿 파일이 존재하지 않습니다. 검색한 경로들 중에서 찾을 수 없습니다."
    Write-Host "검색 경로 예시:"
    $possibleTitlePaths | ForEach-Object { Write-Host "  - $_" }
    exit 1
}

Write-Info "🚀 PR을 생성할 대상 브랜치를 선택하세요:"
Write-Host "┌────────────────────────────┐"
Write-Host "│ 1) develop 브랜치          │"
Write-Host "│ 2) release 브랜치          │"
Write-Host "└────────────────────────────┘"
$TARGET_INPUT = Read-Host "👉 번호 입력 (1 또는 2)"

if ($TARGET_INPUT -eq "1") {
    $BASE_PREFIX = "develop"
} elseif ($TARGET_INPUT -eq "2") {
    $BASE_PREFIX = "release"
} else {
    Write-ErrorMsg "❌ 잘못된 입력입니다. 1 또는 2만 입력해주세요."
    exit 1
}

Write-Host "┌────────────────────────────────────────┐"
$VERSION = Read-Host "│ 📦 대상 버전 입력 (예: 1.2.3): "
Write-Host "└────────────────────────────────────────┘"

if ($VERSION -notmatch '^[0-9]+\.[0-9]+\.[0-9]+$') {
    Write-ErrorMsg "❌ 버전 형식이 올바르지 않습니다. 예: 1.2.3"
    exit 1
}

$BASE_BRANCH = "$BASE_PREFIX/$VERSION"

# 현재 브랜치 조회
$currentBranch = (& git symbolic-ref --short HEAD) 2>&1
$currentBranch = $currentBranch.Trim()
Write-Host ""
Write-Info "📋 현재 브랜치: $currentBranch"
Write-Info "🔁 병합 대상 브랜치: $BASE_BRANCH"
Write-Host ""

Write-Host "┌──────────────────────────────────────────────┐"
$CONFIRM = Read-Host "│ ✅ 위 브랜치를 생성할까요? (y/n): "
Write-Host "└──────────────────────────────────────────────┘"
if ($CONFIRM -notin @("y","Y")) {
    Write-Host "🚫 작업이 취소되었습니다."
    exit 0
}

# gh CLI를 사용하여 PR 생성
try {
    $title = Get-Content $TITLE_FILE -Raw
    $body  = Get-Content $BODY_FILE -Raw

    # gh pr create 실행 (PowerShell에서 외부 인자에 개행/따옴표가 포함될 수 있으므로 임시 파일 사용)
    $tmpTitle = New-TemporaryFile
    $tmpBody  = New-TemporaryFile
    Set-Content -Path $tmpTitle -Value $title -Encoding UTF8
    Set-Content -Path $tmpBody -Value $body -Encoding UTF8

    $ghArgs = @(
        "pr", "create",
        "--title", "@$tmpTitle",
        "--body",  "@$tmpBody",
        "--base",  $BASE_BRANCH,
        "--head",  $currentBranch,
        "--web"
    )

    & gh @ghArgs
    $exitCode = $LASTEXITCODE
    # 임시 파일 정리
    Remove-Item $tmpTitle -ErrorAction SilentlyContinue
    Remove-Item $tmpBody  -ErrorAction SilentlyContinue

    if ($exitCode -ne 0) {
        Write-ErrorMsg "gh pr create 실행 중 오류가 발생했습니다. exit code: $exitCode"
        exit $exitCode
    }
} catch {
    Write-ErrorMsg "PR 생성 실패: $($_.Exception.Message)"
    exit 1
}
