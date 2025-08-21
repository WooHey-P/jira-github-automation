## 📘 CI/CD 워크플로우

| 단계 | Trigger                     | Source 브랜치      | Target 브랜치      | Flavor | 배포 대상                  | 동작                              | 비고              |
|------|------------------------------|--------------------|--------------------|--------|----------------------------|-----------------------------------|-------------------|
| ①    | 작업 완료                   | feature/...        | develop/x.y.z      | -      | -                          | unit-test                 | 작업자 수동 PR    |
| ②    | 단위 테스트 통과 후 PR merge | develop/x.y.z      | -                  | dev    | 개발 환경 (예: Firebase)   | dev-build      | 자동              |
| ③    | QA 통과 후                  | feature/...        | release/x.y.z      | -      | -                          | code review                   | 수동              |
| ④    | release PR merge 시         | release/x.y.z      | -                  | stg    | 스테이징 환경 (예: Firebase)| staging-build      | 자동              |
| ⑤    | QA 통과 후                  | release/x.y.z      | main             | -      | -                          | code review & merge                | 수동              |
| ⑥    | main PR merge 시          | main             | -                  | prod   | 운영 환경 (예: PlayStore, TestFlight)| prodiction-deploy            | 자동              |

## git + jira workflow
### flow
1. feature/{JIRA-KEY}-{description} 브랜치 생성
2. 작업 완료 후 dev/x.x.x 브랜치로 PR
    - conflict 발생 시, feature on dev/x.x.x 브랜치로 rebase
    - conflict 해결
3. 해당 PR을 develop/x.x.x 브랜치로 squash merge
4. develop/x.x.x 브랜치 기준 artifact(apk, ipa) 생성 및 배포(aos: firebase, ios: testflight) - dev server
    - QA 미통과 시
        - 수정 작업량이 많은 경우
            - revert
            - 1번부터 다시 진행
        - 수정 작업량이 적은 경우
            - 1번부터 다시 진행
5. QA 통과 후 feature/{JIRA-KEY}-{description} 브랜치를 release/x.x.x 브랜치로 PR
    - conflict 발생 시, feature on release/x.x.x 브랜치로 rebase
    - conflict 해결
6. 해당 PR을 release/x.x.x 브랜치로 squash merge
7. release/x.x.x 브랜치 기준 artifact(apk, ipa) 생성 및 배포(aos: firebase, ios: testflight) - staging server
    - QA 미통과 시
        - 수정 작업량이 많은 경우
            - revert
            - 1번부터 다시 진행
        - 수정 작업량이 적은 경우
            - 1번부터 다시 진행
8. feature 지라 이슈 상태를 Done으로 변경
9. 사업부 인수 이슈에 feature 지라 이슈 링크 추가
10. 사업부 인수완료 후 release/x.x.x 브랜치를 main 브랜치로 PR
    - conflict 발생 시, release on main 브랜치로 rebase
    - conflict 해결
11. 해당 PR을 main 브랜치로 squash merge
12. main 브랜치 기준 artifact(aab, ipa) 생성 및 배포(aos: playstore, ios: appstore) - production server


### 차트