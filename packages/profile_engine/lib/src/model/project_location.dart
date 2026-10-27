/// 프로젝트 위치. 로컬 또는 SSH 원격.
sealed class ProjectLocation {
  const ProjectLocation();

  Map<String, Object?> toJson();

  factory ProjectLocation.fromJson(Map<String, Object?> json) {
    return switch (json['type']) {
      'local' => LocalLocation(json['path'] as String),
      'ssh' => SshLocation(json['host'] as String, json['path'] as String),
      final other => throw FormatException('unknown location type: $other'),
    };
  }
}

final class LocalLocation extends ProjectLocation {
  /// 절대 경로.
  final String path;

  const LocalLocation(this.path);

  @override
  Map<String, Object?> toJson() => {'type': 'local', 'path': path};
}

final class SshLocation extends ProjectLocation {
  /// `~/.ssh/config`의 Host 이름.
  final String host;

  /// 서버상의 절대 경로.
  final String path;

  const SshLocation(this.host, this.path);

  @override
  Map<String, Object?> toJson() => {'type': 'ssh', 'host': host, 'path': path};
}
