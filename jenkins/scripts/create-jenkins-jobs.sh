#!/bin/bash

# Jenkins 작업 자동 생성 스크립트
# Jenkins CLI를 사용하여 파이프라인 작업들을 생성합니다.

set -e

# 설정 변수: 실제 값들은 .env 또는 jenkins/environment.env 로 이동했습니다.
# 아래 변수들은 빈 값으로 초기화되어 있으며, .env / jenkins/environment.env에서 로드됩니다.
# 값을 변경하려면 프로젝트 루트의 .env 또는 jenkins/environment.env 파일을 편집하세요.
JENKINS_URL=""
JENKINS_USER=""
JENKINS_PASSWORD=""
REPO_URL=""
JENKINS_CLI_JAR=""
PROJECT_PREFIX=""

# .env 로드: 우선순위는 프로젝트 루트의 .env, 없으면 jenkins/environment.env
# (환경 변수가 설정되어 있으면 CLI 인자로 덮어쓸 수 있음)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
ENV_FILE="$REPO_ROOT/.env"
JENKINS_ENV_FILE="$REPO_ROOT/jenkins/environment.env"

if [[ -f "$ENV_FILE" ]]; then
    print_step "환경변수 로드: $ENV_FILE"
    set -o allexport
    # shellcheck disable=SC1090
    . "$ENV_FILE"
    set +o allexport
elif [[ -f "$JENKINS_ENV_FILE" ]]; then
    print_step "환경변수 로드: $JENKINS_ENV_FILE"
    set -o allexport
    # shellcheck disable=SC1090
    . "$JENKINS_ENV_FILE"
    set +o allexport
else
    print_step ".env 파일을 찾지 못했습니다. 스크립트 기본값 또는 CLI 인자를 사용합니다."
fi

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

# 사용법 출력
usage() {
    echo "사용법: $0 -u <jenkins_url> -n <username> -p <password> -r <repo_url> [-P <project_prefix>]"
    echo ""
    echo "옵션:"
    echo "  -u, --url       Jenkins URL (기본값: http://localhost:10060)"
    echo "  -n, --username  Jenkins 사용자명"
    echo "  -p, --password  Jenkins 비밀번호 또는 API 토큰"
    echo "  -r, --repo      Git 저장소 URL"
    echo "  -P, --project   프로젝트 이름 또는 작업명 프리픽스 (예: myapp). 지정하지 않으면 repo 이름에서 유도됩니다."
    echo "  -h, --help      도움말 표시"
    echo ""
    echo "동작:"
    echo "  스크립트를 실행하면 지정한 리포지토를 기반으로 Jenkins에 아래 작업들을 생성합니다."
    echo "  만약 -P 옵션을 지정하지 않으면, repo URL 마지막 부분(예: repo.git -> repo)을 프로젝트 프리픽스로 사용합니다."
    echo ""
    echo "환경변수:"
    echo "  프로젝트 루트의 .env 또는 jenkins/environment.env 파일에서 기본 Jenkins 설정(JENKINS_URL, JENKINS_USER, JENKINS_PASSWORD, REPO_URL 등)을 로드합니다."
    echo "  CLI 인자(-u, -n, -p, -r, -P)는 .env의 값을 덮어씁니다."
    echo ""
    echo "예시:"
    echo "  $0 -u http://jenkins.company.com:8080 -n admin -p your_api_token -r https://github.com/company/repo.git"
    echo "  $0 -u http://jenkins.company.com:8080 -n admin -p your_api_token -r https://github.com/company/repo.git -P myapp"
}

# 명령행 인자 파싱
while [[ $# -gt 0 ]]; do
    case $1 in
        -u|--url)
            JENKINS_URL="$2"
            shift 2
            ;;
        -n|--username)
            JENKINS_USER="$2"
            shift 2
            ;;
        -p|--password)
            JENKINS_PASSWORD="$2"
            shift 2
            ;;
        -r|--repo)
            REPO_URL="$2"
            shift 2
            ;;
        -P|--project)
            PROJECT_PREFIX="$2"
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            print_error "알 수 없는 옵션: $1"
            usage
            exit 1
            ;;
    esac
done

# 필수 파라미터 검증
if [[ -z "$JENKINS_USER" || -z "$JENKINS_PASSWORD" ]]; then
    print_error "Jenkins 사용자명과 비밀번호가 필요합니다."
    usage
    exit 1
fi

# 프로젝트 프리픽스가 비어있으면 사용자에게 물어봄 (빈 입력 시 자동 유도)
if [[ -z "$PROJECT_PREFIX" ]]; then
    read -p "프로젝트 이름(작업명 프리픽스)을 입력하세요 (엔터 시 repo URL에서 자동 유도): " USER_INPUT_PROJECT
    if [[ -n "$USER_INPUT_PROJECT" ]]; then
        PROJECT_PREFIX="$USER_INPUT_PROJECT"
    fi
fi

# PROJECT_PREFIX가 여전히 비어있으면 repo URL에서 유도
if [[ -z "$PROJECT_PREFIX" ]]; then
    PROJECT_PREFIX=$(basename -s .git "$REPO_URL")
    PROJECT_PREFIX=$(echo "$PROJECT_PREFIX" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9._-]/-/g')
fi

print_step "Jenkins CLI 다운로드..."
if [ ! -f "$JENKINS_CLI_JAR" ]; then
    wget -q "${JENKINS_URL}/jnlpJars/jenkins-cli.jar" -O "$JENKINS_CLI_JAR"
fi

# Jenkins 연결 테스트
print_step "Jenkins 연결 테스트..."
java -jar "$JENKINS_CLI_JAR" -s "$JENKINS_URL" -auth "$JENKINS_USER:$JENKINS_PASSWORD" who-am-i

# 작업 XML 템플릿 생성 함수
create_job_xml() {
    local job_name=$1
    local description=$2
    local jenkinsfile_path=$3
    local token=$4
    local filter_expression=$5
    local filter_text=$6

    # XML 특수 문자 이스케이프 함수
    escape_xml() {
        echo "$1" | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g; s/"/\&quot;/g; s/'\''/\&#39;/g'
    }

    local escaped_description=$(escape_xml "$description")
    local escaped_repo_url=$(escape_xml "$REPO_URL")
    local escaped_filter_text=$(escape_xml "$filter_text")
    local escaped_filter_expression=$(escape_xml "$filter_expression")

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

# 작업 생성 함수
create_jenkins_job() {
    local job_name=$1
    local xml_file="/tmp/${job_name}.xml"

    print_step "Jenkins 작업 생성: ${job_name}"

    if java -jar "$JENKINS_CLI_JAR" -s "$JENKINS_URL" -auth "$JENKINS_USER:$JENKINS_PASSWORD" get-job "$job_name" &>/dev/null; then
        print_warning "작업 '${job_name}'이 이미 존재합니다. 업데이트합니다..."
        java -jar "$JENKINS_CLI_JAR" -s "$JENKINS_URL" -auth "$JENKINS_USER:$JENKINS_PASSWORD" update-job "$job_name" < "$xml_file"
    else
        java -jar "$JENKINS_CLI_JAR" -s "$JENKINS_URL" -auth "$JENKINS_USER:$JENKINS_PASSWORD" create-job "$job_name" < "$xml_file"
    fi

    rm -f "$xml_file"
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
echo "2. GitHub 웹훅을 설정하세요 (webhook-setup.md 참고)"
echo "3. 필요한 Credentials를 Jenkins에 추가하세요"
echo "4. 테스트 빌드를 실행하여 설정을 검증하세요"
echo ""
echo "🔗 GitHub 웹훅 URL: ${JENKINS_URL}/generic-webhook-trigger/invoke"

# 임시 파일 정리
rm -f "$JENKINS_CLI_JAR"
