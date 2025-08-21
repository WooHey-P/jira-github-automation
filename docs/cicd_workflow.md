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
```mermaid
flowchart TD

    A["① feature/{JIRA-KEY}-description 브랜치 생성"] --> B["② feature → dev/x.x.x 로 PR"]
    B --> J_dev
    K_dev --> E["③ develop 기준 artifact 생성 및 dev 서버 배포"] & L["⑥ release 기준 artifact 생성 및 staging 서버 배포"] & Q["⑩ main 브랜치로 squash merge"]
    E --> QA1_START(("④ DEV QA 시작"))
    L --> QA2_START(("⑦ RELEASE QA 시작"))
    J_dev -- 예 --> J1_dev
    J_dev -- 아니오 --> K_dev
    J1_dev --> K_dev
    I["⑤ feature → release/x.x.x 로 PR"] --> J_dev
    N["⑧ feature 지라 이슈 상태 Done 변경 및 사업부 인수 이슈에 링크 추가"] --> O["⑨ 사업부 인수 완료 후 release → main PR"]
    O --> J_dev
    Q --> R["⑪ main 기준 production artifact 생성 및 PlayStore/AppStore 배포"]
    R --> S["종료"]
    G --> A & QA_OUT_FAIL
    QA1_START --> F
    F -- 아니오 --> F1
    F1 -- 예 --> G
    F1 -- 아니오 --> H
    H --> QA_OUT_FAIL
    QA_OUT_FAIL --> B
    F -- 예 --> I & N
    QA2_START --> F
    n1["시작"] --> A

    L@{ shape: rect}
    QA2_START@{ shape: circle}
    O@{ shape: rect}
    n1@{ shape: rect}

    subgraph pr_conflict["PR 충돌 체크"]
        direction TB
        J_dev{"충돌 발생?"}
        J1_dev["feature 브랜치에서 target 브랜치 기준으로 rebase 및 충돌 해결"]
        K_dev["target/x.x.x 로 squash merge"]
    end

    subgraph QA_PROCESS["QA 프로세스"]
        direction TB
        F{"QA 통과?"}
        F1{"수정 작업량이 많은가?"}
        G["revert"]
        H["작은 수정"]
    end

````