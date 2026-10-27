import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:profile_engine/profile_engine.dart';

import '../l10n/app_localizations.dart';
import '../providers/providers.dart';
import '../services/project_service.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../window/focus_tint.dart';
import 'recommendation_screen.dart';

/// 폴더를 분석해 판정된 유형과 근거를 보여준다.
class AnalysisScreen extends ConsumerStatefulWidget {
  const AnalysisScreen({super.key, required this.projectId});

  final String projectId;

  @override
  ConsumerState<AnalysisScreen> createState() => _AnalysisScreenState();
}

class _AnalysisScreenState extends ConsumerState<AnalysisScreen> {
  late Future<Result<AnalysisBundle>> _future;
  Project? _project;

  @override
  void initState() {
    super.initState();
    _future = _run();
  }

  /// 목록이 아직 읽히는 중일 수 있으므로 읽기가 끝나길 기다린 뒤 찾는다.
  Future<Project?> _lookup() async {
    final projects = await ref.read(projectsProvider.future);
    return projects.where((p) => p.id == widget.projectId).firstOrNull;
  }

  Future<Result<AnalysisBundle>> _run() async {
    final project = await _lookup();
    if (project == null) {
      return const Err(EngineError('프로젝트를 찾을 수 없습니다'));
    }
    _project = project;
    final result = await ref.read(projectServiceProvider).analyze(project);
    if (result is Ok<AnalysisBundle>) {
      // 마지막 분석 결과를 저장해 목록에 유형을 표시한다.
      final updated = project.copyWith(lastAnalysis: result.value.analysis);
      _project = updated;
      await ref.read(projectsProvider.notifier).upsert(updated);
    }
    return result;
  }

  void _retry() {
    // setState 안에서 Future를 돌려주면 안 되므로, Future를 먼저 만든 뒤 상태에 넣는다.
    final next = _run();
    setState(() {
      _future = next;
    });
  }

  void _next(AnalysisBundle bundle) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            RecommendationScreen(project: _project!, bundle: bundle),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        flexibleSpace: const FocusTint(),
        title: Text(l10n.analysisTitle),
      ),
      body: FutureBuilder<Result<AnalysisBundle>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: AppSpacing.lg),
                  Text(l10n.analysisRunning),
                ],
              ),
            );
          }
          final result = snapshot.data;
          if (snapshot.hasError || result == null) {
            return _Failure(message: '${snapshot.error}', onRetry: _retry);
          }
          return switch (result) {
            Err<AnalysisBundle>(:final error) => _Failure(
              message: error.message,
              onRetry: _retry,
            ),
            Ok<AnalysisBundle>(:final value) => _Result(
              project: _project!,
              bundle: value,
              onNext: () => _next(value),
            ),
          };
        },
      ),
    );
  }
}

class _Failure extends StatelessWidget {
  const _Failure({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: PageBody(
        maxWidth: 560,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              InfoBanner(
                title: l10n.analysisFailed,
                text: message,
                color: Theme.of(context).colorScheme.error,
                icon: Icons.error_outline_rounded,
              ),
              const SizedBox(height: AppSpacing.lg),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: Text(l10n.commonRetry),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Result extends StatelessWidget {
  const _Result({
    required this.project,
    required this.bundle,
    required this.onNext,
  });

  final Project project;
  final AnalysisBundle bundle;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final analysis = bundle.analysis;
    final stats = analysis.stats;
    final canContinue = bundle.recommendation != null;

    return Column(
      children: [
        Expanded(
          child: PageBody(
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                Text(
                  project.name,
                  style: theme.textTheme.titleLarge?.merge(
                    AppFonts.userContent,
                  ),
                ),
                if (project.location is LocalLocation)
                  Text(
                    (project.location as LocalLocation).path,
                    style: pathStyle(context),
                  ),
                const SizedBox(height: AppSpacing.lg),
                if (bundle.competitors.isNotEmpty) ...[
                  InfoBanner(
                    title: l10n.analysisCompetitorsTitle,
                    text: l10n.analysisCompetitorsBody(
                      bundle.competitors.map((t) => t.label).join(', '),
                    ),
                    color: warningColor(context),
                    icon: Icons.alt_route_rounded,
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],
                if (analysis.types.isEmpty)
                  InfoBanner(
                    text: l10n.analysisNoTypes,
                    color: warningColor(context),
                    icon: Icons.help_outline_rounded,
                  )
                else
                  for (var i = 0; i < analysis.types.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: _TypeCard(
                        type: analysis.types[i],
                        primary: i == 0,
                      ),
                    ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  l10n.analysisStats(stats.fileCount.toString()),
                  style: theme.textTheme.bodySmall,
                ),
                if (stats.truncated) ...[
                  const SizedBox(height: AppSpacing.sm),
                  InfoBanner(
                    text: l10n.analysisTruncated,
                    color: warningColor(context),
                    icon: Icons.content_cut_rounded,
                  ),
                ],
                if (stats.largeDirsPresent.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.xs),
                    child: Text(
                      l10n.analysisSkippedDirs(
                        stats.largeDirsPresent.join(', '),
                      ),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                if (analysis.variables.isNotEmpty) ...[
                  SectionHeader(l10n.analysisVariables),
                  for (final e in analysis.variables.entries)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                      child: SelectableText(
                        '${e.key} = ${e.value}',
                        style: monoStyle(context),
                      ),
                    ),
                ],
              ],
            ),
          ),
        ),
        BottomActionBar(
          child: FilledButton.icon(
            onPressed: canContinue ? onNext : null,
            icon: const Icon(Icons.arrow_forward_rounded, size: 18),
            label: Text(l10n.analysisNext),
          ),
        ),
      ],
    );
  }
}

class _TypeCard extends StatelessWidget {
  const _TypeCard({required this.type, required this.primary});

  final DetectedType type;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: ExpansionTile(
        initiallyExpanded: primary,
        shape: const Border(),
        collapsedShape: const Border(),
        title: Row(
          children: [
            Flexible(
              child: Text(
                type.label,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            if (primary) ...[
              const SizedBox(width: AppSpacing.sm),
              Pill(l10n.analysisPrimaryBadge, icon: Icons.star_rounded),
            ],
            const SizedBox(width: AppSpacing.sm),
            Pill(
              l10n.analysisPriority(type.priority.toString()),
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ],
        ),
        childrenPadding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          0,
          AppSpacing.lg,
          AppSpacing.md,
        ),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final e in type.evidence)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.check_rounded,
                    size: 16,
                    color: successColor(context),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      e.description,
                      style: theme.textTheme.bodyMedium?.merge(
                        AppFonts.userContent,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
