import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import 'animated/fade_slide_in.dart';
import 'brand_mark.dart';

/// Shared layout for the login and register screens. Wide windows get a
/// gradient brand panel beside the form; phones get a compact brand header
/// above it.
class AuthScaffold extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget form;
  final Widget? footer;
  final bool showBack;

  const AuthScaffold({
    super.key,
    required this.title,
    required this.subtitle,
    required this.form,
    this.footer,
    this.showBack = false,
  });

  static const _wideBreakpoint = 900.0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= _wideBreakpoint;
          final formColumn = _FormColumn(
            title: title,
            subtitle: subtitle,
            form: form,
            footer: footer,
            showBrand: !wide,
            showBack: showBack,
          );
          if (!wide) return formColumn;
          return Row(
            children: [
              const Expanded(flex: 5, child: _BrandPanel()),
              Expanded(flex: 6, child: formColumn),
            ],
          );
        },
      ),
    );
  }
}

class _FormColumn extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget form;
  final Widget? footer;
  final bool showBrand;
  final bool showBack;

  const _FormColumn({
    required this.title,
    required this.subtitle,
    required this.form,
    required this.footer,
    required this.showBrand,
    required this.showBack,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        if (showBrand) const Positioned.fill(child: _BackdropGlow()),
        SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (showBrand) ...[
                      const FadeSlideIn(
                        child: Row(
                          children: [
                            BrandMark(size: 44),
                            SizedBox(width: 12),
                            Text('TrackIt', style: AppTextStyles.h2),
                          ],
                        ),
                      ),
                      const SizedBox(height: 36),
                    ],
                    FadeSlideIn(
                      index: 1,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: AppTextStyles.h1.copyWith(fontSize: 30),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            subtitle,
                            style: AppTextStyles.bodyLg.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),
                    FadeSlideIn(index: 2, child: form),
                    if (footer != null) ...[
                      const SizedBox(height: 20),
                      FadeSlideIn(index: 3, child: footer!),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
        if (showBack)
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                onPressed: () => Navigator.of(context).maybePop(),
              ),
            ),
          ),
      ],
    );
  }
}

/// Soft tinted glow behind the phone layout.
class _BackdropGlow extends StatelessWidget {
  const _BackdropGlow();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        children: [
          Positioned(
            top: -120,
            right: -80,
            child: _glow(AppColors.primary, 320),
          ),
          Positioned(
            bottom: -140,
            left: -100,
            child: _glow(AppColors.secondary, 300),
          ),
        ],
      ),
    );
  }

  Widget _glow(Color color, double size) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      gradient: RadialGradient(
        colors: [
          color.withValues(alpha: AppColors.isDark ? 0.22 : 0.14),
          color.withValues(alpha: 0),
        ],
      ),
    ),
  );
}

class _BrandPanel extends StatelessWidget {
  const _BrandPanel();

  static const _features = [
    (Icons.account_balance_wallet_outlined, 'Track spending and budgets'),
    (Icons.fitness_center_rounded, 'Log workouts set by set'),
    (Icons.cloud_sync_outlined, 'Works offline, syncs when you sign in'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(gradient: AppColors.primaryGradient),
      padding: const EdgeInsets.all(48),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const FadeSlideIn(
            child: Row(
              children: [
                BrandMark(size: 44, onGradient: true),
                SizedBox(width: 12),
                Text(
                  'TrackIt',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          FadeSlideIn(
            index: 1,
            child: Text(
              'Spending and training,\nin one place.',
              style: AppTextStyles.h1.copyWith(
                color: Colors.white,
                fontSize: 36,
                height: 1.15,
              ),
            ),
          ),
          const SizedBox(height: 32),
          for (var i = 0; i < _features.length; i++)
            FadeSlideIn(
              index: 2 + i,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        _features[i].$1,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        _features[i].$2,
                        style: AppTextStyles.bodyLg.copyWith(
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const Spacer(),
        ],
      ),
    );
  }
}
