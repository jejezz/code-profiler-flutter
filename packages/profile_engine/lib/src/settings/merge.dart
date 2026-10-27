import 'dart:convert';

import '../result.dart';
import 'jsonc.dart';

enum ChangeKind { added, unchanged, conflict }

/// 병합에서 값 하나에 일어난 일.
final class SettingChange {
  /// JSON Pointer(RFC 6901). 설정 키에 `.`과 `/`가 흔해서 경로를 이 형식으로 식별한다.
  /// 예: `/files.watcherExclude/**~1build~1**` (`/`는 `~1`, `~`는 `~0`).
  final String pointer;
  final ChangeKind kind;

  /// 기존 값(없으면 null).
  final Object? existing;

  /// 패치 값. 목록에 항목이 더해진 경우에는 새로 더해진 항목들.
  final Object? patch;

  /// 충돌에서 패치 값으로 교체했는지.
  final bool replaced;

  const SettingChange({
    required this.pointer,
    required this.kind,
    this.existing,
    this.patch,
    this.replaced = false,
  });

  Map<String, Object?> toJson() => {
    'pointer': pointer,
    'kind': kind.name,
    'existing': existing,
    'patch': patch,
    'replaced': replaced,
  };
}

final class MergeResult {
  final Map<String, Object?> merged;
  final List<SettingChange> changes;

  const MergeResult(this.merged, this.changes);
}

/// 표 4.2의 병합 규칙.
///
/// | 기존 | 패치 | 결과 |
/// | Map | Map | 키 단위 재귀 병합 |
/// | List | List | 기존 순서 유지 + 없는 항목만 뒤에 추가 |
/// | 그 외 | 아무거나 | 기존 값 유지(충돌). 같은 값이면 변경 없음 |
/// | 없음 | 아무거나 | 패치 값 추가 |
///
/// [replaceConflicts]에 충돌 항목의 pointer가 있으면 그 항목만 패치 값으로 교체한다.
MergeResult mergeSettings(
  Map<String, Object?> existing,
  Map<String, Object?> patch, {
  Set<String> replaceConflicts = const {},
}) {
  final changes = <SettingChange>[];
  final merged = _mergeMap(existing, patch, '', replaceConflicts, changes);
  return MergeResult(merged, changes);
}

Map<String, Object?> _mergeMap(
  Map<String, Object?> existing,
  Map<String, Object?> patch,
  String pointer,
  Set<String> replace,
  List<SettingChange> changes,
) {
  // Map.of는 기존 키 순서를 보존하고, 새 키는 패치 순서대로 뒤에 붙는다.
  final out = Map<String, Object?>.of(existing);
  for (final entry in patch.entries) {
    final childPointer = '$pointer/${_escape(entry.key)}';
    if (!existing.containsKey(entry.key)) {
      out[entry.key] = entry.value;
      changes.add(
        SettingChange(
          pointer: childPointer,
          kind: ChangeKind.added,
          patch: entry.value,
        ),
      );
    } else {
      out[entry.key] = _mergeValue(
        existing[entry.key],
        entry.value,
        childPointer,
        replace,
        changes,
      );
    }
  }
  return out;
}

Object? _mergeValue(
  Object? existing,
  Object? patch,
  String pointer,
  Set<String> replace,
  List<SettingChange> changes,
) {
  if (existing is Map<String, Object?> && patch is Map<String, Object?>) {
    return _mergeMap(existing, patch, pointer, replace, changes);
  }
  if (existing is List<Object?> && patch is List<Object?>) {
    final out = [...existing];
    final added = <Object?>[];
    for (final item in patch) {
      if (!out.any((x) => deepEquals(x, item))) {
        out.add(item);
        added.add(item);
      }
    }
    changes.add(
      SettingChange(
        pointer: pointer,
        kind: added.isEmpty ? ChangeKind.unchanged : ChangeKind.added,
        existing: existing,
        patch: added.isEmpty ? null : added,
      ),
    );
    return out;
  }
  if (deepEquals(existing, patch)) {
    changes.add(
      SettingChange(
        pointer: pointer,
        kind: ChangeKind.unchanged,
        existing: existing,
      ),
    );
    return existing;
  }
  final replaced = replace.contains(pointer);
  changes.add(
    SettingChange(
      pointer: pointer,
      kind: ChangeKind.conflict,
      existing: existing,
      patch: patch,
      replaced: replaced,
    ),
  );
  return replaced ? patch : existing;
}

String _escape(String key) => key.replaceAll('~', '~0').replaceAll('/', '~1');

/// JSON 값(Map, List, 스칼라)의 깊은 비교.
bool deepEquals(Object? a, Object? b) {
  if (a is Map && b is Map) {
    if (a.length != b.length) return false;
    for (final k in a.keys) {
      if (!b.containsKey(k) || !deepEquals(a[k], b[k])) return false;
    }
    return true;
  }
  if (a is List && b is List) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (!deepEquals(a[i], b[i])) return false;
    }
    return true;
  }
  return a == b;
}

/// 기존 설정 파일에 패치를 적용했을 때의 결과(쓰지 않는 dry-run).
final class SettingsDiff {
  final List<SettingChange> changes;

  /// 적용 후 파일 내용(2칸 들여쓰기, 끝에 줄바꿈).
  final String mergedJson;

  /// 기존 파일에 주석이 있어서, 다시 쓰면 사라진다.
  final bool commentsWillBeLost;

  /// 기존 settings.json이 있었는지.
  final bool existingFile;

  const SettingsDiff({
    required this.changes,
    required this.mergedJson,
    required this.commentsWillBeLost,
    required this.existingFile,
  });

  List<SettingChange> get added => [
    for (final c in changes)
      if (c.kind == ChangeKind.added) c,
  ];

  List<SettingChange> get unchanged => [
    for (final c in changes)
      if (c.kind == ChangeKind.unchanged) c,
  ];

  List<SettingChange> get conflicts => [
    for (final c in changes)
      if (c.kind == ChangeKind.conflict) c,
  ];

  Map<String, Object?> toJson() => {
    'changes': [for (final c in changes) c.toJson()],
    'mergedJson': mergedJson,
    'commentsWillBeLost': commentsWillBeLost,
    'existingFile': existingFile,
    'hasChanges': hasChanges,
  };

  /// 파일에 실제로 써야 할 변화가 있는지(추가되었거나 교체된 충돌이 있는지).
  bool get hasChanges => changes.any(
    (c) =>
        c.kind == ChangeKind.added ||
        (c.kind == ChangeKind.conflict && c.replaced),
  );
}

/// [existingText](없으면 새 파일)에 [patch]를 병합한 diff를 만든다. 파일은 건드리지 않는다.
Result<SettingsDiff> computeSettingsDiff({
  String? existingText,
  required Map<String, Object?> patch,
  Set<String> replaceConflicts = const {},
}) {
  var existing = <String, Object?>{};
  var hadComments = false;
  if (existingText != null) {
    final parsed = parseJsonc(existingText);
    if (parsed is Err<JsoncDocument>) return Err(parsed.error);
    final doc = (parsed as Ok<JsoncDocument>).value;
    hadComments = doc.hadComments;
    final value = doc.value;
    if (value is Map<String, Object?>) {
      existing = value;
    } else if (value != null) {
      return const Err(EngineError('settings.json의 최상위 값이 객체({})가 아닙니다'));
    }
  }

  final result = mergeSettings(
    existing,
    patch,
    replaceConflicts: replaceConflicts,
  );
  return Ok(
    SettingsDiff(
      changes: result.changes,
      mergedJson:
          '${const JsonEncoder.withIndent('  ').convert(result.merged)}\n',
      commentsWillBeLost: hadComments,
      existingFile: existingText != null,
    ),
  );
}
