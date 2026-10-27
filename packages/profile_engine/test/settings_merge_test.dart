import 'dart:convert';

import 'package:profile_engine/profile_engine.dart';
import 'package:test/test.dart';

SettingChange _change(MergeResult r, String pointer) =>
    r.changes.singleWhere((c) => c.pointer == pointer);

void main() {
  group('table 4.2', () {
    test('Map + Map merges key by key, recursively', () {
      final r = mergeSettings(
        {
          'files.watcherExclude': {'**/a': true},
        },
        {
          'files.watcherExclude': {'**/b': true, '**/a': true},
        },
      );
      expect(r.merged, {
        'files.watcherExclude': {'**/a': true, '**/b': true},
      });
      expect(
        _change(r, '/files.watcherExclude/**~1a').kind,
        ChangeKind.unchanged,
      );
      expect(_change(r, '/files.watcherExclude/**~1b').kind, ChangeKind.added);
    });

    test('List + List keeps order and appends only missing items', () {
      final r = mergeSettings(
        {
          'xs': ['a', 'b'],
        },
        {
          'xs': ['b', 'c', 'c', 'a', 'd'],
        },
      );
      expect(r.merged['xs'], ['a', 'b', 'c', 'd']);
      final c = _change(r, '/xs');
      expect(c.kind, ChangeKind.added);
      expect(c.patch, ['c', 'd']);
    });

    test('List + List with nothing new is unchanged', () {
      final r = mergeSettings(
        {
          'xs': ['a'],
        },
        {
          'xs': ['a'],
        },
      );
      expect(_change(r, '/xs').kind, ChangeKind.unchanged);
    });

    test('list items are compared deeply', () {
      final r = mergeSettings(
        {
          'xs': [
            {'k': 1},
          ],
        },
        {
          'xs': [
            {'k': 1},
            {'k': 2},
          ],
        },
      );
      expect(r.merged['xs'], [
        {'k': 1},
        {'k': 2},
      ]);
    });

    test('scalar conflict keeps the existing value and is reported', () {
      final r = mergeSettings({'editor.tabSize': 4}, {'editor.tabSize': 2});
      expect(r.merged['editor.tabSize'], 4);
      final c = _change(r, '/editor.tabSize');
      expect(c.kind, ChangeKind.conflict);
      expect(c.existing, 4);
      expect(c.patch, 2);
      expect(c.replaced, isFalse);
    });

    test('equal scalars are unchanged, not conflicts', () {
      final r = mergeSettings({'a': 'x'}, {'a': 'x'});
      expect(_change(r, '/a').kind, ChangeKind.unchanged);
    });

    test('type mismatch is a conflict', () {
      final r = mergeSettings(
        {'a': 1},
        {
          'a': {'b': 2},
        },
      );
      expect(r.merged['a'], 1);
      expect(_change(r, '/a').kind, ChangeKind.conflict);

      final r2 = mergeSettings(
        {
          'a': ['x'],
        },
        {
          'a': {'b': 2},
        },
      );
      expect(_change(r2, '/a').kind, ChangeKind.conflict);
    });

    test('missing key is added with the patch value', () {
      final r = mergeSettings(
        {'a': 1},
        {
          'b': {'c': true},
        },
      );
      expect(r.merged, {
        'a': 1,
        'b': {'c': true},
      });
      expect(_change(r, '/b').kind, ChangeKind.added);
    });
  });

  group('conflict replacement', () {
    test('only the chosen pointers are replaced', () {
      final r = mergeSettings(
        {'a': 1, 'b': 1, 'c': 1},
        {'a': 2, 'b': 2, 'c': 1},
        replaceConflicts: {'/a'},
      );
      expect(r.merged, {'a': 2, 'b': 1, 'c': 1});
      expect(_change(r, '/a').replaced, isTrue);
      expect(_change(r, '/b').replaced, isFalse);
    });

    test('works on nested keys', () {
      final r = mergeSettings(
        {
          'm': {'k': 1},
        },
        {
          'm': {'k': 2},
        },
        replaceConflicts: {'/m/k'},
      );
      expect(r.merged, {
        'm': {'k': 2},
      });
    });
  });

  test('existing key order is kept and new keys go last', () {
    final r = mergeSettings({'z': 1, 'a': 1}, {'m': 1, 'a': 1});
    expect(r.merged.keys.toList(), ['z', 'a', 'm']);
  });

  test('pointers escape ~ and /', () {
    final r = mergeSettings({}, {'a/b~c': 1});
    expect(r.changes.single.pointer, '/a~1b~0c');
  });

  group('diff', () {
    test('no existing file: everything is added', () {
      final r = computeSettingsDiff(patch: {'a': 1});
      final d = r.valueOrNull!;
      expect(d.existingFile, isFalse);
      expect(d.added, hasLength(1));
      expect(d.hasChanges, isTrue);
      expect(d.commentsWillBeLost, isFalse);
      expect(d.mergedJson, '{\n  "a": 1\n}\n');
    });

    test('comments in the existing file raise the warning flag', () {
      final d = computeSettingsDiff(
        existingText: '{\n  // mine\n  "a": 1,\n}\n',
        patch: {'b': 2},
      ).valueOrNull!;
      expect(d.commentsWillBeLost, isTrue);
      expect(jsonDecode(d.mergedJson), {'a': 1, 'b': 2});
    });

    test('unresolved conflicts alone are not a change to write', () {
      final d = computeSettingsDiff(
        existingText: '{"a": 1}',
        patch: {'a': 2},
      ).valueOrNull!;
      expect(d.conflicts, hasLength(1));
      expect(d.hasChanges, isFalse);
      final replaced = computeSettingsDiff(
        existingText: '{"a": 1}',
        patch: {'a': 2},
        replaceConflicts: {'/a'},
      ).valueOrNull!;
      expect(replaced.hasChanges, isTrue);
      expect(jsonDecode(replaced.mergedJson), {'a': 2});
    });

    test('empty existing file is treated as {}', () {
      final d = computeSettingsDiff(
        existingText: '',
        patch: {'a': 1},
      ).valueOrNull!;
      expect(d.existingFile, isTrue);
      expect(d.added, hasLength(1));
    });

    test('invalid or non-object existing file is an Err', () {
      expect(
        computeSettingsDiff(existingText: '{oops', patch: {'a': 1}),
        isA<Err<SettingsDiff>>(),
      );
      expect(
        computeSettingsDiff(existingText: '[1, 2]', patch: {'a': 1}),
        isA<Err<SettingsDiff>>(),
      );
    });
  });
}
