/// 외부 프로세스 실행 결과.
final class ProcessOutput {
  final int exitCode;
  final String stdout;
  final String stderr;

  /// 시간 제한에 걸려 프로세스를 중단했는지.
  final bool timedOut;

  /// 실행 파일을 시작하지 못한 이유(없으면 null). 이때 [exitCode]는 -1이다.
  final String? startError;

  const ProcessOutput({
    required this.exitCode,
    this.stdout = '',
    this.stderr = '',
    this.timedOut = false,
    this.startError,
  });

  bool get ok => exitCode == 0 && !timedOut && startError == null;

  /// 사용자에게 보여줄 실패 사유 한 줄.
  String get failureReason {
    if (startError != null) return startError!;
    if (timedOut) return '시간 제한을 넘겨 중단했습니다';
    final text = (stderr.trim().isNotEmpty ? stderr : stdout).trim();
    return text.isEmpty ? '종료 코드 $exitCode' : text.split('\n').first.trim();
  }
}

/// [ProcessRunner.start]가 흘려보내는 이벤트.
///
/// `sealed class`는 하위 타입이 이 라이브러리에만 있다고 컴파일러에 알려, `switch`에서
/// 모든 경우를 처리했는지 검사해 준다.
sealed class ProcessEvent {
  const ProcessEvent();
}

/// 한 줄의 출력.
final class OutputLine extends ProcessEvent {
  final String line;
  final bool isError;

  const OutputLine(this.line, {this.isError = false});
}

/// 프로세스 종료. 스트림의 마지막 이벤트다.
final class ProcessExited extends ProcessEvent {
  final int exitCode;

  const ProcessExited(this.exitCode);
}

/// 외부 프로세스 실행 추상화. `code`, `ssh`, `scp` 호출은 모두 이 인터페이스를 거친다.
/// 테스트는 FakeProcessRunner로 대체한다.
abstract interface class ProcessRunner {
  /// 끝날 때까지 기다렸다가 결과를 돌려준다. 시작 실패와 시간 초과는 예외가 아니라
  /// [ProcessOutput]의 필드로 알린다.
  Future<ProcessOutput> run(
    String executable,
    List<String> args, {
    Duration? timeout,
    bool runInShell = false,
  });

  /// 진행 상황을 줄 단위로 흘려보낸다(확장 설치용). 마지막 이벤트는 [ProcessExited]다.
  /// 구독을 취소하면 프로세스를 중단한다.
  Stream<ProcessEvent> start(
    String executable,
    List<String> args, {
    bool runInShell = false,
  });
}
