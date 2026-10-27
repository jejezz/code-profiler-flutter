import 'dart:io';

import '../result.dart';
import 'default_rules.dart';
import 'rules_model.dart';
import 'rules_parser.dart';

/// 내장 기본 규칙만 읽는다.
Result<Rules> loadDefaultRules() => _checked(parseRules(defaultRulesYaml));

/// 기본 규칙을 읽고, [userRulesPath] 파일이 있으면 그 위에 병합한다.
///
/// 사용자 파일이 없으면(경로가 null이거나 파일이 없음) 기본 규칙만 돌려준다.
/// 사용자 파일이 있는데 잘못됐으면 파일 경로와 줄 번호가 담긴 [Err]를 돌려준다.
Future<Result<Rules>> loadRules({String? userRulesPath}) async {
  final base = loadDefaultRules();
  if (base is Err<Rules> || userRulesPath == null) return base;
  final baseRules = (base as Ok<Rules>).value;

  final file = File(userRulesPath);
  if (!await file.exists()) return base;

  final String text;
  try {
    text = await file.readAsString();
  } on FileSystemException catch (e) {
    return Err(EngineError('사용자 규칙 파일을 읽을 수 없습니다: ${e.message}'));
  }

  final parsed = parseRules(text, defaults: baseRules.scan);
  if (parsed is Err<Rules>) {
    return Err(
      EngineError(
        '$userRulesPath: ${parsed.error.message}',
        line: parsed.error.line,
      ),
    );
  }
  return _checked(Ok(baseRules.overriddenBy((parsed as Ok<Rules>).value)));
}

Result<Rules> _checked(Result<Rules> r) {
  if (r is! Ok<Rules>) return r;
  final problem = validateRules(r.value);
  return problem == null ? r : Err(problem);
}
