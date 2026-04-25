import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/network/dio_client.dart';
import '../../../../core/storage/secure_storage.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/shared_widgets.dart';
import '../../../auth/data/models.dart';
import '../../../auth/auth_repository.dart';
import '../../data/models/workflow_models.dart';
import '../../data/n8n_repository.dart';
import '../providers/workflow_provider.dart';

// Keywords associated with each niche for loose client-side matching
const _nicheKeywords = <String, List<String>>{
  'entertainment': ['entertainment', 'funny', 'comedy', 'viral', 'fun', 'meme', 'prank', 'challenge', 'skit'],
  'education': ['education', 'learn', 'tutorial', 'howto', 'tips', 'facts', 'science', 'history', 'study'],
  'business': ['business', 'entrepreneur', 'startup', 'marketing', 'sales', 'ceo', 'hustle', 'success'],
  'finance': ['finance', 'money', 'investing', 'stocks', 'crypto', 'budget', 'wealth', 'financial', 'income'],
  'fitness': ['fitness', 'workout', 'gym', 'health', 'exercise', 'diet', 'nutrition', 'training', 'muscle'],
  'motivation': ['motivation', 'mindset', 'inspire', 'success', 'goals', 'growth', 'positivity', 'mindfulness'],
  'gaming': ['gaming', 'gamer', 'game', 'gameplay', 'esports', 'twitch', 'ps5', 'xbox', 'minecraft', 'fortnite'],
  'art': ['art', 'design', 'drawing', 'painting', 'creative', 'artist', 'illustration', 'sketch', 'digital'],
  'fashion': ['fashion', 'style', 'outfit', 'ootd', 'clothing', 'beauty', 'makeup', 'skincare', 'aesthetic'],
  'cooking': ['cooking', 'food', 'recipe', 'chef', 'baking', 'meal', 'kitchen', 'eat', 'delicious'],
  'travel': ['travel', 'adventure', 'explore', 'trip', 'vacation', 'wanderlust', 'destination', 'vlog'],
  'tech': ['tech', 'technology', 'coding', 'programming', 'ai', 'software', 'developer', 'gadget', 'review'],
  'podcast': ['podcast', 'interview', 'talk', 'discussion', 'story', 'storytelling', 'narration'],
  'news': ['news', 'politics', 'world', 'breaking', 'update', 'current', 'economy', 'report'],
  'storytelling': ['story', 'storytelling', 'narrative', 'tale', 'sharing', 'life', 'experience'],
};

bool _matchesNiche(TrendingVideoModel v, String niche) {
  final keywords = _nicheKeywords[niche.toLowerCase()] ?? [niche.toLowerCase()];
  final haystack = [
    v.title,
    v.niche,
    ...v.hashtags,
  ].join(' ').toLowerCase();
  return keywords.any((kw) => haystack.contains(kw));
}

String _pageNameFromUrl(String? url) {
  if (url == null || url.isEmpty) return '';
  final parts = url.replaceAll(RegExp(r'\?.*'), '').split('/').where((s) => s.isNotEmpty).toList();
  return parts.isNotEmpty ? parts.last : '';
}

String _formatViewCount(int count) {
  if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)}M';
  if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}K';
  if (count > 0) return count.toString();
  return '';
}

// (niche, platform)
final _trendingVideosProvider =
    FutureProvider.family<List<TrendingVideoModel>, (String?, String)>((ref, params) async {
  final (niche, platform) = params;
  final dio = ref.read(dioProvider);

  if (platform == 'instagram') {
    final res = await dio.get('/n8n/trending_videos/');
    final list = res.data['results'] as List? ?? res.data as List;
    return list.cast<Map<String, dynamic>>().map((json) => TrendingVideoModel(
      videoId: json['video_id'] as String? ?? '',
      title: json['title'] as String? ?? 'Instagram Reel',
      author: '',
      thumbnailUrl: json['thumbnail_url'] as String? ?? '',
      views: '',
      likes: '',
      niche: json['category'] as String? ?? 'Instagram',
    )).toList();
  }

  if (platform == 'facebook') {
    // Pass the user's niche so the backend returns only matching reels
    final nicheParam = niche != null && niche.isNotEmpty ? niche.toLowerCase() : 'general';
    final res = await dio.get('/n8n/facebook_reels/', queryParameters: {'niche': nicheParam, 'limit': 20});
    final list = res.data is List ? res.data as List : (res.data['results'] as List? ?? []);
    return list.cast<Map<String, dynamic>>().map((json) {
      final reel = FacebookReelModel.fromJson(json);
      final pageName = _pageNameFromUrl(reel.pageUrl);
      return TrendingVideoModel(
        videoId: reel.reelId,
        title: (reel.text != null && reel.text!.isNotEmpty) ? reel.text! : (pageName.isNotEmpty ? pageName : 'Facebook Reel'),
        author: pageName,
        thumbnailUrl: reel.thumbnailUrl ?? '',
        views: _formatViewCount(reel.playCount),
        likes: '',
        niche: reel.niche ?? nicheParam,
        hashtags: reel.niche != null ? [reel.niche!] : [],
        tiktokUrl: reel.reelUrl ?? '',
      );
    }).toList();
  }

  if (platform == 'youtube') {
    final res = await dio.get('/trends/youtube-videos/');
    final list = res.data['results'] as List? ?? res.data as List;
    return list.cast<Map<String, dynamic>>().map((json) {
      final video = YouTubeVideoModel.fromJson(json);
      final tags = (video.tags ?? '').split(RegExp(r'[,\s]+')).where((t) => t.isNotEmpty).toList();
      return TrendingVideoModel(
        videoId: video.videoId,
        title: video.titre ?? 'YouTube Video',
        author: '',
        thumbnailUrl: 'https://img.youtube.com/vi/${video.videoId}/hqdefault.jpg',
        views: _formatViewCount(video.vues),
        likes: '',
        niche: video.niche ?? 'YouTube',
        hashtags: tags,
        tiktokUrl: 'https://www.youtube.com/watch?v=${video.videoId}',
      );
    }).toList();
  }

  // TikTok
  final repo = ref.read(n8nRepositoryProvider);
  final all = await repo.fetchTrendingVideos(niche: null, platform: platform);
  if (niche == null || niche.isEmpty) return all;
  final filtered = all.where((v) => _matchesNiche(v, niche)).toList();
  return filtered.isNotEmpty ? filtered : all;
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
  String _selectedPlatform = 'tiktok';
  String? _selectedNiche;

  Future<void> _triggerScrape(String platform) async {
    final dio = ref.read(dioProvider);
    final categories = ref.read(authNotifierProvider).valueOrNull?.categories;
    final fallbackNiche = (categories != null && categories.isNotEmpty) ? categories.first : 'general';
    final niche = _selectedNiche ?? fallbackNiche;
    try {
      await dio.post('/n8n/trigger-scrape/', data: {'platform': platform, 'niche': niche});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Scraping $platform "$niche"... 🔄')),
        );
        await Future.delayed(const Duration(seconds: 3));
        if (mounted) ref.invalidate(_trendingVideosProvider((niche, platform)));
      }
    } catch (_) {}
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

    // All platforms: direct n8n webhook flow → script review screen

    // TikTok: direct n8n webhook flow → script review screen
    final profile = await ref.read(secureStorageProvider).readCreatorProfile();
    final creatorId = profile['id'] ?? 'unknown';

    await ref.read(workflowProvider.notifier).startWorkflow(
          creatorId: creatorId,
          selectedVideoId: video.videoId,
          videoTitle: video.title,
          videoAuthor: video.author,
          videoHashtags: video.hashtags,
          videoViews: video.views,
          videoLikes: video.likes,
          niche: _selectedNiche ?? ref.read(authNotifierProvider).valueOrNull?.categories.firstOrNull ?? video.niche,
          userPrompt: _promptCtrl.text.trim(),
          platform: _selectedPlatform,
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
    final categories = ref.watch(authNotifierProvider).valueOrNull?.categories;
    final fallbackNiche = (categories != null && categories.isNotEmpty) ? categories.first : 'general';
    final currentNiche = _selectedNiche ?? fallbackNiche;
    final videosAsync = ref.watch(_trendingVideosProvider((currentNiche, _selectedPlatform)));
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

              // Platform selector
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _PlatformChip(
                        label: 'TikTok',
                        brandColor: const Color(0xFF69C9D0),
                        icon: Icons.music_note_rounded,
                        isSelected: _selectedPlatform == 'tiktok',
                        onTap: () => setState(() {
                          _selectedPlatform = 'tiktok';
                          _selectedVideo = null;
                        }),
                      ),
                      const SizedBox(width: 8),
                      _PlatformChip(
                        label: 'Instagram',
                        brandColor: const Color(0xFFE1306C),
                        icon: Icons.camera_alt_rounded,
                        isSelected: _selectedPlatform == 'instagram',
                        onTap: () => setState(() {
                          _selectedPlatform = 'instagram';
                          _selectedVideo = null;
                        }),
                      ),
                      const SizedBox(width: 8),
                      _PlatformChip(
                        label: 'YouTube',
                        brandColor: const Color(0xFFFF0000),
                        icon: Icons.play_circle_filled_rounded,
                        isSelected: _selectedPlatform == 'youtube',
                        onTap: () => setState(() {
                          _selectedPlatform = 'youtube';
                          _selectedVideo = null;
                        }),
                      ),
                      const SizedBox(width: 8),
                      _PlatformChip(
                        label: 'Facebook',
                        brandColor: const Color(0xFF1877F2),
                        icon: Icons.facebook_rounded,
                        isSelected: _selectedPlatform == 'facebook',
                        onTap: () {
                          setState(() {
                            _selectedPlatform = 'facebook';
                            _selectedVideo = null;
                          });
                        },
                      ),
                    ],
                  ),
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
                              ref.invalidate(_trendingVideosProvider((currentNiche, _selectedPlatform))),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                  data: (videos) {
                    if (videos.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.hourglass_top_rounded,
                                color: AppColors.textMuted, size: 48),
                            const SizedBox(height: 12),
                            Text(
                              _selectedPlatform == 'facebook'
                                  ? 'No reels yet for "$currentNiche"'
                                  : _selectedPlatform == 'threads'
                                      ? 'No Threads posts yet for "$currentNiche"'
                                      : 'Coming soon',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              (_selectedPlatform == 'facebook' || _selectedPlatform == 'threads')
                                  ? 'Tap below to scrape fresh posts for your niche.'
                                  : 'This platform is being integrated.\nCheck back soon!',
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
                            ),
                            if (_selectedPlatform == 'facebook') ...[
                              const SizedBox(height: 16),
                              ElevatedButton.icon(
                                onPressed: () => _triggerScrape('facebook'),
                                icon: const Icon(Icons.refresh_rounded, size: 18),
                                label: const Text('Scrape Now'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF1877F2),
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ],
                            if (_selectedPlatform == 'threads') ...[
                              const SizedBox(height: 16),
                              ElevatedButton.icon(
                                onPressed: () => _triggerScrape('threads'),
                                icon: const Icon(Icons.refresh_rounded, size: 18),
                                label: const Text('Scrape Now'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: Colors.black,
                                ),
                              ),
                            ],
                          ],
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
                                              _PlaceholderThumb(platform: _selectedPlatform),
                                        )
                                      : _PlaceholderThumb(platform: _selectedPlatform),

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

class _PlatformChip extends StatelessWidget {
  const _PlatformChip({
    required this.label,
    required this.brandColor,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final Color brandColor;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? brandColor.withValues(alpha: 0.18) : Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isSelected ? brandColor : Colors.white.withValues(alpha: 0.15),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: isSelected ? brandColor : AppColors.textMuted),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? brandColor : AppColors.textMuted,
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlaceholderThumb extends StatelessWidget {
  const _PlaceholderThumb({this.platform = 'tiktok'});
  final String platform;

  @override
  Widget build(BuildContext context) {
    if (platform == 'instagram') {
      return Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFF58529), Color(0xFFDD2A7B), Color(0xFF8134AF)],
          ),
        ),
        child: const Center(
          child: Icon(Icons.camera_alt_rounded, color: Colors.white38, size: 40),
        ),
      );
    }
    if (platform == 'facebook') {
      return Container(
        color: const Color(0xFF1877F2).withValues(alpha: 0.15),
        child: const Center(
          child: Icon(Icons.play_circle_outline_rounded, color: Color(0xFF1877F2), size: 40),
        ),
      );
    }
    if (platform == 'youtube') {
      return Container(
        color: const Color(0xFFFF0000).withValues(alpha: 0.10),
        child: const Center(
          child: Icon(Icons.play_circle_outline_rounded, color: Color(0xFFFF0000), size: 40),
        ),
      );
    }
    return Container(
      color: Colors.white10,
      child: const Center(
        child: Icon(Icons.play_circle_outline_rounded, color: AppColors.textMuted, size: 40),
      ),
    );
  }
}
