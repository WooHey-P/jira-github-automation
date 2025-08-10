## 📘 CI/CD 워크플로우

| 단계 | Trigger                     | Source 브랜치      | Target 브랜치      | Flavor | 배포 대상                  | 동작                              | 비고              |
|------|------------------------------|--------------------|--------------------|--------|----------------------------|-----------------------------------|-------------------|
| ①    | 작업 완료                   | feature/...        | develop/x.y.z      | -      | -                          | unit-test                 | 작업자 수동 PR    |
| ②    | 단위 테스트 통과 후 PR merge | develop/x.y.z      | -                  | dev    | 개발 환경 (예: Firebase)   | dev-build      | 자동              |
| ③    | QA 통과 후                  | feature/...        | release/x.y.z      | -      | -                          | code review                   | 수동              |
| ④    | release PR merge 시         | release/x.y.z      | -                  | stg    | 스테이징 환경 (예: Firebase)| staging-build      | 자동              |
| ⑤    | QA 통과 후                  | release/x.y.z      | main             | -      | -                          | code review & merge                | 수동              |
| ⑥    | main PR merge 시          | main             | -                  | prod   | 운영 환경 (예: PlayStore, TestFlight)| prodiction-deploy            | 자동              |
