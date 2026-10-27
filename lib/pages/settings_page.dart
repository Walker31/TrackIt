import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/responsive.dart';
import '../widgets/animated/fade_slide_in.dart';
import '../providers/app_providers.dart';
import '../providers/auth_provider.dart';
import 'package:go_router/go_router.dart';

import '../services/app_mode_service.dart';
import '../services/sync_outbox.dart';
import '../services/sync_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/app_button.dart';
import '../widgets/app_card.dart';
import '../widgets/app_snackbar.dart';
import '../utils/format.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  late final TextEditingController _budgetController;

  @override
  void initState() {
    super.initState();
    final expenseProvider = ref.read(expenseProviderProvider);
    _budgetController = TextEditingController(
      text: expenseProvider.monthlyBudget.toStringAsFixed(0),
    );
  }

  @override
  void dispose() {
    _budgetController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);
    final side = Responsive.centeringPadding(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: EdgeInsets.fromLTRB(side, 8, side, 32),
        children: _staggered([
          _buildUserProfile(),
          const SizedBox(height: 28),
          _buildSectionTitle('Appearance'),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Theme', style: AppTextStyles.fieldLabel),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<ThemeMode>(
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment<ThemeMode>(
                        value: ThemeMode.light,
                        icon: Icon(Icons.light_mode_outlined, size: 18),
                        label: Text('Light'),
                      ),
                      ButtonSegment<ThemeMode>(
                        value: ThemeMode.dark,
                        icon: Icon(Icons.dark_mode_outlined, size: 18),
                        label: Text('Dark'),
                      ),
                      ButtonSegment<ThemeMode>(
                        value: ThemeMode.system,
                        icon: Icon(Icons.brightness_auto_outlined, size: 18),
                        label: Text('System'),
                      ),
                    ],
                    selected: {themeMode},
                    onSelectionChanged: (selection) {
                      ref.read(themeModeProvider.notifier).state =
                          selection.first;
                      AppModeService().setThemeMode(selection.first);
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          _buildSectionTitle('Budget'),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Monthly budget', style: AppTextStyles.fieldLabel),
                const SizedBox(height: 10),
                TextField(
                  controller: _budgetController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _saveBudget(),
                  style: AppTextStyles.bodyLg.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: const InputDecoration(
                    prefixText: '₹ ',
                    hintText: 'e.g. 30000',
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Home shows how much of this is left each month.',
                  style: AppTextStyles.bodySm.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 14),
                AppButton(text: 'Save budget', onPressed: _saveBudget),
              ],
            ),
          ),
          const SizedBox(height: 28),
          _buildSectionTitle('Data & sync'),
          _buildSyncCard(),
          if (ref.watch(authProvider).state.status ==
              AuthStatus.authenticated) ...[
            const SizedBox(height: 28),
            _buildLogoutButton(),
          ],
        ]),
      ),
    );
  }

  Widget _buildSyncCard() {
    final isLocal = ref.watch(authProvider).state.status == AuthStatus.local;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isLocal
                    ? Icons.phone_android_rounded
                    : Icons.cloud_done_outlined,
                size: 20,
                color: isLocal ? AppColors.textSecondary : AppColors.income,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  isLocal
                      ? 'Stored on this device only'
                      : 'Synced with your server',
                  style: AppTextStyles.bodyLg.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            isLocal
                ? 'Nothing leaves your phone. Connect a server any time to back up and sync.'
                : 'Changes are saved on this device first and synced when you are online.',
            style: AppTextStyles.bodyMd.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          if (isLocal)
            AppButton(
              text: 'Connect to a server',
              icon: Icons.cloud_outlined,
              onPressed: () => context.push('/login'),
            )
          else ...[
            FutureBuilder<int>(
              future: SyncOutbox.pendingCount(),
              builder: (context, snapshot) {
                final pending = snapshot.data ?? 0;
                return Text(
                  pending == 0
                      ? 'Everything is up to date.'
                      : '$pending deletion${pending == 1 ? '' : 's'} '
                            'waiting to sync',
                  style: AppTextStyles.bodySm.copyWith(
                    color: AppColors.textSecondary,
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            AppButton(
              text: 'Sync now',
              icon: Icons.sync_rounded,
              onPressed: _syncNow,
            ),
            const SizedBox(height: 10),
            AppButton(
              text: 'Use on this device only',
              isPrimary: false,
              onPressed: _switchToLocal,
            ),
          ],
        ],
      ),
    );
  }

  /// Gives each settings block a staggered fade-in; spacers pass through.
  List<Widget> _staggered(List<Widget> children) {
    var index = 0;
    return [
      for (final child in children)
        child is SizedBox ? child : FadeSlideIn(index: index++, child: child),
    ];
  }

  Future<void> _syncNow() async {
    // Providers reload themselves when the sync completes.
    await SyncService().performSync();
    if (mounted) {
      setState(() {});
      AppSnackbar.success(context, 'Sync complete.');
    }
  }

  Future<void> _switchToLocal() async {
    await ref.read(authProvider).useLocalMode();
    if (mounted) AppSnackbar.info(context, 'Now using this device only.');
  }

  Widget _buildUserProfile() {
    final authState = ref.watch(authProvider).state;
    final isLocal = authState.status == AuthStatus.local;
    final username = isLocal
        ? 'Local user'
        : authState.user?['username'] ?? 'User';
    final email = isLocal ? 'Not signed in' : authState.user?['email'] ?? '';

    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: AppColors.primary.withValues(alpha: 0.14),
            child: Text(
              username.isEmpty ? '?' : username[0].toUpperCase(),
              style: AppTextStyles.h2.copyWith(color: AppColors.primary),
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
                if (email.isNotEmpty)
                  Text(
                    email,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.bodyMd.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogoutButton() {
    return AppButton(
      text: 'Log out',
      icon: Icons.logout_rounded,
      color: AppColors.expense,
      onPressed: _handleLogout,
    );
  }

  Future<void> _handleLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text('Are you sure you want to log out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Log out',
              style: TextStyle(color: AppColors.expense),
            ),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      AppSnackbar.info(context, 'You have been logged out.');
      await ref.read(authProvider).logout();
    }
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 10),
      child: Text(title.toUpperCase(), style: AppTextStyles.overline),
    );
  }

  Future<void> _saveBudget() async {
    final amount = double.tryParse(_budgetController.text);
    if (amount == null || amount <= 0) {
      if (mounted) {
        AppSnackbar.warning(context, 'Please enter a valid budget amount.');
      }
      return;
    }

    await ref.read(expenseProviderProvider).updateBudget(amount);

    if (mounted) {
      AppSnackbar.success(
        context,
        'Monthly budget set to ${formatRupees(amount)}.',
      );
    }
  }
}
