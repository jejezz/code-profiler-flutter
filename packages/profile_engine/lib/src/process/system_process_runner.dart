import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'process_runner.dart';

const _utf8 = Utf8Decoder(allowMalformed: true);

/// `dart:io`의 [Process]로 실제 프로세스를 실행하는 구현. `Process`를 직접 부르는
/// 코드는 이 파일에만 둔다.
final class SystemProcessRunner implements ProcessRunner {
  const SystemProcessRunner();

  @override
  Future<ProcessOutput> run(
    String executable,
    List<String> args, {
    Duration? timeout,
    bool runInShell = false,
  }) async {
    final Process process;
    try {
      process = await Process.start(executable, args, runInShell: runInShell);
    } on ProcessException catch (e) {
      return ProcessOutput(
        exitCode: -1,
        startError: _startError(executable, e),
      );
    }
    // 표준 입력을 닫아 두어야 입력을 기다리며 멈추는 프로그램이 없다.
    unawaited(process.stdin.close().catchError((Object _) {}));

    final stdout = process.stdout.transform(_utf8).join();
    final stderr = process.stderr.transform(_utf8).join();
    try {
      final code = timeout == null
          ? await process.exitCode
          : await process.exitCode.timeout(timeout);
      return ProcessOutput(
        exitCode: code,
        stdout: await stdout,
        stderr: await stderr,
      );
    } on TimeoutException {
      process.kill();
      return const ProcessOutput(exitCode: -1, timedOut: true);
    }
  }

  @override
  Stream<ProcessEvent> start(
    String executable,
    List<String> args, {
    bool runInShell = false,
  }) {
    Process? process;
    final controller = StreamController<ProcessEvent>(
      onCancel: () => process?.kill(),
    );

    Future<void> pump() async {
      try {
        process = await Process.start(executable, args, runInShell: runInShell);
      } on ProcessException catch (e) {
        controller
          ..add(OutputLine(_startError(executable, e), isError: true))
          ..add(const ProcessExited(-1));
        await controller.close();
        return;
      }
      final p = process!;
      unawaited(p.stdin.close().catchError((Object _) {}));

      Future<void> forward(Stream<List<int>> s, {required bool isError}) {
        return s.transform(_utf8).transform(const LineSplitter()).forEach((
          line,
        ) {
          if (!controller.isClosed) {
            controller.add(OutputLine(line, isError: isError));
          }
        });
      }

      await Future.wait([
        forward(p.stdout, isError: false),
        forward(p.stderr, isError: true),
      ]);
      final code = await p.exitCode;
      if (!controller.isClosed) {
        controller.add(ProcessExited(code));
        await controller.close();
      }
    }

    unawaited(pump());
    return controller.stream;
  }
}

String _startError(String executable, ProcessException e) =>
    '$executable 을(를) 실행하지 못했습니다: ${e.message}';
