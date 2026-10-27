import 'analysis.dart';
import 'project_location.dart';

class Project {
  /// UUID.
  final String id;

  /// 표시 이름. 기본값은 폴더 이름.
  final String name;
  final ProjectLocation location;

  /// 적용된 프로필.
  final String? profileName;
  final DateTime addedAt;
  final DateTime? lastOpenedAt;
  final AnalysisResult? lastAnalysis;

  const Project({
    required this.id,
    required this.name,
    required this.location,
    this.profileName,
    required this.addedAt,
    this.lastOpenedAt,
    this.lastAnalysis,
  });

  /// null 인자는 "바꾸지 않음"으로 취급한다. 값을 비우는 기능은 필요해지면 추가한다.
  Project copyWith({
    String? id,
    String? name,
    ProjectLocation? location,
    String? profileName,
    DateTime? addedAt,
    DateTime? lastOpenedAt,
    AnalysisResult? lastAnalysis,
  }) => Project(
    id: id ?? this.id,
    name: name ?? this.name,
    location: location ?? this.location,
    profileName: profileName ?? this.profileName,
    addedAt: addedAt ?? this.addedAt,
    lastOpenedAt: lastOpenedAt ?? this.lastOpenedAt,
    lastAnalysis: lastAnalysis ?? this.lastAnalysis,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'location': location.toJson(),
    'profileName': profileName,
    'addedAt': addedAt.toUtc().toIso8601String(),
    'lastOpenedAt': lastOpenedAt?.toUtc().toIso8601String(),
    'lastAnalysis': lastAnalysis?.toJson(),
  };

  factory Project.fromJson(Map<String, Object?> json) {
    final opened = json['lastOpenedAt'] as String?;
    final analysis = json['lastAnalysis'] as Map<String, Object?>?;
    return Project(
      id: json['id'] as String,
      name: json['name'] as String,
      location: ProjectLocation.fromJson(
        json['location'] as Map<String, Object?>,
      ),
      profileName: json['profileName'] as String?,
      addedAt: DateTime.parse(json['addedAt'] as String),
      lastOpenedAt: opened == null ? null : DateTime.parse(opened),
      lastAnalysis: analysis == null ? null : AnalysisResult.fromJson(analysis),
    );
  }
}
