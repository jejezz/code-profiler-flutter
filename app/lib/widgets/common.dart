import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/app_localizations.dart';
import '../theme/app_theme.dart';

/// 흰 배경 위 글자에도 대비가 충분한 경고색 (theming.md §2).
Color warningColor(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
    ? AppColors.warning
    : AppColors.warningTextLight;

Color successColor(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
    ? AppColors.success
    : AppColors.successTextLight;

/// 오류를 스낵바로 알린다. 원문을 복사할 수 있는 "복사" 액션을 붙인다 (ui-ux.md §6).
void showErrorSnackBar(BuildContext context, String message) {
  final l10n = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(
      content: Text(message),
      duration: const Duration(seconds: 8),
      action: SnackBarAction(
        label: l10n.commonCopy,
        onPressed: () => Clipboard.setData(ClipboardData(text: message)),
      ),
    ),
  );
}

/// 완료 알림. 4초 뒤 자동으로 닫힌다.
void showInfoSnackBar(BuildContext context, String message) {
  final messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(content: Text(message), duration: const Duration(seconds: 4)),
  );
}

/// 작은 알약 모양 라벨.
class Pill extends StatelessWidget {
  const Pill(this.text, {super.key, this.color, this.icon});

  final String text;
  final Color? color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = color ?? theme.colorScheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(AppRadius.chip),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: c),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(
                color: c,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 경고·안내 띠.
class InfoBanner extends StatelessWidget {
  const InfoBanner({
    super.key,
    required this.text,
    this.title,
    this.color,
    this.icon = Icons.info_outline_rounded,
  });

  final String? title;
  final String text;
  final Color? color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = color ?? theme.colorScheme.primary;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.10),
        border: Border.all(color: c.withValues(alpha: 0.35)),
        borderRadius: BorderRadius.circular(AppRadius.button + 4),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: c),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title != null)
                  Text(
                    title!,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                Text(text, style: theme.textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.lg, bottom: AppSpacing.sm),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// 가운데 정렬된 스크롤 본문. 넓은 창에서 내용이 너무 퍼지지 않도록 폭을 제한한다.
class PageBody extends StatelessWidget {
  const PageBody({super.key, required this.child, this.maxWidth = 860});

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}

/// 경로·파일 이름 같은 사용자 콘텐츠용 스타일 (fonts.md §3).
TextStyle? pathStyle(BuildContext context) =>
    Theme.of(context).textTheme.bodySmall
        ?.merge(AppFonts.userContent)
        .copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant);

/// 로그·JSON 미리보기용 고정폭 스타일 (fonts.md §4).
TextStyle? monoStyle(BuildContext context) =>
    Theme.of(context).textTheme.bodySmall
        ?.merge(AppFonts.mono)
        .copyWith(fontSize: 12);

/// 화면 아래에 고정되는 행동 줄. 주 행동 버튼을 오른쪽에 둔다.
class BottomActionBar extends StatelessWidget {
  const BottomActionBar({super.key, required this.child, this.leading});

  final Widget child;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
        ),
      ),
      child: Row(
        children: [
          if (leading != null) Expanded(child: leading!) else const Spacer(),
          child,
        ],
      ),
    );
  }
}
