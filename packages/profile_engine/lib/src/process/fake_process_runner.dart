import 'dart:async';

import 'process_runner.dart';

/// [FakeProcessRunner]가 기록한 호출 하나.
final class ProcessCall {
  final String executable;
  final List<String> args;
  final bool runInShell;
  final Duration? timeout;

  /// [ProcessRunner.start]로 호출했는지(false면 [ProcessRunner.run]).
  final bool streamed;

  const ProcessCall(
    this.executable,
    this.args, {
    required this.runInShell,
    this.timeout,
    required this.streamed,
  });

  @override
  String toString() => '$executable ${args.join(' ')}';
}

/// 테스트용 [ProcessRunner]. 호출을 기록하고 미리 정해 둔 응답을 돌려준다.
///
/// [on]으로 응답을 등록한다. 먼저 등록한 것이 먼저 맞는다. 맞는 응답이 없으면 종료 코드
/// 127과 안내 메시지를 돌려주므로, 빠뜨린 등록은 테스트 실패로 드러난다.
final class FakeProcessRunner implements ProcessRunner {
  final List<ProcessCall> calls = [];
  final List<_Stub> _stubs = [];

  /// 실행 파일과 인자가 [matches]를 만족하면 [output]을 돌려준다.
  /// [start]로 호출되면 [events]가 있으면 그것을, 없으면 [output]의 출력을 줄 단위로 흘린다.
  ///
  /// [outputs]를 주면 호출할 때마다 차례로 하나씩 돌려주고 마지막 응답을 반복한다
  /// (예: 처음 몇 번은 실패하다 성공하는 폴링).
  void on(
    bool Function(String executable, List<String> args) matches, {
    ProcessOutput output = const ProcessOutput(exitCode: 0),
    List<ProcessEvent>? events,
    List<ProcessOutput>? outputs,
  }) {
    _stubs.add(_Stub(matches, output, events, outputs));
  }

  /// 인자가 [prefix]로 시작하는 호출에 응답한다(실행 파일은 따지지 않는다).
  void onArgs(
    List<String> prefix, {
    ProcessOutput output = const ProcessOutput(exitCode: 0),
    List<ProcessEvent>? events,
    List<ProcessOutput>? outputs,
  }) {
    on(
      (exe, args) =>
          args.length >= prefix.length &&
          [for (var i = 0; i < prefix.length; i++) args[i] == prefix[i]]
              .every((b) => b),
      output: output,
      events: events,
      outputs: outputs,
    );
  }

  _Stub _find(String executable, List<String> args) {
    for (final s in _stubs) {
      if (s.matches(executable, args)) return s;
    }
    return _Stub(
      (_, _) => true,
      ProcessOutput(
        exitCode: 127,
        stderr:
            'FakeProcessRunner: no response for "$executable ${args.join(' ')}"',
      ),
      null,
      null,
    );
  }

  @override
  Future<ProcessOutput> run(
    String executable,
    List<String> args, {
    Duration? timeout,
    bool runInShell = false,
  }) async {
    calls.add(
      ProcessCall(
        executable,
        List.unmodifiable(args),
        runInShell: runInShell,
        timeout: timeout,
        streamed: false,
      ),
    );
    return _find(executable, args).nextOutput();
  }

  @override
  Stream<ProcessEvent> start(
    String executable,
    List<String> args, {
    bool runInShell = false,
  }) {
    calls.add(
      ProcessCall(
        executable,
        List.unmodifiable(args),
        runInShell: runInShell,
        streamed: true,
      ),
    );
    final stub = _find(executable, args);
    final events =
        stub.events ??
        [
          for (final l in stub.output.stdout.split('\n'))
            if (l.isNotEmpty) OutputLine(l),
          for (final l in stub.output.stderr.split('\n'))
            if (l.isNotEmpty) OutputLine(l, isError: true),
          ProcessExited(stub.output.exitCode),
        ];
    return Stream.fromIterable(events);
  }
}

final class _Stub {
  final bool Function(String, List<String>) matches;
  final ProcessOutput output;
  final List<ProcessEvent>? events;
  final List<ProcessOutput>? outputs;
  var _calls = 0;

  _Stub(this.matches, this.output, this.events, this.outputs);

  ProcessOutput nextOutput() {
    final list = outputs;
    if (list == null || list.isEmpty) return output;
    final i = _calls++;
    return list[i < list.length ? i : list.length - 1];
  }
}
