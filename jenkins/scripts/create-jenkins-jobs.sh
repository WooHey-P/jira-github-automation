#!/bin/bash

# Jenkins 작업 자동 생성 스크립트
# Jenkins CLI를 사용하여 파이프라인 작업들을 생성합니다.
# 모든 설정은 프로젝트 루트의 .env에서 로드됩니다. (CLI 옵션 사용 금지)

set -e

# .env 로드: 프로젝트 루트의 .env
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
ENV_FILE="$REPO_ROOT/.env"

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_step() {
    echo -e "${GREEN}[STEP]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# .env 파일이 있으면 로드
if [[ -f "$ENV_FILE" ]]; then
    print_step "환경변수 로드: $ENV_FILE"
    set -o allexport
    # shellcheck disable=SC1090
    . "$ENV_FILE"
    set +o allexport
else
    print_error ".env 파일을 찾지 못했습니다: $ENV_FILE"
    exit 1
fi

# 필수값 검증 (.env에서 가져오도록 변경됨)
# 요구되는 변수: JENKINS_URL, JENKINS_USER, JENKINS_PASSWORD, REPO_URL
if [[ -z "$JENKINS_URL" ]]; then
    print_error "JENKINS_URL이 설정되어 있지 않습니다. .env 파일을 확인하세요."
    exit 1
fi

if [[ -z "$JENKINS_USER" ]]; then
    print_error "JENKINS_USER가 설정되어 있지 않습니다. .env 파일을 확인하세요."
    exit 1
fi

if [[ -z "$JENKINS_PASSWORD" ]]; then
    print_error "JENKINS_PASSWORD가 설정되어 있지 않습니다. .env 파일을 확인하세요."
    exit 1
fi

if [[ -z "$REPO_URL" ]]; then
    print_error "REPO_URL이 설정되어 있지 않습니다. .env 파일을 확인하세요."
    exit 1
fi

# JENKINS_CLI_JAR 기본값 지정 (명시되지 않았을 경우)
if [[ -z "$JENKINS_CLI_JAR" ]]; then
    # 기본 위치를 /tmp로 지정 (필요 시 .env에서 override 가능)
    JENKINS_CLI_JAR="/tmp/jenkins-cli.jar"
    print_warning "JENKINS_CLI_JAR이 설정되어 있지 않아 기본값으로 설정합니다: $JENKINS_CLI_JAR"
fi

# PROJECT_PREFIX가 비어있으면 REPO_URL에서 유도 (대문자->소문자, 허용 문자로 치환)
if [[ -z "$PROJECT_PREFIX" ]]; then
    PROJECT_PREFIX=$(basename -s .git "$REPO_URL")
    PROJECT_PREFIX=$(echo "$PROJECT_PREFIX" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9._-]/-/g')
    print_step "PROJECT_PREFIX가 비어 있어 repo URL에서 유도: ${PROJECT_PREFIX}"
fi

# 간단한 보안: 비밀번호는 로그에 바로 찍지 않음
print_step "설정 요약:"
echo "  JENKINS_URL: $JENKINS_URL"
echo "  JENKINS_USER: $JENKINS_USER"
echo "  JENKINS_CLI_JAR: $JENKINS_CLI_JAR"
echo "  REPO_URL: $REPO_URL"
echo "  PROJECT_PREFIX: $PROJECT_PREFIX"

# Jenkins CLI 다운로드 및 준비 (기본 동작: Jenkins CLI 사용)
print_step "Jenkins CLI 다운로드..."
DOWNLOAD_URL="${JENKINS_URL%/}/jnlpJars/jenkins-cli.jar"
TMP_HEADERS="/tmp/jenkins-cli.headers"
HTTP_CODE=""

# 다운로드가 필요한 경우에만 시도 (사용자가 JENKINS_CLI_JAR로 경로 지정 가능)
if [ ! -f "$JENKINS_CLI_JAR" ]; then
    if command -v curl >/dev/null 2>&1; then
        # follow redirects with -L; capture headers into TMP_HEADERS and status into HTTP_CODE
        if [[ -n "$JENKINS_USER" && -n "$JENKINS_PASSWORD" ]]; then
            HTTP_CODE=$(curl -sS -L -w "%{http_code}" -D "$TMP_HEADERS" -u "$JENKINS_USER:$JENKINS_PASSWORD" "$DOWNLOAD_URL" -o "$JENKINS_CLI_JAR" || echo "000")
        else
            HTTP_CODE=$(curl -sS -L -w "%{http_code}" -D "$TMP_HEADERS" "$DOWNLOAD_URL" -o "$JENKINS_CLI_JAR" || echo "000")
        fi
    elif command -v wget >/dev/null 2>&1; then
        if [[ -n "$JENKINS_USER" && -n "$JENKINS_PASSWORD" ]]; then
            wget --server-response --auth-no-challenge --user="$JENKINS_USER" --password="$JENKINS_PASSWORD" "$DOWNLOAD_URL" -O "$JENKINS_CLI_JAR" 2> /tmp/jenkins-cli.wget.headers || true
            HTTP_CODE=$(awk '/^  HTTP/{code=$2} END{print code+0}' /tmp/jenkins-cli.wget.headers 2>/dev/null || echo "000")
            cp /tmp/jenkins-cli.wget.headers "$TMP_HEADERS" 2>/dev/null || true
        else
            wget --server-response "$DOWNLOAD_URL" -O "$JENKINS_CLI_JAR" 2> /tmp/jenkins-cli.wget.headers || true
            HTTP_CODE=$(awk '/^  HTTP/{code=$2} END{print code+0}' /tmp/jenkins-cli.wget.headers 2>/dev/null || echo "000")
            cp /tmp/jenkins-cli.wget.headers "$TMP_HEADERS" 2>/dev/null || true
        fi
    else
        print_error "wget 또는 curl이 설치되어 있지 않아 Jenkins CLI를 다운로드할 수 없습니다."
        exit 1
    fi
fi

# 다운로드된 파일 검증 (강건한 검사: HTTP 코드, 헤더, 파일 크기 판단)
if [[ -f "$JENKINS_CLI_JAR" ]]; then
    FILE_SIZE=$(stat -c%s "$JENKINS_CLI_JAR" 2>/dev/null || stat -f%z "$JENKINS_CLI_JAR" 2>/dev/null || echo 0)
    # HTTP_CODE가 비어있을 수 있으므로 TMP_HEADERS에서 추출 시도
    if [[ -z "$HTTP_CODE" && -f "$TMP_HEADERS" ]]; then
        HTTP_CODE=$(awk '/^HTTP/{code=$2} END{print code+0}' "$TMP_HEADERS" 2>/dev/null || echo "")
    fi
    # Content-Type 확인
    CONTENT_TYPE=""
    if [[ -f "$TMP_HEADERS" ]]; then
        CONTENT_TYPE=$(awk -F': ' '/^[Cc]ontent-Type:/{print $2}' "$TMP_HEADERS" 2>/dev/null | tail -n1 || true)
    fi

    print_step "다운로드 HTTP 상태 코드: ${HTTP_CODE:-unknown}"
    print_step "다운로드된 파일 크기(bytes): ${FILE_SIZE}"
    print_step "다운로드 Content-Type: ${CONTENT_TYPE:-unknown}"

    valid=0
    # 우선: 정상 HTTP 200이면 유효성 검사
    if [[ "${HTTP_CODE:-}" == "200" && "${FILE_SIZE}" -ge 1024 ]]; then
        valid=1
    fi
    # 대체: HTTP 코드가 비어있더라도 Content-Type이 Java archive거나 파일 크기가 충분하면 수용
    if [[ "$valid" -eq 0 ]]; then
        if [[ -n "$CONTENT_TYPE" && "$CONTENT_TYPE" =~ (jar|java-archive|application/java-archive) && "${FILE_SIZE}" -ge 1024 ]]; then
            valid=1
        fi
    fi

    if [[ "$valid" -ne 1 ]]; then
        print_error "Jenkins CLI 다운로드에 실패했거나 유효하지 않은 파일입니다. 서버 응답을 확인하세요."
        [[ -f "$TMP_HEADERS" ]] && print_step "HTTP 헤더 (최대 200줄):" && sed -n '1,200p' "$TMP_HEADERS"
        rm -f "$JENKINS_CLI_JAR" 2>/dev/null || true
        exit 1
    fi
else
    print_error "Jenkins CLI JAR 파일이 존재하지 않습니다: $JENKINS_CLI_JAR"
    exit 1
fi

# Jenkins 연결 테스트 (CLI 사용)
print_step "Jenkins 연결 테스트..."
if ! command -v java >/dev/null 2>&1; then
    print_error "Java가 설치되어 있지 않습니다. 'java' 명령을 설치/설정하세요."
    exit 1
fi

if ! java -jar "$JENKINS_CLI_JAR" -s "$JENKINS_URL" -auth "$JENKINS_USER:$JENKINS_PASSWORD" who-am-i >/dev/null 2>&1; then
    print_error "Jenkins 연결 테스트에 실패했습니다. URL, 사용자, 패스워드(API 토큰)를 확인하세요."
    exit 1
fi

# 작업 XML 템플릿 생성 함수
create_job_xml() {
    local job_name=$1
    local description=$2
    local jenkinsfile_path=$3
    local token=$4
    local filter_expression=$5
    local filter_text=$6

    # XML 특수 문자 이스케이프 함수 (정상 동작하도록 개선)
    escape_xml() {
        local s="$1"
        s=${s//&/&amp;}
        s=${s//</&lt;}
        s=${s//>/&gt;}
        s=${s//\"/&quot;}
        s=${s//\' /&apos;}  # (이전 잘못된 패턴, 즉시 정리)
        s=${s//\' /&apos;}
        s=${s//\'/&apos;}
        printf '%s' "$s"
    }

    local escaped_description
    escaped_description=$(escape_xml "$description")
    local escaped_repo_url
    escaped_repo_url=$(escape_xml "$REPO_URL")
    local escaped_filter_text
    escaped_filter_text=$(escape_xml "$filter_text")
    local escaped_filter_expression
    escaped_filter_expression=$(escape_xml "$filter_expression")

    cat > "/tmp/${job_name}.xml" << EOF
<?xml version='1.1' encoding='UTF-8'?>
<flow-definition plugin="workflow-job">
  <actions/>
  <description>${escaped_description}</description>
  <keepDependencies>false</keepDependencies>
  <properties>
    <org.jenkinsci.plugins.workflow.job.properties.PipelineTriggersJobProperty>
      <triggers>
        <org.jenkinsci.plugins.gwt.GenericTrigger plugin="generic-webhook-trigger">
          <spec></spec>
          <genericVariables>
            <org.jenkinsci.plugins.gwt.GenericVariable>
              <expressionType>JSONPath</expressionType>
              <key>ref</key>
              <value>\$.ref</value>
              <regexpFilter></regexpFilter>
              <defaultValue></defaultValue>
            </org.jenkinsci.plugins.gwt.GenericVariable>
            <org.jenkinsci.plugins.gwt.GenericVariable>
              <expressionType>JSONPath</expressionType>
              <key>action</key>
              <value>\$.action</value>
              <regexpFilter></regexpFilter>
              <defaultValue></defaultValue>
            </org.jenkinsci.plugins.gwt.GenericVariable>
            <org.jenkinsci.plugins.gwt.GenericVariable>
              <expressionType>JSONPath</expressionType>
              <key>pr_target_branch</key>
              <value>\$.pull_request.base.ref</value>
              <regexpFilter></regexpFilter>
              <defaultValue></defaultValue>
            </org.jenkinsci.plugins.gwt.GenericVariable>
            <org.jenkinsci.plugins.gwt.GenericVariable>
              <expressionType>JSONPath</expressionType>
              <key>pr_source_branch</key>
              <value>\$.pull_request.head.ref</value>
              <regexpFilter></regexpFilter>
              <defaultValue></defaultValue>
            </org.jenkinsci.plugins.gwt.GenericVariable>
          </genericVariables>
          <regexpFilterText>${escaped_filter_text}</regexpFilterText>
          <regexpFilterExpression>${escaped_filter_expression}</regexpFilterExpression>
          <printPostContent>true</printPostContent>
          <printContributedVariables>true</printContributedVariables>
          <causeString>Triggered by GitHub webhook</causeString>
          <token>${token}</token>
          <tokenCredentialId></tokenCredentialId>
          <silentResponse>false</silentResponse>
          <overrideQuietPeriod>false</overrideQuietPeriod>
          <shouldNotFlatten>false</shouldNotFlatten>
          <allowSeveralTriggersPerBuild>false</allowSeveralTriggersPerBuild>
        </org.jenkinsci.plugins.gwt.GenericTrigger>
      </triggers>
    </org.jenkinsci.plugins.workflow.job.properties.PipelineTriggersJobProperty>
    <org.jenkinsci.plugins.workflow.job.properties.DisableConcurrentBuildsJobProperty/>
  </properties>
  <definition class="org.jenkinsci.plugins.workflow.cps.CpsScmFlowDefinition" plugin="workflow-cps">
    <scm class="hudson.plugins.git.GitSCM" plugin="git">
      <configVersion>2</configVersion>
      <userRemoteConfigs>
        <hudson.plugins.git.UserRemoteConfig>
          <url>${escaped_repo_url}</url>
          <credentialsId>github-credentials</credentialsId>
        </hudson.plugins.git.UserRemoteConfig>
      </userRemoteConfigs>
      <branches>
        <hudson.plugins.git.BranchSpec>
          <name>*/master</name>
        </hudson.plugins.git.BranchSpec>
      </branches>
      <doGenerateSubmoduleConfigurations>false</doGenerateSubmoduleConfigurations>
      <submoduleCfg class="list"/>
      <extensions/>
    </scm>
    <scriptPath>${jenkinsfile_path}</scriptPath>
    <lightweight>true</lightweight>
  </definition>
  <triggers/>
  <disabled>false</disabled>
</flow-definition>
EOF
}

# 작업 생성 함수 (Jenkins CLI 사용)
create_jenkins_job() {
    local job_name=$1
    local xml_file="/tmp/${job_name}.xml"
    local debug_file="/tmp/debug-${job_name}.xml"

    print_step "Jenkins 작업 생성: ${job_name}"

    # 보관용으로 xml 복사 (문제 발생 시 디버깅을 위해 유지)
    if [[ -f "$xml_file" ]]; then
        cp "$xml_file" "$debug_file" 2>/dev/null || true
    fi

    if java -jar "$JENKINS_CLI_JAR" -s "$JENKINS_URL" -auth "$JENKINS_USER:$JENKINS_PASSWORD" get-job "$job_name" &>/dev/null; then
        print_warning "작업 '${job_name}'이 이미 존재합니다. 업데이트합니다..."
        if ! java -jar "$JENKINS_CLI_JAR" -s "$JENKINS_URL" -auth "$JENKINS_USER:$JENKINS_PASSWORD" update-job "$job_name" < "$xml_file"; then
            print_error "작업 업데이트 실패: $job_name"
            echo ""
            print_step "디버그용 XML 파일 위치: ${debug_file}"
            # 원본 파일은 문제 원인 분석을 위해 삭제하지 않음
            exit 1
        fi
    else
        if ! java -jar "$JENKINS_CLI_JAR" -s "$JENKINS_URL" -auth "$JENKINS_USER:$JENKINS_PASSWORD" create-job "$job_name" < "$xml_file"; then
            print_error "작업 생성 실패: $job_name"
            echo ""
            print_step "디버그용 XML 파일 위치: ${debug_file}"
            # 원본 파일은 문제 원인 분석을 위해 삭제하지 않음
            exit 1
        fi
    fi

    # 성공 시 임시 파일과 디버그 파일 정리
    rm -f "$xml_file" "$debug_file" 2>/dev/null || true
}

print_step "Jenkins 파이프라인 작업들을 생성합니다..."

# 1. Unit Tests 작업
create_job_xml \
    "${PROJECT_PREFIX}-unit-tests" \
    "단위 테스트 실행 - feature 브랜치에서 develop으로 PR 생성 시" \
    "jenkins/pipelines/Jenkinsfile.unit-tests" \
    "${PROJECT_PREFIX}-unit-tests-trigger" \
    "^(opened|synchronize|reopened) develop/.*" \
    "\$action \$pr_target_branch"

create_jenkins_job "${PROJECT_PREFIX}-unit-tests"

# 2. Dev Build 작업
create_job_xml \
    "${PROJECT_PREFIX}-dev-build" \
    "개발 빌드 & 배포 - develop 브랜치 푸시 시" \
    "jenkins/pipelines/Jenkinsfile.dev-build" \
    "${PROJECT_PREFIX}-dev-build-trigger" \
    "^refs/heads/develop/.*" \
    "\$ref"

create_jenkins_job "${PROJECT_PREFIX}-dev-build"

# 3. Staging Build 작업
create_job_xml \
    "${PROJECT_PREFIX}-staging-build" \
    "스테이징 빌드 & 배포 - release 브랜치 푸시 시" \
    "jenkins/pipelines/Jenkinsfile.staging-build" \
    "${PROJECT_PREFIX}-staging-build-trigger" \
    "^refs/heads/release/.*" \
    "\$ref"

create_jenkins_job "${PROJECT_PREFIX}-staging-build"

# 4. Production Deploy 작업
create_job_xml \
    "${PROJECT_PREFIX}-production-deploy" \
    "프로덕션 배포 - master 브랜치 푸시 시" \
    "jenkins/pipelines/Jenkinsfile.production-deploy" \
    "${PROJECT_PREFIX}-production-deploy-trigger" \
    "^refs/heads/master\$" \
    "\$ref"

create_jenkins_job "${PROJECT_PREFIX}-production-deploy"

print_step "모든 Jenkins 작업이 생성되었습니다!"

echo ""
echo "🎉 Jenkins 파이프라인 작업 생성 완료!"
echo ""
echo "생성된 작업들:"
echo "- ${PROJECT_PREFIX}-unit-tests (토큰: ${PROJECT_PREFIX}-unit-tests-trigger)"
echo "- ${PROJECT_PREFIX}-dev-build (토큰: ${PROJECT_PREFIX}-dev-build-trigger)"
echo "- ${PROJECT_PREFIX}-staging-build (토큰: ${PROJECT_PREFIX}-staging-build-trigger)"
echo "- ${PROJECT_PREFIX}-production-deploy (토큰: ${PROJECT_PREFIX}-production-deploy-trigger)"
echo ""
echo "📋 다음 단계:"
echo "1. Jenkins 대시보드에서 생성된 작업들을 확인하세요"
echo "2. GitHub 웹훅을 설정하세요 (jenkins/docs/webhook-setup.md 참고)"
echo "3. 필요한 Credentials를 Jenkins에 추가하세요"
echo "4. 테스트 빌드를 실행하여 설정을 검증하세요"
echo ""
echo "🔗 GitHub 웹훅 URL: ${JENKINS_URL}/generic-webhook-trigger/invoke"

# 임시 파일 정리: 없음 (Jenkins CLI를 사용하지 않으므로 별도 삭제 불필요)
