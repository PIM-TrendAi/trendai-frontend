import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../../core/theme/app_theme.dart';

// ── Tutorial service ─────────────────────────────────────────────────────────
// Controls who sees tutorials and which pages have already been shown.
// Call setNewUser() on signup, clearNewUser() on login.

class TutorialService {
  static const _keyNewUser = 'tutorial_new_user_active';

  /// Mark this device session as a fresh signup — enables tutorials on all pages.
  static Future<void> setNewUser() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyNewUser, true);
    // Reset every per-page flag so tutorials play fresh.
    for (final k in ['dashboard', 'trends', 'analytics', 'profile']) {
      await prefs.remove('tutorial_seen_$k');
    }
  }

  /// Call on login so returning users never see the tutorial.
  static Future<void> clearNewUser() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyNewUser, false);
  }

  static Future<bool> _isNewUser() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyNewUser) ?? false;
  }

  static Future<void> _markPageSeen(String pageKey) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('tutorial_seen_$pageKey', true);
  }

  static Future<bool> _hasSeenPage(String pageKey) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('tutorial_seen_$pageKey') ?? false;
  }

  /// Returns true only for brand-new accounts that haven't seen this page yet.
  static Future<bool> shouldShowFor(String pageKey) async {
    if (!await _isNewUser()) return false;
    return !await _hasSeenPage(pageKey);
  }
}

// ── Step definition ──────────────────────────────────────────────────────────

class TutorialStep {
  final GlobalKey targetKey;
  final String title;
  final String body;
  /// true  = tooltip appears BELOW the target (arrow points up)
  /// false = tooltip appears ABOVE the target (arrow points down)
  final bool tooltipBelow;

  const TutorialStep({
    required this.targetKey,
    required this.title,
    required this.body,
    this.tooltipBelow = true,
  });
}

// ── Public entry-point ───────────────────────────────────────────────────────

/// Insert the tutorial overlay into the nearest [Overlay].
/// [pageKey] matches the keys used in [TutorialService] ('dashboard', 'trends', …).
/// Call from [addPostFrameCallback] so all GlobalKeys are mounted.
OverlayEntry showPageTutorial(
  BuildContext context,
  String pageKey,
  List<TutorialStep> steps,
) {
  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => _TutorialOverlay(
      steps: steps,
      onDone: () {
        TutorialService._markPageSeen(pageKey);
        entry.remove();
      },
    ),
  );
  Overlay.of(context).insert(entry);
  return entry;
}

// ── Overlay widget ───────────────────────────────────────────────────────────

class _TutorialOverlay extends StatefulWidget {
  final List<TutorialStep> steps;
  final VoidCallback onDone;

  const _TutorialOverlay({required this.steps, required this.onDone});

  @override
  State<_TutorialOverlay> createState() => _TutorialOverlayState();
}

class _TutorialOverlayState extends State<_TutorialOverlay>
    with SingleTickerProviderStateMixin {
  int _step = 0;
  late AnimationController _ctrl;
  late Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      duration: const Duration(milliseconds: 280),
      vsync: this,
    );
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _advance() {
    if (_step < widget.steps.length - 1) {
      setState(() => _step++);
    } else {
      widget.onDone();
    }
  }

  Rect? _targetRect(GlobalKey key) {
    final ctx = key.currentContext;
    if (ctx == null) return null;
    final box = ctx.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  @override
  Widget build(BuildContext context) {
    final step = widget.steps[_step];
    final rect = _targetRect(step.targetKey);

    return FadeTransition(
      opacity: _fade,
      child: _StepView(
        targetRect: rect,
        title: step.title,
        body: step.body,
        tooltipBelow: step.tooltipBelow,
        stepIndex: _step,
        totalSteps: widget.steps.length,
        onNext: _advance,
        onSkip: widget.onDone,
      ),
    );
  }
}

// ── Single-step view ─────────────────────────────────────────────────────────

class _StepView extends StatelessWidget {
  final Rect? targetRect;
  final String title;
  final String body;
  final bool tooltipBelow;
  final int stepIndex;
  final int totalSteps;
  final VoidCallback onNext;
  final VoidCallback onSkip;

  const _StepView({
    required this.targetRect,
    required this.title,
    required this.body,
    required this.tooltipBelow,
    required this.stepIndex,
    required this.totalSteps,
    required this.onNext,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final topPad = MediaQuery.of(context).padding.top;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onNext,
      child: Stack(
        children: [
          // ── Dark backdrop with spotlight hole
          CustomPaint(
            size: size,
            painter: _SpotlightPainter(targetRect: targetRect),
          ),

          // ── Tooltip + arrow
          if (targetRect != null)
            _buildTooltip(context, size),

          // ── Skip button (top-right)
          Positioned(
            top: topPad + 14,
            right: 18,
            child: GestureDetector(
              onTap: onSkip,
              behavior: HitTestBehavior.opaque,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.25),
                  ),
                ),
                child: const Text(
                  'Skip',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),

          // ── Step counter (top-left)
          Positioned(
            top: topPad + 14,
            left: 18,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                gradient: AppColors.gradientPrimary,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${stepIndex + 1} / $totalSteps',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTooltip(BuildContext context, Size size) {
    const tooltipW = 270.0;
    const hPad = 16.0;
    const arrowH = 14.0;
    const gap = 10.0;

    final rect = targetRect!;

    // Horizontal: center on target, clamp to screen edges
    double left = rect.center.dx - tooltipW / 2;
    left = left.clamp(hPad, size.width - tooltipW - hPad);

    // Arrow tip X relative to tooltip left edge, clamped
    final tipX = (rect.center.dx - left).clamp(24.0, tooltipW - 24.0);

    // Vertical
    final double top;
    if (tooltipBelow) {
      top = rect.bottom + gap;
    } else {
      // Position above: we don't know height yet, use approx 160
      top = rect.top - arrowH - gap - 160;
    }

    return Positioned(
      left: left,
      top: top.clamp(
        MediaQuery.of(context).padding.top + 60,
        size.height - 200,
      ),
      width: tooltipW,
      child: GestureDetector(
        onTap: onNext,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Arrow above card
            if (tooltipBelow)
              _Arrow(tipX: tipX, pointingUp: true),

            // Card
            _TooltipCard(
              title: title,
              body: body,
              stepIndex: stepIndex,
              totalSteps: totalSteps,
              onNext: onNext,
            ),

            // Arrow below card
            if (!tooltipBelow)
              _Arrow(tipX: tipX, pointingUp: false),
          ],
        ),
      ),
    );
  }
}

// ── Spotlight painter ─────────────────────────────────────────────────────────

class _SpotlightPainter extends CustomPainter {
  final Rect? targetRect;

  const _SpotlightPainter({this.targetRect});

  @override
  void paint(Canvas canvas, Size size) {
    final screenRect = Offset.zero & size;

    if (targetRect == null) {
      canvas.drawRect(
        screenRect,
        Paint()..color = Colors.black.withValues(alpha: 0.78),
      );
      return;
    }

    final spotlight = targetRect!.inflate(10);
    final rRect = RRect.fromRectAndRadius(
      spotlight,
      const Radius.circular(14),
    );

    // Semi-transparent backdrop with hole
    final path = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(screenRect)
      ..addRRect(rRect);

    canvas.drawPath(
      path,
      Paint()..color = Colors.black.withValues(alpha: 0.78),
    );

    // Glow border around spotlight
    canvas.drawRRect(
      rRect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = AppColors.primary.withValues(alpha: 0.7)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    canvas.drawRRect(
      rRect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = AppColors.accent.withValues(alpha: 0.5),
    );
  }

  @override
  bool shouldRepaint(_SpotlightPainter old) =>
      old.targetRect != targetRect;
}

// ── Arrow widget ──────────────────────────────────────────────────────────────

class _Arrow extends StatelessWidget {
  final double tipX;
  final bool pointingUp; // true = ▲ (tip at top), false = ▼ (tip at bottom)

  const _Arrow({required this.tipX, required this.pointingUp});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(double.infinity, 14),
      painter: _ArrowPainter(tipX: tipX, pointingUp: pointingUp),
    );
  }
}

class _ArrowPainter extends CustomPainter {
  final double tipX;
  final bool pointingUp;

  const _ArrowPainter({required this.tipX, required this.pointingUp});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF1A1D2E)
      ..style = PaintingStyle.fill;

    final path = Path();
    if (pointingUp) {
      // Triangle pointing up (tip at top, base at bottom)
      path
        ..moveTo(tipX, 0)
        ..lineTo(tipX - 10, size.height)
        ..lineTo(tipX + 10, size.height)
        ..close();
    } else {
      // Triangle pointing down (tip at bottom, base at top)
      path
        ..moveTo(tipX, size.height)
        ..lineTo(tipX - 10, 0)
        ..lineTo(tipX + 10, 0)
        ..close();
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_ArrowPainter old) =>
      old.tipX != tipX || old.pointingUp != pointingUp;
}

// ── Tooltip card ──────────────────────────────────────────────────────────────

class _TooltipCard extends StatelessWidget {
  final String title;
  final String body;
  final int stepIndex;
  final int totalSteps;
  final VoidCallback onNext;

  const _TooltipCard({
    required this.title,
    required this.body,
    required this.stepIndex,
    required this.totalSteps,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final isLast = stepIndex == totalSteps - 1;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1D2E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.35),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.18),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Title
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),

          // Body
          Text(
            body,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.72),
              fontSize: 13,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),

          // Progress dots + Next button
          Row(
            children: [
              // Dots
              Row(
                children: List.generate(totalSteps, (i) {
                  final active = i == stepIndex;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.only(right: 5),
                    width: active ? 18 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(3),
                      gradient: active ? AppColors.gradientPrimary : null,
                      color: active
                          ? null
                          : Colors.white.withValues(alpha: 0.25),
                    ),
                  );
                }),
              ),
              const Spacer(),

              // Next / Done button
              GestureDetector(
                onTap: onNext,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    gradient: AppColors.gradientPrimary,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    isLast ? 'Done' : 'Next',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Curved arrow painter (decorative, used as overlay accent) ─────────────────

class CurvedArrowPainter extends CustomPainter {
  final Color color;
  final bool flipHorizontal;

  const CurvedArrowPainter({
    this.color = AppColors.primary,
    this.flipHorizontal = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (flipHorizontal) {
      canvas.scale(-1, 1);
      canvas.translate(-size.width, 0);
    }

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    final path = Path();
    path.moveTo(size.width * 0.1, size.height * 0.9);
    path.cubicTo(
      size.width * 0.1, size.height * 0.3,
      size.width * 0.7, size.height * 0.3,
      size.width * 0.85, size.height * 0.1,
    );
    canvas.drawPath(path, paint);

    // Arrowhead
    final tip = Offset(size.width * 0.85, size.height * 0.1);
    final angle = atan2(
      size.height * 0.1 - size.height * 0.3,
      size.width * 0.85 - size.width * 0.7,
    );
    const arrowLen = 10.0;
    const arrowAngle = 0.5;

    canvas.drawLine(
      tip,
      Offset(
        tip.dx - arrowLen * cos(angle - arrowAngle),
        tip.dy - arrowLen * sin(angle - arrowAngle),
      ),
      paint..style = PaintingStyle.stroke,
    );
    canvas.drawLine(
      tip,
      Offset(
        tip.dx - arrowLen * cos(angle + arrowAngle),
        tip.dy - arrowLen * sin(angle + arrowAngle),
      ),
      paint,
    );
  }

  @override
  bool shouldRepaint(CurvedArrowPainter old) =>
      old.color != color || old.flipHorizontal != flipHorizontal;
}
