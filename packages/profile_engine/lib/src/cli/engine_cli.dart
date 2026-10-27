import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';

import '../analyzer/analyzer.dart';
import '../model/analysis.dart';
import '../model/recommendation.dart';
import '../recommender/recommender.dart';
import '../result.dart';
import '../rules/rules_loader.dart';
import '../rules/rules_model.dart';
import '../settings/jsonc.dart';
import '../settings/merge.dart';
import '../settings/settings_file.dart';
import '../version.dart';

/// 종료 코드.
const exitOk = 0;
const exitUsage = 1;
const exitPath = 2;
const exitRules = 3;

/// 설정 파일을 읽거나 쓰지 못함(기존 settings.json이 잘못된 경우 포함).
const exitWrite = 4;

const _usage = '''
사용법:
  profile-engine --version
  profile-engine analyze <path> [--rules <file>] [--json]
  profile-engine recommend <path> [--rules <file>] [--json]
  profile-engine diff-settings <path> --patch <json-file|-> [--replace-conflicts p1,p2] [--json]
  profile-engine apply-settings <path> --patch <json-file|-> [--replace-conflicts p1,p2] [--json]

--json 이면 stdout에 JSON 객체 하나를 쓰고, 사람이 읽는 메시지는 stderr에 쓴다.
종료 코드: 0 성공, 1 사용법 오류, 2 경로 없음/권한 없음, 3 규칙 파일 오류, 4 설정 파일 처리 실패''';

/// 엔진 CLI 본체. `bin/profile_engine.dart`가 호출하고, 테스트도 직접 호출한다.
Future<int> runEngineCli(
  List<String> arguments, {
  StringSink? out,
  StringSink? err,
  Stream<List<int>>? stdinStream,
}) async {
  final io = _Io(
    out ?? stdout,
    err ?? stderr,
    json: arguments.contains('--json'),
  );

  final ArgResults results;
  try {
    results = _parser().parse(arguments);
  } on FormatException catch (e) {
    return io.fail(exitUsage, 'usage', EngineError(e.message));
  }

  if (results['version'] as bool) {
    io.out.writeln(engineVersion);
    return exitOk;
  }
  final command = results.command;
  if (command == null) {
    io.err.writeln(_usage);
    return results['help'] as bool ? exitOk : exitUsage;
  }

  switch (command.name) {
    case 'analyze':
      return _analyze(io, command, withRecommendation: false);
    case 'recommend':
      return _analyze(io, command, withRecommendation: true);
    case 'diff-settings':
      return _settings(io, command, stdinStream, apply: false);
    case 'apply-settings':
      return _settings(io, command, stdinStream, apply: true);
  }
  return io.fail(exitUsage, 'usage', EngineError('알 수 없는 명령: ${command.name}'));
}

ArgParser _parser() {
  ArgParser command({
    bool rules = false,
    bool patch = false,
    bool replace = false,
  }) {
    final p = ArgParser()..addFlag('json', negatable: false);
    if (rules) p.addOption('rules');
    if (patch) p.addOption('patch');
    if (replace) p.addOption('replace-conflicts');
    return p;
  }

  return ArgParser()
    ..addFlag('version', negatable: false)
    ..addFlag('help', abbr: 'h', negatable: false)
    ..addCommand('analyze', command(rules: true))
    ..addCommand('recommend', command(rules: true))
    ..addCommand('diff-settings', command(patch: true, replace: true))
    ..addCommand('apply-settings', command(patch: true, replace: true));
}

final class _Io {
  final StringSink out;
  final StringSink err;
  final bool json;

  _Io(this.out, this.err, {required this.json});

  int ok(Map<String, Object?> data, String human) {
    out.writeln(json ? jsonEncode({'ok': true, ...data}) : human);
    return exitOk;
  }

  int fail(int code, String kind, EngineError error) {
    err.writeln(error);
    if (json) {
      out.writeln(
        jsonEncode({
          'ok': false,
          'error': {'kind': kind, 'message': error.message, 'line': error.line},
        }),
      );
    }
    return code;
  }
}

Future<int> _analyze(
  _Io io,
  ArgResults cmd, {
  required bool withRecommendation,
}) async {
  if (cmd.rest.length != 1) {
    return io.fail(
      exitUsage,
      'usage',
      EngineError('${cmd.name} 에는 경로가 하나 필요합니다'),
    );
  }
  final rules = await _loadRules(cmd['rules'] as String?);
  if (rules is Err<Rules>) return io.fail(exitRules, 'rules', rules.error);

  final analysis = analyzeSync(
    cmd.rest.single,
    rules: (rules as Ok<Rules>).value,
  );
  if (analysis is Err<AnalysisResult>) {
    return io.fail(exitPath, 'path', analysis.error);
  }
  final result = (analysis as Ok<AnalysisResult>).value;

  if (!withRecommendation) {
    return io.ok({'analysis': result.toJson()}, _describeAnalysis(result));
  }
  final rec = recommend(result, rules.value);
  if (rec is Err<Recommendation>) {
    // 판정된 유형이 없는 것은 오류가 아니라 "추천 없음"이다.
    return io.ok({
      'analysis': result.toJson(),
      'recommendation': null,
    }, '${_describeAnalysis(result)}\n추천 없음: ${rec.error.message}');
  }
  final recommendation = (rec as Ok<Recommendation>).value;
  return io.ok(
    {'analysis': result.toJson(), 'recommendation': recommendation.toJson()},
    '${_describeAnalysis(result)}\n\n${_describeRecommendation(recommendation)}',
  );
}

Future<int> _settings(
  _Io io,
  ArgResults cmd,
  Stream<List<int>>? stdinStream, {
  required bool apply,
}) async {
  if (cmd.rest.length != 1) {
    return io.fail(
      exitUsage,
      'usage',
      EngineError('${cmd.name} 에는 경로가 하나 필요합니다'),
    );
  }
  final root = cmd.rest.single;
  if (!Directory(root).existsSync()) {
    return io.fail(
      exitPath,
      'path',
      EngineError('경로를 찾을 수 없거나 폴더가 아닙니다: $root'),
    );
  }
  final patch = await _readPatch(cmd['patch'] as String?, stdinStream);
  if (patch is Err<Map<String, Object?>>) {
    return io.fail(exitUsage, 'usage', patch.error);
  }
  final patchMap = (patch as Ok<Map<String, Object?>>).value;
  final replace = {
    for (final p in ((cmd['replace-conflicts'] as String?) ?? '').split(','))
      if (p.trim().isNotEmpty) p.trim(),
  };

  if (!apply) {
    final r = await diffSettingsFile(root, patchMap, replaceConflicts: replace);
    if (r is Err<SettingsDiff>) return io.fail(exitWrite, 'settings', r.error);
    final diff = (r as Ok<SettingsDiff>).value;
    return io.ok({'diff': diff.toJson()}, _describeDiff(diff));
  }

  final r = await applySettingsFile(root, patchMap, replaceConflicts: replace);
  if (r is Err<SettingsWriteResult>) {
    return io.fail(exitWrite, 'settings', r.error);
  }
  final written = (r as Ok<SettingsWriteResult>).value;
  return io.ok(
    {
      'written': written.written,
      'backupPath': written.backupPath,
      'diff': written.diff.toJson(),
    },
    written.written
        ? 'settings.json을 갱신했습니다'
              '${written.backupPath == null ? '' : ' (백업: ${written.backupPath})'}'
        : '바뀔 내용이 없어 파일을 쓰지 않았습니다',
  );
}

/// `--rules`로 파일을 지정했다면 그 파일은 반드시 있어야 한다(기본 규칙 위에 병합된다).
Future<Result<Rules>> _loadRules(String? userRulesPath) async {
  if (userRulesPath != null && !File(userRulesPath).existsSync()) {
    return Err(EngineError('규칙 파일을 찾을 수 없습니다: $userRulesPath'));
  }
  return loadRules(userRulesPath: userRulesPath);
}

/// `--patch`의 값: JSON 파일 경로, 또는 `-`(표준 입력).
Future<Result<Map<String, Object?>>> _readPatch(
  String? source,
  Stream<List<int>>? stdinStream,
) async {
  if (source == null) {
    return const Err(EngineError('--patch <json-file|-> 가 필요합니다'));
  }
  final String text;
  try {
    if (source == '-') {
      text = await utf8.decodeStream(stdinStream ?? stdin);
    } else {
      text = await File(source).readAsString();
    }
  } on FileSystemException catch (e) {
    return Err(EngineError('patch 파일을 읽을 수 없습니다: ${e.message}'));
  } on FormatException catch (e) {
    return Err(EngineError('patch가 UTF-8이 아닙니다: ${e.message}'));
  }
  final parsed = parseJsonc(text);
  if (parsed is Err<JsoncDocument>) {
    return Err(EngineError('patch JSON 오류: ${parsed.error}'));
  }
  final value = (parsed as Ok<JsoncDocument>).value.value;
  if (value is! Map<String, Object?>) {
    return const Err(EngineError('patch의 최상위 값은 객체({})여야 합니다'));
  }
  return Ok(value);
}

String _describeAnalysis(AnalysisResult a) {
  final b = StringBuffer();
  if (a.types.isEmpty) {
    b.writeln('판정된 유형 없음');
  } else {
    b.writeln('판정된 유형:');
    for (final t in a.types) {
      b.writeln('  ${t.label} (${t.typeId}, priority ${t.priority})');
      for (final e in t.evidence) {
        b.writeln('    - ${e.description}');
      }
    }
  }
  b.write(
    '스캔한 파일 ${a.stats.fileCount}개${a.stats.truncated ? ' (상한에서 잘림)' : ''}',
  );
  if (a.variables.isNotEmpty) {
    b.write(
      '\n변수: ${a.variables.entries.map((e) => '${e.key}=${e.value}').join(', ')}',
    );
  }
  return b.toString();
}

String _describeRecommendation(Recommendation r) {
  final b = StringBuffer('추천 프로필: ${r.profileName}\n');
  b.writeln('확장: ${r.extensions.join(', ')}');
  if (r.optionalExtensions.isNotEmpty) {
    b.writeln('선택 확장: ${r.optionalExtensions.join(', ')}');
  }
  b.write('설정 항목 ${r.settingsPatch.length}개');
  for (final n in r.notes) {
    b.write('\n안내: $n');
  }
  return b.toString();
}

String _describeDiff(SettingsDiff d) =>
    '추가 ${d.added.length}, 유지 ${d.unchanged.length}, 충돌 ${d.conflicts.length}'
    '${d.commentsWillBeLost ? '\n경고: 기존 주석이 사라집니다' : ''}';
