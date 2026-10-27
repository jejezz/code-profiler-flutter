import 'package:profile_engine/profile_engine.dart';
import 'package:test/test.dart';

void main() {
  final analysis = AnalysisResult(
    types: const [
      DetectedType(
        typeId: 'esp-idf',
        label: 'ESP-IDF',
        priority: 100,
        evidence: [
          Evidence(
            ruleId: 'file',
            description: 'sdkconfig 파일 발견',
            relativePath: 'sdkconfig',
          ),
          Evidence(ruleId: 'variable', description: 'aospRoot 해석'),
        ],
      ),
    ],
    stats: const TreeStats(
      fileCount: 42,
      truncated: true,
      largeDirsPresent: ['build', 'node_modules'],
    ),
    variables: const {'aospRoot': '/src/aosp'},
    analyzedAt: DateTime.utc(2026, 10, 27, 9, 30),
  );

  test('ProjectLocation: local and ssh round trip', () {
    for (final loc in <ProjectLocation>[
      const LocalLocation('/home/me/app'),
      const SshLocation('devbox', '/srv/aosp/hal'),
    ]) {
      expect(ProjectLocation.fromJson(loc.toJson()).toJson(), loc.toJson());
    }
    expect(
      ProjectLocation.fromJson(const SshLocation('h', '/p').toJson()),
      isA<SshLocation>(),
    );
  });

  test('ProjectLocation: unknown type is rejected', () {
    expect(
      () => ProjectLocation.fromJson({'type': 'ftp'}),
      throwsFormatException,
    );
  });

  test('AnalysisResult round trip keeps nested data', () {
    final back = AnalysisResult.fromJson(analysis.toJson());
    expect(back.toJson(), analysis.toJson());
    expect(back.types.single.evidence.last.relativePath, isNull);
    expect(back.analyzedAt, DateTime.utc(2026, 10, 27, 9, 30));
  });

  test('Project round trip, with and without optional fields', () {
    final full = Project(
      id: 'u-1',
      name: 'hal',
      location: const SshLocation('devbox', '/srv/aosp/hal'),
      profileName: 'C++ AOSP',
      addedAt: DateTime.utc(2026, 10, 1),
      lastOpenedAt: DateTime.utc(2026, 10, 2),
      lastAnalysis: analysis,
    );
    final minimal = Project(
      id: 'u-2',
      name: 'x',
      location: const LocalLocation('/x'),
      addedAt: DateTime.utc(2026, 10, 1),
    );
    for (final p in [full, minimal]) {
      expect(Project.fromJson(p.toJson()).toJson(), p.toJson());
    }
    expect(Project.fromJson(minimal.toJson()).lastAnalysis, isNull);
  });

  test('Recommendation round trip', () {
    const r = Recommendation(
      profileName: 'C++ AOSP',
      extensions: ['llvm-vs-code-extensions.vscode-clangd'],
      optionalExtensions: ['ms-python.python'],
      settingsPatch: {
        'clangd.arguments': ['--background-index'],
        'files.watcherExclude': {'**/out/**': true},
      },
      notes: ['compdb 생성 필요'],
    );
    expect(Recommendation.fromJson(r.toJson()).toJson(), r.toJson());
  });

  test('copyWith replaces only the given fields', () {
    final p = Project(
      id: 'u',
      name: 'a',
      location: const LocalLocation('/a'),
      addedAt: DateTime.utc(2026),
    );
    final q = p.copyWith(name: 'b');
    expect(q.name, 'b');
    expect(q.id, 'u');
    expect(q.addedAt, p.addedAt);
  });
}
