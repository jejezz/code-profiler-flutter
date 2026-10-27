# CLAUDE.md — VS Code Profile Manager (Code Profiler)

이 파일은 Claude Code가 이 저장소에서 작업할 때 따르는 규칙입니다.
상세 설계와 단계별 작업 목록은 `IMPLEMENTATION_PLAN.md`에 있습니다. 작업 시작 전에 반드시 읽으세요.

릴리스·버전·패키징·정보 창·아이콘·라이선스·UI/UX·글꼴·언어·테마는
https://github.com/jejezz/application-release-templates/tree/main/conventions
규약을 따른다. 이 앱에 적용된 규약 버전: conventions-v1 (미적용: README 본문)

### 앱 정체성 (identity.md 기준, 한 번 정하면 릴리스 후 bundle id/AppId는 바꾸지 않음)

| 항목 | 값 |
| --- | --- |
| 표시 이름 | Code Profiler |
| 파일 이름 (PascalCase) | CodeProfiler |
| 패키지/바이너리 (snake_case) | code_profiler |
| 저장소 (kebab-case) | code-profiler-flutter |
| 식별자 접두어 | art.zoomon |
| 식별자 | art.zoomon.codeprofiler |
| 게시자 / 저작권자 | Jongyun Ahn |
| 웹사이트 | 이 앱의 GitHub 저장소 URL |

`flutter create --org art.zoomon --project-name code_profiler app`으로 생성하고,
플랫폼별로 다르게 생성되는 식별자를 커밋 전에 `art.zoomon.codeprofiler`로 통일합니다
(`com.example`이 남으면 안 됨).

## 프로젝트 개요

프로젝트 폴더(로컬 또는 SSH 원격)를 등록하면 폴더 구성을 분석해 프로젝트 유형(ESP-IDF, AOSP, Java, CMake, Make, JS/TS, Python 등)을 판정하고,
알맞은 VS Code 프로필과 `.vscode/settings.json`을 추천·생성한 뒤, `code --profile` 로 VS Code를 열어주는 Flutter 데스크톱 앱입니다.

사용자 배경: C/C++/Java 고급, Dart/Flutter는 이번이 첫 프로젝트에 가깝습니다. 코드에는 Dart 관용구를 쓰되,
낯선 Flutter/Dart 개념(Isolate, Riverpod provider, sealed class 등)이 처음 나오는 곳에는 짧은 주석을 답니다.

## 기술 스택

- Flutter 3.x stable, 데스크톱 타깃: Linux, macOS, Windows
- Dart 3.x (sealed class, records, pattern matching 사용)
- 상태 관리: `flutter_riverpod`
- 패키지: `yaml`, `path`, `path_provider`, `file_picker`, `desktop_drop`, `args`(엔진 CLI), `test`
- application-release-templates 공통 패키지(Phase 0 부트스트랩에서 추가): `window_manager`, `screen_retriever`,
  `package_info_plus`, `url_launcher`, `shared_preferences`, `intl`, `flutter_localizations`(sdk)
- 영속화: 1단계는 앱 지원 디렉터리의 JSON 파일. SQLite(`drift`)는 필요해질 때만 도입
- SSH: 시스템 `ssh`/`scp` 실행 파일을 `Process`로 호출. SSH 라이브러리(`dartssh2` 등)는 쓰지 않음

새 의존성을 추가하기 전에는 이유를 설명하고 사용자 확인을 받으세요.

## 저장소 구조

```text
code-profiler-flutter/
├── CLAUDE.md
├── IMPLEMENTATION_PLAN.md
├── packages/
│   └── profile_engine/          # 순수 Dart. Flutter import 금지
│       ├── lib/
│       │   ├── profile_engine.dart        # 공개 API export
│       │   └── src/
│       │       ├── model/                 # Project, DetectionResult, Recommendation ...
│       │       ├── rules/                 # rules.yaml 로딩·검증
│       │       ├── analyzer/              # 폴더 스캔, 매처
│       │       ├── recommender/           # 판정 → 추천
│       │       ├── settings/              # JSONC 파싱, 병합, diff
│       │       ├── process/               # ProcessRunner 추상화
│       │       ├── vscode/                # VsCodeCli 래퍼
│       │       └── remote/                # SSH 실행, 원격 엔진 배포
│       ├── assets/rules.yaml              # 기본 규칙
│       ├── bin/profile_engine.dart        # 엔진 CLI (원격 배포 대상)
│       └── test/
│           ├── fixtures/                  # 유형별 가짜 프로젝트 트리
│           └── ...
└── app/                         # Flutter UI
    ├── lib/
    │   ├── main.dart
    │   ├── providers/
    │   ├── screens/
    │   └── widgets/
    ├── macos/ linux/ windows/
    └── pubspec.yaml             # profile_engine 을 path 의존성으로 참조
```

## 자주 쓰는 명령

```bash
# 엔진
cd packages/profile_engine
dart pub get
dart analyze
dart format .
dart test
dart run bin/profile_engine.dart analyze <path> --json
dart compile exe bin/profile_engine.dart -o build/profile-engine

# 앱
cd app
flutter pub get
flutter analyze
flutter test
flutter run -d linux     # 또는 macos, windows
```

작업 단위를 끝낼 때마다 `dart analyze`(앱은 `flutter analyze`)와 테스트를 실행하고, 경고·실패가 없어야 다음 단계로 넘어갑니다.

## 반드시 지킬 규칙

### 아키텍처

1. `profile_engine`은 Flutter에 의존하지 않습니다. `package:flutter/...` import 금지. 같은 엔진이 원격 서버에서 CLI로 돌기 때문입니다.
2. 외부 프로세스 호출(`code`, `ssh`, `scp`)은 모두 `ProcessRunner` 인터페이스를 거칩니다. `Process.run`을 직접 부르는 코드는 `process/` 구현체에만 둡니다. 테스트는 `FakeProcessRunner`로 합니다.
3. UI는 엔진의 공개 API(`profile_engine.dart`가 export하는 것)만 사용합니다.

### VS Code 내부 데이터

4. VS Code 사용자 데이터 폴더(`~/.config/Code/User/`, `~/Library/Application Support/Code/User/`, `%APPDATA%\Code\User\`)의 파일에는 **절대 쓰지 않습니다.** 형식이 비공개이고 버전마다 바뀝니다.
5. 프로필 생성·확장 설치·열기는 VS Code CLI로만 합니다. 프로필 목록 표시 같은 읽기가 필요하면 읽기 전용으로, 파싱 실패 시 기능을 조용히 끄는 방어 코드로 작성합니다.
6. 프로필과 폴더의 연결은 VS Code 내부 상태에 의존하지 않고, 앱이 항상 `--profile`을 붙여 여는 것으로 보장합니다.

### 프로젝트 파일 쓰기

7. `.vscode/settings.json` 등 프로젝트 파일을 쓰기 전에는 반드시 dry-run diff를 사용자에게 보여주고 확인을 받습니다.
8. 기존 파일은 덮어쓰기 전에 `settings.json.bak.<타임스탬프>`로 백업합니다.
9. VS Code 설정 파일은 JSONC(주석, 끝 쉼표 허용)입니다. `dart:convert`의 `jsonDecode`로 바로 읽지 말고 `settings/jsonc.dart`의 파서를 거칩니다. 주석이 있던 파일을 병합해 다시 쓰면 주석이 사라진다는 사실을 diff 화면에 경고로 표시합니다.

### 파일 스캔

10. 스캔은 `Isolate.run()`에서 실행해 UI 스레드를 막지 않습니다.
11. `followLinks: false`, 최대 깊이와 최대 파일 수 상한을 둡니다(기본값은 rules.yaml의 `scan` 항목).
12. `skipDirs`(`.git`, `.repo`, `out`, `build`, `node_modules`, `prebuilts` 등)에는 들어가지 않습니다. 단, 디렉터리 존재 여부 자체는 판정 근거로 기록합니다.

### SSH

13. 인증 정보(비밀번호, 키)를 앱이 저장하거나 입력받지 않습니다. 시스템 `ssh`와 `~/.ssh/config`, ssh-agent에 맡깁니다.
14. 모든 ssh 호출에 `-o BatchMode=yes`와 연결 타임아웃을 붙여 프롬프트 대기로 멈추지 않게 합니다.
15. 원격 경로와 인자는 셸 인젝션이 없도록 단일 인용부호로 이스케이프하는 헬퍼(`remote/shell_quote.dart`)를 거칩니다.

### 플랫폼

16. macOS: `macos/Runner/DebugProfile.entitlements`와 `Release.entitlements`에서 `com.apple.security.app-sandbox`를 `false`로 둡니다(외부 프로세스 실행, 임의 폴더 접근 필요).
17. Windows: `code`는 `code.cmd`이므로 `runInShell: true`가 필요합니다. `code` 경로는 사용자가 설정에서 바꿀 수 있어야 합니다.

## 코드 스타일

- `dart format` 기본 규칙, `package:lints/recommended.yaml` + `analysis_options.yaml`의 strict 옵션(`strict-casts`, `strict-raw-types`)
- 모델은 불변(immutable) 클래스, `copyWith`, `toJson`/`fromJson` 수동 구현(코드 생성기 도입은 사용자 확인 후)
- 실패는 예외 대신 결과 타입으로 표현합니다: `sealed class Result<T> { Ok<T>, Err<T> }` (엔진 공개 API)
- 사용자에게 보이는 문자열은 한국어, 코드·로그·식별자는 영어

## 작업 방식

- `IMPLEMENTATION_PLAN.md`의 단계(Phase) 순서를 따르고, 각 단계의 완료 기준을 모두 만족한 뒤 다음 단계로 갑니다.
- Phase 0은 로컬 클론된 `../application-release-templates` 저장소의 "새 앱 시작 체크리스트"(conventions/README.md)를
  그대로 따릅니다. 체크리스트 항목이 끝날 때마다 어떤 파일을 복사·수정했는지 보고합니다.
- 단계를 시작할 때 무엇을 할지 짧게 요약하고, 끝날 때 바뀐 파일과 테스트 결과를 보고합니다.
- 설계 문서와 다르게 구현해야 할 이유가 생기면 먼저 사용자에게 묻고, 합의되면 문서도 함께 고칩니다.
- 실제 VS Code나 SSH 서버가 필요한 통합 테스트는 `@Tags(['integration'])`을 붙이고 기본 `dart test`에서는 제외합니다.