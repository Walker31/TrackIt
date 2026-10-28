import 'dart:async';
import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../providers/app_providers.dart';
import '../providers/auth_provider.dart';
import '../services/app_mode_service.dart';
import '../services/backup_service.dart';
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

/// Settings as grouped rows: account, appearance, budget, data & sync,
/// backup.
/// Values that need typing open a sheet instead of sitting inline.
class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  bool _syncing = false;
  bool _busyBackup = false;

  /// Last finished sync and changes still waiting to upload.
  late Future<(DateTime?, int)> _status = _loadStatus();
  StreamSubscription<void>? _syncSub;

  static Future<(DateTime?, int)> _loadStatus() =>
      (SyncService.lastSyncedAt(), SyncService.pendingChanges()).wait;

  @override
  void initState() {
    super.initState();
    _syncSub = SyncService().onSyncComplete.listen((_) {
      if (mounted) setState(() => _status = _loadStatus());
    });
  }

  @override
  void dispose() {
    _syncSub?.cancel();
    super.dispose();
  }

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
              color: budget > 0
                  ? AppColors.textPrimary
                  : AppColors.textTertiary,
            ),
          ),
          onTap: () => _editBudget(budget),
        ),
      ]),
      _section('Data & sync', [
        if (isLocal) ...[
          _SettingsTile(
            icon: Icons.phone_android_rounded,
            iconColor: AppColors.textSecondary,
            title: 'Stored on this device',
            subtitle: 'Nothing leaves your phone',
            showChevron: false,
          ),
          _SettingsTile(
            icon: Icons.cloud_outlined,
            title: 'Connect to a server',
            subtitle: 'Back up, sync and split costs with friends',
            accent: true,
            onTap: () => context.push('/login'),
          ),
        ] else ...[
          _syncStatusTile(),
          _SettingsTile(
            icon: Icons.sync_rounded,
            title: 'Sync now',
            subtitle: 'Upload changes and fetch new data',
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
      _section('Backup', [
        _SettingsTile(
          icon: Icons.download_rounded,
          title: 'Download backup',
          subtitle: 'Save all your data to a file',
          onTap: _busyBackup ? null : _exportBackup,
        ),
        _SettingsTile(
          icon: Icons.restore_rounded,
          title: 'Restore from backup',
          subtitle: "Replace this phone's data with a backup file",
          onTap: _busyBackup ? null : _restoreBackup,
        ),
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

  /// "Everything is uploaded" or "3 changes waiting to upload", with when
  /// the last sync finished.
  Widget _syncStatusTile() {
    return FutureBuilder<(DateTime?, int)>(
      future: _status,
      builder: (context, snapshot) {
        final (last, pending) = snapshot.data ?? (null, 0);
        final waiting = pending > 0;
        final when = last == null
            ? 'Not synced yet'
            : 'Last synced ${_ago(last)}';
        return _SettingsTile(
          icon: waiting
              ? Icons.cloud_upload_outlined
              : Icons.cloud_done_outlined,
          iconColor: waiting ? AppColors.accent : AppColors.income,
          title: waiting
              ? '${_count(pending, 'change')} waiting to upload'
              : 'Everything is uploaded',
          subtitle: snapshot.hasData ? when : 'Checking…',
          showChevron: false,
        );
      },
    );
  }

  static String _ago(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours} h ago';
    return 'on ${DateFormat('d MMM, h:mm a').format(time)}';
  }

  static String _count(int n, String noun) => '$n $noun${n == 1 ? '' : 's'}';

  Future<void> _syncNow() async {
    setState(() => _syncing = true);
    // Providers reload themselves when the sync completes.
    await SyncService().performSync(forcePull: true);
    final pending = await SyncService.pendingChanges();
    if (!mounted) return;
    setState(() => _syncing = false);
    if (pending == 0) {
      AppSnackbar.success(context, 'Everything is synced.');
    } else {
      AppSnackbar.warning(
        context,
        "${_count(pending, 'change')} couldn't upload. "
        'Check your connection and try again.',
      );
    }
  }

  /// The signed-in username. Backups record it so a restore can tell
  /// whether the data belongs to this account.
  String? get _account {
    final auth = ref.read(authProvider).state;
    if (auth.status != AuthStatus.authenticated) return null;
    return auth.user?['username']?.toString();
  }

  Future<void> _exportBackup() async {
    setState(() => _busyBackup = true);
    try {
      final json = await BackupService().exportJson(account: _account);
      final date = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final name = 'trackit-backup-$date.json';
      final saved = await FilePicker.saveFile(
        fileName: name,
        bytes: utf8.encode(json),
        mimeType: 'application/json',
        dialogTitle: 'Save backup',
      );
      if (saved != null && mounted) {
        AppSnackbar.success(context, 'Backup saved as $name.');
      }
    } catch (e) {
      if (mounted) AppSnackbar.error(context, "Couldn't save the backup: $e");
    } finally {
      if (mounted) setState(() => _busyBackup = false);
    }
  }

  Future<void> _restoreBackup() async {
    final service = BackupService();
    final String json;
    final BackupSummary summary;
    try {
      // Any file type: downloaded JSON often arrives without its MIME type.
      final file = await FilePicker.pickFile(dialogTitle: 'Choose a backup');
      if (file == null) return;
      json = await file.xFile.readAsString();
      summary = service.inspect(json);
    } on BackupException catch (e) {
      if (mounted) AppSnackbar.error(context, e.message);
      return;
    } catch (e) {
      if (mounted) AppSnackbar.error(context, "Couldn't read that file: $e");
      return;
    }
    if (!mounted) return;

    final made = summary.createdAt == null
        ? ''
        : ' from ${DateFormat('d MMM yyyy').format(summary.createdAt!.toLocal())}';
    final contents =
        '${_count(summary.transactions, 'transaction')} and '
        '${_count(summary.workouts, 'workout')}';
    final confirmed = await confirmDestructive(
      context,
      title: 'Restore this backup?',
      message:
          'It has $contents$made. Everything on this phone will be '
          "replaced. This can't be undone.",
      action: 'Restore',
    );
    if (!confirmed || !mounted) return;

    setState(() => _busyBackup = true);
    try {
      await service.restore(json, account: _account);
      // Theme and budget came back with the data; reload what's cached.
      await AppModeService().load();
      ref.read(themeModeProvider.notifier).state = AppModeService.themeMode;
      ref.invalidate(expenseProviderProvider);
      ref.invalidate(workoutProviderProvider);
      ref.invalidate(groupProviderProvider);
      unawaited(SyncService().performSync(forcePull: true));
      if (mounted) {
        setState(() => _status = _loadStatus());
        AppSnackbar.success(context, 'Restored $contents.');
      }
    } on BackupException catch (e) {
      if (mounted) AppSnackbar.error(context, e.message);
    } catch (e) {
      if (mounted) {
        AppSnackbar.error(
          context,
          "Couldn't restore the backup; nothing was changed. ($e)",
        );
      }
    } finally {
      if (mounted) setState(() => _busyBackup = false);
    }
  }

  /// Before leaving server mode: if changes haven't reached the server,
  /// say so and offer to sync first. True means go ahead.
  Future<bool> _confirmLeavingServer({
    required String title,
    required String message,
    required String action,
  }) async {
    final pending = await SyncService.pendingChanges();
    if (!mounted) return false;
    if (pending == 0) {
      return confirmDestructive(
        context,
        title: title,
        message: message,
        action: action,
      );
    }

    final choice = await showDialog<_UnsyncedChoice>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(
          "${_count(pending, 'change')} haven't reached the server yet. "
          "They stay on this phone, but other devices won't see them "
          'until you sync.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, _UnsyncedChoice.cancel),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, _UnsyncedChoice.leave),
            child: Text(
              '$action anyway',
              style: const TextStyle(color: AppColors.expense),
            ),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, _UnsyncedChoice.syncFirst),
            child: const Text('Sync first'),
          ),
        ],
      ),
    );

    switch (choice) {
      case _UnsyncedChoice.leave:
        return true;
      case _UnsyncedChoice.syncFirst:
        setState(() => _syncing = true);
        await SyncService().performSync();
        final left = await SyncService.pendingChanges();
        if (!mounted) return false;
        setState(() => _syncing = false);
        if (left == 0) return true;
        AppSnackbar.warning(
          context,
          "${_count(left, 'change')} still couldn't upload. "
          'Check your connection and try again.',
        );
        return false;
      case _UnsyncedChoice.cancel:
      case null:
        return false;
    }
  }

  Future<void> _switchToLocal() async {
    final go = await _confirmLeavingServer(
      title: 'Use on this device only?',
      message: 'Your data stays here; syncing stops until you sign in again.',
      action: 'Switch',
    );
    if (!go || !mounted) return;
    await ref.read(authProvider).useLocalMode();
    if (mounted) AppSnackbar.info(context, 'Now using this device only.');
  }

  Future<void> _handleLogout() async {
    final go = await _confirmLeavingServer(
      title: 'Log out?',
      message: 'Your data stays on this device. Sign in again to sync.',
      action: 'Log out',
    );
    if (go && mounted) {
      AppSnackbar.info(context, 'You have been logged out.');
      await ref.read(authProvider).logout();
    }
  }
}

enum _UnsyncedChoice { cancel, syncFirst, leave }

/// One settings row: tinted icon, title, optional subtitle and trailing.
class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final Color? iconColor;
  final String title;
  final String? subtitle;
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
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(subtitle!, style: subtitleStyle),
                  ],
                ],
              ),
            ),
            if (trailing != null) ...[const SizedBox(width: 12), trailing!],
            if (showChevron && onTap != null) ...[
              const SizedBox(width: 4),
              Icon(Icons.chevron_right_rounded, color: AppColors.textTertiary),
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
