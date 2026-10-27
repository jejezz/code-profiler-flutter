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
/// Windows의 `code`는 `code.cmd`라서 셸을 거쳐야 한다. 셸을 거칠 때는 인자 속
/// 셸 특수문자가 해석되지 않도록, 그런 문자가 든 인자를 거부한다.
class VsCodeCli {
  final ProcessRunner _runner;

  /// `code` 실행 파일 경로. 사용자가 설정에서 바꿀 수 있다.
  final String codePath;
  final bool _runInShell;

  VsCodeCli(this._runner, {this.codePath = 'code', bool? runInShell})
    : _runInShell = runInShell ?? Platform.isWindows;

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
    if (!_runInShell) return null;
    for (final a in args) {
      if (_shellMeta.any(a.contains)) {
        return EngineError("셸 특수문자가 들어 있어 VS Code에 넘길 수 없습니다: '$a'");
      }
    }
    return null;
  }
}
