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
}
