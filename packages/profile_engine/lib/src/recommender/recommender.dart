import '../model/analysis.dart';
import '../model/recommendation.dart';
import '../result.dart';
import '../rules/rules_model.dart';
import '../settings/merge.dart';
import 'substitute.dart';

/// 분석 결과로 프로필·확장·설정 패치를 추천한다(설계 문서 3.3).
///
/// 1. 최상위 유형(주 유형)의 profile이 추천 프로필이다.
/// 2. 같은 profile을 쓰는 유형의 확장은 `extensions`로 합치고, 다른 profile의 확장은
///    `optionalExtensions`로 보낸다.
/// 3. settings는 주 유형 → 나머지 유형 → sizeRules 순으로 병합한다. 충돌하면 먼저 온 쪽이 이긴다.
/// 4. `${변수}`를 치환한다. 해석되지 않은 변수가 든 설정 항목은 빼고 notes에 경고를 남긴다.
Result<Recommendation> recommend(AnalysisResult analysis, Rules rules) {
  if (analysis.types.isEmpty) {
    return const Err(EngineError('판정된 프로젝트 유형이 없어 추천할 수 없습니다'));
  }

  final byId = {for (final t in rules.types) t.id: t};
  final detected = <TypeRule>[];
  for (final d in analysis.types) {
    final rule = byId[d.typeId];
    if (rule == null) {
      return Err(EngineError("분석 결과의 유형 '${d.typeId}'가 현재 규칙에 없습니다. 다시 분석하세요"));
    }
    detected.add(rule);
  }

  final primary = detected.first;
  final sameProfile = [
    for (final t in detected)
      if (t.profile == primary.profile) t,
  ];
  final extensions = _unique([for (final t in sameProfile) ...t.extensions]);
  final optional = _unique([
    for (final t in detected)
      if (t.profile != primary.profile) ...t.extensions,
  ]).where((e) => !extensions.contains(e)).toList();

  final sizeRules = [
    for (final s in rules.sizeRules)
      if (s.truncated == analysis.stats.truncated) s,
  ];

  var settings = <String, Object?>{};
  for (final patch in [
    for (final t in detected) t.settings,
    for (final s in sizeRules) s.settings,
  ]) {
    settings = mergeSettings(settings, patch).merged;
  }

  final notes = <String>[
    ...[
      for (final t in detected) ...t.notes,
      for (final s in sizeRules) ...s.notes,
    ],
  ];

  final warnings = <String>[];
  final resolvedSettings = <String, Object?>{};
  for (final entry in settings.entries) {
    final missing = <String>{};
    final value = substituteVariables(entry.value, analysis.variables, missing);
    if (missing.isEmpty) {
      resolvedSettings[entry.key] = value;
    } else {
      warnings.add(
        "설정 '${entry.key}'은(는) 해석되지 않은 변수 ${_names(missing)}가 있어 제외했습니다",
      );
    }
  }
  final resolvedNotes = <String>[];
  for (final note in _unique(notes)) {
    final missing = <String>{};
    final text =
        substituteVariables(note, analysis.variables, missing)! as String;
    if (missing.isEmpty) {
      resolvedNotes.add(text);
    } else {
      warnings.add('안내 문구에 해석되지 않은 변수 ${_names(missing)}가 있어 제외했습니다: $note');
    }
  }

  return Ok(
    Recommendation(
      profileName: primary.profile,
      extensions: extensions,
      optionalExtensions: optional,
      settingsPatch: resolvedSettings,
      notes: [...resolvedNotes, ...warnings],
    ),
  );
}

List<String> _unique(Iterable<String> items) => items.toSet().toList();

String _names(Set<String> names) =>
    (names.toList()..sort()).map((n) => '\${$n}').join(', ');
