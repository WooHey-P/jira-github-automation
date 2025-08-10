# GitHub 웹훅 설정 가이드

## 📋 개요
GitHub Actions에서 Jenkins로 마이그레이션 후 GitHub 웹훅을 설정하여 자동 빌드를 트리거하는 방법입니다.

## 🔗 웹훅 설정

### 1. GitHub 레포지토리 웹훅 추가

1. GitHub 레포지토리 페이지로 이동
2. Settings > Webhooks > Add webhook 클릭
3. 다음 정보 입력:

```
Payload URL: http://your-jenkins-server:8080/generic-webhook-trigger/invoke
Content type: application/json
Secret: (선택사항 - 보안을 위해 설정 권장)
```

4. 트리거할 이벤트 선택:
   - ✅ Push events
   - ✅ Pull requests
   - ❌ Repository (체크 해제)

5. Active 체크박스 활성화
6. Add webhook 클릭

### 2. 웹훅 토큰별 트리거 조건

각 Jenkins 작업은 서로 다른 토큰과 필터 조건을 사용합니다:

#### 📝 Unit Tests (`unit-tests-trigger`)
**트리거 조건:**
- 이벤트: Pull Request (opened, synchronize, reopened)
- 타겟 브랜치: `develop/*` 패턴

**GitHub 이벤트:**
```json
{
  "action": "opened",
  "pull_request": {
    "base": {
      "ref": "develop/1.0.0"
    },
    "head": {
      "ref": "feature/new-feature"
    }
  }
}
```

#### 🔨 Dev Build (`dev-build-trigger`)
**트리거 조건:**
- 이벤트: Push
- 브랜치: `develop/*` 패턴

**GitHub 이벤트:**
```json
{
  "ref": "refs/heads/develop/1.0.0",
  "repository": {
    "name": "mobble_commute_driver_flutter"
  }
}
```

#### 🚀 Staging Build (`staging-build-trigger`)
**트리거 조건:**
- 이벤트: Push
- 브랜치: `release/*` 패턴

**GitHub 이벤트:**
```json
{
  "ref": "refs/heads/release/1.0.0",
  "repository": {
    "name": "mobble_commute_driver_flutter"
  }
}
```

#### 📦 Production Deploy (`production-deploy-trigger`)
**트리거 조건:**
- 이벤트: Push
- 브랜치: `master` (정확히 일치)

**GitHub 이벤트:**
```json
{
  "ref": "refs/heads/master",
  "repository": {
    "name": "mobble_commute_driver_flutter"
  }
}
```

## 🔐 보안 설정

### 웹훅 Secret 설정 (권장)

1. **Secret 생성:**
```bash
# 임의의 보안 문자열 생성
openssl rand -hex 20
```

2. **GitHub에서 Secret 설정:**
   - 웹훅 설정에서 Secret 필드에 생성된 문자열 입력

3. **Jenkins에서 Secret 검증 설정:**
   - Generic Webhook Trigger 설정에서 "Token credential ID" 사용
   - Jenkins Credentials에 Secret을 저장하고 참조

### IP 화이트리스트 (선택사항)

GitHub의 웹훅 IP 범위를 방화벽에서 허용:
```
192.30.252.0/22
185.199.108.0/22
140.82.112.0/20
143.55.64.0/20
```

## 🧪 웹훅 테스트

### 1. 웹훅 전송 테스트

GitHub 웹훅 설정 페이지에서:
1. 설정한 웹훅 클릭
2. "Recent Deliveries" 탭 확인
3. "Redeliver" 버튼으로 재전송 테스트

### 2. Jenkins 로그 확인

Jenkins에서 웹훅 수신 로그 확인:
```
Jenkins 관리 > 시스템 로그 > 새 로그 레코더 추가
- 이름: webhook-debug
- 로거: org.jenkinsci.plugins.gwt
- 로그 레벨: ALL
```

### 3. 수동 테스트 시나리오

#### Unit Tests 트리거 테스트:
```bash
# 1. feature 브랜치 생성
git checkout -b feature/webhook-test

# 2. 변경사항 커밋
echo "test" > test.txt
git add test.txt
git commit -m "Test webhook trigger"

# 3. 브랜치 푸시
git push origin feature/webhook-test

# 4. GitHub에서 develop/x.y.z로 PR 생성
```

#### Dev Build 트리거 테스트:
```bash
# 1. develop 브랜치로 이동
git checkout develop/1.0.0

# 2. 변경사항 푸시
git push origin develop/1.0.0
```

## 🛠️ 트러블슈팅

### 웹훅이 작동하지 않을 때

1. **Jenkins URL 접근성 확인:**
```bash
curl -X POST http://your-jenkins-server:8080/generic-webhook-trigger/invoke
```

2. **방화벽 설정 확인:**
   - 8080 포트가 외부에서 접근 가능한지 확인
   - GitHub IP 범위가 허용되어 있는지 확인

3. **웹훅 로그 확인:**
   - GitHub: Settings > Webhooks > 해당 웹훅 > Recent Deliveries
   - 응답 코드와 응답 본문 확인

4. **Jenkins 로그 확인:**
```bash
# Jenkins 로그 실시간 확인
tail -f /var/log/jenkins/jenkins.log

# 또는 Jenkins 웹 인터페이스에서
# Jenkins 관리 > 시스템 로그
```

### 일반적인 오류들

#### 403 Forbidden
- Jenkins 인증이 필요한 경우
- 해결: Jenkins 보안 설정에서 익명 사용자에게 Job/Build 권한 부여

#### 404 Not Found
- 잘못된 Jenkins URL
- 해결: Generic Webhook Trigger 플러그인 설치 확인

#### 필터 조건 불일치
- 정규식 표현식이 잘못된 경우
- 해결: Jenkins 작업 설정의 "regexpFilterExpression" 확인

### 디버깅 도구

#### 웹훅 페이로드 확인:
```bash
# ngrok으로 로컬 테스트 (개발 환경)
ngrok http 8080

# webhook.site으로 페이로드 확인
# 웹훅 URL을 임시로 https://webhook.site/unique-url로 설정
```

#### Jenkins 작업 수동 트리거:
```bash
# 특정 토큰으로 수동 트리거
curl -X POST \
  "http://your-jenkins-server:8080/generic-webhook-trigger/invoke?token=unit-tests-trigger" \
  -H "Content-Type: application/json" \
  -d '{"action":"opened","pull_request":{"base":{"ref":"develop/1.0.0"},"head":{"ref":"feature/test"}}}'
```

## 📊 모니터링

### 웹훅 성공률 모니터링

1. **GitHub Insights:**
   - Settings > Webhooks > 해당 웹훅
   - Recent Deliveries에서 성공/실패 비율 확인

2. **Jenkins Dashboard:**
   - 각 작업의 빌드 히스토리 확인
   - 실패한 빌드의 원인 분석

3. **알림 설정:**
   - Jenkins 플러그인을 사용하여 Slack/이메일 알림 설정
   - 웹훅 실패 시 즉시 알림 받도록 구성

## 📝 체크리스트

마이그레이션 완료 후 다음 사항들을 확인하세요:

- [ ] GitHub 웹훅이 올바른 Jenkins URL로 설정됨
- [ ] 모든 이벤트 타입 (Push, PR)이 선택됨
- [ ] Jenkins에서 Generic Webhook Trigger 플러그인 설치됨
- [ ] 각 Jenkins 작업에 올바른 토큰과 필터가 설정됨
- [ ] 필요한 Credentials가 모두 Jenkins에 등록됨
- [ ] 테스트 시나리오가 모두 성공함
- [ ] 웹훅 전송 로그가 정상적으로 기록됨
- [ ] 빌드 실패 시 알림이 정상 작동함
