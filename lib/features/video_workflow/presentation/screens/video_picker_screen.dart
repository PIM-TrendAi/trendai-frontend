import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/network/dio_client.dart';
import '../../../../core/network/n8n_service.dart';
import '../../../../core/storage/secure_storage.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/shared_widgets.dart';
import '../../../auth/data/models.dart';
import '../../data/models/workflow_models.dart';
import '../providers/workflow_provider.dart';


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

int _parseCount(String s) {
  final v = s.trim().toUpperCase().replaceAll(',', '');
  if (v.endsWith('B')) return ((double.tryParse(v.replaceAll('B', '')) ?? 0) * 1e9).toInt();
  if (v.endsWith('M')) return ((double.tryParse(v.replaceAll('M', '')) ?? 0) * 1e6).toInt();
  if (v.endsWith('K')) return ((double.tryParse(v.replaceAll('K', '')) ?? 0) * 1e3).toInt();
  return int.tryParse(v) ?? 0;
}

// (niche, platform)
final _trendingVideosProvider =
    FutureProvider.family<List<TrendingVideoModel>, (String?, String)>((ref, params) async {
  final (niche, platform) = params;
  final dio = ref.read(dioProvider);

  if (platform == 'tiktok') {
    return ref.read(n8nServiceProvider).fetchTrendingVideos(niche: null);
  }

  if (platform == 'instagram') {
    final queryParams = <String, dynamic>{};
    if (niche != null && niche.isNotEmpty) queryParams['niche'] = niche;
    final res = await dio.get('/n8n/instagram-reels/', queryParameters: queryParams);
    final list = res.data['results'] as List? ?? res.data as List;
    return list.cast<Map<String, dynamic>>().map((json) {
      final Map<String, dynamic> data = Map<String, dynamic>.from(json);
      data['video_id'] = data['reel_id'] ?? data['video_id'] ?? '';
      data['title'] = data['caption'] ?? data['title'] ?? 'Trending Reel';
      data['views'] = ((data['views'] ?? 0) is String ? data['views'] : data['views'].toString());
      data['likes'] = ((data['likes'] ?? 0) is String ? data['likes'] : data['likes'].toString());
      data['author'] = data['author'] ?? '@unknown';
      data['thumbnail_url'] = data['thumbnail_url'] ?? '';
      data['category'] = data['niche'] ?? 'instagram';
      data['niche'] = data['niche'] ?? 'instagram';
      data['tiktok_url'] = data['reel_url'] ?? data['tiktok_url'] ?? '';
      data['hashtags'] = data['hashtags'] is String ? (data['hashtags'] as String).split(',') : (data['hashtags'] as List?)?.cast<String>() ?? [];
      return TrendingVideoModel.fromJson(data);
    }).toList();
  }

  if (platform == 'facebook') {
    final queryParams = <String, dynamic>{};
    if (niche != null && niche.isNotEmpty) queryParams['niche'] = niche;
    final res = await dio.get('/trends/reels/', queryParameters: queryParams);
    final list = res.data['results'] as List? ?? res.data as List;
    return list.map((json) {
      final Map<String, dynamic> data = Map<String, dynamic>.from(json);
      final reel = FacebookReelModel.fromJson(data);
      return TrendingVideoModel(
        videoId: reel.reelId,
        title: reel.text ?? 'Facebook Reel',
        author: '',
        thumbnailUrl: reel.thumbnailUrl ?? '',
        views: reel.playCount.toString(),
        likes: '',
        niche: reel.niche ?? 'facebook',
        hashtags: reel.niche != null ? [reel.niche!] : [],
        tiktokUrl: reel.reelUrl ?? '',
      );
    }).toList();
  }

  if (platform == 'youtube') {
    final res = await dio.get('/trends/youtube-videos/');
    final list = res.data['results'] as List? ?? res.data as List;
    return list.map((json) {
      final video = YouTubeVideoModel.fromJson(json);
      return TrendingVideoModel(
        videoId: video.videoId,
        title: video.titre ?? 'YouTube Video',
        author: '',
        thumbnailUrl: 'https://img.youtube.com/vi/${video.videoId}/hqdefault.jpg',
        views: video.vues.toString(),
        likes: '',
        niche: video.niche ?? 'youtube',
        hashtags: const [],
        tiktokUrl: 'https://www.youtube.com/watch?v=${video.videoId}',
      );
    }).toList();
  }

  if (platform == 'threads') {
    final queryParams = <String, dynamic>{};
    if (niche != null && niche.isNotEmpty) queryParams['niche'] = niche;
    final res = await dio.get('/trends/threads-posts/', queryParameters: queryParams);
    final list = res.data['results'] as List? ?? res.data as List;
    return list.map((json) {
      final Map<String, dynamic> data = Map<String, dynamic>.from(json);
      final post = ThreadsPostModel.fromJson(data);
      return TrendingVideoModel(
        videoId: post.postId,
        title: post.text ?? 'Threads Post',
        author: post.username ?? '@unknown',
        thumbnailUrl: post.thumbnailUrl ?? '',
        views: post.likeCount.toString(),
        likes: post.likeCount.toString(),
        niche: post.niche ?? 'threads',
        hashtags: post.niche != null ? [post.niche!] : [],
        tiktokUrl: post.postUrl ?? '',
      );
    }).toList();
  }

  // Fallback
  return [];
});

class VideoPickerScreen extends ConsumerStatefulWidget {
  const VideoPickerScreen({super.key, this.preselectedVideoId});
  final String? preselectedVideoId;

  @override
  ConsumerState<VideoPickerScreen> createState() => _VideoPickerScreenState();
}

const _kAiAgents = [
  _AiAgent(id: 'gpt4o',    name: 'GPT-4o',          subtitle: 'OpenAI · Best for creativity',    color: Color(0xFF10A37F), icon: Icons.auto_awesome_rounded),
  _AiAgent(id: 'claude',   name: 'Claude 3.5',       subtitle: 'Anthropic · Great for nuance',    color: Color(0xFFD97757), icon: Icons.psychology_rounded),
  _AiAgent(id: 'gemini',   name: 'Gemini Pro',       subtitle: 'Google · Fast & multimodal',      color: Color(0xFF4285F4), icon: Icons.blur_on_rounded),
  _AiAgent(id: 'llama',    name: 'Llama 3',          subtitle: 'Meta · Open-source powerhouse',   color: Color(0xFF0668E1), icon: Icons.memory_rounded),
  _AiAgent(id: 'mistral',  name: 'Mistral Large',    subtitle: 'Mistral AI · Efficient & sharp',  color: Color(0xFFFF7000), icon: Icons.wind_power_rounded),
];

class _AiAgent {
  const _AiAgent({
    required this.id,
    required this.name,
    required this.subtitle,
    required this.color,
    required this.icon,
  });
  final String id;
  final String name;
  final String subtitle;
  final Color color;
  final IconData icon;
}

class _VideoPickerScreenState extends ConsumerState<VideoPickerScreen> with SingleTickerProviderStateMixin {
  late AnimationController _rotateController;
  final _promptCtrl = TextEditingController();
  TrendingVideoModel? _selectedVideo;
  List<String> _niches = [];
  String _sort = 'views';
  String _selectedPlatform = 'tiktok';
  bool _isScraping = false;
  _AiAgent _selectedAgent = _kAiAgents.first;

  @override
  void initState() {
    super.initState();
    _rotateController = AnimationController(vsync: this, duration: const Duration(seconds: 1));
    _loadNiches();
  }

  Future<void> _loadNiches() async {
    final niches = await ref.read(secureStorageProvider).readCreatorNiches();
    if (mounted) setState(() => _niches = niches);
  }

  void _showAgentPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _AgentPickerSheet(
        agents: _kAiAgents,
        selected: _selectedAgent,
        onPick: (agent) {
          setState(() => _selectedAgent = agent);
          Navigator.pop(context);
        },
      ),
    );
  }

  Future<void> _triggerScrape() async {
    if (_isScraping) return;

    setState(() => _isScraping = true);
    _rotateController.repeat();

    try {
      final dio = ref.read(dioProvider);
      final nicheKey = _niches.join(',');
      final nicheStr = _niches.isNotEmpty ? nicheKey : 'trending';

      final response = await dio.post(
        '/n8n/trigger-scrape/',
        data: {
          "niche": nicheStr,
          "platform": _selectedPlatform,
        },
      );

      final bool success = response.data['success'] == true;
      final String msg = success
          ? 'Scraping for "$nicheStr" started on $_selectedPlatform...'
          : (response.data['message'] ?? 'Failed to reach N8N. Make sure the workflow is active.');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
            backgroundColor: success ? const Color(0xFFE1306C) : AppColors.error,
          ),
        );
      }

      if (!success) {
        setState(() => _isScraping = false);
        _rotateController.stop();
        return;
      }

      // Capture the newest ID BEFORE the scan completes
      final initialVideos = ref.read(_trendingVideosProvider((nicheKey, _selectedPlatform))).asData?.value ?? [];
      final String? lastId = initialVideos.isNotEmpty ? initialVideos.first.videoId : null;

      // Poll for new results (max 60 s)
      int attempts = 0;
      const maxAttempts = 20;

      Timer.periodic(const Duration(seconds: 3), (timer) async {
        attempts++;
        if (!mounted || attempts > maxAttempts) {
          timer.cancel();
          if (mounted) {
            setState(() => _isScraping = false);
            _rotateController.stop();
          }
          return;
        }
        try {
          final videos = await ref.refresh(_trendingVideosProvider((nicheKey, _selectedPlatform)).future);
          if (videos.isNotEmpty && videos.first.videoId != lastId) {
            timer.cancel();
            if (mounted) {
              setState(() => _isScraping = false);
              _rotateController.stop();
            }
          }
        } catch (_) {}
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Scraping failed: ${e.toString().replaceAll('Exception: ', '').substring(0, 80)}'),
            backgroundColor: AppColors.error,
          ),
        );
        setState(() => _isScraping = false);
        _rotateController.stop();
      }
    }
  }

  @override
  void dispose() {
    _promptCtrl.dispose();
    _rotateController.dispose();
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
          niche: _niches.isNotEmpty ? _niches.first : video.niche,
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
    final nicheKey = _niches.join(',');
    final videosAsync = ref.watch(_trendingVideosProvider((nicheKey, _selectedPlatform)));
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
                    Row(
                      children: [
                        const Text('Your prompt',
                            style: TextStyle(
                                color: AppColors.textMuted,
                                fontSize: 13,
                                fontWeight: FontWeight.w600)),
                        const Spacer(),
                        GestureDetector(
                          onTap: _showAgentPicker,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [_selectedAgent.color.withValues(alpha: 0.25), _selectedAgent.color.withValues(alpha: 0.10)],
                              ),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: _selectedAgent.color.withValues(alpha: 0.5), width: 1),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(_selectedAgent.icon, size: 14, color: _selectedAgent.color),
                                const SizedBox(width: 5),
                                Text(
                                  _selectedAgent.name,
                                  style: TextStyle(color: _selectedAgent.color, fontSize: 12, fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(width: 4),
                                Icon(Icons.keyboard_arrow_down_rounded, size: 14, color: _selectedAgent.color),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
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
                      const SizedBox(width: 8),
                      _PlatformChip(
                        label: 'Threads',
                        brandColor: Colors.white,
                        icon: Icons.alternate_email_rounded,
                        isSelected: _selectedPlatform == 'threads',
                        onTap: () => setState(() {
                          _selectedPlatform = 'threads';
                          _selectedVideo = null;
                        }),
                      ),
                    ],
                  ),
                ),
              ),

              // Scrape button — shown for instagram, facebook, and threads
              if (_selectedPlatform == 'instagram' || _selectedPlatform == 'facebook' || _selectedPlatform == 'threads')
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Trending Reels',
                          style: TextStyle(
                            color: Color(0xFFE1306C),
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: _isScraping ? null : _triggerScrape,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            gradient: _selectedPlatform == 'instagram' 
                                ? const LinearGradient(colors: [Color(0xFFE1306C), Color(0xFFF58529)])
                                : _selectedPlatform == 'facebook'
                                    ? const LinearGradient(colors: [Color(0xFF1877F2), Color(0xFF3B5998)])
                                    : const LinearGradient(colors: [Colors.white24, Colors.white10]),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: (_selectedPlatform == 'instagram' ? const Color(0xFFE1306C) : _selectedPlatform == 'facebook' ? const Color(0xFF1877F2) : Colors.white).withValues(alpha: 0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Center(
                            child: RotationTransition(
                              turns: _rotateController,
                              child: const Icon(
                                Icons.refresh_rounded,
                                color: Colors.white,
                                size: 22,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              // Sort chips — Views / Likes / Date
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Row(
                  children: [
                    const Icon(Icons.sort_rounded, color: AppColors.textMuted, size: 16),
                    const SizedBox(width: 8),
                    const Text('Sort:', style: TextStyle(color: AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.w600)),
                    const SizedBox(width: 10),
                    _SortChip(label: 'Views',  icon: Icons.play_arrow_rounded,   value: 'views',  selected: _sort, onTap: () => setState(() => _sort = 'views')),
                    const SizedBox(width: 8),
                    _SortChip(label: 'Likes',  icon: Icons.favorite_rounded,     value: 'likes',  selected: _sort, onTap: () => setState(() => _sort = 'likes')),
                    const SizedBox(width: 8),
                    _SortChip(label: 'Date',   icon: Icons.access_time_rounded,  value: 'date',   selected: _sort, onTap: () => setState(() => _sort = 'date')),
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
                              ref.invalidate(_trendingVideosProvider((nicheKey, _selectedPlatform))),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                  data: (videos) {
                    // Show all trends without niche filtering — let the user pick freely.
                    List<TrendingVideoModel> filtered = List<TrendingVideoModel>.from(videos);
                    // Apply sort
                    if (_sort == 'views') {
                      filtered.sort((a, b) => _parseCount(b.views).compareTo(_parseCount(a.views)));
                    } else if (_sort == 'likes') {
                      filtered.sort((a, b) => _parseCount(b.likes).compareTo(_parseCount(a.likes)));
                    }
                    // 'date' keeps API order (newest first)

                    if (filtered.isEmpty) {
                      final bool canScrape = _selectedPlatform == 'facebook' ||
                          _selectedPlatform == 'threads' ||
                          _selectedPlatform == 'instagram';
                      return Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.hourglass_top_rounded,
                                color: AppColors.textMuted, size: 48),
                            const SizedBox(height: 12),
                            Text(
                              _selectedPlatform == 'instagram'
                                  ? 'No reels scraped yet'
                                  : _selectedPlatform == 'facebook'
                                      ? 'No reels yet'
                                      : _selectedPlatform == 'threads'
                                          ? 'No Threads posts yet'
                                          : _selectedPlatform == 'youtube'
                                              ? 'No YouTube videos found'
                                              : 'No trending videos found',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              canScrape
                                  ? 'Tap the refresh button above to scrape fresh reels.'
                                  : _selectedPlatform == 'tiktok'
                                      ? 'Make sure the TikTok N8N workflow is running.'
                                      : _selectedPlatform == 'youtube'
                                          ? 'Make sure the backend is running and YouTube data has been scraped.'
                                          : 'This platform is being integrated.\nCheck back soon!',
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
                            ),
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
                      itemCount: filtered.length,
                      itemBuilder: (ctx, i) {
                        final v = filtered[i];
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
                                          headers: _selectedPlatform == 'tiktok'
                                              ? const {'Referer': 'https://www.tiktok.com/'}
                                              : null,
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
    if (platform == 'threads') {
      return Container(
        color: Colors.white.withValues(alpha: 0.10),
        child: const Center(
          child: Icon(Icons.alternate_email_rounded, color: Colors.white, size: 40),
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

class _AgentPickerSheet extends StatelessWidget {
  const _AgentPickerSheet({
    required this.agents,
    required this.selected,
    required this.onPick,
  });

  final List<_AiAgent> agents;
  final _AiAgent selected;
  final ValueChanged<_AiAgent> onPick;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF14141F),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 36),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: AppColors.gradientPrimary,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.smart_toy_rounded, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 12),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('AI Agent', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
                  Text('Pick the model to write your script', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          ...agents.map((agent) {
            final isSelected = agent.id == selected.id;
            return GestureDetector(
              onTap: () => onPick(agent),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: isSelected ? agent.color.withValues(alpha: 0.12) : Colors.white.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isSelected ? agent.color.withValues(alpha: 0.6) : Colors.white.withValues(alpha: 0.08),
                    width: isSelected ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: agent.color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(agent.icon, color: agent.color, size: 20),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(agent.name, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
                          const SizedBox(height: 2),
                          Text(agent.subtitle, style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                        ],
                      ),
                    ),
                    if (isSelected)
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(color: agent.color, shape: BoxShape.circle),
                        child: const Icon(Icons.check_rounded, color: Colors.white, size: 12),
                      ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _SortChip extends StatelessWidget {
  const _SortChip({
    required this.label,
    required this.icon,
    required this.value,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final String value;
  final String selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isSelected = value == selected;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          gradient: isSelected ? AppColors.gradientPrimary : null,
          color: isSelected ? null : Colors.white.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? Colors.transparent : Colors.white.withValues(alpha: 0.12),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: isSelected ? Colors.white : AppColors.textMuted),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : AppColors.textMuted,
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
