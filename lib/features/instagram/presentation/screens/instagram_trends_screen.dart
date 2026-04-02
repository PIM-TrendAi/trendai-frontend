import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../shared/widgets/shared_widgets.dart';

final _trendingVideosProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final dio = ref.read(dioProvider);
  final res = await dio.get('/n8n/trending_videos/');
  final list = res.data['results'] as List? ?? res.data as List;
  return list.cast<Map<String, dynamic>>();
});

class InstagramTrendsScreen extends ConsumerStatefulWidget {
  const InstagramTrendsScreen({super.key});

  @override
  ConsumerState<InstagramTrendsScreen> createState() => _InstagramTrendsScreenState();
}

class _InstagramTrendsScreenState extends ConsumerState<InstagramTrendsScreen> {
  String _selectedNiche = "Général";
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
      _selectedNiche = niche;
      _isScraping = true;
      _pollCount = 0;
    });
    try {
      final dio = ref.read(dioProvider);
      await dio.post('/n8n/trigger-scrape/', data: {"niche": niche, "platform": "instagram"});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Scraping "$niche" started... 🚀')),
        );
      }

      await ref.refresh(_trendingVideosProvider.future).catchError((_) => <Map<String, dynamic>>[]);

      _pollTimer?.cancel();
      _pollTimer = Timer.periodic(const Duration(seconds: 4), (timer) async {
        if (!mounted) { timer.cancel(); return; }
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
          final newTrends = await ref.refresh(_trendingVideosProvider.future);
          if (newTrends.isNotEmpty) {
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
    final trendsAsync = ref.watch(_trendingVideosProvider);

    return Scaffold(
      body: Stack(
        children: [
          const AnimatedParticleBackground(),
          Column(
            children: [
              const TrendAIAppBar(
                title: 'Instagram Engine',
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
                                  Text('Trend Engine', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                                  SizedBox(height: 4),
                                  Text('Refresh to get the latest viral reels.', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                                ],
                              ),
                            ),
                            GradientButton(
                              label: _isScraping ? 'Scanning...' : 'Refresh 🔄',
                              onPressed: _isScraping ? () {} : () => _triggerScrape(_selectedNiche),
                              isLoading: _isScraping,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),

                      Row(
                        children: [
                          const Icon(Icons.local_fire_department_rounded, color: Color(0xFFE1306C), size: 18),
                          const SizedBox(width: 6),
                          const Text(
                            'Trending Instagram Reels',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                          ),
                          const Spacer(),
                          if (!_isScraping)
                            IconButton(
                              onPressed: () => ref.refresh(_trendingVideosProvider),
                              icon: const Icon(Icons.refresh_rounded, size: 20),
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      trendsAsync.when(
                        data: (trends) => trends.isEmpty
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
                                            : 'No trends in database yet.',
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
                                itemCount: trends.length,
                                itemBuilder: (context, index) => _InstagramVideoCard(video: trends[index]),
                              ),
                        loading: () => const Center(child: CircularProgressIndicator()),
                        error: (e, _) => const Text('Failed to load trends from database'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const Positioned(
            left: 0, right: 0, bottom: 0,
            child: TrendAIBottomNav(currentIndex: 1),
          ),
        ],
      ),
    );
  }
}

class _InstagramVideoCard extends StatelessWidget {
  const _InstagramVideoCard({required this.video});
  final Map<String, dynamic> video;

  @override
  Widget build(BuildContext context) {
    final title = video['title'] as String? ?? 'Untitled';
    final vid = video['video_id'] as String? ?? '';
    final category = video['category'] as String? ?? 'Instagram';

    return GestureDetector(
      onTap: () => context.push(
        '/ai-generator?niche=${Uri.encodeComponent(title)}&selectedVideoId=$vid&platform=instagram',
      ),
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
            // Gradient placeholder (Instagram brand colors)
            Container(
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

            // Info — bottom overlay
            Positioned(
              bottom: 0, left: 0, right: 0,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Trending badge (fixed — no view count in data)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.20),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.orange.withValues(alpha: 0.50)),
                      ),
                      child: const Text(
                        '🔥 Trending',
                        style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Colors.orange),
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
                    const SizedBox(height: 6),
                    // Category chip
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDD2A7B).withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        category,
                        style: const TextStyle(fontSize: 9, color: Colors.white),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
