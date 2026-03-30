import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../shared/widgets/shared_widgets.dart';
import '../../../auth/data/models.dart';

final _facebookReelsProvider = FutureProvider<List<FacebookReelModel>>((ref) async {
  final dio = ref.read(dioProvider);
  final res = await dio.get('/trends/reels/');
  final list = res.data['results'] as List? ?? res.data as List;
  return list.map((e) => FacebookReelModel.fromJson(e as Map<String, dynamic>)).toList();
});

class FacebookEngineScreen extends ConsumerStatefulWidget {
  const FacebookEngineScreen({super.key});

  @override
  ConsumerState<FacebookEngineScreen> createState() => _FacebookEngineScreenState();
}

class _FacebookEngineScreenState extends ConsumerState<FacebookEngineScreen> {
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
      await dio.post('/trends/facebook-scrape/', data: {"niche": niche});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Facebook scraping "$niche" lancée... 🚀')),
        );
      }

      // Clear current reels to show loading UI
      ref.invalidate(_facebookReelsProvider);

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
          final newReels = await ref.refresh(_facebookReelsProvider.future);
          if (newReels.isNotEmpty) {
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
    final reelsAsync = ref.watch(_facebookReelsProvider);

    return Scaffold(
      body: Stack(
        children: [
          const AnimatedParticleBackground(),
          Column(
            children: [
              const TrendAIAppBar(
                title: 'Facebook Engine',
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
                                  Text('Actualisez pour les derniers reels Facebook viraux.',
                                      style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                                ],
                              ),
                            ),
                            GradientButton(
                              label: _isScraping ? 'Scan...' : 'Actualiser 🔄',
                              onPressed: _isScraping ? () {} : () => _triggerScrape("Facebook Trends"),
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
                            'Facebook Reels',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                          ),
                          const Spacer(),
                          if (!_isScraping)
                            IconButton(
                              onPressed: () => ref.refresh(_facebookReelsProvider),
                              icon: const Icon(Icons.refresh_rounded, size: 20),
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      reelsAsync.when(
                        data: (reels) => reels.isEmpty
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
                                            : 'Aucun reel en base de données.',
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
                                itemCount: reels.length,
                                itemBuilder: (context, index) => _FacebookReelCard(reel: reels[index]),
                              ),
                        loading: () => const Center(child: CircularProgressIndicator()),
                        error: (e, _) => const Text('Failed to load reels from database'),
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

class _FacebookReelCard extends StatelessWidget {
  const _FacebookReelCard({required this.reel});
  final FacebookReelModel reel;

  String _formatPlayCount(int count) {
    if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)}M';
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}K';
    return count.toString();
  }

  String _pageNameFromUrl(String? url) {
    if (url == null || url.isEmpty) return 'Facebook Reel';
    final parts = url.replaceAll(RegExp(r'\?.*'), '').split('/').where((s) => s.isNotEmpty).toList();
    return parts.isNotEmpty ? parts.last : 'Facebook Reel';
  }

  @override
  Widget build(BuildContext context) {
    final rawText = reel.text ?? '';
    final title = rawText.isNotEmpty ? rawText : _pageNameFromUrl(reel.pageUrl);
    final niche = (reel.niche != null && reel.niche!.isNotEmpty) ? reel.niche! : 'facebook';

    return GestureDetector(
      onTap: () => context.push(
        '/ai-generator?niche=${Uri.encodeComponent(niche)}&selectedVideoId=${reel.reelId}&platform=facebook',
      ),
      child: GlassCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFF1877F2).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.play_circle_outline_rounded, color: Color(0xFF1877F2)),
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
                              color: Color(0xFF1877F2), fontSize: 10, fontWeight: FontWeight.bold)),
                      const SizedBox(width: 8),
                      if (reel.playCount > 0)
                        Text('${_formatPlayCount(reel.playCount)} views',
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
