import 'dart:io';

import 'package:test/test.dart';

/// 임시 디렉터리에 가짜 프로젝트 트리를 만든다. 테스트가 끝나면 자동으로 지운다.
///
/// [files]의 키가 `/`로 끝나면 빈 디렉터리, 아니면 그 내용을 가진 파일이다.
Directory createFixture(Map<String, String> files) {
  final dir = Directory.systemTemp.createTempSync('profile_engine_fx');
  addTearDown(() => dir.deleteSync(recursive: true));
  files.forEach((rel, content) {
    if (rel.endsWith('/')) {
      Directory('${dir.path}/$rel').createSync(recursive: true);
    } else {
      File('${dir.path}/$rel')
        ..createSync(recursive: true)
        ..writeAsStringSync(content);
    }
  });
  return dir;
}
