import 'package:profile_engine/profile_engine.dart';
import 'package:test/test.dart';

void main() {
  test('finds code on PATH first (posix)', () {
    final found = discoverCodePath(
      environment: {'PATH': '/opt/x:/usr/local/bin:/usr/bin'},
      fileExists: {'/usr/local/bin/code', '/usr/bin/code'}.contains,
      operatingSystem: 'linux',
    );
    expect(found, '/usr/local/bin/code');
  });

  test('falls back to the OS defaults (linux)', () {
    expect(
      discoverCodePath(
        environment: {'PATH': '/nowhere'},
        fileExists: {'/snap/bin/code', '/usr/bin/code'}.contains,
        operatingSystem: 'linux',
      ),
      '/snap/bin/code',
    );
    expect(
      discoverCodePath(
        environment: {'PATH': ''},
        fileExists: {'/usr/bin/code'}.contains,
        operatingSystem: 'linux',
      ),
      '/usr/bin/code',
    );
  });

  test('macOS app bundle', () {
    const path =
        '/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code';
    expect(
      discoverCodePath(
        environment: {'PATH': '/usr/bin'},
        fileExists: {path}.contains,
        operatingSystem: 'macos',
      ),
      path,
    );
  });

  test('Windows looks for code.cmd on Path', () {
    expect(
      discoverCodePath(
        environment: {'Path': r'C:\Windows;C:\Tools\VSCode\bin'},
        fileExists: {r'C:\Tools\VSCode\bin\code.cmd'}.contains,
        operatingSystem: 'windows',
      ),
      r'C:\Tools\VSCode\bin\code.cmd',
    );
  });

  test('Windows default install locations', () {
    const user =
        r'C:\Users\me\AppData\Local\Programs\Microsoft VS Code\bin\code.cmd';
    expect(
      discoverCodePath(
        environment: {
          'Path': r'C:\Windows',
          'LOCALAPPDATA': r'C:\Users\me\AppData\Local',
          'ProgramFiles': r'C:\Program Files',
        },
        fileExists: {user}.contains,
        operatingSystem: 'windows',
      ),
      user,
    );
    const system = r'C:\Program Files\Microsoft VS Code\bin\code.cmd';
    expect(
      discoverCodePath(
        environment: {'Path': '', 'ProgramFiles': r'C:\Program Files'},
        fileExists: {system}.contains,
        operatingSystem: 'windows',
      ),
      system,
    );
  });

  test('returns null when nothing is found', () {
    expect(
      discoverCodePath(
        environment: {'PATH': '/usr/bin'},
        fileExists: (_) => false,
        operatingSystem: 'linux',
      ),
      isNull,
    );
  });
}
