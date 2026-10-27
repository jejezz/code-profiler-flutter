import 'dart:io';

/// 앱 데이터 폴더. 규약(identity.md §6)에 따라 폴더 이름에 파일 이름(PascalCase)을 쓴다.
///
/// - macOS: `~/Library/Application Support/<FileName>`
/// - Windows: `%APPDATA%\<FileName>`
/// - Linux: `${XDG_CONFIG_HOME:-~/.config}/<FileName>`
///
/// 환경은 테스트에서 바꿀 수 있도록 인자로 받는다.
Directory appDataDirectory({
  required String fileName,
  Map<String, String>? environment,
  String? operatingSystem,
}) {
  final env = environment ?? Platform.environment;
  final os = operatingSystem ?? Platform.operatingSystem;
  final home = env['HOME'] ?? env['USERPROFILE'] ?? '.';
  final base = switch (os) {
    'windows' => env['APPDATA'] ?? '$home\\AppData\\Roaming',
    'macos' => '$home/Library/Application Support',
    _ => env['XDG_CONFIG_HOME'] ?? '$home/.config',
  };
  return Directory('$base${os == 'windows' ? r'\' : '/'}$fileName');
}
