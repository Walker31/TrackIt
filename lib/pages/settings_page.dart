import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/responsive.dart';
import '../widgets/animated/fade_slide_in.dart';
import '../providers/app_providers.dart';
import '../providers/auth_provider.dart';
import 'package:go_router/go_router.dart';

import '../services/sync_outbox.dart';
import '../services/sync_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/app_snackbar.dart';

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

    return Scaffold(
      appBar: AppBar(title: const Text('Settings', style: AppTextStyles.h2)),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          Responsive.centeringPadding(context),
          20,
          Responsive.centeringPadding(context),
          24,
        ),
        children: _staggered([
          _buildUserProfile(),
          const SizedBox(height: 24),
          _buildSectionTitle('Appearance'),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Theme Mode', style: AppTextStyles.label),
                  const SizedBox(height: 12),
                  SegmentedButton<ThemeMode>(
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment<ThemeMode>(
                        value: ThemeMode.light,
                        label: Text('Light'),
                      ),
                      ButtonSegment<ThemeMode>(
                        value: ThemeMode.dark,
                        label: Text('Dark'),
                      ),
                      ButtonSegment<ThemeMode>(
                        value: ThemeMode.system,
                        label: Text('System'),
                      ),
                    ],
                    selected: {themeMode},
                    onSelectionChanged: (selection) {
                      ref.read(themeModeProvider.notifier).state =
                          selection.first;
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          _buildSectionTitle('Budget'),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Monthly Budget', style: AppTextStyles.label),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _budgetController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      prefixText: '₹',
                      hintText: 'Enter monthly budget',
                      filled: true,
                      fillColor: Theme.of(
                        context,
                      ).colorScheme.surface.withValues(alpha: 0.75),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _saveBudget,
                      icon: const Icon(Icons.save_outlined),
                      label: const Text('Save Budget'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          _buildSectionTitle('Data & Sync'),
          const SizedBox(height: 12),
          _buildSyncCard(),
          const SizedBox(height: 48),
          if (ref.watch(authProvider).state.status == AuthStatus.authenticated)
            _buildLogoutButton(),
        ]),
      ),
    );
  }

  Widget _buildSyncCard() {
    final isLocal = ref.watch(authProvider).state.status == AuthStatus.local;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isLocal
                  ? 'Stored on this device only'
                  : 'Synced with your server',
              style: AppTextStyles.label,
            ),
            const SizedBox(height: 4),
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
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => context.push('/login'),
                  icon: const Icon(Icons.cloud_outlined),
                  label: const Text('Connect to a server'),
                ),
              )
            else ...[
              FutureBuilder<int>(
                future: SyncOutbox.pendingCount(),
                builder: (context, snapshot) => Text(
                  '${snapshot.data ?? 0} deletions waiting to sync',
                  style: AppTextStyles.bodyMd,
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _syncNow,
                  icon: const Icon(Icons.sync_rounded),
                  label: const Text('Sync now'),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: _switchToLocal,
                  child: const Text('Use on this device only'),
                ),
              ),
            ],
          ],
        ),
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
    await SyncService().performSync();
    await ref.read(expenseProviderProvider).refreshData();
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

    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.05),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            CircleAvatar(
              radius: 30,
              backgroundColor: Theme.of(
                context,
              ).colorScheme.primary.withValues(alpha: 0.2),
              child: Text(
                username[0].toUpperCase(),
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(username, style: AppTextStyles.h3),
                  if (email.isNotEmpty)
                    Text(
                      email,
                      style: AppTextStyles.bodyMd.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogoutButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _handleLogout,
        icon: const Icon(Icons.logout_rounded, color: Colors.redAccent),
        label: const Text(
          'Log Out',
          style: TextStyle(
            color: Colors.redAccent,
            fontWeight: FontWeight.bold,
          ),
        ),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          side: const BorderSide(color: Colors.redAccent, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }

  Future<void> _handleLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Log Out'),
        content: const Text('Are you sure you want to log out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Log Out',
              style: TextStyle(color: Colors.redAccent),
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
    return Text(
      title,
      style: AppTextStyles.h3.copyWith(
        color: Theme.of(context).colorScheme.onSurface,
      ),
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
        'Monthly budget set to ₹${amount.toStringAsFixed(0)}.',
      );
    }
  }
}
