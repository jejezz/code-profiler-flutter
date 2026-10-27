import 'dart:io';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:profile_engine/profile_engine.dart';

import '../app_identity.dart';
import '../l10n/app_localizations.dart';
import '../providers/providers.dart';
import '../settings/settings_menus.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../window/focus_tint.dart';
import 'analysis_screen.dart';
import 'settings_screen.dart';

/// 프로젝트 목록(홈). 폴더를 선택하거나 창에 끌어다 놓아 프로젝트를 추가한다.
class ProjectListScreen extends ConsumerStatefulWidget {
  const ProjectListScreen({super.key, required this.onAbout});

  final VoidCallback onAbout;

  @override
  ConsumerState<ProjectListScreen> createState() => _ProjectListScreenState();
}

class _ProjectListScreenState extends ConsumerState<ProjectListScreen> {
  bool _dragging = false;

  Future<void> _pickFolder() async {
    final l10n = AppLocalizations.of(context);
    final path = await FilePicker.getDirectoryPath(
      dialogTitle: l10n.projectPickFolderTitle,
    );
    if (path == null || !mounted) return;
    await _register([path]);
  }

  /// 폴더들을 목록에 넣고, 첫 번째 프로젝트의 분석 화면으로 간다.
  Future<void> _register(List<String> paths) async {
    final l10n = AppLocalizations.of(context);
    final notifier = ref.read(projectsProvider.notifier);
    Project? first;
    for (final path in paths) {
      if (!mounted) return;
      if (!Directory(path).existsSync()) {
        showErrorSnackBar(context, l10n.projectDropNotFolder(p.basename(path)));
        continue;
      }
      try {
        final added = await notifier.addLocal(path);
        first ??= added;
      } on Object catch (e) {
        if (mounted) showErrorSnackBar(context, '$e');
      }
    }
    if (first != null && mounted) _openAnalysis(first);
  }

  void _openAnalysis(Project project) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AnalysisScreen(projectId: project.id),
      ),
    );
  }

  Future<void> _open(Project project) async {
    final profile = project.profileName;
    if (profile == null) return;
    final l10n = AppLocalizations.of(context);
    final result = await ref
        .read(projectServiceProvider)
        .open(project, profile);
    if (!mounted) return;
    switch (result) {
      case Err<void>(:final error):
        showErrorSnackBar(context, l10n.openFailed(error.message));
      case Ok<void>():
        await ref.read(projectsProvider.notifier).markOpened(project.id);
    }
  }

  Future<void> _confirmRemove(Project project) async {
    final l10n = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.projectRemoveTitle),
        content: Text(l10n.projectRemoveBody(project.name)),
        actions: [
          // 위험한 작업은 기본 포커스를 취소에 둔다 (ui-ux.md §6).
          TextButton(
            autofocus: true,
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.projectRemove),
          ),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(projectsProvider.notifier).remove(project.id);
    }
  }

  void _openSettings() {
    Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => const SettingsScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final projects = ref.watch(projectsProvider);

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyO, control: true):
            _pickFolder,
        const SingleActivator(LogicalKeyboardKey.keyO, meta: true): _pickFolder,
        const SingleActivator(LogicalKeyboardKey.comma, control: true):
            _openSettings,
        const SingleActivator(LogicalKeyboardKey.comma, meta: true):
            _openSettings,
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          appBar: AppBar(
            flexibleSpace: const FocusTint(),
            title: const Text(AppIdentity.displayName),
            actions: [
              IconButton(
                tooltip: l10n.appSettingsTooltip,
                icon: const Icon(Icons.settings_outlined),
                onPressed: _openSettings,
              ),
              const ThemeMenuButton(),
              const LanguageMenuButton(),
              IconButton(
                tooltip: l10n.aboutTooltip,
                icon: const Icon(Icons.info_outline_rounded),
                onPressed: widget.onAbout,
              ),
              const SizedBox(width: AppSpacing.sm),
            ],
          ),
          body: DropTarget(
            onDragEntered: (_) => setState(() => _dragging = true),
            onDragExited: (_) => setState(() => _dragging = false),
            onDragDone: (details) {
              setState(() => _dragging = false);
              _register([for (final f in details.files) f.path]);
            },
            child: Stack(
              children: [
                projects.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.xl),
                      child: Text(l10n.projectLoadError('$e')),
                    ),
                  ),
                  data: (list) => list.isEmpty
                      ? _EmptyState(onAdd: _pickFolder)
                      : _ProjectList(
                          projects: list,
                          onAdd: _pickFolder,
                          onOpen: _open,
                          onAnalyze: _openAnalysis,
                          onRemove: _confirmRemove,
                        ),
                ),
                if (_dragging) _DropOverlay(text: l10n.projectDropHere),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(AppIdentity.iconAsset, width: 48, height: 48),
          const SizedBox(height: AppSpacing.lg),
          Text(
            l10n.homeEmptyTitle,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.lg),
          FilledButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.create_new_folder_outlined, size: 18),
            label: Text(l10n.projectAdd),
          ),
        ],
      ),
    );
  }
}

class _DropOverlay extends StatelessWidget {
  const _DropOverlay({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Positioned.fill(
      child: IgnorePointer(
        child: Container(
          margin: const EdgeInsets.all(AppSpacing.sm),
          decoration: BoxDecoration(
            color: primary.withValues(alpha: 0.08),
            border: Border.all(color: primary, width: 2),
            borderRadius: BorderRadius.circular(AppRadius.tile),
          ),
          alignment: Alignment.center,
          child: Text(
            text,
            style: Theme.of(context).textTheme.titleMedium
                ?.copyWith(color: primary, fontWeight: FontWeight.w800),
          ),
        ),
      ),
    );
  }
}

class _ProjectList extends StatelessWidget {
  const _ProjectList({
    required this.projects,
    required this.onAdd,
    required this.onOpen,
    required this.onAnalyze,
    required this.onRemove,
  });

  final List<Project> projects;
  final VoidCallback onAdd;
  final void Function(Project) onOpen;
  final void Function(Project) onAnalyze;
  final void Function(Project) onRemove;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return PageBody(
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.create_new_folder_outlined, size: 18),
              label: Text(l10n.projectAdd),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          for (final project in projects)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: _ProjectTile(
                project: project,
                onOpen: () => onOpen(project),
                onAnalyze: () => onAnalyze(project),
                onRemove: () => onRemove(project),
              ),
            ),
        ],
      ),
    );
  }
}

class _ProjectTile extends StatelessWidget {
  const _ProjectTile({
    required this.project,
    required this.onOpen,
    required this.onAnalyze,
    required this.onRemove,
  });

  final Project project;
  final VoidCallback onOpen;
  final VoidCallback onAnalyze;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final location = project.location;
    final path = switch (location) {
      LocalLocation(:final path) => path,
      SshLocation(:final host, :final path) => '$host:$path',
    };
    final primaryType = project.lastAnalysis?.types.firstOrNull;
    final locale = Localizations.localeOf(context).toString();
    final opened = project.lastOpenedAt;
    final canOpen = project.profileName != null;

    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.card),
        onTap: onAnalyze,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          child: Row(
            children: [
              Icon(
                Icons.folder_outlined,
                size: 22,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      project.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w700)
                          .merge(AppFonts.userContent),
                    ),
                    Text(
                      path,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: pathStyle(context),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.xs,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Pill(
                          location is LocalLocation
                              ? l10n.projectLocal
                              : (location as SshLocation).host,
                          color: theme.colorScheme.onSurfaceVariant,
                          icon: location is LocalLocation
                              ? Icons.computer_outlined
                              : Icons.cloud_outlined,
                        ),
                        Pill(primaryType?.label ?? l10n.projectNoAnalysis),
                        Pill(
                          project.profileName ?? l10n.projectNoProfile,
                          color: project.profileName == null
                              ? theme.colorScheme.onSurfaceVariant
                              : successColor(context),
                        ),
                        Text(
                          opened == null
                              ? l10n.projectNeverOpened
                              : l10n.projectLastOpened(
                                  DateFormat.yMd(locale)
                                      .add_Hm()
                                      .format(opened.toLocal()),
                                ),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Tooltip(
                message: canOpen
                    ? l10n.projectOpen
                    : l10n.projectOpenNeedsProfile,
                child: FilledButton.tonalIcon(
                  onPressed: canOpen ? onOpen : null,
                  icon: const Icon(Icons.open_in_new_rounded, size: 16),
                  label: Text(l10n.projectOpen),
                ),
              ),
              IconButton(
                tooltip: l10n.projectAnalyze,
                icon: const Icon(Icons.travel_explore_rounded),
                onPressed: onAnalyze,
              ),
              IconButton(
                tooltip: l10n.projectRemove,
                icon: const Icon(Icons.delete_outline_rounded),
                onPressed: onRemove,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
