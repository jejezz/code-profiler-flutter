import 'package:profile_engine/profile_engine.dart';

import 'json_file_store.dart';

/// 프로젝트 목록 저장소.
abstract interface class ProjectStore {
  Future<List<Project>> load();

  Future<void> save(List<Project> projects);
}

/// `projects.json`에 저장한다. 형식: `{"schemaVersion": 1, "projects": [...]}`.
class FileProjectStore implements ProjectStore {
  FileProjectStore(this._store);

  final JsonFileStore _store;

  static const schemaVersion = 1;

  @override
  Future<List<Project>> load() async {
    final json = await _store.read();
    if (json == null) return [];
    if (json is! Map<String, Object?>) return [];
    final version = json['schemaVersion'];
    if (version is int && version > schemaVersion) {
      // 새 버전이 쓴 파일을 옛 버전이 덮어써서 데이터를 잃지 않도록 읽기를 거부한다.
      throw FormatException(
        'projects.json 은 더 새로운 버전($version)이 만든 파일입니다. 앱을 업데이트하세요.',
      );
    }
    final list = json['projects'];
    if (list is! List<Object?>) return [];
    final projects = <Project>[];
    for (final item in list) {
      try {
        projects.add(Project.fromJson(item as Map<String, Object?>));
      } on Object {
        // 항목 하나가 깨져도 나머지는 살린다.
      }
    }
    return projects;
  }

  @override
  Future<void> save(List<Project> projects) => _store.write({
    'schemaVersion': schemaVersion,
    'projects': [for (final p in projects) p.toJson()],
  });
}

/// 테스트용 메모리 저장소.
class MemoryProjectStore implements ProjectStore {
  MemoryProjectStore([List<Project> initial = const []]) : saved = [...initial];

  List<Project> saved;

  @override
  Future<List<Project>> load() async => [...saved];

  @override
  Future<void> save(List<Project> projects) async => saved = [...projects];
}
