#!/bin/bash

# Jenkins 환경 설정 스크립트 - macOS용
# Homebrew를 사용하여 Jenkins 및 필수 도구 설치

set -e

echo "🚀 Jenkins CI/CD 환경 설정을 시작합니다... (macOS)"

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 함수 정의
print_step() {
    echo -e "${GREEN}[STEP]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# macOS 확인
if [[ "$OSTYPE" != "darwin"* ]]; then
    print_error "이 스크립트는 macOS에서만 실행할 수 있습니다."
    print_warning "Linux/Ubuntu용 스크립트를 사용하려면 setup-jenkins.sh를 실행하세요."
    exit 1
fi

# Homebrew 설치 확인
print_step "Homebrew 설치 확인..."
if ! command -v brew &> /dev/null; then
    print_step "Homebrew 설치 중..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

    # Apple Silicon Mac의 경우 PATH 설정
    if [[ $(uname -m) == "arm64" ]]; then
        echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
        eval "$(/opt/homebrew/bin/brew shellenv)"
    fi
else
    print_step "Homebrew가 이미 설치되어 있습니다."
fi

# Homebrew 업데이트
print_step "Homebrew 업데이트..."
brew update

# 1. Java 17 설치
print_step "Java 17 설치..."
if ! brew list openjdk@17 &> /dev/null; then
    brew install openjdk@17
    # Java 17을 기본 Java로 설정
    sudo ln -sfn $(brew --prefix)/opt/openjdk@17/libexec/openjdk.jdk /Library/Java/JavaVirtualMachines/openjdk-17.jdk
else
    print_step "Java 17이 이미 설치되어 있습니다."
fi

export JAVA_HOME=$(/usr/libexec/java_home -v 17)
echo "export JAVA_HOME=$(/usr/libexec/java_home -v 17)" >> ~/.zshrc

# 2. Jenkins 설치
print_step "Jenkins 설치..."
if ! brew list jenkins-lts &> /dev/null; then
    brew install jenkins-lts
else
    print_step "Jenkins가 이미 설치되어 있습니다."
fi

# 3. Git 설치 (최신 버전)
print_step "Git 설치..."
if ! brew list git &> /dev/null; then
    brew install git
else
    print_step "Git이 이미 설치되어 있습니다."
fi

# 4. Flutter 설치
print_step "Flutter 설치..."
if ! command -v flutter &> /dev/null; then
    if ! brew list flutter &> /dev/null; then
        brew install --cask flutter
    fi

    # Flutter PATH 설정
    FLUTTER_PATH=$(brew --prefix)/bin/flutter
    if [[ ":$PATH:" != *":$(dirname $FLUTTER_PATH):"* ]]; then
        echo 'export PATH="$(brew --prefix)/bin:$PATH"' >> ~/.zshrc
    fi
else
    print_step "Flutter가 이미 설치되어 있습니다."
fi

# 5. Android SDK (Android Studio) 설치
print_step "Android Studio 설치 확인..."
if [ ! -d "/Applications/Android Studio.app" ]; then
    print_warning "Android Studio가 설치되어 있지 않습니다."
    read -p "Android Studio를 설치하시겠습니까? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        brew install --cask android-studio
        print_warning "Android Studio 설치 후 SDK Manager에서 다음을 설치하세요:"
        echo "  - Android SDK Platform-Tools"
        echo "  - Android SDK Build-Tools"
        echo "  - Android 13 (API level 33)"
    fi
else
    print_step "Android Studio가 이미 설치되어 있습니다."
fi

# Android 환경 변수 설정
if [ -d "$HOME/Library/Android/sdk" ]; then
    echo 'export ANDROID_HOME=$HOME/Library/Android/sdk' >> ~/.zshrc
    echo 'export ANDROID_SDK_ROOT=$HOME/Library/Android/sdk' >> ~/.zshrc
    echo 'export PATH=$PATH:$ANDROID_HOME/platform-tools:$ANDROID_HOME/tools' >> ~/.zshrc
    export ANDROID_HOME=$HOME/Library/Android/sdk
    export ANDROID_SDK_ROOT=$HOME/Library/Android/sdk
fi

# 6. Xcode Command Line Tools 설치
print_step "Xcode Command Line Tools 설치 확인..."
if ! xcode-select -p &> /dev/null; then
    print_step "Xcode Command Line Tools 설치 중..."
    xcode-select --install
    print_warning "Xcode Command Line Tools 설치가 완료된 후 스크립트를 다시 실행하세요."
    exit 0
else
    print_step "Xcode Command Line Tools가 이미 설치되어 있습니다."
fi

# 7. Node.js 설치 (Firebase CLI용)
print_step "Node.js 설치..."
if ! brew list node &> /dev/null; then
    brew install node
else
    print_step "Node.js가 이미 설치되어 있습니다."
fi

# 8. Firebase CLI 설치
print_step "Firebase CLI 설치..."
if ! command -v firebase &> /dev/null; then
    npm install -g firebase-tools
else
    print_step "Firebase CLI가 이미 설치되어 있습니다."
fi

# 9. CocoaPods 설치
print_step "CocoaPods 설치..."
if ! command -v pod &> /dev/null; then
    sudo gem install cocoapods
else
    print_step "CocoaPods가 이미 설치되어 있습니다."
fi

# 10. Fastlane 설치
print_step "Fastlane 설치..."
if ! command -v fastlane &> /dev/null; then
    sudo gem install fastlane
else
    print_step "Fastlane이 이미 설치되어 있습니다."
fi

# 11. Git 전역 설정
print_step "Git 전역 설정..."
git config --global user.name "Jenkins CI" 2>/dev/null || true
git config --global user.email "jenkins@company.com" 2>/dev/null || true
git config --global init.defaultBranch main 2>/dev/null || true

# 12. Flutter 환경 설정
print_step "Flutter 환경 설정..."
export PATH="$(brew --prefix)/bin:$PATH"
flutter config --no-analytics
flutter precache
flutter doctor

# 13. Jenkins 서비스 시작 준비
print_step "Jenkins 서비스 설정..."

# Jenkins 홈 디렉토리 생성
JENKINS_HOME="$HOME/.jenkins"
mkdir -p "$JENKINS_HOME"

# Jenkins를 서비스로 등록
brew services start jenkins-lts

# Jenkins가 시작될 때까지 대기
print_step "Jenkins 시작 대기 중..."
sleep 10

# Jenkins 포트 확인
JENKINS_PORT=10060
if ! nc -z localhost $JENKINS_PORT 2>/dev/null; then
    print_warning "Jenkins가 포트 10060에서 시작되지 않았습니다."
    print_warning "다른 포트를 사용하고 있을 수 있습니다."
    print_warning "다음 명령어로 Jenkins 로그를 확인하세요:"
    echo "brew services list | grep jenkins"
    echo "tail -f $(brew --prefix)/var/log/jenkins-lts/jenkins.log"
fi

# 14. 설정 완료 안내
print_step "설정 완료!"
echo ""
echo "🎉 Jenkins 설치가 완료되었습니다!"
echo ""
echo "📋 다음 단계:"
echo "1. 브라우저에서 http://localhost:10060 접속"
echo "2. 초기 관리자 비밀번호를 입력하세요:"
echo ""

# 초기 비밀번호 찾기
INITIAL_PASSWORD_FILE="$JENKINS_HOME/secrets/initialAdminPassword"
if [ -f "$INITIAL_PASSWORD_FILE" ]; then
    echo -e "${GREEN}초기 비밀번호:${NC}"
    cat "$INITIAL_PASSWORD_FILE"
else
    echo -e "${YELLOW}초기 비밀번호를 찾을 수 없습니다.${NC}"
    echo "다음 위치를 확인하세요:"
    echo "  - $JENKINS_HOME/secrets/initialAdminPassword"
    echo "  - $(brew --prefix)/var/lib/jenkins/secrets/initialAdminPassword"
    echo ""
    echo "또는 Jenkins 로그에서 비밀번호를 확인하세요:"
    echo "tail -f $(brew --prefix)/var/log/jenkins-lts/jenkins.log"
fi

echo ""
echo "3. 추천 플러그인 설치를 선택하세요"
echo "4. 관리자 계정을 생성하세요"
echo "5. Jenkins URL을 확인하세요"
echo ""
echo "🔧 추가 설정 필요:"
echo "- Jenkins 관리 > 플러그인 관리에서 필수 플러그인 설치"
echo "- Jenkins 관리 > Manage Credentials에서 자격 증명 설정"
echo "- GitHub 웹훅 설정"
echo ""
echo "📖 자세한 내용은 JENKINS_MIGRATION_GUIDE.md를 참고하세요."

echo ""
echo "🛠️ 개발 도구 상태:"
echo "Java: $(java -version 2>&1 | head -n 1)"
echo "Flutter: $(flutter --version | head -n 1)"
echo "Node.js: $(node --version)"
echo "Git: $(git --version)"

echo ""
print_warning "터미널을 재시작하거나 다음 명령어를 실행하여 환경 변수를 적용하세요:"
echo "source ~/.zshrc"

echo ""
echo "Jenkins 서비스 관리 명령어:"
echo "  시작: brew services start jenkins-lts"
echo "  중지: brew services stop jenkins-lts"
echo "  재시작: brew services restart jenkins-lts"
echo "  상태 확인: brew services list | grep jenkins"
