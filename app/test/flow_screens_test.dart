import 'package:code_profiler/screens/analysis_screen.dart';
import 'package:code_profiler/screens/apply_screen.dart';
import 'package:code_profiler/screens/diff_screen.dart';
import 'package:code_profiler/screens/project_list_screen.dart';
import 'package:code_profiler/screens/recommendation_screen.dart';
import 'package:code_profiler/screens/settings_screen.dart';
import 'package:code_profiler/services/app_config.dart';
import 'package:code_profiler/services/project_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:profile_engine/profile_engine.dart';

import 'screen_helpers.dart';

Future<void> _tapText(WidgetTester tester, String text) async {
  await tester.tap(find.text(text));
  await tester.pumpAndSettle();
}

void main() {
  group('AnalysisScreen', () {
    testWidgets('shows types, evidence, stats and the competitor notice', (
      tester,
    ) async {
      final h = Harness(projects: [sampleProject(id: 'p1')]);
      await h.pump(tester, const AnalysisScreen(projectId: 'p1'));

      expect(find.text('Java (Maven)'), findsOneWidget);
      expect(find.text('JavaScript / TypeScript'), findsOneWidget);
      expect(find.text(en.analysisPrimaryBadge), findsOneWidget);
      expect(find.text(en.analysisPriority('70')), findsOneWidget);
      // 주 유형은 펼쳐져 있어 근거가 보인다.
      expect(find.text('pom.xml 파일 발견'), findsOneWidget);
      expect(find.text(en.analysisStats('12')), findsOneWidget);
      expect(find.text(en.analysisSkippedDirs('node_modules')), findsOneWidget);
      expect(find.text('aospRoot = /src/aosp'), findsOneWidget);
      // 근접 경쟁 후보는 알리기만 한다.
      expect(find.text(en.analysisCompetitorsTitle), findsOneWidget);
      expect(
        find.text(en.analysisCompetitorsBody('JavaScript / TypeScript')),
        findsOneWidget,
      );
    });

    testWidgets('saves the last analysis on the project', (tester) async {
      final h = Harness(projects: [sampleProject(id: 'p1')]);
      await h.pump(tester, const AnalysisScreen(projectId: 'p1'));
      expect(h.store.saved.single.lastAnalysis, isNotNull);
      expect(
        h.store.saved.single.lastAnalysis!.types.first.typeId,
        'java-maven',
      );
    });

    testWidgets('a truncated scan shows the warning', (tester) async {
      final h = Harness(projects: [sampleProject(id: 'p1')]);
      h.service.onAnalyze = (_) async => Ok(sampleBundle(truncated: true));
      await h.pump(tester, const AnalysisScreen(projectId: 'p1'));
      expect(find.text(en.analysisTruncated), findsOneWidget);
    });

    testWidgets('no detected type: notice and the next button is disabled', (
      tester,
    ) async {
      final h = Harness(projects: [sampleProject(id: 'p1')]);
      h.service.onAnalyze = (_) async => Ok(sampleBundle(empty: true));
      await h.pump(tester, const AnalysisScreen(projectId: 'p1'));
      expect(find.text(en.analysisNoTypes), findsOneWidget);
      final next = find.widgetWithText(FilledButton, en.analysisNext);
      expect(tester.widget<FilledButton>(next).onPressed, isNull);
    });

    testWidgets('failure shows the message; retry analyzes again', (
      tester,
    ) async {
      final h = Harness(projects: [sampleProject(id: 'p1')]);
      var attempts = 0;
      h.service.onAnalyze = (_) async {
        attempts++;
        return attempts == 1
            ? const Err(EngineError('path not found'))
            : Ok(sampleBundle());
      };
      await h.pump(tester, const AnalysisScreen(projectId: 'p1'));
      expect(find.text(en.analysisFailed), findsOneWidget);
      expect(find.text('path not found'), findsOneWidget);

      await _tapText(tester, en.commonRetry);
      expect(attempts, 2);
      expect(find.text('Java (Maven)'), findsOneWidget);
    });

    testWidgets('the next button opens the recommendation', (tester) async {
      final h = Harness(projects: [sampleProject(id: 'p1')]);
      await h.pump(tester, const AnalysisScreen(projectId: 'p1'));
      await _tapText(tester, en.analysisNext);
      expect(find.text(en.recommendTitle), findsOneWidget);
    });

    testWidgets('unknown project id is reported, not crashed', (tester) async {
      final h = Harness();
      await h.pump(tester, const AnalysisScreen(projectId: 'missing'));
      expect(find.text(en.analysisFailed), findsOneWidget);
    });
  });

  group('RecommendationScreen', () {
    Future<Harness> open(WidgetTester tester) async {
      final h = Harness(projects: [sampleProject(id: 'p1')]);
      await h.pump(
        tester,
        RecommendationScreen(
          project: sampleProject(id: 'p1'),
          bundle: sampleBundle(),
        ),
      );
      return h;
    }

    testWidgets('shows profile, required and optional extensions, notes', (
      tester,
    ) async {
      await open(tester);
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.controller!.text, 'Java');
      expect(find.text('vscjava.vscode-java-pack'), findsOneWidget);
      expect(find.text(en.recommendExtensionsOptional), findsOneWidget);
      expect(find.text('빌드 후 compile_commands.json 을 만드세요.'), findsOneWidget);
      expect(find.text(en.recommendSettingsCount('2')), findsOneWidget);

      // 필수 확장은 체크되어 있고 선택 확장은 해제되어 있다.
      final boxes = tester
          .widgetList<CheckboxListTile>(find.byType(CheckboxListTile))
          .toList();
      expect(boxes.map((b) => b.value), [true, true, false]);
    });

    testWidgets('an empty or unsafe profile name disables the next button', (
      tester,
    ) async {
      await open(tester);
      final next = find.widgetWithText(FilledButton, en.recommendNext);

      await tester.enterText(find.byType(TextField), '');
      await tester.pump();
      expect(find.text(en.recommendProfileEmpty), findsOneWidget);
      expect(tester.widget<FilledButton>(next).onPressed, isNull);

      await tester.enterText(find.byType(TextField), 'bad&name');
      await tester.pump();
      expect(find.text(en.recommendProfileInvalid), findsOneWidget);
      expect(tester.widget<FilledButton>(next).onPressed, isNull);

      await tester.enterText(find.byType(TextField), 'C++ AOSP');
      await tester.pump();
      expect(tester.widget<FilledButton>(next).onPressed, isNotNull);
    });

    testWidgets('choosing another type recommends again with it as primary', (
      tester,
    ) async {
      final h = Harness(projects: [sampleProject(id: 'p1')]);
      h.service.onRecommend = (a, id) => Ok(
        id == 'node'
            ? const Recommendation(
                profileName: 'Web / Python',
                extensions: ['dbaeumer.vscode-eslint'],
                optionalExtensions: ['vscjava.vscode-java-pack'],
              )
            : sampleRecommendation(),
      );
      await h.pump(
        tester,
        RecommendationScreen(
          project: sampleProject(id: 'p1'),
          bundle: sampleBundle(),
        ),
      );
      await _tapText(tester, 'JavaScript / TypeScript');
      expect(h.service.recommendPrimaries.last, 'node');
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'Web / Python',
      );
      expect(find.text('dbaeumer.vscode-eslint'), findsOneWidget);
    });

    testWidgets('next opens the diff screen', (tester) async {
      await open(tester);
      await _tapText(tester, en.recommendNext);
      expect(find.text(en.diffTitle), findsWidgets);
    });
  });

  group('DiffScreen', () {
    ApplyPlan plan() => ApplyPlan(
      project: sampleProject(id: 'p1'),
      profileName: 'Java',
      extensions: const ['a.b'],
      settingsPatch: const {'a': 2},
    );

    testWidgets('shows added, conflicts and the comment warning', (
      tester,
    ) async {
      final h = Harness(projects: [sampleProject(id: 'p1')]);
      await h.pump(tester, DiffScreen(plan: plan()));

      expect(find.text(en.diffAdded('1')), findsOneWidget);
      expect(find.text(en.diffConflicts('1')), findsOneWidget);
      expect(find.text(en.diffUnchanged('1')), findsOneWidget);
      expect(find.text('new.key'), findsOneWidget);
      expect(find.text('${en.diffExisting}: 1'), findsOneWidget);
      expect(find.text('${en.diffPatch}: 2'), findsOneWidget);
      expect(find.text(en.diffCommentsWarning), findsOneWidget);
    });

    testWidgets('toggling a conflict recomputes the diff with that pointer', (
      tester,
    ) async {
      final h = Harness(projects: [sampleProject(id: 'p1')]);
      await h.pump(tester, DiffScreen(plan: plan()));
      expect(h.service.diffReplaces.last, isEmpty);

      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      expect(h.service.diffReplaces.last, {'/a'});
      expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);

      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      expect(h.service.diffReplaces.last, isEmpty);
    });

    testWidgets('a brand-new file is announced', (tester) async {
      final h = Harness(projects: [sampleProject(id: 'p1')]);
      h.service.onDiff = (_, patch, _) async =>
          computeSettingsDiff(patch: {'a': 1});
      await h.pump(tester, DiffScreen(plan: plan()));
      expect(find.text(en.diffNewFile), findsOneWidget);
    });

    testWidgets('an unchanged file is announced', (tester) async {
      final h = Harness(projects: [sampleProject(id: 'p1')]);
      h.service.onDiff = (_, _, _) async =>
          computeSettingsDiff(existingText: '{"a": 1}', patch: {'a': 1});
      await h.pump(tester, DiffScreen(plan: plan()));
      expect(find.text(en.diffNoChange), findsOneWidget);
    });

    testWidgets('a failure is shown and applying is disabled', (tester) async {
      final h = Harness(projects: [sampleProject(id: 'p1')]);
      h.service.onDiff = (_, _, _) async =>
          const Err(EngineError('bad json', line: 3));
      await h.pump(tester, DiffScreen(plan: plan()));
      expect(find.text(en.diffFailed), findsOneWidget);
      expect(find.text('줄 3: bad json'), findsOneWidget);
      final apply = find.widgetWithText(FilledButton, en.diffApply);
      expect(tester.widget<FilledButton>(apply).onPressed, isNull);
    });

    testWidgets('apply passes the chosen conflict replacements on', (
      tester,
    ) async {
      final h = Harness(projects: [sampleProject(id: 'p1')]);
      await h.pump(tester, DiffScreen(plan: plan()));
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      await _tapText(tester, en.diffApply);
      expect(find.text(en.applyTitle), findsOneWidget);
      expect(h.service.applied.single.replaceConflicts, {'/a'});
      expect(h.service.applied.single.profileName, 'Java');
    });
  });

  group('ApplyScreen', () {
    ApplyPlan plan() => ApplyPlan(
      project: sampleProject(id: 'p1'),
      profileName: 'Java',
      extensions: const ['a.b', 'c.d'],
      settingsPatch: const {'a': 2},
    );

    testWidgets('success: steps done, log lines, profile saved, open offered', (
      tester,
    ) async {
      final h = Harness(projects: [sampleProject(id: 'p1')]);
      await h.pump(tester, ApplyScreen(plan: plan()));

      expect(find.byIcon(Icons.check_circle_rounded), findsNWidgets(2));
      expect(find.text('Installing a.b'), findsOneWidget);
      expect(find.text(en.applySettingsWritten), findsOneWidget);
      expect(
        find.text(en.applySettingsBackup('/p/settings.json.bak.1')),
        findsOneWidget,
      );
      expect(find.text(en.applyDone), findsOneWidget);
      // 이후 목록의 "열기"가 이 프로필로 열리도록 저장된다.
      expect(h.store.saved.single.profileName, 'Java');

      await _tapText(tester, en.projectOpen);
      expect(h.service.opened.single.$2, 'Java');
      expect(h.store.saved.single.lastOpenedAt, isNotNull);
    });

    testWidgets('no extensions: says so and still writes settings', (
      tester,
    ) async {
      final h = Harness(projects: [sampleProject(id: 'p1')]);
      await h.pump(
        tester,
        ApplyScreen(
          plan: ApplyPlan(
            project: sampleProject(id: 'p1'),
            profileName: 'Java',
            extensions: const [],
            settingsPatch: const {},
          ),
        ),
      );
      expect(find.text(en.applyNoExtensions), findsOneWidget);
      expect(find.text(en.applyDone), findsOneWidget);
    });

    testWidgets('failure: names the step, saves nothing, retry runs again', (
      tester,
    ) async {
      final h = Harness(projects: [sampleProject(id: 'p1')]);
      var runs = 0;
      h.service.onApply = (plan) {
        runs++;
        return runs == 1
            ? Stream.fromIterable(const [
                StepStarted(ApplyStep.extensions),
                ExtensionStarted('a.b'),
                ExtensionOutput('a.b', 'not found', isError: true),
                ExtensionFinished('a.b', ok: false, exitCode: 1),
                StepFailed(ApplyStep.extensions, 'a.b'),
              ])
            : Stream.fromIterable(successEvents(plan));
      };
      await h.pump(tester, ApplyScreen(plan: plan()));

      expect(
        find.text(en.applyFailedStep(en.applyStepExtensions, 'a.b')),
        findsOneWidget,
      );
      expect(find.text(en.applyExtFailed('a.b', '1')), findsOneWidget);
      expect(find.byIcon(Icons.error_rounded), findsOneWidget);
      expect(h.store.saved.single.profileName, isNull);
      expect(find.text(en.projectOpen), findsNothing);

      await _tapText(tester, en.commonRetry);
      expect(runs, 2);
      expect(find.text(en.applyDone), findsOneWidget);
      expect(h.store.saved.single.profileName, 'Java');
    });

    testWidgets('a settings failure marks the settings step', (tester) async {
      final h = Harness(projects: [sampleProject(id: 'p1')]);
      h.service.onApply = (_) => Stream.fromIterable(const [
        StepStarted(ApplyStep.extensions),
        StepFinished(ApplyStep.extensions),
        StepStarted(ApplyStep.settings),
        StepFailed(ApplyStep.settings, 'JSON 문법 오류'),
      ]);
      await h.pump(tester, ApplyScreen(plan: plan()));
      expect(
        find.text(en.applyFailedStep(en.applyStepSettings, 'JSON 문법 오류')),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
      expect(find.byIcon(Icons.error_rounded), findsOneWidget);
    });
  });

  group('SettingsScreen', () {
    testWidgets('save stores the code path; empty clears it', (tester) async {
      final h = Harness();
      await h.pump(tester, const SettingsScreen());
      await tester.enterText(find.byType(TextField), r'C:\VS\bin\code.cmd');
      await _tapText(tester, en.settingsSave);
      expect(h.configStore.saved.codePath, r'C:\VS\bin\code.cmd');
      expect(find.text(en.settingsSaved), findsOneWidget);

      await tester.enterText(find.byType(TextField), '  ');
      await _tapText(tester, en.settingsSave);
      expect(h.configStore.saved.codePath, isNull);
    });

    testWidgets('check runs code --version and shows the result', (
      tester,
    ) async {
      final runner = FakeProcessRunner()
        ..onArgs(
          ['--version'],
          output: const ProcessOutput(
            exitCode: 0,
            stdout: '1.99.0\nabc\nx64\n',
          ),
        );
      final h = Harness(runner: runner);
      await h.pump(tester, const SettingsScreen());
      await tester.enterText(find.byType(TextField), '/opt/code');
      await _tapText(tester, en.settingsTest);
      expect(find.text(en.settingsTestOk('1.99.0')), findsOneWidget);
      expect(runner.calls.single.executable, '/opt/code');
    });

    testWidgets('check failure is shown as an error', (tester) async {
      final runner = FakeProcessRunner()
        ..onArgs(
          ['--version'],
          output: const ProcessOutput(exitCode: -1, startError: 'not runnable'),
        );
      final h = Harness(runner: runner);
      await h.pump(tester, const SettingsScreen());
      await tester.enterText(find.byType(TextField), '/nope');
      await _tapText(tester, en.settingsTest);
      expect(find.textContaining('not runnable'), findsOneWidget);
    });

    testWidgets('the saved path is prefilled', (tester) async {
      final h = Harness(
        initialConfig: const AppConfig(codePath: '/saved/code'),
      );
      await h.pump(tester, const SettingsScreen());
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        '/saved/code',
      );
    });
  });

  testWidgets('whole flow: add → analyze → recommend → diff → apply → open', (
    tester,
  ) async {
    final h = Harness(
      projects: [sampleProject(id: 'p1', name: 'demo')],
    );
    await h.pump(tester, ProjectListScreen(onAbout: () {}));

    await tester.tap(find.byTooltip(en.projectAnalyze));
    await tester.pumpAndSettle();
    await _tapText(tester, en.analysisNext);

    // 선택 확장을 하나 켜고 필수 확장 하나를 끈다.
    final tiles = find.byType(CheckboxListTile);
    await tester.tap(tiles.at(1));
    await tester.tap(tiles.at(2));
    await tester.pump();
    await _tapText(tester, en.recommendNext);

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    await _tapText(tester, en.diffApply);

    final plan = h.service.applied.single;
    expect(plan.profileName, 'Java');
    expect(plan.extensions, [
      'vscjava.vscode-java-pack',
      'dbaeumer.vscode-eslint',
    ]);
    expect(plan.replaceConflicts, {'/a'});
    expect(find.text(en.applyDone), findsOneWidget);

    await _tapText(tester, en.applyBackToList);
    expect(find.text('demo'), findsOneWidget);
    expect(h.store.saved.single.profileName, 'Java');
    expect(h.store.saved.single.lastAnalysis, isNotNull);

    await _tapText(tester, en.projectOpen);
    expect(h.service.opened.single.$2, 'Java');
  });
}
