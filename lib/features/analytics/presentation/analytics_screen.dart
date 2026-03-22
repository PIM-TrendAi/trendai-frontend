/// Analytics screen — stat cards, 7-day engagement line chart, platform bar chart, heatmap.
library;
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

class AnalyticsScreen extends ConsumerWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(_analyticsSummaryProvider);
    final engagementAsync = ref.watch(_engagementProvider);
    final platformAsync = ref.watch(_platformProvider);

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

                      // ── Engagement Trend (line chart)
                      Text('Engagement Trend',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 14),
                      engagementAsync.when(
                        data: (data) => GlassCard(
                          child: SizedBox(
                            height: 160,
                            child: _EngagementLineChart(data: data),
                          ),
                        ),
                        loading: () => const Center(child: CircularProgressIndicator()),
                        error: (_, __) => const SizedBox.shrink(),
                      ),
                      const SizedBox(height: 24),

                      // ── Platform Performance (bar chart)
                      Text('Platform Performance',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 14),
                      platformAsync.when(
                        data: (data) => GlassCard(
                          child: SizedBox(
                            height: 180,
                            child: _PlatformBarChart(data: data),
                          ),
                        ),
                        loading: () => const Center(child: CircularProgressIndicator()),
                        error: (_, __) => const SizedBox.shrink(),
                      ),
                      const SizedBox(height: 24),

                      // ── Best Posting Times (simple heatmap)
                      Text('Best Posting Times',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 14),
                      GlassCard(
                        child: _PostingHeatmap(),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const Positioned(
            left: 0, right: 0, bottom: 0,
            child: TrendAIBottomNav(currentIndex: 4),
          ),
        ],
      ),
    );
  }
}

// ── Stat card
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
          Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
          const Spacer(),
          GradientText(value, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 22)),
          if (trend != null) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.arrow_upward_rounded, color: AppColors.success, size: 12),
                Text(trend!, style: const TextStyle(color: AppColors.success, fontSize: 11, fontWeight: FontWeight.w600)),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ── Engagement line chart
class _EngagementLineChart extends StatelessWidget {
  const _EngagementLineChart({required this.data});
  final List<Map<String, dynamic>> data;

  @override
  Widget build(BuildContext context) {
    final spots = data.asMap().entries.map((e) =>
      FlSpot(e.key.toDouble(), (e.value['engagement'] as num).toDouble()),
    ).toList();

    return LineChart(
      LineChartData(
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (v, _) => Text(
                data[v.toInt()]['day'] as String? ?? '',
                style: const TextStyle(color: AppColors.textMuted, fontSize: 10),
              ),
              interval: 1,
            ),
          ),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            gradient: AppColors.gradientPrimaryHorizontal,
            barWidth: 3,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                colors: [AppColors.primary.withValues(alpha: 0.3), Colors.transparent],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Platform bar chart
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

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxVal * 1.2,
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (v, _) {
                final name = data[v.toInt()]['name'] as String? ?? '';
                return Text(name, style: const TextStyle(color: AppColors.textMuted, fontSize: 10));
              },
            ),
          ),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        barGroups: data.asMap().entries.map((e) {
          final color = _platformColors[e.value['name']] ?? AppColors.primary;
          return BarChartGroupData(
            x: e.key,
            barRods: [
              BarChartRodData(
                toY: (e.value['value'] as num).toDouble(),
                gradient: LinearGradient(
                  colors: [color, AppColors.primary],
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                ),
                width: 28,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }
}

// ── Posting heatmap
class _PostingHeatmap extends StatelessWidget {
  final _hours = ['6AM', '12PM', '6PM', '12AM'];
  final _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  // Score matrix [hours][days] scaled 0-10
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
            children: _days.map((d) => Text(d, style: const TextStyle(color: AppColors.textMuted, fontSize: 9))).toList(),
          ),
        ),
        const SizedBox(height: 8),
        ...List.generate(_hours.length, (hi) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              children: [
                SizedBox(
                  width: 36,
                  child: Text(_hours[hi], style: const TextStyle(color: AppColors.textMuted, fontSize: 9)),
                ),
                ...List.generate(_days.length, (di) {
                  final score = _scores[hi][di];
                  final opacity = score / 10.0;
                  return Expanded(
                    child: Container(
                      height: 28,
                      margin: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: opacity * 0.8),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  );
                }),
              ],
            ),
          );
        }),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            const Text('Low', style: TextStyle(color: AppColors.textMuted, fontSize: 10)),
            const SizedBox(width: 6),
            ...List.generate(5, (i) => Container(
              width: 14,
              height: 14,
              margin: const EdgeInsets.symmetric(horizontal: 1),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: (i + 1) * 0.2),
                borderRadius: BorderRadius.circular(3),
              ),
            )),
            const SizedBox(width: 6),
            const Text('High', style: TextStyle(color: AppColors.textMuted, fontSize: 10)),
          ],
        ),
      ],
    );
  }
}
