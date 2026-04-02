import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
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

// Returns a momentum badge based on view count.
({String label, Color color}) _fbMomentumBadge(int viewCount) {
  if (viewCount >= 1000000) return (label: '🔥 Hot',    color: Colors.orange);
  if (viewCount >= 100000)  return (label: '📈 Rising', color: AppColors.success);
  return                           (label: '➡ Steady',  color: AppColors.textMuted);
}

String _fbFormatCount(int count) {
  if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)}M';
  if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}K';
  return count.toString();
}

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
          SnackBar(content: Text('Facebook scraping "$niche" started... 🚀')),
        );
      }

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
              const SnackBar(content: Text('N8N took too long. Check the workflow and retry.')),
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
                                  Text('Refresh to get the latest viral Facebook reels.',
                                      style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                                ],
                              ),
                            ),
                            GradientButton(
                              label: _isScraping ? 'Scanning...' : 'Refresh 🔄',
                              onPressed: _isScraping ? () {} : () => _triggerScrape("Facebook Trends"),
                              isLoading: _isScraping,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),

                      Row(
                        children: [
                          const Icon(Icons.local_fire_department_rounded, color: Color(0xFF1877F2), size: 18),
                          const SizedBox(width: 6),
                          const Text(
                            'Trending Facebook Reels',
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
                                            ? 'N8N analysis in progress...'
                                            : 'No reels in database yet.',
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
                                itemCount: reels.length,
                                itemBuilder: (context, index) => _FacebookVideoCard(reel: reels[index]),
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

class _FacebookVideoCard extends StatelessWidget {
  const _FacebookVideoCard({required this.reel});
  final FacebookReelModel reel;

  static const _fbBlue = Color(0xFF1877F2);

  String _pageNameFromUrl(String? url) {
    if (url == null || url.isEmpty) return 'Facebook';
    final parts = url.replaceAll(RegExp(r'\?.*'), '').split('/').where((s) => s.isNotEmpty).toList();
    return parts.isNotEmpty ? parts.last : 'Facebook';
  }

  @override
  Widget build(BuildContext context) {
    final hasThumb = reel.thumbnailUrl != null && reel.thumbnailUrl!.isNotEmpty;
    final hasUrl = reel.reelUrl != null && reel.reelUrl!.isNotEmpty;
    final pageName = _pageNameFromUrl(reel.pageUrl);
    final rawText = reel.text ?? '';
    final title = rawText.isNotEmpty ? rawText : pageName;
    final niche = (reel.niche != null && reel.niche!.isNotEmpty) ? reel.niche! : 'facebook';
    final badge = _fbMomentumBadge(reel.playCount);

    return GestureDetector(
      onTap: hasUrl
          ? () => launchUrl(Uri.parse(reel.reelUrl!), mode: LaunchMode.externalApplication)
          : () => context.push(
                '/ai-generator?niche=${Uri.encodeComponent(niche)}&selectedVideoId=${reel.reelId}&platform=facebook',
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
            // Thumbnail or placeholder
            hasThumb
                ? Image.network(
                    reel.thumbnailUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _placeholder(),
                  )
                : _placeholder(),

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
            if (hasUrl)
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
                    if (pageName.isNotEmpty)
                      Text(
                        '@$pageName',
                        style: const TextStyle(
                          fontSize: 10,
                          color: _fbBlue,
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    const SizedBox(height: 4),
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
                    if (reel.playCount > 0) ...[
                      const SizedBox(height: 6),
                      Row(children: [
                        const Icon(Icons.play_arrow_rounded, size: 12, color: Colors.white70),
                        const SizedBox(width: 2),
                        Text(_fbFormatCount(reel.playCount),
                            style: const TextStyle(fontSize: 10, color: Colors.white70)),
                      ]),
                    ],
                    const SizedBox(height: 5),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: _fbBlue.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        niche,
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

  Widget _placeholder() => Container(
    color: _fbBlue.withValues(alpha: 0.10),
    child: const Center(
      child: Icon(Icons.play_circle_outline_rounded, color: _fbBlue, size: 40),
    ),
  );
}
