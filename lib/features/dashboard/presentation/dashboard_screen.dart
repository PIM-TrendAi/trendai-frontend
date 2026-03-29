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
  return list
      .map((e) => TrendModel.fromJson(e as Map<String, dynamic>))
      .toList();
});

final _youtubeHistoryProvider =
    FutureProvider<List<YouTubeGeneratedModel>>((ref) async {
  final dio = ref.read(dioProvider);
  final res = await dio.get('/scripts/youtube/history/');
  final list = res.data['results'] as List? ?? res.data as List;
  return list
      .map((e) => YouTubeGeneratedModel.fromJson(e as Map<String, dynamic>))
      .toList();
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
                    const SizedBox(height: 14),

                    // ── Quick Menu
                    Row(
                      children: [
                        Expanded(
                          child: _QuickActionButton(
                            icon: Icons.video_library_rounded,
                            label: 'My Videos',
                            onTap: () => context.push('/my-videos'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _QuickActionButton(
                            icon: Icons.category_rounded,
                            label: 'My Niche',
                            onTap: () => context.go('/category-selection'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),

                    // ── Trending Now
                    Row(
                      children: [
                        Icon(Icons.local_fire_department_rounded,
                            color: AppColors.primary),
                        const SizedBox(width: 8),
                        Text('Trending Now 🔥',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700)),
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
                          separatorBuilder: (_, __) =>
                              const SizedBox(width: 14),
                          itemBuilder: (ctx, i) =>
                              _TrendingCard(trend: trends[i]),
                        ),
                      ),
                      loading: () =>
                          const Center(child: CircularProgressIndicator()),
                      error: (e, _) => GlassCard(
                        child: Text(
                            'Could not load trends. Check API connection.',
                            style: TextStyle(color: AppColors.textMuted)),
                      ),
                    ),
                    const SizedBox(height: 28),

                    // ── Your Generated Videos
                    Row(
                      children: [
                        Icon(Icons.video_library_rounded,
                            color: AppColors.primary),
                        const SizedBox(width: 8),
                        Text('Your AI Videos 🤖',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700)),
                      ],
                    ),
                    const SizedBox(height: 14),
                    ref.watch(_youtubeHistoryProvider).when(
                          data: (videos) => videos.isEmpty
                              ? GlassCard(
                                  padding: const EdgeInsets.all(20),
                                  child: Row(
                                    children: [
                                      Icon(Icons.info_outline,
                                          color: AppColors.textMuted),
                                      const SizedBox(width: 12),
                                      const Expanded(
                                          child: Text(
                                              'No videos generated yet. Try generating one!',
                                              style: TextStyle(
                                                  color: AppColors.textMuted))),
                                    ],
                                  ),
                                )
                              : SizedBox(
                                  height: 160,
                                  child: ListView.separated(
                                    scrollDirection: Axis.horizontal,
                                    padding: EdgeInsets.zero,
                                    itemCount: videos.length,
                                    separatorBuilder: (_, __) =>
                                        const SizedBox(width: 14),
                                    itemBuilder: (ctx, i) =>
                                        _YouTubeGeneratedCard(video: videos[i]),
                                  ),
                                ),
                          loading: () =>
                              const Center(child: CircularProgressIndicator()),
                          error: (e, _) => GlassCard(
                            child: Text(
                                'Could not load history. Check API connection.',
                                style: TextStyle(color: AppColors.textMuted)),
                          ),
                        ),
                    const SizedBox(height: 28),

                    // ── Multi-Platform Heatmap
                    Text('Multi-Platform Heatmap',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 14),
                    _PlatformHeatmap(),
                    const SizedBox(height: 28),

                    // ── Recommendations
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Recommended For You',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700)),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            gradient: AppColors.gradientPrimary,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text('Personalized',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600)),
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
                  Text('Viral Score Today',
                      style:
                          TextStyle(color: AppColors.textMuted, fontSize: 13)),
                ],
              ),
              const SizedBox(height: 8),
              GradientText(
                '$score%',
                style: Theme.of(context)
                    .textTheme
                    .displaySmall
                    ?.copyWith(fontWeight: FontWeight.w800),
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
      ..shader = AppColors.gradientPrimary
          .createShader(Rect.fromCircle(center: center, radius: radius))
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
                    Icon(Icons.arrow_upward_rounded,
                        color: AppColors.success, size: 14),
                    Text('${trend.growth.toInt()}%',
                        style: TextStyle(
                            color: AppColors.success,
                            fontWeight: FontWeight.w600,
                            fontSize: 12)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(trend.hashtag,
                style:
                    const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                maxLines: 2,
                overflow: TextOverflow.ellipsis),
            const Spacer(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Score',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
                GradientText('${trend.score.toInt()}%',
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 14)),
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
                SizedBox(
                    width: 80,
                    child: Text(name,
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w500))),
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
                Text('$score%',
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 13)),
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
  const _RecommendationCard(
      {required this.title, required this.hook, required this.bestTime});
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
          Text(hook,
              style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Best time: $bestTime',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
              GestureDetector(
                onTap: () => context.go('/ai-generator'),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    gradient: AppColors.gradientPrimary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text('Generate Script',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 12)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  const _QuickActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: GlassCard(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: AppColors.primary, size: 18),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Generated Video Card
class _YouTubeGeneratedCard extends StatelessWidget {
  const _YouTubeGeneratedCard({required this.video});
  final YouTubeGeneratedModel video;

  @override
  Widget build(BuildContext context) {
    bool isPending = video.status == 'pending_review';
    bool isPosted = video.status == 'posted';

    return Container(
      width: 240,
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
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isPosted
                      ? AppColors.success.withValues(alpha: 0.2)
                      : (isPending
                          ? Colors.orange.withValues(alpha: 0.2)
                          : Colors.grey.withValues(alpha: 0.2)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  video.status.toUpperCase(),
                  style: TextStyle(
                    color: isPosted
                        ? AppColors.success
                        : (isPending ? Colors.orange : Colors.grey),
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              TrendTypeIcon(type: 'video'),
            ],
          ),
          const SizedBox(height: 12),
          Text(video.title,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              maxLines: 2,
              overflow: TextOverflow.ellipsis),
          const SizedBox(height: 6),
          Text('Niche: ${video.niche}',
              style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
          const Spacer(),
          if (isPending)
            Text('Check your email to approve.',
                style: TextStyle(
                    color: AppColors.accent,
                    fontSize: 11,
                    fontStyle: FontStyle.italic)),
          if (isPosted)
            Row(
              children: [
                Icon(Icons.check_circle_rounded,
                    color: AppColors.success, size: 14),
                const SizedBox(width: 4),
                const Text('Published!',
                    style: TextStyle(
                        color: AppColors.success,
                        fontSize: 11,
                        fontWeight: FontWeight.w600)),
              ],
            ),
        ],
      ),
    );
  }
}
