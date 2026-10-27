import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/app_providers.dart';
import '../providers/auth_provider.dart';
import '../services/app_mode_service.dart';
import '../services/sync_outbox.dart';
import '../services/sync_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../theme/responsive.dart';
import '../utils/format.dart';
import '../widgets/animated/fade_slide_in.dart';
import '../widgets/app_button.dart';
import '../widgets/app_card.dart';
import '../widgets/app_snackbar.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/glass_container.dart';

/// Settings as grouped rows: account, appearance, budget, data & sync.
/// Values that need typing open a sheet instead of sitting inline.
class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  bool _syncing = false;

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider).state;
    final isLocal = auth.status == AuthStatus.local;
    final budget = ref.watch(expenseProviderProvider).monthlyBudget;
    final side = Responsive.centeringPadding(context);

    final sections = <Widget>[
      _profile(auth, isLocal),
      _section('Appearance', [_themeRow()]),
      _section('Budget', [
        _SettingsTile(
          icon: Icons.savings_outlined,
          title: 'Monthly budget',
          subtitle: 'Shown on Home',
          trailing: Text(
            budget > 0 ? formatRupees(budget) : 'Not set',
            style: AppTextStyles.bodyMd.copyWith(
              fontWeight: FontWeight.w600,
              color: budget > 0 ? AppColors.textPrimary : AppColors.textTertiary,
            ),
          ),
          onTap: () => _editBudget(budget),
        ),
      ]),
      _section('Data & sync', [
        _SettingsTile(
          icon: isLocal ? Icons.phone_android_rounded : Icons.cloud_done_outlined,
          iconColor: isLocal ? AppColors.textSecondary : AppColors.income,
          title: isLocal ? 'Stored on this device' : 'Synced with your server',
          subtitle: isLocal
              ? 'Nothing leaves your phone'
              : 'Saved here first, synced when online',
          showChevron: false,
        ),
        if (isLocal)
          _SettingsTile(
            icon: Icons.cloud_outlined,
            title: 'Connect to a server',
            subtitle: 'Back up and sync across devices',
            accent: true,
            onTap: () => context.push('/login'),
          )
        else ...[
          _SettingsTile(
            icon: Icons.sync_rounded,
            title: 'Sync now',
            subtitleWidget: FutureBuilder<int>(
              future: SyncOutbox.pendingCount(),
              builder: (context, snapshot) {
                final pending = snapshot.data ?? 0;
                return Text(
                  pending == 0
                      ? 'Everything is up to date'
                      : '$pending deletion${pending == 1 ? '' : 's'} '
                            'waiting to sync',
                  style: _SettingsTile.subtitleStyle,
                );
              },
            ),
            trailing: _syncing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : null,
            onTap: _syncing ? null : _syncNow,
          ),
          _SettingsTile(
            icon: Icons.phonelink_erase_rounded,
            title: 'Use on this device only',
            subtitle: 'Stop syncing; your data stays here',
            onTap: _switchToLocal,
          ),
        ],
      ]),
      if (auth.status == AuthStatus.authenticated)
        _section(null, [
          _SettingsTile(
            icon: Icons.logout_rounded,
            title: 'Log out',
            destructive: true,
            showChevron: false,
            onTap: _handleLogout,
          ),
        ]),
      Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Text(
          'TrackIt 1.0',
          textAlign: TextAlign.center,
          style: AppTextStyles.bodySm.copyWith(color: AppColors.textTertiary),
        ),
      ),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: EdgeInsets.fromLTRB(side, 8, side, 40),
        children: [
          for (var i = 0; i < sections.length; i++)
            FadeSlideIn(index: i, child: sections[i]),
        ],
      ),
    );
  }

  Widget _profile(AuthState auth, bool isLocal) {
    final username = isLocal ? 'You' : auth.user?['username'] ?? 'User';
    final detail = isLocal
        ? 'Using TrackIt without an account'
        : auth.user?['email'] ?? '';

    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: AppCard(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: AppColors.brandGradient,
                shape: BoxShape.circle,
              ),
              child: isLocal
                  ? const Icon(Icons.person_rounded, color: Colors.white)
                  : Text(
                      username.isEmpty ? '?' : username[0].toUpperCase(),
                      style: AppTextStyles.h2.copyWith(color: Colors.white),
                    ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    username,
                    style: AppTextStyles.h3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (detail.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      detail,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.bodyMd.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// A titled card of rows separated by inset dividers.
  Widget _section(String? title, List<Widget> rows) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title != null)
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 8),
              child: Text(title.toUpperCase(), style: AppTextStyles.overline),
            ),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (var i = 0; i < rows.length; i++) ...[
                  if (i > 0) const Divider(height: 1, indent: 64),
                  rows[i],
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _themeRow() {
    final themeMode = ref.watch(themeModeProvider);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const _TileIcon(icon: Icons.palette_outlined),
              const SizedBox(width: 14),
              Text('Theme', style: _SettingsTile.titleStyle),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<ThemeMode>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(
                  value: ThemeMode.light,
                  icon: Icon(Icons.light_mode_outlined, size: 18),
                  label: Text('Light'),
                ),
                ButtonSegment(
                  value: ThemeMode.dark,
                  icon: Icon(Icons.dark_mode_outlined, size: 18),
                  label: Text('Dark'),
                ),
                ButtonSegment(
                  value: ThemeMode.system,
                  icon: Icon(Icons.brightness_auto_outlined, size: 18),
                  label: Text('Auto'),
                ),
              ],
              selected: {themeMode},
              onSelectionChanged: (selection) {
                HapticFeedback.selectionClick();
                ref.read(themeModeProvider.notifier).state = selection.first;
                AppModeService().setThemeMode(selection.first);
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _editBudget(double current) async {
    final saved = await showModalBottomSheet<double>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _BudgetSheet(initial: current),
    );
    if (saved == null) return;
    await ref.read(expenseProviderProvider).updateBudget(saved);
    if (mounted) {
      AppSnackbar.success(
        context,
        'Monthly budget set to ${formatRupees(saved)}.',
      );
    }
  }

  Future<void> _syncNow() async {
    setState(() => _syncing = true);
    // Providers reload themselves when the sync completes.
    await SyncService().performSync();
    if (mounted) {
      setState(() => _syncing = false);
      AppSnackbar.success(context, 'Sync complete.');
    }
  }

  Future<void> _switchToLocal() async {
    await ref.read(authProvider).useLocalMode();
    if (mounted) AppSnackbar.info(context, 'Now using this device only.');
  }

  Future<void> _handleLogout() async {
    final confirm = await confirmDestructive(
      context,
      title: 'Log out?',
      message: 'Your data stays on this device. Sign in again to sync.',
      action: 'Log out',
    );
    if (confirm && mounted) {
      AppSnackbar.info(context, 'You have been logged out.');
      await ref.read(authProvider).logout();
    }
  }
}

/// One settings row: tinted icon, title, optional subtitle and trailing.
class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final Color? iconColor;
  final String title;
  final String? subtitle;
  final Widget? subtitleWidget;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool showChevron;

  /// Teal title, for the row that is the section's main action.
  final bool accent;
  final bool destructive;

  const _SettingsTile({
    required this.icon,
    required this.title,
    this.iconColor,
    this.subtitle,
    this.subtitleWidget,
    this.trailing,
    this.onTap,
    this.showChevron = true,
    this.accent = false,
    this.destructive = false,
  });

  static TextStyle get titleStyle => AppTextStyles.bodyLg.copyWith(
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  static TextStyle get subtitleStyle =>
      AppTextStyles.bodySm.copyWith(color: AppColors.textSecondary);

  @override
  Widget build(BuildContext context) {
    final color = destructive
        ? AppColors.expense
        : accent
        ? AppColors.primary
        : null;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            _TileIcon(icon: icon, color: color ?? iconColor),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: titleStyle.copyWith(color: color)),
                  if (subtitleWidget != null || subtitle != null) ...[
                    const SizedBox(height: 2),
                    subtitleWidget ?? Text(subtitle!, style: subtitleStyle),
                  ],
                ],
              ),
            ),
            if (trailing != null) ...[const SizedBox(width: 12), trailing!],
            if (showChevron && onTap != null) ...[
              const SizedBox(width: 4),
              Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textTertiary,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TileIcon extends StatelessWidget {
  final IconData icon;
  final Color? color;

  const _TileIcon({required this.icon, this.color});

  @override
  Widget build(BuildContext context) {
    final tint = color ?? AppColors.primary;
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, size: 19, color: tint),
    );
  }
}

/// Bottom sheet for typing a new monthly budget; pops with the amount.
class _BudgetSheet extends StatefulWidget {
  final double initial;

  const _BudgetSheet({required this.initial});

  @override
  State<_BudgetSheet> createState() => _BudgetSheetState();
}

class _BudgetSheetState extends State<_BudgetSheet> {
  late final _controller = TextEditingController(
    text: widget.initial > 0 ? widget.initial.toStringAsFixed(0) : '',
  );
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    final amount = double.tryParse(_controller.text);
    if (amount == null || amount <= 0) {
      setState(() => _error = 'Enter an amount above zero.');
      return;
    }
    Navigator.pop(context, amount);
  }

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      sheet: true,
      borderRadius: 24,
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Monthly budget', style: AppTextStyles.h2),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
                tooltip: 'Close',
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'How much you plan to spend in a month.',
            style: AppTextStyles.bodyMd.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _controller,
            autofocus: true,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _save(),
            onChanged: (_) {
              if (_error != null) setState(() => _error = null);
            },
            style: AppTextStyles.h2,
            decoration: InputDecoration(
              prefixText: '₹ ',
              hintText: 'e.g. 30000',
              errorText: _error,
            ),
          ),
          const SizedBox(height: 24),
          AppButton(text: 'Save', onPressed: _save),
        ],
      ),
    );
  }
}
