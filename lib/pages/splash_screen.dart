import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/brand_mark.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});
  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _intro = AnimationController(
    duration: const Duration(milliseconds: 1100),
    vsync: this,
  )..forward();

  // Slow breathing glow behind the logo while we wait.
  late final AnimationController _pulse = AnimationController(
    duration: const Duration(milliseconds: 1600),
    vsync: this,
  )..repeat(reverse: true);

  late final Animation<double> _logoScale = CurvedAnimation(
    parent: _intro,
    curve: const Interval(0, 0.6, curve: Curves.easeOutBack),
  );
  late final Animation<double> _textReveal = CurvedAnimation(
    parent: _intro,
    curve: const Interval(0.35, 1, curve: Curves.easeOutCubic),
  );

  // Only show a progress hint if start-up is slower than the intro.
  bool _showProgress = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 1800), () {
      if (mounted) setState(() => _showProgress = true);
    });

    // Wait for auth status to be determined
    Future.microtask(() {
      _checkAuthAndNavigate();
    });
  }

  void _checkAuthAndNavigate() {
    final authState = ref.read(authProvider).state;
    if (authState.status != AuthStatus.initial) {
      _navigateToNext(authState.status);
    } else {
      // Listen for changes
      ref.listenManual(authProvider, (previous, next) {
        if (next.state.status != AuthStatus.initial) {
          _navigateToNext(next.state.status);
        }
      });
    }
  }

  void _navigateToNext(AuthStatus status) {
    if (!mounted) return;

    // Let the intro animation finish before moving on
    Future.delayed(const Duration(milliseconds: 1100), () {
      if (mounted) {
        if (status == AuthStatus.authenticated || status == AuthStatus.local) {
          context.go('/home');
        } else {
          context.go('/login');
        }
      }
    });
  }

  @override
  void dispose() {
    _intro.dispose();
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.splashGradient),
        child: SafeArea(
          child: Stack(
            children: [
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 140,
                      height: 140,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          AnimatedBuilder(
                            animation: _pulse,
                            builder: (context, _) => Container(
                              width: 96 + 40 * _pulse.value,
                              height: 96 + 40 * _pulse.value,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white.withValues(
                                  alpha: 0.14 * (1 - _pulse.value) + 0.04,
                                ),
                              ),
                            ),
                          ),
                          ScaleTransition(
                            scale: _logoScale,
                            child: const BrandMark(size: 84, onGradient: true),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    FadeTransition(
                      opacity: _textReveal,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0, 0.3),
                          end: Offset.zero,
                        ).animate(_textReveal),
                        child: Column(
                          children: [
                            Text(
                              'TrackIt',
                              style: AppTextStyles.h1.copyWith(
                                color: Colors.white,
                                fontSize: 34,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Spending and training, in one place',
                              style: AppTextStyles.bodyMd.copyWith(
                                color: Colors.white.withValues(alpha: 0.8),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 48,
                child: AnimatedOpacity(
                  opacity: _showProgress ? 1 : 0,
                  duration: const Duration(milliseconds: 300),
                  child: Center(
                    child: SizedBox(
                      width: 120,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: LinearProgressIndicator(
                          minHeight: 3,
                          color: Colors.white,
                          backgroundColor: Colors.white.withValues(alpha: 0.2),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
