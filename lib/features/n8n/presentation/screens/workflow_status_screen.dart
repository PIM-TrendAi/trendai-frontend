import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/shared_widgets.dart';
import '../../data/workflow_models.dart';
import '../../data/workflow_repository.dart';

class WorkflowStatusScreen extends ConsumerStatefulWidget {
  final String sessionId;
  const WorkflowStatusScreen({super.key, required this.sessionId});

  @override
  ConsumerState<WorkflowStatusScreen> createState() => _WorkflowStatusScreenState();
}

class _WorkflowStatusScreenState extends ConsumerState<WorkflowStatusScreen> {
  Timer? _pollingTimer;
  WorkflowSession? _session;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchSession();
    _startPolling();
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  void _startPolling() {
    _pollingTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      // Only poll if we are in an active state
      if (_session != null && [
        WorkflowStatus.scraping,
        WorkflowStatus.scriptGeneration,
        WorkflowStatus.scriptApproved,
        WorkflowStatus.videoApproved
      ].contains(_session!.status)) {
        _fetchSession(silent: true);
      }
    });
  }

  Future<void> _fetchSession({bool silent = false}) async {
    if (!silent) setState(() => _loading = true);
    try {
      final session = await ref.read(workflowRepositoryProvider).getSession(widget.sessionId);
      if (mounted) {
        setState(() {
          _session = session;
          _loading = false;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load session $e';
          if (!silent) _loading = false;
        });
      }
    }
  }

  Future<void> _approveReject(bool isScript, bool approved) async {
    setState(() => _loading = true);
    try {
      final repo = ref.read(workflowRepositoryProvider);
      if (isScript) {
        if (_session!.scriptId == null) throw Exception("Missing Script ID");
        await repo.approveScript(widget.sessionId, _session!.scriptId!, approved);
      } else {
        if (_session!.videoId == null) throw Exception("Missing Video ID");
        await repo.approveVideo(widget.sessionId, _session!.videoId!, approved);
      }
      await Future.delayed(const Duration(seconds: 1)); // Give n8n time to write updates to pg
      await _fetchSession(); 
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Action failed: $e')));
        setState(() => _loading = false);
      }
    }
  }

  Widget _buildStatusIndicator() {
    if (_session == null) return const SizedBox.shrink();
    
    String text = '';
    IconData icon = Icons.info;
    Color color = AppColors.primary;
    bool spin = false;

    switch (_session!.status) {
      case WorkflowStatus.scraping:
      case WorkflowStatus.scriptGeneration:
        text = 'Agent is Generating Script via Ollama...';
        icon = Icons.search_rounded;
        spin = true;
        break;
      case WorkflowStatus.scriptPending:
        text = 'Script generated! Waiting for your approval.';
        icon = Icons.warning_amber_rounded;
        color = Colors.orangeAccent;
        break;
      case WorkflowStatus.scriptApproved:
        text = 'Script approved. Generating video via Fal.ai... (Takes ~3m)';
        icon = Icons.movie_creation_rounded;
        spin = true;
        break;
      case WorkflowStatus.scriptDeclined:
        text = 'Script declined. Agent is writing a new one...';
        icon = Icons.refresh_rounded;
        color = Colors.orangeAccent;
        spin = true;
        break;
      case WorkflowStatus.videoPending:
        text = 'Video generated! Waiting for your approval.';
        icon = Icons.warning_amber_rounded;
        color = Colors.orangeAccent;
        break;
      case WorkflowStatus.videoApproved:
        text = 'Video approved. Posting to TikTok...';
        icon = Icons.cloud_upload_rounded;
        spin = true;
        break;
      case WorkflowStatus.videoDeclined:
        text = 'Video declined. Agent is rendering a new one...';
        icon = Icons.refresh_rounded;
        color = Colors.orangeAccent;
        spin = true;
        break;
      case WorkflowStatus.posted:
        text = 'Success! Video posted to TikTok.';
        icon = Icons.check_circle_rounded;
        color = Colors.greenAccent;
        break;
      case WorkflowStatus.failed:
        text = 'Workflow failed.';
        icon = Icons.error_rounded;
        color = Colors.redAccent;
        break;
    }

    return GlassCard(
      child: Row(
        children: [
          if (spin) const SizedBox(
            width: 24, height: 24,
            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
          ) else Icon(icon, color: color, size: 28),
          const SizedBox(width: 16),
          Expanded(child: Text(text, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16))),
        ],
      ),
    );
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
                title: 'Agent Workflow', 
                subtitle: _session != null ? 'Niche: ${_session!.niche}' : '',
                showBack: true,
              ),
              Expanded(
                child: _loading && _session == null
                    ? const Center(child: CircularProgressIndicator())
                    : _error != null
                        ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
                        : SingleChildScrollView(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                            child: Column(
 crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _buildStatusIndicator(),
                                const SizedBox(height: 24),
                                
                                // Show Script if available
                                if (_session!.scriptContent != null && _session!.scriptContent!.isNotEmpty) ...[
                                  GlassCard(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Row(children: [
                                          Icon(Icons.notes_rounded, color: AppColors.primary),
                                          SizedBox(width: 8),
                                          Text('AI Generated Script', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                                        ]),
                                        const SizedBox(height: 16),
                                        Text(_session!.scriptContent!, style: const TextStyle(height: 1.5, color: Colors.white70)),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 24),
                                ],

                                // Script Approval Buttons
                                if (_session!.status == WorkflowStatus.scriptPending)
                                  Row(
                                    children: [
                                      Expanded(child: _RejectButton(onPressed: () => _approveReject(true, false))),
                                      const SizedBox(width: 16),
                                      Expanded(child: _ApproveButton(onPressed: () => _approveReject(true, true))),
                                    ],
                                  ),

                                // Show Video if available
                                if (_session!.videoUrl != null && _session!.videoUrl!.isNotEmpty) ...[
                                  GlassCard(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Row(children: [
                                          Icon(Icons.video_file_rounded, color: AppColors.primary),
                                          SizedBox(width: 8),
                                          Text('Final Video', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                                        ]),
                                        const SizedBox(height: 12),
                                        _InlineVideoPlayer(videoUrl: _session!.videoUrl!),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 24),
                                ],

                                // Video Approval Buttons
                                if (_session!.status == WorkflowStatus.videoPending)
                                  Row(
                                    children: [
                                      Expanded(child: _RejectButton(onPressed: () => _approveReject(false, false))),
                                      const SizedBox(width: 16),
                                      Expanded(child: _ApproveButton(onPressed: () => _approveReject(false, true))),
                                    ],
                                  ),
                                  
                                // TikTok Link
                                if (_session!.tiktokPostUrl != null && _session!.tiktokPostUrl!.isNotEmpty) ...[
                                  GlassCard(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Row(children: [
                                          Icon(Icons.check_circle_rounded, color: Colors.green),
                                          SizedBox(width: 8),
                                          Text('Posted to TikTok!', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                                        ]),
                                        const SizedBox(height: 16),
                                        Text('TikTok URL: ${_session!.tiktokPostUrl}', style: const TextStyle(color: Colors.blueAccent)),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
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

class _ApproveButton extends StatelessWidget {
  final VoidCallback onPressed;
  const _ApproveButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: const Text('Approve', style: TextStyle(fontWeight: FontWeight.bold)),
    );
  }
}

class _RejectButton extends StatelessWidget {
  final VoidCallback onPressed;
  const _RejectButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.redAccent.withValues(alpha: 0.2),
        foregroundColor: Colors.redAccent,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: const Text('Reject', style: TextStyle(fontWeight: FontWeight.bold)),
    );
  }
}

// ─── Inline Video Player ──────────────────────────────────────────────────────

class _InlineVideoPlayer extends StatefulWidget {
  final String videoUrl;
  const _InlineVideoPlayer({required this.videoUrl});

  @override
  State<_InlineVideoPlayer> createState() => _InlineVideoPlayerState();
}

class _InlineVideoPlayerState extends State<_InlineVideoPlayer> {
  VideoPlayerController? _controller;
  bool _initialized = false;
  bool _loading = false;

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _initAndPlay() async {
    if (_initialized) {
      _controller!.value.isPlaying ? _controller!.pause() : _controller!.play();
      setState(() {});
      return;
    }
    setState(() => _loading = true);
    final uri = Uri.tryParse(widget.videoUrl);
    if (uri == null) return;
    _controller = VideoPlayerController.networkUrl(uri);
    await _controller!.initialize();
    await _controller!.setLooping(true);
    await _controller!.play();
    if (mounted) setState(() { _initialized = true; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: _initialized && _controller != null
          ? Column(
              children: [
                AspectRatio(
                  aspectRatio: _controller!.value.aspectRatio,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      VideoPlayer(_controller!),
                      GestureDetector(
                        onTap: _initAndPlay,
                        child: AnimatedOpacity(
                          opacity: _controller!.value.isPlaying ? 0 : 1,
                          duration: const Duration(milliseconds: 300),
                          child: Container(
                            color: Colors.black45,
                            child: const Center(
                              child: Icon(Icons.play_arrow_rounded,
                                  size: 56, color: Colors.white),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                VideoProgressIndicator(
                  _controller!,
                  allowScrubbing: true,
                  colors: const VideoProgressColors(playedColor: AppColors.primary),
                ),
              ],
            )
          : GestureDetector(
              onTap: _initAndPlay,
              child: Container(
                height: 200,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white12),
                ),
                child: Center(
                  child: _loading
                      ? const CircularProgressIndicator(color: AppColors.primary)
                      : const Column(
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
    );
  }
}
