# VS Code 확장 격리 가이드: 프로필과 워크스페이스로 언어별 개발환경 분리하기

Oct 27, 2026 · @JYAHN

## 1. 왜 필요한가

결론부터: 설치된 확장 개수보다 **필요 없는 곳에서 켜지는 확장과 언어 서버**가 느려짐의 원인입니다. 이 문서는 "필요한 곳에서만 켠다"를 VS Code 기능만으로 구현하는 방법을 단계별로 설명합니다.

VS Code 확장은 `package.json`의 `activationEvents` 조건이 맞을 때만 활성화됩니다. 예를 들어 `onLanguage:java`인 확장은 `.java` 파일을 열기 전까지 메모리에 거의 올라오지 않습니다. 하지만 다음 세 가지 경우에는 부담이 생깁니다.

- **항상 켜지는 확장**: `*` 또는 `onStartupFinished`로 선언된 확장은 어떤 폴더를 열든 로딩됩니다.
- **넓은 조건으로 켜지는 확장**: `workspaceContains:**/CMakeLists.txt` 같은 조건은 대형 소스 트리에서 거의 항상 참이 됩니다. ESP-IDF, CMake Tools, Makefile Tools가 엉뚱한 프로젝트에서 켜지는 이유입니다.
- **언어 서버**: clangd, cpptools, Java JDT LS, Pylance는 별도 프로세스로 뜨고, 한 번 시작되면 파일을 닫아도 계속 남습니다. Java JDT LS는 JVM 위에서 돌아 500MB\~1GB 이상을 쓰는 경우가 흔합니다.

또한 모든 확장은 하나의 Extension Host(Node.js 프로세스)를 공유합니다. 확장 하나가 이벤트 루프를 오래 붙잡으면 다른 확장의 자동완성과 진단까지 함께 느려집니다.

## 2. 핵심 개념 3가지

확장 격리는 세 겹의 장치로 이루어집니다. 바깥에서 안쪽 순서로 **프로필 → 워크스페이스 활성/비활성 → 설정 범위**이며, 바깥 장치일수록 효과가 큽니다.

| 장치 | 무엇을 분리하나 | 저장 위치 | 효과 |
| --- | --- | --- | --- |
| 프로필 (Profile) | 설치된 확장 목록, 설정, 단축키, 스니펫, 태스크 | VS Code 사용자 데이터 폴더 | 확장이 아예 설치되어 있지 않은 것과 같음 |
| 워크스페이스 활성/비활성 | 같은 프로필 안에서 확장을 켜고 끄는 상태 | VS Code 내부 저장소 (워크스페이스별) | 해당 폴더에서 로딩 자체를 막음 |
| 설정 범위 (User / Workspace / Folder) | 확장의 동작 방식 (인덱싱 범위, 자동 구성 등) | `settings.json`, `.vscode/settings.json`, `.code-workspace` | 켜진 확장을 가볍게 만듦 |

각 장치의 쓰임은 다음과 같습니다.

- **프로필**: 언어나 플랫폼이 완전히 다른 작업 묶음을 나눌 때 씁니다. 예: `ESP-IDF`, `Java`, `C++ (AOSP)`, `Web`.
- **워크스페이스 활성/비활성**: 같은 프로필 안에서 일부 프로젝트만 특정 확장이 필요할 때 씁니다. 예: C++ 프로필에서 CMake 프로젝트만 CMake Tools를 켬.
- **설정 범위**: 확장은 켜야 하지만 덜 일하게 만들고 싶을 때 씁니다. 예: `out/` 디렉터리 인덱싱 제외, 폴더를 열 때 자동 구성 끄기.

설정의 우선순위는 Folder > Workspace > User 순입니다. 즉 프로젝트 폴더의 `.vscode/settings.json`이 사용자 설정을 덮어씁니다. 프로필마다 User 설정이 따로 있다는 점도 기억해 두세요.

> 주의: `.vscode/extensions.json`의 `recommendations`는 **추천만** 할 뿐 확장을 켜거나 끄지 않습니다. 활성/비활성은 2번 장치(확장 뷰의 메뉴)로만 바뀝니다.

## 3. 1단계: 현재 상태 진단하기

격리 전에 무엇이 실제로 무거운지 먼저 확인합니다. 아래 명령은 모두 명령 팔레트(`Ctrl+Shift+P`, macOS는 `Cmd+Shift+P`)에서 실행합니다.

| 명령 | 보여주는 것 | 확인할 점 |
| --- | --- | --- |
| `Developer: Open Process Explorer` | 프로세스별 CPU·메모리 | `extensionHost`와 그 아래 언어 서버(java, clangd, cpptools, node)의 메모리 |
| `Developer: Show Running Extensions` | 활성화된 확장 목록과 활성화 시간 | 이 프로젝트와 무관한데 켜진 확장, 활성화 시간이 수백 ms 이상인 확장 |
| `Developer: Startup Performance` | 창이 뜨기까지 단계별 시간 | 확장 활성화 구간이 전체에서 차지하는 비중 |
| `Help: Start Extension Bisect` | 확장을 절반씩 꺼가며 문제 확장 탐색 | 원인을 모를 때 최후 수단 |

확장이 왜 켜졌는지는 해당 확장의 `package.json`에서 `activationEvents`를 보면 알 수 있습니다. 확장 설치 폴더는 다음과 같습니다.

```bash
# Linux / macOS
ls ~/.vscode/extensions/
# 예: ESP-IDF 확장이 어떤 조건에서 켜지는지 확인
grep -A 20 '"activationEvents"' ~/.vscode/extensions/espressif.esp-idf-extension-*/package.json
```

빠르게 비교해 보고 싶다면 확장을 끈 상태로 실행해 체감 차이를 봅니다.

```bash
code --disable-extensions .                      # 모든 확장 끄고 실행 (이번 세션만)
code --disable-extension redhat.java .           # 특정 확장만 끄고 실행 (이번 세션만)
code --list-extensions --show-versions           # 설치된 확장 목록
```

## 4. 2단계: 프로필 만들기

프로필은 "VS Code를 여러 개 설치한 것처럼" 확장과 설정을 통째로 분리합니다. 먼저 **기본(Default) 프로필을 최소화**하고, 언어별 프로필을 따로 만드는 것이 기본 전략입니다.

### 4.1 GUI로 만들기

1. 왼쪽 아래 톱니바퀴(관리) 아이콘 → **Profiles** 를 엽니다. 또는 명령 팔레트에서 `Profiles: New Profile...` 을 실행합니다.
2. **New Profile** 을 누르고 이름을 입력합니다. 예: `C++ AOSP`.
3. **Copy from** 에서 시작점을 고릅니다.
   - `None` (빈 프로필): 확장 없이 깨끗하게 시작. 가장 권장.
   - 기존 프로필 복사: 테마·단축키 같은 공통 설정을 이어받고 싶을 때.
   - 내장 템플릿 (Python, Java 등): 해당 언어용 추천 확장이 미리 들어 있음.
4. 프로필에 포함할 항목(Settings, Keyboard Shortcuts, Snippets, Tasks, Extensions)을 고릅니다. 체크를 해제한 항목은 Default 프로필의 것을 공유합니다.
5. **Create** 후 해당 프로필로 전환된 상태에서 필요한 확장만 설치합니다.

> 팁: 테마, 키맵(Vim 등), GitLens처럼 모든 프로필에 공통으로 필요한 확장은 확장 뷰에서 우클릭 → **Apply Extension to all Profiles** 를 쓰면 한 번에 적용됩니다.

### 4.2 터미널에서 만들고 확장 설치하기

`--profile` 옵션에 없는 이름을 주면 새 프로필이 생성됩니다. 확장 설치도 프로필 단위로 할 수 있어서 스크립트로 환경을 재현하기 좋습니다.

```bash
# 프로필 생성 겸 확장 설치
code --profile "C++ AOSP" --install-extension llvm-vs-code-extensions.vscode-clangd
code --profile "Java"     --install-extension vscjava.vscode-java-pack
code --profile "ESP-IDF"  --install-extension espressif.esp-idf-extension

# 프로필별 설치 목록 확인
code --profile "Java" --list-extensions
```

### 4.3 권장 프로필 구성 예

| 프로필 | 포함 확장 (ID) | 용도 |
| --- | --- | --- |
| Default | 테마, 키맵, GitLens 정도 | 문서·설정 파일 편집, 가벼운 작업 |
| C++ AOSP | `llvm-vs-code-extensions.vscode-clangd` | AOSP 네이티브, HAL, 대형 C++ 트리 |
| Java | `vscjava.vscode-java-pack`, `vscjava.vscode-gradle` | 앱·프레임워크 Java, Gradle 프로젝트 |
| ESP-IDF | `espressif.esp-idf-extension`, `ms-vscode.cpptools` 또는 clangd | ESP32 펌웨어 |
| Embedded Make | `ms-vscode.makefile-tools`, clangd | 커널, 부트로더, Makefile 기반 C |
| Web / Python | `ms-python.python`, `dbaeumer.vscode-eslint`, `esbenp.prettier-vscode` | 서버 스크립트, 웹 프론트엔드 |

## 5. 3단계: 폴더에 프로필 연결하기

폴더를 연 상태에서 프로필을 바꾸면, VS Code는 **그 폴더(또는 워크스페이스)와 프로필의 연결을 기억**합니다. 다음에 그 폴더를 열면 자동으로 같은 프로필이 적용됩니다.

1. 프로젝트 폴더를 엽니다. 예: `~/esp/my-intercom-fw`.
2. 톱니바퀴 → **Profiles** → `ESP-IDF` 를 선택합니다. 창이 해당 프로필로 다시 로딩됩니다.
3. 창을 닫았다가 같은 폴더를 다시 열어 봅니다. 상태 표시줄 왼쪽 아래 톱니바퀴 옆이나 창 제목에 프로필 이름이 표시되면 연결된 것입니다.

터미널에서 처음부터 원하는 프로필로 여는 방법도 있습니다. 셸 별칭으로 만들어 두면 편합니다.

```bash
# ~/.bashrc 또는 ~/.zshrc
alias code-aosp='code --profile "C++ AOSP"'
alias code-java='code --profile "Java"'
alias code-esp='code --profile "ESP-IDF"'

# 사용
code-aosp ~/aosp/vendor/europa/hal/camera
code-esp  ~/esp/my-intercom-fw
```

Windows에서는 바로가기를 만들어 대상에 `--profile` 을 붙이면 됩니다.

```text
"C:\Users\<사용자>\AppData\Local\Programs\Microsoft VS Code\Code.exe" --profile "ESP-IDF"
```

> 주의: 연결은 폴더 경로 단위입니다. 같은 저장소를 다른 경로에 클론하면 새 폴더로 취급되므로 한 번 더 프로필을 선택해야 합니다.

## 6. 4단계: 전역 비활성 + 워크스페이스 활성

프로필을 새로 만들 정도는 아니지만 일부 프로젝트에서만 쓰는 확장은 **"기본은 끄고, 필요한 곳에서만 켠다"** 로 관리합니다. 반대로 "기본은 켜고, 불필요한 곳에서 끈다"로 하면 새 폴더를 열 때마다 끄는 작업을 반복해야 합니다.

### 설정 순서

1. 확장 뷰(`Ctrl+Shift+X`)에서 대상 확장의 톱니바퀴 → **Disable** 을 누릅니다. 현재 프로필의 모든 폴더에서 꺼집니다.
2. 이 확장이 필요한 프로젝트 폴더를 엽니다.
3. 같은 확장의 톱니바퀴 → **Enable (Workspace)** 를 누릅니다. 이 폴더에서만 켜집니다.
4. 필요한 다른 프로젝트에서도 3번을 반복합니다.

| 메뉴 | 의미 |
| --- | --- |
| Disable | 현재 프로필 전체에서 끔 |
| Disable (Workspace) | 지금 열린 폴더/워크스페이스에서만 끔 |
| Enable | 현재 프로필 전체에서 켬 |
| Enable (Workspace) | 전역으로 꺼진 확장을 지금 열린 폴더/워크스페이스에서만 켬 |

이 상태는 `.vscode/` 폴더가 아니라 VS Code 내부 저장소에 워크스페이스별로 저장됩니다. 그래서 저장소에 커밋되지 않고, 팀원과 공유되지도 않습니다. 팀과 공유하려면 7장의 `extensions.json` 추천을 함께 씁니다.

### 이 패턴이 잘 맞는 확장

- CMake Tools, Makefile Tools: 빌드 시스템을 자동 탐지하며 구성을 시도함
- ESP-IDF, PlatformIO: 툴체인 검증과 환경 검사를 수행함
- Docker, Kubernetes, 원격 개발 확장: 특정 프로젝트에서만 필요함
- Android/Gradle 계열: Gradle 동기화가 무거움

## 7. 5단계: 설정 파일로 확장을 가볍게 만들기

켜야 하는 확장은 프로젝트 설정으로 "덜 일하게" 만듭니다. 이 설정은 `.vscode/` 에 저장되므로 저장소에 커밋해 팀과 공유할 수 있습니다.

### 7.1 프로젝트 폴더 구조

```text
my-project/
├── .vscode/
│   ├── settings.json      # 이 프로젝트 전용 설정 (User 설정을 덮어씀)
│   ├── extensions.json    # 추천/비추천 확장 목록 (켜고 끄지는 않음)
│   ├── tasks.json         # 빌드·플래시 등 작업
│   └── launch.json        # 디버그 구성
└── ...
```

### 7.2 settings.json: 모든 프로젝트에 공통으로 넣을 만한 항목

```json
{
  // 파일 감시 제외: 빌드 산출물과 대형 디렉터리
  "files.watcherExclude": {
    "**/build/**": true,
    "**/out/**": true,
    "**/.git/objects/**": true,
    "**/node_modules/**": true
  },
  // 검색 제외
  "search.exclude": {
    "**/build": true,
    "**/out": true
  },
  // 탐색기에서도 숨기고 싶을 때
  "files.exclude": {
    "**/.cache": true
  }
}
```

### 7.3 언어별 설정

같은 파일 안에서 언어별로 다른 설정을 줄 수 있습니다. 확장을 끄지는 못하지만 포매터나 저장 시 동작을 언어별로 나눌 때 유용합니다.

```json
{
  "[cpp]": {
    "editor.defaultFormatter": "llvm-vs-code-extensions.vscode-clangd",
    "editor.formatOnSave": false
  },
  "[java]": {
    "editor.tabSize": 4
  },
  "[makefile]": {
    "editor.insertSpaces": false   // Makefile은 탭 필수
  }
}
```

### 7.4 extensions.json: 추천과 비추천

```json
{
  "recommendations": [
    "llvm-vs-code-extensions.vscode-clangd"
  ],
  "unwantedRecommendations": [
    "ms-vscode.cpptools"          // clangd와 충돌하므로 설치 추천 안 함
  ]
}
```

이 파일은 폴더를 열 때 "추천 확장을 설치하시겠습니까?" 알림을 띄우는 역할만 합니다. 이미 설치된 확장을 끄려면 6장의 방법을 써야 합니다.

## 8. 예제 1: ESP-IDF

ESP-IDF 확장은 활성화될 때 IDF 경로, 툴체인, Python 가상환경을 검증하므로 **전용 프로필**로 완전히 분리하는 것을 권장합니다.

### 8.1 프로필 만들기

```bash
code --profile "ESP-IDF" --install-extension espressif.esp-idf-extension
code --profile "ESP-IDF" --install-extension ms-vscode.cpptools
# 또는 cpptools 대신 clangd
# code --profile "ESP-IDF" --install-extension llvm-vs-code-extensions.vscode-clangd
```

그다음 Default 프로필에서는 ESP-IDF 확장을 **제거(Uninstall)** 합니다. 다른 프로젝트에서 실수로 활성화될 일이 사라집니다.

### 8.2 프로젝트 연결

```bash
code --profile "ESP-IDF" ~/esp/my-intercom-fw
```

처음 열 때 확장의 설정 마법사(EIM 또는 Configure Extension)가 뜨면 IDF 설치 경로를 지정합니다. 이 정보는 ESP-IDF 프로필의 User 설정에만 저장되므로 다른 프로필에 영향을 주지 않습니다.

### 8.3 프로젝트 settings.json

```json
{
  // 보드별로 다른 값은 프로젝트에 둠
  "idf.port": "/dev/ttyUSB0",
  "idf.flashType": "UART",

  // IntelliSense가 ESP-IDF 빌드 결과를 쓰도록 연결 (cpptools 사용 시)
  "C_Cpp.default.compileCommands": "${workspaceFolder}/build/compile_commands.json",

  "files.watcherExclude": {
    "**/build/**": true,
    "**/managed_components/**": true
  },
  "search.exclude": {
    "**/build": true,
    "**/managed_components": true
  }
}
```

`idf.` 로 시작하는 설정 이름은 확장 버전에 따라 바뀌기도 합니다. 설정 화면(`Ctrl+,`)에서 `idf` 로 검색해 현재 버전의 이름을 확인하세요.

### 8.4 ESP-IDF 프로젝트가 여러 개일 때

- 모든 ESP 프로젝트를 같은 `ESP-IDF` 프로필에 연결합니다. 확장과 IDF 경로는 공유하고, 포트·보드 같은 차이는 각 프로젝트의 `.vscode/settings.json` 에 둡니다.
- IDF 버전이 다른 프로젝트(예: v4.4와 v5.x)를 함께 유지해야 한다면 `ESP-IDF v4`, `ESP-IDF v5` 처럼 프로필을 버전별로 나누는 것이 가장 깔끔합니다.

## 9. 예제 2: Java

Java 확장(Red Hat JDT LS)은 가장 무거운 언어 서버이므로 **전용 프로필 + 메모리·임포트 제한**이 핵심입니다.

### 9.1 프로필 만들기

```bash
code --profile "Java" --install-extension vscjava.vscode-java-pack
code --profile "Java" --install-extension vscjava.vscode-gradle   # Gradle 프로젝트일 때
```

`vscode-java-pack` 에는 언어 지원, 디버거, 테스트 러너, Maven, 프로젝트 관리자가 함께 들어 있습니다. 쓰지 않는 구성 요소(예: Maven을 안 쓰면 `vscjava.vscode-maven`)는 6장 방법으로 꺼 두면 더 가벼워집니다.

### 9.2 Java 프로필의 User 설정

```json
{
  // JDT LS의 JVM 힙 상한. 기본값보다 명시적으로 제한
  "java.jdt.ls.vmargs": "-Xmx1G -XX:+UseG1GC -XX:+UseStringDeduplication",

  // 처음 열 때 자동으로 전체 빌드 구성을 임포트하지 않고 물어봄
  "java.configuration.updateBuildConfiguration": "interactive",

  // 저장할 때마다 전체 자동 빌드하지 않음 (대형 프로젝트)
  "java.autobuild.enabled": false
}
```

### 9.3 코드 읽기 전용 프로젝트: LightWeight 모드

AOSP 프레임워크의 Java 코드처럼 빌드 연동 없이 탐색만 할 때는 경량 모드가 효과적입니다. 문법 오류 표시, 아웃라인, 파일 내 이동은 되지만 프로젝트 전체 분석은 하지 않습니다.

```json
// .vscode/settings.json
{
  "java.server.launchMode": "LightWeight",
  "java.import.exclusions": [
    "**/out/**",
    "**/build/**",
    "**/node_modules/**",
    "**/.gradle/**"
  ]
}
```

| 모드 | 특징 | 언제 |
| --- | --- | --- |
| `LightWeight` | 빠르게 뜨고 메모리 적음, 프로젝트 전체 분석 없음 | 코드 읽기, 대형 트리 일부 탐색 |
| `Standard` | 전체 분석, 리팩터링, 빌드 연동 | 실제 개발·디버깅 |
| `Hybrid` | LightWeight로 시작 후 필요할 때 Standard로 전환 | 둘 다 할 때 |

### 9.4 문제가 생길 때

- 상태 표시줄의 Java 아이콘이 계속 돌거나 인덱스가 꼬이면 명령 팔레트에서 `Java: Clean Java Language Server Workspace` 를 실행합니다.
- Gradle 동기화가 오래 걸리면 Gradle 데몬 메모리도 함께 확인합니다. 프로젝트의 `gradle.properties` 에 `org.gradle.jvmargs=-Xmx2g` 같은 값을 둡니다.

## 10. 예제 3: C/C++ (AOSP 대형 트리 포함)

C/C++는 **IntelliSense 엔진을 하나만 쓰고, `compile_commands.json` 으로 정확한 빌드 정보를 주는 것**이 성능과 정확도를 모두 해결합니다.

### 10.1 엔진 선택: cpptools vs clangd

| 항목 | `ms-vscode.cpptools` | `llvm-vs-code-extensions.vscode-clangd` |
| --- | --- | --- |
| 엔진 | Microsoft 자체 IntelliSense + 태그 파서 | LLVM clangd |
| 대형 트리 | 태그 파서 DB가 커지기 쉬움 | 백그라운드 인덱스, 디스크 저장 |
| 정확도 | 설정에 따라 차이 큼 | 컴파일러와 같은 파서라 정확함 |
| 디버거 | 내장 (cppdbg) | 없음, 디버깅은 cpptools 또는 CodeLLDB 필요 |
| 권장 | 디버깅이 필요한 작은 프로젝트 | AOSP, 커널 등 대형 트리 |

**둘을 함께 쓸 때**는 cpptools의 IntelliSense를 꺼서 엔진이 두 개 돌지 않게 합니다. 디버거만 cpptools를 쓰는 구성입니다.

```json
{
  "C_Cpp.intelliSenseEngine": "disabled"
}
```

### 10.2 clangd 설정 (C++ AOSP 프로필의 User 설정)

```json
{
  "clangd.arguments": [
    "--background-index",      // 인덱스를 백그라운드로 만들고 디스크에 저장
    "--pch-storage=disk",      // 프리컴파일 헤더를 메모리 대신 디스크에
    "--malloc-trim",           // 사용하지 않는 메모리를 OS에 반환 (Linux)
    "-j=4",                    // 인덱싱 스레드 수 제한
    "--header-insertion=never" // 자동 #include 삽입 끔
  ]
}
```

### 10.3 AOSP에서 compile\_commands.json 만들기

AOSP(Soong)는 환경 변수로 컴파일 DB를 생성할 수 있습니다.

```bash
cd ~/aosp
source build/envsetup.sh
lunch <target>
SOONG_GEN_COMPDB=1 SOONG_GEN_COMPDB_DEBUG=1 m nothing
# 결과: out/soong/development/ide/compdb/compile_commands.json
```

전체 트리를 열지 말고, **작업 중인 모듈 디렉터리만 열고** clangd에 DB 위치를 알려줍니다.

```json
// ~/aosp/vendor/europa/hal/camera/.vscode/settings.json
{
  "clangd.arguments": [
    "--compile-commands-dir=${env:HOME}/aosp/out/soong/development/ide/compdb",
    "--background-index",
    "--pch-storage=disk",
    "-j=4"
  ]
}
```

전체 트리를 열어야 할 때는 감시와 검색 제외가 필수입니다.

```json
// ~/aosp/.vscode/settings.json
{
  "files.watcherExclude": {
    "**/out/**": true,
    "**/prebuilts/**": true,
    "**/.repo/**": true,
    "**/external/**": true
  },
  "search.exclude": {
    "**/out": true,
    "**/prebuilts": true,
    "**/.repo": true
  },
  "search.followSymlinks": false
}
```

### 10.4 일반 C/C++ 프로젝트 (cpptools 사용)

```json
// .vscode/c_cpp_properties.json 없이 settings.json만으로 구성
{
  "C_Cpp.default.compileCommands": "${workspaceFolder}/build/compile_commands.json",
  "C_Cpp.default.cppStandard": "c++17",
  "C_Cpp.workspaceParsingPriority": "low",   // 백그라운드 파싱 우선순위 낮춤
  "C_Cpp.files.exclude": {
    "**/build/**": true,
    "**/third_party/**": true
  }
}
```

## 11. 예제 4: Makefile / CMake

빌드 시스템 확장은 폴더 안에 `Makefile` 이나 `CMakeLists.txt` 만 있어도 켜져서 **자동 구성(configure)을 시도**합니다. 대형 트리에서는 대부분 하위 디렉터리에 이 파일이 있으므로 "전역 비활성 + 워크스페이스 활성"(6장)과 자동 구성 끄기를 함께 씁니다.

### 11.1 CMake Tools

```bash
code --profile "C++ AOSP" --install-extension ms-vscode.cmake-tools
# 확장 뷰에서 Disable → CMake 프로젝트에서만 Enable (Workspace)
```

```json
// CMake 프로젝트의 .vscode/settings.json
{
  "cmake.configureOnOpen": false,        // 폴더 열 때 자동 configure 안 함
  "cmake.configureOnEdit": false,        // CMakeLists 수정 시 자동 configure 안 함
  "cmake.buildDirectory": "${workspaceFolder}/build",
  "cmake.configureSettings": {
    "CMAKE_EXPORT_COMPILE_COMMANDS": "ON"  // clangd/cpptools용 DB 생성
  }
}
```

`CMAKE_EXPORT_COMPILE_COMMANDS` 를 켜면 `build/compile_commands.json` 이 만들어지고, 10장의 clangd나 cpptools가 이를 그대로 씁니다.

### 11.2 Makefile Tools

```json
// Makefile 프로젝트의 .vscode/settings.json
{
  "makefile.configureOnOpen": false,     // 열 때 make --dry-run 분석 안 함
  "makefile.makeDirectory": "${workspaceFolder}",
  "makefile.makefilePath": "${workspaceFolder}/Makefile"
}
```

Makefile Tools는 `make --dry-run` 결과를 분석해 IntelliSense 정보를 만듭니다. 커널처럼 큰 Makefile에서는 이 분석이 매우 오래 걸리므로, 확장 없이 `compile_commands.json` 을 직접 만드는 편이 낫습니다.

```bash
# 방법 1: bear로 실제 빌드를 가로채서 생성 (범용)
sudo apt install bear
bear -- make -j$(nproc)

# 방법 2: 리눅스 커널은 빌드 후 내장 스크립트 사용
make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- -j$(nproc)
./scripts/clang-tools/gen_compile_commands.py
```

이렇게 만든 DB를 clangd에 주면 Makefile Tools는 아예 설치하지 않아도 됩니다.

### 11.3 빌드는 tasks.json으로

빌드 확장 없이도 `tasks.json` 으로 `Ctrl+Shift+B` 빌드를 쓸 수 있습니다. 확장이 상주하지 않으니 가장 가볍습니다.

```json
// .vscode/tasks.json
{
  "version": "2.0.0",
  "tasks": [
    {
      "label": "make",
      "type": "shell",
      "command": "make -j$(nproc)",
      "group": { "kind": "build", "isDefault": true },
      "problemMatcher": "$gcc"   // 컴파일 오류를 문제 패널에 표시
    },
    {
      "label": "clean",
      "type": "shell",
      "command": "make clean"
    }
  ]
}
```

## 12. 예제 5: Python, JavaScript/TypeScript

Python과 JS/TS는 서버 스크립트나 웹 작업처럼 성격이 비슷한 경우가 많아 **`Web / Python` 프로필 하나**로 묶고, 분석 범위를 좁히는 설정을 프로젝트마다 둡니다.

### 12.1 프로필 만들기

```bash
code --profile "Web / Python" --install-extension ms-python.python          # Pylance가 함께 설치됨
code --profile "Web / Python" --install-extension dbaeumer.vscode-eslint
code --profile "Web / Python" --install-extension esbenp.prettier-vscode
```

JavaScript/TypeScript 언어 기능은 VS Code에 내장되어 있어 별도 확장이 필요 없습니다.

### 12.2 Python 프로젝트 settings.json

```json
{
  // 이 프로젝트의 가상환경을 사용 (python -m venv .venv 로 만든 경우)
  "python.defaultInterpreterPath": "${workspaceFolder}/.venv/bin/python",

  // 열린 파일만 진단 → 대형 프로젝트에서 CPU·메모리 절약
  "python.analysis.diagnosticMode": "openFilesOnly",

  // 분석하지 않을 폴더
  "python.analysis.exclude": [
    "**/.venv",
    "**/__pycache__",
    "**/data",
    "**/models"          // 모델 가중치 같은 대용량 폴더
  ],

  "files.watcherExclude": {
    "**/.venv/**": true,
    "**/__pycache__/**": true
  }
}
```

가상환경(`.venv`)을 프로젝트마다 두면 패키지가 프로젝트별로 분리되어, VS Code가 엉뚱한 라이브러리를 분석하는 일도 줄어듭니다.

```bash
cd ~/work/face-server
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

### 12.3 JavaScript/TypeScript 프로젝트 settings.json

```json
{
  // TypeScript 서버 메모리 상한 (MB)
  "typescript.tsserver.maxTsServerMemory": 2048,

  // ESLint를 입력할 때마다가 아니라 저장할 때만 실행
  "eslint.run": "onSave",

  "[javascript]": {
    "editor.defaultFormatter": "esbenp.prettier-vscode",
    "editor.formatOnSave": true
  },
  "[typescript]": {
    "editor.defaultFormatter": "esbenp.prettier-vscode",
    "editor.formatOnSave": true
  },

  "files.watcherExclude": {
    "**/node_modules/**": true,
    "**/dist/**": true
  },
  "search.exclude": {
    "**/node_modules": true,
    "**/dist": true
  }
}
```

TypeScript 서버가 분석할 파일 범위는 프로젝트 루트의 `tsconfig.json`(JS만 쓰면 `jsconfig.json`)으로 정합니다.

```json
// jsconfig.json (순수 JavaScript 프로젝트)
{
  "compilerOptions": { "checkJs": false },
  "include": ["src/**/*"],
  "exclude": ["node_modules", "dist"]
}
```

## 13. 예제 6: 멀티 루트 워크스페이스 (혼합 프로젝트)

서로 다른 경로의 폴더 여러 개를 한 창에서 다뤄야 할 때는 `.code-workspace` 파일을 씁니다. 이 파일 하나가 **하나의 워크스페이스**로 취급되어, 프로필 연결과 확장 활성/비활성 상태가 이 파일 단위로 저장됩니다.

### 13.1 언제 쓰나

- 같은 기능을 이루는 C++ HAL과 Java 프레임워크 서비스를 함께 볼 때
- AOSP 트리 중 필요한 모듈 몇 개만 골라 열고 싶을 때 (전체 트리를 여는 것보다 훨씬 가벼움)
- 앱 코드와 그 앱이 쓰는 서버 코드를 함께 볼 때

반대로 ESP 펌웨어와 Java 앱처럼 **필요한 확장이 완전히 다른 프로젝트는 한 워크스페이스에 묶지 않습니다.** 한 창은 한 프로필만 쓰기 때문에 결국 모든 확장을 한 프로필에 넣어야 하기 때문입니다.

### 13.2 예: AOSP 모듈 몇 개만 묶기

```json
// ~/workspaces/camera-feature.code-workspace
{
  "folders": [
    { "name": "Camera HAL (C++)",   "path": "/home/zoomon/aosp/vendor/europa/hal/camera" },
    { "name": "CameraService",      "path": "/home/zoomon/aosp/frameworks/av/services/camera" },
    { "name": "Launcher (Java)",    "path": "/home/zoomon/aosp/packages/apps/EuropaLauncher" }
  ],
  "settings": {
    // 워크스페이스 전체에 적용
    "clangd.arguments": [
      "--compile-commands-dir=/home/zoomon/aosp/out/soong/development/ide/compdb",
      "--background-index",
      "-j=4"
    ],
    "java.server.launchMode": "LightWeight",
    "files.watcherExclude": { "**/out/**": true }
  },
  "extensions": {
    "recommendations": [
      "llvm-vs-code-extensions.vscode-clangd",
      "vscjava.vscode-java-pack"
    ]
  }
}
```

여는 방법은 다음과 같습니다.

```bash
code --profile "C++ AOSP" ~/workspaces/camera-feature.code-workspace
```

또는 VS Code에서 **File → Open Workspace from File...** 을 쓰고, 한 번 프로필을 고르면 이후 자동으로 연결됩니다. 위 예처럼 C++와 Java를 함께 다룬다면, C++ AOSP 프로필에 Java 확장도 설치해 두고 **이 워크스페이스에서만 Enable (Workspace)** 하는 방식이 깔끔합니다.

### 13.3 설정이 적용되는 순서

| 위치 | 적용 범위 |
| --- | --- |
| 프로필의 User 설정 | 그 프로필로 연 모든 창 |
| `.code-workspace` 의 `settings` | 이 워크스페이스 전체 |
| 각 폴더의 `.vscode/settings.json` | 그 폴더 안의 파일만 (폴더 단위로 바꿀 수 있는 설정만) |

창 전체에 걸리는 설정(예: `window.*`, 일부 확장 서버 인자)은 폴더 설정에서는 무시되고 워크스페이스 설정에 두어야 적용됩니다. 설정 화면에서 해당 항목에 "Workspace Folder" 탭이 보이면 폴더 단위로 바꿀 수 있는 설정입니다.

## 14. 프로필 공유와 문제 해결

### 14.1 프로필 내보내기·가져오기

잘 만든 프로필은 파일로 내보내 다른 PC나 팀원에게 그대로 옮길 수 있습니다.

1. 톱니바퀴 → **Profiles** → 대상 프로필의 `...` → **Export...**
2. 내보낼 항목(설정, 확장, 단축키 등)을 고르고 **Local file** 또는 **GitHub Gist** 를 선택합니다.
3. 받는 쪽은 **Profiles** → **New Profile** 옆 메뉴 → **Import Profile...** 에서 `.code-profile` 파일이나 Gist URL을 지정합니다.

> 팁: 팀 공용 프로필은 사내 저장소에 `.code-profile` 파일로 두고, 프로젝트별 세부 설정은 각 저장소의 `.vscode/` 에 두면 역할이 깔끔하게 나뉩니다. 설정 동기화(Settings Sync)를 켜 두면 개인 PC 간에는 프로필이 자동으로 동기화됩니다.

### 14.2 자주 겪는 문제

| 증상 | 원인 | 해결 |
| --- | --- | --- |
| 폴더를 열 때마다 다른 프로필로 열림 | 폴더와 프로필 연결이 안 됨 | 그 폴더를 연 상태에서 원하는 프로필로 한 번 전환 |
| 같은 저장소인데 프로필이 연결 안 됨 | 다른 경로에 클론됨 | 경로마다 한 번씩 연결, 또는 `--profile` 별칭 사용 |
| Enable (Workspace) 메뉴가 안 보임 | 확장이 전역으로 켜져 있음 | 먼저 **Disable** 로 전역에서 끈 뒤 다시 확인 |
| 설정을 넣었는데 적용 안 됨 | 폴더 설정에 창 단위 설정을 넣음 | `.code-workspace` 의 `settings` 나 User 설정으로 옮김 |
| 자동완성·진단이 두 번 뜸 | cpptools와 clangd가 동시에 동작 | `"C_Cpp.intelliSenseEngine": "disabled"` |
| 프로필을 바꿨는데도 느림 | 이전 언어 서버가 남아 있음 | `Developer: Reload Window` 또는 창을 닫고 다시 열기 |
| 확장 설정이 프로필마다 다름 | 정상 동작 (User 설정은 프로필별) | 공통 항목은 프로필 생성 시 Settings를 공유로 선택 |

### 14.3 원상 복구

프로필은 삭제해도 프로젝트 파일에는 영향이 없습니다. **Profiles** 에서 프로필의 `...` → **Delete** 하면 그 프로필의 확장과 설정만 지워지고, 연결되어 있던 폴더는 Default 프로필로 돌아갑니다.

## 15. 치트시트

### 상황별 선택

| 상황 | 쓸 장치 |
| --- | --- |
| 언어·플랫폼이 완전히 다른 작업 (ESP vs Java vs AOSP C++) | 프로필 분리 |
| 같은 프로필 안에서 일부 프로젝트만 쓰는 확장 (CMake Tools 등) | 전역 Disable + Enable (Workspace) |
| 확장은 켜야 하는데 무거움 | `.vscode/settings.json` 으로 범위·자동 동작 제한 |
| 여러 경로의 폴더를 한 창에서 | `.code-workspace` + 프로필 연결 |
| 팀과 같은 환경 공유 | `.code-profile` 내보내기 + `extensions.json` 추천 |

### 자주 쓰는 명령

```bash
code --profile "<이름>" <폴더>                          # 프로필로 열기 (없으면 생성)
code --profile "<이름>" --install-extension <ID>        # 프로필에 확장 설치
code --profile "<이름>" --list-extensions               # 프로필의 확장 목록
code --disable-extensions <폴더>                         # 확장 없이 열기 (이번 세션만)
code --disable-extension <ID> <폴더>                     # 특정 확장만 끄고 열기 (이번 세션만)
```

### 명령 팔레트

- `Profiles: New Profile...` · `Profiles: Switch Profile` · `Profiles: Export Profile...`
- `Developer: Open Process Explorer` · `Developer: Show Running Extensions` · `Developer: Startup Performance`
- `Help: Start Extension Bisect` · `Developer: Reload Window`

### 대형 트리에서 빼먹지 말 것

- `files.watcherExclude`, `search.exclude` 에 `out/`, `build/`, `prebuilts/`, `.repo/`, `node_modules/` 추가
- C/C++는 IntelliSense 엔진 하나만, `compile_commands.json` 연결
- 빌드 확장은 `configureOnOpen: false`
- Java는 `-Xmx` 제한, 읽기 전용이면 `LightWeight`
- 전체 트리 대신 필요한 모듈만 열기
