/// 스캔 상한과 건너뛸 디렉터리.
final class ScanConfig {
  final int maxDepth;
  final int maxFiles;
  final List<String> skipDirs;

  const ScanConfig({
    required this.maxDepth,
    required this.maxFiles,
    required this.skipDirs,
  });

  static const defaults = ScanConfig(
    maxDepth: 3,
    maxFiles: 20000,
    skipDirs: [
      '.git',
      '.repo',
      'out',
      'build',
      'node_modules',
      'prebuilts',
      '.venv',
      'venv',
      '__pycache__',
      '.gradle',
      '.idea',
      'managed_components',
      '.cache',
      'dist',
      'target',
    ],
  );
}

/// 매처 트리. `all`/`any`로 중첩할 수 있다.
sealed class Matcher {
  const Matcher();
}

final class AllMatcher extends Matcher {
  final List<Matcher> children;

  const AllMatcher(this.children);
}

final class AnyMatcher extends Matcher {
  final List<Matcher> children;

  const AnyMatcher(this.children);
}

final class FileMatcher extends Matcher {
  final String glob;

  const FileMatcher(this.glob);
}

final class DirMatcher extends Matcher {
  final String glob;

  const DirMatcher(this.glob);
}

final class FileContainsMatcher extends Matcher {
  final String glob;
  final RegExp pattern;

  const FileContainsMatcher(this.glob, this.pattern);
}

/// 변수가 해석되면 참.
final class VariableMatcher extends Matcher {
  final String name;

  const VariableMatcher(this.name);
}

/// 변수 정의. 프로젝트 경로에서 부모 방향으로 [anyOf] 중 하나를 찾는다.
final class VariableRule {
  final List<String> anyOf;
  final int maxLevels;

  const VariableRule({required this.anyOf, required this.maxLevels});
}

final class TypeRule {
  final String id;
  final String label;
  final int priority;
  final Matcher match;
  final List<String> suppresses;
  final String profile;
  final List<String> extensions;
  final Map<String, Object?> settings;
  final List<String> notes;

  const TypeRule({
    required this.id,
    required this.label,
    required this.priority,
    required this.match,
    this.suppresses = const [],
    required this.profile,
    this.extensions = const [],
    this.settings = const {},
    this.notes = const [],
  });
}

/// 트리 규모에 따른 추가 패치. 현재 조건은 `truncated`만 지원한다.
final class SizeRule {
  final bool truncated;
  final Map<String, Object?> settings;
  final List<String> notes;

  const SizeRule({
    required this.truncated,
    this.settings = const {},
    this.notes = const [],
  });
}

final class Rules {
  final int version;
  final ScanConfig scan;
  final Map<String, VariableRule> variables;
  final List<TypeRule> types;
  final List<SizeRule> sizeRules;

  const Rules({
    required this.version,
    required this.scan,
    this.variables = const {},
    required this.types,
    this.sizeRules = const [],
  });

  /// 사용자 규칙을 기본 규칙 위에 얹는다. 같은 `id`의 type은 제자리에서 교체하고
  /// 새 `id`는 뒤에 추가한다. 변수는 이름 단위로 덮어쓰고 sizeRules는 이어 붙인다.
  Rules overriddenBy(Rules user) {
    final merged = [...types];
    for (final t in user.types) {
      final i = merged.indexWhere((m) => m.id == t.id);
      if (i >= 0) {
        merged[i] = t;
      } else {
        merged.add(t);
      }
    }
    return Rules(
      version: version,
      scan: user.scan,
      variables: {...variables, ...user.variables},
      types: merged,
      sizeRules: [...sizeRules, ...user.sizeRules],
    );
  }
}
