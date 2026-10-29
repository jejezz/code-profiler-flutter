# IMPLEMENTED — 구현 완료 현황

마지막 갱신 기준: Phase 5 구현 + 수동 확인 중 발견된 버그 수정 2건까지.
남은 일과 다음 단계는 [PLAN.md](PLAN.md), 전체 설계는 [IMPLEMENTATION_PLAN.md](IMPLEMENTATION_PLAN.md)에 있다.

## 1. 한눈에 보기

| Phase | 내용 | 상태 | 커밋 |
|---|---|---|---|
| 0 | 스캐폴딩 + application-release-templates conventions-v1 부트스트랩 | 완료 (첫 태그 `v0.1.0-rc.1` 제외) | `5b82def`, `8abbde0` |
| 1 | 모델·JSON·`Result`·규칙 로딩 | 완료 | `5edb345` |
| 2 | 분석기(스캐너·매처·변수·Isolate) | 완료 | `5edb345` |
| 3 | 추천기·JSONC·병합·diff·백업/원자적 쓰기 | 완료 | `5edb345` |
| 4 | 프로세스 계층·`VsCodeCli`·엔진 CLI | 완료 | `d45459b` |
| 5 | 앱(로컬 프로젝트) | 구현 완료, **수동 확인 중**, **커밋 전** | — |

테스트: 엔진 173개 통과(+통합 2개는 기본 제외), 앱 121개 통과. `dart analyze`·`flutter analyze` 경고 0.

## 2. 저장소 구조 (실제)

```text
code-profiler-flutter/
├── Claude.md  IMPLEMENTATION_PLAN.md  IMPLEMENTED.md  PLAN.md  LICENSE
├── README.md  README.ko.md          # 뼈대만 (본문 {{TODO}} 13곳)
├── .github/workflows/release.yml    # app/ 하위 구조에 맞게 수정, Flutter 3.47.8 고정
├── installer/windows/app.iss        # AppId 발급 완료
├── scripts/bump-version.sh  tool/readme/
├── packages/profile_engine/         # 순수 Dart 엔진 + CLI
└── app/                             # Flutter 데스크톱 앱 (Windows 우선)
```

앱 정체성: 표시 이름 `Code Profiler`, 패키지 `code_profiler`, 식별자 `art.zoomon.codeprofiler`, 게시자·저작권자 `Jongyun Ahn`, 버전 `0.1.0-rc.1+1`.

## 3. 엔진 (`packages/profile_engine`)

| 영역 | 파일 | 핵심 |
|---|---|---|
| 결과 타입 | `lib/src/result.dart` | `Result<T>` = `Ok`/`Err`, `EngineError(message, line)` |
| 모델 | `lib/src/model/` | `Project`, `ProjectLocation`(Local/Ssh), `Evidence`, `DetectedType`, `TreeStats`, `AnalysisResult`, `Recommendation` — 불변, `copyWith`, 수동 `toJson`/`fromJson` |
| 규칙 | `lib/src/rules/` | YAML 파서(줄 번호 오류), 매처 트리, 사용자 규칙 병합, 참조 검증. 기본 규칙은 `assets/rules.yaml` → `tool/gen_default_rules.dart`로 `default_rules.dart`에 내장(테스트가 동기화 검사) |
| 분석기 | `lib/src/analyzer/` | 너비 우선 스캔(깊이·파일 수 상한, skipDirs, 링크 미추적), 자체 glob, `findUpward` 변수, 매처 평가, `analyze()`(Isolate) / `analyzeSync()` |
| 추천기 | `lib/src/recommender/` | 3.3절 규칙(주 유형 프로필, 확장 합침/선택, settings 병합, `${변수}` 치환·예약 변수 보존·미해석 시 항목 제외+경고) |
| 설정 처리 | `lib/src/settings/` | JSONC 파서, 병합(표 4.2)+JSON Pointer 식별, `SettingsDiff`, `.bak.<타임스탬프>` 백업 + 임시 파일→rename 쓰기 |
| 프로세스 | `lib/src/process/` | `ProcessRunner` 인터페이스, `SystemProcessRunner`, `FakeProcessRunner`. 출력은 UTF-8 → 실패 시 시스템 인코딩(cp949 등) |
| VS Code | `lib/src/vscode/` | `VsCodeCli`(version, listExtensions, **profileExists, createProfile**, installExtension(s), open), `discoverCodePath`. 프로필은 CLI에 생성 명령이 없어, 없는 이름으로 프로젝트를 열어 만들고 `--list-extensions`가 성공할 때까지 폴링한다 |
| CLI | `lib/src/cli/engine_cli.dart`, `bin/profile_engine.dart` | `--version`, `analyze`, `recommend`, `diff-settings`, `apply-settings`. `--json`이면 stdout에 JSON 하나. 종료 코드 0/1/2/3/4. `dart compile exe` 확인 완료 |

### 알아둘 동작·결정
- `maxDepth: 3` = 파일 경로에 든 디렉터리 단계 수가 3 이하인 파일만 스캔.
- 판정 순서: priority 내림차순, 동률은 규칙 파일 순서. `suppresses`는 맞은 유형 전체 기준으로 한꺼번에 제거.
- 충돌 항목 식별자는 JSON Pointer(RFC 6901). 예: `/files.watcherExclude/**~1build~1**`.
- 종료 코드 4 = 설정 파일 쓰기/처리 실패(기존 settings.json이 잘못된 경우 포함). `diff-settings`도 `--replace-conflicts`를 받는다.
- Windows `code.cmd`는 **셸 없이 직접 실행**한다. `runInShell: true`는 "공백 있는 설치 경로 + 공백 있는 프로필 이름" 조합에서 `cmd`가 따옴표를 벗겨 깨짐(직접 재현·확인). 배치 파일 인자의 `& | < > ^ % "` 등은 거부한다. (`CLAUDE.md` 규칙 17 갱신 완료)
- 통합 테스트는 `dart_test.yaml`로 기본 제외: `dart test -t integration --run-skipped` (실제 VS Code 사용, 이 PC에서 통과).
- 새 의존성: `yaml`, `args` (CLAUDE.md 기술 스택에 명시된 것).

## 4. 앱 (`app/`)

### Phase 0 산출물
Saturn 테마·SeoulNamsan 글꼴·gen-l10n(ko/en)·라이트/다크·`window_manager`·정보 창·업데이트 모듈(`app_updater` git 의존성)·아이콘(고양이+Icons8 글리프, 판 hue 356)·LICENSE(MIT)·릴리스 워크플로. 플랫폼 식별자는 `art.zoomon.codeprofiler`로 통일, macOS 샌드박스 해제.

### Phase 5 산출물
| 영역 | 파일 | 핵심 |
|---|---|---|
| 서비스 | `lib/services/project_service.dart` | 화면이 엔진·VS Code를 쓰는 **유일한 통로**. `ProjectService` 인터페이스 + `LocalProjectService`. 적용은 `Stream<ApplyEvent>` (확장 설치 → 설정 쓰기). SSH는 "아직 지원하지 않음" |
| 저장 | `lib/services/json_file_store.dart`, `project_store.dart`, `app_config.dart`, `app_paths.dart` | `projects.json`(schemaVersion 1, 항목 단위 복구, 새 버전 파일은 읽기 거부), `app_settings.json`(code 경로). 위치는 규약 identity.md §6: `%APPDATA%\CodeProfiler` 등 |
| 상태 | `lib/providers/providers.dart` | Riverpod 3.x: `projectsProvider`, `appConfigProvider`, `vscodeCliProvider`, `projectServiceProvider` 등 |
| 화면 | `lib/screens/` | 목록(폴더 선택·창 드롭·Ctrl/⌘+O/,), 분석 결과(+근접 경쟁 후보 알림), 추천 편집, 설정 diff(충돌별 교체 토글·주석 손실 경고), 적용 진행(줄 단위 로그·재시도), 설정(code 경로 탐지/찾아보기/확인/저장) |
| 위젯·유틸 | `lib/widgets/common.dart`, `lib/services/analysis_hints.dart` | `Pill`, `InfoBanner`, `BottomActionBar`, 오류 스낵바(복사), `closeCompetitors`, `pointerSegments`, `hasUnsafeProfileChars` |
| 문구 | `lib/l10n/app_ko.arb`, `app_en.arb` | 새 키 약 90개, 한·영 쌍 일치(번역 누락 0) |

### 의존성 메모
- `flutter_riverpod 3.4.3`, `file_picker 13.3.0`, `desktop_drop 0.6.1`, `path`. `desktop_drop` 0.9 이상은 `file_picker` 12+와 `cross_file` 버전이 충돌해서 형제 앱과 같은 0.6.x로 맞춤.
- `window_manager ^0.4.3`, `screen_retriever ^0.2.2`(템플릿 코드가 이 버전에서만 컴파일됨).
- `path_provider`는 쓰지 않는다(앱 데이터 폴더 직접 계산).

## 5. 수동 확인에서 발견·수정된 문제

| # | 증상 | 원인 | 조치 | 상태 |
|---|---|---|---|---|
| 1 | 적용 시 `'...\Microsoft' 은(는) 명령이 아닙니다` + 한글 깨짐 | `runInShell`에서 `cmd`가 따옴표 처리 실패 / UTF-8 고정 디코딩 | 셸 없이 직접 실행, 디코딩 폴백, 회귀 테스트 | 수정·테스트 통과 (커밋 전) |
| 2 | 적용 시 `Profile 'Web / Python' not found.` | VS Code는 **없는 프로필**에 `--install-extension`을 못 한다. 프로필 생성 단계가 설계에 없었음 | 적용 순서를 프로필 준비 → 확장 설치 → 설정 쓰기로 변경(`createProfile`, `ApplyStep.profile`), 테스트 추가 | 구현·테스트 통과 (커밋 전), **실제 VS Code 수동 확인 필요** |

## 6. 현재 작업 트리

- 마지막 커밋: `a3c664a` (Phase 5). **프로필 생성 단계(수정 2번)는 미커밋.**
- 사용자 실행 중인 디버그 앱이 `code_profiler.exe`를 잠그므로, 빌드 전에 앱을 닫아야 한다. 검증용 릴리스 빌드는 `app/build/windows/x64/runner/Release/`에 있다.
- 수동 확인용 샘플: 스크래치패드 `samples/esp-idf-sample`(주석·충돌 있는 `.vscode/settings.json` 포함), `samples/gradle-sample`.
- 주의: `app/lib`의 템플릿 복사 파일(`about/`, `settings/`, `theme/`, `update/`, `window/`, `app_identity.dart`)은 `dart format`으로 다시 정렬하지 않는다(린트가 새로 생김). 내가 쓴 파일만 포맷한다.
