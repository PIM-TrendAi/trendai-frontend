/// Analytics screen — Facebook Live Stats, stat cards, engagement chart, platform bar chart, heatmap.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../shared/widgets/shared_widgets.dart';

// ── Providers
final _fbVideosProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final res = await ref.read(dioProvider).get('/analytics/facebook-videos/');
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
    final fbAsync = ref.watch(_fbVideosProvider);
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

                      // ── Facebook Live Stats section
                      fbAsync.when(
                        data: (fbData) {
                          final videos = (fbData['videos'] as List? ?? [])
                              .cast<Map<String, dynamic>>();
                          final summary = fbData['summary'] as Map<String, dynamic>? ?? {};
                          final totalViews = summary['total_views'] ?? 0;
                          final engagement = summary['engagement'] ?? 0.0;
                          final source = fbData['source'] as String? ?? 'unknown';
                          final isRealData = source == 'facebook_api';
                          final fbErrors = fbData['partial_errors'] as List? ?? fbData['fb_errors'] as List?;

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Section header
                              Row(
                                children: [
                                  Container(
                                    width: 32, height: 32,
                                    decoration: const BoxDecoration(
                                      color: Color(0xFF1877F2),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Center(
                                      child: Text('f', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18)),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  const Expanded(
                                    child: Text('Facebook Live Stats',
                                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                                  ),
                                  // Refresh button
                                  IconButton(
                                    icon: const Icon(Icons.refresh_rounded, size: 18),
                                    onPressed: () => ref.invalidate(_fbVideosProvider),
                                    tooltip: 'Actualiser',
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                  ),
                                  const SizedBox(width: 8),
                                  // Source badge
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: isRealData
                                          ? AppColors.success.withValues(alpha: 0.15)
                                          : AppColors.warning.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Container(
                                          width: 8, height: 8,
                                          decoration: BoxDecoration(
                                            color: isRealData ? AppColors.success : AppColors.warning,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                        const SizedBox(width: 5),
                                        Text(
                                          isRealData ? 'LIVE' : 'LOCAL',
                                          style: TextStyle(
                                            color: isRealData ? AppColors.success : AppColors.warning,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),

                              // ── Error banner when using local DB
                              if (!isRealData) ..._buildErrorBanner(fbErrors, fbData['fb_hint'] as String?),

                              const SizedBox(height: 10),

                              // Video stat cards
                              if (videos.isEmpty)
                                GlassCard(
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Center(
                                      child: Column(
                                        children: [
                                          Icon(Icons.video_library_outlined,
                                              color: AppColors.textMuted, size: 32),
                                          const SizedBox(height: 8),
                                          Text(
                                            isRealData
                                                ? 'Aucune vidéo trouvée sur votre page Facebook.'
                                                : 'Aucune vidéo dans la base locale.',
                                            style: TextStyle(color: AppColors.textMuted),
                                            textAlign: TextAlign.center,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                )
                              else
                                ...videos.map((v) => _VideoStatCard(video: v)),

                              const SizedBox(height: 20),

                              // Summary cards row
                              Row(
                                children: [
                                  Expanded(
                                    child: _SummaryCard(
                                      icon: Icons.remove_red_eye_outlined,
                                      label: 'Total Views',
                                      value: _formatNumber(totalViews is int ? totalViews : (totalViews as num).toInt()),
                                      color: AppColors.primary,
                                      isLive: isRealData,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _SummaryCard(
                                      icon: Icons.local_fire_department_rounded,
                                      label: 'Engagement',
                                      value: '$engagement%',
                                      color: AppColors.warning,
                                      isLive: isRealData,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          );
                        },
                        loading: () => const Center(child: CircularProgressIndicator()),
                        error: (err, __) => GlassCard(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              children: [
                                const Icon(Icons.wifi_off_rounded, color: AppColors.error, size: 28),
                                const SizedBox(height: 8),
                                Text('Impossible de contacter le backend.',
                                    style: TextStyle(color: AppColors.error, fontWeight: FontWeight.w600)),
                                const SizedBox(height: 4),
                                Text(err.toString(),
                                    style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
                              ],
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 28),

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

                      // ── Best Posting Times (heatmap)
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
          Positioned(
            left: 0, right: 0, bottom: 0,
            child: const TrendAIBottomNav(currentIndex: 3),
          ),
        ],
      ),
    );
  }
}

// ── Utility: format large numbers (56 → "56", 1500 → "1.5K")
String _formatNumber(int n) {
  if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
  if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
  return n.toString();
}

// ── Facebook video stat card
class _VideoStatCard extends StatelessWidget {
  const _VideoStatCard({required this.video});
  final Map<String, dynamic> video;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hashtags = video['hashtags'] as String? ?? '#viral';
    final views = video['views'] ?? 0;
    final likes = video['likes'] ?? 0;
    final comments = video['comments'] ?? 0;
    final shares = video['shares'] ?? 0;
    final avgWatch = video['avg_watch'] ?? 0.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.grey.shade200),
      ),
      child: Row(
        children: [
          // Thumbnail (real image or gradient placeholder)
          _VideoThumbnail(
            url: video['thumbnail_url'] as String? ?? '',
            isDark: isDark,
            seed: (video['session'] as String? ?? video['id']?.toString() ?? '0').hashCode,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(hashtags,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 12,
                  runSpacing: 4,
                  children: [
                    _StatChip(Icons.play_arrow_rounded, '$views views', Colors.white70),
                    _StatChip(Icons.favorite_rounded, '$likes likes', AppColors.error),
                    _StatChip(Icons.chat_bubble_outline_rounded, '$comments comments', Colors.white60),
                  ],
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 12,
                  children: [
                    _StatChip(Icons.share_rounded, '$shares shares', Colors.white60),
                    _StatChip(Icons.timer_outlined, '${avgWatch}s avg watch', AppColors.primary),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Video thumbnail: shows real thumb from Facebook or a gradient placeholder
class _VideoThumbnail extends StatelessWidget {
  const _VideoThumbnail({required this.url, required this.isDark, this.seed = 0});
  final String url;
  final bool isDark;
  final int seed;

  static const _gradients = [
    [Color(0xFF6C5CE7), Color(0xFF00C6FF)],
    [Color(0xFFFF7675), Color(0xFFD63031)],
    [Color(0xFF00B894), Color(0xFF00CEC9)],
    [Color(0xFFE84393), Color(0xFFFD79A8)],
    [Color(0xFFF39C12), Color(0xFFE67E22)],
  ];

  Widget _buildGradient() {
    final pair = _gradients[seed.abs() % _gradients.length];
    return Container(
      width: 72, height: 72,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: LinearGradient(
          colors: pair,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: const Center(
        child: Icon(Icons.play_arrow_rounded, color: Colors.white, size: 32),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (url.isEmpty) return _buildGradient();

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Stack(
        children: [
          _buildGradient(), // always visible as base
          Image.network(
            url,
            width: 72, height: 72,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => const SizedBox.shrink(),
            loadingBuilder: (_, child, progress) {
              if (progress == null) return child;
              return const SizedBox.shrink(); // gradient shows through while loading
            },
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip(this.icon, this.label, this.color);
  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 3),
        Text(label, style: TextStyle(fontSize: 11, color: color)),
      ],
    );
  }
}

// ── Helper: error banner from FB API failure
List<Widget> _buildErrorBanner(List? errors, String? hint) {
  return [
    Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFF6B35).withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFF6B35).withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Color(0xFFFF6B35), size: 16),
              SizedBox(width: 6),
              Text('Données locales — API Facebook indisponible',
                  style: TextStyle(
                    color: Color(0xFFFF6B35),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  )),
            ],
          ),
          if (errors != null && errors.isNotEmpty) ...[  
            const SizedBox(height: 6),
            ...errors.map((e) => Text(
              '• $e',
              style: const TextStyle(color: Color(0xFFFF6B35), fontSize: 10),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            )),
          ],
          if (hint != null) ...[  
            const SizedBox(height: 4),
            Text(hint, style: const TextStyle(color: Color(0xFFFFAA80), fontSize: 10)),
          ],
        ],
      ),
    ),
  ];
}

// (Insights warning removed as views are now fetched directly without read_insights)

// ── Summary card (Total Views / Engagement)
class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    this.isLive = false,
  });
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final bool isLive;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 6),
              Text(label, style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
            ],
          ),
          const SizedBox(height: 8),
          GradientText(value, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 22)),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(
                isLive ? Icons.wifi_rounded : Icons.storage_rounded,
                color: isLive ? AppColors.success : AppColors.warning,
                size: 12,
              ),
              const SizedBox(width: 3),
              Text(
                isLive ? 'Facebook live' : 'Base locale',
                style: TextStyle(
                  color: isLive ? AppColors.success : AppColors.warning,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Engagement line chart (unchanged)
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
              getTitlesWidget: (v, _) {
                final idx = v.toInt();
                if (idx < 0 || idx >= data.length) return const SizedBox.shrink();
                return Text(
                  data[idx]['day'] as String? ?? '',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 10),
                );
              },
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

// ── Platform bar chart (unchanged)
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
    final vals = data.map((d) => (d['value'] as num).toDouble()).toList();
    final maxVal = vals.isEmpty ? 1.0 : vals.reduce((a, b) => a > b ? a : b);

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
                final idx = v.toInt();
                if (idx < 0 || idx >= data.length) return const SizedBox.shrink();
                final name = data[idx]['name'] as String? ?? '';
                return Text(name, style: TextStyle(color: AppColors.textMuted, fontSize: 10));
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

// ── Posting heatmap (unchanged)
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
        ...List.generate(_hours.length, (hi) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              children: [
                SizedBox(
                  width: 36,
                  child: Text(_hours[hi], style: TextStyle(color: AppColors.textMuted, fontSize: 9)),
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
