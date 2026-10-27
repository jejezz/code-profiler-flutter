# IMPLEMENTATION_PLAN.md — VS Code Profile Manager

이 문서는 설계와 단계별 작업 목록입니다. Claude Code는 Phase 순서대로 진행하고, 각 Phase의 "완료 기준"을 모두 만족해야 다음으로 넘어갑니다.

---

## 1. 목표와 범위

### 목표

1. 로컬 또는 SSH 원격 프로젝트 폴더를 앱에 등록한다.
2. 폴더 구성을 분석해 프로젝트 유형과 근거를 보여준다.
3. 유형에 맞는 VS Code 프로필(이름, 확장 목록)과 `.vscode/settings.json` 패치를 추천한다.
4. 사용자가 추천을 수정·확인하면 프로필을 만들고 확장을 설치하고 설정을 적용한다.
5. 버튼 한 번으로 `code --profile <이름> [--remote ssh-remote+<host>] <경로>`를 실행한다.

### 범위 밖 (하지 않음)

- VS Code 내부 저장소 쓰기(프로필 삭제, 워크스페이스 단위 Enable/Disable 제어)
- SSH 인증 정보 관리
- VS Code 확장으로 배포
- 코드 생성기(freezed, json_serializable) 도입 — 필요 시 사용자 확인 후

---

## 2. 도메인 모델 (`profile_engine/lib/src/model/`)

```dart
/// 프로젝트 위치. 로컬 또는 SSH 원격.
sealed class ProjectLocation {
  const ProjectLocation();
}

final class LocalLocation extends ProjectLocation {
  final String path; // 절대 경로
  const LocalLocation(this.path);
}

final class SshLocation extends ProjectLocation {
  final String host; // ~/.ssh/config 의 Host 이름
  final String path; // 서버상의 절대 경로
  const SshLocation(this.host, this.path);
}

class Project {
  final String id;              // UUID
  final String name;            // 표시 이름, 기본값은 폴더 이름
  final ProjectLocation location;
  final String? profileName;    // 적용된 프로필
  final DateTime addedAt;
  final DateTime? lastOpenedAt;
  final AnalysisResult? lastAnalysis;
}

class Evidence {
  final String ruleId;          // 어떤 매처가
  final String description;     // 예: "sdkconfig 파일 발견"
  final String? relativePath;
}

class DetectedType {
  final String typeId;          // rules.yaml 의 types[].id
  final String label;
  final int priority;
  final List<Evidence> evidence;
}

class TreeStats {
  final int fileCount;          // 스캔한 파일 수 (상한에서 잘렸으면 truncated=true)
  final bool truncated;
  final List<String> largeDirsPresent; // out, build, node_modules 등 존재 여부
}

class AnalysisResult {
  final List<DetectedType> types;     // priority 내림차순, suppress 적용 후
  final TreeStats stats;
  final Map<String, String> variables; // 예: aospRoot
  final DateTime analyzedAt;
}

class Recommendation {
  final String profileName;
  final List<String> extensions;       // 프로필에 설치할 확장 ID
  final List<String> optionalExtensions; // 보조 유형용, 사용자가 선택
  final Map<String, Object?> settingsPatch; // .vscode/settings.json 에 병합할 내용
  final List<String> notes;            // 사용자 안내 문구 (예: compdb 생성 명령)
}
```

모든 모델은 `toJson`/`fromJson`을 수동 구현합니다. 엔진 CLI의 JSON 출력과 앱의 저장 형식에 같이 쓰입니다.

---

## 3. 규칙 파일 (`profile_engine/assets/rules.yaml`)

분석 규칙은 코드가 아니라 YAML로 정의합니다. 새 유형 추가는 이 파일 수정만으로 가능해야 합니다.
앱은 기본 규칙을 내장하고, 사용자 규칙 파일(앱 지원 디렉터리의 `rules.user.yaml`)이 있으면 같은 `id`를 덮어쓰고 새 `id`는 추가합니다.

### 3.1 스키마

```yaml
version: 1

scan:
  maxDepth: 3            # 루트 기준 탐색 깊이
  maxFiles: 20000        # 이 이상이면 truncated
  skipDirs: [.git, .repo, out, build, node_modules, prebuilts, .venv, venv,
             __pycache__, .gradle, .idea, managed_components, .cache, dist, target]

# 변수: 매처와 settings 값에서 ${이름} 으로 참조
variables:
  aospRoot:
    findUpward:          # 프로젝트 경로에서 부모 방향으로 찾기
      anyOf: [".repo", "build/envsetup.sh"]
      maxLevels: 12

types:
  - id: <문자열>
    label: <표시 이름>
    priority: <정수, 클수록 우선>
    match:               # all / any 조합, 중첩 가능
      any:
        - file: <glob, 루트 기준>
        - dir: <glob>
        - fileContains: { glob: <glob>, pattern: <정규식> }
        - variable: <변수 이름>      # 변수가 해석되면 참
    suppresses: [<type id>, ...]   # 이 유형이 맞으면 함께 맞은 유형을 숨김
    profile: <프로필 이름>
    extensions: [<확장 ID>, ...]
    settings: { ... }              # settingsPatch 에 병합
    notes: [<문자열>, ...]
```

### 3.2 기본 규칙 (초기 내용)

```yaml
types:
  - id: esp-idf
    label: ESP-IDF
    priority: 100
    match:
      any:
        - file: sdkconfig
        - file: "**/idf_component.yml"
        - fileContains: { glob: CMakeLists.txt, pattern: "IDF_PATH|project\\.cmake" }
    suppresses: [cmake]
    profile: ESP-IDF
    extensions: [espressif.esp-idf-extension, llvm-vs-code-extensions.vscode-clangd]
    settings:
      files.watcherExclude: { "**/build/**": true, "**/managed_components/**": true }
      search.exclude: { "**/build": true, "**/managed_components": true }
    notes:
      - "idf.port 등 보드별 설정은 프로젝트 settings.json 에 직접 추가하세요."

  - id: aosp-module
    label: AOSP 모듈
    priority: 90
    match:
      all:
        - any:
            - file: Android.bp
            - file: Android.mk
        - variable: aospRoot
    suppresses: [cmake, make]
    profile: C++ AOSP
    extensions: [llvm-vs-code-extensions.vscode-clangd]
    settings:
      clangd.arguments:
        - "--compile-commands-dir=${aospRoot}/out/soong/development/ide/compdb"
        - "--background-index"
        - "--pch-storage=disk"
        - "--malloc-trim"
        - "-j=4"
      files.watcherExclude: { "**/out/**": true, "**/.cache/**": true }
      search.followSymlinks: false
    notes:
      - "compdb 생성: cd ${aospRoot} && source build/envsetup.sh && lunch <target> && SOONG_GEN_COMPDB=1 SOONG_GEN_COMPDB_DEBUG=1 m nothing"

  - id: java-gradle
    label: Java (Gradle)
    priority: 70
    match:
      any:
        - file: build.gradle
        - file: build.gradle.kts
        - file: settings.gradle
        - file: settings.gradle.kts
    profile: Java
    extensions: [vscjava.vscode-java-pack, vscjava.vscode-gradle]
    settings:
      java.import.exclusions: ["**/build/**", "**/.gradle/**", "**/node_modules/**"]
      java.configuration.updateBuildConfiguration: interactive

  - id: java-maven
    label: Java (Maven)
    priority: 70
    match:
      any:
        - file: pom.xml
    profile: Java
    extensions: [vscjava.vscode-java-pack]
    settings:
      java.import.exclusions: ["**/target/**", "**/node_modules/**"]
      java.configuration.updateBuildConfiguration: interactive

  - id: cmake
    label: CMake
    priority: 50
    match:
      any:
        - file: CMakeLists.txt
    profile: C++
    extensions: [llvm-vs-code-extensions.vscode-clangd, ms-vscode.cmake-tools]
    settings:
      cmake.configureOnOpen: false
      cmake.configureOnEdit: false
      cmake.buildDirectory: "${workspaceFolder}/build"
      cmake.configureSettings: { CMAKE_EXPORT_COMPILE_COMMANDS: "ON" }

  - id: linux-kernel
    label: Linux 커널 / 부트로더
    priority: 60
    match:
      all:
        - file: Kconfig
        - file: Makefile
    suppresses: [make]
    profile: Embedded Make
    extensions: [llvm-vs-code-extensions.vscode-clangd]
    settings:
      files.watcherExclude: { "**/*.o": true, "**/*.cmd": true }
    notes:
      - "빌드 후 ./scripts/clang-tools/gen_compile_commands.py 로 compile_commands.json 을 생성하세요."

  - id: make
    label: Makefile
    priority: 40
    match:
      any:
        - file: Makefile
        - file: makefile
        - file: GNUmakefile
    profile: Embedded Make
    extensions: [llvm-vs-code-extensions.vscode-clangd]
    settings:
      "[makefile]": { editor.insertSpaces: false }
    notes:
      - "bear -- make 로 compile_commands.json 을 생성하면 clangd 가 정확해집니다."

  - id: node
    label: JavaScript / TypeScript
    priority: 60
    match:
      any:
        - file: package.json
        - file: tsconfig.json
        - file: jsconfig.json
    profile: Web / Python
    extensions: [dbaeumer.vscode-eslint, esbenp.prettier-vscode]
    settings:
      eslint.run: onSave
      files.watcherExclude: { "**/node_modules/**": true, "**/dist/**": true }
      search.exclude: { "**/node_modules": true, "**/dist": true }

  - id: python
    label: Python
    priority: 60
    match:
      any:
        - file: pyproject.toml
        - file: requirements.txt
        - file: setup.py
    profile: Web / Python
    extensions: [ms-python.python]
    settings:
      python.analysis.diagnosticMode: openFilesOnly
      python.analysis.exclude: ["**/.venv", "**/__pycache__"]
      files.watcherExclude: { "**/.venv/**": true, "**/__pycache__/**": true }

# 트리 규모에 따른 추가 패치 (유형과 무관하게 적용)
sizeRules:
  - when: { truncated: true }
    settings:
      search.followSymlinks: false
    notes:
      - "트리가 매우 큽니다. 전체 대신 작업 모듈 폴더만 여는 것을 권장합니다."
```

### 3.3 판정 규칙

1. 모든 type의 `match`를 평가해 맞은 것을 모은다.
2. 맞은 type들의 `suppresses`에 들어 있는 type을 제거한다.
3. priority 내림차순 정렬. 최상위 type이 **주 유형**이고 그 `profile`이 추천 프로필이 된다.
4. 주 유형과 같은 프로필을 쓰는 type의 `extensions`는 `extensions`에 합친다. 다른 프로필의 type은 `optionalExtensions`로 보낸다.
5. `settings`는 주 유형 → 나머지 유형 → `sizeRules` 순으로 병합한다(4.2의 병합 규칙).
6. `${변수}`를 치환한다. 해석되지 않은 변수가 남으면 해당 설정 항목을 빼고 notes에 경고를 추가한다.
   `${workspaceFolder}`처럼 VS Code가 해석하는 변수는 치환하지 않고 그대로 둔다(예약 목록: `workspaceFolder`, `workspaceFolderBasename`, `userHome`, `env:*`).

---

## 4. 설정 파일 처리 (`profile_engine/lib/src/settings/`)

### 4.1 JSONC 파서

- `//` 주석, `/* */` 주석, 끝 쉼표를 허용한다. 문자열 안의 `//`는 주석이 아니다.
- 구현: 주석·끝 쉼표를 제거한 문자열을 만든 뒤 `jsonDecode`. 직접 구현하고 테스트로 검증한다.
- 결과에 `hadComments: bool`을 함께 돌려준다.

### 4.2 병합 규칙

| 기존 값 | 패치 값 | 결과 |
| --- | --- | --- |
| Map | Map | 키 단위 재귀 병합 |
| List | List | 기존 순서 유지 + 없는 항목만 뒤에 추가 |
| 그 외 | 아무거나 | **기존 값 유지**, diff에 "충돌(기존 유지)"로 표시 |
| 없음 | 아무거나 | 패치 값 추가 |

사용자가 diff 화면에서 충돌 항목별로 "패치 값으로 교체"를 선택할 수 있다.

### 4.3 diff

- 결과 객체: 추가된 키, 변경 없는 키, 충돌 키 목록 + 최종 JSON 문자열(2칸 들여쓰기).
- `hadComments`가 참이면 "기존 주석이 사라집니다" 경고 플래그.

### 4.4 쓰기

1. 기존 파일이 있으면 `settings.json.bak.<yyyyMMdd-HHmmss>`로 복사
2. 임시 파일에 쓴 뒤 rename(원자적 교체)
3. `.vscode/` 디렉터리가 없으면 생성

---

## 5. 프로세스 계층 (`profile_engine/lib/src/process/`, `vscode/`, `remote/`)

### 5.1 ProcessRunner

```dart
abstract interface class ProcessRunner {
  Future<ProcessOutput> run(String executable, List<String> args,
      {Duration? timeout, bool runInShell = false});

  /// 진행 상황을 줄 단위로 흘려보내는 실행 (확장 설치용)
  Stream<ProcessEvent> start(String executable, List<String> args,
      {bool runInShell = false});
}
```

- `SystemProcessRunner`: `dart:io` 구현
- `FakeProcessRunner`: 테스트용. 호출 기록을 남기고 미리 정한 응답을 돌려줌

### 5.2 VsCodeCli

| 메서드 | 실행 명령 |
| --- | --- |
| `version()` | `code --version` |
| `listExtensions(profile)` | `code --profile <p> --list-extensions` |
| `installExtension(profile, id)` | `code --profile <p> --install-extension <id>` (stream) |
| `open(profile, location)` | Local: `code --profile <p> <path>` / SSH: `code --profile <p> --remote ssh-remote+<host> <path>` |

- `code` 실행 파일 경로는 설정값. 기본값은 OS별 탐색 결과(PATH의 `code`, macOS `/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code`, Linux `/snap/bin/code`, `/usr/bin/code`).
- Windows의 `code.cmd`는 셸 없이 직접 실행한다(`runInShell: true`는 공백이 든 경로+인자 조합에서 `cmd`가 따옴표를 벗겨 깨짐). 배치 파일 인자의 셸 특수문자는 거부한다.
- 확장 설치는 이미 설치된 확장을 `listExtensions`로 확인해 건너뛴다.

### 5.3 원격 실행 (`remote/`)

원격 프로젝트는 **엔진 CLI를 서버에 배포**해서 분석·설정 쓰기를 서버에서 실행하고 JSON 결과만 받는다.

- 배포 위치: `~/.local/bin/profile-engine`
- 버전 확인: `ssh -o BatchMode=yes -o ConnectTimeout=10 <host> '~/.local/bin/profile-engine --version'`
  - 없거나 버전이 다르면 배포 필요 상태로 표시
- 서버 아키텍처 확인: `ssh <host> 'uname -m'` → `x86_64` / `aarch64`
- 빌드: `dart compile exe bin/profile_engine.dart -o build/profile-engine-linux-<arch>`
  - Dart 3.8 이상에서 Linux 대상 교차 컴파일(`--target-os linux --target-arch x64|arm64`)을 우선 시도
  - 교차 컴파일이 안 되는 환경이면, 앱이 사용자에게 서버에서 직접 빌드하는 명령을 안내
- 전송: `scp -o BatchMode=yes <binary> <host>:~/.local/bin/profile-engine` 후 `chmod +x`
- 모든 원격 인자는 `shellQuote()`를 거친다

---

## 6. 엔진 CLI (`profile_engine/bin/profile_engine.dart`)

`args` 패키지 사용. 모든 출력은 `--json`일 때 stdout에 JSON 한 개, 사람이 읽는 메시지는 stderr.

```text
profile-engine --version
profile-engine analyze <path> [--rules <file>] --json
profile-engine recommend <path> [--rules <file>] --json        # analyze + recommend
profile-engine diff-settings <path> --patch <json-file> [--replace-conflicts p1,p2] --json  # 쓰지 않고 diff만
profile-engine apply-settings <path> --patch <json-file> [--replace-conflicts key1,key2] --json
```

종료 코드: 0 성공, 1 사용법 오류, 2 경로 없음/권한 없음, 3 규칙 파일 오류, 4 설정 파일 쓰기/처리 실패.

`--patch`의 JSON은 SSH로 넘길 때 임시 파일 대신 stdin(`--patch -`)으로도 받을 수 있게 한다.

---

## 7. 앱 UI (`app/`)

### 7.1 화면

| 화면 | 내용 |
| --- | --- |
| 프로젝트 목록 | 이름, 위치(로컬/호스트명), 주 유형, 프로필, 마지막 열기. 열기·재분석·삭제 버튼. 드래그 앤 드롭으로 로컬 폴더 추가 |
| 프로젝트 추가 | 로컬: 폴더 선택. SSH: 호스트(`~/.ssh/config`의 Host 목록에서 선택 또는 입력) + 원격 경로 입력, 연결 테스트 버튼 |
| 분석 결과 | 판정 유형과 근거(Evidence) 목록, 트리 통계, 해석된 변수 |
| 추천 편집 | 프로필 이름(기존 프로필 선택 또는 새 이름), 확장 체크리스트(필수/선택), notes |
| 설정 diff | 추가/충돌/유지 항목, 충돌별 교체 토글, 주석 손실 경고, 적용 버튼 |
| 적용 진행 | 단계별 진행: 프로필 확장 설치(줄 단위 로그) → 설정 쓰기 → 완료. 실패 시 단계와 메시지 |
| 설정 | `code` 경로, 사용자 규칙 파일 열기, 원격 엔진 배포 상태(호스트별) |

### 7.2 상태와 저장

- Riverpod provider: `projectsProvider`(목록, 저장 포함), `engineProvider`(엔진 인스턴스), `vscodeCliProvider`, `settingsProvider`
- 저장: 앱 데이터 폴더(규약 identity.md §6, `path_provider` 미사용)의 `projects.json`, `app_settings.json`
- 저장 형식에 `schemaVersion`을 넣는다

### 7.3 `~/.ssh/config` 호스트 목록

- `Host` 줄의 이름만 읽는다. 와일드카드(`*`, `?`)가 들어간 패턴은 제외
- `Include` 지시어는 1단계 깊이까지 따라간다
- 파싱 실패 시 수동 입력만 허용

---

## 8. 테스트

### 8.1 픽스처 (`profile_engine/test/fixtures/`)

테스트 시작 시 임시 디렉터리에 생성하는 헬퍼(`createFixture(Map<String, String> files)`)로 만든다. 저장소에 실제 트리를 커밋하지 않는다.

| 픽스처 | 내용 | 기대 주 유형 |
| --- | --- | --- |
| esp_idf | `CMakeLists.txt`(IDF_PATH 포함), `sdkconfig`, `main/main.c` | esp-idf, cmake 숨김 |
| aosp_module | `aosp/.repo/`, `aosp/build/envsetup.sh`, `aosp/vendor/x/hal/Android.bp` → 경로는 hal 폴더 | aosp-module, aospRoot 해석 |
| aosp_no_root | `Android.bp`만 있고 상위에 `.repo` 없음 | aosp-module 미판정 |
| gradle | `settings.gradle.kts`, `app/build.gradle.kts` | java-gradle |
| kernel | `Kconfig`, `Makefile` | linux-kernel, make 숨김 |
| mixed_web_py | `package.json`, `requirements.txt` | 같은 프로필 → 확장 합쳐짐 |
| big_tree | 파일 수가 maxFiles 초과 | truncated, sizeRules 적용 |
| skip_dirs | `node_modules/` 안에만 `pom.xml` | java-maven 미판정 |
| symlink_loop | 자기 자신을 가리키는 심볼릭 링크 | 무한 루프 없이 종료 |

### 8.2 단위 테스트 대상

- JSONC 파서: 줄 주석, 블록 주석, 문자열 안 `//`, 끝 쉼표, 이스케이프
- 병합: 표 4.2의 네 경우, 중첩 Map, List 중복 제거
- 변수 치환: 해석 성공, 미해석 시 항목 제거 + 경고, 예약 변수 보존
- 규칙 로딩: 스키마 오류 메시지(줄 번호 포함), 사용자 규칙 덮어쓰기
- VsCodeCli: FakeProcessRunner로 인자 구성 검증(로컬/SSH, Windows 배치 파일)
- shellQuote: 공백, 작은따옴표, `$`, 백틱

---

## 9. 단계별 작업 (Phase)

### Phase 0 — 스캐폴딩 (application-release-templates conventions-v1 부트스트랩)

우선 지원 OS: **Windows** (`flutter run -d windows`). Linux/macOS 플랫폼 폴더는 같이 생성하되
수동 실행 확인은 Windows로만 한다.

앱 정체성(이미 확정, CLAUDE.md 표 참고): 표시 이름 `Code Profiler`, 파일 이름 `CodeProfiler`,
패키지명 `code_profiler`, 식별자 `art.zoomon.codeprofiler`, 게시자/저작권자 `Jongyun Ahn`.

#### 0.1 profile_engine (순수 Dart, 규약 영향 없음)

- [ ] `packages/profile_engine` 생성 (`dart create -t package`)
- [ ] `analysis_options.yaml` (strict 옵션)

#### 0.2 app 부트스트랩 — `conventions/README.md`의 "새 앱 시작 체크리스트" 순서

1. [ ] **정체성 반영** — `flutter create --platforms=linux,macos,windows --org art.zoomon --project-name code_profiler app`
   생성 후 macOS `AppInfo.xcconfig`, Windows `Runner.rc`, Linux `CMakeLists.txt`의
   이름·저작권·식별자를 위 표 값으로 통일 (`com.example` 잔존 금지).
   app의 pubspec에 `profile_engine: { path: ../packages/profile_engine }` 추가.
2. [ ] **LICENSE 추가** — `conventions/licensing.md` 템플릿(MIT, 저작권자 `Jongyun Ahn`, 연도는 첫 릴리스 연도).
3. [ ] **공통 파일 복사** — `application-release-templates/common/README.md` 순서대로
   (`lib/app_identity.dart`, 정보 창, ARB 키, 아이콘/버전 스크립트). 자리 표시자를 위 정체성 값으로 채운다.
4. [ ] **아이콘** — 글리프 SVG를 `assets/icon/source_glyph.svg`에 두고
   `python3 tool/icon/generate_icons.py` 실행 (`conventions/icons.md`).
5. [ ] **버전** — `pubspec.yaml` 버전을 `0.1.0-rc.1+1`로 시작 (`conventions/versioning.md`).
   이후 `scripts/bump-version.sh`로만 올린다.
6. [ ] **앱 골격** — 첫 화면 전에 아래를 먼저 깐다.
   - Saturn 테마 토큰과 공통 위젯 (`conventions/ui-ux.md`)
   - SeoulNamsan + 대체 글꼴 (`conventions/fonts.md`)
   - `gen-l10n` ko/en + 언어 전환 (`conventions/localization.md`)
   - 시스템/라이트/다크 전환 (`conventions/theming.md`)
   - `window_manager` 창 크기 + `window-placement.md`의 `placeWindowAtStartup` (center: true 금지)
   - 앱 바 오른쪽 `테마 | 언어 | 정보` 버튼
7. [ ] **정보 창** — `conventions/about-dialog.md` 형식. 버전은 `package_info_plus`로 읽고 하드코딩 금지.
8. [ ] **릴리스 워크플로 복사** — `application-release-templates/desktop/`의 GitHub Actions·Inno Setup·
   Linux `install.sh`. 시크릿 등록(서명/공증 등, 해당 시).
9. [ ] **README / CLAUDE.md** — `python3 tool/readme/init_readme.py`로 뼈대 생성(`conventions/readme-guide.md`).
   CLAUDE.md의 conventions 버전 고지 줄 유지(현재 `conventions-v1`).
10. [ ] **첫 태그** — 프리릴리스 `v0.1.0-rc.1`을 태그해서 릴리스 파이프라인이 끝까지 도는 것을 확인.

macOS entitlements(샌드박스 해제, `com.apple.security.app-sandbox: false`)는 0.2의 1단계에서
플랫폼 폴더가 생성된 뒤 바로 적용한다 (아키텍처 규칙 16).

**완료 기준**: `dart analyze`, `flutter analyze` 경고 0, `flutter run -d windows`로 Saturn 테마 적용된
빈 창 + 정보 창이 뜸, `v0.1.0-rc.1` 태그로 데스크톱 릴리스 워크플로가 끝까지 성공.

### Phase 1 — 모델과 규칙 로딩

- [x] 2장의 모델 + JSON 직렬화
- [x] `Result<T>` 타입
- [x] rules.yaml 로딩·검증, 사용자 규칙 병합
- [x] 3.2의 기본 규칙 파일 (`assets/rules.yaml`). 컴파일된 엔진 CLI에는 assets가 따라가지 않아 `tool/gen_default_rules.dart`가 `lib/src/rules/default_rules.dart` 상수로 내장하고, 테스트가 둘의 동기화를 검사한다

**완료 기준**: 모델 왕복 직렬화 테스트, 규칙 로딩 성공/실패 테스트 통과.

### Phase 2 — 분석기

- [x] 스캐너: 깊이·파일 수 상한, skipDirs, followLinks false, TreeStats
- [x] 매처: file, dir, fileContains, variable, all/any 중첩
- [x] 변수 해석: findUpward
- [x] suppresses, priority 정렬
- [x] `Isolate.run()`으로 감싼 공개 API `analyze(path)`

**완료 기준**: 8.1 픽스처 전부 기대 결과와 일치.

### Phase 3 — 추천기와 설정 처리

- [x] 3.3 판정 규칙에 따른 Recommendation 생성
- [x] JSONC 파서, 병합, diff, 백업 후 원자적 쓰기

**완료 기준**: 8.2의 JSONC·병합·변수 치환 테스트 통과. 픽스처에 대해 추천 결과 스냅샷 테스트.

### Phase 4 — 프로세스 계층과 엔진 CLI

- [x] ProcessRunner, SystemProcessRunner, FakeProcessRunner
- [x] VsCodeCli (code 경로 탐색 포함)
- [x] 6장의 엔진 CLI 명령 전부
- [x] `dart compile exe` 빌드 확인

구현 메모: Windows 배치 파일(`code.cmd`)이나 셸을 거칠 때는 인자에 `& | < > ^ % " `` 줄바꿈`이 있으면 실행하지 않고 오류로 돌려준다. 프로세스 출력은 UTF-8, 실패 시 시스템 인코딩으로 읽는다. 통합 테스트는 `dart_test.yaml`로 기본 제외(`dart test -t integration --run-skipped`). 종료 코드 4는 설정 파일 처리 실패(기존 settings.json이 잘못된 경우 포함)를 뜻하고, `diff-settings`도 `--replace-conflicts`를 받아 선택을 반영한 미리보기를 만든다.

**완료 기준**: FakeProcessRunner 기반 테스트 통과. 컴파일된 실행 파일로 `analyze <픽스처> --json`이 올바른 JSON 출력.

### Phase 5 — 앱: 로컬 프로젝트

- [x] 프로젝트 목록·추가(폴더 선택, 드래그 앤 드롭)·저장
- [x] 분석 결과, 추천 편집, 설정 diff, 적용 진행 화면
- [x] 열기 버튼
- [x] 설정 화면(code 경로)

구현 메모: 상태 관리는 `flutter_riverpod` 3.x. 화면은 엔진을 직접 부르지 않고 `ProjectService`(로컬 구현 `LocalProjectService`)만 쓴다 — Phase 6에서 SSH 구현을 같은 인터페이스에 붙인다. 저장은 `path_provider` 대신 규약(identity.md §6)의 앱 데이터 폴더(`%APPDATA%\CodeProfiler`, macOS `~/Library/Application Support/CodeProfiler`, Linux `${XDG_CONFIG_HOME:-~/.config}/CodeProfiler`)에 `projects.json`·`app_settings.json`으로 한다. `desktop_drop 0.6.1`은 `file_picker 13`과 `cross_file` 버전이 맞는 조합이다(0.9 이상은 충돌). 프로젝트 추가는 폴더 선택 또는 창 드롭이며, SSH 입력은 Phase 6에서 더한다.

**완료 기준**: 로컬 ESP-IDF·Gradle 샘플 프로젝트로 등록 → 분석 → 추천 → 적용 → VS Code가 해당 프로필로 열림을 수동 확인. 위젯 테스트로 목록·diff 화면 기본 동작 검증.

### Phase 6 — SSH 원격 프로젝트

- [ ] `~/.ssh/config` 호스트 파서
- [ ] shellQuote, 원격 실행 래퍼(BatchMode, 타임아웃)
- [ ] 원격 엔진 버전 확인·아키텍처 확인·배포
- [ ] 원격 analyze/recommend/diff/apply를 엔진 CLI 호출로 연결
- [ ] 열기 시 `--remote ssh-remote+<host>`
- [ ] 연결 실패·엔진 없음·권한 없음 상태를 화면에 표시

**완료 기준**: 실제 SSH 서버의 AOSP 모듈 폴더로 전 과정 수동 확인(aospRoot 해석, compdb 경로가 settings에 들어감). 통합 테스트는 `integration` 태그.

### Phase 7 — 마무리

- [ ] 사용자 규칙 파일 편집 진입점과 재로딩
- [ ] (선택) VS Code 프로필 목록 읽기 전용 표시 — 실패 시 숨김
- [ ] 에러 메시지 정리, 로그 파일(앱 지원 디렉터리)
- [ ] 릴리스 빌드 (`flutter build linux|macos|windows`)

**완료 기준**: 세 OS 중 사용자가 쓰는 OS에서 릴리스 빌드 실행 확인.

---

## 10. 열린 질문 (해결됨)

1. ~~주로 쓰는 로컬 OS는 무엇인가?~~ → **Windows** 우선 지원 (Phase 9 참고).
2. ~~원격 서버 아키텍처는 x86_64인가?~~ → **x86_64만** 교차 컴파일 대상으로 삼는다
   (`profile-engine-linux-x64`만 Phase 6에서 빌드; aarch64는 필요해지면 추가).
3. 기존 프로필 이름을 이미 쓰고 있다면 rules.yaml의 `profile` 값을 그에 맞출 것인가?
   → 아직 충돌 보고가 없으므로 3.2의 기본값(`ESP-IDF`, `C++ AOSP`, `Java`, `C++`, `Embedded Make`, `Web / Python`)을
   그대로 쓴다. 실제 VS Code에 동일 이름의 다른 프로필이 있으면 Phase 5에서 다시 확인한다.
4. ~~한 프로젝트에 여러 프로필 후보가 비슷한 우선순위로 맞을 때, 자동 선택할지 매번 묻게 할지?~~
   → **자동 선택(최고 priority) + 알림**. 판정 결과 화면(7.1 "분석 결과")에
   priority 차이가 작은(기본 임계값 10 이하) 후보가 있으면 "근접 경쟁 후보" 배지로 표시하고,
   사용자가 원하면 추천 편집 화면에서 다른 유형의 프로필로 바꿀 수 있게 한다
   (강제 선택 모달은 띄우지 않음).
