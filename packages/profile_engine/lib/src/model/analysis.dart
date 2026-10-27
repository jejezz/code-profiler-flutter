/// 판정 근거 하나. 어떤 매처가 무엇을 찾았는지.
final class Evidence {
  /// 근거를 낸 매처 종류(예: `file`, `dir`, `fileContains`, `variable`).
  final String ruleId;
  final String description;
  final String? relativePath;

  const Evidence({
    required this.ruleId,
    required this.description,
    this.relativePath,
  });

  Evidence copyWith({
    String? ruleId,
    String? description,
    String? relativePath,
  }) => Evidence(
    ruleId: ruleId ?? this.ruleId,
    description: description ?? this.description,
    relativePath: relativePath ?? this.relativePath,
  );

  Map<String, Object?> toJson() => {
    'ruleId': ruleId,
    'description': description,
    'relativePath': relativePath,
  };

  factory Evidence.fromJson(Map<String, Object?> json) => Evidence(
    ruleId: json['ruleId'] as String,
    description: json['description'] as String,
    relativePath: json['relativePath'] as String?,
  );
}

/// 판정된 프로젝트 유형 하나.
final class DetectedType {
  /// rules.yaml `types[].id`.
  final String typeId;
  final String label;
  final int priority;
  final List<Evidence> evidence;

  const DetectedType({
    required this.typeId,
    required this.label,
    required this.priority,
    this.evidence = const [],
  });

  DetectedType copyWith({
    String? typeId,
    String? label,
    int? priority,
    List<Evidence>? evidence,
  }) => DetectedType(
    typeId: typeId ?? this.typeId,
    label: label ?? this.label,
    priority: priority ?? this.priority,
    evidence: evidence ?? this.evidence,
  );

  Map<String, Object?> toJson() => {
    'typeId': typeId,
    'label': label,
    'priority': priority,
    'evidence': [for (final e in evidence) e.toJson()],
  };

  factory DetectedType.fromJson(Map<String, Object?> json) => DetectedType(
    typeId: json['typeId'] as String,
    label: json['label'] as String,
    priority: json['priority'] as int,
    evidence: [
      for (final e in json['evidence'] as List<Object?>)
        Evidence.fromJson(e as Map<String, Object?>),
    ],
  );
}

final class TreeStats {
  /// 스캔한 파일 수. 상한에서 잘렸으면 [truncated]가 true.
  final int fileCount;
  final bool truncated;

  /// out, build, node_modules 등 들어가지 않고 존재만 확인한 큰 디렉터리.
  final List<String> largeDirsPresent;

  const TreeStats({
    required this.fileCount,
    required this.truncated,
    this.largeDirsPresent = const [],
  });

  TreeStats copyWith({
    int? fileCount,
    bool? truncated,
    List<String>? largeDirsPresent,
  }) => TreeStats(
    fileCount: fileCount ?? this.fileCount,
    truncated: truncated ?? this.truncated,
    largeDirsPresent: largeDirsPresent ?? this.largeDirsPresent,
  );

  Map<String, Object?> toJson() => {
    'fileCount': fileCount,
    'truncated': truncated,
    'largeDirsPresent': largeDirsPresent,
  };

  factory TreeStats.fromJson(Map<String, Object?> json) => TreeStats(
    fileCount: json['fileCount'] as int,
    truncated: json['truncated'] as bool,
    largeDirsPresent: [
      for (final d in json['largeDirsPresent'] as List<Object?>) d as String,
    ],
  );
}

final class AnalysisResult {
  /// priority 내림차순, suppresses 적용 후.
  final List<DetectedType> types;
  final TreeStats stats;

  /// 해석된 변수. 예: `aospRoot`.
  final Map<String, String> variables;
  final DateTime analyzedAt;

  const AnalysisResult({
    required this.types,
    required this.stats,
    this.variables = const {},
    required this.analyzedAt,
  });

  AnalysisResult copyWith({
    List<DetectedType>? types,
    TreeStats? stats,
    Map<String, String>? variables,
    DateTime? analyzedAt,
  }) => AnalysisResult(
    types: types ?? this.types,
    stats: stats ?? this.stats,
    variables: variables ?? this.variables,
    analyzedAt: analyzedAt ?? this.analyzedAt,
  );

  Map<String, Object?> toJson() => {
    'types': [for (final t in types) t.toJson()],
    'stats': stats.toJson(),
    'variables': variables,
    'analyzedAt': analyzedAt.toUtc().toIso8601String(),
  };

  factory AnalysisResult.fromJson(Map<String, Object?> json) => AnalysisResult(
    types: [
      for (final t in json['types'] as List<Object?>)
        DetectedType.fromJson(t as Map<String, Object?>),
    ],
    stats: TreeStats.fromJson(json['stats'] as Map<String, Object?>),
    variables: {
      for (final e in (json['variables'] as Map<String, Object?>).entries)
        e.key: e.value as String,
    },
    analyzedAt: DateTime.parse(json['analyzedAt'] as String),
  );
}
