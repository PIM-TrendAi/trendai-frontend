/// Shared widgets used across the TrendAI app.
/// Includes: AppBarWidget, BottomNavWidget, GradientButton,
///  GlassCard, AnimatedCounter, PlatformBadge.
library;
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';

// ─────────────────────────────────────────────
// AppBar Widget — matches Figma sticky header
// ─────────────────────────────────────────────
class TrendAIAppBar extends StatelessWidget implements PreferredSizeWidget {
  const TrendAIAppBar({
    super.key,
    required this.title,
    this.subtitle,
    this.action,
    this.actions,
    this.showBack = false,
  });

  final String title;
  final String? subtitle;
  final Widget? action;
  final List<Widget>? actions;
  final bool showBack;

  @override
  Size get preferredSize => const Size.fromHeight(72);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F111E) : Colors.white,
        border: Border(
          bottom: BorderSide(
             color: isDark ? Colors.white.withValues(alpha: 0.10) : Colors.black.withValues(alpha: 0.05),
          ),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              if (showBack)
                GestureDetector(
                  onTap: () => context.pop(),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isDark ? Colors.white.withValues(alpha: 0.10) : Colors.grey.shade200,
                      ),
                    ),
                    child: Icon(Icons.arrow_back_ios_new, size: 16, color: isDark ? Colors.white : AppColors.textLight),
                  ),
                )
              else
                const SizedBox(width: 36),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                          ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.auto_awesome_rounded, size: 12, color: AppColors.primary),
                          const SizedBox(width: 4),
                          Text(
                            subtitle!,
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                  color: AppColors.textMuted,
                                  fontWeight: FontWeight.w500,
                                ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              if (actions != null)
                Row(mainAxisSize: MainAxisSize.min, children: actions!)
              else
                SizedBox(width: 36, child: action),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Bottom Nav Bar — glassmorphism floating pill
// ─────────────────────────────────────────────
class TrendAIBottomNav extends StatelessWidget {
  const TrendAIBottomNav({super.key, required this.currentIndex});
  final int currentIndex;

  static const _routes = ['/dashboard', '/trends', '/n8n-picker', '/my-videos', '/analytics', '/profile'];
  static const _labels = ['Home', 'Trends', 'Agent', 'Videos', 'Stats', 'Me'];
  static const _icons = [
    Icons.home_rounded,
    Icons.trending_up_rounded,
    Icons.auto_awesome_rounded,
    Icons.video_library_rounded,
    Icons.bar_chart_rounded,
    Icons.person_rounded,
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? null : Colors.white.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(40),
        gradient: isDark
            ? LinearGradient(
                colors: [
                  Colors.white.withValues(alpha: 0.08),
                  Colors.white.withValues(alpha: 0.04),
                ],
              )
            : null,
        border: Border.all(
            color: isDark ? Colors.white.withValues(alpha: 0.12) : Colors.black.withValues(alpha: 0.05)),
        boxShadow: isDark ? null : [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 20)],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: List.generate(_routes.length, (i) {
          final isActive = i == currentIndex;
          return GestureDetector(
            onTap: () => context.go(_routes[i]),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: isActive ? AppColors.gradientPrimary : null,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                   Icon(
                    _icons[i],
                    size: 22,
                    color: isActive ? Colors.white : (isDark ? AppColors.textMuted : AppColors.textMuted.withValues(alpha: 0.7)),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _labels[i],
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      color: isActive ? Colors.white : AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Gradient Button — primary CTA
// ─────────────────────────────────────────────
class GradientButton extends StatelessWidget {
  const GradientButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
    this.enabled = true,
  });

  final String label;
  final VoidCallback onPressed;
  final IconData? icon;
  final bool isLoading;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled && !isLoading ? onPressed : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 56,
        decoration: BoxDecoration(
          gradient: enabled ? AppColors.gradientPrimary : const LinearGradient(
            colors: [Color(0xFF555555), Color(0xFF555555)],
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Center(
          child: isLoading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (icon != null) ...[Icon(icon, size: 18), const SizedBox(width: 8)],
                    Text(
                      label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Glass Card — backdrop blur card
// ─────────────────────────────────────────────
class GlassCard extends StatelessWidget {
  const GlassCard({super.key, required this.child, this.padding, this.borderRadius});
  final Widget child;
  final EdgeInsets? padding;
  final double? borderRadius;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white.withValues(alpha: 0.80),
        borderRadius: BorderRadius.circular(borderRadius ?? 20),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.10)
              : Colors.black.withValues(alpha: 0.06),
        ),
      ),
      child: child,
    );
  }
}

// ─────────────────────────────────────────────
// Platform Badge
// ─────────────────────────────────────────────
class PlatformBadge extends StatelessWidget {
  const PlatformBadge({super.key, required this.platform});
  final String platform;

  Color _color() {
    switch (platform) {
      case 'TikTok': return AppColors.tikTok.withValues(alpha: 0.20);
      case 'Instagram': return AppColors.instagram.withValues(alpha: 0.20);
      case 'YouTube': return AppColors.youtube.withValues(alpha: 0.20);
      case 'Facebook': return AppColors.facebook.withValues(alpha: 0.20);
      default: return Colors.white.withValues(alpha: 0.10);
    }
  }

  Color _textColor() {
    switch (platform) {
      case 'TikTok': return AppColors.tikTok;
      case 'Instagram': return AppColors.instagram;
      case 'YouTube': return AppColors.youtube;
      case 'Facebook': return AppColors.facebook;
      default: return AppColors.textMuted;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _color(),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(platform, style: TextStyle(color: _textColor(), fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }
}

// ─────────────────────────────────────────────
// Trend Type Icon
// ─────────────────────────────────────────────
class TrendTypeIcon extends StatelessWidget {
  const TrendTypeIcon({super.key, required this.type});
  final String type;

  @override
  Widget build(BuildContext context) {
    IconData icon;
    Color color;
    switch (type) {
      case 'audio':
        icon = Icons.music_note_rounded;
        color = AppColors.accent;
        break;
      case 'video':
        icon = Icons.videocam_rounded;
        color = AppColors.primary;
        break;
      default:
        icon = Icons.tag_rounded;
        color = AppColors.primary;
    }
    return Icon(icon, color: color, size: 20);
  }
}

// ─────────────────────────────────────────────
// Gradient Text
// ─────────────────────────────────────────────
class GradientText extends StatelessWidget {
  const GradientText(this.text, {super.key, this.style});
  final String text;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (bounds) => AppColors.gradientPrimaryHorizontal.createShader(bounds),
      child: Text(text, style: style),
    );
  }
}

// ─────────────────────────────────────────────
// Animated background particles (background decoration)
// ─────────────────────────────────────────────
class AnimatedParticleBackground extends StatefulWidget {
  const AnimatedParticleBackground({super.key, this.count = 20});
  final int count;

  @override
  State<AnimatedParticleBackground> createState() =>
      _AnimatedParticleBackgroundState();
}

class _AnimatedParticleBackgroundState
    extends State<AnimatedParticleBackground> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 10))
      ..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, __) => CustomPaint(
        painter: _ParticlePainter(_controller.value, widget.count),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _ParticlePainter extends CustomPainter {
  _ParticlePainter(this.t, this.count);
  final double t;
  final int count;
  static final _rng = math.Random(42);
  static late final List<double> _oxList;
  static late final List<double> _oyList;
  static late final List<double> _speedList;
  static bool _init = false;

  static void _initParticles(int n) {
    if (_init) return;
    _oxList = List.generate(n, (_) => _rng.nextDouble());
    _oyList = List.generate(n, (_) => _rng.nextDouble());
    _speedList = List.generate(n, (_) => 0.3 + _rng.nextDouble() * 0.7);
    _init = true;
  }

  @override
  void paint(Canvas canvas, Size size) {
    _initParticles(count);
    final paint = Paint()..style = PaintingStyle.fill;
    for (var i = 0; i < count; i++) {
      final progress = (_oyList[i] + t * _speedList[i]) % 1.0;
      final x = _oxList[i] * size.width;
      final y = (1 - progress) * size.height;
      final opacity = (progress < 0.2
          ? progress / 0.2
          : progress > 0.8
              ? (1 - progress) / 0.2
              : 1.0) * 0.15;
      paint.color = (i.isEven ? AppColors.primary : AppColors.accent)
          .withValues(alpha: opacity);
      canvas.drawCircle(Offset(x, y), 2, paint);
    }
  }

  @override
  bool shouldRepaint(_ParticlePainter old) => old.t != t;
}
