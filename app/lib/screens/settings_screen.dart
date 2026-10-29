import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:profile_engine/profile_engine.dart';

import '../l10n/app_localizations.dart';
import '../providers/providers.dart';
import '../services/app_config.dart';
import '../settings/settings_menus.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

/// 설정 대화상자: 데스크톱 전용 앱이라 모달로 띄운다 (settings-screen.md §1).
Future<void> showSettingsDialog(BuildContext context) =>
    showDialog<void>(context: context, builder: (_) => const SettingsScreen());

/// 앱 설정: 외형(모드·색 구성·언어)과 VS Code 실행 파일(`code`) 경로.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late final TextEditingController _codePath;
  String? _status;
  bool _statusIsError = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _codePath = TextEditingController(
      text: ref.read(appConfigProvider).codePath ?? '',
    );
  }

  @override
  void dispose() {
    _codePath.dispose();
    super.dispose();
  }

  void _setStatus(String text, {bool error = false}) => setState(() {
    _status = text;
    _statusIsError = error;
  });

  void _detect() {
    final l10n = AppLocalizations.of(context);
    final found = discoverCodePath();
    if (found == null) {
      _setStatus(l10n.settingsNotFound, error: true);
    } else {
      _codePath.text = found;
      _setStatus(l10n.settingsDetected(found));
    }
  }

  Future<void> _browse() async {
    final file = await FilePicker.pickFile();
    final path = file?.path;
    if (path != null && mounted) setState(() => _codePath.text = path);
  }

  Future<void> _test() async {
    final l10n = AppLocalizations.of(context);
    setState(() => _busy = true);
    final typed = _codePath.text.trim();
    final path = typed.isEmpty ? const AppConfig().effectiveCodePath : typed;
    final cli = VsCodeCli(ref.read(processRunnerProvider), codePath: path);
    final result = await cli.version();
    if (!mounted) return;
    setState(() => _busy = false);
    switch (result) {
      case Ok<String>(:final value):
        _setStatus(l10n.settingsTestOk(value));
      case Err<String>(:final error):
        _setStatus(l10n.settingsTestFailed(error.message), error: true);
    }
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    final typed = _codePath.text.trim();
    final notifier = ref.read(appConfigProvider.notifier);
    final current = ref.read(appConfigProvider);
    try {
      await notifier.update(
        typed.isEmpty
            ? current.copyWith(clearCodePath: true)
            : current.copyWith(codePath: typed),
      );
      if (mounted) _setStatus(l10n.settingsSaved);
    } on Object catch (e) {
      if (mounted) showErrorSnackBar(context, '$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return AlertDialog(
      title: Text(l10n.settingsTitle),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SectionHeader(l10n.settingsSectionAppearance),
              Text(l10n.settingsMode, style: theme.textTheme.bodySmall),
              const SizedBox(height: AppSpacing.xs),
              const ModeSegmentedButton(),
              const SizedBox(height: AppSpacing.md),
              Text(l10n.settingsPalette, style: theme.textTheme.bodySmall),
              const SizedBox(height: AppSpacing.xs),
              const AccentPaletteChips(),
              const SizedBox(height: AppSpacing.md),
              Text(l10n.languageMenuTooltip, style: theme.textTheme.bodySmall),
              const SizedBox(height: AppSpacing.xs),
              const LanguageSegmentedButton(),
              const SizedBox(height: AppSpacing.xl),
              SectionHeader(l10n.settingsCodePath),
              TextField(
                controller: _codePath,
                style: AppFonts.userContent,
                decoration: InputDecoration(hintText: l10n.settingsCodePathHint),
                onSubmitted: (_) => _save(),
              ),
              const SizedBox(height: AppSpacing.md),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  OutlinedButton(
                    onPressed: _detect,
                    child: Text(l10n.settingsDetect),
                  ),
                  OutlinedButton(
                    onPressed: _browse,
                    child: Text(l10n.settingsBrowse),
                  ),
                  OutlinedButton(
                    onPressed: _busy ? null : _test,
                    child: Text(l10n.settingsTest),
                  ),
                  FilledButton(onPressed: _save, child: Text(l10n.settingsSave)),
                ],
              ),
              if (_status != null) ...[
                const SizedBox(height: AppSpacing.md),
                Text(
                  _status!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: _statusIsError
                        ? theme.colorScheme.error
                        : successColor(context),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(l10n.commonClose)),
      ],
    );
  }
}
