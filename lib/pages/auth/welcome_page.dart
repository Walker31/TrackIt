import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/animated/fade_slide_in.dart';
import '../../widgets/app_button.dart';
import '../../widgets/brand_mark.dart';

/// First screen for a new install: what the app does and three plain
/// choices. Login and sign-up fields live on their own pages.
class WelcomePage extends ConsumerWidget {
  const WelcomePage({super.key});

  static const _features = [
    (Icons.account_balance_wallet_outlined, 'Track spending and budgets'),
    (Icons.groups_outlined, 'Split costs with friends'),
    (Icons.fitness_center_rounded, 'Log workouts set by set'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoading = ref.watch(authProvider).state.isLoading;

    Future<void> startLocal() async {
      await ref.read(authProvider).useLocalMode();
      if (context.mounted) context.go('/home');
    }

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Spacer(flex: 3),
        const FadeSlideIn(child: Center(child: BrandMark(size: 72))),
        const SizedBox(height: 20),
        FadeSlideIn(
          index: 1,
          child: Column(
            children: [
              const Text(
                'TrackIt',
                textAlign: TextAlign.center,
                style: AppTextStyles.h1,
              ),
              const SizedBox(height: 6),
              Text(
                'Spending and training, in one place.',
                textAlign: TextAlign.center,
                style: AppTextStyles.bodyLg.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 36),
        for (var i = 0; i < _features.length; i++)
          FadeSlideIn(index: 2 + i, child: _feature(_features[i])),
        const Spacer(flex: 4),
        const SizedBox(height: 24),
        FadeSlideIn(
          index: 5,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppButton(
                text: 'Get started',
                isLoading: isLoading,
                onPressed: startLocal,
              ),
              const SizedBox(height: 6),
              Text(
                'No account needed. Your data stays on this phone.',
                textAlign: TextAlign.center,
                style: AppTextStyles.bodySm.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 16),
              AppButton(
                text: 'I have an account',
                isPrimary: false,
                onPressed: () => context.push('/login'),
              ),
              const SizedBox(height: 4),
              TextButton(
                onPressed: () => context.push('/register'),
                child: const Text('Create an account'),
              ),
            ],
          ),
        ),
      ],
    );

    return Scaffold(
      body: SafeArea(
        // Scrolls only on screens too short to fit everything.
        child: LayoutBuilder(
          builder: (context, viewport) => SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: 420,
                  minHeight: viewport.maxHeight - 40,
                ),
                child: IntrinsicHeight(child: content),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _feature((IconData, String) feature) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(feature.$1, size: 20, color: AppColors.primary),
          ),
          const SizedBox(width: 14),
          Expanded(child: Text(feature.$2, style: AppTextStyles.bodyLg)),
        ],
      ),
    );
  }
}
