/// TrendDetail screen — deep-dive on a single trend.
/// Shows line chart (7-day performance), engagement stats, analysis, action buttons.
library;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../shared/widgets/shared_widgets.dart';
import '../../../auth/data/models.dart';

final _trendDetailProvider = FutureProvider.family<TrendModel, int>((ref, id) async {
  final dio = ref.read(dioProvider);
  final res = await dio.get('/trends/$id/');
  return TrendModel.fromJson(res.data as Map<String, dynamic>);
});

class TrendDetailScreen extends ConsumerWidget {
  const TrendDetailScreen({super.key, required this.id});
  final int id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trendAsync = ref.watch(_trendDetailProvider(id));

    return Scaffold(
      body: Stack(
        children: [
          const AnimatedParticleBackground(),
          trendAsync.when(
            data: (trend) => CustomScrollView(
              slivers: [
                SliverToBoxAdapter(child: TrendAIAppBar(title: trend.hashtag, showBack: true)),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      // ── Header badges
                      Row(
                        children: [
                          PlatformBadge(platform: trend.platform),
                          const SizedBox(width: 8),
                          TrendTypeIcon(type: trend.type),
                          const Spacer(),
                          Row(children: [
                            const Icon(Icons.arrow_upward_rounded, color: AppColors.success, size: 16),
                            Text('${trend.growth.toInt()}% growth',
                                style: const TextStyle(color: AppColors.success, fontWeight: FontWeight.w600)),
                          ]),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // ── 7-Day line chart
                      GlassCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('7-Day Performance',
                                style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                            const SizedBox(height: 16),
                            SizedBox(
                              height: 140,
                              child: _SparklineChart(chartData: trend.chartData),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // ── Engagement stats
                      Row(
                        children: [
                          _StatChip(label: 'Views', value: _fmt(trend.totalViews), icon: Icons.visibility_rounded),
                          const SizedBox(width: 10),
                          _StatChip(label: 'Likes', value: _fmt(trend.totalLikes), icon: Icons.favorite_rounded),
                          const SizedBox(width: 10),
                          _StatChip(label: 'Shares', value: _fmt(trend.totalShares), icon: Icons.share_rounded),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // ── Analysis — Why It's Working
                      GlassCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              const Icon(Icons.auto_awesome_rounded, color: AppColors.primary, size: 18),
                              const SizedBox(width: 8),
                              Text('Why It\'s Working',
                                  style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                            ]),
                            const SizedBox(height: 12),
                            ...trend.analysis.map((s) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 16),
                                  const SizedBox(width: 8),
                                  Expanded(child: Text(s, style: const TextStyle(fontSize: 13))),
                                ],
                              ),
                            )),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // ── Content Stats
                      GlassCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Content Insights',
                                style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                            const SizedBox(height: 12),
                            _InsightRow(icon: Icons.people_alt_rounded, label: 'Target', value: trend.targetAudience),
                            _InsightRow(icon: Icons.timer_rounded, label: 'Avg Length', value: trend.avgVideoLength),
                            _InsightRow(icon: Icons.movie_rounded, label: 'Format', value: trend.dominantFormat),
                            _InsightRow(icon: Icons.schedule_rounded, label: 'Best Time', value: trend.bestPostingTime),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // ── Action Buttons
                      GradientButton(
                        label: 'Generate Script',
                        icon: Icons.auto_awesome_rounded,
                        onPressed: () => context.go('/ai-generator'),
                      ),
                      const SizedBox(height: 12),
                      _SaveTrendButton(trendId: trend.id, isSaved: trend.isSaved, ref: ref),
                    ]),
                  ),
                ),
              ],
            ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
          ),
        ],
      ),
    );
  }

  String _fmt(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return n.toString();
  }
}

class _SparklineChart extends StatelessWidget {
  const _SparklineChart({required this.chartData});
  final List<Map<String, dynamic>> chartData;

  @override
  Widget build(BuildContext context) {
    if (chartData.isEmpty) return const SizedBox.shrink();
    final spots = chartData.asMap().entries.map((e) =>
      FlSpot(e.key.toDouble(), (e.value['value'] as num).toDouble()),
    ).toList();

    return LineChart(
      LineChartData(
        gridData: const FlGridData(show: false),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (val, _) => Text(
                chartData[val.toInt()]['day'] as String? ?? '',
                style: const TextStyle(color: AppColors.textMuted, fontSize: 10),
              ),
              interval: 1,
            ),
          ),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
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

class _StatChip extends StatelessWidget {
  const _StatChip({required this.label, required this.value, required this.icon});
  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GlassCard(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Icon(icon, color: AppColors.primary, size: 20),
            const SizedBox(height: 6),
            GradientText(value, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
            Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
          ],
        ),
      ),
    );
  }
}

class _InsightRow extends StatelessWidget {
  const _InsightRow({required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primary, size: 16),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
          const Spacer(),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
        ],
      ),
    );
  }
}

class _SaveTrendButton extends ConsumerStatefulWidget {
  const _SaveTrendButton({required this.trendId, required this.isSaved, required this.ref});
  final int trendId;
  final bool isSaved;
  final WidgetRef ref;

  @override
  ConsumerState<_SaveTrendButton> createState() => _SaveTrendButtonState();
}

class _SaveTrendButtonState extends ConsumerState<_SaveTrendButton> {
  late bool _saved;

  @override
  void initState() {
    super.initState();
    _saved = widget.isSaved;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        final dio = ref.read(dioProvider);
        try {
          if (_saved) {
            await dio.delete('/trends/${widget.trendId}/save/');
          } else {
            await dio.post('/trends/${widget.trendId}/save/');
          }
          setState(() => _saved = !_saved);
          HapticFeedback.lightImpact();
        } catch (_) {}
      },
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          color: _saved ? Colors.white.withValues(alpha: 0.08) : null,
          gradient: _saved ? null : AppColors.gradientPrimary,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _saved ? Colors.white.withValues(alpha: 0.15) : Colors.transparent),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(_saved ? Icons.bookmark_rounded : Icons.bookmark_add_outlined, color: Colors.white),
            const SizedBox(width: 8),
            Text(_saved ? 'Saved' : 'Save Trend',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}
