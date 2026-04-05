// Dashboard screen — main screen with viral score card, trending hashtags,
// platform heatmap, and AI recommendations. Matches the Figma design.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../shared/widgets/shared_widgets.dart';
import '../../auth/data/models.dart';
import '../../auth/auth_repository.dart';
import '../../trends/data/trends_provider.dart';

class _DashboardVideo {
  final String platform;
  final String title;
  final String thumbnailUrl;
  final String externalUrl;
  final String viewsLabel;
  final int views;

  const _DashboardVideo({
    required this.platform,
    required this.title,
    required this.thumbnailUrl,
    this.externalUrl = '',
    this.viewsLabel = '',
    this.views = 0,
  });
}

String _fmtCount(int count) {
  if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)}M';
  if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}K';
  if (count > 0) return count.toString();
  return '';
}

final _dashboardVideosProvider = FutureProvider<List<_DashboardVideo>>((ref) async {
  final dio = ref.read(dioProvider);
  final results = <_DashboardVideo>[];

  final futures = await Future.wait([
    // TikTok
    ref.read(tiktokVideosProvider('').future).then<List<_DashboardVideo>>((vids) =>
      vids.take(3).map((v) => _DashboardVideo(
        platform: 'tiktok',
        title: v.title,
        thumbnailUrl: v.thumbnailUrl,
        externalUrl: v.tiktokUrl,
        viewsLabel: v.views,
      )).toList(),
    ).catchError((_) => <_DashboardVideo>[]),
    // Instagram
    dio.get('/n8n/trending_videos/').then<List<_DashboardVideo>>((res) {
      final list = res.data['results'] as List? ?? res.data as List;
      return list.cast<Map<String, dynamic>>().take(3).map((j) => _DashboardVideo(
        platform: 'instagram',
        title: j['title'] as String? ?? 'Instagram Reel',
        thumbnailUrl: j['thumbnail_url'] as String? ?? '',
        externalUrl: j['tiktok_url'] as String? ?? '',
        viewsLabel: j['views'] as String? ?? '',
      )).toList();
    }).catchError((_) => <_DashboardVideo>[]),
    // YouTube
    dio.get('/trends/youtube-videos/').then<List<_DashboardVideo>>((res) {
      final list = res.data['results'] as List? ?? res.data as List;
      return list.cast<Map<String, dynamic>>().take(3).map((j) {
        final yt = YouTubeVideoModel.fromJson(j);
        return _DashboardVideo(
          platform: 'youtube',
          title: yt.titre ?? 'YouTube Video',
          thumbnailUrl: 'https://img.youtube.com/vi/${yt.videoId}/hqdefault.jpg',
          externalUrl: 'https://www.youtube.com/watch?v=${yt.videoId}',
          viewsLabel: _fmtCount(yt.vues),
          views: yt.vues,
        );
      }).toList();
    }).catchError((_) => <_DashboardVideo>[]),
    // Facebook
    dio.get('/trends/reels/').then<List<_DashboardVideo>>((res) {
      final list = res.data['results'] as List? ?? res.data as List;
      return list.cast<Map<String, dynamic>>().take(3).map((j) {
        final fb = FacebookReelModel.fromJson(j);
        return _DashboardVideo(
          platform: 'facebook',
          title: (fb.text != null && fb.text!.isNotEmpty) ? fb.text! : 'Facebook Reel',
          thumbnailUrl: fb.thumbnailUrl ?? '',
          externalUrl: fb.reelUrl ?? '',
          viewsLabel: _fmtCount(fb.playCount),
          views: fb.playCount,
        );
      }).toList();
    }).catchError((_) => <_DashboardVideo>[]),
  ]);

  // Interleave
  final maxLen = futures.fold<int>(0, (m, b) => b.length > m ? b.length : m);
  for (var i = 0; i < maxLen; i++) {
    for (final bucket in futures) {
      if (i < bucket.length) results.add(bucket[i]);
    }
  }
  return results;
});

// ── Personalised recommendations from backend (Claude AI or rule-based fallback)
class _Recommendation {
  final String title;
  final String hook;
  final String bestTime;
  final String niche;
  final String platform;
  final String videoId;
  final String angle;

  const _Recommendation({
    required this.title,
    required this.hook,
    required this.bestTime,
    required this.niche,
    required this.platform,
    required this.videoId,
    required this.angle,
  });

  factory _Recommendation.fromJson(Map<String, dynamic> j) => _Recommendation(
        title: j['title'] as String? ?? 'Trending Content',
        hook: j['hook'] as String? ?? '',
        bestTime: j['best_time'] as String? ?? '6:00 PM',
        niche: j['niche'] as String? ?? '',
        platform: j['platform'] as String? ?? 'tiktok',
        videoId: j['video_id'] as String? ?? '',
        angle: j['angle'] as String? ?? '',
      );
}

final _recommendationsProvider = FutureProvider<List<_Recommendation>>((ref) async {
  // Watch the user's niches — re-fetches automatically when they change
  ref.watch(authNotifierProvider.select((u) => u.valueOrNull?.categories));
  final dio = ref.read(dioProvider);
  final res = await dio.get('/n8n/recommendations/');
  final list = res.data as List? ?? [];
  return list.map((e) => _Recommendation.fromJson(e as Map<String, dynamic>)).toList();
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
                    Consumer(builder: (context, ref, _) {
                      final videosAsync = ref.watch(_dashboardVideosProvider);
                      return videosAsync.when(
                        data: (videos) => SizedBox(
                          height: 200,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            padding: EdgeInsets.zero,
                            itemCount: videos.take(8).length,
                            separatorBuilder: (_, __) => const SizedBox(width: 12),
                            itemBuilder: (ctx, i) => _DashboardVideoCard(video: videos[i]),
                          ),
                        ),
                        loading: () => const SizedBox(height: 200, child: Center(child: CircularProgressIndicator())),
                        error: (e, _) => const GlassCard(
                          child: Text('Could not load trending videos.', style: TextStyle(color: AppColors.textMuted)),
                        ),
                      );
                    }),
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
                          child: const Text('AI Personalized', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Consumer(builder: (context, ref, _) {
                      final recsAsync = ref.watch(_recommendationsProvider);
                      return recsAsync.when(
                        data: (recs) => Column(
                          children: [
                            for (final rec in recs) ...[
                              _RecommendationCard(rec: rec),
                              const SizedBox(height: 12),
                            ],
                          ],
                        ),
                        loading: () => Column(
                          children: List.generate(2, (_) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: GlassCard(
                              child: SizedBox(
                                height: 80,
                                child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary)),
                              ),
                            ),
                          )),
                        ),
                        error: (_, __) => const SizedBox.shrink(),
                      );
                    }),
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

// ── Dashboard Video Card (horizontal scroll with thumbnails)
class _DashboardVideoCard extends StatelessWidget {
  const _DashboardVideoCard({required this.video});
  final _DashboardVideo video;

  static const _platformColors = {
    'tiktok': AppColors.tikTok,
    'instagram': Color(0xFFDD2A7B),
    'youtube': Color(0xFFFF0000),
    'facebook': Color(0xFF1877F2),
  };

  static const _platformLabels = {
    'tiktok': 'TikTok',
    'instagram': 'Instagram',
    'youtube': 'YouTube',
    'facebook': 'Facebook',
  };

  @override
  Widget build(BuildContext context) {
    final color = _platformColors[video.platform] ?? AppColors.primary;
    final label = _platformLabels[video.platform] ?? video.platform;

    return GestureDetector(
      onTap: video.externalUrl.isNotEmpty
          ? () => launchUrl(Uri.parse(video.externalUrl), mode: LaunchMode.externalApplication)
          : null,
      child: Container(
        width: 130,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: Colors.white.withValues(alpha: 0.05),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        clipBehavior: Clip.hardEdge,
        child: Stack(
          fit: StackFit.expand,
          children: [
            video.thumbnailUrl.isNotEmpty
                ? Image.network(video.thumbnailUrl, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: color.withValues(alpha: 0.10),
                      child: Center(child: Icon(Icons.play_circle_outline_rounded, color: color, size: 32)),
                    ))
                : Container(
                    color: color.withValues(alpha: 0.10),
                    child: Center(child: Icon(Icons.play_circle_outline_rounded, color: color, size: 32)),
                  ),
            // Gradient overlay
            Positioned(
              bottom: 0, left: 0, right: 0,
              child: Container(
                height: 80,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter, end: Alignment.topCenter,
                    colors: [Colors.black.withValues(alpha: 0.85), Colors.transparent],
                  ),
                ),
              ),
            ),
            // Play button
            Center(
              child: Container(
                width: 32, height: 32,
                decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.4), shape: BoxShape.circle),
                child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 20),
              ),
            ),
            // Platform badge
            Positioned(
              top: 6, left: 6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(label, style: const TextStyle(fontSize: 7, fontWeight: FontWeight.w700, color: Colors.white)),
              ),
            ),
            // Title & views
            Positioned(
              bottom: 0, left: 0, right: 0,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(video.title,
                        maxLines: 2, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.white, height: 1.2)),
                    if (video.viewsLabel.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(video.viewsLabel,
                          style: const TextStyle(fontSize: 9, color: Colors.white70)),
                    ],
                  ],
                ),
              ),
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
  const _RecommendationCard({required this.rec});
  final _Recommendation rec;

  static const _platformIcons = {
    'tiktok': Icons.music_note_rounded,
    'instagram': Icons.camera_alt_rounded,
    'youtube': Icons.play_circle_rounded,
    'facebook': Icons.facebook_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final icon = _platformIcons[rec.platform] ?? Icons.video_call_rounded;

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: AppColors.primary),
              const SizedBox(width: 6),
              if (rec.niche.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(rec.niche, style: const TextStyle(color: AppColors.primary, fontSize: 10, fontWeight: FontWeight.w600)),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(rec.title, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(rec.hook, style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
          if (rec.angle.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(rec.angle, style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
          ],
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Best time: ${rec.bestTime}', style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
              GestureDetector(
                onTap: () {
                  final params = <String, String>{
                    'niche': rec.niche,
                    'platform': rec.platform,
                    if (rec.videoId.isNotEmpty) 'selectedVideoId': rec.videoId,
                  };
                  final query = params.entries.map((e) => '${e.key}=${Uri.encodeComponent(e.value)}').join('&');
                  context.push('/ai-generator?$query');
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    gradient: AppColors.gradientPrimary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text('1-Tap Generate',
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


