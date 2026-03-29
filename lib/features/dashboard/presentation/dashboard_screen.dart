/// Dashboard screen — main screen with viral score card, trending hashtags,
/// platform heatmap, and AI recommendations. Matches the Figma design.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../shared/widgets/shared_widgets.dart';
import '../../auth/data/models.dart';

final _dashboardTrendsProvider = FutureProvider<List<TrendModel>>((ref) async {
  final dio = ref.read(dioProvider);
  final res = await dio.get('/trends/', queryParameters: {'sort': 'growth'});
  final list = res.data['results'] as List? ?? res.data as List;
  return list.map((e) => TrendModel.fromJson(e as Map<String, dynamic>)).toList();
});

final _dashboardReelsProvider = FutureProvider<List<FacebookReelModel>>((ref) async {
  final dio = ref.read(dioProvider);
  final res = await dio.get('/trends/reels/');
  final data = res.data;
  // Handle both paginated {count, results:[...]} and plain list responses
  final List<dynamic> rawList = (data is Map) ? (data['results'] as List? ?? []) : (data as List? ?? []);
  final List<FacebookReelModel> result = [];
  for (final e in rawList) {
    try {
      result.add(FacebookReelModel.fromJson(e as Map<String, dynamic>));
    } catch (_) {
      // Skip malformed records without crashing the whole list
    }
  }
  return result;
});

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trendsAsync = ref.watch(_dashboardTrendsProvider);

    return Scaffold(
      body: Stack(
        children: [
          const AnimatedParticleBackground(),
          CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: TrendAIAppBar(
                  title: 'Dashboard',
                  subtitle: 'Powered by AI • Real-time insights',
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    // ── Viral Score Card
                    _ViralScoreCard(score: 87),
                    const SizedBox(height: 28),

                    // ── Trending Now
                    Row(
                      children: [
                        Icon(Icons.local_fire_department_rounded, color: AppColors.primary),
                        const SizedBox(width: 8),
                        Text('Trending Now 🔥',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                      ],
                    ),
                    const SizedBox(height: 14),
                    trendsAsync.when(
                      data: (trends) => SizedBox(
                        height: 170,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          padding: EdgeInsets.zero,
                          itemCount: trends.take(5).length,
                          separatorBuilder: (_, __) => const SizedBox(width: 14),
                          itemBuilder: (ctx, i) => _TrendingCard(trend: trends[i]),
                        ),
                      ),
                      loading: () => const Center(child: CircularProgressIndicator()),
                      error: (e, _) => GlassCard(
                        child: Text('Could not load trends. Check API connection.', style: TextStyle(color: AppColors.textMuted)),
                      ),
                    ),
                    const SizedBox(height: 28),

                    // ── Scraped Reels
                    Row(
                      children: [
                        Icon(Icons.video_library_rounded, color: AppColors.primary),
                        const SizedBox(width: 8),
                        Text('Top Scraped Reels 🤖',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                      ],
                    ),
                    const SizedBox(height: 14),
                    ref.watch(_dashboardReelsProvider).when(
                      data: (reels) {
                        final uiList = reels.where((r) => r.thumbnailUrl != null && r.thumbnailUrl!.isNotEmpty).toList();
                        
                        if (uiList.isEmpty) {
                          return GlassCard(
                            child: const Padding(
                              padding: EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                              child: Center(
                                child: Text('No scraped reels with images match your niches yet. Try exploring other niches or triggering a new scrape!',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: Colors.white70, fontSize: 13),
                                ),
                              ),
                            ),
                          );
                        }

                        return SizedBox(
                          height: 180,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            padding: EdgeInsets.zero,
                            itemCount: uiList.length,
                            separatorBuilder: (_, __) => const SizedBox(width: 14),
                            itemBuilder: (ctx, i) => _ScrapedReelCard(reel: uiList[i]),
                          ),
                        );
                      },
                      loading: () => const Center(child: CircularProgressIndicator()),
                      error: (e, _) => GlassCard(
                        child: Text('Could not load scraped reels.', style: TextStyle(color: AppColors.textMuted)),
                      ),
                    ),
                    const SizedBox(height: 28),

                    // ── Multi-Platform Heatmap
                    Text('Multi-Platform Heatmap',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 14),
                    _PlatformHeatmap(),
                    const SizedBox(height: 28),

                    // ── Recommendations
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Recommended For You',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            gradient: AppColors.gradientPrimary,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text('Personalized', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _RecommendationCard(
                      title: 'How AI is Changing Everything',
                      hook: "You won't believe what AI can do now...",
                      bestTime: '6:00 PM',
                    ),
                    const SizedBox(height: 12),
                    _RecommendationCard(
                      title: '5 Productivity Secrets',
                      hook: 'Stop wasting time and start doing this...',
                      bestTime: '12:00 PM',
                    ),
                    const SizedBox(height: 100),
                  ]),
                ),
              ),
            ],
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: const TrendAIBottomNav(currentIndex: 0),
          ),
        ],
      ),
    );
  }
}

// ── Viral Score Card
class _ViralScoreCard extends StatelessWidget {
  const _ViralScoreCard({required this.score});
  final int score;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.bolt_rounded, color: AppColors.primary, size: 18),
                  const SizedBox(width: 6),
                  Text('Viral Score Today', style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
                ],
              ),
              const SizedBox(height: 8),
              GradientText(
                '$score%',
                style: Theme.of(context).textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w800),
              ),
            ],
          ),
          SizedBox(
            width: 80,
            height: 80,
            child: CustomPaint(painter: _CircularProgressPainter(score / 100)),
          ),
        ],
      ),
    );
  }
}

class _CircularProgressPainter extends CustomPainter {
  _CircularProgressPainter(this.progress);
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 6;
    final trackPaint = Paint()
      ..color = AppColors.primary.withValues(alpha: 0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7;
    final progressPaint = Paint()
      ..shader = AppColors.gradientPrimary.createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, trackPaint);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -3.14 / 2,
      2 * 3.14 * progress,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(_) => true;
}

// ── Trending Card (horizontal scroll)
class _TrendingCard extends StatelessWidget {
  const _TrendingCard({required this.trend});
  final TrendModel trend;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.go('/trend/${trend.id}'),
      child: Container(
        width: 200,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TrendTypeIcon(type: trend.type),
                Row(
                  children: [
                    Icon(Icons.arrow_upward_rounded, color: AppColors.success, size: 14),
                    Text('${trend.growth.toInt()}%',
                        style: TextStyle(color: AppColors.success, fontWeight: FontWeight.w600, fontSize: 12)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(trend.hashtag,
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                maxLines: 2,
                overflow: TextOverflow.ellipsis),
            const Spacer(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Score', style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
                GradientText('${trend.score.toInt()}%',
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Platform Heatmap
class _PlatformHeatmap extends StatelessWidget {
  final _platforms = const [
    ('TikTok', 92, AppColors.tikTok),
    ('Instagram', 85, AppColors.instagram),
    ('YouTube', 78, AppColors.youtube),
    ('Facebook', 65, AppColors.facebook),
    ('X', 71, AppColors.x),
  ];

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Column(
        children: _platforms.map((p) {
          final (name, score, color) = p;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                SizedBox(width: 80, child: Text(name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: score / 100,
                      backgroundColor: Colors.white.withValues(alpha: 0.06),
                      valueColor: AlwaysStoppedAnimation(color),
                      minHeight: 10,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text('$score%', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ── Recommendation Card
class _RecommendationCard extends StatelessWidget {
  const _RecommendationCard({required this.title, required this.hook, required this.bestTime});
  final String title;
  final String hook;
  final String bestTime;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(hook, style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Best time: $bestTime', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
              GestureDetector(
                onTap: () => context.go('/ai-generator'),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    gradient: AppColors.gradientPrimary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text('Generate Script',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Scraped Reel Card
class _ScrapedReelCard extends StatelessWidget {
  const _ScrapedReelCard({required this.reel});
  final FacebookReelModel reel;

  @override
  Widget build(BuildContext context) {
    final hasImage = reel.thumbnailUrl != null && reel.thumbnailUrl!.isNotEmpty;
    
    return GestureDetector(
      onTap: () => context.go('/ai-generator'), // Allows user to jump to the generator
      child: Container(
        width: 220,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            children: [
              // Background Image or Gradient Fallback
              if (hasImage)
                Positioned.fill(
                  child: Image.network(
                    reel.thumbnailUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _buildDashboardGradientFallback(reel.id),
                  ),
                )
              else
                Positioned.fill(
                  child: _buildDashboardGradientFallback(reel.id),
                ),

              // Gradient Overlay
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.black.withValues(alpha: 0.8),
                        Colors.black.withValues(alpha: 0.3),
                        Colors.black.withValues(alpha: 0.8),
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
              ),

              // Content
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.facebook.withValues(alpha: 0.25),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.facebook.withValues(alpha: 0.5)),
                          ),
                          child: Text(reel.niche ?? 'General', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
                        ),
                        Row(
                          children: [
                            const Icon(Icons.play_arrow_rounded, color: Colors.white70, size: 14),
                            Text('${reel.playCount}',
                                style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w600, fontSize: 12)),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(reel.text ?? 'No description available for this reel.',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13, height: 1.4),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis),
                    const Spacer(),
                    SizedBox(
                      width: double.infinity,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            )
                          ],
                        ),
                        child: const Text('Generate AI Video', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDashboardGradientFallback(int id) {
    final colors = [
      [const Color(0xFF6C5CE7), const Color(0xFF00C6FF)],
      [const Color(0xFFFF7675), const Color(0xFFD63031)],
      [const Color(0xFF00B894), const Color(0xFF00CEC9)],
      [const Color(0xFFE84393), const Color(0xFFFD79A8)],
    ];
    final colorPair = colors[id % colors.length];
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: colorPair,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
    );
  }
}
