import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:profile_engine/profile_engine.dart';

import '../l10n/app_localizations.dart';
import '../providers/providers.dart';
import '../services/analysis_hints.dart';
import '../services/project_service.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../window/focus_tint.dart';
import 'apply_screen.dart';

/// `.vscode/settings.json`에 무엇이 바뀌는지 미리 보여주고, 충돌 항목별로 교체 여부를 고르게 한다.
/// 이 화면이 설정 파일을 쓰기 전의 확인 단계다(아키텍처 규칙 7).
class DiffScreen extends ConsumerStatefulWidget {
  const DiffScreen({super.key, required this.plan});

  final ApplyPlan plan;

  @override
  ConsumerState<DiffScreen> createState() => _DiffScreenState();
}

class _DiffScreenState extends ConsumerState<DiffScreen> {
  final Set<String> _replace = {};
  SettingsDiff? _diff;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  /// 교체 선택이 바뀔 때마다 다시 계산한다. 새 결과가 올 때까지 이전 결과를 그대로 둔다.
  Future<void> _reload() async {
    setState(() => _loading = true);
    final r = await ref.read(projectServiceProvider).diff(
      widget.plan.project,
      widget.plan.settingsPatch,
      {..._replace},
    );
    if (!mounted) return;
    setState(() {
      _loading = false;
      switch (r) {
        case Ok<SettingsDiff>(:final value):
          _diff = value;
          _error = null;
        case Err<SettingsDiff>(:final error):
          _error = error.toString();
      }
    });
  }

  void _toggle(String pointer, bool replace) {
    if (replace) {
      _replace.add(pointer);
    } else {
      _replace.remove(pointer);
    }
    _reload();
  }

  void _apply() {
    final plan = ApplyPlan(
      project: widget.plan.project,
      profileName: widget.plan.profileName,
      extensions: widget.plan.extensions,
      settingsPatch: widget.plan.settingsPatch,
      replaceConflicts: {..._replace},
    );
    Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => ApplyScreen(plan: plan)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final diff = _diff;

    return Scaffold(
      appBar: AppBar(
        flexibleSpace: const FocusTint(),
        title: Text(l10n.diffTitle),
      ),
      body: Column(
        children: [
          if (_loading) const LinearProgressIndicator(minHeight: 2),
          Expanded(
            child: _error != null
                ? PageBody(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: InfoBanner(
                        title: l10n.diffFailed,
                        text: _error!,
                        color: Theme.of(context).colorScheme.error,
                        icon: Icons.error_outline_rounded,
                      ),
                    ),
                  )
                : diff == null
                ? Center(child: Text(l10n.diffLoading))
                : _DiffBody(diff: diff, replace: _replace, onToggle: _toggle),
          ),
          BottomActionBar(
            child: FilledButton.icon(
              onPressed: diff == null || _error != null || _loading
                  ? null
                  : _apply,
              icon: const Icon(Icons.check_rounded, size: 18),
              label: Text(l10n.diffApply),
            ),
          ),
        ],
      ),
    );
  }
}

class _DiffBody extends StatelessWidget {
  const _DiffBody({
    required this.diff,
    required this.replace,
    required this.onToggle,
  });

  final SettingsDiff diff;
  final Set<String> replace;
  final void Function(String pointer, bool replace) onToggle;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final added = diff.added;
    final conflicts = diff.conflicts;
    final unchanged = diff.unchanged;

    return PageBody(
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          if (!diff.existingFile)
            InfoBanner(text: l10n.diffNewFile)
          else if (!diff.hasChanges)
            InfoBanner(text: l10n.diffNoChange),
          if (diff.commentsWillBeLost && diff.hasChanges)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: InfoBanner(
                text: l10n.diffCommentsWarning,
                color: warningColor(context),
                icon: Icons.warning_amber_rounded,
              ),
            ),
          if (added.isNotEmpty) ...[
            SectionHeader(l10n.diffAdded(added.length.toString())),
            for (final c in added) _ChangeRow(change: c),
          ],
          if (conflicts.isNotEmpty) ...[
            SectionHeader(l10n.diffConflicts(conflicts.length.toString())),
            for (final c in conflicts)
              _ConflictRow(
                change: c,
                replaced: replace.contains(c.pointer),
                onChanged: (v) => onToggle(c.pointer, v),
              ),
          ],
          if (unchanged.isNotEmpty) ...[
            SectionHeader(l10n.diffUnchanged(unchanged.length.toString())),
            Card(
              margin: EdgeInsets.zero,
              child: ExpansionTile(
                shape: const Border(),
                collapsedShape: const Border(),
                title: Text(
                  unchanged
                      .map((c) => pointerSegments(c.pointer).join(' › '))
                      .join(', '),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: monoStyle(context),
                ),
              ),
            ),
          ],
          if (diff.hasChanges) ...[
            SectionHeader(l10n.diffMergedPreview),
            Card(
              margin: EdgeInsets.zero,
              child: ExpansionTile(
                shape: const Border(),
                collapsedShape: const Border(),
                title: Text('settings.json', style: monoStyle(context)),
                childrenPadding: const EdgeInsets.all(AppSpacing.lg),
                expandedAlignment: Alignment.centerLeft,
                children: [
                  SelectableText(diff.mergedJson, style: monoStyle(context)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _KeyText extends StatelessWidget {
  const _KeyText(this.pointer);

  final String pointer;

  @override
  Widget build(BuildContext context) => Text(
    pointerSegments(pointer).join(' › '),
    style: monoStyle(context)?.copyWith(fontWeight: FontWeight.w700),
  );
}

class _ChangeRow extends StatelessWidget {
  const _ChangeRow({required this.change});

  final SettingChange change;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.add_rounded, size: 16, color: successColor(context)),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _KeyText(change.pointer),
                Text(previewValue(change.patch), style: monoStyle(context)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ConflictRow extends StatelessWidget {
  const _ConflictRow({
    required this.change,
    required this.replaced,
    required this.onChanged,
  });

  final SettingChange change;
  final bool replaced;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.compare_arrows_rounded,
            size: 16,
            color: warningColor(context),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _KeyText(change.pointer),
                Text(
                  '${l10n.diffExisting}: ${previewValue(change.existing)}',
                  style: monoStyle(context),
                ),
                Text(
                  '${l10n.diffPatch}: ${previewValue(change.patch)}',
                  style: monoStyle(context),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Text(l10n.diffReplace, style: Theme.of(context).textTheme.bodySmall),
          Switch(value: replaced, onChanged: onChanged),
        ],
      ),
    );
  }
}
