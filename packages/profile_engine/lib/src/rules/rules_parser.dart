import 'package:yaml/yaml.dart';

import '../result.dart';
import 'rules_model.dart';

/// 파서 내부에서만 쓰는 예외. 공개 함수 경계에서 [Err]로 바꾼다.
class _RulesFormatException implements Exception {
  final String message;
  final int? line;

  _RulesFormatException(this.message, this.line);
}

/// 줄 번호가 붙은 오류를 던진다. 줄 번호는 1부터 센다.
Never _fail(YamlNode node, String message) =>
    throw _RulesFormatException(message, node.span.start.line + 1);

/// 규칙 YAML 문자열을 [Rules]로 바꾼다. 구조만 검사하고, type 사이의 참조
/// (`suppresses`, `variable`)는 병합 뒤에 [validateRules]로 검사한다.
///
/// [defaults]는 `scan`에서 빠진 필드를 채울 값이다. 사용자 규칙 파일은 기본 규칙의
/// scan을 넘겨서 일부 필드만 바꿀 수 있다.
Result<Rules> parseRules(
  String source, {
  ScanConfig defaults = ScanConfig.defaults,
}) {
  try {
    final YamlNode root;
    try {
      root = loadYamlNode(source);
    } on YamlException catch (e) {
      return Err(
        EngineError(
          'YAML 문법 오류: ${e.message}',
          line: e.span?.start.line == null ? null : e.span!.start.line + 1,
        ),
      );
    }
    return Ok(_parseRoot(root, defaults));
  } on _RulesFormatException catch (e) {
    return Err(EngineError(e.message, line: e.line));
  }
}

/// type 사이의 참조가 모두 존재하는지 검사한다. 문제가 없으면 null.
EngineError? validateRules(Rules rules) {
  final ids = {for (final t in rules.types) t.id};
  for (final t in rules.types) {
    for (final s in t.suppresses) {
      if (!ids.contains(s)) {
        return EngineError("type '${t.id}'의 suppresses에 없는 type '$s'가 있습니다");
      }
    }
    for (final name in _variableNames(t.match)) {
      if (!rules.variables.containsKey(name)) {
        return EngineError("type '${t.id}'가 정의되지 않은 변수 '$name'를 참조합니다");
      }
    }
  }
  return null;
}

Iterable<String> _variableNames(Matcher m) sync* {
  switch (m) {
    case AllMatcher(:final children) || AnyMatcher(:final children):
      for (final c in children) {
        yield* _variableNames(c);
      }
    case VariableMatcher(:final name):
      yield name;
    case FileMatcher() || DirMatcher() || FileContainsMatcher():
      break;
  }
}

Rules _parseRoot(YamlNode root, ScanConfig defaults) {
  final map = _map(root, '최상위');
  _checkKeys(map, const {'version', 'scan', 'variables', 'types', 'sizeRules'});

  final versionNode = _required(map, 'version');
  if (_int(versionNode, 'version') != 1) {
    _fail(versionNode, '지원하지 않는 version 입니다(1만 지원)');
  }

  final scanNode = map.nodes['scan'];
  final variablesNode = map.nodes['variables'];
  final typesNode = map.nodes['types'];
  final sizeNode = map.nodes['sizeRules'];

  final types = <TypeRule>[];
  final seen = <String>{};
  if (typesNode != null) {
    for (final n in _list(typesNode, 'types').nodes) {
      final t = _parseType(n);
      if (!seen.add(t.id)) _fail(n, "type id '${t.id}'가 중복됩니다");
      types.add(t);
    }
  }

  return Rules(
    version: 1,
    scan: scanNode == null ? defaults : _parseScan(scanNode, defaults),
    variables: variablesNode == null
        ? const {}
        : _parseVariables(variablesNode),
    types: types,
    sizeRules: sizeNode == null
        ? const []
        : [
            for (final n in _list(sizeNode, 'sizeRules').nodes)
              _parseSizeRule(n),
          ],
  );
}

ScanConfig _parseScan(YamlNode node, ScanConfig defaults) {
  final map = _map(node, 'scan');
  _checkKeys(map, const {'maxDepth', 'maxFiles', 'skipDirs'});
  final depth = map.nodes['maxDepth'];
  final files = map.nodes['maxFiles'];
  final skip = map.nodes['skipDirs'];
  final maxDepth = depth == null ? defaults.maxDepth : _int(depth, 'maxDepth');
  final maxFiles = files == null ? defaults.maxFiles : _int(files, 'maxFiles');
  if (maxDepth < 0) _fail(depth!, 'maxDepth는 0 이상이어야 합니다');
  if (maxFiles < 1) _fail(files!, 'maxFiles는 1 이상이어야 합니다');
  return ScanConfig(
    maxDepth: maxDepth,
    maxFiles: maxFiles,
    skipDirs: skip == null ? defaults.skipDirs : _strings(skip, 'skipDirs'),
  );
}

Map<String, VariableRule> _parseVariables(YamlNode node) {
  final result = <String, VariableRule>{};
  final map = _map(node, 'variables');
  for (final name in map.keys) {
    final key = name as String;
    final body = _map(map.nodes[key]!, "변수 '$key'");
    _checkKeys(body, const {'findUpward'});
    final up = _map(_required(body, 'findUpward'), 'findUpward');
    _checkKeys(up, const {'anyOf', 'maxLevels'});
    final anyOf = _strings(_required(up, 'anyOf'), 'anyOf');
    if (anyOf.isEmpty) _fail(up.nodes['anyOf']!, 'anyOf는 비어 있을 수 없습니다');
    final levels = up.nodes['maxLevels'];
    final maxLevels = levels == null ? 12 : _int(levels, 'maxLevels');
    if (maxLevels < 1) _fail(levels!, 'maxLevels는 1 이상이어야 합니다');
    result[key] = VariableRule(anyOf: anyOf, maxLevels: maxLevels);
  }
  return result;
}

TypeRule _parseType(YamlNode node) {
  final map = _map(node, 'type');
  _checkKeys(map, const {
    'id',
    'label',
    'priority',
    'match',
    'suppresses',
    'profile',
    'extensions',
    'settings',
    'notes',
  });
  final suppresses = map.nodes['suppresses'];
  final extensions = map.nodes['extensions'];
  final settings = map.nodes['settings'];
  final notes = map.nodes['notes'];
  return TypeRule(
    id: _str(_required(map, 'id'), 'id'),
    label: _str(_required(map, 'label'), 'label'),
    priority: _int(_required(map, 'priority'), 'priority'),
    match: _parseMatcher(_required(map, 'match')),
    suppresses: suppresses == null
        ? const []
        : _strings(suppresses, 'suppresses'),
    profile: _str(_required(map, 'profile'), 'profile'),
    extensions: extensions == null
        ? const []
        : _strings(extensions, 'extensions'),
    settings: settings == null ? const {} : _settings(settings),
    notes: notes == null ? const [] : _strings(notes, 'notes'),
  );
}

SizeRule _parseSizeRule(YamlNode node) {
  final map = _map(node, 'sizeRules 항목');
  _checkKeys(map, const {'when', 'settings', 'notes'});
  final whenMap = _map(_required(map, 'when'), 'when');
  _checkKeys(whenMap, const {'truncated'});
  final truncated = _required(whenMap, 'truncated');
  if (truncated.value is! bool) {
    _fail(truncated, 'truncated는 true/false 여야 합니다');
  }
  final settings = map.nodes['settings'];
  final notes = map.nodes['notes'];
  return SizeRule(
    truncated: truncated.value as bool,
    settings: settings == null ? const {} : _settings(settings),
    notes: notes == null ? const [] : _strings(notes, 'notes'),
  );
}

Matcher _parseMatcher(YamlNode node) {
  final map = _map(node, 'match');
  if (map.length != 1) {
    _fail(
      node,
      'match에는 all/any/file/dir/fileContains/variable 중 정확히 하나의 키가 있어야 합니다',
    );
  }
  final key = map.keys.single as String;
  final value = map.nodes[key]!;
  switch (key) {
    case 'all' || 'any':
      final items = _list(value, key).nodes;
      if (items.isEmpty) _fail(value, '$key는 비어 있을 수 없습니다');
      final children = [for (final n in items) _parseMatcher(n)];
      return key == 'all' ? AllMatcher(children) : AnyMatcher(children);
    case 'file':
      return FileMatcher(_str(value, 'file'));
    case 'dir':
      return DirMatcher(_str(value, 'dir'));
    case 'variable':
      return VariableMatcher(_str(value, 'variable'));
    case 'fileContains':
      final body = _map(value, 'fileContains');
      _checkKeys(body, const {'glob', 'pattern'});
      final patternNode = _required(body, 'pattern');
      final RegExp regExp;
      try {
        regExp = RegExp(_str(patternNode, 'pattern'));
      } on FormatException catch (e) {
        _fail(patternNode, '정규식이 올바르지 않습니다: ${e.message}');
      }
      return FileContainsMatcher(_str(_required(body, 'glob'), 'glob'), regExp);
    default:
      _fail(node, "알 수 없는 매처 '$key' 입니다");
  }
}

YamlMap _map(YamlNode node, String what) {
  if (node is! YamlMap) _fail(node, '$what은(는) 키-값 목록이어야 합니다');
  return node;
}

YamlList _list(YamlNode node, String what) {
  if (node is! YamlList) _fail(node, '$what은(는) 목록이어야 합니다');
  return node;
}

String _str(YamlNode node, String what) {
  final v = node.value;
  if (v is! String || v.isEmpty) _fail(node, '$what은(는) 비어 있지 않은 문자열이어야 합니다');
  return v;
}

int _int(YamlNode node, String what) {
  final v = node.value;
  if (v is! int) _fail(node, '$what은(는) 정수여야 합니다');
  return v;
}

List<String> _strings(YamlNode node, String what) => [
  for (final n in _list(node, what).nodes) _str(n, '$what의 항목'),
];

YamlNode _required(YamlMap map, String key) {
  final n = map.nodes[key];
  if (n == null) _fail(map, "필수 키 '$key'가 없습니다");
  return n;
}

void _checkKeys(YamlMap map, Set<String> allowed) {
  for (final k in map.keys) {
    if (k is! String || !allowed.contains(k)) {
      _fail(map.nodes[k]!, "알 수 없는 키 '$k' 입니다(허용: ${allowed.join(', ')})");
    }
  }
}

Map<String, Object?> _settings(YamlNode node) {
  final plain = _plain(_map(node, 'settings'));
  return plain as Map<String, Object?>;
}

/// YamlMap/YamlList를 일반 Map/List로 바꾼다(JSON 직렬화와 병합을 위해).
Object? _plain(Object? v) => switch (v) {
  YamlMap m => {for (final e in m.entries) '${e.key}': _plain(e.value)},
  YamlList l => [for (final e in l) _plain(e)],
  _ => v,
};
