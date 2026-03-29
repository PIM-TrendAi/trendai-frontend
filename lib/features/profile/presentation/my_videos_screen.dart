/// My Videos screen — lists all videos generated & posted on Facebook.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../shared/widgets/shared_widgets.dart';

final _myVideosProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final res = await ref.read(dioProvider).get('/scripts/videos/');
  final dynamic data = res.data;
  final List raw = data is List ? data : (data['results'] ?? []);
  return raw.cast<Map<String, dynamic>>();
});

class MyVideosScreen extends ConsumerWidget {
  const MyVideosScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final videosAsync = ref.watch(_myVideosProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Stack(
        children: [
          if (isDark) const AnimatedParticleBackground(),
          Column(
            children: [
              // ── AppBar
              SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios_rounded),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      Expanded(
                        child: Column(
                          children: [
                            const Text(
                              'My Videos',
                              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.auto_awesome, size: 12, color: AppColors.primary),
                                const SizedBox(width: 4),
                                Text(
                                  'Your generated content',
                                  style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.refresh_rounded),
                        onPressed: () => ref.invalidate(_myVideosProvider),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),

              // ── Video list
              Expanded(
                child: videosAsync.when(
                  data: (videos) {
                    if (videos.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.video_library_outlined, size: 64, color: AppColors.textMuted),
                            const SizedBox(height: 16),
                            Text(
                              'No videos yet.\nGenerate your first video in AI Gen!',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: AppColors.textMuted, fontSize: 15),
                            ),
                          ],
                        ),
                      );
                    }
                    return ListView.separated(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
                      separatorBuilder: (_, __) => const SizedBox(height: 16),
                      itemCount: videos.length,
                      itemBuilder: (ctx, i) => _VideoCard(video: videos[i]),
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(
                    child: Text('Failed to load videos', style: TextStyle(color: AppColors.error)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _VideoCard extends StatelessWidget {
  const _VideoCard({required this.video});
  final Map<String, dynamic> video;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final status = (video['status'] as String? ?? 'pending').toLowerCase();
    final isApproved = status == 'approved' || status == 'done';
    final isFailed = status == 'failed' || status == 'rejected';

    final statusLabel = isApproved
        ? 'Approved'
        : isFailed
            ? 'Failed'
            : status == 'processing'
                ? 'Processing'
                : 'Pending';

    final statusColor = isApproved
        ? AppColors.success
        : isFailed
            ? AppColors.error
            : status == 'processing'
                ? Colors.orangeAccent
                : AppColors.textMuted;

    // Date
    String dateStr = '';
    final createdAt = video['created_at'] as String? ?? '';
    if (createdAt.isNotEmpty) {
      dateStr = createdAt.split('T').first; // ISO → date part
    }

    // Script preview
    final script = video['script_text'] as String? ??
        video['script'] as String? ??
        video['user_prompt'] as String? ??
        '';
    final session = video['reel_id'] as String? ??
        video['id']?.toString() ??
        '';

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F111E) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.grey.shade200,
        ),
        boxShadow: isDark
            ? [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 20)]
            : [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 16)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Thumbnail placeholder / Real Image
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            child: SizedBox(
              height: 180,
              child: Stack(
                fit: StackFit.expand,
                children: [
                   Builder(builder: (ctx) {
                      final url = video['thumbnail_url'] as String?;
                      final hasUrl = url != null && url.isNotEmpty;
                      
                      Widget fallback = _buildGradient(session.hashCode);
                      
                      if (!hasUrl) return fallback;
                      
                      return Image.network(
                        url,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => fallback,
                      );
                   }),
                  // Dark overlay
                  Container(color: Colors.black.withValues(alpha: 0.2)),
                  // Play button
                  Center(
                    child: Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.25),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white.withValues(alpha: 0.6), width: 2),
                      ),
                      child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 32),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Info section
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Status badge + date
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isApproved ? Icons.check_circle_rounded : 
                            isFailed ? Icons.cancel_rounded : Icons.schedule_rounded,
                            color: statusColor, size: 13,
                          ),
                          const SizedBox(width: 4),
                          Text(statusLabel,
                              style: TextStyle(color: statusColor, fontWeight: FontWeight.w700, fontSize: 12)),
                        ],
                      ),
                    ),
                    const Spacer(),
                    Text(dateStr, style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                  ],
                ),
                if (script.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    '"$script"',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isDark ? Colors.white70 : Colors.black87,
                      fontSize: 13,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
                if (session.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Session: $session',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 11),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGradient(int seed) {
    final colors = [
      [const Color(0xFF6C5CE7), const Color(0xFF00C6FF)],
      [const Color(0xFFFF7675), const Color(0xFFD63031)],
      [const Color(0xFF00B894), const Color(0xFF00CEC9)],
      [const Color(0xFFE84393), const Color(0xFFFD79A8)],
    ];
    final colorPair = colors[seed.abs() % colors.length];
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: colorPair,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
    );
  }
}
