# 🚀 Jenkins CI/CD Pipeline Templates

이 디렉토리는 Flutter 프로젝트를 위한 **재사용 가능한 Jenkins CI/CD 템플릿**을 포함합니다.

## 📂 디렉토리 구조

```
jenkins/
├── 📄 README.md                      # 이 파일 - 사용법 가이드
├── 📋 SETUP_GUIDE.md                 # 새 프로젝트 적용 가이드
├── 📝 .env (프로젝트 루트)            # 환경 변수 템플릿 (루트 .env로 통합됨)
├── pipelines/                        # Jenkins 파이프라인 템플릿들
│   ├── Jenkinsfile.unit-tests        # ① 단위 테스트
│   ├── Jenkinsfile.dev-build         # ② 개발 빌드
│   ├── Jenkinsfile.staging-build     # ④ 스테이징 빌드
│   └── Jenkinsfile.production-deploy # ⑥ 프로덕션 배포
├── scripts/                          # 자동화 스크립트들
│   ├── create-jenkins-jobs.sh        # Jenkins 작업 생성
│   └── setup-jenkins-macos.sh        # macOS Jenkins 설치
└── docs/                             # 상세 문서들
    ├── JENKINS_MIGRATION_GUIDE.md    # 상세 마이그레이션 가이드
    └── webhook-setup.md              # GitHub 웹훅 설정
```

## 🚀 새 프로젝트에 적용하기

### 1. 빠른 시작 (5분)
```bash
# 1. jenkins/ 디렉토리를 새 프로젝트로 복사
cp -r jenkins/ /path/to/new-project/

# 2. Jenkins 작업 자동 생성
cd jenkins/scripts
./create-jenkins-jobs.sh \
  -n jenkins_username \
  -p jenkins_password \
  -r https://github.com/organization/new-project.git
```

### 2. 상세 설정
자세한 설정 방법은 다음 문서들을 참고하세요:
- `SETUP_GUIDE.md` - 새 프로젝트 적용 단계별 가이드
- `docs/JENKINS_MIGRATION_GUIDE.md` - 상세 마이그레이션 가이드
- `docs/webhook-setup.md` - GitHub 웹훅 설정

## 🔧 프로젝트별 수정이 필요한 부분

### Jenkinsfile들에서 수정할 항목들
- **Flutter 버전**: `FLUTTER_VERSION = '3.24.0'`
- **Android API**: `platforms;android-33`
- **브랜치 패턴**: `develop/.*`, `release/.*`
- **Firebase App ID들**: 각 환경별 App ID

### 스크립트에서 수정할 항목들
- **저장소 URL**: `create-jenkins-jobs.sh`의 `-r` 파라미터
- **Jenkins URL**: 새 Jenkins 서버 주소
- **작업명**: `mobble-*` → `프로젝트명-*`

## 🎯 지원하는 CI/CD 워크플로우

| 단계 | 트리거 | 소스 브랜치 | 타겟 브랜치 | 동작 |
|------|--------|-------------|-------------|------|
| ① | PR 생성 | feature/* | develop/* | 단위 테스트 실행 |
| ② | 머지 완료 | develop/* | - | dev 빌드 & Firebase 배포 |
| ④ | 머지 완료 | release/* | - | stg 빌드 & Firebase 배포 |
| ⑥ | 머지 완료 | main | - | prod 빌드 & Store 업로드 |

## 📚 추가 문서

- **Jenkins 설정**: `docs/JENKINS_MIGRATION_GUIDE.md`
- **환경 변수**: `.env` (프로젝트 루트로 통합됨)
- **웹훅 설정**: `docs/webhook-setup.md`

---
**버전**: v1.0.0  
**호환성**: Flutter 3.24.0+, Jenkins LTS, macOS  
**최종 업데이트**: 2025.08.05
