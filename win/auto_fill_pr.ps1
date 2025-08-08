# PowerShell: auto_fill_pr.ps1 (win/auto_fill_pr.ps1)
# 목적: auto_fill_pr.sh 와 동일한 동작을 하는 PowerShell 포팅본
# 사용: PowerShell에서 실행 (예: powershell -ExecutionPolicy Bypass -File .\auto_fill_pr.ps1)

# dot-source 공통 유틸리티
$scriptDir = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Definition }
$commonPath = Join-Path $scriptDir "common.ps1"
if (-not (Test-Path $commonPath)) {
    # common.ps1이 win/에 없으면 상위 폴더에서 시도
    $alt = Join-Path $scriptDir "..\win\common.ps1"
    if (Test-Path $alt) { $commonPath = $alt }
}
if (Test-Path $commonPath) { . $commonPath } else {
    Write-Host "Error: common.ps1 를 찾을 수 없습니다. ($commonPath)" -ForegroundColor Red
    exit 1
}

Load-Env
Set-Defaults

Write-Info "🚀 PR 템플릿을 AI로 자동 생성하시겠습니까?"
Write-Info "현재 브랜치의 커밋 메시지를 분석하여 PR 제목과 본문을 생성합니다."
$answer = Read-Host "계속하시겠습니까? (Y/n)"
if ($answer -match '^[Nn]') {
    Write-Warn "취소되었습니다."
    exit 0
}

# git 레포 확인
if (-not (Test-Path ".git")) {
    Write-ErrorMsg "Error: 현재 디렉토리가 git 레포지토리가 아닙니다."
    exit 1
}

# GEMINI_API_KEY 확인
if (-not $env:GEMINI_API_KEY) {
    Write-ErrorMsg "Error: GEMINI_API_KEY 환경변수가 설정되지 않았습니다."
    Write-Warn ".env 파일을 생성하거나 환경변수를 설정해주세요: setx GEMINI_API_KEY 'your_api_key' (새 세션 필요)"
    exit 1
}

# 현재 브랜치
$currentBranch = (& git branch --show-current) 2>&1
$currentBranch = $currentBranch.Trim()
Write-Info "현재 브랜치: $currentBranch"

# release 브랜치 찾기 (원격, 최신)
$remoteBranches = (& git branch -r) -join "`n"
$releaseMatches = Select-String -InputObject $remoteBranches -Pattern 'origin/release/[0-9]+\.[0-9]+\.[0-9]+' -AllMatches |
    ForEach-Object { $_.Matches } | ForEach-Object { $_.Value -replace '^origin/','' }

# 정렬: 단순 버전 정렬 (문자열 기준으로도 괜찮음)
if ($releaseMatches) {
    $releaseBranches = $releaseMatches | Sort-Object {[version]($_ -replace 'release/','')}
    $releaseBranch = $releaseBranches[-1]
} else {
    Write-Warn "Warning: release/x.x.x 형태의 브랜치를 찾을 수 없습니다. $($env:DEFAULT_BASE_BRANCH) 브랜치를 기준으로 사용합니다."
    $releaseBranch = $env:DEFAULT_BASE_BRANCH
}

Write-Info "기준 브랜치: $releaseBranch"

# 커밋 메시지 수집
Write-Info "커밋 메시지를 수집하는 중..."
$commitMessages = (& git log --oneline "$releaseBranch..$currentBranch" --pretty=format:"- %s") 2>&1
if (-not $commitMessages -or $commitMessages -match 'fatal') {
    Write-Warn "Warning: 커밋 메시지를 찾을 수 없습니다. 현재 브랜치의 최근 10개 커밋을 사용합니다."
    $commitMessages = (& git log --oneline -10 --pretty=format:"- %s") -join "`n"
} else {
    $commitMessages = $commitMessages -join "`n"
}

Write-Success "수집된 커밋 메시지:"
Write-Host $commitMessages

function Generate-PrContent {
    param(
        [Parameter(Mandatory=$true)][ValidateSet("title","body")] [string]$Type,
        [string]$CommitMessages
    )

    if ($Type -eq "title") {
        $prompt = @"
다음 커밋 메시지들을 분석하여 간결하고 명확한 PR 제목을 한 줄로 생성해주세요.
커밋 메시지 컨벤션(feat:, fix:, refactor: 등)을 포함하여 작성해주세요.

커밋 메시지들:
$CommitMessages

현재 예시 형태: 'fix: 이메일 중복 체크 오류 해결'
위 형태와 유사하게 작성해주세요. 오직 제목만 반환하고 다른 설명은 포함하지 마세요.
"@
    } else {
        $prompt = @"
다음 커밋 메시지들을 분석하여 PR 본문을 마크다운 형식으로 생성해주세요.

커밋 메시지들:
$CommitMessages

다음 템플릿 형식을 유지하면서 내용을 채워주세요:

### 변경사항 요약
- (커밋 메시지를 기반으로 한 변경사항들을 요약)

### 관련 이슈
- JIRA: (적절한 이슈 번호가 있다면 포함, 없으면 TODO로 표시)

### 검토 요청사항
- [ ] (변경사항에 따른 적절한 테스트 항목들)

위 형식을 정확히 유지하면서 커밋 메시지 내용을 반영하여 작성해주세요.
"@
    }

    # 요청 페이로드 구성
    $payload = @{
        contents = @(
            @{
                parts = @(
                    @{ text = $prompt }
                )
            }
        )
    }

    try {
        $response = Invoke-RestMethod -Uri $env:GEMINI_API_URL -Method Post -Headers @{
            "Content-Type" = "application/json"
            "x-goog-api-key" = $env:GEMINI_API_KEY
        } -Body (ConvertTo-Json $payload -Depth 10) -ErrorAction Stop

        # 응답에서 텍스트 추출
        if ($response.candidates -and $response.candidates.Count -gt 0) {
            $text = $response.candidates[0].content.parts[0].text
            return $text
        } else {
            # 에러가 있을 수 있음
            if ($response.error -and $response.error.message) {
                Write-ErrorMsg "API Error: $($response.error.message)"
            }
            return $null
        }
    } catch {
        Write-ErrorMsg "API 호출 실패: $($_.Exception.Message)"
        return $null
    }
}

# PR 제목 생성
Write-Info "`nPR 제목을 생성하는 중..."
$prTitle = Generate-PrContent -Type "title" -CommitMessages $commitMessages
if (-not $prTitle) {
    Write-ErrorMsg "Error: PR 제목 생성에 실패했습니다."
    exit 1
}

# PR 본문 생성
Write-Info "`nPR 본문을 생성하는 중..."
$prBody = Generate-PrContent -Type "body" -CommitMessages $commitMessages
if (-not $prBody) {
    Write-ErrorMsg "Error: PR 본문 생성에 실패했습니다."
    exit 1
}

# 템플릿 저장 디렉토리
$prTemplatesDir = Join-Path $scriptDir "..\pr_templates"
$prTemplatesDir = (Resolve-Path $prTemplatesDir).Path

# 디렉토리 존재 확인
if (-not (Test-Path $prTemplatesDir)) {
    New-Item -ItemType Directory -Path $prTemplatesDir -Force | Out-Null
}

# 파일 쓰기
Set-Content -Path (Join-Path $prTemplatesDir "pr_title.txt") -Value $prTitle -Encoding UTF8
Set-Content -Path (Join-Path $prTemplatesDir "pr_body.md") -Value $prBody -Encoding UTF8

Write-Success "`n✅ PR 템플릿이 성공적으로 업데이트되었습니다!"
Write-Host "  - 제목: $prTemplatesDir\pr_title.txt"
Write-Host "  - 본문: $prTemplatesDir\pr_body.md"

Write-Host "`n=== PR 제목 파일 ===="
Get-Content (Join-Path $prTemplatesDir "pr_title.txt") | Write-Host
Write-Host "`n=== PR 본문 파일 ===="
Get-Content (Join-Path $prTemplatesDir "pr_body.md") | Write-Host
