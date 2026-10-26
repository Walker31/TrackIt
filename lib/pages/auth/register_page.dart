import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_snackbar.dart';
import '../../widgets/auth_field.dart';
import '../../widgets/auth_scaffold.dart';

class RegisterPage extends ConsumerStatefulWidget {
  const RegisterPage({super.key});

  @override
  ConsumerState<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends ConsumerState<RegisterPage> {
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    if (_usernameController.text.trim().isEmpty ||
        _passwordController.text.isEmpty) {
      AppSnackbar.warning(context, 'Please fill in a username and password.');
      return;
    }
    if (_passwordController.text != _confirmPasswordController.text) {
      AppSnackbar.warning(context, 'Passwords do not match.');
      return;
    }

    final error = await ref
        .read(authProvider)
        .register(
          _usernameController.text.trim(),
          _passwordController.text.trim(),
          _emailController.text.trim(),
        );

    if (mounted) {
      if (error == null) {
        context.go('/home');
        AppSnackbar.success(
          context,
          'Account created. Welcome to TrackIt!',
          aboveNav: true,
        );
      } else {
        AppSnackbar.error(context, error);
      }
    }
  }

  @override
  void initState() {
    super.initState();
    // Re-render the match hint as the user types.
    _passwordController.addListener(_refresh);
    _confirmPasswordController.addListener(_refresh);
  }

  void _refresh() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider).state;
    final confirm = _confirmPasswordController.text;
    final matches = confirm.isNotEmpty && confirm == _passwordController.text;

    return AuthScaffold(
      title: 'Create account',
      subtitle: 'Back up your data and use it on any device.',
      showBack: true,
      form: AutofillGroup(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AuthField(
              controller: _usernameController,
              hint: 'Username',
              icon: Icons.person_outline_rounded,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.newUsername],
            ),
            const SizedBox(height: 12),
            AuthField(
              controller: _emailController,
              hint: 'Email (optional)',
              icon: Icons.mail_outline_rounded,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.email],
            ),
            const SizedBox(height: 12),
            AuthField(
              controller: _passwordController,
              hint: 'Password',
              icon: Icons.lock_outline_rounded,
              obscure: _obscurePassword,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.newPassword],
              suffix: IconButton(
                tooltip: _obscurePassword ? 'Show password' : 'Hide password',
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  size: 20,
                  color: AppColors.textTertiary,
                ),
                onPressed: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
              ),
            ),
            const SizedBox(height: 12),
            AuthField(
              controller: _confirmPasswordController,
              hint: 'Confirm password',
              icon: Icons.lock_reset_rounded,
              obscure: _obscurePassword,
              textInputAction: TextInputAction.done,
              onSubmitted: _handleRegister,
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              child: confirm.isEmpty
                  ? const SizedBox(width: double.infinity)
                  : Padding(
                      padding: const EdgeInsets.only(top: 8, left: 4),
                      child: Row(
                        children: [
                          Icon(
                            matches
                                ? Icons.check_circle_rounded
                                : Icons.error_outline_rounded,
                            size: 16,
                            color: matches
                                ? AppColors.income
                                : AppColors.expense,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            matches
                                ? 'Passwords match'
                                : "Passwords don't match yet",
                            style: AppTextStyles.bodySm.copyWith(
                              color: matches
                                  ? AppColors.income
                                  : AppColors.expense,
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
            const SizedBox(height: 24),
            AppButton(
              text: 'Create account',
              isLoading: authState.isLoading,
              onPressed: _handleRegister,
            ),
          ],
        ),
      ),
      footer: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            'Already have an account?',
            style: AppTextStyles.bodyMd.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          TextButton(
            onPressed: () => context.pop(),
            child: Text(
              'Log in',
              style: AppTextStyles.bodyMd.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
