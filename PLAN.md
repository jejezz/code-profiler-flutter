# PLAN — 남은 작업과 다음 단계

구현된 것은 [IMPLEMENTED.md](IMPLEMENTED.md), 전체 설계와 Phase 정의는 [IMPLEMENTATION_PLAN.md](IMPLEMENTATION_PLAN.md).
작업 원칙은 [Claude.md](Claude.md): Phase 순서를 지키고, 완료 기준을 만족한 뒤 다음으로 간다. 설계와 다르게 구현할 이유가 생기면 사용자에게 알리고 문서를 함께 고친다.

## 1. 지금 바로 할 일 — 프로필 생성 단계 추가 (Phase 5 수정)

### 문제
적용 중 `code --profile "Web / Python" --install-extension ...`이 `Profile 'Web / Python' not found.`로 실패한다. VS Code CLI에는 프로필 생성 명령이 없고, **없는 프로필 이름으로 `code --profile <이름> <폴더>`를 실행하면 빈 프로필이 만들어진다**(창이 열림). 확장 설치는 그 뒤에야 가능하다.

### 설계 (아직 코드 변경 없음)
적용 순서를 **프로필 준비 → 확장 설치 → 설정 쓰기**로 바꾼다.

1. **엔진 `VsCodeCli.ensureProfile(profile, location, {timeout = 60s, pollInterval = 1s, wait})`**
   - `listExtensions(profile)`이 성공하면 이미 있는 프로필 → `ProfileState.existed`.
   - 실패하면 `open(profile, location)`으로 프로젝트를 그 프로필로 열어 생성 → 성공할 때까지 `listExtensions`를 1초 간격으로 폴링 → `ProfileState.created`.
   - 열기 실패나 시간 초과는 `Err`(시간 초과 메시지에 "VS Code가 시작 중이면 잠시 뒤 다시 시도").
   - `wait`(지연 함수)를 주입 가능하게 해서 테스트가 실제로 기다리지 않게 한다.
   - 이미 있던 프로필인지 새로 만들었는지는 구분해서 돌려준다(UI 로그용).
2. **`FakeProcessRunner`** — 같은 인자에 호출마다 다른 응답을 주는 `outputs: List<ProcessOutput>` 지원(마지막 응답 반복). 폴링 테스트에 필요.
3. **앱 `project_service.dart`** — `ApplyStep.profile` 추가(가장 앞), 이벤트 `ProfileExists` / `ProfileCreating` / `ProfileCreated`. 실패는 `StepFailed(profile, 메시지)`. 확장이 없어도 프로필 단계는 수행(적용 뒤 프로필이 존재하도록).
4. **앱 화면 `apply_screen.dart`** — 단계 행 3개, 새 로그 문구. 진행 중 뒤로가기 막기는 유지.
5. **문구(ko/en 쌍)**: `applyStepProfile`("프로필 준비"), `applyProfileExists`, `applyProfileCreating`("프로필이 없어 VS Code를 열어 새로 만듭니다: {name}"), `applyProfileCreated`.
6. **테스트**
   - 엔진: 있음 / 없음→생성(폴링 2~3회 후 성공) / 열기 실패 / 시간 초과 / 셸 특수문자 거부.
   - 앱: `successEvents`에 프로필 단계 추가, 완료 아이콘 개수(2→3), 프로필 실패 시나리오, `LocalProjectService.apply` 이벤트 순서.
   - 통합(`@Tags(['integration'])`): **임시 프로필 이름**으로 실제 생성 → 폴링 성공 확인. VS Code 창이 열리므로 사용자 동의 후에만 실행하고, 테스트 후 임시 프로필은 사용자가 VS Code에서 지우게 안내(엔진은 VS Code 내부 저장소에 쓰지 않는다).
7. **문서** — IMPLEMENTATION_PLAN 5.2절(VsCodeCli 표)에 `ensureProfile` 추가, 5장 적용 흐름과 7.1 "적용 진행" 단계 갱신, IMPLEMENTED 갱신.

### 확인할 점 (구현 후 사용자 수동 확인)
- 새 프로필이 만들어질 때 프로젝트 창이 먼저 열린다. 그 창에서 이어서 설치된 확장이 **재시작 없이 활성화되는지** 확인(안 되면 완료 화면에 "창 다시 불러오기" 안내 추가).
- 이미 있는 프로필로 다시 적용하면 창이 새로 열리지 않는지.
- 프로필 이름 대소문자·공백·`+`·`/`가 VS Code에서 그대로 쓰이는지.

## 2. 그다음 — Phase 5 마무리

1. 사용자가 샘플 프로젝트(`esp-idf-sample`, `gradle-sample`)로 등록 → 분석 → 추천 → 적용 → 열기를 끝까지 수동 확인하고 결과를 알려 준다. (**완료 기준: VS Code가 해당 프로필로 열림**)
2. 발견된 문제 수정.
3. 커밋: Phase 5 전체 + 셸 없는 실행/디코딩 수정 + 프로필 생성 단계. 사용자가 확인 후 요청하면 진행(자동 커밋 금지).

## 3. Phase 6 — SSH 원격 프로젝트

설계는 IMPLEMENTATION_PLAN 5.3·6·7.3·Phase 6. 이미 깔린 것: `SshLocation`, `VsCodeCli.open`의 `--remote ssh-remote+<host>`, 엔진 CLI 4개 명령, `ProjectService` 인터페이스.

- `~/.ssh/config` 호스트 파서(와일드카드 제외, `Include` 1단계, 실패 시 수동 입력만).
- `remote/shell_quote.dart`(단일 인용부호 이스케이프) + 원격 실행 래퍼(`-o BatchMode=yes`, 연결 타임아웃 필수).
- 원격 엔진: 버전 확인(`~/.local/bin/profile-engine --version`) → 아키텍처(`uname -m`, **x86_64만**) → `dart compile exe --target-os linux --target-arch x64` 교차 컴파일 시도, 불가하면 서버에서 직접 빌드하는 명령 안내 → `scp` + `chmod +x`.
- `SshProjectService`(또는 `LocalProjectService` 확장): 원격 analyze/recommend/diff/apply를 엔진 CLI 호출(`--patch -`로 stdin 전달)로 연결, 확장 설치·열기는 로컬 `code`가 `--remote`로.
- 앱: 프로젝트 추가 화면에 SSH 탭(호스트 선택/입력 + 경로 + 연결 테스트), 설정 화면에 원격 엔진 배포 상태(호스트별), 연결 실패·엔진 없음·권한 없음 상태 표시.
- 프로필 생성(§1)은 SSH에서도 `open`으로 같은 방식이므로 재사용.
- **완료 기준**: 실제 SSH 서버의 AOSP 모듈 폴더로 전 과정 수동 확인(`aospRoot` 해석, compdb 경로가 settings에 들어감). 통합 테스트는 `integration` 태그.
- 사전 확인 필요: 사용자의 SSH 서버 접속 정보(`~/.ssh/config` Host 이름), 서버에 `code` 원격 서버 설치 여부.

## 4. Phase 7 — 마무리

- 사용자 규칙 파일(`rules.user.yaml`) 편집 진입점과 재로딩 — 지금은 `projectServiceProvider`가 `loadRules()`를 경로 없이 부른다.
- (선택) VS Code 프로필 목록 읽기 전용 표시 — 실패하면 조용히 숨김(규칙 5). 추천 편집 화면의 프로필 이름 후보에 쓸 수 있다.
- 에러 메시지 정리(엔진 오류는 한국어 고정 — 영어 로케일에서도 한국어로 나옴), 로그 파일(앱 데이터 폴더).
- 릴리스 빌드 실행 확인(`flutter build windows` 확인은 Phase 5 때 완료, Linux/macOS는 해당 OS에서).

## 5. 미결 항목 (Phase와 무관하게 남은 것)

| 항목 | 내용 | 비고 |
|---|---|---|
| 첫 태그 `v0.1.0-rc.1` | 릴리스 파이프라인 end-to-end 확인이 Phase 0 완료 기준의 마지막 조각 | 사용자가 직접 진행하기로 함(건너뜀). macOS 서명·공증 시크릿이 없으면 워크플로의 인증서/서명/공증 단계를 먼저 지워야 함 |
| README 본문 | `README.md`/`README.ko.md`의 `{{TODO}}` 13곳 | 구조 검사(bootstrap)는 통과. 정식 릴리스 전 필수 |
| 스크린샷·데모 GIF | `tool/readme/capture.sh`로 교체(지금은 "준비 중" 이미지) | 첫 화면 완성 후 |
| 아이콘 글리프 해상도 | Icons8 원본이 100px라 1024px로 늘려 씀 | 더 큰 PNG/SVG를 받으면 `app/assets/icon/source_glyph.png` 교체 후 `python tool/icon/generate_icons.py <고양이 PNG>` |
| 업데이트 모듈 | 템플릿의 `app_updater`(git 의존성 `updater-v0.1.0`)를 넣어 둠 | 계획서에 없던 의존성. 필요 없으면 제거 |
| LICENSE | 공개 저장소를 가정해 MIT | 비공개면 변경 |
| `.gitattributes` | 줄바꿈 경고("LF will be replaced by CRLF")가 커밋마다 나옴 | 원하면 추가 |
| `Project.copyWith` | null 인자는 "바꾸지 않음"이라 값 비우기 불가 | 재분석에서 필요해지면 추가 |
| macOS 디버그 `.dev` 식별자 | identity.md §7. macOS에서만 해당 | macOS 빌드를 시작할 때 |
| 엔진 오류 메시지 언어 | 엔진은 한국어 고정 | l10n이 필요해지면 오류 코드 → 앱에서 문구로 |
| `dart format` 주의 | 템플릿 복사 파일은 포맷하지 않는다 | IMPLEMENTED §6 |

## 6. 작업 재개 체크리스트

1. `git status`로 미커밋 변경 확인(Phase 5 전체 + 수정 1번이 들어 있어야 함).
2. 실행 중인 앱이 있으면 닫기(`code_profiler.exe` 잠금).
3. §1 구현 → `dart analyze`/`dart test`(엔진), `flutter analyze`/`flutter test`(앱) → 사용자 수동 확인.
4. 확인 결과를 받아 수정 → 사용자 요청 시 커밋.
