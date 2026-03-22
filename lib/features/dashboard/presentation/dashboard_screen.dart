/// Dashboard screen — main screen with viral score card, trending hashtags,
/// platform heatmap, and AI recommendations. Matches the Figma design.
library;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../shared/widgets/shared_widgets.dart';
import '../../auth/data/models.dart';
import '../../n8n/data/workflow_repository.dart';

final _dashboardTrendsProvider = FutureProvider<List<TrendModel>>((ref) async {
  final dio = ref.read(dioProvider);
  final res = await dio.get('/trends/', queryParameters: {'sort': 'growth'});
  final list = res.data['results'] as List? ?? res.data as List;
  return list.map((e) => TrendModel.fromJson(e as Map<String, dynamic>)).toList();
});

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    // Fire and forget: try to trigger n8n scraping so data is fresh
    ref.read(workflowRepositoryProvider).triggerScrape();
  }

  @override
  Widget build(BuildContext context) {
    final trendsAsync = ref.watch(_dashboardTrendsProvider);

    return Scaffold(
      body: Stack(
        children: [
          const AnimatedParticleBackground(),
          CustomScrollView(
            slivers: [
              const SliverToBoxAdapter(
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
                    const _ViralScoreCard(score: 87),
                    const SizedBox(height: 28),

                    // ── Trending Now
                    Row(
                      children: [
                        const Icon(Icons.local_fire_department_rounded, color: AppColors.primary),
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
                      error: (e, _) => const GlassCard(
                        child: Text('Could not load trends. Check API connection.', style: TextStyle(color: AppColors.textMuted)),
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
                    const _RecommendationCard(
                      title: 'How AI is Changing Everything',
                      hook: "You won't believe what AI can do now...",
                      bestTime: '6:00 PM',
                    ),
                    const SizedBox(height: 12),
                    const _RecommendationCard(
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
          const Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: TrendAIBottomNav(currentIndex: 0),
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
              const Row(
                children: [
                  Icon(Icons.bolt_rounded, color: AppColors.primary, size: 18),
                  SizedBox(width: 6),
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
                    const Icon(Icons.arrow_upward_rounded, color: AppColors.success, size: 14),
                    Text('${trend.growth.toInt()}%',
                        style: const TextStyle(color: AppColors.success, fontWeight: FontWeight.w600, fontSize: 12)),
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
                const Text('Score', style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
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
          Text(hook, style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Best time: $bestTime', style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
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
