import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../shared/widgets/shared_widgets.dart';

class VideoReviewScreen extends ConsumerStatefulWidget {
  final int videoId;

  const VideoReviewScreen({super.key, required this.videoId});

  @override
  ConsumerState<VideoReviewScreen> createState() => _VideoReviewScreenState();
}

class _VideoReviewScreenState extends ConsumerState<VideoReviewScreen> {
  Timer? _timer;
  Map<String, dynamic>? _record;
  String _status = 'polling'; // polling | ready | approving | approved | rejecting | publishing | published | error
  int _pollCount = 0;
  static const _maxPolls = 30; // 30 × 3s = 90s

  @override
  void initState() {
    super.initState();
    _startPolling();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startPolling() {
    _pollCount = 0;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 3), (_) => _poll());
    _poll();
  }

  Future<void> _poll() async {
    _pollCount++;
    if (_pollCount > _maxPolls) {
      _timer?.cancel();
      if (mounted) setState(() => _status = 'error');
      return;
    }
    try {
      final dio = ref.read(dioProvider);
      final res = await dio.get('/scripts/videos/');
      final dynamic data = res.data;
      final List<dynamic> all = data is List ? data : (data['results'] as List? ?? []);

      for (final item in all) {
        final map = item as Map<String, dynamic>;
        if (map['id'] == widget.videoId) {
          final videoStatus = (map['status'] as String? ?? '').toLowerCase();
          final hasVideo = (map['video_url'] as String? ?? '').isNotEmpty;

          if (hasVideo || videoStatus == 'done' || videoStatus == 'approved' ||
              videoStatus == 'published' || videoStatus == 'rejected') {
            _timer?.cancel();
            if (mounted) setState(() { _record = map; _status = 'ready'; });
          }
          return;
        }
      }
    } catch (_) {}
  }

  Future<void> _reject() async {
    setState(() => _status = 'rejecting');
    try {
      await ref.read(dioProvider).post('/scripts/videos/${widget.videoId}/reject/');
    } catch (_) {}
    if (mounted) context.pop();
  }

  Future<void> _approve() async {
    setState(() => _status = 'approving');
    try {
      await ref.read(dioProvider).post('/scripts/videos/${widget.videoId}/approve/');
      if (mounted) setState(() => _status = 'approved');
    } catch (_) {
      if (mounted) setState(() => _status = 'ready');
    }
  }

  Future<void> _publish() async {
    setState(() => _status = 'publishing');
    try {
      await ref.read(dioProvider).post('/scripts/videos/${widget.videoId}/publish/');
      if (mounted) setState(() => _status = 'published');
    } catch (e) {
      if (mounted) {
        setState(() => _status = 'approved');
        // Extract FB error message from DioException response
        String errMsg = 'Publication échouée.';
        try {
          final resp = (e as dynamic).response;
          if (resp != null) {
            final body = resp.data as Map<String, dynamic>? ?? {};
            errMsg = body['error'] as String? ?? errMsg;
          }
        } catch (_) {}
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(errMsg),
          backgroundColor: const Color(0xFFE17055),
          duration: const Duration(seconds: 6),
        ));
      }
    }
  }

  Future<void> _watchVideo() async {
    final url = _record?['video_url'] as String? ?? '';
    if (url.isEmpty) return;
    final uri = Uri.parse(url);
    try {
      // Try external app first (video player / browser)
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched && mounted) {
        // Fallback: open in in-app browser
        await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Impossible d\'ouvrir la vidéo.'),
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      body: Stack(
        children: [
          if (isDark) const AnimatedParticleBackground(),
          Column(
            children: [
              SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios_rounded),
                        onPressed: () => context.pop(),
                      ),
                      Expanded(
                        child: Column(
                          children: [
                            const Text('Video Review',
                                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.auto_awesome, size: 12, color: AppColors.primary),
                                const SizedBox(width: 4),
                                Text('Review & publish your AI video',
                                    style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 48),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(child: _buildBody(isDark)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBody(bool isDark) {
    switch (_status) {
      case 'polling':
        return _buildPolling(isDark);
      case 'ready':
      case 'approving':
        return _buildVideoReady(isDark, isApproving: _status == 'approving');
      case 'approved':
      case 'publishing':
        return _buildApproved(isDark, isPublishing: _status == 'publishing');
      case 'published':
        return _buildPublished(isDark);
      case 'rejecting':
        return _buildRejecting(isDark);
      case 'error':
        return _buildError();
      default:
        return _buildPolling(isDark);
    }
  }

  Widget _buildPolling(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 72,
              height: 72,
              child: CircularProgressIndicator(strokeWidth: 3, color: AppColors.primary),
            ),
            const SizedBox(height: 28),
            Text('Generating your video...',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : Colors.black87)),
            const SizedBox(height: 12),
            Text('AI is rendering your cartoon video.\nThis usually takes 10–30 seconds.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textMuted, fontSize: 14, height: 1.6)),
            const SizedBox(height: 24),
            LinearProgressIndicator(
              backgroundColor: AppColors.primary.withValues(alpha: 0.15),
              valueColor: AlwaysStoppedAnimation(AppColors.primary),
            ),
            const SizedBox(height: 8),
            Text('${((_pollCount / _maxPolls) * 100).clamp(0, 99).toInt()}%',
                style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _buildRejecting(bool isDark) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(strokeWidth: 3, color: AppColors.error),
          const SizedBox(height: 20),
          Text('Rejecting video...', style: TextStyle(color: AppColors.textMuted, fontSize: 15)),
        ],
      ),
    );
  }

  Widget _buildVideoReady(bool isDark, {required bool isApproving}) {
    final videoUrl = _record?['video_url'] as String? ?? '';
    final scriptText = _record?['script_text'] as String? ??
        _record?['user_prompt'] as String? ?? '';
    final niche = _record?['niche'] as String? ?? '';
    final createdAt = (_record?['created_at'] as String? ?? '').split('T').first;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Video Preview Card
          Stack(
            children: [
              Container(
                height: 220,
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: LinearGradient(
                    colors: [
                      AppColors.primary.withValues(alpha: 0.4),
                      AppColors.accent.withValues(alpha: 0.25),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.3),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Center(
                    child: Icon(
                      Icons.play_circle_rounded,
                      color: Colors.white.withValues(alpha: 0.8),
                      size: 72,
                    ),
                  ),
                ),
              ),
              // Niche badge (top-left)
              Positioned(
                top: 14,
                left: 14,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.videocam_rounded, color: Colors.white, size: 12),
                      const SizedBox(width: 4),
                      Text(
                        'AI Generated • $niche',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // ── Watch Video button (visible, prominent)
          if (videoUrl.isNotEmpty)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _watchVideo,
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Text(
                  'Regarder la vidéo',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: BorderSide(color: AppColors.primary, width: 1.5),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          const SizedBox(height: 16),

          // ── Script info card
          if (scriptText.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : Colors.grey.shade50,
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : Colors.grey.shade200,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.description_outlined, size: 15, color: AppColors.primary),
                      const SizedBox(width: 6),
                      Text(
                        'Video Prompt',
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '"$scriptText"',
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? Colors.white70 : Colors.black87,
                      fontStyle: FontStyle.italic,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 12),

          // ── Meta row
          Row(
            children: [
              Icon(Icons.calendar_today_rounded, size: 13, color: AppColors.textMuted),
              const SizedBox(width: 5),
              Text(createdAt, style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
              const SizedBox(width: 16),
              Icon(Icons.circle, size: 8, color: AppColors.success),
              const SizedBox(width: 5),
              Text(
                'Prêt',
                style: TextStyle(
                  color: AppColors.success,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),

          // ── Reject / Approve actions
          if (isApproving)
            const Center(child: CircularProgressIndicator())
          else
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _reject,
                    icon: const Icon(Icons.close_rounded),
                    label: const Text('Reject'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side: BorderSide(color: AppColors.error.withValues(alpha: 0.6)),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  flex: 2,
                  child: GradientButton(
                    label: 'Approve Video',
                    onPressed: _approve,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildApproved(bool isDark, {required bool isPublishing}) {
    final videoUrl = _record?['video_url'] as String? ?? '';
    final scriptText = _record?['script_text'] as String? ?? '';

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Approved banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: AppColors.success.withValues(alpha: 0.12),
              border: Border.all(color: AppColors.success.withValues(alpha: 0.4)),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.check_circle_rounded, color: AppColors.success, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Video Approved!',
                          style: TextStyle(color: AppColors.success, fontWeight: FontWeight.w800, fontSize: 17)),
                      const SizedBox(height: 4),
                      Text('Ready to publish on Facebook',
                          style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ── Video preview (tappable)
          if (videoUrl.isNotEmpty)
            GestureDetector(
              onTap: _watchVideo,
              child: Container(
                height: 180,
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: LinearGradient(
                    colors: [AppColors.primary.withValues(alpha: 0.4), AppColors.accent.withValues(alpha: 0.3)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.play_circle_rounded, color: Colors.white, size: 56),
                      SizedBox(height: 8),
                      Text('Watch Video', style: TextStyle(color: Colors.white70, fontSize: 13)),
                    ],
                  ),
                ),
              ),
            ),

          if (scriptText.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text('"$scriptText"',
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: AppColors.textMuted, fontSize: 13, fontStyle: FontStyle.italic)),
          ],
          const SizedBox(height: 32),

          // ── Publish button
          if (isPublishing)
            Column(
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text('Publishing to Facebook...', style: TextStyle(color: AppColors.textMuted, fontSize: 14)),
              ],
            )
          else
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _publish,
                icon: const Icon(Icons.facebook_rounded, size: 22),
                label: const Text('Publish to Facebook', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1877F2),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
              ),
            ),
          const SizedBox(height: 12),
          Center(
            child: TextButton(
              onPressed: () => context.go('/ai-generator'),
              child: Text('Generate another video', style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPublished(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: const Color(0xFF1877F2).withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.facebook_rounded, color: Color(0xFF1877F2), size: 56),
            ),
            const SizedBox(height: 24),
            const Text('Published!',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            Text(
              'Your video has been published\nto your Facebook page.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textMuted, fontSize: 15, height: 1.6),
            ),
            const SizedBox(height: 40),
            GradientButton(
              label: 'Generate Another Video',
              onPressed: () => context.go('/ai-generator'),
            ),
            const SizedBox(height: 14),
            TextButton(
              onPressed: () => context.go('/my-videos'),
              child: Text('View My Videos', style: TextStyle(color: AppColors.textMuted)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline_rounded, size: 64, color: AppColors.error),
            const SizedBox(height: 16),
            const Text('Video generation timed out.',
                textAlign: TextAlign.center, style: TextStyle(fontSize: 16)),
            const SizedBox(height: 8),
            Text('Check My Videos for status updates.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textMuted, fontSize: 14)),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton(
                  onPressed: () => context.go('/my-videos'),
                  child: const Text('My Videos'),
                ),
                const SizedBox(width: 12),
                GradientButton(
                  label: 'Try Again',
                  onPressed: () {
                    setState(() { _status = 'polling'; });
                    _startPolling();
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
