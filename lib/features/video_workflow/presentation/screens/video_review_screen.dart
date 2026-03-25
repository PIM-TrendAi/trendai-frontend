import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:video_player/video_player.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/shared_widgets.dart';
import '../providers/workflow_provider.dart';

class VideoReviewScreen extends ConsumerStatefulWidget {
  const VideoReviewScreen({super.key});

  @override
  ConsumerState<VideoReviewScreen> createState() => _VideoReviewScreenState();
}

class _VideoReviewScreenState extends ConsumerState<VideoReviewScreen> {
  VideoPlayerController? _controller;
  bool _controllerReady = false;

  @override
  void initState() {
    super.initState();
    _initVideo();
  }

  Future<void> _initVideo() async {
    final url = ref.read(workflowProvider).videoUrl;
    if (url == null || url.isEmpty) return;
    final ctrl = VideoPlayerController.networkUrl(Uri.parse(url));
    await ctrl.initialize();
    ctrl.setLooping(true);
    ctrl.play();
    if (mounted) {
      setState(() {
        _controller = ctrl;
        _controllerReady = true;
      });
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _approve() async {
    await ref.read(workflowProvider.notifier).approveVideo();
    if (!mounted) return;
    final state = ref.read(workflowProvider);
    if (state.status == WorkflowStatus.done) {
      ref.read(workflowProvider.notifier).reset();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Video posted to TikTok!'),
          backgroundColor: AppColors.success,
        ),
      );
      context.go('/dashboard');
    }
  }

  Future<void> _decline() async {
    await ref.read(workflowProvider.notifier).declineVideo();
    if (!mounted) return;
    context.go('/video-generation');
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(workflowProvider);
    final isPosting = state.status == WorkflowStatus.posting;
    final isRegenerating = state.status == WorkflowStatus.generatingVideo;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Review Video'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: Stack(
        children: [
          const AnimatedParticleBackground(count: 8),
          SafeArea(
            child: Column(
              children: [
                // Video player
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: _controllerReady && _controller != null
                          ? Stack(
                              alignment: Alignment.center,
                              children: [
                                AspectRatio(
                                  aspectRatio: _controller!.value.aspectRatio,
                                  child: VideoPlayer(_controller!),
                                ),
                                // Play/pause tap overlay
                                GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _controller!.value.isPlaying
                                          ? _controller!.pause()
                                          : _controller!.play();
                                    });
                                  },
                                  child: Container(color: Colors.transparent),
                                ),
                                // Pause icon flash
                                if (!(_controller?.value.isPlaying ?? true))
                                  const Icon(Icons.pause_circle_outline_rounded,
                                      size: 64, color: Colors.white70),
                              ],
                            )
                          : Container(
                              color: Colors.white10,
                              child: const Center(
                                child: CircularProgressIndicator(),
                              ),
                            ),
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // Buttons
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: isPosting || isRegenerating
                              ? null
                              : _decline,
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('Regenerate'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            side: const BorderSide(
                                color: AppColors.textMuted, width: 1),
                            foregroundColor: AppColors.textMuted,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: GradientButton(
                          label: 'Post to TikTok',
                          onPressed: isPosting || isRegenerating
                              ? () {}
                              : _approve,
                          isLoading: isPosting,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
