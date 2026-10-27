import 'package:code_profiler/l10n/app_localizations.dart';
import 'package:code_profiler/providers/providers.dart';
import 'package:code_profiler/services/app_config.dart';
import 'package:code_profiler/services/project_service.dart';
import 'package:code_profiler/services/project_store.dart';
import 'package:code_profiler/settings/app_settings.dart';
import 'package:code_profiler/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:profile_engine/profile_engine.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 화면 테스트용 가짜 서비스. 각 동작을 핸들러로 바꿔 끼우고 호출을 기록한다.
class FakeProjectService implements ProjectService {
  Future<Result<AnalysisBundle>> Function(Project) onAnalyze = (_) async =>
      Ok(sampleBundle());
  Result<Recommendation> Function(AnalysisResult, String?) onRecommend = (
    a,
    id,
  ) => Ok(sampleRecommendation());
  Future<Result<SettingsDiff>> Function(
    Project,
    Map<String, Object?>,
    Set<String>,
  )
  onDiff = (p, patch, replace) async => Ok(sampleDiff(patch, replace));
  Stream<ApplyEvent> Function(ApplyPlan) onApply = (plan) =>
      Stream.fromIterable(successEvents(plan));
  Future<Result<void>> Function(Project, String) onOpen = (p, profile) async =>
      const Ok(null);

  final List<Project> analyzed = [];
  final List<Set<String>> diffReplaces = [];
  final List<String?> recommendPrimaries = [];
  final List<ApplyPlan> applied = [];
  final List<(Project, String)> opened = [];

  @override
  Future<Result<AnalysisBundle>> analyze(Project project) {
    analyzed.add(project);
    return onAnalyze(project);
  }

  @override
  Result<Recommendation> recommendFor(
    AnalysisResult analysis, {
    String? primaryTypeId,
  }) {
    recommendPrimaries.add(primaryTypeId);
    return onRecommend(analysis, primaryTypeId);
  }

  @override
  Future<Result<SettingsDiff>> diff(
    Project project,
    Map<String, Object?> patch,
    Set<String> replaceConflicts,
  ) {
    diffReplaces.add({...replaceConflicts});
    return onDiff(project, patch, replaceConflicts);
  }

  @override
  Stream<ApplyEvent> apply(ApplyPlan plan) {
    applied.add(plan);
    return onApply(plan);
  }

  @override
  Future<Result<void>> open(Project project, String profileName) {
    opened.add((project, profileName));
    return onOpen(project, profileName);
  }
}

List<ApplyEvent> successEvents(ApplyPlan plan) => [
  const StepStarted(ApplyStep.extensions),
  for (final e in plan.extensions) ...[
    ExtensionStarted(e),
    ExtensionOutput(e, 'Installing $e'),
    ExtensionFinished(e, ok: true, exitCode: 0),
  ],
  const StepFinished(ApplyStep.extensions),
  const StepStarted(ApplyStep.settings),
  const StepFinished(
    ApplyStep.settings,
    written: true,
    backupPath: '/p/settings.json.bak.1',
  ),
];

AnalysisResult sampleAnalysis({bool truncated = false, bool empty = false}) =>
    AnalysisResult(
      types: empty
          ? const []
          : const [
              DetectedType(
                typeId: 'java-maven',
                label: 'Java (Maven)',
                priority: 70,
                evidence: [
                  Evidence(
                    ruleId: 'file',
                    description: 'pom.xml 파일 발견',
                    relativePath: 'pom.xml',
                  ),
                ],
              ),
              DetectedType(
                typeId: 'node',
                label: 'JavaScript / TypeScript',
                priority: 60,
                evidence: [
                  Evidence(
                    ruleId: 'file',
                    description: 'package.json 파일 발견',
                    relativePath: 'package.json',
                  ),
                ],
              ),
            ],
      stats: TreeStats(
        fileCount: 12,
        truncated: truncated,
        largeDirsPresent: const ['node_modules'],
      ),
      variables: const {'aospRoot': '/src/aosp'},
      analyzedAt: DateTime.utc(2026, 10, 27),
    );

Recommendation sampleRecommendation({String profile = 'Java'}) =>
    Recommendation(
      profileName: profile,
      extensions: const ['vscjava.vscode-java-pack', 'vscjava.vscode-gradle'],
      optionalExtensions: const ['dbaeumer.vscode-eslint'],
      settingsPatch: const {
        'java.import.exclusions': ['**/target/**'],
        'files.watcherExclude': {'**/target/**': true},
      },
      notes: const ['빌드 후 compile_commands.json 을 만드세요.'],
    );

AnalysisBundle sampleBundle({
  bool truncated = false,
  bool empty = false,
  bool competitors = true,
}) {
  final analysis = sampleAnalysis(truncated: truncated, empty: empty);
  return AnalysisBundle(
    analysis,
    empty ? null : sampleRecommendation(),
    competitors: competitors && !empty ? [analysis.types[1]] : const [],
  );
}

/// 기존 settings.json에 주석이 있고 `a`가 충돌하는 diff.
SettingsDiff sampleDiff(Map<String, Object?> patch, Set<String> replace) =>
    computeSettingsDiff(
      existingText: '{\n  // mine\n  "a": 1,\n  "keep": true\n}\n',
      patch: {'a': 2, 'new.key': 'v', 'keep': true},
      replaceConflicts: replace,
    ).valueOrNull!;

Project sampleProject({
  String id = 'p1',
  String name = 'demo',
  String? profile,
  AnalysisResult? analysis,
  DateTime? lastOpened,
}) => Project(
  id: id,
  name: name,
  location: LocalLocation('/work/$name'),
  profileName: profile,
  addedAt: DateTime.utc(2026, 10, 1),
  lastOpenedAt: lastOpened,
  lastAnalysis: analysis,
);

AppLocalizations get en => lookupAppLocalizations(const Locale('en'));

class Harness {
  Harness({
    List<Project> projects = const [],
    FakeProjectService? service,
    FakeProcessRunner? runner,
    this.initialConfig = const AppConfig(),
  }) : store = MemoryProjectStore(projects),
       configStore = MemoryAppConfigStore(),
       service = service ?? FakeProjectService(),
       runner = runner ?? FakeProcessRunner();

  final MemoryProjectStore store;
  final MemoryAppConfigStore configStore;
  final FakeProjectService service;
  final FakeProcessRunner runner;
  final AppConfig initialConfig;

  /// [home]을 앱 환경(테마, 영어 로케일, Riverpod 저장소)과 함께 띄운다.
  Future<void> pump(WidgetTester tester, Widget home) async {
    SharedPreferences.setMockInitialValues({});
    final settings = await AppSettings.load();
    // 데스크톱 해상도에 가까운 크기로 두어 화면이 잘리지 않게 한다.
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          projectStoreProvider.overrideWithValue(store),
          appConfigStoreProvider.overrideWithValue(configStore),
          appConfigProvider.overrideWith(
            () => AppConfigNotifier(initialConfig),
          ),
          processRunnerProvider.overrideWithValue(runner),
          projectServiceProvider.overrideWithValue(service),
        ],
        child: AppSettingsScope(
          settings: settings,
          child: MaterialApp(
            theme: AppTheme.light(),
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: home,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }
}
