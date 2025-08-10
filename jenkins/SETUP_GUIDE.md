# 🚀 새 프로젝트에 Jenkins CI/CD 적용 가이드

## 📋 5분 빠른 적용

### 1. 파일 복사
```bash
# jenkins/ 디렉토리를 새 프로젝트로 복사
cp -r jenkins/ /path/to/new-project/
cd /path/to/new-project/jenkins
```

### 2. 프로젝트별 수정사항

#### A. 스크립트 실행 시 파라미터 변경
```bash
cd scripts
./create-jenkins-jobs.sh \
  -n your_jenkins_username \
  -p your_jenkins_password \
  -r https://github.com/YOUR_ORG/YOUR_PROJECT.git
```

#### B. Jenkinsfile에서 수정할 부분들
각 `pipelines/Jenkinsfile.*` 파일에서 다음 항목들을 프로젝트에 맞게 수정:

**공통 수정사항:**
- Flutter 버전: `FLUTTER_VERSION = '3.24.0'` → 원하는 버전
- 브랜치 패턴: `develop/.*`, `release/.*` → 프로젝트 브랜치 패턴

**Android 관련:**
- API 레벨: `platforms;android-33` → 타겟 API
- 키스토어 파일명: `mobble-integration.keystore` → 프로젝트 키스토어

**Firebase 관련:**
- App ID들: `firebase-dev-android-app-id`, `firebase-stg-android-app-id` 등
- 서비스 계정 키: credential ID 이름들

### 3. GitHub 웹훅 설정
```
Repository Settings > Webhooks > Add webhook
Payload URL: http://your-jenkins-server:PORT/generic-webhook-trigger/invoke
Events: Push events, Pull requests
```

## 🔧 상세 설정이 필요한 경우

복잡한 설정이나 문제 해결이 필요하다면:
- `docs/JENKINS_MIGRATION_GUIDE.md` - 전체 마이그레이션 가이드
- `docs/webhook-setup.md` - 웹훅 설정 및 트러블슈팅

## ⚠️ 주의사항

1. **Credentials 설정**: 새 Jenkins에서 모든 필요한 credentials 추가 필요
2. **Flutter 환경**: `.env` 파일(프로젝트 루트) 참고하여 Flutter/Android SDK 설치
3. **플러그인**: Generic Webhook Trigger 플러그인 설치 필수

## 🎯 작업명 패턴

생성되는 Jenkins 작업들:
- `프로젝트명-unit-tests`
- `프로젝트명-dev-build` 
- `프로젝트명-staging-build`
- `프로젝트명-production-deploy`

작업명을 변경하려면 `scripts/create-jenkins-jobs.sh`에서 수정하세요.
