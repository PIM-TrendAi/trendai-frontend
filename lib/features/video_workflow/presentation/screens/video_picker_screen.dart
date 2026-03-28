import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/storage/secure_storage.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/shared_widgets.dart';
import '../../data/models/workflow_models.dart';
import '../../data/n8n_repository.dart';
import '../providers/workflow_provider.dart';

final _trendingVideosProvider =
    FutureProvider<List<TrendingVideoModel>>((ref) {
  // No niche filter — webhook defaults to 'trending' category (78 videos)
  return ref.read(n8nRepositoryProvider).fetchTrendingVideos(niche: null);
});

class VideoPickerScreen extends ConsumerStatefulWidget {
  const VideoPickerScreen({super.key, this.preselectedVideoId});
  final String? preselectedVideoId;

  @override
  ConsumerState<VideoPickerScreen> createState() => _VideoPickerScreenState();
}

class _VideoPickerScreenState extends ConsumerState<VideoPickerScreen> {
  final _promptCtrl = TextEditingController();
  TrendingVideoModel? _selectedVideo;
  String? _niche;

  @override
  void initState() {
    super.initState();
    _loadNiche();
  }

  Future<void> _loadNiche() async {
    final niches = await ref.read(secureStorageProvider).readCreatorNiches();
    if (niches.isNotEmpty && mounted) {
      setState(() => _niche = niches.first);
    }
  }

  @override
  void dispose() {
    _promptCtrl.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    final video = _selectedVideo;
    if (video == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a trending video first.')),
      );
      return;
    }
    if (_promptCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a prompt for your script.')),
      );
      return;
    }

    final profile = await ref.read(secureStorageProvider).readCreatorProfile();
    final creatorId = profile['id'] ?? 'unknown';

    await ref.read(workflowProvider.notifier).startWorkflow(
          creatorId: creatorId,
          selectedVideoId: video.videoId,
          niche: _niche ?? video.niche,
          userPrompt: _promptCtrl.text.trim(),
        );

    if (!mounted) return;
    final state = ref.read(workflowProvider);
    if (state.status == WorkflowStatus.pendingScriptReview) {
      context.go('/script-review');
    } else if (state.status == WorkflowStatus.error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(state.errorMessage ?? 'Failed to generate script'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final videosAsync = ref.watch(_trendingVideosProvider);
    final workflowState = ref.watch(workflowProvider);
    final isLoading = workflowState.status == WorkflowStatus.generatingScript;

    return Scaffold(
      appBar: const TrendAIAppBar(
        title: 'Pick a Trend',
        showBack: true,
      ),
      body: Stack(
        children: [
          const AnimatedParticleBackground(count: 8),
          Column(
            children: [
              // Prompt input
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Your prompt',
                        style: TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 13,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _promptCtrl,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        hintText: 'e.g. Focus on morning routines for busy people',
                        hintStyle: TextStyle(fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),

              // Trending videos list
              Expanded(
                child: videosAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.wifi_off_rounded,
                            color: AppColors.textMuted, size: 48),
                        const SizedBox(height: 12),
                        const Text('Could not load trending videos',
                            style: TextStyle(color: AppColors.textMuted)),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: () =>
                              ref.invalidate(_trendingVideosProvider),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                  data: (videos) {
                    if (videos.isEmpty) {
                      return const Center(
                        child: Text(
                          'No trending videos yet.\nRun the daily scrape first.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.textMuted),
                        ),
                      );
                    }
                    return GridView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                        childAspectRatio: 0.62, // portrait video ratio
                      ),
                      itemCount: videos.length,
                      itemBuilder: (ctx, i) {
                        final v = videos[i];
                        final isSelected = _selectedVideo?.videoId == v.videoId;
                        return GestureDetector(
                          onTap: () => setState(() => _selectedVideo = v),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isSelected
                                    ? AppColors.primary
                                    : Colors.white.withValues(alpha: 0.10),
                                width: isSelected ? 2.5 : 1,
                              ),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(13),
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  // Thumbnail
                                  v.thumbnailUrl.isNotEmpty
                                      ? Image.network(
                                          v.thumbnailUrl,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) =>
                                              _PlaceholderThumb(),
                                        )
                                      : _PlaceholderThumb(),

                                  // Dark gradient at bottom
                                  Positioned(
                                    left: 0, right: 0, bottom: 0,
                                    child: Container(
                                      height: 80,
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          begin: Alignment.bottomCenter,
                                          end: Alignment.topCenter,
                                          colors: [
                                            Colors.black.withValues(alpha: 0.85),
                                            Colors.transparent,
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),

                                  // Author + views at bottom
                                  Positioned(
                                    left: 8, right: 8, bottom: 8,
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          v.author,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        Text(
                                          '${v.views} views',
                                          style: TextStyle(
                                            color: Colors.white
                                                .withValues(alpha: 0.7),
                                            fontSize: 10,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  // Play button (opens TikTok)
                                  Positioned(
                                    top: 8, right: 8,
                                    child: GestureDetector(
                                      onTap: () async {
                                        final uri =
                                            Uri.parse(v.tiktokUrl);
                                        if (await canLaunchUrl(uri)) {
                                          await launchUrl(uri,
                                              mode: LaunchMode
                                                  .externalApplication);
                                        }
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: BoxDecoration(
                                          color: Colors.black
                                              .withValues(alpha: 0.55),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.play_arrow_rounded,
                                          color: Colors.white,
                                          size: 18,
                                        ),
                                      ),
                                    ),
                                  ),

                                  // Selected checkmark
                                  if (isSelected)
                                    Positioned(
                                      top: 8, left: 8,
                                      child: Container(
                                        padding: const EdgeInsets.all(3),
                                        decoration: const BoxDecoration(
                                          gradient: AppColors.gradientPrimary,
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.check_rounded,
                                          color: Colors.white,
                                          size: 14,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),

              // Start button
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                child: GradientButton(
                  label: 'Generate Script',
                  onPressed: _start,
                  isLoading: isLoading,
                  enabled: !isLoading,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PlaceholderThumb extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white10,
      child: const Center(
        child: Icon(Icons.play_circle_outline_rounded,
            color: AppColors.textMuted, size: 40),
      ),
    );
  }
}
