/// TrendsList screen — filterable/sortable list of viral trends.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../shared/widgets/shared_widgets.dart';
import '../../../auth/data/models.dart';
import 'package:dio/dio.dart';

typedef _TrendsQuery = ({String sort, String? platform});

final _allTrendsProvider =
    FutureProvider.family<List<TrendModel>, _TrendsQuery>(
  (ref, query) async {
    final params = <String, String>{'sort': query.sort};
    if (query.platform != null) {
      params['platform'] = query.platform!;
    }

    final dio = ref.read(dioProvider);
    final res = await dio.get('/trends/', queryParameters: params);
    final list = res.data['results'] as List? ?? res.data as List;
    return list
        .map((e) => TrendModel.fromJson(e as Map<String, dynamic>))
        .toList();
  },
);

class TrendsListScreen extends ConsumerStatefulWidget {
  const TrendsListScreen({super.key});
  @override
  ConsumerState<TrendsListScreen> createState() => _TrendsListState();
}

class _TrendsListState extends ConsumerState<TrendsListScreen> {
  String _platform = 'All';
  String _sort = 'growth';

  final _platforms = ['All', 'TikTok', 'Instagram', 'YouTube', 'Facebook'];
  final _sortOptions = [
    ('Growth', 'growth'),
    ('Popularity', 'score'),
    ('Recent', 'recent'),
  ];

  @override
  Widget build(BuildContext context) {
    final query = (
      sort: _sort,
      platform: _platform == 'All' ? null : _platform,
    );
    final trendsAsync = ref.watch(_allTrendsProvider(query));

    return Scaffold(
      body: Stack(
        children: [
          const AnimatedParticleBackground(),
          Column(
            children: [
              TrendAIAppBar(
                  title: 'Trending Now',
                  subtitle: 'Real-time • Multi-platform'),

              // Platform filter chips
              SizedBox(
                height: 52,
                child: ListView.separated(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  scrollDirection: Axis.horizontal,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemCount: _platforms.length,
                  itemBuilder: (_, i) {
                    final active = _platforms[i] == _platform;
                    return GestureDetector(
                      onTap: () => setState(() => _platform = _platforms[i]),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 6),
                        decoration: BoxDecoration(
                          gradient: active ? AppColors.gradientPrimary : null,
                          color: active
                              ? null
                              : Colors.white.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: Colors.white
                                  .withValues(alpha: active ? 0 : 0.12)),
                        ),
                        child: Text(_platforms[i],
                            style: TextStyle(
                              color:
                                  active ? Colors.white : AppColors.textMuted,
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
                    Icon(Icons.filter_list_rounded,
                        color: AppColors.primary, size: 18),
                    const SizedBox(width: 8),
                    const Text('Sort by',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    const Spacer(),
                    ..._sortOptions.map((opt) {
                      final (label, value) = opt;
                      final active = value == _sort;
                      return GestureDetector(
                        onTap: () => setState(() => _sort = value),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 5),
                          margin: const EdgeInsets.only(left: 6),
                          decoration: BoxDecoration(
                            gradient: active ? AppColors.gradientPrimary : null,
                            color: active
                                ? null
                                : Colors.white.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(label,
                              style: TextStyle(
                                color:
                                    active ? Colors.white : AppColors.textMuted,
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              )),
                        ),
                      );
                    }),
                  ],
                ),
              ),

              // Trends list
              Expanded(
                child: trendsAsync.when(
                  data: (trends) => ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 100),
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemCount: trends.length,
                    itemBuilder: (ctx, i) => _TrendCard(trend: trends[i]),
                  ),
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (err, stack) {
                    debugPrint('Error loading trends: $err');
                    String errorMessage = 'Failed to load trends';
                    if (err is DioException) {
                      errorMessage = err.response?.data?.toString() ??
                          err.message ??
                          'Network error';
                    } else {
                      errorMessage = err.toString();
                    }
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.warning_rounded,
                              size: 60, color: AppColors.error),
                          const SizedBox(height: 12),
                          Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 24.0),
                            child: Text(
                              errorMessage,
                              textAlign: TextAlign.center,
                              style: TextStyle(color: AppColors.textMuted),
                            ),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: () =>
                                ref.invalidate(_allTrendsProvider(query)),
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: const TrendAIBottomNav(currentIndex: 1),
          ),
        ],
      ),
    );
  }
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
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700, fontSize: 15)),
                        ),
                      ]),
                      const SizedBox(height: 8),
                      Row(children: [
                        PlatformBadge(platform: trend.platform),
                        const SizedBox(width: 8),
                        Text('${trend.views} views',
                            style: TextStyle(
                                color: AppColors.textMuted, fontSize: 12)),
                      ]),
                    ],
                  ),
                ),
                Column(
                  children: [
                    Row(
                      children: [
                        Icon(Icons.arrow_upward_rounded,
                            color: AppColors.success, size: 16),
                        Text('${trend.growth.toInt()}%',
                            style: TextStyle(
                                color: AppColors.success,
                                fontWeight: FontWeight.w700)),
                      ],
                    ),
                    Text('Growth',
                        style: TextStyle(
                            color: AppColors.textMuted, fontSize: 11)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Text('Trend Score',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
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
                valueColor: AlwaysStoppedAnimation(AppColors.primary),
                minHeight: 6,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
