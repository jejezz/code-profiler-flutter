import 'package:profile_engine/profile_engine.dart';
import 'package:test/test.dart';

JsoncDocument _ok(String s) {
  final r = parseJsonc(s);
  expect(r, isA<Ok<JsoncDocument>>(), reason: '${r.errorOrNull}');
  return r.valueOrNull!;
}

void main() {
  test('plain JSON has no comments', () {
    final d = _ok('{"a": 1, "b": [true, null]}');
    expect(d.value, {
      'a': 1,
      'b': [true, null],
    });
    expect(d.hadComments, isFalse);
  });

  test('line comment', () {
    final d = _ok('{\n  // editor font\n  "a": 1 // trailing\n}\n');
    expect(d.value, {'a': 1});
    expect(d.hadComments, isTrue);
  });

  test('block comment, including across lines', () {
    final d = _ok('{ /* one */ "a": /* two\nlines */ 2 }');
    expect(d.value, {'a': 2});
    expect(d.hadComments, isTrue);
  });

  test('// and /* inside strings are not comments', () {
    final d = _ok(r'{"url": "http://x.y/*z*/", "p": "a//b"}');
    expect(d.value, {'url': 'http://x.y/*z*/', 'p': 'a//b'});
    expect(d.hadComments, isFalse);
  });

  test('trailing commas in objects and arrays', () {
    final d = _ok('{"a": [1, 2,], "b": {"c": 1,},}');
    expect(d.value, {
      'a': [1, 2],
      'b': {'c': 1},
    });
  });

  test('trailing comma followed by a comment before the bracket', () {
    final d = _ok('{"a": [1, // one\n 2, /* two */ ], }');
    expect(d.value, {
      'a': [1, 2],
    });
  });

  test('a comma inside a string before a bracket is kept', () {
    expect(_ok(r'{"a": "x,}"}').value, {'a': 'x,}'});
  });

  test('escapes: escaped quote and trailing backslash before a comment', () {
    final d = _ok('{"a": "say \\"//hi\\"", "b": "c:\\\\" // comment\n}');
    expect(d.value, {'a': 'say "//hi"', 'b': r'c:\'});
    expect(d.hadComments, isTrue);
  });

  test('BOM is ignored', () {
    expect(_ok('\uFEFF{"a": 1}').value, {'a': 1});
  });

  test('empty and comment-only files give a null value', () {
    expect(_ok('').value, isNull);
    expect(_ok('  \n').value, isNull);
    final d = _ok('// nothing here\n');
    expect(d.value, isNull);
    expect(d.hadComments, isTrue);
  });

  test('unterminated block comment reports its start line', () {
    final r = parseJsonc('{\n  "a": 1 /* never closed\n}');
    expect(r.errorOrNull!.line, 2);
    expect(r.errorOrNull!.message, contains('블록 주석'));
  });

  test('syntax error keeps original line numbers despite comments', () {
    final r = parseJsonc('{\n  // c\n  /* x\n y */\n  "a": oops\n}');
    expect(r, isA<Err<JsoncDocument>>());
    expect(r.errorOrNull!.line, 5);
  });
}
