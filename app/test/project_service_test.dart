import 'dart:convert';
import 'dart:io';

import 'package:code_profiler/providers/providers.dart';
import 'package:code_profiler/services/app_config.dart';
import 'package:code_profiler/services/project_service.dart';
import 'package:code_profiler/services/project_store.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:profile_engine/profile_engine.dart';

Directory _fixture(Map<String, String> files) {
  final dir = Directory.systemTemp.createTempSync('code_profiler_svc');
  addTearDown(() {
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });
  files.forEach((rel, content) {
    File('${dir.path}/$rel')
      ..createSync(recursive: true)
      ..writeAsStringSync(content);
  });
  return dir;
}

Project _local(Directory dir) => Project(
  id: 'id-1',
  name: 'proj',
  location: LocalLocation(dir.path),
  addedAt: DateTime.utc(2026),
);

LocalProjectService _service(FakeProcessRunner fake) => LocalProjectService(
  cli: VsCodeCli(fake, codePath: 'code', runInShell: false),
  loadRules: () async => loadDefaultRules(),
  // 위젯 테스트 환경에서 Isolate를 쓰지 않도록 동기 분석을 감싼다.
  analyzer: (path, {rules}) async => analyzeSync(path, rules: rules!),
);

void main() {
  group('LocalProjectService', () {
    test(
      'analyze returns the analysis, a recommendation and competitors',
      () async {
        final fx = _fixture({'pom.xml': '<project/>', 'package.json': '{}'});
        final r = await _service(FakeProcessRunner()).analyze(_local(fx));
        final bundle = (r as Ok<AnalysisBundle>).value;
        expect(bundle.analysis.types.map((t) => t.typeId), [
          'java-maven',
          'node',
        ]);
        expect(bundle.recommendation!.profileName, 'Java');
        expect(bundle.competitors.map((t) => t.typeId), ['node']);
      },
    );

    test('analyze with no detected type has no recommendation', () async {
      final fx = _fixture({'readme.txt': ''});
      final r = await _service(FakeProcessRunner()).analyze(_local(fx));
      final bundle = (r as Ok<AnalysisBundle>).value;
      expect(bundle.analysis.types, isEmpty);
      expect(bundle.recommendation, isNull);
    });

    test('analyze reports a missing folder as an Err', () async {
      final fx = _fixture({'a.txt': ''});
      final project = _local(fx);
      fx.deleteSync(recursive: true);
      final r = await _service(FakeProcessRunner()).analyze(project);
      expect(r, isA<Err<AnalysisBundle>>());
    });

    test('recommendFor switches the primary type', () async {
      final fx = _fixture({'pom.xml': '', 'package.json': '{}'});
      final service = _service(FakeProcessRunner());
      final bundle =
          ((await service.analyze(_local(fx))) as Ok<AnalysisBundle>).value;
      final r = service.recommendFor(bundle.analysis, primaryTypeId: 'node');
      expect(r.valueOrNull!.profileName, 'Web / Python');
      expect(
        r.valueOrNull!.optionalExtensions,
        contains('vscjava.vscode-java-pack'),
      );
      final same = service.recommendFor(bundle.analysis);
      expect(same.valueOrNull!.profileName, 'Java');
    });

    test('recommendFor before analyze is an Err', () {
      final r = _service(FakeProcessRunner()).recommendFor(
        AnalysisResult(
          types: const [DetectedType(typeId: 'node', label: 'n', priority: 1)],
          stats: const TreeStats(fileCount: 0, truncated: false),
          analyzedAt: DateTime.utc(2026),
        ),
      );
      expect(r, isA<Err<Recommendation>>());
    });

    test('diff does not write anything', () async {
      final fx = _fixture({'.vscode/settings.json': '{"a": 1}'});
      final r = await _service(FakeProcessRunner())
          .diff(_local(fx), {'a': 2, 'b': 1}, {});
      final diff = (r as Ok<SettingsDiff>).value;
      expect(diff.conflicts, hasLength(1));
      expect(diff.added, hasLength(1));
      expect(
        File('${fx.path}/.vscode/settings.json').readAsStringSync(),
        '{"a": 1}',
      );
    });

    test('apply installs missing extensions, then writes settings', () async {
      final fx = _fixture({'.vscode/settings.json': '{"a": 1}'});
      final fake = FakeProcessRunner()
        ..onArgs([
          '--profile',
          'Java',
          '--list-extensions',
        ], output: const ProcessOutput(exitCode: 0, stdout: 'old.ext\n'))
        ..onArgs(
          ['--profile', 'Java', '--install-extension', 'new.ext'],
          events: const [OutputLine('Installing'), ProcessExited(0)],
        );
      final events = await _service(fake)
          .apply(
            ApplyPlan(
              project: _local(fx),
              profileName: 'Java',
              extensions: const ['old.ext', 'new.ext'],
              settingsPatch: const {'b': 2},
            ),
          )
          .toList();
      expect(events.map((e) => e.runtimeType), [
        StepStarted,
        ExtensionSkipped,
        ExtensionStarted,
        ExtensionOutput,
        ExtensionFinished,
        StepFinished,
        StepStarted,
        StepFinished,
      ]);
      final last = events.last as StepFinished;
      expect(last.step, ApplyStep.settings);
      expect(last.written, isTrue);
      expect(last.backupPath, isNotNull);
      expect(
        jsonDecode(File('${fx.path}/.vscode/settings.json').readAsStringSync()),
        {'a': 1, 'b': 2},
      );
      expect(
        fake.calls.where((c) => c.args.contains('--install-extension')),
        hasLength(1),
      );
    });

    test('with no extensions only the settings are written', () async {
      final fx = _fixture({'a.txt': ''});
      final fake = FakeProcessRunner()..onArgs(['--profile']);
      final events = await _service(fake)
          .apply(
            ApplyPlan(
              project: _local(fx),
              profileName: 'P',
              extensions: const [],
              settingsPatch: const {'b': 2},
            ),
          )
          .toList();
      expect(events.whereType<StepFailed>(), isEmpty);
      expect(File('${fx.path}/.vscode/settings.json').existsSync(), isTrue);
    });

    test('a failed install stops before the settings are touched', () async {
      final fx = _fixture({'a.txt': ''});
      final fake = FakeProcessRunner()
        ..onArgs(['--profile', 'P', '--list-extensions'])
        ..onArgs(
          ['--profile', 'P', '--install-extension', 'bad.ext'],
          events: const [OutputLine('nope', isError: true), ProcessExited(1)],
        );
      final events = await _service(fake)
          .apply(
            ApplyPlan(
              project: _local(fx),
              profileName: 'P',
              extensions: const ['bad.ext'],
              settingsPatch: const {'b': 2},
            ),
          )
          .toList();
      final failed = events.last as StepFailed;
      expect(failed.step, ApplyStep.extensions);
      expect(failed.message, 'bad.ext');
      expect(events.whereType<StepStarted>().map((e) => e.step), [
        ApplyStep.extensions,
      ]);
      expect(Directory('${fx.path}/.vscode').existsSync(), isFalse);
    });

    test(
      'a settings write failure is reported as a failed settings step',
      () async {
        final fx = _fixture({'.vscode/settings.json': '{oops'});
        final fake = FakeProcessRunner()..onArgs(['--profile']);
        final events = await _service(fake)
            .apply(
              ApplyPlan(
                project: _local(fx),
                profileName: 'P',
                extensions: const [],
                settingsPatch: const {'b': 2},
              ),
            )
            .toList();
        final failed = events.last as StepFailed;
        expect(failed.step, ApplyStep.settings);
      },
    );

    test('open runs code --profile <p> <path>', () async {
      final fx = _fixture({'a.txt': ''});
      final fake = FakeProcessRunner()..onArgs(['--profile']);
      final r = await _service(fake).open(_local(fx), 'Java');
      expect(r.isOk, isTrue);
      expect(fake.calls.single.args, ['--profile', 'Java', fx.path]);
    });

    test('SSH projects are not supported yet', () async {
      final ssh = Project(
        id: 's',
        name: 's',
        location: const SshLocation('devbox', '/srv/x'),
        addedAt: DateTime.utc(2026),
      );
      final service = _service(FakeProcessRunner());
      expect(await service.analyze(ssh), isA<Err<AnalysisBundle>>());
      expect(await service.open(ssh, 'P'), isA<Err<void>>());
      expect(
        await service.diff(ssh, const {}, const {}),
        isA<Err<SettingsDiff>>(),
      );
      final events = await service
          .apply(
            ApplyPlan(
              project: ssh,
              profileName: 'P',
              extensions: const [],
              settingsPatch: const {},
            ),
          )
          .toList();
      expect(events.single, isA<StepFailed>());
    });
  });

  group('ProjectsNotifier', () {
    ProviderContainer container(MemoryProjectStore store) {
      final c = ProviderContainer(
        overrides: [projectStoreProvider.overrideWithValue(store)],
      );
      addTearDown(c.dispose);
      return c;
    }

    test('addLocal registers a folder once and persists it', () async {
      final fx = _fixture({'a.txt': ''});
      final store = MemoryProjectStore();
      final c = container(store);
      final notifier = c.read(projectsProvider.notifier);
      final a = await notifier.addLocal(fx.path);
      final b = await notifier.addLocal(fx.path);
      expect(b.id, a.id);
      expect(store.saved, hasLength(1));
      expect((store.saved.single.location as LocalLocation).path, isNotEmpty);
      expect(a.name, fx.path.split(RegExp(r'[\\/]')).last);
    });

    test('remove, upsert and markOpened update state and store', () async {
      final fx = _fixture({'a.txt': ''});
      final store = MemoryProjectStore();
      final c = container(store);
      final notifier = c.read(projectsProvider.notifier);
      final p = await notifier.addLocal(fx.path);

      await notifier.upsert(p.copyWith(profileName: 'Java'));
      expect(store.saved.single.profileName, 'Java');

      await notifier.markOpened(p.id);
      expect(store.saved.single.lastOpenedAt, isNotNull);
      expect(c.read(projectsProvider).value!.single.lastOpenedAt, isNotNull);

      await notifier.remove(p.id);
      expect(store.saved, isEmpty);
      expect(c.read(projectsProvider).value, isEmpty);
    });

    test('loads what the store already has', () async {
      final store = MemoryProjectStore([
        Project(
          id: 'x',
          name: 'x',
          location: const LocalLocation('/x'),
          addedAt: DateTime.utc(2026),
        ),
      ]);
      final c = container(store);
      expect((await c.read(projectsProvider.future)).single.id, 'x');
    });
  });

  group('AppConfigNotifier', () {
    test('update stores the config and rebuilds the VS Code CLI', () async {
      final store = MemoryAppConfigStore();
      final c = ProviderContainer(
        overrides: [
          appConfigStoreProvider.overrideWithValue(store),
          processRunnerProvider.overrideWithValue(FakeProcessRunner()),
        ],
      );
      addTearDown(c.dispose);
      final before = c.read(vscodeCliProvider);
      await c
          .read(appConfigProvider.notifier)
          .update(const AppConfig(codePath: '/opt/code'));
      expect(store.saved.codePath, '/opt/code');
      final after = c.read(vscodeCliProvider);
      expect(after.codePath, '/opt/code');
      expect(identical(before, after), isFalse);
    });
  });
}
