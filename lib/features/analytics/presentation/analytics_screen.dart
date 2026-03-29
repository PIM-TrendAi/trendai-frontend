/// Analytics / Stats screen
/// Section 1: YouTube Live Stats (real data from user's channel via YouTube API)
/// Section 2: Engagement trend line chart
/// Section 3: Platform bar chart
/// Section 4: Best posting time heatmap
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../shared/widgets/shared_widgets.dart';

// ── Providers
final _analyticsSummaryProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final res = await ref.read(dioProvider).get('/analytics/summary/');
  return res.data as Map<String, dynamic>;
});

final _engagementProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final res = await ref.read(dioProvider).get('/analytics/engagement/');
  return List<Map<String, dynamic>>.from(res.data['data']);
});

final _platformProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final res = await ref.read(dioProvider).get('/analytics/platforms/');
  return List<Map<String, dynamic>>.from(res.data['data']);
});

final _ytStatusProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final res = await ref.read(dioProvider).get('/analytics/youtube/status/');
  return res.data as Map<String, dynamic>;
});

final _ytChannelStatsProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final res = await ref.read(dioProvider).get('/analytics/youtube/channel-stats/');
  return res.data as Map<String, dynamic>;
});

final _ytMyVideosProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final res = await ref.read(dioProvider).get('/analytics/youtube/my-videos/');
  final data = res.data;
  if (data is Map && data['results'] != null) {
    return List<Map<String, dynamic>>.from(data['results']);
  }
  return [];
});

class AnalyticsScreen extends ConsumerWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(_analyticsSummaryProvider);
    final engagementAsync = ref.watch(_engagementProvider);
    final platformAsync = ref.watch(_platformProvider);
    final ytStatusAsync = ref.watch(_ytStatusProvider);

    return Scaffold(
      body: Stack(
        children: [
          const AnimatedParticleBackground(),
          Column(
            children: [
              const TrendAIAppBar(title: 'Analytics', subtitle: 'Last 7 days'),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [

                      // ── YouTube Live Stats Section
                      ytStatusAsync.when(
                        data: (status) => status['connected'] == true
                            ? _YouTubeLiveSection(ref: ref)
                            : _YouTubeConnectBanner(ref: ref),
                        loading: () => const SizedBox.shrink(),
                        error: (_, __) => _YouTubeConnectBanner(ref: ref),
                      ),
                      const SizedBox(height: 24),

                      // ── Stat Cards
                      summaryAsync.when(
                        data: (summary) => GridView.count(
                          crossAxisCount: 2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 1.4,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          children: [
                            _StatCard(label: '👁 Total Views', value: summary['total_views']?['label'] ?? '--', trend: summary['total_views']?['trend']),
                            _StatCard(label: '💥 Engagement', value: summary['engagement']?['label'] ?? '--', trend: summary['engagement']?['trend']),
                            _StatCard(label: '👥 Followers', value: summary['followers']?['label'] ?? '--', trend: summary['followers']?['trend']),
                            _StatCard(label: '🔥 Viral Score', value: summary['viral_score']?['label'] ?? '--', trend: summary['viral_score']?['trend']),
                          ],
                        ),
                        loading: () => const Center(child: CircularProgressIndicator()),
                        error: (_, __) => const SizedBox.shrink(),
                      ),
                      const SizedBox(height: 24),

                      // ── Engagement Trend
                      Text('Engagement Trend',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 14),
                      engagementAsync.when(
                        data: (data) => GlassCard(
                          child: SizedBox(height: 160, child: _EngagementLineChart(data: data)),
                        ),
                        loading: () => const Center(child: CircularProgressIndicator()),
                        error: (_, __) => const SizedBox.shrink(),
                      ),
                      const SizedBox(height: 24),

                      // ── Platform Performance
                      Text('Platform Performance',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 14),
                      platformAsync.when(
                        data: (data) => GlassCard(
                          child: SizedBox(height: 180, child: _PlatformBarChart(data: data)),
                        ),
                        loading: () => const Center(child: CircularProgressIndicator()),
                        error: (_, __) => const SizedBox.shrink(),
                      ),
                      const SizedBox(height: 24),

                      // ── Best Posting Times
                      Text('Best Posting Times',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 14),
                      GlassCard(child: _PostingHeatmap()),
                    ],
                  ),
                ),
              ),
            ],
          ),
          Positioned(
            left: 0, right: 0, bottom: 0,
            child: const TrendAIBottomNav(currentIndex: 3),
          ),
        ],
      ),
    );
  }
}

// ── YouTube Connect Banner (when not connected)
class _YouTubeConnectBanner extends ConsumerWidget {
  const _YouTubeConnectBanner({required this.ref});
  final WidgetRef ref;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFF0000).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFF0000).withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFFF0000),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('YouTube not connected',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                Text('Connect to see your real video stats',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => Navigator.of(context).pushNamed('/profile'),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                gradient: AppColors.gradientPrimary,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text('Connect',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12)),
            ),
          ),
        ],
      ),
    );
  }
}

// ── YouTube Live Stats Section (when connected)
class _YouTubeLiveSection extends ConsumerWidget {
  const _YouTubeLiveSection({required this.ref});
  final WidgetRef ref;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final channelAsync = ref.watch(_ytChannelStatsProvider);
    final videosAsync = ref.watch(_ytMyVideosProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFFF0000),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 10),
            const Text('YouTube Live Stats',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 7, height: 7,
                    decoration: BoxDecoration(color: AppColors.success, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 5),
                  Text('LIVE', style: TextStyle(color: AppColors.success, fontSize: 11, fontWeight: FontWeight.w800)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // Channel stats row
        channelAsync.when(
          data: (stats) => Row(
            children: [
              _YtStatPill(icon: Icons.remove_red_eye_outlined, label: stats['view_count'] ?? '--', sub: 'Total Views'),
              const SizedBox(width: 10),
              _YtStatPill(icon: Icons.people_outline_rounded, label: stats['subscriber_count'] ?? '--', sub: 'Subscribers'),
              const SizedBox(width: 10),
              _YtStatPill(icon: Icons.video_library_outlined, label: stats['video_count'] ?? '--', sub: 'Videos'),
            ],
          ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Text('Could not load channel stats: $e',
              style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
        ),
        const SizedBox(height: 16),

        // My videos list
        videosAsync.when(
          data: (videos) => videos.isEmpty
              ? GlassCard(
                  child: Center(
                    child: Text('No published videos found on your channel.',
                        style: TextStyle(color: AppColors.textMuted)),
                  ),
                )
              : Column(
                  children: videos.map((v) => _YtVideoStatCard(video: v)).toList(),
                ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => const SizedBox.shrink(),
        ),
      ],
    );
  }
}

class _YtStatPill extends StatelessWidget {
  const _YtStatPill({required this.icon, required this.label, required this.sub});
  final IconData icon;
  final String label;
  final String sub;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.grey.shade200,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: const Color(0xFFFF0000), size: 18),
            const SizedBox(height: 4),
            GradientText(label, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
            Text(sub, style: TextStyle(color: AppColors.textMuted, fontSize: 9)),
          ],
        ),
      ),
    );
  }
}

class _YtVideoStatCard extends StatelessWidget {
  const _YtVideoStatCard({required this.video});
  final Map<String, dynamic> video;

  String _fmt(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return n.toString();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tags = (video['tags'] as List?)?.take(3).join(' ') ?? '';
    final views = _fmt((video['views'] as num?)?.toInt() ?? 0);
    final likes = _fmt((video['likes'] as num?)?.toInt() ?? 0);
    final comments = _fmt((video['comments'] as num?)?.toInt() ?? 0);
    final thumb = video['thumbnail'] as String?;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.grey.shade200,
        ),
      ),
      child: Row(
        children: [
          // Thumbnail
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: thumb != null && thumb.isNotEmpty
                ? Image.network(thumb, width: 64, height: 64, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _placeholder())
                : _placeholder(),
          ),
          const SizedBox(width: 12),
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tags.isNotEmpty ? tags : (video['title'] as String? ?? 'Video'),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    _StatChip(icon: Icons.remove_red_eye_outlined, value: views),
                    const SizedBox(width: 8),
                    _StatChip(icon: Icons.favorite_outline_rounded, value: likes),
                    const SizedBox(width: 8),
                    _StatChip(icon: Icons.comment_outlined, value: comments),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _placeholder() {
    return Container(
      width: 64, height: 64,
      decoration: BoxDecoration(
        gradient: AppColors.gradientPrimary,
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 28),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.icon, required this.value});
  final IconData icon;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 12, color: AppColors.textMuted),
      const SizedBox(width: 3),
      Text(value, style: TextStyle(fontSize: 11, color: AppColors.textMuted, fontWeight: FontWeight.w600)),
    ]);
  }
}

// ── Stat card (existing)
class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value, this.trend});
  final String label;
  final String value;
  final String? trend;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
          const Spacer(),
          GradientText(value, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 22)),
          if (trend != null) ...[
            const SizedBox(height: 4),
            Row(children: [
              Icon(Icons.arrow_upward_rounded, color: AppColors.success, size: 12),
              Text(trend!, style: TextStyle(color: AppColors.success, fontSize: 11, fontWeight: FontWeight.w600)),
            ]),
          ],
        ],
      ),
    );
  }
}

// ── Engagement line chart (existing)
class _EngagementLineChart extends StatelessWidget {
  const _EngagementLineChart({required this.data});
  final List<Map<String, dynamic>> data;

  @override
  Widget build(BuildContext context) {
    final spots = data.asMap().entries.map((e) =>
      FlSpot(e.key.toDouble(), (e.value['engagement'] as num).toDouble()),
    ).toList();

    return LineChart(LineChartData(
      gridData: FlGridData(show: false),
      borderData: FlBorderData(show: false),
      titlesData: FlTitlesData(
        bottomTitles: AxisTitles(sideTitles: SideTitles(
          showTitles: true,
          getTitlesWidget: (v, _) => Text(data[v.toInt()]['day'] as String? ?? '',
              style: TextStyle(color: AppColors.textMuted, fontSize: 10)),
          interval: 1,
        )),
        topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
      ),
      lineBarsData: [LineChartBarData(
        spots: spots,
        isCurved: true,
        gradient: AppColors.gradientPrimaryHorizontal,
        barWidth: 3,
        dotData: FlDotData(show: false),
        belowBarData: BarAreaData(show: true, gradient: LinearGradient(
          colors: [AppColors.primary.withValues(alpha: 0.3), Colors.transparent],
          begin: Alignment.topCenter, end: Alignment.bottomCenter,
        )),
      )],
    ));
  }
}

// ── Platform bar chart (existing)
class _PlatformBarChart extends StatelessWidget {
  const _PlatformBarChart({required this.data});
  final List<Map<String, dynamic>> data;

  static const _platformColors = {
    'TikTok': AppColors.tikTok,
    'Instagram': AppColors.instagram,
    'YouTube': AppColors.youtube,
    'Facebook': AppColors.facebook,
  };

  @override
  Widget build(BuildContext context) {
    final maxVal = data.map((d) => (d['value'] as num).toDouble()).reduce((a, b) => a > b ? a : b);

    return BarChart(BarChartData(
      alignment: BarChartAlignment.spaceAround,
      maxY: maxVal * 1.2,
      gridData: FlGridData(show: false),
      borderData: FlBorderData(show: false),
      titlesData: FlTitlesData(
        bottomTitles: AxisTitles(sideTitles: SideTitles(
          showTitles: true,
          getTitlesWidget: (v, _) {
            final name = data[v.toInt()]['name'] as String? ?? '';
            return Text(name, style: TextStyle(color: AppColors.textMuted, fontSize: 10));
          },
        )),
        topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
      ),
      barGroups: data.asMap().entries.map((e) {
        final color = _platformColors[e.value['name']] ?? AppColors.primary;
        return BarChartGroupData(x: e.key, barRods: [BarChartRodData(
          toY: (e.value['value'] as num).toDouble(),
          gradient: LinearGradient(
            colors: [color, AppColors.primary],
            begin: Alignment.bottomCenter, end: Alignment.topCenter,
          ),
          width: 28,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
        )]);
      }).toList(),
    ));
  }
}

// ── Posting heatmap (existing)
class _PostingHeatmap extends StatelessWidget {
  final _hours = ['6AM', '12PM', '6PM', '12AM'];
  final _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  final _scores = [
    [2, 3, 4, 5, 8, 9, 7],
    [5, 6, 7, 8, 9, 8, 6],
    [8, 9, 9, 9, 10, 9, 8],
    [3, 4, 5, 6, 7, 8, 7],
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 44),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: _days.map((d) => Text(d, style: TextStyle(color: AppColors.textMuted, fontSize: 9))).toList(),
          ),
        ),
        const SizedBox(height: 8),
        ...List.generate(_hours.length, (hi) => Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(children: [
            SizedBox(width: 36, child: Text(_hours[hi], style: TextStyle(color: AppColors.textMuted, fontSize: 9))),
            ...List.generate(_days.length, (di) {
              final score = _scores[hi][di];
              final opacity = score / 10.0;
              return Expanded(child: Container(
                height: 28,
                margin: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: opacity * 0.8),
                  borderRadius: BorderRadius.circular(4),
                ),
              ));
            }),
          ]),
        )),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text('Low', style: TextStyle(color: AppColors.textMuted, fontSize: 10)),
            const SizedBox(width: 6),
            ...List.generate(5, (i) => Container(
              width: 14, height: 14,
              margin: const EdgeInsets.symmetric(horizontal: 1),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: (i + 1) * 0.2),
                borderRadius: BorderRadius.circular(3),
              ),
            )),
            const SizedBox(width: 6),
            Text('High', style: TextStyle(color: AppColors.textMuted, fontSize: 10)),
          ],
        ),
      ],
    );
  }
}
