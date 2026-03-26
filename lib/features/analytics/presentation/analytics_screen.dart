// Analytics screen — stat cards, engagement chart, platform chart, heatmap, TikTok live stats.
import 'dart:async';
import 'dart:convert';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../../../core/config/server_config.dart' show ServerConfig;
import '../../../../core/network/dio_client.dart';
import '../../../../core/storage/secure_storage.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/shared_widgets.dart';

// ── REST providers
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

// ── WebSocket config
String get _wsBase => '${ServerConfig.wsBase}/ws/tiktok-stats/';
const _reconnectDelay = Duration(seconds: 5);

// ─────────────────────────────────────────────
// Screen
// ─────────────────────────────────────────────
class AnalyticsScreen extends ConsumerStatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  ConsumerState<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends ConsumerState<AnalyticsScreen> {
  // WebSocket state
  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _sub;
  Timer? _reconnectTimer;
  List<Map<String, dynamic>> _videos = [];
  bool _wsConnected = false;
  bool _wsLoading = true;
  String? _wsError;

  @override
  void initState() {
    super.initState();
    _connectWs();
  }

  @override
  void dispose() {
    _reconnectTimer?.cancel();
    _sub?.cancel();
    _channel?.sink.close();
    super.dispose();
  }

  // ── WebSocket connect
  Future<void> _connectWs() async {
    final jwt = await ref.read(secureStorageProvider).readAccessToken();
    if (!mounted) return;
    if (jwt == null) {
      setState(() { _wsLoading = false; _wsError = 'not_authenticated'; });
      return;
    }
    final uri = Uri.parse('$_wsBase?token=$jwt');
    _channel = WebSocketChannel.connect(uri);
    setState(() { _wsConnected = true; _wsLoading = _videos.isEmpty; _wsError = null; });

    _sub?.cancel();
    _sub = _channel!.stream.listen(
      _onWsMessage,
      onError: (_) => _onWsDisconnected(),
      onDone: _onWsDisconnected,
      cancelOnError: true,
    );
  }

  void _onWsMessage(dynamic raw) {
    if (!mounted) return;
    final Map<String, dynamic> data;
    try { data = jsonDecode(raw as String) as Map<String, dynamic>; }
    catch (_) { return; }

    if (data.containsKey('error')) {
      setState(() { _wsError = data['error'] as String; _wsLoading = false; _wsConnected = false; });
      return;
    }
    setState(() {
      _videos = List<Map<String, dynamic>>.from(data['videos'] as List);
      _wsLoading = false;
      _wsConnected = true;
      _wsError = null;
    });
  }

  void _onWsDisconnected() {
    if (!mounted) return;
    setState(() { _wsConnected = false; _wsLoading = false; });
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(_reconnectDelay, _connectWs);
  }

  // ── Build
  @override
  Widget build(BuildContext context) {
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

                      // ── TikTok Live Stats section (WebSocket)
                      _TikTokLiveSection(
                        videos: _videos,
                        connected: _wsConnected,
                        loading: _wsLoading,
                        error: _wsError,
                        onRetry: _connectWs,
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
                        data: (data) => GlassCard(child: SizedBox(height: 160, child: _EngagementLineChart(data: data))),
                        loading: () => const Center(child: CircularProgressIndicator()),
                        error: (_, __) => const SizedBox.shrink(),
                      ),
                      const SizedBox(height: 24),

                      // ── Platform Performance
                      Text('Platform Performance',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 14),
                      platformAsync.when(
                        data: (data) => GlassCard(child: SizedBox(height: 180, child: _PlatformBarChart(data: data))),
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
          const Positioned(left: 0, right: 0, bottom: 0, child: TrendAIBottomNav(currentIndex: 3)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// TikTok Live Stats inline section
// ─────────────────────────────────────────────
class _TikTokLiveSection extends StatelessWidget {
  const _TikTokLiveSection({
    required this.videos,
    required this.connected,
    required this.loading,
    required this.error,
    required this.onRetry,
  });

  final List<Map<String, dynamic>> videos;
  final bool connected;
  final bool loading;
  final String? error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppColors.tikTok.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.play_circle_rounded, color: AppColors.tikTok, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text('TikTok Live Stats',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            ),
            _PulseIndicator(connected: connected),
          ],
        ),
        const SizedBox(height: 14),

        // Content
        if (loading && videos.isEmpty)
          const Center(child: Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: CircularProgressIndicator(),
          ))
        else if (error != null && videos.isEmpty)
          GlassCard(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(_errorLabel(error!),
                        style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
                  ),
                  TextButton(onPressed: onRetry, child: const Text('Retry')),
                ],
              ),
            ),
          )
        else if (videos.isEmpty)
          GlassCard(
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: Text('No videos found on your TikTok account',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
              ),
            ),
          )
        else
          ...videos.map((v) => _VideoStatCard(video: v)),
      ],
    );
  }

  String _errorLabel(String code) {
    switch (code) {
      case 'tiktok_token_expired': return 'TikTok session expired — reconnect in Profile';
      case 'tiktok_not_connected': return 'TikTok not connected — go to Profile to connect';
      default: return 'Could not reach server — retrying…';
    }
  }
}

// ─────────────────────────────────────────────
// Pulse dot
// ─────────────────────────────────────────────
class _PulseIndicator extends StatelessWidget {
  const _PulseIndicator({required this.connected});
  final bool connected;

  @override
  Widget build(BuildContext context) {
    final color = connected ? AppColors.success : AppColors.textMuted;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle))
            .animate(onPlay: (c) => c.repeat())
            .scaleXY(begin: 1.0, end: connected ? 1.6 : 1.0, duration: 700.ms, curve: Curves.easeInOut)
            .then()
            .scaleXY(begin: 1.6, end: 1.0, duration: 700.ms),
        const SizedBox(width: 5),
        Text(connected ? 'LIVE' : 'Offline',
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color, letterSpacing: 0.5)),
      ],
    );
  }
}

// ─────────────────────────────────────────────
// Video stat card
// ─────────────────────────────────────────────
class _VideoStatCard extends StatelessWidget {
  const _VideoStatCard({required this.video});
  final Map<String, dynamic> video;

  @override
  Widget build(BuildContext context) {
    final title = video['title'] as String? ?? 'Untitled';
    final thumbnail = video['thumbnail_url'] as String? ?? '';
    final views = video['views'] as int? ?? 0;
    final likes = video['likes'] as int? ?? 0;
    final comments = video['comments'] as int? ?? 0;
    final shares = video['shares'] as int? ?? 0;
    final avgWatch = (video['avg_watch_time_seconds'] as num?)?.toDouble() ?? 0.0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GlassCard(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: thumbnail.isNotEmpty
                  ? Image.network(thumbnail, width: 72, height: 72, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _thumb())
                  : _thumb(),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, maxLines: 2, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  const SizedBox(height: 7),
                  Wrap(
                    spacing: 10,
                    runSpacing: 5,
                    children: [
                      _chip(Icons.play_arrow_rounded, _fmt(views), 'views'),
                      _chip(Icons.favorite_rounded, _fmt(likes), 'likes', color: AppColors.tikTok),
                      _chip(Icons.comment_rounded, _fmt(comments), 'comments'),
                      _chip(Icons.share_rounded, _fmt(shares), 'shares'),
                      _chip(Icons.timer_rounded, '${avgWatch.toStringAsFixed(1)}s', 'avg watch', color: AppColors.accent),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _thumb() => Container(
    width: 72, height: 72,
    decoration: BoxDecoration(
      color: AppColors.tikTok.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(8),
    ),
    child: const Icon(Icons.play_circle_outline_rounded, color: AppColors.tikTok, size: 28),
  );

  Widget _chip(IconData icon, String value, String label, {Color color = AppColors.textMuted}) =>
      Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 3),
        Text('$value $label', style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w500)),
      ]);

  String _fmt(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return n.toString();
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
            Row(children: [
              const Icon(Icons.arrow_upward_rounded, color: AppColors.success, size: 12),
              Text(trend!, style: const TextStyle(color: AppColors.success, fontSize: 11, fontWeight: FontWeight.w600)),
            ]),
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
      FlSpot(e.key.toDouble(), (e.value['engagement'] as num).toDouble())).toList();

    return LineChart(LineChartData(
      gridData: const FlGridData(show: false),
      borderData: FlBorderData(show: false),
      titlesData: FlTitlesData(
        bottomTitles: AxisTitles(sideTitles: SideTitles(
          showTitles: true, interval: 1,
          getTitlesWidget: (v, _) => Text(data[v.toInt()]['day'] as String? ?? '',
              style: const TextStyle(color: AppColors.textMuted, fontSize: 10)),
        )),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      ),
      lineBarsData: [LineChartBarData(
        spots: spots, isCurved: true,
        gradient: AppColors.gradientPrimaryHorizontal, barWidth: 3,
        dotData: const FlDotData(show: false),
        belowBarData: BarAreaData(show: true, gradient: LinearGradient(
          colors: [AppColors.primary.withValues(alpha: 0.3), Colors.transparent],
          begin: Alignment.topCenter, end: Alignment.bottomCenter,
        )),
      )],
    ));
  }
}

// ── Platform bar chart
class _PlatformBarChart extends StatelessWidget {
  const _PlatformBarChart({required this.data});
  final List<Map<String, dynamic>> data;

  static const _platformColors = {
    'TikTok': AppColors.tikTok, 'Instagram': AppColors.instagram,
    'YouTube': AppColors.youtube, 'Facebook': AppColors.facebook,
  };

  @override
  Widget build(BuildContext context) {
    final maxVal = data.map((d) => (d['value'] as num).toDouble()).reduce((a, b) => a > b ? a : b);
    return BarChart(BarChartData(
      alignment: BarChartAlignment.spaceAround,
      maxY: maxVal * 1.2,
      gridData: const FlGridData(show: false),
      borderData: FlBorderData(show: false),
      titlesData: FlTitlesData(
        bottomTitles: AxisTitles(sideTitles: SideTitles(
          showTitles: true,
          getTitlesWidget: (v, _) => Text(data[v.toInt()]['name'] as String? ?? '',
              style: const TextStyle(color: AppColors.textMuted, fontSize: 10)),
        )),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      ),
      barGroups: data.asMap().entries.map((e) {
        final color = _platformColors[e.value['name']] ?? AppColors.primary;
        return BarChartGroupData(x: e.key, barRods: [BarChartRodData(
          toY: (e.value['value'] as num).toDouble(),
          gradient: LinearGradient(colors: [color, AppColors.primary],
              begin: Alignment.bottomCenter, end: Alignment.topCenter),
          width: 28,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
        )]);
      }).toList(),
    ));
  }
}

// ── Posting heatmap
class _PostingHeatmap extends StatelessWidget {
  final _hours = const ['6AM', '12PM', '6PM', '12AM'];
  final _days  = const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  final _scores = const [
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
        ...List.generate(_hours.length, (hi) => Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(children: [
            SizedBox(width: 36, child: Text(_hours[hi], style: const TextStyle(color: AppColors.textMuted, fontSize: 9))),
            ...List.generate(_days.length, (di) {
              final opacity = _scores[hi][di] / 10.0;
              return Expanded(child: Container(
                height: 28, margin: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: opacity * 0.8),
                  borderRadius: BorderRadius.circular(4),
                ),
              ));
            }),
          ]),
        )),
        const SizedBox(height: 8),
        Row(mainAxisAlignment: MainAxisAlignment.end, children: [
          const Text('Low', style: TextStyle(color: AppColors.textMuted, fontSize: 10)),
          const SizedBox(width: 6),
          ...List.generate(5, (i) => Container(
            width: 14, height: 14, margin: const EdgeInsets.symmetric(horizontal: 1),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: (i + 1) * 0.2),
              borderRadius: BorderRadius.circular(3),
            ),
          )),
          const SizedBox(width: 6),
          const Text('High', style: TextStyle(color: AppColors.textMuted, fontSize: 10)),
        ]),
      ],
    );
  }
}
