import 'dart:io';

import 'package:profile_engine/profile_engine.dart';

import 'json_file_store.dart';

/// 앱 설정(`app_settings.json`). 테마·언어는 규약의 shared_preferences 키를 그대로 쓰므로
/// 여기에는 두지 않는다.
class AppConfig {
  const AppConfig({this.codePath});

  /// 사용자가 지정한 `code` 실행 파일 경로. null이면 자동 탐지한다.
  final String? codePath;

  /// 실제로 실행할 `code` 경로: 지정값 → 자동 탐지 → PATH에서 찾는 이름.
  /// Windows의 PATH 탐색은 확장자가 필요하므로 `code.cmd`다.
  String get effectiveCodePath =>
      codePath ??
      discoverCodePath() ??
      (Platform.isWindows ? 'code.cmd' : 'code');

  /// [codePath]를 null로 되돌리려면 [clearCodePath]를 true로 준다.
  AppConfig copyWith({String? codePath, bool clearCodePath = false}) =>
      AppConfig(codePath: clearCodePath ? null : (codePath ?? this.codePath));

  Map<String, Object?> toJson() => {'schemaVersion': 1, 'codePath': codePath};

  factory AppConfig.fromJson(Map<String, Object?> json) {
    final path = json['codePath'];
    return AppConfig(codePath: path is String && path.isNotEmpty ? path : null);
  }
}

abstract interface class AppConfigStore {
  Future<AppConfig> load();

  Future<void> save(AppConfig config);
}

class FileAppConfigStore implements AppConfigStore {
  FileAppConfigStore(this._store);

  final JsonFileStore _store;

  @override
  Future<AppConfig> load() async {
    final json = await _store.read();
    return json is Map<String, Object?>
        ? AppConfig.fromJson(json)
        : const AppConfig();
  }

  @override
  Future<void> save(AppConfig config) => _store.write(config.toJson());
}

class MemoryAppConfigStore implements AppConfigStore {
  MemoryAppConfigStore([this.saved = const AppConfig()]);

  AppConfig saved;

  @override
  Future<AppConfig> load() async => saved;

  @override
  Future<void> save(AppConfig config) async => saved = config;
}
