import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
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
          SnackBar(content: Text('YouTube scraping "$niche" lancée... 🚀')),
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
              const SnackBar(content: Text('N8N took too long. Vérifiez le workflow et réessayez.')),
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
                      // Refresh Action
                      GlassCard(
                        padding: const EdgeInsets.all(20),
                        child: Row(
                          children: [
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Moteur de Tendances',
                                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                                  SizedBox(height: 4),
                                  Text('Actualisez pour les dernières vidéos YouTube virales.',
                                      style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                                ],
                              ),
                            ),
                            GradientButton(
                              label: _isScraping ? 'Scan...' : 'Actualiser 🔄',
                              onPressed: _isScraping ? () {} : () => _triggerScrape("YouTube Trends"),
                              isLoading: _isScraping,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Results Header
                      Row(
                        children: [
                          const Icon(Icons.flash_on_rounded, color: Colors.amber, size: 20),
                          const SizedBox(width: 8),
                          const Text(
                            'YouTube Trending',
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
                                            ? 'Analyse N8N en cours...'
                                            : 'Aucune vidéo en base de données.',
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
                                  crossAxisCount: 1,
                                  crossAxisSpacing: 12,
                                  mainAxisSpacing: 12,
                                  childAspectRatio: 3.5,
                                ),
                                itemCount: videos.length,
                                itemBuilder: (context, index) => _YouTubeVideoCard(video: videos[index]),
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

class _YouTubeVideoCard extends StatelessWidget {
  const _YouTubeVideoCard({required this.video});
  final YouTubeVideoModel video;

  String _formatViews(int count) {
    if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)}M';
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}K';
    return count.toString();
  }

  @override
  Widget build(BuildContext context) {
    final title = video.titre ?? 'YouTube Video';
    final niche = video.niche ?? 'YouTube';

    return GestureDetector(
      onTap: () => context.push(
        '/ai-generator?niche=${Uri.encodeComponent(niche)}&selectedVideoId=${video.videoId}&platform=youtube',
      ),
      child: GlassCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFFFF0000).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.play_arrow_rounded, color: Color(0xFFFF0000)),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    children: [
                      Text(niche,
                          style: const TextStyle(
                              color: Color(0xFFFF0000), fontSize: 10, fontWeight: FontWeight.bold)),
                      const SizedBox(width: 8),
                      if (video.vues > 0)
                        Text('${_formatViews(video.vues)} views',
                            style: const TextStyle(color: AppColors.textMuted, fontSize: 10)),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Colors.white24),
          ],
        ),
      ),
    );
  }
}
