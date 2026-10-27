import 'dart:convert';
import 'dart:io';

import '../model/analysis.dart';
import '../rules/rules_model.dart';
import 'glob.dart';
import 'scanner.dart';

/// fileContains가 한 번에 읽는 최대 바이트 수와 검사할 최대 파일 수.
const _maxReadBytes = 512 * 1024;
const _maxContainsCandidates = 50;

/// 매처 평가에 필요한 입력.
final class MatchContext {
  final ScanSnapshot snapshot;
  final Map<String, String> variables;
  final Map<String, Glob> _globs = {};

  MatchContext(this.snapshot, this.variables);

  Glob glob(String pattern) => _globs.putIfAbsent(pattern, () => Glob(pattern));
}

/// 매처가 맞으면 근거 목록을, 맞지 않으면 null을 돌려준다.
///
/// `all`은 모든 자식의 근거를, `any`는 맞은 자식들의 근거를 모두 합친다.
List<Evidence>? evaluate(Matcher matcher, MatchContext ctx) {
  switch (matcher) {
    case AllMatcher(:final children):
      final all = <Evidence>[];
      for (final child in children) {
        final e = evaluate(child, ctx);
        if (e == null) return null;
        all.addAll(e);
      }
      return all;
    case AnyMatcher(:final children):
      final any = <Evidence>[];
      var matched = false;
      for (final child in children) {
        final e = evaluate(child, ctx);
        if (e != null) {
          matched = true;
          any.addAll(e);
        }
      }
      return matched ? any : null;
    case FileMatcher(:final glob):
      final g = ctx.glob(glob);
      for (final f in ctx.snapshot.files) {
        if (g.matches(f)) {
          return [
            Evidence(ruleId: 'file', description: '$f 파일 발견', relativePath: f),
          ];
        }
      }
      return null;
    case DirMatcher(:final glob):
      final g = ctx.glob(glob);
      for (final d in ctx.snapshot.dirs) {
        if (g.matches(d)) {
          return [
            Evidence(ruleId: 'dir', description: '$d 디렉터리 발견', relativePath: d),
          ];
        }
      }
      return null;
    case FileContainsMatcher(:final glob, :final pattern):
      final g = ctx.glob(glob);
      var checked = 0;
      for (final f in ctx.snapshot.files) {
        if (!g.matches(f)) continue;
        if (++checked > _maxContainsCandidates) break;
        if (_fileHas(ctx.snapshot.root, f, pattern)) {
          return [
            Evidence(
              ruleId: 'fileContains',
              description: '$f 에서 패턴 ${pattern.pattern} 발견',
              relativePath: f,
            ),
          ];
        }
      }
      return null;
    case VariableMatcher(:final name):
      final value = ctx.variables[name];
      if (value == null) return null;
      return [
        Evidence(ruleId: 'variable', description: '변수 $name 해석됨: $value'),
      ];
  }
}

bool _fileHas(String root, String relativePath, RegExp pattern) {
  try {
    final raf = File('$root/$relativePath').openSync();
    try {
      final text = utf8.decode(
        raf.readSync(_maxReadBytes),
        allowMalformed: true,
      );
      return pattern.hasMatch(text);
    } finally {
      raf.closeSync();
    }
  } on FileSystemException {
    return false;
  }
}
