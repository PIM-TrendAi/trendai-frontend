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
          SnackBar(content: Text('Analyse de la niche "$niche" lancée... 🚀')),
        );
      }
      
      // Clear current trends to show loading UI
      await ref.refresh(_trendingVideosProvider.future);

      // Start polling DB every 4 seconds to wait for N8N to finish scraping
      _pollTimer?.cancel();
      _pollTimer = Timer.periodic(const Duration(seconds: 4), (timer) async {
        if (!mounted) { timer.cancel(); return; }
        _pollCount++;
        
        // Timeout after _maxPollAttempts
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
              TrendAIAppBar(
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
                      // Refresh Action
                      GlassCard(
                        padding: const EdgeInsets.all(20),
                        child: Row(
                          children: [
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Moteur de Tendances', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                                  SizedBox(height: 4),
                                  Text('Actualisez pour les dernières vidéos virales.', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                                ],
                              ),
                            ),
                            GradientButton(
                              label: _isScraping ? 'Scan...' : 'Actualiser 🔄',
                              onPressed: _isScraping ? () {} : () => _triggerScrape("Instagram Trends"),
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
                            'Tendances Actuelles',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                          ),
                          const Spacer(),
                          if (!_isScraping) 
                             IconButton(
                               onPressed: () => ref.refresh(_trendingVideosProvider), 
                               icon: const Icon(Icons.refresh_rounded, size: 20)
                             ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      trendsAsync.when(
                        data: (trends) => trends.isEmpty 
                          ? Center(child: Padding(
                              padding: const EdgeInsets.only(top: 40),
                              child: Column(
                                children: [
                                  if (_isScraping) const CircularProgressIndicator(),
                                  const SizedBox(height: 16),
                                  Text(
                                    _isScraping 
                                        ? 'Analyse N8N en cours...' 
                                        : 'Aucune tendance en base de données.', 
                                    style: TextStyle(color: AppColors.textMuted)
                                  ),
                                ],
                              ),
                            ))
                          : GridView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 1, // Full width for better read
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 12,
                                childAspectRatio: 3.5,
                              ),
                              itemCount: trends.length,
                              itemBuilder: (context, index) => _NicheCard(video: trends[index]),
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
          Positioned(
            left: 0, right: 0, bottom: 0,
            child: const TrendAIBottomNav(currentIndex: 1),
          ),
        ],
      ),
    );
  }
}

class _NicheCard extends StatelessWidget {
  const _NicheCard({required this.video});
  final Map<String, dynamic> video;

  @override
  Widget build(BuildContext context) {
    final title = video['title'] ?? 'Untitled Trend';
    final vid = video['video_id'] ?? '';
    final category = video['category'] ?? 'Instagram';

    return GestureDetector(
      onTap: () => context.push('/ai-generator?niche=${Uri.encodeComponent(title)}&selectedVideoId=$vid'),
      child: GlassCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.trending_up_rounded, color: AppColors.primary),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(category, style: const TextStyle(color: AppColors.primary, fontSize: 10, fontWeight: FontWeight.bold)),
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
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});
  final String title;
  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: -0.5),
    );
  }
}
