final class Recommendation {
  final String profileName;

  /// 프로필에 설치할 확장 ID.
  final List<String> extensions;

  /// 다른 프로필을 쓰는 보조 유형의 확장. 사용자가 고른다.
  final List<String> optionalExtensions;

  /// `.vscode/settings.json`에 병합할 내용.
  final Map<String, Object?> settingsPatch;

  /// 사용자 안내 문구(예: compdb 생성 명령).
  final List<String> notes;

  const Recommendation({
    required this.profileName,
    this.extensions = const [],
    this.optionalExtensions = const [],
    this.settingsPatch = const {},
    this.notes = const [],
  });

  Recommendation copyWith({
    String? profileName,
    List<String>? extensions,
    List<String>? optionalExtensions,
    Map<String, Object?>? settingsPatch,
    List<String>? notes,
  }) => Recommendation(
    profileName: profileName ?? this.profileName,
    extensions: extensions ?? this.extensions,
    optionalExtensions: optionalExtensions ?? this.optionalExtensions,
    settingsPatch: settingsPatch ?? this.settingsPatch,
    notes: notes ?? this.notes,
  );

  Map<String, Object?> toJson() => {
    'profileName': profileName,
    'extensions': extensions,
    'optionalExtensions': optionalExtensions,
    'settingsPatch': settingsPatch,
    'notes': notes,
  };

  factory Recommendation.fromJson(Map<String, Object?> json) => Recommendation(
    profileName: json['profileName'] as String,
    extensions: _strings(json['extensions']),
    optionalExtensions: _strings(json['optionalExtensions']),
    settingsPatch: Map<String, Object?>.of(
      json['settingsPatch'] as Map<String, Object?>,
    ),
    notes: _strings(json['notes']),
  );
}

List<String> _strings(Object? v) => [
  for (final s in v as List<Object?>) s as String,
];
