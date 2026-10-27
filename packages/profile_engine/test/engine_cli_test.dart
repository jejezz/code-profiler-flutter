import 'dart:convert';
import 'dart:io';

import 'package:profile_engine/profile_engine.dart';
import 'package:profile_engine/src/cli/engine_cli.dart';
import 'package:test/test.dart';

import 'fixtures/fixture.dart';

final class _Run {
  final int code;
  final String out;
  final String err;

  _Run(this.code, this.out, this.err);

  Map<String, Object?> get json => jsonDecode(out) as Map<String, Object?>;
}

Future<_Run> _run(List<String> args, {String? stdinText}) async {
  final out = StringBuffer();
  final err = StringBuffer();
  final code = await runEngineCli(
    args,
    out: out,
    err: err,
    stdinStream: stdinText == null
        ? null
        : Stream.value(utf8.encode(stdinText)),
  );
  return _Run(code, out.toString(), err.toString());
}

Directory _esp() => createFixture({
  'CMakeLists.txt': 'include(\$ENV{IDF_PATH}/x/project.cmake)\n',
  'sdkconfig': '',
  'main/main.c': '',
});

void main() {
  test(
    '--version prints the engine version and matches pubspec.yaml',
    () async {
      final r = await _run(['--version']);
      expect(r.code, exitOk);
      expect(r.out.trim(), engineVersion);
      final pubspec = File('pubspec.yaml').readAsStringSync();
      expect(
        pubspec,
        contains(RegExp('^version: $engineVersion\\s*\$', multiLine: true)),
      );
    },
  );

  group('analyze', () {
    test('--json writes exactly one JSON object to stdout', () async {
      final fx = _esp();
      final r = await _run(['analyze', fx.path, '--json']);
      expect(r.code, exitOk);
      expect(r.out.trim().split('\n'), hasLength(1));
      expect(r.err, isEmpty);
      final analysis = AnalysisResult.fromJson(
        r.json['analysis'] as Map<String, Object?>,
      );
      expect(analysis.types.map((t) => t.typeId), ['esp-idf']);
      expect(r.json['ok'], isTrue);
    });

    test('without --json it prints a readable summary', () async {
      final r = await _run(['analyze', _esp().path]);
      expect(r.code, exitOk);
      expect(r.out, contains('ESP-IDF'));
      expect(r.out, contains('sdkconfig'));
    });

    test('missing path: exit 2, JSON error, message on stderr', () async {
      final r = await _run([
        'analyze',
        '${Directory.systemTemp.path}/nope_xyz',
        '--json',
      ]);
      expect(r.code, exitPath);
      expect((r.json['error'] as Map)['kind'], 'path');
      expect(r.json['ok'], isFalse);
      expect(r.err, contains('찾을 수 없'));
    });

    test('no path: usage error, exit 1', () async {
      final r = await _run(['analyze', '--json']);
      expect(r.code, exitUsage);
      expect((r.json['error'] as Map)['kind'], 'usage');
    });

    test('--rules adds user rules; a missing rules file is exit 3', () async {
      final fx = createFixture({
        'Cargo.toml': '',
        'rules.yaml': '''
version: 1
types:
  - id: rust
    label: Rust
    priority: 60
    match: { file: Cargo.toml }
    profile: Rust
''',
        'bad.yaml': 'version: 1\ntypes:\n  - id: x\n',
      });
      final ok = await _run([
        'analyze',
        fx.path,
        '--rules',
        '${fx.path}/rules.yaml',
        '--json',
      ]);
      expect(ok.code, exitOk);
      expect(
        ((ok.json['analysis'] as Map)['types'] as List).map(
          (t) => (t as Map)['typeId'],
        ),
        ['rust'],
      );

      final bad = await _run([
        'analyze',
        fx.path,
        '--rules',
        '${fx.path}/bad.yaml',
        '--json',
      ]);
      expect(bad.code, exitRules);
      expect(((bad.json['error'] as Map))['line'], 3);

      final missing = await _run([
        'analyze',
        fx.path,
        '--rules',
        '${fx.path}/none.yaml',
        '--json',
      ]);
      expect(missing.code, exitRules);
    });
  });

  group('recommend', () {
    test('returns analysis and recommendation', () async {
      final r = await _run(['recommend', _esp().path, '--json']);
      expect(r.code, exitOk);
      final rec = Recommendation.fromJson(
        r.json['recommendation'] as Map<String, Object?>,
      );
      expect(rec.profileName, 'ESP-IDF');
      expect(rec.extensions, contains('espressif.esp-idf-extension'));
    });

    test(
      'a folder with no detected type is ok with a null recommendation',
      () async {
        final fx = createFixture({'readme.txt': ''});
        final r = await _run(['recommend', fx.path, '--json']);
        expect(r.code, exitOk);
        expect(r.json['recommendation'], isNull);
      },
    );
  });

  group('settings', () {
    test(
      'diff-settings reads the patch from a file and does not write',
      () async {
        final fx = createFixture({
          'patch.json': '{"a": 1, "m": {"k": 2}}',
          '.vscode/settings.json': '{ // mine\n "a": 5 }',
        });
        final r = await _run([
          'diff-settings',
          fx.path,
          '--patch',
          '${fx.path}/patch.json',
          '--json',
        ]);
        expect(r.code, exitOk);
        final diff = r.json['diff'] as Map<String, Object?>;
        expect(diff['commentsWillBeLost'], isTrue);
        expect(diff['hasChanges'], isTrue);
        final changes = (diff['changes'] as List).cast<Map<String, Object?>>();
        expect(
          changes.firstWhere((c) => c['pointer'] == '/a')['kind'],
          'conflict',
        );
        expect(
          File('${fx.path}/.vscode/settings.json').readAsStringSync(),
          '{ // mine\n "a": 5 }',
        );
      },
    );

    test(
      'apply-settings with --patch - reads stdin and writes with a backup',
      () async {
        final fx = createFixture({'.vscode/settings.json': '{"a": 1}'});
        final r = await _run([
          'apply-settings',
          fx.path,
          '--patch',
          '-',
          '--json',
        ], stdinText: '{"b": 2}');
        expect(r.code, exitOk);
        expect(r.json['written'], isTrue);
        expect(r.json['backupPath'], isNotNull);
        expect(
          jsonDecode(
            File('${fx.path}/.vscode/settings.json').readAsStringSync(),
          ),
          {'a': 1, 'b': 2},
        );
      },
    );

    test('--replace-conflicts replaces only the listed pointers', () async {
      final fx = createFixture({
        '.vscode/settings.json': '{"a": 1, "b": 1}',
        'p.json': '{"a": 2, "b": 2}',
      });
      final r = await _run([
        'apply-settings',
        fx.path,
        '--patch',
        '${fx.path}/p.json',
        '--replace-conflicts',
        '/a',
        '--json',
      ]);
      expect(r.code, exitOk);
      expect(
        jsonDecode(File('${fx.path}/.vscode/settings.json').readAsStringSync()),
        {'a': 2, 'b': 1},
      );
    });

    test('nothing to change: written false', () async {
      final fx = createFixture({'.vscode/settings.json': '{"a": 1}'});
      final r = await _run([
        'apply-settings',
        fx.path,
        '--patch',
        '-',
        '--json',
      ], stdinText: '{"a": 1}');
      expect(r.code, exitOk);
      expect(r.json['written'], isFalse);
    });

    test(
      'invalid existing settings.json: exit 4 and the file is untouched',
      () async {
        final fx = createFixture({'.vscode/settings.json': '{oops'});
        final r = await _run([
          'apply-settings',
          fx.path,
          '--patch',
          '-',
          '--json',
        ], stdinText: '{"a": 1}');
        expect(r.code, exitWrite);
        expect((r.json['error'] as Map)['kind'], 'settings');
        expect(
          File('${fx.path}/.vscode/settings.json').readAsStringSync(),
          '{oops',
        );
      },
    );

    test('bad patch: exit 1; missing project: exit 2', () async {
      final fx = createFixture({'a.txt': ''});
      expect(
        (await _run([
          'diff-settings',
          fx.path,
          '--patch',
          '-',
        ], stdinText: '[1]')).code,
        exitUsage,
      );
      expect(
        (await _run([
          'diff-settings',
          fx.path,
          '--patch',
          '-',
        ], stdinText: '{oops')).code,
        exitUsage,
      );
      expect((await _run(['diff-settings', fx.path])).code, exitUsage);
      expect(
        (await _run([
          'diff-settings',
          '${fx.path}/none',
          '--patch',
          '-',
        ], stdinText: '{}')).code,
        exitPath,
      );
    });

    test('Korean text survives the JSON round trip', () async {
      final fx = createFixture({'a.txt': ''});
      final r = await _run([
        'apply-settings',
        fx.path,
        '--patch',
        '-',
        '--json',
      ], stdinText: '{"k": "한글"}');
      expect(r.code, exitOk);
      expect(
        File('${fx.path}/.vscode/settings.json').readAsStringSync(),
        contains('한글'),
      );
    });
  });

  group('usage', () {
    test('no command: exit 1; unknown command and flags: exit 1', () async {
      expect((await _run([])).code, exitUsage);
      expect((await _run(['frobnicate'])).code, exitUsage);
      expect((await _run(['analyze', '.', '--nope'])).code, exitUsage);
    });

    test('--help is not an error', () async {
      final r = await _run(['--help']);
      expect(r.code, exitOk);
      expect(r.err, contains('사용법'));
    });
  });
}
