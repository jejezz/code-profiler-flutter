import 'dart:io';

import '../rules/rules_model.dart';

/// 폴더 스캔 결과. 경로는 모두 루트 기준 상대 경로이고 구분자는 `/`다.
final class ScanSnapshot {
  final String root;

  /// 스캔한 파일. skipDirs 안의 파일은 들어 있지 않다.
  final List<String> files;

  /// 발견한 디렉터리. skipDirs는 들어가지 않지만 존재 여부는 여기에 남긴다.
  final List<String> dirs;

  /// 건너뛴 skipDirs의 이름(중복 없음, 정렬됨).
  final List<String> skippedDirNames;

  /// maxFiles 상한에 걸려 스캔을 멈췄는지.
  final bool truncated;

  const ScanSnapshot({
    required this.root,
    required this.files,
    required this.dirs,
    required this.skippedDirNames,
    required this.truncated,
  });
}

/// [root]를 너비 우선으로 훑는다.
///
/// - 심볼릭 링크는 따라가지 않고 무시한다(순환 방지).
/// - 깊이 [ScanConfig.maxDepth]보다 깊은 디렉터리에는 들어가지 않는다. 파일 경로에
///   들어 있는 디렉터리 단계 수가 maxDepth 이하인 파일만 스캔한다.
/// - 너비 우선이라 파일 수 상한에 걸려도 루트에 가까운 표식 파일부터 확보된다.
/// - 읽을 수 없는 디렉터리는 건너뛴다.
ScanSnapshot scanTree(String root, ScanConfig config) {
  final skip = config.skipDirs.toSet();
  final files = <String>[];
  final dirs = <String>[];
  final skipped = <String>{};
  var truncated = false;

  var level = <String>[''];
  scan:
  for (var depth = 0; depth <= config.maxDepth && level.isNotEmpty; depth++) {
    final next = <String>[];
    for (final rel in level) {
      final List<FileSystemEntity> entries;
      try {
        entries = Directory(rel.isEmpty ? root : '$root/$rel')
            .listSync(followLinks: false);
      } on FileSystemException {
        continue;
      }
      entries.sort((a, b) => a.path.compareTo(b.path));
      for (final entry in entries) {
        if (entry is Link) continue;
        final name = _baseName(entry.path);
        final childRel = rel.isEmpty ? name : '$rel/$name';
        if (entry is Directory) {
          dirs.add(childRel);
          if (skip.contains(name)) {
            skipped.add(name);
          } else {
            next.add(childRel);
          }
        } else if (entry is File) {
          if (files.length >= config.maxFiles) {
            truncated = true;
            break scan;
          }
          files.add(childRel);
        }
      }
    }
    level = next;
  }

  return ScanSnapshot(
    root: root,
    files: files,
    dirs: dirs,
    skippedDirNames: skipped.toList()..sort(),
    truncated: truncated,
  );
}

String _baseName(String path) =>
    path.substring(path.lastIndexOf(RegExp(r'[\\/]')) + 1);
