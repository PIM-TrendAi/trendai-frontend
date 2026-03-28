import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/shared_widgets.dart';
import '../providers/workflow_provider.dart';

class VideoGenerationScreen extends ConsumerStatefulWidget {
  const VideoGenerationScreen({super.key});

  @override
  ConsumerState<VideoGenerationScreen> createState() =>
      _VideoGenerationScreenState();
}

class _VideoGenerationScreenState
    extends ConsumerState<VideoGenerationScreen> {
  Timer? _timer;
  int _elapsedSeconds = 0;
  static const _maxWaitSeconds = 120; // 2 minutes then show error

  @override
  void initState() {
    super.initState();
    _startPolling();
  }

  void _startPolling() {
    _timer = Timer.periodic(const Duration(seconds: 5), (_) async {
      if (!mounted) return;
      _elapsedSeconds += 5;
      if (_elapsedSeconds >= _maxWaitSeconds) {
        _timer?.cancel();
        setState(() {}); // trigger error UI rebuild
        return;
      }
      await ref.read(workflowProvider.notifier).pollVideoStatus();
      if (!mounted) return;
      final status = ref.read(workflowProvider).status;
      if (status == WorkflowStatus.pendingVideoReview) {
        _timer?.cancel();
        context.go('/video-review');
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final timedOut = _elapsedSeconds >= _maxWaitSeconds;

    return Scaffold(
      body: Stack(
        children: [
          const AnimatedParticleBackground(count: 15),
          SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: timedOut ? _buildErrorState(context) : _buildLoadingState(context),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 120,
          height: 120,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: AppColors.gradientPrimary,
          ),
          child: const Icon(
            Icons.movie_creation_outlined,
            color: Colors.white,
            size: 56,
          ),
        )
            .animate(onPlay: (c) => c.repeat())
            .scaleXY(
                begin: 1.0,
                end: 1.08,
                duration: const Duration(seconds: 1),
                curve: Curves.easeInOut)
            .then()
            .scaleXY(
                begin: 1.08,
                end: 1.0,
                duration: const Duration(seconds: 1),
                curve: Curves.easeInOut),
        const SizedBox(height: 36),
        Text(
          'Generating your video',
          style: Theme.of(context)
              .textTheme
              .headlineSmall
              ?.copyWith(fontWeight: FontWeight.w800),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        const Text(
          'AI is creating your video based on the approved script. This usually takes 1–3 minutes.',
          style: TextStyle(color: AppColors.textMuted, height: 1.5),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 40),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(3, (i) {
            return Container(
              width: 10,
              height: 10,
              margin: const EdgeInsets.symmetric(horizontal: 5),
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary,
              ),
            )
                .animate(
                    delay: Duration(milliseconds: i * 300),
                    onPlay: (c) => c.repeat())
                .fadeIn(duration: const Duration(milliseconds: 400))
                .then()
                .fadeOut(duration: const Duration(milliseconds: 400));
          }),
        ),
      ],
    );
  }

  Widget _buildErrorState(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.orange.withValues(alpha: 0.15),
            border: Border.all(color: Colors.orange.withValues(alpha: 0.4), width: 2),
          ),
          child: const Icon(
            Icons.warning_amber_rounded,
            color: Colors.orange,
            size: 56,
          ),
        ).animate().scale(duration: const Duration(milliseconds: 400), curve: Curves.elasticOut),
        const SizedBox(height: 36),
        Text(
          'Video generation unavailable',
          style: Theme.of(context)
              .textTheme
              .headlineSmall
              ?.copyWith(fontWeight: FontWeight.w800),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.orange.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.orange.withValues(alpha: 0.25)),
          ),
          child: const Text(
            'The AI video service could not be reached. This usually means the service is unavailable or requires a paid plan.',
            style: TextStyle(color: AppColors.textMuted, height: 1.6),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 32),
        GradientButton(
          label: 'Go Back to Script',
          onPressed: () {
            ref.read(workflowProvider.notifier).reset();
            context.go('/video-picker');
          },
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: () {
            setState(() => _elapsedSeconds = 0);
            _startPolling();
          },
          child: const Text(
            'Try again anyway',
            style: TextStyle(color: AppColors.textMuted),
          ),
        ),
      ],
    ).animate().fadeIn(duration: const Duration(milliseconds: 400));
  }
}
