import 'package:profile_engine/profile_engine.dart';

import 'analysis_hints.dart';

/// 분석 결과와 그에 따른 추천. 판정된 유형이 없으면 [recommendation]은 null이다.
class AnalysisBundle {
  const AnalysisBundle(
    this.analysis,
    this.recommendation, {
    this.competitors = const [],
  });

  final AnalysisResult analysis;
  final Recommendation? recommendation;

  /// 주 유형과 priority가 가깝고 다른 프로필을 쓰는 후보([closeCompetitors]).
  final List<DetectedType> competitors;
}

/// "적용" 한 번에 필요한 모든 입력.
class ApplyPlan {
  const ApplyPlan({
    required this.project,
    required this.profileName,
    required this.extensions,
    required this.settingsPatch,
    this.replaceConflicts = const {},
  });

  final Project project;
  final String profileName;
  final List<String> extensions;
  final Map<String, Object?> settingsPatch;
  final Set<String> replaceConflicts;
}

/// 적용 단계. 프로필이 있어야 확장을 설치할 수 있으므로 프로필 준비가 가장 앞이다.
enum ApplyStep { profile, extensions, settings }

/// 적용 진행 이벤트. 화면이 현재 언어로 문구를 만들 수 있도록 문구 대신 데이터를 담는다.
sealed class ApplyEvent {
  const ApplyEvent();
}

final class StepStarted extends ApplyEvent {
  const StepStarted(this.step);

  final ApplyStep step;
}

/// 프로필이 이미 있다.
final class ProfileExists extends ApplyEvent {
  const ProfileExists();
}

/// 프로필이 없어 VS Code를 열어 새로 만드는 중이다(수십 초 걸릴 수 있다).
final class ProfileCreating extends ApplyEvent {
  const ProfileCreating();
}

final class ProfileCreated extends ApplyEvent {
  const ProfileCreated();
}

final class ExtensionSkipped extends ApplyEvent {
  const ExtensionSkipped(this.id);

  final String id;
}

final class ExtensionStarted extends ApplyEvent {
  const ExtensionStarted(this.id);

  final String id;
}

final class ExtensionOutput extends ApplyEvent {
  const ExtensionOutput(this.id, this.line, {this.isError = false});

  final String id;
  final String line;
  final bool isError;
}

final class ExtensionFinished extends ApplyEvent {
  const ExtensionFinished(this.id, {required this.ok, required this.exitCode});

  final String id;
  final bool ok;
  final int exitCode;
}

final class StepFinished extends ApplyEvent {
  const StepFinished(this.step, {this.written, this.backupPath});

  final ApplyStep step;

  /// settings 단계에서 파일을 실제로 썼는지.
  final bool? written;
  final String? backupPath;
}

/// 단계가 실패해 적용을 멈췄다.
final class StepFailed extends ApplyEvent {
  const StepFailed(this.step, this.message);

  final ApplyStep step;
  final String message;
}

/// 화면이 엔진과 VS Code를 쓰는 유일한 통로. 화면 테스트는 이 인터페이스를 가짜로 바꾼다.
abstract interface class ProjectService {
  Future<Result<AnalysisBundle>> analyze(Project project);

  /// [primaryTypeId] 유형을 주 유형으로 삼아 다시 추천한다.
  Result<Recommendation> recommendFor(
    AnalysisResult analysis, {
    String? primaryTypeId,
  });

  Future<Result<SettingsDiff>> diff(
    Project project,
    Map<String, Object?> patch,
    Set<String> replaceConflicts,
  );

  Stream<ApplyEvent> apply(ApplyPlan plan);

  Future<Result<void>> open(Project project, String profileName);
}

typedef AnalyzeFunction = Future<Result<AnalysisResult>> Function(
  String path, {
  Rules? rules,
});

// 클래스 안에서는 `analyze`가 같은 이름의 메서드를 가리키므로, 엔진 함수는 이렇게 감싼다.
Future<Result<AnalysisResult>> _engineAnalyze(String path, {Rules? rules}) =>
    analyze(path, rules: rules);

/// 로컬 폴더용 구현. SSH 프로젝트는 Phase 6에서 원격 엔진 호출로 확장한다.
class LocalProjectService implements ProjectService {
  LocalProjectService({
    required this.cli,
    required this.loadRules,
    this.analyzer = _engineAnalyze,
  });

  final VsCodeCli cli;
  final Future<Result<Rules>> Function() loadRules;
  final AnalyzeFunction analyzer;

  static const _sshError = EngineError('SSH 프로젝트는 아직 지원하지 않습니다');

  Rules? _cachedRules;

  /// [analyze]가 읽은 규칙을 [recommendFor]가 다시 쓰도록 보관한다.
  Future<Result<Rules>> _rules() async {
    final r = await loadRules();
    if (r is Ok<Rules>) _cachedRules = r.value;
    return r;
  }

  String? _localPath(Project p) =>
      p.location is LocalLocation ? (p.location as LocalLocation).path : null;

  @override
  Future<Result<AnalysisBundle>> analyze(Project project) async {
    final path = _localPath(project);
    if (path == null) return const Err(_sshError);
    final rules = await _rules();
    if (rules is Err<Rules>) return Err(rules.error);
    final r = await analyzer(path, rules: (rules as Ok<Rules>).value);
    if (r is Err<AnalysisResult>) return Err(r.error);
    final analysis = (r as Ok<AnalysisResult>).value;
    return Ok(
      AnalysisBundle(
        analysis,
        recommend(analysis, rules.value).valueOrNull,
        competitors: closeCompetitors(analysis, rules.value),
      ),
    );
  }

  @override
  Result<Recommendation> recommendFor(
    AnalysisResult analysis, {
    String? primaryTypeId,
  }) {
    // 규칙은 분석 때 이미 한 번 읽었으므로, 같은 규칙으로 다시 계산하려면 캐시가 필요하다.
    final rules = _cachedRules;
    if (rules == null) {
      return const Err(EngineError('규칙이 아직 로드되지 않았습니다. 다시 분석하세요'));
    }
    var types = analysis.types;
    if (primaryTypeId != null) {
      final i = types.indexWhere((t) => t.typeId == primaryTypeId);
      if (i > 0) {
        types = [types[i], ...types.sublist(0, i), ...types.sublist(i + 1)];
      }
    }
    return recommend(analysis.copyWith(types: types), rules);
  }

  @override
  Future<Result<SettingsDiff>> diff(
    Project project,
    Map<String, Object?> patch,
    Set<String> replaceConflicts,
  ) async {
    final path = _localPath(project);
    if (path == null) return const Err(_sshError);
    return diffSettingsFile(path, patch, replaceConflicts: replaceConflicts);
  }

  @override
  Stream<ApplyEvent> apply(ApplyPlan plan) async* {
    final path = _localPath(plan.project);
    if (path == null) {
      yield StepFailed(ApplyStep.profile, _sshError.message);
      return;
    }

    // 프로필이 없으면 확장을 설치할 수 없다. CLI에는 생성 명령이 없어서, 없는 이름으로
    // 프로젝트를 열면 만들어지는 동작을 이용한다(VsCodeCli.createProfile).
    yield const StepStarted(ApplyStep.profile);
    if (await cli.profileExists(plan.profileName)) {
      yield const ProfileExists();
    } else {
      yield const ProfileCreating();
      final created = await cli.createProfile(
        plan.profileName,
        plan.project.location,
      );
      if (created is Err<void>) {
        yield StepFailed(ApplyStep.profile, created.error.message);
        return;
      }
      yield const ProfileCreated();
    }
    yield const StepFinished(ApplyStep.profile);

    yield const StepStarted(ApplyStep.extensions);
    final failed = <String>[];
    await for (final e in cli.installExtensions(
      plan.profileName,
      plan.extensions,
    )) {
      switch (e) {
        case InstallSkipped(:final extensionId):
          yield ExtensionSkipped(extensionId);
        case InstallStarted(:final extensionId):
          yield ExtensionStarted(extensionId);
        case InstallLog(:final extensionId, :final line, :final isError):
          yield ExtensionOutput(extensionId, line, isError: isError);
        case InstallFinished(
          :final extensionId,
          :final success,
          :final exitCode,
        ):
          if (!success) failed.add(extensionId);
          yield ExtensionFinished(extensionId, ok: success, exitCode: exitCode);
      }
    }
    if (failed.isNotEmpty) {
      yield StepFailed(ApplyStep.extensions, failed.join(', '));
      return;
    }
    yield const StepFinished(ApplyStep.extensions);

    yield const StepStarted(ApplyStep.settings);
    final r = await applySettingsFile(
      path,
      plan.settingsPatch,
      replaceConflicts: plan.replaceConflicts,
    );
    switch (r) {
      case Err<SettingsWriteResult>(:final error):
        yield StepFailed(ApplyStep.settings, error.message);
      case Ok<SettingsWriteResult>(:final value):
        yield StepFinished(
          ApplyStep.settings,
          written: value.written,
          backupPath: value.backupPath,
        );
    }
  }

  @override
  Future<Result<void>> open(Project project, String profileName) async {
    if (_localPath(project) == null) return const Err(_sshError);
    return cli.open(profileName, project.location);
  }
}
