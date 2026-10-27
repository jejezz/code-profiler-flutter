import 'package:profile_engine/profile_engine.dart';
import 'package:test/test.dart';

import 'fixtures/fixture.dart';

final Rules _rules = loadDefaultRules().valueOrNull!;

Recommendation _recommend(Map<String, String> files, {String? sub}) {
  final fx = createFixture(files);
  final a = analyzeSync(
    sub == null ? fx.path : '${fx.path}/$sub',
    rules: _rules,
  );
  final r = recommend(a.valueOrNull!, _rules);
  expect(r, isA<Ok<Recommendation>>(), reason: '${r.errorOrNull}');
  return r.valueOrNull!;
}

AnalysisResult _analysis(
  List<String> typeIds, {
  Map<String, String> variables = const {},
  bool truncated = false,
}) => AnalysisResult(
  types: [
    for (final id in typeIds)
      DetectedType(
        typeId: id,
        label: id,
        priority: _rules.types.firstWhere((t) => t.id == id).priority,
      ),
  ],
  stats: TreeStats(fileCount: 1, truncated: truncated),
  variables: variables,
  analyzedAt: DateTime.utc(2026),
);

void main() {
  group('snapshots for the 8.1 fixtures', () {
    test('esp_idf', () {
      final r = _recommend({
        'CMakeLists.txt': 'include(\$ENV{IDF_PATH}/x/project.cmake)\n',
        'sdkconfig': '',
        'main/main.c': '',
      });
      expect(r.toJson(), {
        'profileName': 'ESP-IDF',
        'extensions': [
          'espressif.esp-idf-extension',
          'llvm-vs-code-extensions.vscode-clangd',
        ],
        'optionalExtensions': <String>[],
        'settingsPatch': {
          'files.watcherExclude': {
            '**/build/**': true,
            '**/managed_components/**': true,
          },
          'search.exclude': {'**/build': true, '**/managed_components': true},
        },
        'notes': ['idf.port 등 보드별 설정은 프로젝트 settings.json 에 직접 추가하세요.'],
      });
    });

    test('aosp_module: aospRoot is substituted into clangd args and notes', () {
      final r = _recommend({
        'aosp/.repo/': '',
        'aosp/build/envsetup.sh': '',
        'aosp/vendor/x/hal/Android.bp': '',
      }, sub: 'aosp/vendor/x/hal');
      expect(r.profileName, 'C++ AOSP');
      expect(r.extensions, ['llvm-vs-code-extensions.vscode-clangd']);
      final args = r.settingsPatch['clangd.arguments']! as List<Object?>;
      final compdb = args.first! as String;
      expect(compdb, startsWith('--compile-commands-dir='));
      expect(compdb, endsWith('/out/soong/development/ide/compdb'));
      expect(compdb, isNot(contains(r'${')));
      expect(r.settingsPatch['search.followSymlinks'], false);
      expect(r.notes.single, startsWith('compdb 생성: cd '));
      expect(r.notes.single, isNot(contains(r'${aospRoot}')));
    });

    test('gradle', () {
      final r = _recommend({
        'settings.gradle.kts': '',
        'app/build.gradle.kts': '',
      });
      expect(r.profileName, 'Java');
      expect(r.extensions, [
        'vscjava.vscode-java-pack',
        'vscjava.vscode-gradle',
      ]);
      expect(
        r.settingsPatch['java.configuration.updateBuildConfiguration'],
        'interactive',
      );
    });

    test('kernel: Embedded Make', () {
      final r = _recommend({'Kconfig': '', 'Makefile': ''});
      expect(r.profileName, 'Embedded Make');
      expect(r.notes.single, contains('gen_compile_commands.py'));
    });

    test('mixed_web_py: same profile merges extensions', () {
      final r = _recommend({'package.json': '{}', 'requirements.txt': ''});
      expect(r.profileName, 'Web / Python');
      expect(r.extensions, [
        'dbaeumer.vscode-eslint',
        'esbenp.prettier-vscode',
        'ms-python.python',
      ]);
      expect(r.optionalExtensions, isEmpty);
      expect(
        r.settingsPatch.keys,
        containsAll([
          'eslint.run',
          'python.analysis.diagnosticMode',
          'files.watcherExclude',
          'search.exclude',
        ]),
      );
      // node가 먼저 오므로 같은 키의 하위 항목은 둘 다 보존된다.
      final watcher =
          r.settingsPatch['files.watcherExclude']! as Map<String, Object?>;
      expect(
        watcher.keys,
        containsAll([
          '**/node_modules/**',
          '**/dist/**',
          '**/.venv/**',
          '**/__pycache__/**',
        ]),
      );
    });
  });

  group('profile and extension rules', () {
    test('a different-profile type goes to optionalExtensions', () {
      final r = recommend(
        _analysis(['java-maven', 'cmake']),
        _rules,
      ).valueOrNull!;
      expect(r.profileName, 'Java');
      expect(r.extensions, ['vscjava.vscode-java-pack']);
      expect(r.optionalExtensions, [
        'llvm-vs-code-extensions.vscode-clangd',
        'ms-vscode.cmake-tools',
      ]);
    });

    test('an optional extension already in the main list is dropped', () {
      final r = recommend(
        _analysis(['node', 'cmake', 'make']),
        _rules,
      ).valueOrNull!;
      expect(r.profileName, 'Web / Python');
      expect(r.optionalExtensions.toSet().length, r.optionalExtensions.length);
    });

    test(
      'settings of all detected types are merged, primary wins conflicts',
      () {
        final r = recommend(
          _analysis(['java-maven', 'cmake']),
          _rules,
        ).valueOrNull!;
        expect(
          r.settingsPatch.keys,
          containsAll(['java.import.exclusions', 'cmake.configureOnOpen']),
        );
      },
    );

    test('no detected type is an Err', () {
      expect(recommend(_analysis([]), _rules), isA<Err<Recommendation>>());
    });

    test('a detected type missing from the rules is an Err', () {
      final a = AnalysisResult(
        types: const [DetectedType(typeId: 'ghost', label: 'g', priority: 1)],
        stats: const TreeStats(fileCount: 0, truncated: false),
        analyzedAt: DateTime.utc(2026),
      );
      expect(recommend(a, _rules), isA<Err<Recommendation>>());
    });
  });

  group('sizeRules', () {
    test('applied only when the tree was truncated', () {
      final small = recommend(_analysis(['make']), _rules).valueOrNull!;
      expect(small.settingsPatch.containsKey('search.followSymlinks'), isFalse);

      final big = recommend(
        _analysis(['make'], truncated: true),
        _rules,
      ).valueOrNull!;
      expect(big.settingsPatch['search.followSymlinks'], false);
      expect(big.notes, contains('트리가 매우 큽니다. 전체 대신 작업 모듈 폴더만 여는 것을 권장합니다.'));
    });
  });

  group('variable substitution', () {
    final vars = {'aospRoot': '/src/aosp'};
    Object? sub(Object? v, [Map<String, String>? m, Set<String>? missing]) =>
        substituteVariables(v, m ?? vars, missing ?? <String>{});

    test('resolved variable', () {
      expect(sub(r'${aospRoot}/out'), '/src/aosp/out');
      expect(sub(r'a ${aospRoot} b ${aospRoot}'), 'a /src/aosp b /src/aosp');
    });

    test('recurses into lists and maps, leaves non-strings alone', () {
      expect(
        sub({
          'k': [r'${aospRoot}', 1, true, null],
          'n': {'p': r'x/${aospRoot}'},
        }),
        {
          'k': ['/src/aosp', 1, true, null],
          'n': {'p': 'x//src/aosp'},
        },
      );
    });

    test('reserved variables are preserved', () {
      const text =
          r'${workspaceFolder}/build:${workspaceFolderBasename}:${userHome}:${env:HOME}';
      final missing = <String>{};
      expect(sub(text, const {}, missing), text);
      expect(missing, isEmpty);
    });

    test('unresolved variables are reported and left in place', () {
      final missing = <String>{};
      expect(sub(r'${nope}/x', vars, missing), r'${nope}/x');
      expect(missing, {'nope'});
    });

    test('an unresolved variable drops that setting and adds a warning', () {
      final rule = TypeRule(
        id: 't',
        label: 'T',
        priority: 1,
        match: const FileMatcher('x'),
        profile: 'P',
        settings: const {
          'good': r'${known}',
          'bad': [r'--dir=${missing}/x'],
          'keep': r'${workspaceFolder}/b',
        },
        notes: const [r'run in ${missing}', r'ok ${known}'],
      );
      final rules = Rules(version: 1, scan: ScanConfig.defaults, types: [rule]);
      final a = AnalysisResult(
        types: [const DetectedType(typeId: 't', label: 'T', priority: 1)],
        stats: const TreeStats(fileCount: 0, truncated: false),
        variables: const {'known': 'K'},
        analyzedAt: DateTime.utc(2026),
      );
      final r = recommend(a, rules).valueOrNull!;
      expect(r.settingsPatch, {'good': 'K', 'keep': r'${workspaceFolder}/b'});
      expect(r.notes.first, 'ok K');
      expect(r.notes.where((n) => n.contains(r'${missing}')), hasLength(2));
      expect(r.notes.any((n) => n.contains("'bad'")), isTrue);
    });
  });
}
