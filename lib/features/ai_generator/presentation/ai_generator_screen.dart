/// AI Script & Video Generator screen — prompt + style/duration/platform selectors,
/// calls n8n workflow for video generation or standard AI for scripts.
library;

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/network/dio_client.dart';
import '../../../shared/widgets/shared_widgets.dart';
import '../../auth/data/models.dart';

final _videoGenerationStatusProvider =
    StateProvider<Map<String, dynamic>?>((_) => null);

class AIGeneratorScreen extends ConsumerStatefulWidget {
  const AIGeneratorScreen({super.key, this.niche, this.selectedVideoId, this.platform});
  final String? niche;
  final String? selectedVideoId;
  final String? platform;

  @override
  ConsumerState<AIGeneratorScreen> createState() => _AIGeneratorScreenState();
}

class _AIGeneratorScreenState extends ConsumerState<AIGeneratorScreen> {
  bool _loading = false;
  bool _autoApprovingScript = false;
  Timer? _pollingTimer;
  String? _currentSessionId;
  String? _lastAutoApprovedScriptId;

  final styles = ['Funny', 'Informative', 'Dramatic', 'Casual'];
  final durations = ['30s', '60s', '90s'];
  final platforms = ['TikTok', 'Instagram', 'YouTube', 'Facebook'];

  @override
  void initState() {
    super.initState();
    // Load the latest session on page open so the script shows immediately
    _loadLatestSession();
  }

  Future<void> _loadLatestSession() async {
    try {
      final dio = ref.read(dioProvider);
      final res = await dio.get('/n8n/sessions/latest/');
      if (!mounted) return;
      final sessionId = res.data['session_id'];
      if (sessionId != null) {
        _currentSessionId = sessionId;
        final statusRes = await dio.get('/n8n/sessions/$sessionId/');
        if (!mounted) return;
        final data = statusRes.data;
        final status = data['status'];
        debugPrint('Loaded session: status=$status, script=${data['script_content'] != null}');

        // Only show if session is still active (not finished)
        if (status == 'posted' || status == 'declined') {
          // Old finished session — ignore, let user start fresh
          _currentSessionId = null;
          return;
        }

        ref.read(_videoGenerationStatusProvider.notifier).state = data;

        // If still in progress, resume polling
        if (data['video_url'] == null) {
          _startPolling();
        }
      }
    } catch (e) {
      debugPrint('Load latest session failed: $e');
    }
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  Future<void> _startGeneration() async {
    setState(() => _loading = true);
    try {
      final dio = ref.read(dioProvider);

      // Always use the n8n VIDEO workflow
      final niche = widget.niche ?? 'General';
      final res = await dio.post('/n8n/start/', data: {
        'niche': niche,
        'selected_video_id': widget.selectedVideoId ?? 'test_video_123',
        'custom_prompt': "Générer une vidéo virale sur le sujet: $niche",
        'style': 'Informative',
        'duration': '60s',
        'platform': widget.platform ?? 'tiktok',
      });

      if (res.data['success'] == true) {
        // Start polling for status
        if (mounted) _startPolling();
      }
    } catch (e) {
      if (e is DioException) {
        if (e.response == null) {
          _showError('Server unreachable: ${e.message}');
        } else {
          final dataError =
              e.response?.data is Map ? e.response?.data['error'] : null;
          _showError(dataError ?? 'Server Error ${e.response?.statusCode}');
        }
      } else {
        _showError('Generation failed: $e');
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  void _startPolling() async {
    _pollingTimer?.cancel();

    if (!mounted) return;
    // Attempt to get the session ID immediately
    final dio = ref.read(dioProvider);
    try {
      final res = await dio.get('/n8n/sessions/latest/');
      if (res.data['session_id'] != null) {
        _currentSessionId = res.data['session_id'];
      }
    } catch (_) {}

    _pollingTimer = Timer.periodic(const Duration(seconds: 3), (timer) async {
      if (!mounted) { timer.cancel(); return; }

      // If we still don't have a session ID, keep looking
      if (_currentSessionId == null) {
        try {
          final res = await dio.get('/n8n/sessions/latest/');
          if (res.data['session_id'] != null) {
            _currentSessionId = res.data['session_id'];
          }
        } catch (_) {}
      }

      if (_currentSessionId == null) return;

      try {
        final statusRes = await dio.get('/n8n/sessions/$_currentSessionId/');
        final data = statusRes.data;
        if (!mounted) { timer.cancel(); return; }
        debugPrint('Polling data: status=${data['status']}, script_content=${data['script_content'] != null ? 'YES (${(data['script_content'] as String).length} chars)' : 'NULL'}');
        ref.read(_videoGenerationStatusProvider.notifier).state = data;

        final status = data['status'];
        final scriptId = data['script_id'];

        // This screen is a one-tap video flow: auto-approve generated script.
        if (status == 'script_pending' &&
            scriptId != null &&
            !_autoApprovingScript &&
            _lastAutoApprovedScriptId != scriptId) {
          await _autoApproveScript(data);
        }

        // Stop polling if we reach a final state or have a video URL
        if (data['video_url'] != null ||
            status == 'posted' ||
            status == 'declined') {
          timer.cancel();
          if (mounted) setState(() => _loading = false);
        }
      } catch (e) {
        debugPrint('Polling error: $e');
      }
    });
  }

  Future<void> _autoApproveScript(Map<String, dynamic> status) async {
    final scriptId = status['script_id'];
    final sessionId = status['session_id'];
    if (scriptId == null || sessionId == null) return;

    _autoApprovingScript = true;
    try {
      final dio = ref.read(dioProvider);
      await dio.post('/n8n/approve/script/', data: {
        'session_id': sessionId,
        'script_id': scriptId,
        'approved': true,
      });
      _lastAutoApprovedScriptId = scriptId as String?;
    } catch (e) {
      debugPrint('Auto-approve script failed: $e');
    } finally {
      _autoApprovingScript = false;
    }
  }

  Future<void> _publishVideo() async {
    final status = ref.read(_videoGenerationStatusProvider);
    if (status == null) return;

    setState(() => _loading = true);
    try {
      final dio = ref.read(dioProvider);
      await dio.post('/n8n/approve/video/', data: {
        'session_id': status['session_id'],
        'video_id': status['video_id'],
        'approved': true,
        'platform': widget.platform ?? 'tiktok',
      });
      _startPolling(); // Poll again to see completion
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Publication de la vidéo lancée ! 🚀')),
        );
      }
    } catch (e) {
      _showError('La publication a échoué.');
    }
    setState(() => _loading = false);
  }

  Future<void> _refuseVideo() async {
    final status = ref.read(_videoGenerationStatusProvider);
    if (status == null) return;

    setState(() => _loading = true);
    try {
      final dio = ref.read(dioProvider);
      await dio.post('/n8n/approve/video/', data: {
        'session_id': status['session_id'],
        'video_id': status['video_id'],
        'approved': false,
        'platform': widget.platform ?? 'tiktok',
      });
      ref.read(_videoGenerationStatusProvider.notifier).state = null;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Vidéo refusée et supprimée.')),
        );
      }
    } catch (e) {
      _showError('Action failed.');
    }
    setState(() => _loading = false);
  }

  void _showError(String msg) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final videoStatus = ref.watch(_videoGenerationStatusProvider);

    return Scaffold(
      body: Stack(
        children: [
          const AnimatedParticleBackground(),
          Column(
            children: [
              const TrendAIAppBar(
                title: 'Production Studio',
                subtitle: 'AI Video Engine',
                showBack: true,
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Show generated script above the subject header
                      if (videoStatus != null &&
                          videoStatus['script_content'] != null) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: AppColors.primary.withValues(alpha: 0.2),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.auto_awesome,
                                      size: 16,
                                      color: AppColors.primary.withValues(alpha: 0.8)),
                                  const SizedBox(width: 8),
                                  const Text('SCRIPT GÉNÉRÉ',
                                      style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 1.2,
                                          color: AppColors.primary)),
                                ],
                              ),
                              const SizedBox(height: 14),
                              Text(
                                videoStatus['script_content'] as String,
                                style: const TextStyle(
                                    fontSize: 14,
                                    height: 1.6,
                                    color: Colors.white70),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      // Professional Subject Header
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(24),
                          gradient: LinearGradient(
                            colors: [
                              AppColors.primary.withValues(alpha: 0.15),
                              Colors.transparent
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          border: Border.all(
                              color: AppColors.primary.withValues(alpha: 0.2)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                      color: AppColors.primary
                                          .withValues(alpha: 0.1),
                                      shape: BoxShape.circle),
                                  child: const Icon(Icons.movie_filter_rounded,
                                      color: AppColors.primary, size: 20),
                                ),
                                const SizedBox(width: 12),
                                const Text('SUJET DE PRODUCTION',
                                    style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 1.2,
                                        color: AppColors.primary)),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              widget.niche ?? 'Tendance Générale',
                              style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w900,
                                  height: 1.1),
                            ),
                            const SizedBox(height: 24),
                            if (videoStatus == null ||
                                videoStatus['status'] == 'declined')
                              GradientButton(
                                label: 'Lancer la Production 🎬',
                                onPressed: _startGeneration,
                                isLoading: _loading,
                              ),
                          ],
                        ),
                      ),

                      // Video Generation Status UI
                      if (videoStatus != null) ...[
                        const SizedBox(height: 24),
                        _VideoStatusCard(
                          status: videoStatus,
                          onPublish: _publishVideo,
                          onRefuse: _refuseVideo,
                          isLoading: _loading,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
          const Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: TrendAIBottomNav(currentIndex: 2),
          ),
        ],
      ),
    );
  }
}

class _VideoStatusCard extends StatelessWidget {
  const _VideoStatusCard(
      {required this.status,
      required this.onPublish,
      required this.onRefuse,
      required this.isLoading});
  final Map<String, dynamic> status;
  final VoidCallback onPublish;
  final VoidCallback onRefuse;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final state = status['status'] ?? 'processing';
    final videoUrl = status['video_url'];

    double progress = 0.2;
    String stepLabel = "Analyse en cours...";
    if (state == 'processing') {
      progress = 0.5;
      stepLabel = "Génération du Montage...";
    }
    if (videoUrl != null) {
      progress = 0.9;
      stepLabel = "Prêt pour Validation";
    }
    if (state == 'posted') {
      progress = 1.0;
      stepLabel = "Publication Terminée";
    }

    return GlassCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Text('ÉTAT DE LA PRODUCTION',
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                    color: AppColors.textMuted)),
            const Spacer(),
            _StatusBadge(status: state),
          ]),
          const SizedBox(height: 20),

          // Progress Bar
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(stepLabel,
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600)),
                  Text('${(progress * 100).toInt()}%',
                      style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 13)),
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 8,
                  backgroundColor: Colors.white.withValues(alpha: 0.05),
                  valueColor: const AlwaysStoppedAnimation(AppColors.primary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),

          if (videoUrl != null) ...[
            const Text('Aperçu du Clip',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 12),
            AspectRatio(
              aspectRatio: 9 / 16,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: Colors.black,
                  boxShadow: [
                    BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.2),
                        blurRadius: 20)
                  ],
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    const Icon(Icons.play_circle_fill,
                        size: 70, color: Colors.white70),
                    Positioned(
                        bottom: 20,
                        child: Text('VIDÉO GÉNÉRÉE',
                            style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.5),
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 2))),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            if (state == 'video_pending') ...[
              GradientButton(
                label: 'Publier sur Instagram 🚀',
                onPressed: onPublish,
                isLoading: isLoading,
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: onRefuse,
                  child: const Text('Rejeter ce projet',
                      style: TextStyle(color: Colors.redAccent, fontSize: 13)),
                ),
              ),
            ],
            if (state == 'posted')
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12)),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.check_circle, color: Colors.green, size: 20),
                    SizedBox(width: 12),
                    Text('Production En Ligne !',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, color: Colors.green)),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});
  final String status;
  @override
  Widget build(BuildContext context) {
    Color color = Colors.orange;
    String label = status.replaceAll('_', ' ').toUpperCase();
    if (status == 'posted') color = Colors.green;
    if (status == 'video_pending') color = Colors.blue;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(label,
          style: TextStyle(
              color: color, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});
  final String label;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(label,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
    );
  }
}

class _ChipRow extends StatelessWidget {
  const _ChipRow(
      {required this.options, required this.selected, required this.onSelect});
  final List<String> options;
  final String selected;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      children: options.map((o) {
        final active = o == selected;
        return GestureDetector(
          onTap: () => onSelect(o),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            decoration: BoxDecoration(
              gradient: active ? AppColors.gradientPrimary : null,
              color: active ? null : Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: Colors.white.withValues(alpha: active ? 0 : 0.12)),
            ),
            child: Text(o,
                style: TextStyle(
                  color: active ? Colors.white : AppColors.textMuted,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                )),
          ),
        );
      }).toList(),
    );
  }
}
