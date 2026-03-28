// Three onboarding screens (pages 1, 2, 3) based on the Figma design.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/shared_widgets.dart';

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key, required this.page});
  final int page;

  static const _data = [
    _OnboardingData(
      emoji: '🔥',
      title: 'Discover\nViral Trends',
      subtitle: 'Track what\'s exploding on TikTok, Instagram, YouTube, and more — in real time.',
    ),
    _OnboardingData(
      emoji: '🤖',
      title: 'AI-Powered\nScript Generator',
      subtitle: 'Turn any idea into a viral script with hooks, CTAs, and hashtags — in seconds.',
    ),
    _OnboardingData(
      emoji: '📊',
      title: 'Deep Platform\nAnalytics',
      subtitle: 'Understand your performance across every platform with beautiful visual insights.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final d = _data[page - 1];
    final isLast = page == 3;

    return Scaffold(
      body: Stack(
        children: [
          const AnimatedParticleBackground(),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                children: [
                  const SizedBox(height: 24),
                  // Top row: dots + skip
                  Row(
                    children: [
                      const Spacer(),
                      // Progress dots
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(3, (i) => AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          width: i == page - 1 ? 24 : 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: i == page - 1 ? AppColors.primary : Colors.white24,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        )),
                      ),
                      const Spacer(),
                      if (!isLast)
                        GestureDetector(
                          onTap: () => context.go('/signup'),
                          child: const Text('Skip',
                              style: TextStyle(color: AppColors.textMuted, fontSize: 14, fontWeight: FontWeight.w600)),
                        ),
                      if (isLast) const SizedBox(width: 32),
                    ],
                  ),
                  const Spacer(),
                  // Hero illustration
                  Container(
                    width: 160,
                    height: 160,
                    decoration: BoxDecoration(
                      gradient: AppColors.gradientPrimary,
                      borderRadius: BorderRadius.circular(40),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.4),
                          blurRadius: 60,
                          spreadRadius: 10,
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(d.emoji, style: const TextStyle(fontSize: 72)),
                    ),
                  ),
                  const SizedBox(height: 48),
                  Text(
                    d.title,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.displaySmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          height: 1.2,
                        ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    d.subtitle,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.textMuted, fontSize: 15, height: 1.6),
                  ),
                  const Spacer(),
                  GradientButton(
                    label: isLast ? 'Get Started' : 'Next',
                    icon: isLast ? Icons.rocket_launch_rounded : Icons.arrow_forward_rounded,
                    onPressed: () => context.go(isLast ? '/signup' : '/onboarding-${page + 1}'),
                  ),
                  const SizedBox(height: 16),
                  if (!isLast)
                    TextButton(
                      onPressed: () => context.go('/login'),
                      child: const Text('Already have an account?  Login',
                          style: TextStyle(color: AppColors.textMuted)),
                    ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OnboardingData {
  const _OnboardingData({
    required this.emoji,
    required this.title,
    required this.subtitle,
  });
  final String emoji;
  final String title;
  final String subtitle;
}
