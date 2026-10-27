import 'dart:io';

import '../result.dart';
import 'merge.dart';

/// 쓰기 결과.
final class SettingsWriteResult {
  final SettingsDiff diff;

  /// 실제로 파일을 썼는지. 바뀔 것이 없으면 false.
  final bool written;

  /// 덮어쓰기 전에 만든 백업 경로(기존 파일이 없었거나 쓰지 않았으면 null).
  final String? backupPath;

  const SettingsWriteResult({
    required this.diff,
    required this.written,
    this.backupPath,
  });
}

File _settingsFile(String projectRoot) =>
    File('$projectRoot/.vscode/settings.json');

/// `<projectRoot>/.vscode/settings.json`에 [patch]를 적용했을 때의 diff를 만든다(쓰지 않음).
Future<Result<SettingsDiff>> diffSettingsFile(
  String projectRoot,
  Map<String, Object?> patch, {
  Set<String> replaceConflicts = const {},
}) async {
  final file = _settingsFile(projectRoot);
  final String? text;
  try {
    text = await file.exists() ? await file.readAsString() : null;
  } on FileSystemException catch (e) {
    return Err(EngineError('settings.json을 읽을 수 없습니다: ${e.message}'));
  }
  return computeSettingsDiff(
    existingText: text,
    patch: patch,
    replaceConflicts: replaceConflicts,
  );
}

/// 패치를 `.vscode/settings.json`에 쓴다.
///
/// 1. 기존 파일이 있으면 `settings.json.bak.<yyyyMMdd-HHmmss>`로 복사한다.
/// 2. 같은 폴더의 임시 파일에 쓴 뒤 rename으로 교체한다(쓰다가 중단돼도 원본이 깨지지 않음).
/// 3. `.vscode/` 폴더가 없으면 만든다.
///
/// 바뀔 것이 없으면 아무것도 쓰지 않는다. 호출하기 전에 [diffSettingsFile]로 사용자에게
/// diff를 보여주고 확인을 받아야 한다.
Future<Result<SettingsWriteResult>> applySettingsFile(
  String projectRoot,
  Map<String, Object?> patch, {
  Set<String> replaceConflicts = const {},
  DateTime? now,
}) async {
  final diffResult = await diffSettingsFile(
    projectRoot,
    patch,
    replaceConflicts: replaceConflicts,
  );
  if (diffResult is Err<SettingsDiff>) return Err(diffResult.error);
  final diff = (diffResult as Ok<SettingsDiff>).value;
  if (!diff.hasChanges) {
    return Ok(SettingsWriteResult(diff: diff, written: false));
  }

  final file = _settingsFile(projectRoot);
  final temp = File('${file.path}.tmp');
  try {
    await file.parent.create(recursive: true);
    String? backupPath;
    if (diff.existingFile) {
      backupPath = await _freeBackupPath(file.path, now ?? DateTime.now());
      await file.copy(backupPath);
    }
    await temp.writeAsString(diff.mergedJson, flush: true);
    await temp.rename(file.path);
    return Ok(
      SettingsWriteResult(diff: diff, written: true, backupPath: backupPath),
    );
  } on FileSystemException catch (e) {
    if (await temp.exists()) {
      try {
        await temp.delete();
      } on FileSystemException {
        // 임시 파일 정리 실패는 원래 오류보다 덜 중요하다.
      }
    }
    return Err(EngineError('settings.json을 쓰지 못했습니다: ${e.message}'));
  }
}

/// 같은 초에 두 번 쓰는 경우를 위해 이미 있는 이름이면 `-1`, `-2`를 붙인다.
Future<String> _freeBackupPath(String settingsPath, DateTime now) async {
  final base = '$settingsPath.bak.${_stamp(now)}';
  var candidate = base;
  for (var n = 1; await File(candidate).exists(); n++) {
    candidate = '$base-$n';
  }
  return candidate;
}

String _stamp(DateTime t) {
  String two(int v) => v.toString().padLeft(2, '0');
  return '${t.year.toString().padLeft(4, '0')}${two(t.month)}${two(t.day)}'
      '-${two(t.hour)}${two(t.minute)}${two(t.second)}';
}
