import 'dart:io';

/// VS Code 실행 파일(`code`)을 찾는다. 못 찾으면 null.
///
/// 순서: PATH의 `code`(Windows는 `code.cmd`) → OS별 기본 설치 위치.
/// 환경과 파일 시스템은 테스트에서 바꿀 수 있도록 인자로 받는다.
String? discoverCodePath({
  Map<String, String>? environment,
  bool Function(String path)? fileExists,
  String? operatingSystem,
}) {
  final env = environment ?? Platform.environment;
  final exists = fileExists ?? (p) => File(p).existsSync();
  final os = operatingSystem ?? Platform.operatingSystem;
  final windows = os == 'windows';

  final pathVar = env[windows ? 'Path' : 'PATH'] ?? env['PATH'] ?? env['Path'];
  if (pathVar != null) {
    final names = windows ? ['code.cmd', 'code.exe', 'code.bat'] : ['code'];
    for (final dir in pathVar.split(windows ? ';' : ':')) {
      if (dir.isEmpty) continue;
      for (final name in names) {
        final candidate = '$dir${windows ? r'\' : '/'}$name';
        if (exists(candidate)) return candidate;
      }
    }
  }

  final defaults = switch (os) {
    'macos' => [
      '/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code',
    ],
    'linux' => ['/snap/bin/code', '/usr/bin/code'],
    'windows' => [
      if (env['LOCALAPPDATA'] != null)
        '${env['LOCALAPPDATA']}\\Programs\\Microsoft VS Code\\bin\\code.cmd',
      if (env['ProgramFiles'] != null)
        '${env['ProgramFiles']}\\Microsoft VS Code\\bin\\code.cmd',
    ],
    _ => <String>[],
  };
  for (final candidate in defaults) {
    if (exists(candidate)) return candidate;
  }
  return null;
}
