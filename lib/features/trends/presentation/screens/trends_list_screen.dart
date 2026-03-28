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

/// Parses human-readable counts like "1.2M", "450K", "3B" → integer.
int _parseCount(String s) {
  final v = s.trim().toUpperCase().replaceAll(',', '');
  if (v.endsWith('B')) return ((double.tryParse(v.replaceAll('B', '')) ?? 0) * 1e9).toInt();
  if (v.endsWith('M')) return ((double.tryParse(v.replaceAll('M', '')) ?? 0) * 1e6).toInt();
  if (v.endsWith('K')) return ((double.tryParse(v.replaceAll('K', '')) ?? 0) * 1e3).toInt();
  return int.tryParse(v) ?? 0;
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
                    if (_platform == 'TikTok' || _platform == 'All') ...[
                      _TikTokVideosSection(sort: _sort, niche: _niche),
                      const SizedBox(height: 20),
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
    return GestureDetector(
      onTap: video.tiktokUrl.isNotEmpty
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

            // Open-in-new icon — top right
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
