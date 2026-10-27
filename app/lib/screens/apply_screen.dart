import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:profile_engine/profile_engine.dart';

import '../l10n/app_localizations.dart';
import '../providers/providers.dart';
import '../services/project_service.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../window/focus_tint.dart';

enum _StepState { pending, running, done, failed }

class _LogLine {
  const _LogLine(this.text, {this.isError = false});

  final String text;
  final bool isError;
}

/// 확장 설치 → 설정 쓰기를 차례로 실행하고 진행 상황을 줄 단위 로그로 보여준다.
class ApplyScreen extends ConsumerStatefulWidget {
  const ApplyScreen({super.key, required this.plan});

  final ApplyPlan plan;

  @override
  ConsumerState<ApplyScreen> createState() => _ApplyScreenState();
}

class _ApplyScreenState extends ConsumerState<ApplyScreen> {
  final Map<ApplyStep, _StepState> _steps = {
    for (final s in ApplyStep.values) s: _StepState.pending,
  };
  final List<_LogLine> _log = [];
  final _scroll = ScrollController();
  StreamSubscription<ApplyEvent>? _subscription;
  String? _failure;
  bool _running = false;
  bool _succeeded = false;

  @override
  void initState() {
    super.initState();
    // 화면이 그려진 뒤에 시작해야 AppLocalizations를 안전하게 읽을 수 있다.
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _scroll.dispose();
    super.dispose();
  }

  String _stepLabel(ApplyStep step) {
    final l10n = AppLocalizations.of(context);
    return switch (step) {
      ApplyStep.extensions => l10n.applyStepExtensions,
      ApplyStep.settings => l10n.applyStepSettings,
    };
  }

  void _start() {
    if (!mounted) return;
    setState(() {
      for (final s in ApplyStep.values) {
        _steps[s] = _StepState.pending;
      }
      _log.clear();
      _failure = null;
      _succeeded = false;
      _running = true;
    });
    _subscription = ref
        .read(projectServiceProvider)
        .apply(widget.plan)
        .listen(
          _onEvent,
          onError: (Object e) => _fail(ApplyStep.extensions, '$e'),
          onDone: _onDone,
        );
  }

  void _add(String text, {bool isError = false}) {
    _log.add(_LogLine(text, isError: isError));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.jumpTo(_scroll.position.maxScrollExtent);
      }
    });
  }

  void _fail(ApplyStep step, String message) {
    final l10n = AppLocalizations.of(context);
    setState(() {
      _steps[step] = _StepState.failed;
      _failure = l10n.applyFailedStep(_stepLabel(step), message);
      _running = false;
    });
  }

  void _onEvent(ApplyEvent event) {
    final l10n = AppLocalizations.of(context);
    setState(() {
      switch (event) {
        case StepStarted(:final step):
          _steps[step] = _StepState.running;
          if (step == ApplyStep.extensions && widget.plan.extensions.isEmpty) {
            _add(l10n.applyNoExtensions);
          }
        case ExtensionSkipped(:final id):
          _add(l10n.applyExtSkipped(id));
        case ExtensionStarted(:final id):
          _add(l10n.applyExtInstalling(id));
        case ExtensionOutput(:final line, :final isError):
          _add(line, isError: isError);
        case ExtensionFinished(:final id, :final ok, :final exitCode):
          if (!ok) {
            _add(l10n.applyExtFailed(id, exitCode.toString()), isError: true);
          }
        case StepFinished(:final step, :final written, :final backupPath):
          _steps[step] = _StepState.done;
          if (step == ApplyStep.settings) {
            if (written == true) {
              _add(l10n.applySettingsWritten);
              if (backupPath != null) {
                _add(l10n.applySettingsBackup(backupPath));
              }
            } else {
              _add(l10n.applySettingsUnchanged);
            }
          }
        case StepFailed(:final step, :final message):
          _steps[step] = _StepState.failed;
          _failure = l10n.applyFailedStep(_stepLabel(step), message);
      }
    });
  }

  Future<void> _onDone() async {
    if (!mounted) return;
    if (_failure != null) {
      setState(() => _running = false);
      return;
    }
    // 프로필 이름을 프로젝트에 기록한다. 이후 목록의 "열기"는 항상 이 프로필로 연다.
    try {
      await ref
          .read(projectsProvider.notifier)
          .upsert(
            widget.plan.project.copyWith(profileName: widget.plan.profileName),
          );
    } on Object catch (e) {
      if (mounted) {
        showErrorSnackBar(
          context,
          AppLocalizations.of(context).applySaveFailed('$e'),
        );
      }
    }
    if (mounted) {
      setState(() {
        _running = false;
        _succeeded = true;
      });
    }
  }

  Future<void> _openInVsCode() async {
    final l10n = AppLocalizations.of(context);
    final project = widget.plan.project;
    final result = await ref
        .read(projectServiceProvider)
        .open(project, widget.plan.profileName);
    if (!mounted) return;
    switch (result) {
      case Err<void>(:final error):
        showErrorSnackBar(context, l10n.openFailed(error.message));
      case Ok<void>():
        await ref.read(projectsProvider.notifier).markOpened(project.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return PopScope(
      // 실행 중에는 뒤로 가지 못하게 한다 — 설치가 끝나기 전에 화면이 사라지면 결과를 알 수 없다.
      canPop: !_running,
      child: Scaffold(
        appBar: AppBar(
          flexibleSpace: const FocusTint(),
          automaticallyImplyLeading: !_running,
          title: Text(l10n.applyTitle),
        ),
        body: Column(
          children: [
            Expanded(
              child: PageBody(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final step in ApplyStep.values)
                        _StepRow(label: _stepLabel(step), state: _steps[step]!),
                      const SizedBox(height: AppSpacing.md),
                      Expanded(
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(AppSpacing.md),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerLowest,
                            border: Border.all(
                              color: theme.colorScheme.outlineVariant,
                            ),
                            borderRadius: BorderRadius.circular(
                              AppRadius.button + 4,
                            ),
                          ),
                          child: ListView.builder(
                            controller: _scroll,
                            itemCount: _log.length,
                            itemBuilder: (_, i) => SelectableText(
                              _log[i].text,
                              style: monoStyle(context)?.copyWith(
                                color: _log[i].isError
                                    ? theme.colorScheme.error
                                    : null,
                              ),
                            ),
                          ),
                        ),
                      ),
                      if (_failure != null) ...[
                        const SizedBox(height: AppSpacing.md),
                        InfoBanner(
                          text: _failure!,
                          color: theme.colorScheme.error,
                          icon: Icons.error_outline_rounded,
                        ),
                      ],
                      if (_succeeded) ...[
                        const SizedBox(height: AppSpacing.md),
                        InfoBanner(
                          text: l10n.applyDone,
                          color: successColor(context),
                          icon: Icons.check_circle_outline_rounded,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            BottomActionBar(
              leading: Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: _running
                      ? null
                      : () => Navigator.of(context).popUntil((r) => r.isFirst),
                  child: Text(l10n.applyBackToList),
                ),
              ),
              child: _succeeded
                  ? FilledButton.icon(
                      onPressed: _openInVsCode,
                      icon: const Icon(Icons.open_in_new_rounded, size: 18),
                      label: Text(l10n.projectOpen),
                    )
                  : OutlinedButton.icon(
                      onPressed: _running || _failure == null ? null : _start,
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      label: Text(l10n.commonRetry),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({required this.label, required this.state});

  final String label;
  final _StepState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final Widget icon = switch (state) {
      _StepState.pending => Icon(
        Icons.radio_button_unchecked_rounded,
        size: 18,
        color: theme.colorScheme.onSurfaceVariant,
      ),
      _StepState.running => const SizedBox(
        width: 16,
        height: 16,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
      _StepState.done => Icon(
        Icons.check_circle_rounded,
        size: 18,
        color: successColor(context),
      ),
      _StepState.failed => Icon(
        Icons.error_rounded,
        size: 18,
        color: theme.colorScheme.error,
      ),
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: [
          SizedBox(width: 20, child: Center(child: icon)),
          const SizedBox(width: AppSpacing.md),
          Text(label, style: theme.textTheme.bodyLarge),
        ],
      ),
    );
  }
}
