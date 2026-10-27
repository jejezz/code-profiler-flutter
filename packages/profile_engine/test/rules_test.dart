import 'dart:io';

import 'package:profile_engine/profile_engine.dart';
import 'package:test/test.dart';

const _minimalType = '''
version: 1
types:
  - id: a
    label: A
    priority: 1
    match: { file: a.txt }
    profile: P
''';

EngineError _error(Result<Rules> r) {
  expect(r, isA<Err<Rules>>());
  return r.errorOrNull!;
}

Rules _ok(Result<Rules> r) {
  expect(r, isA<Ok<Rules>>(), reason: '${r.errorOrNull}');
  return r.valueOrNull!;
}

void main() {
  group('default rules', () {
    test('load and validate', () {
      final rules = _ok(loadDefaultRules());
      expect(rules.types.map((t) => t.id), [
        'esp-idf',
        'aosp-module',
        'java-gradle',
        'java-maven',
        'cmake',
        'linux-kernel',
        'make',
        'node',
        'python',
      ]);
      expect(rules.scan.maxDepth, 3);
      expect(rules.scan.maxFiles, 20000);
      expect(rules.scan.skipDirs, contains('node_modules'));
      expect(rules.variables['aospRoot']!.maxLevels, 12);
      expect(rules.sizeRules.single.truncated, isTrue);
    });

    test('matcher tree and settings are parsed', () {
      final rules = _ok(loadDefaultRules());
      final aosp = rules.types.firstWhere((t) => t.id == 'aosp-module');
      final match = aosp.match as AllMatcher;
      expect(match.children[0], isA<AnyMatcher>());
      expect((match.children[1] as VariableMatcher).name, 'aospRoot');
      expect(aosp.suppresses, ['cmake', 'make']);
      expect(aosp.settings['clangd.arguments'], isA<List<Object?>>());

      final esp = rules.types.firstWhere((t) => t.id == 'esp-idf');
      final contains = (esp.match as AnyMatcher).children
          .whereType<FileContainsMatcher>()
          .single;
      expect(contains.pattern.hasMatch('include(\$ENV{IDF_PATH}/x)'), isTrue);
      expect(contains.pattern.hasMatch('project.cmake'), isTrue);
    });

    test('assets/rules.yaml matches the embedded constant', () {
      final file = File('assets/rules.yaml').readAsStringSync();
      final embedded = loadDefaultRules();
      final fromFile = parseRules(file.replaceAll('\r\n', '\n'));
      expect(embedded.isOk, isTrue);
      expect(fromFile.isOk, isTrue);
      final a = embedded.valueOrNull!;
      final b = fromFile.valueOrNull!;
      expect(
        a.types.map((t) => [t.id, t.priority, t.profile]),
        b.types.map((t) => [t.id, t.priority, t.profile]),
      );
      final gen = File('lib/src/rules/default_rules.dart').readAsStringSync();
      expect(gen, contains(file.replaceAll('\r\n', '\n')));
    });
  });

  group('schema errors carry line numbers', () {
    test('unknown key', () {
      final e = _error(
        parseRules('''
version: 1
types:
  - id: a
    label: A
    priority: 1
    match: { file: a.txt }
    profile: P
    extension: [x]
'''),
      );
      expect(e.message, contains("'extension'"));
      expect(e.line, 8);
    });

    test('missing required key points at the type', () {
      final e = _error(
        parseRules('''
version: 1
types:
  - id: a
    label: A
    match: { file: a.txt }
    profile: P
'''),
      );
      expect(e.message, contains("'priority'"));
      expect(e.line, 3);
    });

    test('wrong value type', () {
      final e = _error(
        parseRules(_minimalType.replaceFirst('priority: 1', 'priority: high')),
      );
      expect(e.message, contains('priority'));
      expect(e.line, 5);
    });

    test('bad regex in fileContains', () {
      final e = _error(
        parseRules('''
version: 1
types:
  - id: a
    label: A
    priority: 1
    match:
      fileContains: { glob: x, pattern: "(" }
    profile: P
'''),
      );
      expect(e.message, contains('정규식'));
      expect(e.line, 7);
    });

    test('match with two keys', () {
      final e = _error(
        parseRules(
          _minimalType.replaceFirst('{ file: a.txt }', '{ file: a, dir: b }'),
        ),
      );
      expect(e.message, contains('정확히 하나'));
      expect(e.line, 6);
    });

    test('duplicate type id', () {
      final e = _error(
        parseRules('''
version: 1
types:
  - id: a
    label: A
    priority: 1
    match: { file: a }
    profile: P
  - id: a
    label: B
    priority: 2
    match: { file: b }
    profile: P
'''),
      );
      expect(e.message, contains('중복'));
      expect(e.line, 8);
    });

    test('unsupported version', () {
      final e = _error(parseRules('version: 2\ntypes: []\n'));
      expect(e.message, contains('version'));
      expect(e.line, 1);
    });

    test('YAML syntax error', () {
      final e = _error(parseRules('version: 1\ntypes: [\n'));
      expect(e.message, contains('YAML'));
    });

    test('empty all/any', () {
      final e = _error(
        parseRules(_minimalType.replaceFirst('{ file: a.txt }', '{ any: [] }')),
      );
      expect(e.message, contains('비어'));
    });
  });

  group('references are validated after merging', () {
    test('suppresses must name an existing type', () {
      final r = parseRules('''
version: 1
types:
  - id: a
    label: A
    priority: 1
    match: { file: a }
    suppresses: [ghost]
    profile: P
''');
      final rules = _ok(r);
      expect(validateRules(rules)!.message, contains('ghost'));
    });

    test('variable must be defined', () {
      final rules = _ok(
        parseRules(
          _minimalType.replaceFirst('{ file: a.txt }', '{ variable: nope }'),
        ),
      );
      expect(validateRules(rules)!.message, contains('nope'));
    });
  });

  group('user rules', () {
    late Directory dir;
    setUp(() => dir = Directory.systemTemp.createTempSync('rules_test'));
    tearDown(() => dir.deleteSync(recursive: true));

    String write(String text) {
      final f = File('${dir.path}/rules.user.yaml')..writeAsStringSync(text);
      return f.path;
    }

    test('missing file means defaults only', () async {
      final r = await loadRules(userRulesPath: '${dir.path}/none.yaml');
      expect(_ok(r).types, hasLength(9));
      expect(_ok(await loadRules()).types, hasLength(9));
    });

    test('same id overrides in place, new id is appended', () async {
      final path = write('''
version: 1
types:
  - id: cmake
    label: CMake (custom)
    priority: 55
    match: { file: CMakeLists.txt }
    profile: My C++
  - id: rust
    label: Rust
    priority: 60
    match: { file: Cargo.toml }
    profile: Rust
''');
      final rules = _ok(await loadRules(userRulesPath: path));
      expect(rules.types, hasLength(10));
      final i = rules.types.indexWhere((t) => t.id == 'cmake');
      expect(i, 4);
      expect(rules.types[i].profile, 'My C++');
      expect(rules.types.last.id, 'rust');
    });

    test('scan inherits unspecified fields from defaults', () async {
      final path = write('version: 1\nscan: { maxDepth: 5 }\n');
      final rules = _ok(await loadRules(userRulesPath: path));
      expect(rules.scan.maxDepth, 5);
      expect(rules.scan.maxFiles, 20000);
      expect(rules.scan.skipDirs, contains('.git'));
    });

    test('user variables and sizeRules are added', () async {
      final path = write('''
version: 1
variables:
  extra:
    findUpward: { anyOf: [marker], maxLevels: 2 }
sizeRules:
  - when: { truncated: true }
    notes: ["x"]
''');
      final rules = _ok(await loadRules(userRulesPath: path));
      expect(rules.variables.keys, containsAll(['aospRoot', 'extra']));
      expect(rules.sizeRules, hasLength(2));
    });

    test('error mentions the file and line', () async {
      final path = write('version: 1\ntypes:\n  - id: x\n');
      final e = _error(await loadRules(userRulesPath: path));
      expect(e.message, contains('rules.user.yaml'));
      expect(e.line, 3);
    });

    test('user rule suppressing an unknown type is rejected', () async {
      final path = write('''
version: 1
types:
  - id: z
    label: Z
    priority: 1
    match: { file: z }
    suppresses: [ghost]
    profile: P
''');
      expect(
        _error(await loadRules(userRulesPath: path)).message,
        contains('ghost'),
      );
    });
  });

  group('Result', () {
    test('Ok and Err expose value and error', () {
      const ok = Ok<int>(1);
      const err = Err<int>(EngineError('boom', line: 3));
      expect(ok.valueOrNull, 1);
      expect(ok.errorOrNull, isNull);
      expect(err.valueOrNull, isNull);
      expect(err.errorOrNull.toString(), '줄 3: boom');
    });
  });
}
