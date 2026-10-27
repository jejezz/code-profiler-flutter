import 'dart:convert';
import 'dart:io';

/// JSON 파일 하나를 안전하게 읽고 쓴다.
///
/// - 쓰기는 같은 폴더의 임시 파일에 쓴 뒤 rename으로 교체한다(쓰다 중단돼도 원본이 남는다).
/// - 쓰기는 한 번에 하나씩 차례로 실행한다.
/// - 내용이 JSON이 아니면 `.corrupt-<시각>`으로 옮겨 두고 "없음"으로 취급한다. 다음 저장이
///   손상된 파일을 덮어써서 복구할 수단을 잃는 일을 막는다.
class JsonFileStore {
  JsonFileStore(this.file);

  final File file;
  Future<void> _writes = Future.value();

  /// 파일이 없거나 손상됐으면 null.
  Future<Object?> read() async {
    final String text;
    try {
      if (!await file.exists()) return null;
      text = await file.readAsString();
    } on FileSystemException {
      return null;
    }
    try {
      return jsonDecode(text);
    } on FormatException {
      final stamp = DateTime.now().millisecondsSinceEpoch;
      try {
        await file.rename('${file.path}.corrupt-$stamp');
      } on FileSystemException {
        // 옮기지 못해도 읽기는 계속 "없음"으로 처리한다.
      }
      return null;
    }
  }

  Future<void> write(Object json) {
    final next = _writes.then((_) async {
      await file.parent.create(recursive: true);
      final temp = File('${file.path}.tmp');
      await temp.writeAsString(
        '${const JsonEncoder.withIndent('  ').convert(json)}\n',
        flush: true,
      );
      await temp.rename(file.path);
    });
    // 한 번의 실패가 뒤의 쓰기를 막지 않도록 체인에는 오류를 남기지 않는다.
    _writes = next.catchError((Object _) {});
    return next;
  }
}
