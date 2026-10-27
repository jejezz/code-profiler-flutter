import 'dart:io';
import 'dart:isolate';

import '../model/analysis.dart';
import '../result.dart';
import '../rules/rules_loader.dart';
import '../rules/rules_model.dart';
import 'matcher.dart';
import 'scanner.dart';
import 'variables.dart';

/// [path] 폴더를 분석한다. 스캔은 별도 Isolate에서 돌려 UI 스레드를 막지 않는다.
///
/// Isolate는 메모리를 공유하지 않는 Dart의 실행 단위(스레드와 비슷하지만 서로 메시지로만
/// 통신)다. `Isolate.run`은 함수 하나를 새 Isolate에서 실행하고 결과를 돌려받는다.
///
/// [rules]를 생략하면 내장 기본 규칙을 쓴다.
Future<Result<AnalysisResult>> analyze(String path, {Rules? rules}) async {
  final Rules resolved;
  if (rules != null) {
    resolved = rules;
  } else {
    final loaded = loadDefaultRules();
    if (loaded is Err<Rules>) return Err(loaded.error);
    resolved = (loaded as Ok<Rules>).value;
  }
  try {
    return await Isolate.run(() => analyzeSync(path, rules: resolved));
  } on Object catch (e) {
    return Err(EngineError('분석 중 오류가 발생했습니다: $e'));
  }
}

/// [analyze]와 같지만 현재 Isolate에서 동기로 실행한다(엔진 CLI와 테스트용).
Result<AnalysisResult> analyzeSync(
  String path, {
  required Rules rules,
  DateTime? now,
}) {
  final dir = Directory(path);
  if (!dir.existsSync()) {
    return Err(EngineError('경로를 찾을 수 없거나 폴더가 아닙니다: $path'));
  }
  final root = _normalize(dir.absolute.path);

  final ScanSnapshot snapshot;
  final Map<String, String> variables;
  try {
    snapshot = scanTree(root, rules.scan);
    variables = resolveVariables(root, rules.variables);
  } on FileSystemException catch (e) {
    return Err(EngineError('폴더를 읽을 수 없습니다: ${e.message}'));
  }

  final ctx = MatchContext(snapshot, variables);
  final matched = <TypeRule, List<Evidence>>{};
  for (final type in rules.types) {
    final evidence = evaluate(type.match, ctx);
    if (evidence != null) matched[type] = evidence;
  }

  // suppresses는 맞은 유형 전체를 기준으로 계산한 뒤 한꺼번에 제거한다.
  final suppressed = {for (final t in matched.keys) ...t.suppresses};
  final detected = [
    for (final e in matched.entries)
      if (!suppressed.contains(e.key.id))
        DetectedType(
          typeId: e.key.id,
          label: e.key.label,
          priority: e.key.priority,
          evidence: e.value,
        ),
  ];
  // List.sort는 안정 정렬이 아니므로 규칙 파일의 순서를 보조 키로 쓴다.
  final order = {
    for (var i = 0; i < rules.types.length; i++) rules.types[i].id: i,
  };
  detected.sort((a, b) {
    final byPriority = b.priority.compareTo(a.priority);
    return byPriority != 0
        ? byPriority
        : order[a.typeId]!.compareTo(order[b.typeId]!);
  });

  return Ok(
    AnalysisResult(
      types: detected,
      stats: TreeStats(
        fileCount: snapshot.files.length,
        truncated: snapshot.truncated,
        largeDirsPresent: snapshot.skippedDirNames,
      ),
      variables: variables,
      analyzedAt: (now ?? DateTime.now()).toUtc(),
    ),
  );
}

String _normalize(String path) {
  if (path.length > 1 && (path.endsWith('/') || path.endsWith(r'\'))) {
    return path.substring(0, path.length - 1);
  }
  return path;
}
