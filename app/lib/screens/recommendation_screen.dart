import 'dart:convert';

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
import 'diff_screen.dart';

/// 추천을 확인·수정한다: 프로필 이름, 설치할 확장, 설정 패치.
class RecommendationScreen extends ConsumerStatefulWidget {
  const RecommendationScreen({
    super.key,
    required this.project,
    required this.bundle,
  });

  final Project project;
  final AnalysisBundle bundle;

  @override
  ConsumerState<RecommendationScreen> createState() =>
      _RecommendationScreenState();
}

class _RecommendationScreenState extends ConsumerState<RecommendationScreen> {
  late String _primaryId;
  late Recommendation _recommendation;
  late Set<String> _selected;
  final _profile = TextEditingController();

  AnalysisResult get _analysis => widget.bundle.analysis;

  @override
  void initState() {
    super.initState();
    _primaryId = _analysis.types.first.typeId;
    _recommendation = widget.bundle.recommendation!;
    _selected = {..._recommendation.extensions};
    _profile.text = _recommendation.profileName;
    _profile.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _profile.dispose();
    super.dispose();
  }

  /// [typeId] 유형을 주 유형으로 삼아 추천을 다시 만든다. 프로필 이름과 확장 선택도 새로 정해진다.
  void _selectPrimary(String typeId) {
    final r = ref
        .read(projectServiceProvider)
        .recommendFor(_analysis, primaryTypeId: typeId);
    if (r is Ok<Recommendation>) {
      setState(() {
        _primaryId = typeId;
        _recommendation = r.value;
        _selected = {...r.value.extensions};
        _profile.text = r.value.profileName;
      });
    } else if (r is Err<Recommendation>) {
      showErrorSnackBar(context, r.error.message);
    }
  }

  /// 프로필 이름 후보: 판정된 각 유형의 프로필과 다른 프로젝트가 쓰는 프로필.
  List<String> _suggestions() {
    final service = ref.read(projectServiceProvider);
    final names = <String>{};
    for (final t in _analysis.types) {
      final r = service.recommendFor(_analysis, primaryTypeId: t.typeId);
      if (r is Ok<Recommendation>) names.add(r.value.profileName);
    }
    for (final p in ref.read(projectsProvider).value ?? const <Project>[]) {
      if (p.profileName != null) names.add(p.profileName!);
    }
    return names.toList()..sort();
  }

  String? _profileError(AppLocalizations l10n) {
    final name = _profile.text.trim();
    if (name.isEmpty) return l10n.recommendProfileEmpty;
    if (hasUnsafeProfileChars(name)) return l10n.recommendProfileInvalid;
    return null;
  }

  void _next() {
    final plan = ApplyPlan(
      project: widget.project,
      profileName: _profile.text.trim(),
      extensions: [
        for (final e in [
          ..._recommendation.extensions,
          ..._recommendation.optionalExtensions,
        ])
          if (_selected.contains(e)) e,
      ],
      settingsPatch: _recommendation.settingsPatch,
    );
    Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => DiffScreen(plan: plan)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final error = _profileError(l10n);
    final rec = _recommendation;

    return Scaffold(
      appBar: AppBar(
        flexibleSpace: const FocusTint(),
        title: Text(l10n.recommendTitle),
      ),
      body: Column(
        children: [
          Expanded(
            child: PageBody(
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                children: [
                  if (_analysis.types.length > 1) ...[
                    SectionHeader(l10n.recommendPrimaryType),
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children: [
                        for (final t in _analysis.types)
                          ChoiceChip(
                            label: Text(t.label),
                            selected: t.typeId == _primaryId,
                            onSelected: (_) => _selectPrimary(t.typeId),
                          ),
                      ],
                    ),
                  ],
                  SectionHeader(l10n.recommendProfile),
                  TextField(
                    controller: _profile,
                    decoration: InputDecoration(
                      helperText: l10n.recommendProfileHelp,
                      errorText: error,
                      suffixIcon: PopupMenuButton<String>(
                        tooltip: l10n.recommendProfileSuggestions,
                        icon: const Icon(Icons.arrow_drop_down_rounded),
                        onSelected: (v) => _profile.text = v,
                        itemBuilder: (_) => [
                          for (final s in _suggestions())
                            PopupMenuItem(value: s, child: Text(s)),
                        ],
                      ),
                    ),
                  ),
                  SectionHeader(l10n.recommendExtensionsRequired),
                  for (final id in rec.extensions) _extensionTile(id),
                  if (rec.optionalExtensions.isNotEmpty) ...[
                    SectionHeader(l10n.recommendExtensionsOptional),
                    for (final id in rec.optionalExtensions) _extensionTile(id),
                  ],
                  SectionHeader(
                    l10n.recommendSettings,
                    trailing: Text(
                      l10n.recommendSettingsCount(
                        rec.settingsPatch.length.toString(),
                      ),
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                  if (rec.settingsPatch.isNotEmpty)
                    Card(
                      margin: EdgeInsets.zero,
                      child: ExpansionTile(
                        shape: const Border(),
                        collapsedShape: const Border(),
                        title: Text(
                          rec.settingsPatch.keys.join(', '),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: monoStyle(context),
                        ),
                        childrenPadding: const EdgeInsets.all(AppSpacing.lg),
                        expandedAlignment: Alignment.centerLeft,
                        children: [
                          SelectableText(
                            const JsonEncoder.withIndent('  ')
                                .convert(rec.settingsPatch),
                            style: monoStyle(context),
                          ),
                        ],
                      ),
                    ),
                  if (rec.notes.isNotEmpty) ...[
                    SectionHeader(l10n.recommendNotes),
                    for (final n in rec.notes)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: InfoBanner(text: n),
                      ),
                  ],
                ],
              ),
            ),
          ),
          BottomActionBar(
            child: FilledButton.icon(
              onPressed: error == null ? _next : null,
              icon: const Icon(Icons.compare_arrows_rounded, size: 18),
              label: Text(l10n.recommendNext),
            ),
          ),
        ],
      ),
    );
  }

  Widget _extensionTile(String id) => CheckboxListTile(
    dense: true,
    contentPadding: EdgeInsets.zero,
    controlAffinity: ListTileControlAffinity.leading,
    title: Text(id, style: monoStyle(context)),
    value: _selected.contains(id),
    onChanged: (v) => setState(() {
      if (v == true) {
        _selected.add(id);
      } else {
        _selected.remove(id);
      }
    }),
  );
}
