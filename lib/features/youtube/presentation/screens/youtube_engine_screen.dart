import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../shared/widgets/shared_widgets.dart';
import '../../../auth/data/models.dart';

final _youtubeVideosProvider = FutureProvider<List<YouTubeVideoModel>>((ref) async {
  final dio = ref.read(dioProvider);
  final res = await dio.get('/trends/youtube-videos/');
  final list = res.data['results'] as List? ?? res.data as List;
  return list.map((e) => YouTubeVideoModel.fromJson(e as Map<String, dynamic>)).toList();
});

// Returns a momentum badge based on view count.
({String label, Color color}) _ytMomentumBadge(int viewCount) {
  if (viewCount >= 1000000) return (label: '🔥 Hot',    color: Colors.orange);
  if (viewCount >= 100000)  return (label: '📈 Rising', color: AppColors.success);
  return                           (label: '➡ Steady',  color: AppColors.textMuted);
}

String _ytFormatCount(int count) {
  if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)}M';
  if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}K';
  return count.toString();
}

class YouTubeEngineScreen extends ConsumerStatefulWidget {
  const YouTubeEngineScreen({super.key});

  @override
  ConsumerState<YouTubeEngineScreen> createState() => _YouTubeEngineScreenState();
}

class _YouTubeEngineScreenState extends ConsumerState<YouTubeEngineScreen> {
  bool _isScraping = false;
  Timer? _pollTimer;
  int _pollCount = 0;
  static const int _maxPollAttempts = 20;

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _triggerScrape(String niche) async {
    setState(() {
      _isScraping = true;
      _pollCount = 0;
    });
    try {
      final dio = ref.read(dioProvider);
      await dio.post('/trends/youtube-scrape/', data: {"niche": niche});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('YouTube scraping "$niche" started... 🚀')),
        );
      }

      ref.invalidate(_youtubeVideosProvider);

      _pollTimer?.cancel();
      _pollTimer = Timer.periodic(const Duration(seconds: 4), (timer) async {
        if (!mounted) {
          timer.cancel();
          return;
        }
        _pollCount++;

        if (_pollCount >= _maxPollAttempts) {
          timer.cancel();
          if (mounted) {
            setState(() => _isScraping = false);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('N8N took too long. Check the workflow and retry.')),
            );
          }
          return;
        }

        try {
          final newVideos = await ref.refresh(_youtubeVideosProvider.future);
          if (newVideos.isNotEmpty) {
            timer.cancel();
            if (mounted) setState(() => _isScraping = false);
          }
        } catch (_) {}
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to trigger scraping. Ensure n8n is online.')),
        );
        setState(() => _isScraping = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final videosAsync = ref.watch(_youtubeVideosProvider);

    return Scaffold(
      body: Stack(
        children: [
          const AnimatedParticleBackground(),
          Column(
            children: [
              const TrendAIAppBar(
                title: 'YouTube Engine',
                subtitle: 'Scrape & Generate',
                showBack: true,
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      GlassCard(
                        padding: const EdgeInsets.all(20),
                        child: Row(
                          children: [
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Trend Engine',
                                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                                  SizedBox(height: 4),
                                  Text('Refresh to get the latest viral YouTube videos.',
                                      style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                                ],
                              ),
                            ),
                            GradientButton(
                              label: _isScraping ? 'Scanning...' : 'Refresh 🔄',
                              onPressed: _isScraping ? () {} : () => _triggerScrape("YouTube Trends"),
                              isLoading: _isScraping,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),

                      Row(
                        children: [
                          const Icon(Icons.local_fire_department_rounded, color: Color(0xFFFF0000), size: 18),
                          const SizedBox(width: 6),
                          const Text(
                            'Trending YouTube Videos',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                          ),
                          const Spacer(),
                          if (!_isScraping)
                            IconButton(
                              onPressed: () => ref.refresh(_youtubeVideosProvider),
                              icon: const Icon(Icons.refresh_rounded, size: 20),
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      videosAsync.when(
                        data: (videos) => videos.isEmpty
                            ? Center(
                                child: Padding(
                                  padding: const EdgeInsets.only(top: 40),
                                  child: Column(
                                    children: [
                                      if (_isScraping) const CircularProgressIndicator(),
                                      const SizedBox(height: 16),
                                      Text(
                                        _isScraping
                                            ? 'N8N analysis in progress...'
                                            : 'No videos in database yet.',
                                        style: const TextStyle(color: AppColors.textMuted),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            : GridView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  crossAxisSpacing: 10,
                                  mainAxisSpacing: 10,
                                  childAspectRatio: 9 / 16,
                                ),
                                itemCount: videos.length,
                                itemBuilder: (context, index) => _YTVideoCard(video: videos[index]),
                              ),
                        loading: () => const Center(child: CircularProgressIndicator()),
                        error: (e, _) => const Text('Failed to load videos from database'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: TrendAIBottomNav(currentIndex: 1),
          ),
        ],
      ),
    );
  }
}

class _YTVideoCard extends StatelessWidget {
  const _YTVideoCard({required this.video});
  final YouTubeVideoModel video;

  static const _ytRed = Color(0xFFFF0000);

  List<String> _parseTags(String? tags) {
    if (tags == null || tags.isEmpty) return [];
    return tags.split(RegExp(r'[,\s]+'))
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final thumbnailUrl = 'https://img.youtube.com/vi/${video.videoId}/hqdefault.jpg';
    final videoUrl = 'https://www.youtube.com/watch?v=${video.videoId}';
    final title = video.titre ?? 'YouTube Video';
    final niche = video.niche ?? 'YouTube';
    final badge = _ytMomentumBadge(video.vues);
    final tags = _parseTags(video.tags);

    return GestureDetector(
      onTap: () => launchUrl(Uri.parse(videoUrl), mode: LaunchMode.externalApplication),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: Colors.white.withValues(alpha: 0.05),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        clipBehavior: Clip.hardEdge,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Thumbnail from YouTube CDN
            Image.network(
              thumbnailUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _placeholder(),
            ),

            // Gradient overlay — bottom
            Positioned(
              bottom: 0, left: 0, right: 0,
              child: Container(
                height: 160,
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

            // Play icon — center
            Center(
              child: Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.4),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 26),
              ),
            ),

            // Open-in-new — top right
            Positioned(
              top: 8, right: 8,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(Icons.open_in_new_rounded, size: 13, color: Colors.white),
              ),
            ),

            // Info — bottom overlay
            Positioned(
              bottom: 0, left: 0, right: 0,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: badge.color.withValues(alpha: 0.20),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: badge.color.withValues(alpha: 0.50)),
                      ),
                      child: Text(
                        badge.label,
                        style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: badge.color),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                        height: 1.3,
                      ),
                    ),
                    if (video.vues > 0) ...[
                      const SizedBox(height: 6),
                      Row(children: [
                        const Icon(Icons.play_arrow_rounded, size: 12, color: Colors.white70),
                        const SizedBox(width: 2),
                        Text(_ytFormatCount(video.vues),
                            style: const TextStyle(fontSize: 10, color: Colors.white70)),
                      ]),
                    ],
                    if (tags.isNotEmpty) ...[
                      const SizedBox(height: 5),
                      Wrap(
                        spacing: 4,
                        runSpacing: 3,
                        children: tags.take(2).map((tag) => Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                          decoration: BoxDecoration(
                            color: _ytRed.withValues(alpha: 0.25),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(tag, style: const TextStyle(fontSize: 9, color: Colors.white)),
                        )).toList(),
                      ),
                    ] else ...[
                      const SizedBox(height: 5),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: _ytRed.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(niche, style: const TextStyle(fontSize: 9, color: Colors.white)),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeholder() => Container(
    color: _ytRed.withValues(alpha: 0.10),
    child: const Center(
      child: Icon(Icons.play_circle_outline_rounded, color: _ytRed, size: 40),
    ),
  );
}
