/// 실패 정보. [line]은 규칙 파일처럼 줄 번호가 의미 있을 때만 채운다(1부터 시작).
final class EngineError {
  final String message;
  final int? line;

  const EngineError(this.message, {this.line});

  @override
  String toString() => line == null ? message : '줄 $line: $message';
}

/// 예외 대신 성공/실패를 값으로 돌려주는 타입.
///
/// Dart 3의 `sealed class`는 하위 클래스가 같은 라이브러리에만 있다고 컴파일러에게
/// 알려 주므로, `switch`에서 [Ok]와 [Err]를 모두 처리했는지 검사해 준다.
sealed class Result<T> {
  const Result();

  bool get isOk => this is Ok<T>;

  T? get valueOrNull => switch (this) {
    Ok<T>(:final value) => value,
    Err<T>() => null,
  };

  EngineError? get errorOrNull => switch (this) {
    Ok<T>() => null,
    Err<T>(:final error) => error,
  };
}

final class Ok<T> extends Result<T> {
  final T value;

  const Ok(this.value);
}

final class Err<T> extends Result<T> {
  final EngineError error;

  const Err(this.error);
}
