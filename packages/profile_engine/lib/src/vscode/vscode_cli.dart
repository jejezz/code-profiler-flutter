import 'dart:io';

import '../model/project_location.dart';
import '../process/process_runner.dart';
import '../result.dart';

/// 확장 설치 진행 상황.
sealed class InstallEvent {
  final String extensionId;

  const InstallEvent(this.extensionId);
}

/// 이미 설치되어 있어 건너뜀.
final class InstallSkipped extends InstallEvent {
  const InstallSkipped(super.extensionId);
}

final class InstallStarted extends InstallEvent {
  const InstallStarted(super.extensionId);
}

final class InstallLog extends InstallEvent {
  final String line;
  final bool isError;

  const InstallLog(super.extensionId, this.line, {this.isError = false});
}

final class InstallFinished extends InstallEvent {
  final bool success;
  final int exitCode;

  const InstallFinished(
    super.extensionId, {
    required this.success,
    required this.exitCode,
  });
}

/// VS Code CLI(`code`) 래퍼. 프로필 생성·확장 설치·열기는 이 CLI로만 한다.
///
/// Windows의 `code`는 `code.cmd`(배치 파일)다. `runInShell: true`로 실행하면 Dart가
/// 공백이 든 경로와 인자를 따옴표로 감싸고, `cmd /c`가 따옴표가 여러 개인 명령줄의 바깥
/// 따옴표를 벗겨 버려 "경로에 공백이 있는 설치 + 공백이 든 프로필 이름" 조합이 깨진다.
/// 그래서 셸 없이 직접 실행한다(Windows가 배치 파일은 스스로 `cmd`로 실행한다).
///
/// 배치 파일은 어느 쪽이든 `cmd`가 인자를 해석하므로, 인자 속 셸 특수문자(`&`, `|` 등)를
/// 거부한다.
class VsCodeCli {
  final ProcessRunner _runner;

  /// `code` 실행 파일 경로. 사용자가 설정에서 바꿀 수 있다.
  final String codePath;
  final bool _runInShell;
  final bool _isWindows;

  /// [createProfile]이 프로필이 생겼는지 확인하는 간격과 최대 대기 시간.
  final Duration profilePollInterval;
  final Duration profileTimeout;
  final Future<void> Function(Duration) _wait;

  /// [runInShell]은 기본값 false다(위 설명). [isWindows]와 [wait](대기 함수)는 테스트에서
  /// 바꿀 수 있다.
  VsCodeCli(
    this._runner, {
    this.codePath = 'code',
    bool? runInShell,
    bool? isWindows,
    this.profilePollInterval = const Duration(seconds: 1),
    this.profileTimeout = const Duration(seconds: 60),
    Future<void> Function(Duration)? wait,
  }) : _runInShell = runInShell ?? false,
       _isWindows = isWindows ?? Platform.isWindows,
       _wait = wait ?? Future<void>.delayed;

  /// 인자가 `cmd`에 해석될 수 있는 실행 방식인지(셸을 거치거나 Windows 배치 파일).
  bool get _argsReachCmd =>
      _runInShell ||
      (_isWindows &&
          RegExp(r'\.(cmd|bat)$', caseSensitive: false).hasMatch(codePath));

  static const _shellMeta = [
    '&',
    '|',
    '<',
    '>',
    '^',
    '%',
    '"',
    '`',
    '\n',
    '\r',
  ];

  /// `code --version`의 첫 줄(버전 번호).
  Future<Result<String>> version() async {
    final out = await _run(['--version'], const Duration(seconds: 15));
    if (!out.ok) {
      return Err(EngineError('VS Code 버전을 확인하지 못했습니다: ${out.failureReason}'));
    }
    final first = out.stdout
        .split('\n')
        .map((l) => l.trim())
        .firstWhere((l) => l.isNotEmpty, orElse: () => '');
    return first.isEmpty
        ? const Err(EngineError('VS Code가 버전을 출력하지 않았습니다'))
        : Ok(first);
  }

  /// 프로필에 설치된 확장 ID 목록(소문자).
  Future<Result<List<String>>> listExtensions(String profile) async {
    final bad = _checkArgs([profile]);
    if (bad != null) return Err(bad);
    final out = await _run([
      '--profile',
      profile,
      '--list-extensions',
    ], const Duration(seconds: 60));
    if (!out.ok) {
      return Err(EngineError('확장 목록을 읽지 못했습니다: ${out.failureReason}'));
    }
    return Ok([
      for (final l in out.stdout.split('\n'))
        if (l.trim().isNotEmpty) l.trim().toLowerCase(),
    ]);
  }

  /// [profile]이 VS Code에 이미 있는지.
  ///
  /// `--list-extensions`는 없는 프로필에 `Profile '<이름>' not found.`로 실패하므로, 성공하면
  /// 있는 것으로 본다. 다른 이유로 실패해도 false이고, 그 경우 [createProfile]이 같은 원인을
  /// 오류로 돌려준다.
  Future<bool> profileExists(String profile) async =>
      (await listExtensions(profile)).isOk;

  /// 없는 프로필을 만든다.
  ///
  /// VS Code CLI에는 프로필 생성 명령이 없다. **없는 이름으로 `code --profile <이름> <폴더>`를
  /// 실행하면 빈 프로필이 만들어지고 그 폴더가 그 프로필로 열린다.** 그래서 [location]을
  /// 그 프로필로 연 뒤, [profileTimeout] 안에 `--list-extensions`가 성공할 때까지
  /// [profilePollInterval]마다 확인한다. 확장 설치는 프로필이 생긴 뒤에야 가능하다.
  Future<Result<void>> createProfile(
    String profile,
    ProjectLocation location,
  ) async {
    final opened = await open(profile, location);
    if (opened is Err<void>) return opened;

    var waited = Duration.zero;
    while (waited < profileTimeout) {
      await _wait(profilePollInterval);
      waited += profilePollInterval;
      if (await profileExists(profile)) return const Ok(null);
    }
    return Err(
      EngineError(
        "프로필 '$profile'이(가) 만들어졌는지 ${profileTimeout.inSeconds}초 안에 확인하지 못했습니다. "
        'VS Code가 시작 중이면 잠시 뒤 다시 시도하세요',
      ),
    );
  }

  /// 확장 하나를 설치한다. 출력을 줄 단위로 흘리고 마지막에 [ProcessExited]가 온다.
  Stream<ProcessEvent> installExtension(String profile, String extensionId) {
    final bad = _checkArgs([profile, extensionId]);
    if (bad != null) {
      return Stream.fromIterable([
        OutputLine(bad.message, isError: true),
        const ProcessExited(-1),
      ]);
    }
    return _runner.start(codePath, [
      '--profile',
      profile,
      '--install-extension',
      extensionId,
    ], runInShell: _runInShell);
  }

  /// [extensionIds]를 차례로 설치한다. 이미 설치된 확장은 건너뛴다.
  /// 확장 목록을 읽지 못하면 모두 설치를 시도한다(건너뛰기는 최적화일 뿐이다).
  Stream<InstallEvent> installExtensions(
    String profile,
    List<String> extensionIds,
  ) async* {
    final listed = await listExtensions(profile);
    final installed = {...?listed.valueOrNull};
    for (final id in extensionIds) {
      if (installed.contains(id.toLowerCase())) {
        yield InstallSkipped(id);
        continue;
      }
      yield InstallStarted(id);
      var exitCode = -1;
      await for (final e in installExtension(profile, id)) {
        switch (e) {
          case OutputLine(:final line, :final isError):
            yield InstallLog(id, line, isError: isError);
          case ProcessExited(exitCode: final code):
            exitCode = code;
        }
      }
      yield InstallFinished(id, success: exitCode == 0, exitCode: exitCode);
    }
  }

  /// [location]을 [profile]로 연다. 로컬은 `code --profile <p> <path>`, SSH는
  /// `code --profile <p> --remote ssh-remote+<host> <path>`.
  Future<Result<void>> open(String profile, ProjectLocation location) async {
    final args = switch (location) {
      LocalLocation(:final path) => ['--profile', profile, path],
      SshLocation(:final host, :final path) => [
        '--profile',
        profile,
        '--remote',
        'ssh-remote+$host',
        path,
      ],
    };
    final bad = _checkArgs(args);
    if (bad != null) return Err(bad);
    final out = await _run(args, const Duration(seconds: 30));
    if (!out.ok) {
      return Err(EngineError('VS Code를 열지 못했습니다: ${out.failureReason}'));
    }
    return const Ok(null);
  }

  Future<ProcessOutput> _run(List<String> args, Duration timeout) =>
      _runner.run(codePath, args, timeout: timeout, runInShell: _runInShell);

  EngineError? _checkArgs(List<String> args) {
    if (!_argsReachCmd) return null;
    for (final a in args) {
      if (_shellMeta.any(a.contains)) {
        return EngineError("셸 특수문자가 들어 있어 VS Code에 넘길 수 없습니다: '$a'");
      }
    }
    return null;
  }
}
