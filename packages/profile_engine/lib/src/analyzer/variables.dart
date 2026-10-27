import 'dart:io';

import '../rules/rules_model.dart';

/// rules.yaml `variables`를 모두 해석한다. 해석되지 않은 변수는 결과에 없다.
Map<String, String> resolveVariables(
  String root,
  Map<String, VariableRule> rules,
) {
  final result = <String, String>{};
  for (final entry in rules.entries) {
    final value = _findUpward(root, entry.value);
    if (value != null) result[entry.key] = value;
  }
  return result;
}

/// [root]에서 시작해 부모 방향으로 최대 [VariableRule.maxLevels]단계 올라가며
/// anyOf 중 하나가 있는 가장 가까운 디렉터리의 경로를 돌려준다.
String? _findUpward(String root, VariableRule rule) {
  var dir = Directory(root).absolute;
  for (var level = 0; level <= rule.maxLevels; level++) {
    for (final name in rule.anyOf) {
      final type = FileSystemEntity.typeSync(
        '${dir.path}/$name',
        followLinks: false,
      );
      if (type != FileSystemEntityType.notFound) return dir.path;
    }
    final parent = dir.parent;
    if (parent.path == dir.path) break;
    dir = parent;
  }
  return null;
}
