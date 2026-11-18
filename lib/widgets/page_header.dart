import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../theme/responsive.dart';
import 'sync_status.dart';

/// Plain, non-collapsing page title used at the top of each main tab, with
/// the settings shortcut every tab shares.
class PageHeader extends StatelessWidget {
  final String title;

  /// Small line above the title (e.g. today's date).
  final String? overline;

  /// Page actions shown at the end of the header (e.g. "Add expense").
  final List<Widget> actions;

  const PageHeader({
    super.key,
    required this.title,
    this.overline,
    this.actions = const [],
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 8, 0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (overline != null) ...[
                    Text(
                      overline!,
                      style: AppTextStyles.bodyMd.copyWith(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                  ],
                  Text(title, style: AppTextStyles.h1),
                ],
              ),
            ),
            ...actions,
            // Wider windows have both in the side rail.
            if (WindowSize.of(context).usesBottomNav) ...[
              const SyncStatusIndicator(),
              IconButton(
                tooltip: 'Settings',
                onPressed: () => context.push('/settings'),
                icon: Icon(
                  Icons.settings_outlined,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// The page's main "add" action as a labelled header button. Wide windows
/// use it instead of a floating "+" in the far corner.
class HeaderAddButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;

  const HeaderAddButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilledButton.icon(
        onPressed: onPressed,
        icon: const Icon(Icons.add_rounded, size: 18),
        label: Text(label),
      ),
    );
  }
}
