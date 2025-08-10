# Jenkins CI/CD 마이그레이션 가이드

## 📋 개요
GitHub Actions에서 Jenkins로 CI/CD 파이프라인을 마이그레이션하기 위한 완전한 가이드입니다.

## 🗂️ 파일 구조
```
jenkins/
├── Jenkinsfile.unit-tests          # ① PR 단위 테스트
├── Jenkinsfile.dev-build           # ② develop 브랜치 빌드 & 배포
├── Jenkinsfile.staging-build       # ④ release 브랜치 빌드 & 배포
├── Jenkinsfile.production-deploy   # ⑥ master 브랜치 프로덕션 배포
├── jenkins-jobs-config.xml         # Jenkins 작업 설정
└── webhook-setup.md                # GitHub 웹훅 설정 가이드
```

## 🔧 Jenkins 서버 설정

### 1. 필수 플러그인 설치
Jenkins 관리 > 플러그인 관리에서 다음 플러그인들을 설치하세요:

```
- Pipeline
- Git
- GitHub
- Generic Webhook Trigger
- Credentials Binding
- Pipeline: Stage View
- Blue Ocean (선택사항)
- Slack Notification (선택사항)
- HTML Publisher (커버리지 리포트용)
```

### 2. Jenkins 시스템 설정

#### 환경 변수 설정
Jenkins 관리 > 시스템 설정에서 다음 환경 변수를 설정:

```bash
# Flutter 설정
FLUTTER_HOME=/opt/flutter
PATH=$PATH:$FLUTTER_HOME/bin

# Android 설정
ANDROID_HOME=/opt/android-sdk
ANDROID_SDK_ROOT=$ANDROID_HOME
JAVA_HOME=/usr/lib/jvm/java-17-openjdk

# iOS 설정 (macOS 노드에서만)
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
```

#### Node 라벨 설정
- `android`: Android 빌드 가능한 노드
- `ios`: iOS 빌드 가능한 macOS 노드
- `flutter`: Flutter SDK가 설치된 노드

## 🔐 Credentials 설정

Jenkins 관리 > Manage Credentials에서 다음 자격 증명을 추가하세요:

### GitHub 관련
- `github-credentials`: GitHub 사용자명/토큰 (Git 클론용)
- `github-token`: GitHub Personal Access Token (API 호출용)

### Android 관련
- `android-keystore-base64`: 키스토어 파일의 Base64 인코딩
- `android-keystore-password`: 키스토어 비밀번호
- `android-key-password`: 키 비밀번호
- `android-key-alias`: 키 별칭
- `google-play-service-account-key`: Google Play 서비스 계정 JSON 파일

### iOS 관련
- `ios-build-certificate-base64`: 개발용 인증서 (.p12) Base64
- `ios-distribution-certificate-base64`: 배포용 인증서 (.p12) Base64
- `ios-p12-password`: .p12 파일 비밀번호
- `ios-provision-profile-base64`: 프로비저닝 프로파일 Base64
- `ios-appstore-provision-profile-base64`: App Store 프로비저닝 프로파일 Base64
- `ios-keychain-password`: 키체인 비밀번호
- `app-store-connect-api-key-id`: App Store Connect API 키 ID
- `app-store-connect-issuer-id`: App Store Connect Issuer ID
- `app-store-connect-api-key`: App Store Connect API 키 파일

### Firebase 관련
- `firebase-service-account-key`: Firebase 서비스 계정 JSON 파일
- `firebase-dev-android-app-id`: Firebase 개발용 Android 앱 ID
- `firebase-dev-ios-app-id`: Firebase 개발용 iOS 앱 ID
- `firebase-stg-android-app-id`: Firebase 스테이징용 Android 앱 ID
- `firebase-stg-ios-app-id`: Firebase 스테이징용 iOS 앱 ID

## 📦 Jenkins 작업 생성

### 1. Pipeline 작업 생성
각 Jenkinsfile에 대해 다음과 같이 Pipeline 작업을 생성하세요:

1. 새 작업 > Pipeline 선택
2. 작업명 입력:
   - `mobble-unit-tests`
   - `mobble-dev-build`
   - `mobble-staging-build`
   - `mobble-production-deploy`

3. Pipeline 설정:
   - Definition: "Pipeline script from SCM" 선택
   - SCM: Git 선택
   - Repository URL: 프로젝트 Git URL
   - Credentials: github-credentials 선택
   - Branch: */master (모든 브랜치에서 Jenkinsfile 읽기 위해)
   - Script Path: 각각의 Jenkinsfile 경로 지정
     - `jenkins/Jenkinsfile.unit-tests`
     - `jenkins/Jenkinsfile.dev-build`
     - `jenkins/Jenkinsfile.staging-build`
     - `jenkins/Jenkinsfile.production-deploy`

### 2. 웹훅 트리거 설정

각 작업의 "Build Triggers"에서 "Generic Webhook Trigger" 설정:

#### Unit Tests 작업
- Token: `unit-tests-trigger`
- Post content parameters:
  - Variable: `action`, Expression: `$.action`
  - Variable: `pr_target_branch`, Expression: `$.pull_request.base.ref`
  - Variable: `pr_source_branch`, Expression: `$.pull_request.head.ref`
- Optional filter:
  - Expression: `^(opened|synchronize|reopened) develop/.*`
  - Text: `$action $pr_target_branch`

#### Dev Build 작업
- Token: `dev-build-trigger`
- Post content parameters:
  - Variable: `ref`, Expression: `$.ref`
- Optional filter:
  - Expression: `^refs/heads/develop/.*`
  - Text: `$ref`

#### Staging Build 작업
- Token: `staging-build-trigger`
- Post content parameters:
  - Variable: `ref`, Expression: `$.ref`
- Optional filter:
  - Expression: `^refs/heads/release/.*`
  - Text: `$ref`

#### Production Deploy 작업
- Token: `production-deploy-trigger`
- Post content parameters:
  - Variable: `ref`, Expression: `$.ref`
- Optional filter:
  - Expression: `^refs/heads/master$`
  - Text: `$ref`

## 🔗 GitHub 웹훅 설정

GitHub 레포지토리 설정 > Webhooks > Add webhook:

1. Payload URL: `http://your-jenkins-server/generic-webhook-trigger/invoke`
2. Content type: `application/json`
3. Secret: (선택사항)
4. Events 선택:
   - Push events
   - Pull requests
5. Active 체크

## 🚀 빌드 환경 설정

### Flutter 설치 (모든 노드)
```bash
# Flutter SDK 설치
sudo git clone https://github.com/flutter/flutter.git -b stable /opt/flutter
sudo chown -R jenkins:jenkins /opt/flutter
export PATH="/opt/flutter/bin:$PATH"

# Flutter 설정
flutter config --no-analytics
flutter precache
flutter doctor
```

### Android 설정 (Android 빌드 노드)
```bash
# Android SDK 설치
sudo mkdir -p /opt/android-sdk
sudo chown jenkins:jenkins /opt/android-sdk

# SDK 도구 설치 (jenkins 사용자로)
su - jenkins
cd /opt/android-sdk
wget https://dl.google.com/android/repository/commandlinetools-linux-9477386_latest.zip
unzip commandlinetools-linux-9477386_latest.zip
./cmdline-tools/bin/sdkmanager --sdk_root=/opt/android-sdk --install "platform-tools" "platforms;android-33" "build-tools;33.0.0"

# Java 17 설치
sudo apt-get install openjdk-17-jdk
```

### iOS 설정 (macOS 노드)
```bash
# Xcode Command Line Tools 설치
xcode-select --install

# CocoaPods 설치
sudo gem install cocoapods

# Fastlane 설치
sudo gem install fastlane

# Ruby 환경 설정
gem install bundler
```

### Firebase CLI 설치 (모든 노드)
```bash
# Node.js 설치 (Ubuntu)
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
sudo apt-get install -y nodejs

# Firebase CLI 설치
sudo npm install -g firebase-tools
```

## 📊 모니터링 및 알림

### Slack 알림 설정 (선택사항)
1. Slack 플러그인 설치
2. Slack 워크스페이스에서 Jenkins 앱 추가
3. Jenkins에서 Slack 설정:
   - Workspace: 워크스페이스명
   - Credential: Slack 토큰
   - Default channel: #ci-cd

### 빌드 상태 배지
README.md에 빌드 상태 배지 추가:
```markdown
[![Build Status](http://your-jenkins-server/buildStatus/icon?job=mobble-unit-tests)](http://your-jenkins-server/job/mobble-unit-tests/)
```

## 🔄 CI/CD 워크플로우 테스트

### 1. 단위 테스트 파이프라인 테스트
```bash
# feature 브랜치에서 develop으로 PR 생성
git checkout -b feature/test-jenkins
git push origin feature/test-jenkins
# GitHub에서 develop/x.y.z로 PR 생성
```

### 2. 개발 빌드 파이프라인 테스트
```bash
# develop 브랜치에 푸시
git checkout develop/1.0.0
git push origin develop/1.0.0
```

### 3. 스테이징 빌드 파이프라인 테스트
```bash
# release 브랜치에 푸시
git checkout release/1.0.0
git push origin release/1.0.0
```

### 4. 프로덕션 배포 파이프라인 테스트
```bash
# master 브랜치에 푸시 (VERSION_NAME, VERSION_CODE 파라미터와 함께)
git checkout master
git push origin master
```

## 📝 주의사항

1. **보안**: 모든 민감한 정보는 Jenkins Credentials에 저장하세요
2. **권한**: Jenkins 사용자가 필요한 디렉토리에 읽기/쓰기 권한이 있는지 확인하세요
3. **백업**: Jenkins 설정과 작업 정의를 정기적으로 백업하세요
4. **로그**: 빌드 로그를 주기적으로 정리하여 디스크 공간을 관리하세요
5. **업데이트**: Flutter, Android SDK, Xcode 등을 정기적으로 업데이트하세요

## 🛠️ 트러블슈팅

### 일반적인 문제들
- **Flutter 명령어를 찾을 수 없음**: PATH 환경 변수 확인
- **Android 빌드 실패**: ANDROID_HOME, JAVA_HOME 환경 변수 확인
- **iOS 빌드 실패**: 코드 서명 인증서 및 프로비저닝 프로파일 확인
- **웹훅이 작동하지 않음**: Jenkins URL과 GitHub 웹훅 설정 확인

### 로그 확인 방법
- Jenkins 콘솔 로그에서 상세한 오류 메시지 확인
- `flutter doctor -v`로 Flutter 환경 확인
- `adb devices`로 Android 디바이스 연결 확인
