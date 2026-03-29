/// My Videos screen — shows REAL published videos from the user's YouTube channel.
/// Fetches from /analytics/youtube/my-videos/ which calls YouTube Data API v3.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/shared_widgets.dart';

final _myVideosProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final dio = ref.read(dioProvider);
  try {
    final res = await dio.get('/analytics/youtube/my-videos/');
    final data = res.data;
    if (data is Map && data['results'] != null) {
      return List<Map<String, dynamic>>.from(data['results']);
    }
    return [];
  } catch (_) {
    return [];
  }
});

class MyVideosScreen extends ConsumerWidget {
  const MyVideosScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final videosAsync = ref.watch(_myVideosProvider);

    return Scaffold(
      body: Stack(
        children: [
          const AnimatedParticleBackground(),
          Column(
            children: [
              TrendAIAppBar(
                title: 'My Videos',
                subtitle: 'Published on your YouTube channel',
                showBack: true,
                action: IconButton(
                  icon: Icon(Icons.refresh_rounded, color: AppColors.primary, size: 22),
                  onPressed: () => ref.invalidate(_myVideosProvider),
                ),
              ),
              Expanded(
                child: videosAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => _ErrorState(
                    message: 'Failed to load videos: $e',
                    onRetry: () => ref.invalidate(_myVideosProvider),
                  ),
                  data: (videos) {
                    if (videos.isEmpty) {
                      return _EmptyState();
                    }
                    return RefreshIndicator(
                      onRefresh: () async => ref.invalidate(_myVideosProvider),
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                        itemCount: videos.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (_, i) => _VideoCard(video: videos[i]),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Empty state widget
class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.video_library_outlined, size: 48, color: AppColors.primary),
            ),
            const SizedBox(height: 16),
            Text('No published videos found',
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
            const SizedBox(height: 8),
            Text(
              'Connect your YouTube account in the Me screen to see your real published videos.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textMuted, fontSize: 13, height: 1.5),
            ),
            const SizedBox(height: 24),
            GestureDetector(
              onTap: () => context.go('/profile'),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  gradient: AppColors.gradientPrimary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text('Go to Me → Connect YouTube',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Error state widget
class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.wifi_off_rounded, size: 48, color: AppColors.textMuted),
            const SizedBox(height: 12),
            Text('YouTube not connected',
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            const SizedBox(height: 8),
            Text(
              'Connect your YouTube account in the Me screen to see your real videos.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textMuted, fontSize: 13, height: 1.5),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: () => context.go('/profile'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    decoration: BoxDecoration(
                      gradient: AppColors.gradientPrimary,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text('Connect YouTube',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
                  ),
                ),
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: onRetry,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                    ),
                    child: Text('Retry', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700, fontSize: 13)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Real YouTube video card
class _VideoCard extends StatelessWidget {
  const _VideoCard({required this.video});
  final Map<String, dynamic> video;

  String _fmt(dynamic n) {
    final num val = (n is num) ? n : int.tryParse(n?.toString() ?? '0') ?? 0;
    if (val >= 1000000) return '${(val / 1000000).toStringAsFixed(1)}M';
    if (val >= 1000) return '${(val / 1000).toStringAsFixed(1)}K';
    return val.toInt().toString();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final title = video['title'] as String? ?? 'Untitled';
    final thumb = video['thumbnail'] as String?;
    final views = _fmt(video['views']);
    final likes = _fmt(video['likes']);
    final comments = _fmt(video['comments']);
    final publishedAt = video['published_at'] as String? ?? '';
    final tags = (video['tags'] as List?)?.take(3).map((t) => '#$t').join(' ') ?? '';
    final youtubeUrl = video['youtube_url'] as String? ?? '';

    // Parse date
    String dateStr = '';
    if (publishedAt.isNotEmpty) {
      try {
        final dt = DateTime.parse(publishedAt);
        dateStr = '${dt.day}/${dt.month}/${dt.year}';
      } catch (_) {}
    }

    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.grey.shade200,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Thumbnail
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: thumb != null && thumb.isNotEmpty
                  ? Image.network(thumb, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _thumbnailPlaceholder())
                  : _thumbnailPlaceholder(),
            ),
          ),
          // Info
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title
                Text(title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, height: 1.3)),
                if (tags.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(tags,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.w500)),
                ],
                const SizedBox(height: 12),
                // Stats row
                Row(
                  children: [
                    _StatPill(icon: Icons.remove_red_eye_outlined, value: views, color: AppColors.primary),
                    const SizedBox(width: 8),
                    _StatPill(icon: Icons.favorite_outline_rounded, value: likes, color: const Color(0xFFFF4081)),
                    const SizedBox(width: 8),
                    _StatPill(icon: Icons.comment_outlined, value: comments, color: AppColors.accent),
                    const Spacer(),
                    if (dateStr.isNotEmpty)
                      Text(dateStr, style: TextStyle(color: AppColors.textMuted, fontSize: 10)),
                  ],
                ),
                if (youtubeUrl.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  // Status badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6, height: 6,
                          decoration: BoxDecoration(color: AppColors.success, shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 5),
                        Text('Published', style: TextStyle(
                            color: AppColors.success, fontSize: 11, fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _thumbnailPlaceholder() {
    return Container(
      decoration: BoxDecoration(gradient: AppColors.gradientPrimary),
      child: const Center(
        child: Icon(Icons.play_arrow_rounded, color: Colors.white, size: 48),
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  const _StatPill({required this.icon, required this.value, required this.color});
  final IconData icon;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 13, color: color),
      const SizedBox(width: 3),
      Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
    ]);
  }
}
