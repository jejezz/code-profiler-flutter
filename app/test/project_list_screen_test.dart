import 'package:code_profiler/screens/project_list_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:profile_engine/profile_engine.dart';

import 'screen_helpers.dart';

void main() {
  Widget home() => ProjectListScreen(onAbout: () {});

  testWidgets('empty state: icon, one line and the primary action', (
    tester,
  ) async {
    await Harness().pump(tester, home());
    expect(find.text(en.homeEmptyTitle), findsOneWidget);
    expect(find.widgetWithText(FilledButton, en.projectAdd), findsOneWidget);
  });

  testWidgets('lists projects with type and profile', (tester) async {
    final h = Harness(
      projects: [
        sampleProject(
          id: 'a',
          name: 'alpha',
          profile: 'Java',
          analysis: sampleAnalysis(),
        ),
        sampleProject(id: 'b', name: 'beta'),
      ],
    );
    await h.pump(tester, home());
    expect(find.text('alpha'), findsOneWidget);
    expect(find.text('beta'), findsOneWidget);
    expect(find.text('Java (Maven)'), findsOneWidget);
    expect(find.text('Java'), findsOneWidget);
    expect(find.text(en.projectNoAnalysis), findsOneWidget);
    expect(find.text(en.projectNoProfile), findsOneWidget);
    expect(find.text(en.projectNeverOpened), findsNWidgets(2));
  });

  testWidgets('open is enabled only for a project with a profile', (
    tester,
  ) async {
    final h = Harness(
      projects: [
        sampleProject(id: 'a', name: 'alpha', profile: 'Java'),
        sampleProject(id: 'b', name: 'beta'),
      ],
    );
    await h.pump(tester, home());
    final buttons = tester
        .widgetList<ButtonStyleButton>(
          find.byWidgetPredicate(
            (w) => w is ButtonStyleButton && w is FilledButton,
          ),
        )
        .toList();
    final openButtons = find.widgetWithText(FilledButton, en.projectOpen);
    expect(openButtons, findsNWidgets(2));
    expect(tester.widget<FilledButton>(openButtons.at(0)).onPressed, isNotNull);
    expect(tester.widget<FilledButton>(openButtons.at(1)).onPressed, isNull);
    expect(buttons, isNotEmpty);
  });

  testWidgets('open runs the project with its profile and records the time', (
    tester,
  ) async {
    final h = Harness(projects: [sampleProject(profile: 'C++ AOSP')]);
    await h.pump(tester, home());
    await tester.tap(find.widgetWithText(FilledButton, en.projectOpen));
    await tester.pumpAndSettle();
    expect(h.service.opened.single.$2, 'C++ AOSP');
    expect(h.store.saved.single.lastOpenedAt, isNotNull);
  });

  testWidgets('a failed open shows the error', (tester) async {
    final h = Harness(projects: [sampleProject(profile: 'Java')]);
    h.service.onOpen = (_, _) async => const Err(EngineError('boom'));
    await h.pump(tester, home());
    await tester.tap(find.widgetWithText(FilledButton, en.projectOpen));
    await tester.pumpAndSettle();
    expect(find.text(en.openFailed('boom')), findsOneWidget);
    expect(h.store.saved.single.lastOpenedAt, isNull);
  });

  testWidgets('remove asks first; cancel keeps the project', (tester) async {
    final h = Harness(projects: [sampleProject(name: 'alpha')]);
    await h.pump(tester, home());
    await tester.tap(find.byTooltip(en.projectRemove));
    await tester.pumpAndSettle();
    expect(find.text(en.projectRemoveTitle), findsOneWidget);
    expect(find.text(en.projectRemoveBody('alpha')), findsOneWidget);

    await tester.tap(find.text(en.commonCancel));
    await tester.pumpAndSettle();
    expect(h.store.saved, hasLength(1));
    expect(find.text('alpha'), findsOneWidget);
  });

  testWidgets('remove confirmed drops it from the list and the store', (
    tester,
  ) async {
    final h = Harness(projects: [sampleProject(name: 'alpha')]);
    await h.pump(tester, home());
    await tester.tap(find.byTooltip(en.projectRemove));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, en.projectRemove));
    await tester.pumpAndSettle();
    expect(h.store.saved, isEmpty);
    expect(find.text(en.homeEmptyTitle), findsOneWidget);
  });

  testWidgets('the analyze button opens the analysis screen', (tester) async {
    final h = Harness(
      projects: [sampleProject(id: 'a', name: 'alpha')],
    );
    await h.pump(tester, home());
    await tester.tap(find.byTooltip(en.projectAnalyze));
    await tester.pumpAndSettle();
    expect(find.text(en.analysisTitle), findsOneWidget);
    expect(h.service.analyzed.single.id, 'a');
  });

  testWidgets('settings button opens the settings screen', (tester) async {
    await Harness().pump(tester, home());
    await tester.tap(find.byTooltip(en.appSettingsTooltip));
    await tester.pumpAndSettle();
    expect(find.text(en.settingsCodePath), findsOneWidget);
  });
}
