import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../services/app_mode_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/animated/tap_scale.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_snackbar.dart';
import '../../widgets/auth_field.dart';
import '../../widgets/auth_scaffold.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (_usernameController.text.trim().isEmpty ||
        _passwordController.text.isEmpty) {
      AppSnackbar.warning(context, 'Enter your username and password.');
      return;
    }

    final error = await ref
        .read(authProvider)
        .login(
          _usernameController.text.trim(),
          _passwordController.text.trim(),
        );

    if (mounted) {
      if (error == null) {
        context.go('/home');
        AppSnackbar.success(context, 'Welcome back!', aboveNav: true);
      } else {
        AppSnackbar.error(context, error);
      }
    }
  }

  Future<void> _editServerUrl() async {
    final controller = TextEditingController(text: ApiService.baseUrl);
    final saved = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Server URL'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.url,
          decoration: InputDecoration(hintText: ApiService.defaultBaseUrl),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (saved != null) await AppModeService().setServerUrl(saved);
    if (mounted) setState(() {});
  }

  String get _serverHost {
    final host = Uri.tryParse(ApiService.baseUrl)?.host ?? '';
    return host.isEmpty ? ApiService.baseUrl : host;
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider).state;

    return AuthScaffold(
      title: 'Welcome back',
      subtitle: 'Log in to sync your data across devices.',
      // Pushed from the welcome screen or Settings.
      showBack: context.canPop(),
      form: AutofillGroup(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AuthField(
              controller: _usernameController,
              hint: 'Username',
              icon: Icons.person_outline_rounded,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.username],
            ),
            const SizedBox(height: 12),
            AuthField(
              controller: _passwordController,
              hint: 'Password',
              icon: Icons.lock_outline_rounded,
              obscure: _obscurePassword,
              textInputAction: TextInputAction.done,
              onSubmitted: _handleLogin,
              autofillHints: const [AutofillHints.password],
              suffix: _VisibilityToggle(
                obscured: _obscurePassword,
                onPressed: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
              ),
            ),
            const SizedBox(height: 20),
            AppButton(
              text: 'Log in',
              isLoading: authState.isLoading,
              onPressed: _handleLogin,
            ),
          ],
        ),
      ),
      footer: Column(
        children: [
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                'New to TrackIt?',
                style: AppTextStyles.bodyMd.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              TextButton(
                // Swap pages so back always returns to where login opened.
                onPressed: () => context.pushReplacement('/register'),
                child: Text(
                  'Create an account',
                  style: AppTextStyles.bodyMd.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          _ServerChip(host: _serverHost, onTap: _editServerUrl),
        ],
      ),
    );
  }
}

class _VisibilityToggle extends StatelessWidget {
  final bool obscured;
  final VoidCallback onPressed;
  const _VisibilityToggle({required this.obscured, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: obscured ? 'Show password' : 'Hide password',
      onPressed: onPressed,
      icon: AnimatedSwitcher(
        duration: const Duration(milliseconds: 180),
        child: Icon(
          obscured ? Icons.visibility_off_outlined : Icons.visibility_outlined,
          key: ValueKey(obscured),
          size: 20,
          color: AppColors.textTertiary,
        ),
      ),
    );
  }
}

/// Shows which backend the app will log in to; tap to change it.
class _ServerChip extends StatelessWidget {
  final String host;
  final VoidCallback onTap;
  const _ServerChip({required this.host, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return TapScale(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.dns_outlined, size: 15, color: AppColors.textSecondary),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                'Server: $host',
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.bodySm.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.edit_outlined, size: 13, color: AppColors.textTertiary),
          ],
        ),
      ),
    );
  }
}
