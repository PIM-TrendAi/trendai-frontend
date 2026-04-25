// TrendsList screen — filterable/sortable list of viral trends.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/storage/secure_storage.dart';
import '../../../../shared/widgets/shared_widgets.dart';
import '../../../auth/data/models.dart';
import '../../../video_workflow/data/models/workflow_models.dart';
import '../../data/trends_provider.dart';

final _allTrendsProvider = FutureProvider.family<List<TrendModel>, Map<String, String>>(
  (ref, params) async {
    final dio = ref.read(dioProvider);
    final res = await dio.get('/trends/', queryParameters: params);
    final list = res.data['results'] as List? ?? res.data as List;
    return list.map((e) => TrendModel.fromJson(e as Map<String, dynamic>)).toList();
  },
);

final _instagramTrendsVideosProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final dio = ref.read(dioProvider);
  final res = await dio.get('/n8n/trending_videos/');
  final list = res.data['results'] as List? ?? res.data as List;
  return list.cast<Map<String, dynamic>>();
});

final _facebookTrendsReelsProvider = FutureProvider<List<FacebookReelModel>>((ref) async {
  final dio = ref.read(dioProvider);
  final res = await dio.get('/trends/reels/');
  final list = res.data['results'] as List? ?? res.data as List;
  return list.map((e) => FacebookReelModel.fromJson(e as Map<String, dynamic>)).toList();
});

final _youtubeTrendsVideosProvider = FutureProvider<List<YouTubeVideoModel>>((ref) async {
  final dio = ref.read(dioProvider);
  final res = await dio.get('/trends/youtube-videos/');
  final list = res.data['results'] as List? ?? res.data as List;
  return list.map((e) => YouTubeVideoModel.fromJson(e as Map<String, dynamic>)).toList();
});

/// Parses human-readable counts like "1.2M", "450K", "3B" → integer.
int _parseCount(String s) {
  final v = s.trim().toUpperCase().replaceAll(',', '');
  if (v.endsWith('B')) return ((double.tryParse(v.replaceAll('B', '')) ?? 0) * 1e9).toInt();
  if (v.endsWith('M')) return ((double.tryParse(v.replaceAll('M', '')) ?? 0) * 1e6).toInt();
  if (v.endsWith('K')) return ((double.tryParse(v.replaceAll('K', '')) ?? 0) * 1e3).toInt();
  return int.tryParse(v) ?? 0;
}

/// Computes a TikTok Algo Score (0–100) based on the like/view ratio and
/// view volume tier — mirrors the key signals TikTok weights most heavily.
int _algoScore(String views, String likes) {
  final v = _parseCount(views);
  final l = _parseCount(likes);
  if (v <= 0) return 0;
  final ratio = l / v;
  // Like/view ratio score — 10 %+ gives the maximum 50 pts
  final ratioScore = (ratio * 500).clamp(0.0, 50.0).round();
  // Volume tier score (max 30 pts) — rewards proven reach
  final volumeScore = v >= 10000000 ? 30
      : v >= 5000000  ? 25
      : v >= 1000000  ? 20
      : v >= 500000   ? 15
      : v >= 100000   ? 10
      : v >= 10000    ? 5
      : 0;
  // Engagement quality bonus (max 20 pts)
  final engBonus = ratio >= 0.10 ? 20 : ratio >= 0.05 ? 14 : ratio >= 0.02 ? 7 : 0;
  return (ratioScore + volumeScore + engBonus).clamp(0, 100);
}

/// Returns a momentum label and color for a pill badge.
/// Pass [growth] for hashtag trend cards, or [viewCount] for TikTok video cards.
({String label, Color color}) _momentumBadge({double? growth, int? viewCount}) {
  if (growth != null) {
    if (growth >= 50) return (label: '🔥 Hot',        color: Colors.orange);
    if (growth >= 20) return (label: '📈 Rising',     color: AppColors.success);
    if (growth >= 0)  return (label: '➡ Steady',     color: AppColors.textMuted);
    return             (label: '📉 Declining',         color: AppColors.error);
  }
  final v = viewCount ?? 0;
  if (v >= 1000000) return (label: '🔥 Hot',    color: Colors.orange);
  if (v >= 100000)  return (label: '📈 Rising', color: AppColors.success);
  return              (label: '➡ Steady',       color: AppColors.textMuted);
}

class TrendsListScreen extends ConsumerStatefulWidget {
  const TrendsListScreen({super.key});
  @override
  ConsumerState<TrendsListScreen> createState() => _TrendsListState();
}

class _TrendsListState extends ConsumerState<TrendsListScreen> {
  String _platform = 'All';
  String _sort = 'views';
  String _niche = '';
  final _scrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    _initNiche();
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _initNiche() async {
    final niches = await ref.read(secureStorageProvider).readCreatorNiches();
    if (niches.isNotEmpty && mounted) {
      setState(() => _niche = niches.first);
    }
  }

  final _platforms = ['All', 'TikTok', 'Instagram', 'YouTube', 'Facebook'];
  final _sortOptions = [
    ('Views', 'views'),
    ('Likes', 'likes'),
    ('Algo',  'algo'),
    ('Date',  'recent'),
  ];
  final _niches = [
    ('All',        ''),
    ('Comedy',     'comedy'),
    ('Beauty',     'beauty'),
    ('Fitness',    'fitness'),
    ('Food',       'food'),
    ('Finance',    'finance'),
    ('Tech',       'tech'),
    ('Fashion',    'fashion'),
    ('Music',      'music'),
    ('Gaming',     'gaming'),
    ('Education',  'education'),
  ];

  @override
  Widget build(BuildContext context) {
    final params = <String, String>{'sort': _sort};
    if (_platform != 'All') params['platform'] = _platform;
    if (_niche.isNotEmpty) params['niche'] = _niche;
    final trendsAsync = ref.watch(_allTrendsProvider(params));

    return Scaffold(
      body: Stack(
        children: [
          const AnimatedParticleBackground(),
          Column(
            children: [
              const TrendAIAppBar(title: 'Trending Now', subtitle: 'Real-time • Multi-platform'),

              // Platform filter chips
              SizedBox(
                height: 52,
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  scrollDirection: Axis.horizontal,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemCount: _platforms.length,
                  itemBuilder: (_, i) {
                    final active = _platforms[i] == _platform;
                    return GestureDetector(
                      onTap: () => setState(() => _platform = _platforms[i]),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        decoration: BoxDecoration(
                          gradient: active ? AppColors.gradientPrimary : null,
                          color: active ? null : Colors.white.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white.withValues(alpha: active ? 0 : 0.12)),
                        ),
                        child: Text(_platforms[i],
                            style: TextStyle(
                              color: active ? Colors.white : AppColors.textMuted,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            )),
                      ),
                    );
                  },
                ),
              ),

              // Sort
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                child: Row(
                  children: [
                    const Icon(Icons.filter_list_rounded, color: AppColors.primary, size: 18),
                    const SizedBox(width: 8),
                    const Text('Sort by', style: TextStyle(fontWeight: FontWeight.w600)),
                    const Spacer(),
                    ..._sortOptions.map((opt) {
                      final (label, value) = opt;
                      final active = value == _sort;
                      return GestureDetector(
                        onTap: () => setState(() => _sort = value),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                          margin: const EdgeInsets.only(left: 6),
                          decoration: BoxDecoration(
                            gradient: active ? AppColors.gradientPrimary : null,
                            color: active ? null : Colors.white.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(label,
                              style: TextStyle(
                                color: active ? Colors.white : AppColors.textMuted,
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              )),
                        ),
                      );
                    }),
                  ],
                ),
              ),

              // Niche filter chips (only shown for TikTok/All)
              if (_platform == 'TikTok' || _platform == 'All')
                SizedBox(
                  height: 40,
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    scrollDirection: Axis.horizontal,
                    separatorBuilder: (_, __) => const SizedBox(width: 6),
                    itemCount: _niches.length,
                    itemBuilder: (_, i) {
                      final (label, value) = _niches[i];
                      final active = value == _niche;
                      return GestureDetector(
                        onTap: () => setState(() => _niche = value),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                          decoration: BoxDecoration(
                            color: active
                                ? AppColors.tikTok.withValues(alpha: 0.25)
                                : Colors.white.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: active
                                  ? AppColors.tikTok.withValues(alpha: 0.6)
                                  : Colors.white.withValues(alpha: 0.08),
                            ),
                          ),
                          child: Text(label,
                              style: TextStyle(
                                color: active ? AppColors.tikTok : AppColors.textMuted,
                                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                                fontSize: 12,
                              )),
                        ),
                      );
                    },
                  ),
                ),
              if (_platform == 'TikTok' || _platform == 'All')
                const SizedBox(height: 8),

              // Trends list
              Expanded(
                child: ListView(
                  controller: _scrollCtrl,
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 100),
                  children: [
                    if (_platform == 'All') ...[
                      _AllPlatformsMixedSection(sort: _sort, niche: _niche),
                      const SizedBox(height: 20),
                    ],
                    if (_platform == 'TikTok') ...[
                      _TikTokVideosSection(sort: _sort, niche: _niche),
                      const SizedBox(height: 20),
                    ],
                    if (_platform == 'Instagram') ...[
                      _InstagramTrendsSection(sort: _sort),
                      const SizedBox(height: 20),
                    ],
                    if (_platform == 'YouTube') ...[
                      _YouTubeTrendsSection(sort: _sort),
                      const SizedBox(height: 20),
                    ],
                    if (_platform == 'Facebook') ...[
                      _FacebookTrendsSection(sort: _sort),
                      const SizedBox(height: 20),
                    ],
                    if (_platform == 'TikTok' || _platform == 'All') ...[
                      Text('Trending Hashtags',
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              color: AppColors.textMuted, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 12),
                    ],
                    ...trendsAsync.when(
                      data: (trends) {
                        // Client-side niche filter — runs whether or not backend honours the param
                        final filtered = _niche.isEmpty
                            ? trends
                            : () {
                                final keywords = nicheKeywords[_niche.toLowerCase()] ?? [_niche.toLowerCase()];
                                final result = trends.where((t) {
                                  final haystack = t.hashtag.toLowerCase();
                                  return keywords.any((kw) => haystack.contains(kw));
                                }).toList();
                                return result.isNotEmpty ? result : trends;
                              }();
                        return filtered.asMap().entries.map((e) => Padding(
                          padding: EdgeInsets.only(bottom: e.key < filtered.length - 1 ? 12 : 0),
                          child: _TrendCard(trend: e.value),
                        )).toList();
                      },
                      loading: () => [const Center(child: CircularProgressIndicator())],
                      error: (err, _) => [Center(child: Text(err.toString(), style: const TextStyle(color: AppColors.textMuted)))],
                    ),
                  ],
                ),
              ),
            ],
          ),
          Positioned(
            left: 0, right: 0, bottom: 0,
            child: TrendAIBottomNav(currentIndex: 1, scrollController: _scrollCtrl),
          ),
        ],
      ),
    );
  }
}

// ── All Platforms Mixed Section ──────────────────────────────────────────────

/// A unified item for the mixed "All" grid.
class _MixedVideo {
  final String platform; // tiktok, instagram, youtube, facebook
  final String title;
  final String thumbnailUrl;
  final String author;
  final int views;
  final String viewsLabel;
  final String likes;
  final String category;
  final String videoId;
  final String externalUrl;
  final List<String> hashtags;

  const _MixedVideo({
    required this.platform,
    required this.title,
    required this.thumbnailUrl,
    this.author = '',
    this.views = 0,
    this.viewsLabel = '',
    this.likes = '',
    this.category = '',
    this.videoId = '',
    this.externalUrl = '',
    this.hashtags = const [],
  });
}

final _allPlatformsMixedProvider = FutureProvider<List<_MixedVideo>>((ref) async {
  final dio = ref.read(dioProvider);
  final results = <_MixedVideo>[];

  // Fetch all in parallel
  final futures = await Future.wait([
    ref.read(tiktokVideosProvider('').future).then<List<_MixedVideo>>((vids) =>
      vids.map((v) => _MixedVideo(
        platform: 'tiktok',
        title: v.title,
        thumbnailUrl: v.thumbnailUrl,
        author: v.author,
        views: _parseCount(v.views),
        viewsLabel: v.views,
        likes: v.likes,
        category: v.niche,
        videoId: v.videoId,
        externalUrl: v.tiktokUrl,
        hashtags: v.hashtags,
      )).toList(),
    ).catchError((_) => <_MixedVideo>[]),
    dio.get('/n8n/trending_videos/').then<List<_MixedVideo>>((res) {
      final list = res.data['results'] as List? ?? res.data as List;
      return list.cast<Map<String, dynamic>>().map((j) => _MixedVideo(
        platform: 'instagram',
        title: j['title'] as String? ?? 'Instagram Reel',
        thumbnailUrl: j['thumbnail_url'] as String? ?? '',
        author: j['author'] as String? ?? '',
        views: _parseCount(j['views'] as String? ?? '0'),
        viewsLabel: j['views'] as String? ?? '',
        likes: j['likes'] as String? ?? '',
        category: j['category'] as String? ?? 'Instagram',
        videoId: j['video_id'] as String? ?? '',
        externalUrl: j['tiktok_url'] as String? ?? '',
      )).toList();
    }).catchError((_) => <_MixedVideo>[]),
    dio.get('/trends/youtube-videos/').then<List<_MixedVideo>>((res) {
      final list = res.data['results'] as List? ?? res.data as List;
      return list.cast<Map<String, dynamic>>().map((j) {
        final yt = YouTubeVideoModel.fromJson(j);
        return _MixedVideo(
          platform: 'youtube',
          title: yt.titre ?? 'YouTube Video',
          thumbnailUrl: 'https://img.youtube.com/vi/${yt.videoId}/hqdefault.jpg',
          views: yt.vues,
          viewsLabel: _formatCount(yt.vues),
          category: yt.niche ?? 'YouTube',
          videoId: yt.videoId,
          externalUrl: 'https://www.youtube.com/watch?v=${yt.videoId}',
        );
      }).toList();
    }).catchError((_) => <_MixedVideo>[]),
    dio.get('/trends/reels/').then<List<_MixedVideo>>((res) {
      final list = res.data['results'] as List? ?? res.data as List;
      return list.cast<Map<String, dynamic>>().map((j) {
        final fb = FacebookReelModel.fromJson(j);
        return _MixedVideo(
          platform: 'facebook',
          title: (fb.text != null && fb.text!.isNotEmpty) ? fb.text! : 'Facebook Reel',
          thumbnailUrl: fb.thumbnailUrl ?? '',
          views: fb.playCount,
          viewsLabel: _formatCount(fb.playCount),
          category: fb.niche ?? 'Facebook',
          videoId: fb.reelId,
          externalUrl: fb.reelUrl ?? '',
        );
      }).toList();
    }).catchError((_) => <_MixedVideo>[]),
  ]);

  // Round-robin interleave: pick 1 from each platform in turn
  final buckets = futures.toList();
  final maxLen = buckets.fold<int>(0, (m, b) => b.length > m ? b.length : m);
  for (var i = 0; i < maxLen; i++) {
    for (final bucket in buckets) {
      if (i < bucket.length) results.add(bucket[i]);
    }
  }
  return results;
});

class _AllPlatformsMixedSection extends ConsumerWidget {
  const _AllPlatformsMixedSection({required this.sort, required this.niche});
  final String sort;
  final String niche;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_allPlatformsMixedProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          const Icon(Icons.local_fire_department_rounded, color: AppColors.primary, size: 18),
          const SizedBox(width: 6),
          Text('Trending Across All Platforms',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
        ]),
        const SizedBox(height: 12),
        async.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (_, __) => const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: Text('Could not load videos', style: TextStyle(color: AppColors.textMuted))),
          ),
          data: (videos) {
            if (videos.isEmpty) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(child: Text('No trending videos found', style: TextStyle(color: AppColors.textMuted))),
              );
            }
            final sorted = [...videos];
            if (sort == 'views') {
              sorted.sort((a, b) => b.views.compareTo(a.views));
            } else if (sort == 'likes') {
              sorted.sort((a, b) => _parseCount(b.likes).compareTo(_parseCount(a.likes)));
            }
            // 'recent' keeps API order
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 9 / 16,
              ),
              itemCount: sorted.length,
              itemBuilder: (_, i) => _MixedVideoCard(video: sorted[i]),
            );
          },
        ),
      ],
    );
  }
}

class _MixedVideoCard extends StatelessWidget {
  const _MixedVideoCard({required this.video});
  final _MixedVideo video;

  static const _platformColors = {
    'tiktok': AppColors.tikTok,
    'instagram': Color(0xFFDD2A7B),
    'youtube': Color(0xFFFF0000),
    'facebook': Color(0xFF1877F2),
  };

  static const _platformIcons = {
    'tiktok': Icons.music_note_rounded,
    'instagram': Icons.camera_alt_rounded,
    'youtube': Icons.play_circle_filled_rounded,
    'facebook': Icons.facebook_rounded,
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
                      child: Center(child: Icon(_platformIcons[video.platform] ?? Icons.play_circle_outline_rounded, color: color, size: 40)),
                    ))
                : Container(
                    color: color.withValues(alpha: 0.10),
                    child: Center(child: Icon(_platformIcons[video.platform] ?? Icons.play_circle_outline_rounded, color: color, size: 40)),
                  ),
            Positioned(
              bottom: 0, left: 0, right: 0,
              child: Container(
                height: 160,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter, end: Alignment.topCenter,
                    colors: [Colors.black.withValues(alpha: 0.85), Colors.transparent],
                  ),
                ),
              ),
            ),
            Center(
              child: Container(
                width: 40, height: 40,
                decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.4), shape: BoxShape.circle),
                child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 26),
              ),
            ),
            // Platform badge — top left
            Positioned(
              top: 8, left: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(_platformIcons[video.platform] ?? Icons.play_circle_outline_rounded, color: Colors.white, size: 10),
                    const SizedBox(width: 3),
                    Text(label, style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w700, color: Colors.white)),
                  ],
                ),
              ),
            ),
            if (video.externalUrl.isNotEmpty)
              Positioned(
                top: 8, right: 8,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.4), borderRadius: BorderRadius.circular(6)),
                  child: const Icon(Icons.open_in_new_rounded, size: 13, color: Colors.white),
                ),
              ),
            Positioned(
              bottom: 0, left: 0, right: 0,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (video.author.isNotEmpty)
                      Text('@${video.author}',
                          style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w700),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 3),
                    Text(video.title,
                        maxLines: 2, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white, height: 1.3)),
                    if (video.viewsLabel.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Row(children: [
                        const Icon(Icons.play_arrow_rounded, size: 12, color: Colors.white70),
                        const SizedBox(width: 2),
                        Text(video.viewsLabel, style: const TextStyle(fontSize: 10, color: Colors.white70)),
                      ]),
                    ],
                    const SizedBox(height: 5),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(color: color.withValues(alpha: 0.25), borderRadius: BorderRadius.circular(4)),
                      child: Text(video.category, style: const TextStyle(fontSize: 9, color: Colors.white), maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
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

// ── TikTok Trending Videos Section ──────────────────────────────────────────

class _TikTokVideosSection extends ConsumerWidget {
  const _TikTokVideosSection({required this.sort, required this.niche});
  final String sort;
  final String niche;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final videosAsync = ref.watch(tiktokVideosProvider(niche));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          const Icon(Icons.local_fire_department_rounded, color: AppColors.tikTok, size: 18),
          const SizedBox(width: 6),
          Text('Trending TikTok Videos',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
        ]),
        const SizedBox(height: 12),
        videosAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (_, __) => const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: Text('Could not load videos', style: TextStyle(color: AppColors.textMuted))),
          ),
          data: (videos) {
            if (videos.isEmpty) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(child: Text('No trending videos found', style: TextStyle(color: AppColors.textMuted))),
              );
            }
            // Client-side sort
            final sorted = [...videos];
            if (sort == 'views') {
              sorted.sort((a, b) => _parseCount(b.views).compareTo(_parseCount(a.views)));
            } else if (sort == 'likes') {
              sorted.sort((a, b) => _parseCount(b.likes).compareTo(_parseCount(a.likes)));
            } else if (sort == 'algo') {
              sorted.sort((a, b) => _algoScore(b.views, b.likes).compareTo(_algoScore(a.views, a.likes)));
            }
            // 'recent' keeps API order (most recently trending first)

            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 9 / 16,
              ),
              itemCount: sorted.length,
              itemBuilder: (_, i) => _TikTokVideoCard(video: sorted[i]),
            );
          },
        ),
      ],
    );
  }
}

class _TikTokVideoCard extends StatelessWidget {
  const _TikTokVideoCard({required this.video});
  final TrendingVideoModel video;

  @override
  Widget build(BuildContext context) {
    final score = _algoScore(video.views, video.likes);
    final scoreColor = score >= 70
        ? Colors.orange
        : score >= 45
            ? AppColors.success
            : AppColors.textMuted;
    final v = _parseCount(video.views);
    final l = _parseCount(video.likes);
    final engRate = v > 0 ? (l / v * 100).toStringAsFixed(1) : '0.0';

    return GestureDetector(
      onTap: () => context.push(
        '/ai-generator'
        '?niche=${Uri.encodeComponent(video.niche.isNotEmpty ? video.niche : video.title)}'
        '&selectedVideoId=${video.videoId}'
        '&platform=tiktok',
      ),
      onLongPress: video.tiktokUrl.isNotEmpty
          ? () => launchUrl(Uri.parse(video.tiktokUrl), mode: LaunchMode.externalApplication)
          : null,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: Colors.white.withValues(alpha: 0.05),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        clipBehavior: Clip.hardEdge,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Thumbnail — full bleed
            video.thumbnailUrl.isNotEmpty
                ? Image.network(
                    video.thumbnailUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _placeholder(),
                  )
                : _placeholder(),

            // Gradient overlay — bottom 45%
            Positioned(
              bottom: 0, left: 0, right: 0,
              child: Container(
                height: 160,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.85),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),

            // Play icon — center
            Center(
              child: Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.4),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 26),
              ),
            ),

            // Algo Score badge — top left
            Positioned(
              top: 8, left: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: scoreColor.withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '⚡$score',
                  style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Colors.white),
                ),
              ),
            ),

            // Open-in-new icon — top right (long-press hint)
            if (video.tiktokUrl.isNotEmpty)
              Positioned(
                top: 8, right: 8,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(Icons.open_in_new_rounded, size: 13, color: Colors.white),
                ),
              ),

            // Info — bottom overlay
            Positioned(
              bottom: 0, left: 0, right: 0,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (video.author.isNotEmpty)
                      Text(
                        '@${video.author}',
                        style: const TextStyle(
                          fontSize: 10,
                          color: AppColors.tikTok,
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    const SizedBox(height: 4),
                    Builder(builder: (_) {
                      final badge = _momentumBadge(viewCount: _parseCount(video.views));
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: badge.color.withValues(alpha: 0.20),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: badge.color.withValues(alpha: 0.50)),
                        ),
                        child: Text(
                          badge.label,
                          style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: badge.color),
                        ),
                      );
                    }),
                    const SizedBox(height: 3),
                    Text(
                      video.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(children: [
                      const Icon(Icons.play_arrow_rounded, size: 12, color: Colors.white70),
                      const SizedBox(width: 2),
                      Text(video.views,
                          style: const TextStyle(fontSize: 10, color: Colors.white70)),
                      const SizedBox(width: 10),
                      const Icon(Icons.favorite_rounded, size: 12, color: AppColors.tikTok),
                      const SizedBox(width: 2),
                      Text(video.likes,
                          style: const TextStyle(fontSize: 10, color: Colors.white70)),
                      const SizedBox(width: 8),
                      Text('$engRate% ER',
                          style: TextStyle(fontSize: 9, color: AppColors.tikTok.withValues(alpha: 0.85), fontWeight: FontWeight.w600)),
                    ]),
                    if (video.hashtags.isNotEmpty) ...[
                      const SizedBox(height: 5),
                      Wrap(
                        spacing: 4,
                        runSpacing: 3,
                        children: video.hashtags.take(2).map((tag) => Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.25),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(tag,
                              style: const TextStyle(fontSize: 9, color: Colors.white)),
                        )).toList(),
                      ),
                    ],
                    const SizedBox(height: 6),
                    // "Use as inspiration" CTA
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 5),
                      decoration: BoxDecoration(
                        color: AppColors.tikTok.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppColors.tikTok.withValues(alpha: 0.5)),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.auto_awesome, size: 10, color: AppColors.tikTok),
                          SizedBox(width: 4),
                          Text('Use as Inspiration',
                              style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: AppColors.tikTok)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeholder() => Container(
    color: AppColors.tikTok.withValues(alpha: 0.1),
    child: const Center(
      child: Icon(Icons.play_circle_outline_rounded, color: AppColors.tikTok, size: 40),
    ),
  );
}

class _TrendCard extends StatelessWidget {
  const _TrendCard({required this.trend});
  final TrendModel trend;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.go('/trend/${trend.id}'),
      child: GlassCard(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        TrendTypeIcon(type: trend.type),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(trend.hashtag,
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                        ),
                      ]),
                      const SizedBox(height: 8),
                      Row(children: [
                        PlatformBadge(platform: trend.platform),
                        const SizedBox(width: 8),
                        const Icon(Icons.play_arrow_rounded, size: 13, color: AppColors.textMuted),
                        const SizedBox(width: 3),
                        Text('${trend.views} views',
                            style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                        const SizedBox(width: 10),
                        const Icon(Icons.favorite_rounded, size: 13, color: AppColors.tikTok),
                        const SizedBox(width: 3),
                        Text('${trend.totalLikes}',
                            style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                      ]),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.arrow_upward_rounded, color: AppColors.success, size: 16),
                        Text('${trend.growth.toInt()}%',
                            style: const TextStyle(color: AppColors.success, fontWeight: FontWeight.w700)),
                      ],
                    ),
                    const Text('Growth', style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
                    const SizedBox(height: 6),
                    Builder(builder: (_) {
                      final badge = _momentumBadge(growth: trend.growth);
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: badge.color.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: badge.color.withValues(alpha: 0.45)),
                        ),
                        child: Text(
                          badge.label,
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: badge.color),
                        ),
                      );
                    }),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Text('Trend Score', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                const Spacer(),
                GradientText('${trend.score.toInt()}%',
                    style: const TextStyle(fontWeight: FontWeight.w700)),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: trend.score / 100,
                backgroundColor: Colors.white.withValues(alpha: 0.06),
                valueColor: const AlwaysStoppedAnimation(AppColors.primary),
                minHeight: 6,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Shared count formatter ───────────────────────────────────────────────────

String _formatCount(int count) {
  if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)}M';
  if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}K';
  return count.toString();
}

// ── Instagram Trends Section ─────────────────────────────────────────────────

class _InstagramTrendsSection extends ConsumerWidget {
  const _InstagramTrendsSection({required this.sort});
  final String sort;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_instagramTrendsVideosProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          const Icon(Icons.local_fire_department_rounded, color: Color(0xFFE1306C), size: 18),
          const SizedBox(width: 6),
          Text('Trending Instagram Reels',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
        ]),
        const SizedBox(height: 12),
        async.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (_, __) => const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: Text('Could not load reels', style: TextStyle(color: AppColors.textMuted))),
          ),
          data: (videos) {
            if (videos.isEmpty) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(child: Text('No Instagram reels found', style: TextStyle(color: AppColors.textMuted))),
              );
            }
            final sorted = [...videos];
            if (sort == 'views') {
              sorted.sort((a, b) => _parseCount(b['views'] as String? ?? '0').compareTo(_parseCount(a['views'] as String? ?? '0')));
            } else if (sort == 'likes') {
              sorted.sort((a, b) => _parseCount(b['likes'] as String? ?? '0').compareTo(_parseCount(a['likes'] as String? ?? '0')));
            }
            // 'recent' keeps API order
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 9 / 16,
              ),
              itemCount: sorted.length,
              itemBuilder: (_, i) => _InstagramTrendCard(video: sorted[i]),
            );
          },
        ),
      ],
    );
  }
}

class _InstagramTrendCard extends StatelessWidget {
  const _InstagramTrendCard({required this.video});
  final Map<String, dynamic> video;

  @override
  Widget build(BuildContext context) {
    final title = video['title'] as String? ?? 'Instagram Reel';
    final vid = video['video_id'] as String? ?? '';
    final category = video['category'] as String? ?? 'Instagram';
    final thumbnailUrl = video['thumbnail_url'] as String? ?? '';

    return GestureDetector(
      onTap: () => context.push(
        '/ai-generator?niche=${Uri.encodeComponent(title)}&selectedVideoId=$vid&platform=instagram',
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: Colors.white.withValues(alpha: 0.05),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        clipBehavior: Clip.hardEdge,
        child: Stack(
          fit: StackFit.expand,
          children: [
            thumbnailUrl.isNotEmpty
                ? Image.network(
                    thumbnailUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFFF58529), Color(0xFFDD2A7B), Color(0xFF8134AF)],
                        ),
                      ),
                      child: const Center(
                        child: Icon(Icons.camera_alt_rounded, color: Colors.white38, size: 40),
                      ),
                    ),
                  )
                : Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFFF58529), Color(0xFFDD2A7B), Color(0xFF8134AF)],
                      ),
                    ),
                    child: const Center(
                      child: Icon(Icons.camera_alt_rounded, color: Colors.white38, size: 40),
                    ),
                  ),
            Positioned(
              bottom: 0, left: 0, right: 0,
              child: Container(
                height: 160,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [Colors.black.withValues(alpha: 0.85), Colors.transparent],
                  ),
                ),
              ),
            ),
            Center(
              child: Container(
                width: 40, height: 40,
                decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.4), shape: BoxShape.circle),
                child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 26),
              ),
            ),
            Positioned(
              bottom: 0, left: 0, right: 0,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.20),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.orange.withValues(alpha: 0.50)),
                      ),
                      child: const Text('🔥 Trending',
                          style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Colors.orange)),
                    ),
                    const SizedBox(height: 3),
                    Text(title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white, height: 1.3)),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDD2A7B).withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(category,
                          style: const TextStyle(fontSize: 9, color: Colors.white),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    ),
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

// ── YouTube Trends Section ───────────────────────────────────────────────────

class _YouTubeTrendsSection extends ConsumerWidget {
  const _YouTubeTrendsSection({required this.sort});
  final String sort;

  static const _ytRed = Color(0xFFFF0000);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_youtubeTrendsVideosProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          const Icon(Icons.local_fire_department_rounded, color: _ytRed, size: 18),
          const SizedBox(width: 6),
          Text('Trending YouTube Videos',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
        ]),
        const SizedBox(height: 12),
        async.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (_, __) => const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: Text('Could not load videos', style: TextStyle(color: AppColors.textMuted))),
          ),
          data: (videos) {
            if (videos.isEmpty) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(child: Text('No YouTube videos found', style: TextStyle(color: AppColors.textMuted))),
              );
            }
            final sorted = [...videos];
            if (sort == 'views') {
              sorted.sort((a, b) => b.vues.compareTo(a.vues));
            } else if (sort == 'recent') {
              sorted.sort((a, b) => (b.scrapedAt ?? '').compareTo(a.scrapedAt ?? ''));
            }
            // no likes field on YouTube model — 'likes' keeps API order
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 9 / 16,
              ),
              itemCount: sorted.length,
              itemBuilder: (_, i) => _YouTubeTrendCard(video: sorted[i]),
            );
          },
        ),
      ],
    );
  }
}

class _YouTubeTrendCard extends StatelessWidget {
  const _YouTubeTrendCard({required this.video});
  final YouTubeVideoModel video;

  static const _ytRed = Color(0xFFFF0000);

  ({String label, Color color}) _badge(int views) {
    if (views >= 1000000) return (label: '🔥 Hot',    color: Colors.orange);
    if (views >= 100000)  return (label: '📈 Rising', color: AppColors.success);
    return                       (label: '➡ Steady',  color: AppColors.textMuted);
  }

  List<String> _parseTags(String? tags) {
    if (tags == null || tags.isEmpty) return [];
    return tags.split(RegExp(r'[,\s]+')).map((t) => t.trim()).where((t) => t.isNotEmpty).toList();
  }

  @override
  Widget build(BuildContext context) {
    final thumbnailUrl = 'https://img.youtube.com/vi/${video.videoId}/hqdefault.jpg';
    final title = video.titre ?? 'YouTube Video';
    final niche = video.niche ?? 'YouTube';
    final badge = _badge(video.vues);
    final tags = _parseTags(video.tags);

    return GestureDetector(
      onTap: () => launchUrl(
        Uri.parse('https://www.youtube.com/watch?v=${video.videoId}'),
        mode: LaunchMode.externalApplication,
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: Colors.white.withValues(alpha: 0.05),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        clipBehavior: Clip.hardEdge,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.network(thumbnailUrl, fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  color: _ytRed.withValues(alpha: 0.10),
                  child: const Center(child: Icon(Icons.play_circle_outline_rounded, color: _ytRed, size: 40)),
                )),
            Positioned(
              bottom: 0, left: 0, right: 0,
              child: Container(
                height: 160,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter, end: Alignment.topCenter,
                    colors: [Colors.black.withValues(alpha: 0.85), Colors.transparent],
                  ),
                ),
              ),
            ),
            Center(
              child: Container(
                width: 40, height: 40,
                decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.4), shape: BoxShape.circle),
                child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 26),
              ),
            ),
            Positioned(
              top: 8, right: 8,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.4), borderRadius: BorderRadius.circular(6)),
                child: const Icon(Icons.open_in_new_rounded, size: 13, color: Colors.white),
              ),
            ),
            Positioned(
              bottom: 0, left: 0, right: 0,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: badge.color.withValues(alpha: 0.20),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: badge.color.withValues(alpha: 0.50)),
                      ),
                      child: Text(badge.label,
                          style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: badge.color)),
                    ),
                    const SizedBox(height: 3),
                    Text(title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white, height: 1.3)),
                    if (video.vues > 0) ...[
                      const SizedBox(height: 6),
                      Row(children: [
                        const Icon(Icons.play_arrow_rounded, size: 12, color: Colors.white70),
                        const SizedBox(width: 2),
                        Text(_formatCount(video.vues), style: const TextStyle(fontSize: 10, color: Colors.white70)),
                      ]),
                    ],
                    const SizedBox(height: 5),
                    Wrap(
                      spacing: 4, runSpacing: 3,
                      children: (tags.isNotEmpty ? tags.take(2).toList() : [niche]).map((tag) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: _ytRed.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(tag, style: const TextStyle(fontSize: 9, color: Colors.white)),
                      )).toList(),
                    ),
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

// ── Facebook Trends Section ──────────────────────────────────────────────────

class _FacebookTrendsSection extends ConsumerWidget {
  const _FacebookTrendsSection({required this.sort});
  final String sort;

  static const _fbBlue = Color(0xFF1877F2);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_facebookTrendsReelsProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          const Icon(Icons.local_fire_department_rounded, color: _fbBlue, size: 18),
          const SizedBox(width: 6),
          Text('Trending Facebook Reels',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
        ]),
        const SizedBox(height: 12),
        async.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (_, __) => const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: Text('Could not load reels', style: TextStyle(color: AppColors.textMuted))),
          ),
          data: (reels) {
            if (reels.isEmpty) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(child: Text('No Facebook reels found', style: TextStyle(color: AppColors.textMuted))),
              );
            }
            final sorted = [...reels];
            if (sort == 'views') {
              sorted.sort((a, b) => b.playCount.compareTo(a.playCount));
            } else if (sort == 'recent') {
              sorted.sort((a, b) => (b.createdAt ?? '').compareTo(a.createdAt ?? ''));
            }
            // no likes field on Facebook model — 'likes' keeps API order
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 9 / 16,
              ),
              itemCount: sorted.length,
              itemBuilder: (_, i) => _FacebookTrendCard(reel: sorted[i]),
            );
          },
        ),
      ],
    );
  }
}

class _FacebookTrendCard extends StatelessWidget {
  const _FacebookTrendCard({required this.reel});
  final FacebookReelModel reel;

  static const _fbBlue = Color(0xFF1877F2);

  ({String label, Color color}) _badge(int views) {
    if (views >= 1000000) return (label: '🔥 Hot',    color: Colors.orange);
    if (views >= 100000)  return (label: '📈 Rising', color: AppColors.success);
    return                       (label: '➡ Steady',  color: AppColors.textMuted);
  }

  String _pageNameFromUrl(String? url) {
    if (url == null || url.isEmpty) return 'Facebook';
    final parts = url.replaceAll(RegExp(r'\?.*'), '').split('/').where((s) => s.isNotEmpty).toList();
    return parts.isNotEmpty ? parts.last : 'Facebook';
  }

  @override
  Widget build(BuildContext context) {
    final hasThumb = reel.thumbnailUrl != null && reel.thumbnailUrl!.isNotEmpty;
    final hasUrl = reel.reelUrl != null && reel.reelUrl!.isNotEmpty;
    final pageName = _pageNameFromUrl(reel.pageUrl);
    final rawText = reel.text ?? '';
    final title = rawText.isNotEmpty ? rawText : pageName;
    final niche = (reel.niche != null && reel.niche!.isNotEmpty) ? reel.niche! : 'facebook';
    final badge = _badge(reel.playCount);

    return GestureDetector(
      onTap: hasUrl
          ? () => launchUrl(Uri.parse(reel.reelUrl!), mode: LaunchMode.externalApplication)
          : () => context.push(
                '/ai-generator?niche=${Uri.encodeComponent(niche)}&selectedVideoId=${reel.reelId}&platform=facebook'),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: Colors.white.withValues(alpha: 0.05),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        clipBehavior: Clip.hardEdge,
        child: Stack(
          fit: StackFit.expand,
          children: [
            hasThumb
                ? Image.network(reel.thumbnailUrl!, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: _fbBlue.withValues(alpha: 0.10),
                      child: const Center(child: Icon(Icons.play_circle_outline_rounded, color: _fbBlue, size: 40)),
                    ))
                : Container(
                    color: _fbBlue.withValues(alpha: 0.10),
                    child: const Center(child: Icon(Icons.play_circle_outline_rounded, color: _fbBlue, size: 40)),
                  ),
            Positioned(
              bottom: 0, left: 0, right: 0,
              child: Container(
                height: 160,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter, end: Alignment.topCenter,
                    colors: [Colors.black.withValues(alpha: 0.85), Colors.transparent],
                  ),
                ),
              ),
            ),
            Center(
              child: Container(
                width: 40, height: 40,
                decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.4), shape: BoxShape.circle),
                child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 26),
              ),
            ),
            if (hasUrl)
              Positioned(
                top: 8, right: 8,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.4), borderRadius: BorderRadius.circular(6)),
                  child: const Icon(Icons.open_in_new_rounded, size: 13, color: Colors.white),
                ),
              ),
            Positioned(
              bottom: 0, left: 0, right: 0,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (pageName.isNotEmpty)
                      Text('@$pageName',
                          style: const TextStyle(fontSize: 10, color: _fbBlue, fontWeight: FontWeight.w700),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: badge.color.withValues(alpha: 0.20),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: badge.color.withValues(alpha: 0.50)),
                      ),
                      child: Text(badge.label,
                          style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: badge.color)),
                    ),
                    const SizedBox(height: 3),
                    Text(title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white, height: 1.3)),
                    if (reel.playCount > 0) ...[
                      const SizedBox(height: 6),
                      Row(children: [
                        const Icon(Icons.play_arrow_rounded, size: 12, color: Colors.white70),
                        const SizedBox(width: 2),
                        Text(_formatCount(reel.playCount), style: const TextStyle(fontSize: 10, color: Colors.white70)),
                      ]),
                    ],
                    const SizedBox(height: 5),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(color: _fbBlue.withValues(alpha: 0.25), borderRadius: BorderRadius.circular(4)),
                      child: Text(niche, style: const TextStyle(fontSize: 9, color: Colors.white), maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
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
