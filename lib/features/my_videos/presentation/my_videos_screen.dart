import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/shared_widgets.dart';
import '../../auth/auth_repository.dart';
import '../../video_workflow/data/models/workflow_models.dart';
import '../../video_workflow/data/n8n_repository.dart';

final _myVideosProvider = FutureProvider.autoDispose<List<CreatorVideoModel>>((ref) async {
  final user = ref.watch(authNotifierProvider).valueOrNull;
  if (user == null) return [];
  return ref.read(n8nRepositoryProvider).fetchMyVideos(user.creatorId);
});

class MyVideosScreen extends ConsumerWidget {
  const MyVideosScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final videosAsync = ref.watch(_myVideosProvider);

    return Scaffold(
      body: Stack(
        children: [
          if (isDark) const AnimatedParticleBackground(),
          Column(
            children: [
              TrendAIAppBar(
                title: 'My Videos',
                subtitle: 'Your generated content',
                showBack: true,
                action: IconButton(
                  icon: const Icon(Icons.refresh_rounded),
                  onPressed: () => ref.invalidate(_myVideosProvider),
                ),
              ),
              Expanded(
                child: videosAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline, size: 48, color: AppColors.error),
                        const SizedBox(height: 12),
                        const Text('Failed to load videos', style: TextStyle(color: AppColors.error)),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: () => ref.invalidate(_myVideosProvider),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                  data: (videos) {
                    if (videos.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.video_library_outlined, size: 64,
                                color: isDark ? Colors.white24 : Colors.black26),
                            const SizedBox(height: 16),
                            Text('No videos yet',
                                style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? Colors.white54 : Colors.black45)),
                            const SizedBox(height: 8),
                            Text('Generate your first video from the AI Gen tab',
                                style: TextStyle(
                                    fontSize: 13,
                                    color: isDark ? Colors.white38 : Colors.black38)),
                          ],
                        ),
                      );
                    }
                    return ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
                      itemCount: videos.length,
                      itemBuilder: (_, i) => _VideoCard(video: videos[i]),
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

class _VideoCard extends StatelessWidget {
  const _VideoCard({required this.video});
  final CreatorVideoModel video;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final statusInfo = _statusInfo(video.status);

    return GestureDetector(
      onTap: video.videoUrl.isNotEmpty
          ? () => _openPlayer(context, video.videoUrl)
          : null,
      child: _buildCard(context, isDark, statusInfo),
    );
  }

  void _openPlayer(BuildContext context, String url) {
    showDialog(
      context: context,
      barrierColor: Colors.black,
      builder: (_) => _VideoPlayerDialog(url: url),
    );
  }

  Widget _buildCard(BuildContext context, bool isDark, _StatusInfo statusInfo) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F111E) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.grey.shade200,
        ),
        boxShadow: isDark
            ? [BoxShadow(color: AppColors.primary.withValues(alpha: 0.06), blurRadius: 20)]
            : [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 12)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Thumbnail / video placeholder
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            child: SizedBox(
              height: 200,
              width: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Thumbnail image
                  video.thumbnailUrl.isNotEmpty
                      ? Image.network(
                          video.thumbnailUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _thumbPlaceholder(isDark),
                        )
                      : _thumbPlaceholder(isDark),
                  // Gradient overlay
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Colors.black.withValues(alpha: 0.55)],
                      ),
                    ),
                  ),
                  // Play button (only if video is ready)
                  if (video.videoUrl.isNotEmpty)
                    Center(
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.black45,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white60, width: 1.5),
                        ),
                        child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 34),
                      ),
                    )
                  else
                    Center(
                      child: Icon(Icons.hourglass_top_rounded,
                          size: 40, color: isDark ? Colors.white38 : Colors.black38),
                    ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Status badge + date row
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusInfo.color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: statusInfo.color.withValues(alpha: 0.4)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(statusInfo.icon, size: 12, color: statusInfo.color),
                          const SizedBox(width: 5),
                          Text(statusInfo.label,
                              style: TextStyle(
                                  color: statusInfo.color,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ),
                    const Spacer(),
                    Text(
                      _formatDate(video.createdAt),
                      style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                    ),
                  ],
                ),
                if (video.scriptContent.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    video.scriptContent,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? Colors.white70 : Colors.black87,
                      height: 1.4,
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                Text(
                  'Session: ${video.sessionId}',
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 10),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _thumbPlaceholder(bool isDark) => Container(
        color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade100,
        child: Center(
          child: Icon(Icons.video_library_outlined,
              size: 40, color: isDark ? Colors.white24 : Colors.black26),
        ),
      );

  _StatusInfo _statusInfo(String status) {
    switch (status) {
      case 'approved':
        return const _StatusInfo('Approved', AppColors.success, Icons.check_circle_outline_rounded);
      case 'declined':
        return const _StatusInfo('Declined', AppColors.error, Icons.cancel_outlined);
      default:
        return const _StatusInfo('Waiting Approval', AppColors.warning, Icons.hourglass_top_rounded);
    }
  }

  String _formatDate(String raw) {
    if (raw.isEmpty) return '';
    try {
      final dt = DateTime.parse(raw).toLocal();
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) {
      return raw.substring(0, raw.length.clamp(0, 10));
    }
  }
}

class _StatusInfo {
  const _StatusInfo(this.label, this.color, this.icon);
  final String label;
  final Color color;
  final IconData icon;
}

class _VideoPlayerDialog extends StatefulWidget {
  const _VideoPlayerDialog({required this.url});
  final String url;

  @override
  State<_VideoPlayerDialog> createState() => _VideoPlayerDialogState();
}

class _VideoPlayerDialogState extends State<_VideoPlayerDialog> {
  late VideoPlayerController _ctrl;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    _ctrl = VideoPlayerController.networkUrl(Uri.parse(widget.url));
    _ctrl.initialize().then((_) {
      if (mounted) {
        setState(() => _ready = true);
        _ctrl.play();
        _ctrl.setLooping(true);
      }
    });
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Video
          Center(
            child: _ready
                ? GestureDetector(
                    onTap: () => setState(() {
                      _ctrl.value.isPlaying ? _ctrl.pause() : _ctrl.play();
                    }),
                    child: AspectRatio(
                      aspectRatio: _ctrl.value.aspectRatio,
                      child: VideoPlayer(_ctrl),
                    ),
                  )
                : const CircularProgressIndicator(color: Colors.white),
          ),
          // Progress bar
          if (_ready)
            Positioned(
              bottom: 48,
              left: 16,
              right: 16,
              child: VideoProgressIndicator(
                _ctrl,
                allowScrubbing: true,
                colors: const VideoProgressColors(
                  playedColor: AppColors.primary,
                  bufferedColor: Colors.white24,
                  backgroundColor: Colors.white12,
                ),
              ),
            ),
          // Play/pause icon overlay
          if (_ready && !_ctrl.value.isPlaying)
            const Center(
              child: Icon(Icons.play_circle_outline_rounded,
                  size: 72, color: Colors.white70),
            ),
          // Close button
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 12,
            child: GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.close_rounded, color: Colors.white, size: 22),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
