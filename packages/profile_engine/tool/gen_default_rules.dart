// assets/rules.yaml 을 lib/src/rules/default_rules.dart 의 문자열 상수로 복사한다.
// 컴파일한 엔진 실행 파일(원격 배포용)에는 assets 폴더가 따라가지 않으므로 기본 규칙을
// 코드에 내장해야 한다. rules.yaml 을 고친 뒤 `dart run tool/gen_default_rules.dart`.
import 'dart:io';

void main() {
  final yaml = File('assets/rules.yaml')
      .readAsStringSync()
      .replaceAll('\r\n', '\n');
  if (yaml.contains("'''")) {
    stderr.writeln("rules.yaml 에 ''' 가 있어 상수로 내장할 수 없습니다.");
    exit(1);
  }
  File('lib/src/rules/default_rules.dart').writeAsStringSync(
    '// 생성 파일: tool/gen_default_rules.dart 로 assets/rules.yaml 에서 만든다. 직접 고치지 않는다.\n'
    "const defaultRulesYaml = r'''\n$yaml''';\n",
  );
}
