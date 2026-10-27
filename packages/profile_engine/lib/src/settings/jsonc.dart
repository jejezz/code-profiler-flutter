import 'dart:convert';

import '../result.dart';

/// JSONC 파싱 결과.
final class JsoncDocument {
  /// 내용이 비어 있으면(공백·주석뿐) null.
  final Object? value;

  /// `//` 또는 `/* */` 주석이 하나라도 있었는지. 다시 쓰면 주석이 사라진다.
  final bool hadComments;

  const JsoncDocument(this.value, {required this.hadComments});
}

/// VS Code 설정 파일(JSONC)을 읽는다. 주석과 끝 쉼표를 허용한다.
///
/// 주석과 끝 쉼표를 공백으로 바꾼 문자열을 만들어 `jsonDecode`에 넘긴다. 줄바꿈은
/// 그대로 두므로 오류의 줄 번호는 원본과 같다. 문자열 안의 `//`는 주석이 아니다.
Result<JsoncDocument> parseJsonc(String source) {
  final text = source.startsWith('﻿') ? source.substring(1) : source;

  final stripped = _stripComments(text);
  if (stripped.errorLine != null) {
    return Err(EngineError('닫히지 않은 블록 주석입니다', line: stripped.errorLine));
  }
  final cleaned = _removeTrailingCommas(stripped.text);

  if (cleaned.trim().isEmpty) {
    return Ok(JsoncDocument(null, hadComments: stripped.hadComments));
  }
  try {
    return Ok(
      JsoncDocument(jsonDecode(cleaned), hadComments: stripped.hadComments),
    );
  } on FormatException catch (e) {
    final offset = e.offset;
    final line = offset == null
        ? null
        : '\n'
                  .allMatches(
                    cleaned.substring(0, offset.clamp(0, cleaned.length)),
                  )
                  .length +
              1;
    return Err(EngineError('JSON 문법 오류: ${e.message}', line: line));
  }
}

({String text, bool hadComments, int? errorLine}) _stripComments(String s) {
  final out = StringBuffer();
  var hadComments = false;
  var i = 0;
  while (i < s.length) {
    final c = s[i];
    if (c == '"') {
      i = _copyString(s, i, out);
    } else if (c == '/' && i + 1 < s.length && s[i + 1] == '/') {
      hadComments = true;
      while (i < s.length && s[i] != '\n') {
        out.write(s[i] == '\r' ? '\r' : ' ');
        i++;
      }
    } else if (c == '/' && i + 1 < s.length && s[i + 1] == '*') {
      hadComments = true;
      final startLine = '\n'.allMatches(s.substring(0, i)).length + 1;
      final end = s.indexOf('*/', i + 2);
      if (end < 0) return (text: '', hadComments: true, errorLine: startLine);
      for (var k = i; k < end + 2; k++) {
        out.write(s[k] == '\n' || s[k] == '\r' ? s[k] : ' ');
      }
      i = end + 2;
    } else {
      out.write(c);
      i++;
    }
  }
  return (text: out.toString(), hadComments: hadComments, errorLine: null);
}

String _removeTrailingCommas(String s) {
  final out = StringBuffer();
  var i = 0;
  while (i < s.length) {
    final c = s[i];
    if (c == '"') {
      i = _copyString(s, i, out);
    } else if (c == ',') {
      var j = i + 1;
      while (j < s.length && _isSpace(s[j])) {
        j++;
      }
      final trailing = j < s.length && (s[j] == ']' || s[j] == '}');
      out.write(trailing ? ' ' : ',');
      i++;
    } else {
      out.write(c);
      i++;
    }
  }
  return out.toString();
}

/// [start]의 여는 따옴표부터 닫는 따옴표까지(이스케이프 포함) [out]에 복사하고 다음 위치를 돌려준다.
int _copyString(String s, int start, StringBuffer out) {
  out.write('"');
  var i = start + 1;
  while (i < s.length) {
    final c = s[i];
    out.write(c);
    i++;
    if (c == r'\' && i < s.length) {
      out.write(s[i]);
      i++;
    } else if (c == '"') {
      break;
    }
  }
  return i;
}

bool _isSpace(String c) => c == ' ' || c == '\n' || c == '\r' || c == '\t';
