import 'dart:io';

import 'package:profile_engine/profile_engine.dart';
import 'package:test/test.dart';

import 'fixtures/fixture.dart';

void main() {
  const runner = SystemProcessRunner();
  final dart = Platform.resolvedExecutable;

  String script(String body) {
    final fx = createFixture({'s.dart': "import 'dart:io';\n$body"});
    return '${fx.path}/s.dart';
  }

  test('run: captures stdout, stderr and the exit code', () async {
    final s = script(
      "void main() { print('out'); stderr.writeln('err'); exit(3); }",
    );
    final r = await runner.run(dart, [s]);
    expect(r.exitCode, 3);
    expect(r.stdout.trim(), 'out');
    expect(r.stderr.trim(), 'err');
    expect(r.ok, isFalse);
  });

  test('run: decodes UTF-8 output', () async {
    final s = script("void main() { stdout.write('한글 ✓'); }");
    final r = await runner.run(dart, [s]);
    expect(r.stdout, '한글 ✓');
    expect(r.ok, isTrue);
  });

  test('run: a missing executable is a startError, not an exception', () async {
    final r = await runner.run('definitely-not-a-real-program-xyz', []);
    expect(r.exitCode, -1);
    expect(r.startError, contains('definitely-not-a-real-program-xyz'));
    expect(r.ok, isFalse);
    expect(r.failureReason, contains('실행하지 못했습니다'));
  });

  test('run: a timeout stops the process and sets timedOut', () async {
    final s = script(
      'Future<void> main() async { await Future<void>.delayed(const Duration(seconds: 30)); }',
    );
    final watch = Stopwatch()..start();
    final r = await runner.run(dart, [
      s,
    ], timeout: const Duration(milliseconds: 800));
    expect(r.timedOut, isTrue);
    expect(r.ok, isFalse);
    expect(watch.elapsed, lessThan(const Duration(seconds: 15)));
  });

  test('run: stdin is closed so programs that read it do not hang', () async {
    final s = script("void main() { print(stdin.readLineSync() ?? 'eof'); }");
    final r = await runner.run(dart, [s], timeout: const Duration(seconds: 20));
    expect(r.stdout.trim(), 'eof');
  });

  test('start: streams lines and ends with ProcessExited', () async {
    final s = script(
      "void main() { print('one'); stderr.writeln('two'); print('three'); exit(2); }",
    );
    final events = await runner.start(dart, [s]).toList();
    expect(events.last, isA<ProcessExited>());
    expect((events.last as ProcessExited).exitCode, 2);
    final lines = events.whereType<OutputLine>().toList();
    expect(lines.where((l) => !l.isError).map((l) => l.line), ['one', 'three']);
    expect(lines.where((l) => l.isError).map((l) => l.line), ['two']);
  });

  test(
    'start: a missing executable yields an error line and exit -1',
    () async {
      final events = await runner
          .start('definitely-not-a-real-program-xyz', [])
          .toList();
      expect(events.first, isA<OutputLine>());
      expect((events.first as OutputLine).isError, isTrue);
      expect((events.last as ProcessExited).exitCode, -1);
    },
  );

  test('start: cancelling the subscription kills the process', () async {
    final s = script(
      "Future<void> main() async { print('ready'); await Future<void>.delayed(const Duration(seconds: 60)); }",
    );
    final watch = Stopwatch()..start();
    await for (final e in runner.start(dart, [s])) {
      if (e is OutputLine && e.line == 'ready') break;
    }
    expect(watch.elapsed, lessThan(const Duration(seconds: 30)));
  });
}
