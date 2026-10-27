// Riverpod provider는 "값을 만들어 주는 레시피"다. 화면은 `ref.watch(provider)`로 값을 읽고,
// 값이 바뀌면 자동으로 다시 그려진다. `Notifier`는 값과 그 값을 바꾸는 메서드를 한 클래스에 묶은
// provider이고, `AsyncNotifier`는 처음 값을 비동기로 만드는 경우(파일 읽기 등)에 쓴다.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:profile_engine/profile_engine.dart';

import '../services/app_config.dart';
import '../services/ids.dart';
import '../services/project_service.dart';
import '../services/project_store.dart';

/// main()이 실제 저장소로 덮어쓴다(테스트는 메모리 저장소로).
final projectStoreProvider = Provider<ProjectStore>(
  (ref) => throw UnimplementedError('projectStoreProvider must be overridden'),
);

final appConfigStoreProvider = Provider<AppConfigStore>(
  (ref) =>
      throw UnimplementedError('appConfigStoreProvider must be overridden'),
);

final processRunnerProvider = Provider<ProcessRunner>(
  (ref) => const SystemProcessRunner(),
);

class AppConfigNotifier extends Notifier<AppConfig> {
  AppConfigNotifier([this._initial = const AppConfig()]);

  final AppConfig _initial;

  @override
  AppConfig build() => _initial;

  Future<void> update(AppConfig config) async {
    state = config;
    await ref.read(appConfigStoreProvider).save(config);
  }
}

final appConfigProvider = NotifierProvider<AppConfigNotifier, AppConfig>(
  AppConfigNotifier.new,
);

/// 설정의 `code` 경로가 바뀌면 새로 만들어진다.
final vscodeCliProvider = Provider<VsCodeCli>((ref) {
  final config = ref.watch(appConfigProvider);
  return VsCodeCli(
    ref.watch(processRunnerProvider),
    codePath: config.effectiveCodePath,
  );
});

final projectServiceProvider = Provider<ProjectService>((ref) {
  return LocalProjectService(
    cli: ref.watch(vscodeCliProvider),
    // 사용자 규칙 파일 경로는 Phase 7에서 연결한다.
    loadRules: () => loadRules(),
  );
});

class ProjectsNotifier extends AsyncNotifier<List<Project>> {
  @override
  Future<List<Project>> build() => ref.read(projectStoreProvider).load();

  List<Project> get _current => state.value ?? const [];

  /// 로컬 폴더를 등록한다. 이미 등록된 폴더면 그 프로젝트를 돌려준다.
  Future<Project> addLocal(String path) async {
    await future;
    final normalized = p.normalize(p.absolute(path));
    for (final existing in _current) {
      final loc = existing.location;
      if (loc is LocalLocation && _samePath(loc.path, normalized)) {
        return existing;
      }
    }
    final name = p.basename(normalized);
    final project = Project(
      id: generateId(),
      name: name.isEmpty ? normalized : name,
      location: LocalLocation(normalized),
      addedAt: DateTime.now(),
    );
    await _save([..._current, project]);
    return project;
  }

  Future<void> upsert(Project project) async {
    await future;
    final list = [..._current];
    final i = list.indexWhere((x) => x.id == project.id);
    if (i < 0) {
      list.add(project);
    } else {
      list[i] = project;
    }
    await _save(list);
  }

  Future<void> remove(String id) async {
    await future;
    await _save([
      for (final x in _current)
        if (x.id != id) x,
    ]);
  }

  Future<void> markOpened(String id) async {
    await future;
    final i = _current.indexWhere((x) => x.id == id);
    if (i < 0) return;
    await upsert(_current[i].copyWith(lastOpenedAt: DateTime.now()));
  }

  Future<void> _save(List<Project> list) async {
    state = AsyncData(list);
    await ref.read(projectStoreProvider).save(list);
  }

  // Windows 경로는 대소문자를 구분하지 않는다.
  bool _samePath(String a, String b) =>
      a == b ||
      a.toLowerCase() == b.toLowerCase() && p.style == p.Style.windows;
}

final projectsProvider = AsyncNotifierProvider<ProjectsNotifier, List<Project>>(
  ProjectsNotifier.new,
);
