import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'process_runner.dart';

/// 프로세스 출력 바이트를 문자열로 바꾼다.
///
/// 대부분의 도구(`code` 등 Node 프로그램)는 UTF-8로 쓰지만, Windows의 `cmd`는 오류
/// 메시지를 시스템 코드 페이지(예: 한국어 cp949)로 쓴다. UTF-8로 읽다 깨지면 [fallback]
/// (기본: 시스템 인코딩)으로 다시 읽어, 한글 오류 메시지가 깨져 보이지 않게 한다.
String decodeProcessOutput(List<int> bytes, {Encoding? fallback}) {
  try {
    return utf8.decode(bytes);
  } on FormatException {
    try {
      return (fallback ?? systemEncoding).decode(bytes);
    } on FormatException {
      return utf8.decode(bytes, allowMalformed: true);
    }
  }
}

/// 바이트 스트림을 줄 단위 문자열로 바꾼다. 줄 경계(0x0A)는 UTF-8과 cp949 모두에서
/// 다른 글자의 일부가 될 수 없으므로, 바이트 단계에서 먼저 나눈 뒤 줄마다 디코딩한다.
Stream<String> _lines(Stream<List<int>> bytes) async* {
  var pending = <int>[];
  await for (final chunk in bytes) {
    for (final b in chunk) {
      if (b == 0x0A) {
        yield _line(pending);
        pending = <int>[];
      } else {
        pending.add(b);
      }
    }
  }
  if (pending.isNotEmpty) yield _line(pending);
}

String _line(List<int> bytes) {
  final end = bytes.isNotEmpty && bytes.last == 0x0D
      ? bytes.length - 1
      : bytes.length;
  return decodeProcessOutput(bytes.sublist(0, end));
}

Future<String> _collect(Stream<List<int>> bytes) async {
  final all = <int>[];
  await for (final chunk in bytes) {
    all.addAll(chunk);
  }
  return decodeProcessOutput(all);
}

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

    final stdout = _collect(process.stdout);
    final stderr = _collect(process.stderr);
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
        return _lines(s).forEach((line) {
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
