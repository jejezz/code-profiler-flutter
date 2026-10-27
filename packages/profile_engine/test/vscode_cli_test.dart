import 'package:profile_engine/profile_engine.dart';
import 'package:test/test.dart';

VsCodeCli _cli(FakeProcessRunner fake, {bool runInShell = false}) =>
    VsCodeCli(fake, codePath: 'code', runInShell: runInShell);

void main() {
  group('version', () {
    test('returns the first line of --version', () async {
      final fake = FakeProcessRunner()
        ..onArgs(
          ['--version'],
          output: const ProcessOutput(
            exitCode: 0,
            stdout: '1.99.0\nabc123\nx64\n',
          ),
        );
      final r = await _cli(fake).version();
      expect(r.valueOrNull, '1.99.0');
      expect(fake.calls.single.args, ['--version']);
      expect(fake.calls.single.executable, 'code');
    });

    test('failure becomes an Err with the reason', () async {
      final fake = FakeProcessRunner()
        ..onArgs([
          '--version',
        ], output: const ProcessOutput(exitCode: 1, stderr: 'boom\n'));
      final r = await _cli(fake).version();
      expect(r.errorOrNull!.message, contains('boom'));
    });

    test('a missing executable is reported, not thrown', () async {
      final fake = FakeProcessRunner()
        ..onArgs(
          ['--version'],
          output: const ProcessOutput(
            exitCode: -1,
            startError: 'code 을(를) 실행하지 못했습니다',
          ),
        );
      expect(
        (await _cli(fake).version()).errorOrNull!.message,
        contains('실행하지 못했습니다'),
      );
    });
  });

  group('listExtensions', () {
    test('uses --profile and lowercases the ids', () async {
      final fake = FakeProcessRunner()
        ..onArgs(
          ['--profile', 'C++ AOSP', '--list-extensions'],
          output: const ProcessOutput(
            exitCode: 0,
            stdout:
                'llvm-vs-code-extensions.vscode-clangd\nMS-Python.python\n\n',
          ),
        );
      final r = await _cli(fake).listExtensions('C++ AOSP');
      expect(r.valueOrNull, [
        'llvm-vs-code-extensions.vscode-clangd',
        'ms-python.python',
      ]);
      expect(fake.calls.single.args, [
        '--profile',
        'C++ AOSP',
        '--list-extensions',
      ]);
    });

    test('failure is an Err', () async {
      final fake = FakeProcessRunner(); // 응답 없음 → 127
      expect((await _cli(fake).listExtensions('P')).isOk, isFalse);
    });
  });

  group('open', () {
    test('local: code --profile <p> <path>', () async {
      final fake = FakeProcessRunner()..onArgs(['--profile']);
      final r = await _cli(fake).open('Java', const LocalLocation('/work/app'));
      expect(r.isOk, isTrue);
      expect(fake.calls.single.args, ['--profile', 'Java', '/work/app']);
    });

    test('ssh: adds --remote ssh-remote+<host>', () async {
      final fake = FakeProcessRunner()..onArgs(['--profile']);
      await _cli(fake)
          .open('C++ AOSP', const SshLocation('devbox', '/srv/aosp/hal'));
      expect(fake.calls.single.args, [
        '--profile',
        'C++ AOSP',
        '--remote',
        'ssh-remote+devbox',
        '/srv/aosp/hal',
      ]);
    });

    test('a non-zero exit is an Err', () async {
      final fake = FakeProcessRunner()
        ..onArgs([
          '--profile',
        ], output: const ProcessOutput(exitCode: 1, stderr: 'no'));
      expect(
        (await _cli(fake).open('P', const LocalLocation('/x'))).isOk,
        isFalse,
      );
    });

    test('has a timeout', () async {
      final fake = FakeProcessRunner()..onArgs(['--profile']);
      await _cli(fake).open('P', const LocalLocation('/x'));
      expect(fake.calls.single.timeout, isNotNull);
    });
  });

  group('Windows (runInShell)', () {
    test('every call goes through the shell', () async {
      final fake = FakeProcessRunner()..onArgs(['--profile']);
      final cli = _cli(fake, runInShell: true);
      await cli.open('P', const LocalLocation(r'C:\work\app'));
      await cli.listExtensions('P');
      expect(fake.calls.map((c) => c.runInShell), [true, true]);
    });

    test('is off elsewhere', () async {
      final fake = FakeProcessRunner()..onArgs(['--profile']);
      await _cli(fake).open('P', const LocalLocation('/x'));
      expect(fake.calls.single.runInShell, isFalse);
    });

    test(
      'shell metacharacters in arguments are refused, nothing runs',
      () async {
        final fake = FakeProcessRunner()..onArgs(['--profile']);
        final cli = _cli(fake, runInShell: true);
        for (final bad in [
          r'C:\a&calc',
          r'C:\a|b',
          r'C:\%PATH%',
          'a"b',
          r'C:\a^b',
        ]) {
          final r = await cli.open('P', LocalLocation(bad));
          expect(r.errorOrNull!.message, contains('셸 특수문자'), reason: bad);
        }
        final r = await cli.listExtensions('Pro&file');
        expect(r.isOk, isFalse);
        expect(fake.calls, isEmpty);
      },
    );

    test('spaces and + are fine', () async {
      final fake = FakeProcessRunner()..onArgs(['--profile']);
      final r = await _cli(
        fake,
        runInShell: true,
      ).open('C++ AOSP', const LocalLocation(r'C:\My Work\app'));
      expect(r.isOk, isTrue);
    });

    test(
      'without a shell the metacharacters are harmless and allowed',
      () async {
        final fake = FakeProcessRunner()..onArgs(['--profile']);
        final r = await _cli(fake).open('P', const LocalLocation('/a&b'));
        expect(r.isOk, isTrue);
      },
    );
  });

  group('Windows batch file (code.cmd)', () {
    const codeCmd =
        r'C:\Users\me\AppData\Local\Programs\Microsoft VS Code\bin\code.cmd';

    VsCodeCli cli(
      FakeProcessRunner fake, {
      String path = codeCmd,
      bool windows = true,
    }) => VsCodeCli(fake, codePath: path, isWindows: windows);

    test(
      'runs without a shell, so spaces in the path and the profile survive',
      () async {
        final fake = FakeProcessRunner()..onArgs(['--profile']);
        final r = await cli(fake)
            .open('Web / Python', const LocalLocation(r'C:\My Work\app'));
        expect(r.isOk, isTrue);
        final call = fake.calls.single;
        expect(call.runInShell, isFalse);
        expect(call.executable, codeCmd);
        expect(call.args, ['--profile', 'Web / Python', r'C:\My Work\app']);
      },
    );

    test('list and install also skip the shell', () async {
      final fake = FakeProcessRunner()..onArgs(['--profile']);
      final c = cli(fake);
      await c.listExtensions('C++ AOSP');
      await c.installExtension('C++ AOSP', 'a.b').toList();
      expect(fake.calls.map((call) => call.runInShell), [false, false]);
    });

    test('cmd metacharacters are still refused for batch files', () async {
      final fake = FakeProcessRunner()..onArgs(['--profile']);
      final c = cli(fake);
      expect(
        (await c.open('P', const LocalLocation(r'C:\a&calc'))).isOk,
        isFalse,
      );
      expect((await c.listExtensions('P|Q')).isOk, isFalse);
      expect(fake.calls, isEmpty);
    });

    test('uppercase and .bat are batch files too', () async {
      final fake = FakeProcessRunner()..onArgs(['--profile']);
      for (final path in [
        r'C:\VS\bin\CODE.CMD',
        r'C:\VS\bin\code.bat',
        'code.cmd',
      ]) {
        final r = await cli(
          fake,
          path: path,
        ).open('P', const LocalLocation('a&b'));
        expect(r.isOk, isFalse, reason: path);
      }
    });

    test(
      'a real executable is not guarded, nor is any path off Windows',
      () async {
        final fake = FakeProcessRunner()..onArgs(['--profile']);
        final exe = await cli(
          fake,
          path: r'C:\VS\Code.exe',
        ).open('P', const LocalLocation('a&b'));
        expect(exe.isOk, isTrue);
        final posix = await cli(
          fake,
          path: '/opt/code.cmd',
          windows: false,
        ).open('P', const LocalLocation('a&b'));
        expect(posix.isOk, isTrue);
      },
    );
  });

  group('installExtensions', () {
    test('skips installed extensions, streams the rest', () async {
      final fake = FakeProcessRunner()
        ..onArgs([
          '--profile',
          'P',
          '--list-extensions',
        ], output: const ProcessOutput(exitCode: 0, stdout: 'a.installed\n'))
        ..onArgs(
          ['--profile', 'P', '--install-extension', 'b.new'],
          events: const [
            OutputLine('Installing extensions...'),
            OutputLine('Extension b.new v1.0 was successfully installed.'),
            ProcessExited(0),
          ],
        );
      final events = await _cli(fake)
          .installExtensions('P', ['A.Installed', 'b.new'])
          .toList();
      expect(events.map((e) => e.runtimeType), [
        InstallSkipped,
        InstallStarted,
        InstallLog,
        InstallLog,
        InstallFinished,
      ]);
      expect((events.first as InstallSkipped).extensionId, 'A.Installed');
      final done = events.last as InstallFinished;
      expect(done.success, isTrue);
      expect(
        fake.calls.where((c) => c.args.contains('--install-extension')),
        hasLength(1),
      );
    });

    test('a failed install reports the exit code and continues', () async {
      final fake = FakeProcessRunner()
        ..onArgs(['--profile', 'P', '--list-extensions'])
        ..onArgs(
          ['--profile', 'P', '--install-extension', 'bad.ext'],
          events: const [
            OutputLine('not found', isError: true),
            ProcessExited(1),
          ],
        )
        ..onArgs(
          ['--profile', 'P', '--install-extension', 'good.ext'],
          events: const [ProcessExited(0)],
        );
      final events = await _cli(fake)
          .installExtensions('P', ['bad.ext', 'good.ext'])
          .toList();
      final finished = events.whereType<InstallFinished>().toList();
      expect(finished.map((f) => f.success), [false, true]);
      expect(finished.first.exitCode, 1);
      expect(events.whereType<InstallLog>().single.isError, isTrue);
    });

    test('if listing fails everything is attempted', () async {
      final fake = FakeProcessRunner()
        ..onArgs([
          '--profile',
          'P',
          '--list-extensions',
        ], output: const ProcessOutput(exitCode: 1))
        ..onArgs(
          ['--profile', 'P', '--install-extension'],
          events: const [ProcessExited(0)],
        );
      final events = await _cli(fake).installExtensions('P', ['x.y']).toList();
      expect(events.whereType<InstallSkipped>(), isEmpty);
      expect(events.whereType<InstallFinished>().single.success, isTrue);
    });

    test(
      'install uses the shell on Windows and refuses metacharacters',
      () async {
        final fake = FakeProcessRunner()..onArgs(['--profile']);
        final cli = _cli(fake, runInShell: true);
        final events = await cli.installExtension('P', 'a.b').toList();
        expect(fake.calls.single.runInShell, isTrue);
        expect(events.last, isA<ProcessExited>());

        final refused = await cli.installExtension('P&x', 'a.b').toList();
        expect((refused.last as ProcessExited).exitCode, -1);
        expect(fake.calls, hasLength(1));
      },
    );
  });
}
