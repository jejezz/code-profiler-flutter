@Tags(['integration'])
library;

import 'package:profile_engine/profile_engine.dart';
import 'package:test/test.dart';

// 실제 VS Code가 필요하다. 실행: dart test -t integration --run-skipped
void main() {
  test('the discovered code executable reports a version', () async {
    final path = discoverCodePath();
    if (path == null) {
      markTestSkipped('VS Code(code)를 찾지 못했습니다');
      return;
    }
    final cli = VsCodeCli(const SystemProcessRunner(), codePath: path);
    final v = await cli.version();
    expect(v.isOk, isTrue, reason: '${v.errorOrNull}');
    expect(v.valueOrNull, matches(RegExp(r'^\d+\.\d+\.\d+')));
  });

  test(
    'a profile name with spaces reaches VS Code instead of breaking cmd',
    () async {
      final path = discoverCodePath();
      if (path == null) {
        markTestSkipped('VS Code(code)를 찾지 못했습니다');
        return;
      }
      final cli = VsCodeCli(const SystemProcessRunner(), codePath: path);
      // 존재하지 않는 프로필이라 실패해도 되지만, 실패 원인이 cmd의 따옴표 처리여서는 안 된다.
      final r = await cli.listExtensions('No Such Profile / Test');
      final message = r.errorOrNull?.message ?? '';
      expect(message, isNot(contains('is not recognized')));
      expect(message, isNot(contains('인식')));
      expect(message, isNot(contains('구문이 잘못')));
      expect(message, isNot(contains('�')));
    },
  );
}
