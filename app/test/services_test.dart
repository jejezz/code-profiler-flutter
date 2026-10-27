import 'dart:convert';
import 'dart:io';

import 'package:code_profiler/services/analysis_hints.dart';
import 'package:code_profiler/services/app_config.dart';
import 'package:code_profiler/services/app_paths.dart';
import 'package:code_profiler/services/ids.dart';
import 'package:code_profiler/services/json_file_store.dart';
import 'package:code_profiler/services/project_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:profile_engine/profile_engine.dart';

Directory _tempDir() {
  final dir = Directory.systemTemp.createTempSync('code_profiler_test');
  addTearDown(() => dir.deleteSync(recursive: true));
  return dir;
}

Project _project(String id, {String? profile}) => Project(
  id: id,
  name: 'p$id',
  location: LocalLocation('/work/$id'),
  profileName: profile,
  addedAt: DateTime.utc(2026, 10, 1),
);

void main() {
  group('appDataDirectory (identity.md §6)', () {
    test('Windows: %APPDATA%\\<FileName>', () {
      final d = appDataDirectory(
        fileName: 'CodeProfiler',
        environment: {'APPDATA': r'C:\Users\me\AppData\Roaming'},
        operatingSystem: 'windows',
      );
      expect(d.path, r'C:\Users\me\AppData\Roaming\CodeProfiler');
    });

    test('macOS: ~/Library/Application Support/<FileName>', () {
      final d = appDataDirectory(
        fileName: 'CodeProfiler',
        environment: {'HOME': '/Users/me'},
        operatingSystem: 'macos',
      );
      expect(d.path, '/Users/me/Library/Application Support/CodeProfiler');
    });

    test('Linux: XDG_CONFIG_HOME, else ~/.config', () {
      expect(
        appDataDirectory(
          fileName: 'CodeProfiler',
          environment: {'XDG_CONFIG_HOME': '/cfg', 'HOME': '/home/me'},
          operatingSystem: 'linux',
        ).path,
        '/cfg/CodeProfiler',
      );
      expect(
        appDataDirectory(
          fileName: 'CodeProfiler',
          environment: {'HOME': '/home/me'},
          operatingSystem: 'linux',
        ).path,
        '/home/me/.config/CodeProfiler',
      );
    });
  });

  group('JsonFileStore', () {
    test('missing file reads as null', () async {
      final store = JsonFileStore(File('${_tempDir().path}/x.json'));
      expect(await store.read(), isNull);
    });

    test('write creates parent folders and round-trips', () async {
      final file = File('${_tempDir().path}/a/b/x.json');
      final store = JsonFileStore(file);
      await store.write({
        'k': [1, 2],
        'm': '한글',
      });
      expect(await store.read(), {
        'k': [1, 2],
        'm': '한글',
      });
      expect(file.readAsStringSync(), endsWith('\n'));
    });

    test('no temp file is left behind', () async {
      final dir = _tempDir();
      await JsonFileStore(File('${dir.path}/x.json')).write({'a': 1});
      expect(dir.listSync().map((e) => e.path.split(RegExp(r'[\\/]')).last), [
        'x.json',
      ]);
    });

    test('a corrupt file is moved aside and reads as null', () async {
      final dir = _tempDir();
      final file = File('${dir.path}/x.json')..writeAsStringSync('{oops');
      final store = JsonFileStore(file);
      expect(await store.read(), isNull);
      expect(file.existsSync(), isFalse);
      final names = dir.listSync().map((e) => e.path).toList();
      expect(names.single, contains('x.json.corrupt-'));
      // 다음 저장은 새 파일을 만들고 손상된 사본은 그대로 남는다.
      await store.write({'a': 1});
      expect(dir.listSync(), hasLength(2));
    });

    test('concurrent writes finish in order, last one wins', () async {
      final file = File('${_tempDir().path}/x.json');
      final store = JsonFileStore(file);
      await Future.wait([
        for (var i = 0; i < 10; i++) store.write({'n': i}),
      ]);
      expect(await store.read(), {'n': 9});
    });
  });

  group('FileProjectStore', () {
    JsonFileStore json() =>
        JsonFileStore(File('${_tempDir().path}/projects.json'));

    test('empty when no file', () async {
      expect(await FileProjectStore(json()).load(), isEmpty);
    });

    test('round trip with schemaVersion', () async {
      final raw = json();
      final store = FileProjectStore(raw);
      await store.save([_project('1', profile: 'Java'), _project('2')]);
      final back = await store.load();
      expect(back.map((p) => p.id), ['1', '2']);
      expect(back.first.profileName, 'Java');
      final file = (await raw.read())! as Map<String, Object?>;
      expect(file['schemaVersion'], 1);
    });

    test('one broken entry does not lose the others', () async {
      final raw = json();
      await raw.write({
        'schemaVersion': 1,
        'projects': [
          _project('1').toJson(),
          {'id': 'broken'},
          _project('3').toJson(),
        ],
      });
      final back = await FileProjectStore(raw).load();
      expect(back.map((p) => p.id), ['1', '3']);
    });

    test('a file from a newer version is refused, not overwritten', () async {
      final raw = json();
      await raw.write({'schemaVersion': 99, 'projects': []});
      await expectLater(
        FileProjectStore(raw).load(),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('AppConfig', () {
    test('an explicit code path wins over discovery', () {
      expect(
        const AppConfig(codePath: '/opt/code').effectiveCodePath,
        '/opt/code',
      );
    });

    test('copyWith can clear the path', () {
      const c = AppConfig(codePath: '/x');
      expect(c.copyWith(clearCodePath: true).codePath, isNull);
      expect(c.copyWith().codePath, '/x');
      expect(c.copyWith(codePath: '/y').codePath, '/y');
    });

    test('file store round trip; empty string means unset', () async {
      final raw = JsonFileStore(File('${_tempDir().path}/app_settings.json'));
      final store = FileAppConfigStore(raw);
      expect((await store.load()).codePath, isNull);
      await store.save(const AppConfig(codePath: r'C:\VS\code.cmd'));
      expect((await store.load()).codePath, r'C:\VS\code.cmd');
      await raw.write({'codePath': ''});
      expect((await store.load()).codePath, isNull);
    });
  });

  group('analysis hints', () {
    final rules = loadDefaultRules().valueOrNull!;

    AnalysisResult analysis(List<(String, int)> types) => AnalysisResult(
      types: [
        for (final (id, priority) in types)
          DetectedType(typeId: id, label: id, priority: priority),
      ],
      stats: const TreeStats(fileCount: 1, truncated: false),
      analyzedAt: DateTime.utc(2026),
    );

    test('close competitors: different profile and priority within 10', () {
      final r = closeCompetitors(
        analysis([('java-maven', 70), ('node', 60), ('cmake', 50)]),
        rules,
      );
      expect(r.map((t) => t.typeId), ['node']);
    });

    test('same-profile types are not competitors', () {
      final r = closeCompetitors(
        analysis([('node', 60), ('python', 60)]),
        rules,
      );
      expect(r, isEmpty);
    });

    test('a single type has no competitors; threshold is adjustable', () {
      expect(closeCompetitors(analysis([('node', 60)]), rules), isEmpty);
      expect(
        closeCompetitors(analysis([('java-maven', 70), ('cmake', 50)]), rules),
        isEmpty,
      );
      expect(
        closeCompetitors(
          analysis([('java-maven', 70), ('cmake', 50)]),
          rules,
          threshold: 20,
        ).map((t) => t.typeId),
        ['cmake'],
      );
    });

    test('pointerSegments decodes ~1 and ~0', () {
      expect(pointerSegments('/files.watcherExclude/**~1build~1**'), [
        'files.watcherExclude',
        '**/build/**',
      ]);
      expect(pointerSegments('/a~0b'), ['a~b']);
      expect(pointerSegments(''), isEmpty);
    });

    test('previewValue quotes strings and truncates', () {
      expect(previewValue('x'), '"x"');
      expect(previewValue(3), '3');
      expect(previewValue(['a', 'b']), '[a, b]');
      final long = previewValue('x' * 200, max: 20);
      expect(long.length, 20);
      expect(long, endsWith('…'));
      expect(previewValue('a\nb'), '"a b"');
    });

    test('hasUnsafeProfileChars', () {
      for (final bad in [
        'a&b',
        'a|b',
        'a<b',
        'a>b',
        'a^b',
        'a%b',
        'a"b',
        'a`b',
      ]) {
        expect(hasUnsafeProfileChars(bad), isTrue, reason: bad);
      }
      for (final ok in ['C++ AOSP', 'Web / Python', 'ESP-IDF', '프로필']) {
        expect(hasUnsafeProfileChars(ok), isFalse, reason: ok);
      }
    });
  });

  group('generateId', () {
    test('is a UUID v4 and unique', () {
      final re = RegExp(
        r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
      );
      final ids = {for (var i = 0; i < 200; i++) generateId()};
      expect(ids, hasLength(200));
      expect(ids.every(re.hasMatch), isTrue);
    });
  });

  test('JSON written by FileProjectStore is plain valid JSON', () async {
    final file = File('${_tempDir().path}/projects.json');
    await FileProjectStore(JsonFileStore(file)).save([_project('1')]);
    expect(jsonDecode(file.readAsStringSync()), isA<Map<String, Object?>>());
  });
}
