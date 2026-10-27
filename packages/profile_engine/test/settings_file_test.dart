import 'dart:convert';
import 'dart:io';

import 'package:profile_engine/profile_engine.dart';
import 'package:test/test.dart';

import 'fixtures/fixture.dart';

SettingsWriteResult _ok(Result<SettingsWriteResult> r) {
  expect(r, isA<Ok<SettingsWriteResult>>(), reason: '${r.errorOrNull}');
  return r.valueOrNull!;
}

List<String> _vscodeFiles(Directory root) => [
  for (final e in Directory('${root.path}/.vscode').listSync())
    e.path.split(RegExp(r'[\\/]')).last,
]..sort();

void main() {
  final now = DateTime(2026, 10, 27, 9, 5, 7);

  test('creates .vscode/settings.json when missing, no backup', () async {
    final fx = createFixture({'a.txt': ''});
    final r = _ok(await applySettingsFile(fx.path, {'a': 1}, now: now));
    expect(r.written, isTrue);
    expect(r.backupPath, isNull);
    expect(_vscodeFiles(fx), ['settings.json']);
    expect(
      jsonDecode(File('${fx.path}/.vscode/settings.json').readAsStringSync()),
      {'a': 1},
    );
  });

  test('backs up the existing file with a timestamp and merges', () async {
    final fx = createFixture({
      '.vscode/settings.json': '{\n  // keep\n  "a": 1,\n}\n',
    });
    final r = _ok(await applySettingsFile(fx.path, {'b': 2}, now: now));
    expect(r.written, isTrue);
    expect(r.diff.commentsWillBeLost, isTrue);
    expect(r.backupPath, endsWith('settings.json.bak.20261027-090507'));
    expect(
      File(r.backupPath!).readAsStringSync(),
      '{\n  // keep\n  "a": 1,\n}\n',
    );
    expect(
      jsonDecode(File('${fx.path}/.vscode/settings.json').readAsStringSync()),
      {'a': 1, 'b': 2},
    );
    expect(_vscodeFiles(fx), [
      'settings.json',
      'settings.json.bak.20261027-090507',
    ]);
  });

  test('two writes in the same second do not overwrite the backup', () async {
    final fx = createFixture({'.vscode/settings.json': '{"a": 1}'});
    _ok(await applySettingsFile(fx.path, {'b': 2}, now: now));
    final second = _ok(await applySettingsFile(fx.path, {'c': 3}, now: now));
    expect(second.backupPath, endsWith('20261027-090507-1'));
    expect(_vscodeFiles(fx), hasLength(3));
  });

  test('nothing to change: no write, no backup', () async {
    final fx = createFixture({'.vscode/settings.json': '{"a": 1}'});
    final r = _ok(await applySettingsFile(fx.path, {'a': 1}, now: now));
    expect(r.written, isFalse);
    expect(r.backupPath, isNull);
    expect(_vscodeFiles(fx), ['settings.json']);
  });

  test('kept conflicts alone do not rewrite the file', () async {
    final fx = createFixture({'.vscode/settings.json': '{"a": 1}'});
    final r = _ok(await applySettingsFile(fx.path, {'a': 2}, now: now));
    expect(r.written, isFalse);
    expect(r.diff.conflicts, hasLength(1));
  });

  test('chosen conflicts are replaced', () async {
    final fx = createFixture({'.vscode/settings.json': '{"a": 1}'});
    final r = _ok(
      await applySettingsFile(
        fx.path,
        {'a': 2},
        replaceConflicts: {'/a'},
        now: now,
      ),
    );
    expect(r.written, isTrue);
    expect(
      jsonDecode(File('${fx.path}/.vscode/settings.json').readAsStringSync()),
      {'a': 2},
    );
  });

  test('invalid existing file: Err and the file is untouched', () async {
    final fx = createFixture({'.vscode/settings.json': '{oops'});
    final r = await applySettingsFile(fx.path, {'a': 1}, now: now);
    expect(r, isA<Err<SettingsWriteResult>>());
    expect(
      File('${fx.path}/.vscode/settings.json').readAsStringSync(),
      '{oops',
    );
    expect(_vscodeFiles(fx), ['settings.json']);
  });

  test('no temp file is left behind after a write', () async {
    final fx = createFixture({'.vscode/settings.json': '{}'});
    _ok(await applySettingsFile(fx.path, {'a': 1}, now: now));
    expect(_vscodeFiles(fx).any((f) => f.endsWith('.tmp')), isFalse);
  });

  test('diffSettingsFile does not write', () async {
    final fx = createFixture({'a.txt': ''});
    final r = await diffSettingsFile(fx.path, {'a': 1});
    expect(r.valueOrNull!.added, hasLength(1));
    expect(Directory('${fx.path}/.vscode').existsSync(), isFalse);
  });
}
