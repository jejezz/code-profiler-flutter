/// 루트 기준 상대 경로(구분자 `/`)에 대한 최소 glob.
///
/// 지원: `*`(`/` 제외 임의 문자), `?`(한 글자), `**/`(0개 이상의 디렉터리),
/// `**`(`/` 포함 임의 문자). 대소문자를 구분한다. 중괄호·문자 클래스는 지원하지 않는다.
final class Glob {
  final String pattern;
  final RegExp _regExp;

  Glob(this.pattern) : _regExp = RegExp(_toRegExp(pattern));

  bool matches(String relativePath) => _regExp.hasMatch(relativePath);
}

String _toRegExp(String glob) {
  final out = StringBuffer('^');
  var i = 0;
  while (i < glob.length) {
    final c = glob[i];
    if (c == '*') {
      if (i + 1 < glob.length && glob[i + 1] == '*') {
        if (i + 2 < glob.length && glob[i + 2] == '/') {
          out.write('(?:.*/)?');
          i += 3;
        } else {
          out.write('.*');
          i += 2;
        }
      } else {
        out.write('[^/]*');
        i++;
      }
    } else if (c == '?') {
      out.write('[^/]');
      i++;
    } else {
      out.write(RegExp.escape(c));
      i++;
    }
  }
  out.write(r'$');
  return out.toString();
}
