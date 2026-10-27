import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:profile_engine/profile_engine.dart';

import '../l10n/app_localizations.dart';
import '../providers/providers.dart';
import '../services/app_config.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../window/focus_tint.dart';

/// 앱 설정. 지금은 VS Code 실행 파일(`code`) 경로만 다룬다.
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
    return Scaffold(
      appBar: AppBar(
        flexibleSpace: const FocusTint(),
        title: Text(l10n.settingsTitle),
      ),
      body: PageBody(
        maxWidth: 720,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
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
    );
  }
}
