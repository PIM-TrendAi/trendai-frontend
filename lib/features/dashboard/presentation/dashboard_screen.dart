// Dashboard screen — main screen with viral score card, trending hashtags,
// platform heatmap, and AI recommendations. Matches the Figma design.
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

final _analyticsSummaryProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final res = await ref.read(dioProvider).get('/analytics/summary/');
  return res.data as Map<String, dynamic>;
});

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});
  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  final _scrollCtrl = ScrollController();

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final trendsAsync = ref.watch(_dashboardTrendsProvider);
    final summaryAsync = ref.watch(_analyticsSummaryProvider);

    return Scaffold(
      body: Stack(
        children: [
          const AnimatedParticleBackground(),
          CustomScrollView(
            controller: _scrollCtrl,
            slivers: [
              const SliverToBoxAdapter(
                child: TrendAIAppBar(
                  title: 'Dashboard',
                  subtitle: 'Powered by AI • Real-time insights',
                  leading: _QuickMenuButton(),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    // ── Viral Score Card
                    summaryAsync.when(
                      data: (summary) {
                        final score = (summary['viral_score']?['value'] as num?)?.toInt() ?? 0;
                        return _ViralScoreCard(score: score);
                      },
                      loading: () => const _ViralScoreCard(score: 0),
                      error: (_, __) => const _ViralScoreCard(score: 0),
                    ),
                    const SizedBox(height: 28),

                    // ── Instagram Section (Added)
                    _InstagramScraperCard(),
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
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: TrendAIBottomNav(currentIndex: 0, scrollController: _scrollCtrl),
          ),
        ],
      ),
    );
  }
}

// ── Quick Menu Button (top-left)
class _QuickMenuButton extends StatefulWidget {
  const _QuickMenuButton();
  @override
  State<_QuickMenuButton> createState() => _QuickMenuButtonState();
}

class _QuickMenuButtonState extends State<_QuickMenuButton> {
  bool _open = false;

  Future<void> _showMenu() async {
    setState(() => _open = true);

    final renderBox = context.findRenderObject() as RenderBox;
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final position = RelativeRect.fromRect(
      Rect.fromPoints(
        renderBox.localToGlobal(Offset(0, renderBox.size.height + 4), ancestor: overlay),
        renderBox.localToGlobal(renderBox.size.bottomRight(Offset.zero), ancestor: overlay),
      ),
      Offset.zero & overlay.size,
    );

    final result = await showMenu<String>(
      context: context,
      position: position,
      elevation: 12,
      color: const Color(0xFF0F111E),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.10)),
      ),
      items: [
        const PopupMenuItem(
          value: '/my-videos',
          child: Row(children: [
            Icon(Icons.video_library_rounded, color: AppColors.primary, size: 16),
            SizedBox(width: 10),
            Text('My Videos',
                style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600, fontSize: 13)),
          ]),
        ),
        const PopupMenuItem(
          value: '/category-selection?from=profile',
          child: Row(children: [
            Icon(Icons.tune_rounded, color: AppColors.tikTok, size: 16),
            SizedBox(width: 10),
            Text('My Niche',
                style: TextStyle(color: AppColors.tikTok, fontWeight: FontWeight.w600, fontSize: 13)),
          ]),
        ),
      ],
    );

    if (!mounted) return;
    setState(() => _open = false);
    if (result != null) context.push(result);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _showMenu,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          gradient: _open ? AppColors.gradientPrimary : null,
          color: _open ? null : Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        ),
        child: const Icon(Icons.widgets_rounded, size: 18, color: Colors.white),
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

// ── Instagram Scraper Card
class _InstagramScraperCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF833AB4), Color(0xFFFD1D1D), Color(0xFFFCB045)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text('Instagram Engine 🔥', 
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Scrape trending niches, choose your favorite, and generate a viral reel in seconds.',
            style: TextStyle(color: AppColors.textMuted, fontSize: 13, height: 1.5),
          ),
          const SizedBox(height: 18),
          GradientButton(
            label: 'Explore Instagram Trends 🚀',
            onPressed: () => context.go('/instagram-engine'),
          ),
        ],
      ),
    );
  }
}

