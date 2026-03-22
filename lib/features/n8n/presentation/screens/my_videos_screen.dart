import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/shared_widgets.dart';
import '../../../../core/network/dio_client.dart';
import '../../data/workflow_repository.dart';

// ─── Model ───────────────────────────────────────────────────────────────────

class GeneratedVideoItem {
  final String videoId;
  final String sessionId;
  final String videoUrl;
  final String status;
  final String niche;
  final String scriptPreview;
  final String? createdAt;

  GeneratedVideoItem({
    required this.videoId,
    required this.sessionId,
    required this.videoUrl,
    required this.status,
    required this.niche,
    required this.scriptPreview,
    this.createdAt,
  });

  factory GeneratedVideoItem.fromJson(Map<String, dynamic> j) =>
      GeneratedVideoItem(
        videoId: j['video_id'] ?? '',
        sessionId: j['session_id'] ?? '',
        videoUrl: j['video_url'] ?? '',
        status: j['status'] ?? '',
        niche: j['niche'] ?? '',
        scriptPreview: j['script_preview'] ?? '',
        createdAt: j['created_at'],
      );
}

// ─── Screen ──────────────────────────────────────────────────────────────────

class MyVideosScreen extends ConsumerStatefulWidget {
  const MyVideosScreen({super.key});

  @override
  ConsumerState<MyVideosScreen> createState() => _MyVideosScreenState();
}

class _MyVideosScreenState extends ConsumerState<MyVideosScreen> {
  List<GeneratedVideoItem> _videos = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchVideos();
  }

  Future<void> _fetchVideos() async {
    setState(() => _loading = true);
    try {
      // We call the endpoint directly via the repository's dio
      final response = await ref.read(dioProvider).get('/n8n/my-videos/');
      final List data = response.data is List ? response.data : [];
      setState(() {
        _videos = data.map((e) => GeneratedVideoItem.fromJson(e)).toList();
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const AnimatedParticleBackground(),
          Column(
            children: [
              TrendAIAppBar(
                title: 'My Videos',
                subtitle: '${_videos.length} generated video${_videos.length == 1 ? '' : 's'}',
                showBack: true,
                actions: [
                  IconButton(
                    icon: const Icon(Icons.refresh_rounded, color: Colors.white70),
                    onPressed: _fetchVideos,
                  )
                ],
              ),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _videos.isEmpty
                        ? const Center(
                            child: Padding(
                              padding: EdgeInsets.all(32),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.video_library_rounded,
                                      size: 72, color: Colors.white24),
                                  SizedBox(height: 16),
                                  Text('No videos yet',
                                      style: TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold)),
                                  SizedBox(height: 8),
                                  Text(
                                    'Go to the Agent screen, pick a niche and approve a script to generate your first video!',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(color: Colors.white54),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.all(16),
                            itemCount: _videos.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 16),
                            itemBuilder: (context, i) =>
                                _VideoCard(video: _videos[i]),
                          ),
              ),
            ],
          ),
          const Positioned(
            left: 0, right: 0, bottom: 0,
            child: TrendAIBottomNav(currentIndex: 3),
          ),
        ],
      ),
    );
  }
}

// ─── Video Card ───────────────────────────────────────────────────────────────

class _VideoCard extends ConsumerStatefulWidget {
  final GeneratedVideoItem video;
  const _VideoCard({required this.video});

  @override
  ConsumerState<_VideoCard> createState() => _VideoCardState();
}

class _VideoCardState extends ConsumerState<_VideoCard> {
  VideoPlayerController? _controller;
  bool _showPlayer = false;
  bool _initialized = false;
  bool _acting = false;
  late String _status;

  @override
  void initState() {
    super.initState();
    _status = widget.video.status;
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _initPlayer() async {
    if (_initialized) {
      setState(() => _showPlayer = true);
      _controller?.play();
      return;
    }
    final uri = Uri.tryParse(widget.video.videoUrl);
    if (uri == null || widget.video.videoUrl.isEmpty) return;

    _controller = VideoPlayerController.networkUrl(uri);
    await _controller!.initialize();
    await _controller!.setLooping(true);
    await _controller!.play();
    if (mounted) {
      setState(() {
        _initialized = true;
        _showPlayer = true;
      });
    }
  }

  Future<void> _decide(bool approve) async {
    setState(() => _acting = true);
    try {
      await ref.read(workflowRepositoryProvider).approveVideo(
        widget.video.sessionId,
        widget.video.videoId,
        approve,
      );
      if (mounted) {
        setState(() {
          _status = approve ? 'approved' : 'declined';
          _acting = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(approve
              ? '✅ Video approved — posting to TikTok...'
              : '❌ Video declined'),
          backgroundColor: approve ? Colors.green : Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _acting = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Failed. Check backend connection.'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }

  String _formatDate(String? iso) {
    if (iso == null) return '';
    try {
      final dt = DateTime.parse(iso).toLocal();
      return '${dt.day}/${dt.month}/${dt.year}  ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  gradient: AppColors.gradientPrimary,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(widget.video.niche.isEmpty ? 'General' : widget.video.niche,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12)),
              ),
              const Spacer(),
              Text(_formatDate(widget.video.createdAt),
                  style: const TextStyle(color: Colors.white38, fontSize: 11)),
            ],
          ),
          const SizedBox(height: 12),

          // Video player or thumbnail
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: _showPlayer && _initialized && _controller != null
                ? AspectRatio(
                    aspectRatio: 9 / 16,
                    child: Stack(
                      alignment: Alignment.bottomCenter,
                      children: [
                        VideoPlayer(_controller!),
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              if (_controller!.value.isPlaying) {
                                _controller!.pause();
                              } else {
                                _controller!.play();
                              }
                            });
                          },
                          child: AnimatedOpacity(
                            opacity: _controller!.value.isPlaying ? 0 : 1,
                            duration: const Duration(milliseconds: 300),
                            child: Container(
                              color: Colors.black45,
                              child: const Center(
                                child: Icon(Icons.play_arrow_rounded,
                                    size: 64, color: Colors.white),
                              ),
                            ),
                          ),
                        ),
                        VideoProgressIndicator(_controller!,
                            allowScrubbing: true,
                            colors: const VideoProgressColors(
                                playedColor: AppColors.primary)),
                      ],
                    ),
                  )
                : GestureDetector(
                    onTap: _initPlayer,
                    child: Container(
                      height: 200,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.play_circle_fill_rounded,
                                size: 64, color: AppColors.primary),
                            SizedBox(height: 8),
                            Text('Tap to play video',
                                style: TextStyle(color: Colors.white54)),
                          ],
                        ),
                      ),
                    ),
                  ),
          ),

          // Script preview
          if (widget.video.scriptPreview.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Text('Script preview',
                style: TextStyle(
                    color: Colors.white38,
                    fontSize: 11,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(widget.video.scriptPreview,
                style: const TextStyle(
                    color: Colors.white60, fontSize: 13, height: 1.5)),
          ],

          // Status badge
          const SizedBox(height: 12),
          Row(
            children: [
              _StatusBadge(status: _status),
            ],
          ),

          // ── Approve / Decline buttons for pending videos ──
          if (_status == 'pending_approval') ...[
            const SizedBox(height: 16),
            _acting
                ? const Center(
                    child: SizedBox(
                      height: 36,
                      width: 36,
                      child: CircularProgressIndicator(
                          color: AppColors.primary, strokeWidth: 2),
                    ),
                  )
                : Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _decide(false),
                          icon: const Icon(Icons.close_rounded, size: 16),
                          label: const Text('Decline'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.redAccent,
                            side: const BorderSide(color: Colors.redAccent),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _decide(true),
                          icon: const Icon(Icons.check_rounded, size: 16),
                          label: const Text('Approve & Post'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                    ],
                  ),
          ],
        ],
      ),
    );
  }
}


class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    IconData icon;
    switch (status) {
      case 'approved':
        color = Colors.greenAccent;
        icon = Icons.check_circle_rounded;
        break;
      case 'pending_approval':
        color = Colors.orangeAccent;
        icon = Icons.hourglass_top_rounded;
        break;
      default:
        color = Colors.white38;
        icon = Icons.info_rounded;
    }
    return Row(
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(status.replaceAll('_', ' '),
            style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
      ],
    );
  }
}
