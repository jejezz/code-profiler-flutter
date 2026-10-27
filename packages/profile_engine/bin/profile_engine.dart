import 'dart:convert';
import 'dart:io';

import 'package:profile_engine/src/cli/engine_cli.dart';

Future<void> main(List<String> arguments) async {
  // 앱이 stdout을 UTF-8로 읽으므로, 콘솔 코드 페이지(예: Windows cp949)와 무관하게 UTF-8로 쓴다.
  stdout.encoding = utf8;
  stderr.encoding = utf8;
  final code = await runEngineCli(arguments);
  await stdout.flush();
  await stderr.flush();
  exit(code);
}
