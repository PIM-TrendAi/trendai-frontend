/// AI Script & Video Generator screen — prompt + style/duration/platform selectors,
/// calls n8n workflow for video generation or standard AI for scripts.
library;

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/network/dio_client.dart';
import '../../../shared/widgets/shared_widgets.dart';

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

  // Platform selection
  late Set<String> _selectedPlatforms;

  final styles = ['Funny', 'Informative', 'Dramatic', 'Casual'];
  final durations = ['30s', '60s', '90s'];
  final platforms = ['TikTok', 'Instagram', 'YouTube', 'Facebook'];

  @override
  void initState() {
    super.initState();
    // Initialise platform selection from route param (default tiktok)
    final initial = (widget.platform ?? 'tiktok').toLowerCase();
    _selectedPlatforms = {initial};
    // Clear any stale session state from a previous platform
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(_videoGenerationStatusProvider.notifier).state = null;
      // Auto-start workflow for non-TikTok when arriving with a selected video
      final platform = (widget.platform ?? 'tiktok').toLowerCase();
      if (widget.selectedVideoId != null &&
          widget.selectedVideoId!.isNotEmpty &&
          platform != 'tiktok') {
        _startGeneration();
      }
    });
    // Load the latest session on page open so the script shows immediately
    _loadLatestSession();
  }

  Future<void> _loadLatestSession() async {
    // If opened from a specific reel selection, don't restore a previous session —
    // the user intends to start fresh for this reel.
    if (widget.selectedVideoId != null && widget.selectedVideoId!.isNotEmpty) return;

    try {
      final dio = ref.read(dioProvider);
      final currentPlatform = (widget.platform ?? 'tiktok').toLowerCase();
      final res = await dio.get('/n8n/sessions/latest/', queryParameters: {
        'platform': currentPlatform,
      });
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
      // Primary platform drives the n8n workflow
      final primaryPlatform = _selectedPlatforms.isNotEmpty
          ? _selectedPlatforms.first
          : (widget.platform ?? 'tiktok');

      final niche = widget.niche ?? 'General';
      // custom_prompt is the optional creator angle — the backend builds
      // the full algo-optimised prompt around it automatically for TikTok.
      final res = await dio.post('/n8n/start/', data: {
        'niche': niche,
        'selected_video_id': widget.selectedVideoId ?? 'test_video_123',
        'custom_prompt': '', // backend injects algo formula; leave blank for default
        'style': 'Informative',
        'duration': '60s',
        'platform': primaryPlatform,
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
    final currentPlatform = (widget.platform ?? 'tiktok').toLowerCase();
    try {
      final res = await dio.get('/n8n/sessions/latest/', queryParameters: {
        'platform': currentPlatform,
      });
      if (res.data['session_id'] != null) {
        _currentSessionId = res.data['session_id'];
      }
    } catch (_) {}

    _pollingTimer = Timer.periodic(const Duration(seconds: 3), (timer) async {
      if (!mounted) { timer.cancel(); return; }

      // If we still don't have a session ID, keep looking
      if (_currentSessionId == null) {
        try {
          final res = await dio.get('/n8n/sessions/latest/', queryParameters: {
            'platform': currentPlatform,
          });
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
      final targets = _selectedPlatforms.isNotEmpty
          ? _selectedPlatforms.toList()
          : [widget.platform ?? 'tiktok'];

      // Only TikTok and Instagram have live n8n publish webhooks
      const _supported = {'tiktok', 'instagram'};

      // Post to every supported selected platform
      for (final platform in targets.where((p) => _supported.contains(p))) {
        await dio.post('/n8n/approve/video/', data: {
          'session_id': status['session_id'],
          'video_id': status['video_id'],
          'approved': true,
          'platform': platform,
        });
      }
      _startPolling(); // Poll again to see completion
      if (mounted) {
        final names = targets.map((p) => p[0].toUpperCase() + p.substring(1)).join(', ');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Publication lancée sur $names ! 🚀')),
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
                      // ── Platform selector ─────────────────────────────
                      _PlatformSelector(
                        selected: _selectedPlatforms,
                        onChanged: (updated) =>
                            setState(() => _selectedPlatforms = updated),
                      ),
                      const SizedBox(height: 20),
                      // Show generated script above the subject header
                      if (videoStatus != null &&
                          videoStatus['script_content'] != null) ...[
                        _StructuredScriptCard(
                          scriptContent: videoStatus['script_content'] as String,
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

                      if (videoStatus != null) ...[
                        const SizedBox(height: 24),
                        _VideoStatusCard(
                          status: videoStatus,
                          onPublish: _publishVideo,
                          onRefuse: _refuseVideo,
                          isLoading: _loading,
                          selectedPlatforms: _selectedPlatforms,
                        ),
                      ],

                      // ── TikTok Algo Tips — shown whenever TikTok is a target
                      if (_selectedPlatforms.contains('tiktok')) ...[
                        const SizedBox(height: 24),
                        _TikTokAlgoCard(
                          scriptContent: videoStatus?['script_content'] as String?,
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
  const _VideoStatusCard({
    required this.status,
    required this.onPublish,
    required this.onRefuse,
    required this.isLoading,
    this.selectedPlatforms = const {},
  });
  final Map<String, dynamic> status;
  final VoidCallback onPublish;
  final VoidCallback onRefuse;
  final bool isLoading;
  final Set<String> selectedPlatforms;

  String _publishLabel() {
    if (selectedPlatforms.isEmpty) return 'Publier 🚀';
    if (selectedPlatforms.length == 4) {
      return 'Publier sur toutes les plateformes 🚀';
    }
    final names = selectedPlatforms
        .map((p) => p[0].toUpperCase() + p.substring(1))
        .join(' + ');
    return 'Publier sur $names 🚀';
  }

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
                label: _publishLabel(),
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

// ── Structured Script Viewer ────────────────────────────────────────────────
/// Parses the algo-optimised script (sections labelled [HOOK]/[BODY]/[CTA]/[LOOP]/[HASHTAGS])
/// and displays each as a colour-coded card with its algo purpose.
class _StructuredScriptCard extends StatelessWidget {
  const _StructuredScriptCard({required this.scriptContent});
  final String scriptContent;

  static const _sections = [
    (
      label: 'HOOK',
      emoji: '🎣',
      color: Color(0xFFFF0050),
      reason: '0–3 s • stop the scroll',
    ),
    (
      label: 'BODY',
      emoji: '🎬',
      color: Color(0xFF7C3AED),
      reason: 'core value • keeps watch time',
    ),
    (
      label: 'CTA',
      emoji: '💬',
      color: Color(0xFF0EA5E9),
      reason: 'engagement bait • boosts comments/saves',
    ),
    (
      label: 'LOOP',
      emoji: '🔄',
      color: Color(0xFF10B981),
      reason: 'seamless replay • counts as re-watch',
    ),
    (
      label: 'HASHTAGS',
      emoji: '#️⃣',
      color: Color(0xFFF59E0B),
      reason: '1 mega + 2 niche + 1 micro + 1 trending',
    ),
  ];

  /// Extracts the text between two consecutive section labels.
  static String? _extract(String raw, String label) {
    final pattern = RegExp(
      r'\[' + label + r'\]\s*([\s\S]*?)(?=\[\w|$)',
      caseSensitive: false,
    );
    final m = pattern.firstMatch(raw);
    return m?.group(1)?.trim();
  }

  @override
  Widget build(BuildContext context) {
    // Check for at least one labelled section to switch to structured view.
    final hasStructure =
        RegExp(r'\[(HOOK|BODY|CTA|LOOP|HASHTAGS)\]', caseSensitive: false)
            .hasMatch(scriptContent);

    if (!hasStructure) {
      // Fallback: plain text (old-style scripts)
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(children: [
              Icon(Icons.auto_awesome, size: 16, color: AppColors.primary),
              SizedBox(width: 8),
              Text('SCRIPT GÉNÉRÉ',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold,
                      letterSpacing: 1.2, color: AppColors.primary)),
            ]),
            const SizedBox(height: 14),
            Text(scriptContent,
                style: const TextStyle(fontSize: 14, height: 1.6, color: Colors.white70)),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        const Row(children: [
          Icon(Icons.auto_awesome, size: 16, color: AppColors.primary),
          SizedBox(width: 8),
          Text('ALGO-OPTIMISED SCRIPT',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold,
                  letterSpacing: 1.2, color: AppColors.primary)),
        ]),
        const SizedBox(height: 12),
        ..._sections.map((s) {
          final text = _extract(scriptContent, s.label);
          if (text == null || text.isEmpty) return const SizedBox.shrink();
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              decoration: BoxDecoration(
                color: s.color.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: s.color.withValues(alpha: 0.30)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Text(s.emoji, style: const TextStyle(fontSize: 13)),
                    const SizedBox(width: 6),
                    Text(s.label,
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800,
                            letterSpacing: 1.1, color: s.color)),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: s.color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(s.reason,
                          style: TextStyle(fontSize: 9, color: s.color,
                              fontWeight: FontWeight.w600)),
                    ),
                  ]),
                  const SizedBox(height: 8),
                  Text(text,
                      style: const TextStyle(fontSize: 13, height: 1.55,
                          color: Colors.white, fontWeight: FontWeight.w400)),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}

// ── TikTok Algorithm Tips Card ─────────────────────────────────────────────
/// Displayed whenever TikTok is among the selected publish targets.
/// Shows: hook quality analysis, best posting times, and key algo tips.
class _TikTokAlgoCard extends StatelessWidget {
  const _TikTokAlgoCard({this.scriptContent});
  final String? scriptContent;

  static const _postingWindows = [
    ('6–9 AM', '🌅 Morning'),
    ('12–2 PM', '☀️ Lunch'),
    ('7–11 PM', '🌙 Prime'),
  ];

  static const _tips = [
    (Icons.timer_outlined,        '🎣 Hook first 3 s',    'Open with a bold statement, question, or shock. Viewers decide in 3 seconds.'),
    (Icons.loop_rounded,          '🔄 Seamless loop',     'End where you began so TikTok counts re-watches as bonus completions.'),
    (Icons.music_note_rounded,    '🎵 Trending audio',    "Pick a sound from TikTok's trending list to ride its FYP wave."),
    (Icons.tag_rounded,           '#️⃣ 3–5 hashtags',      'Mix 1 mega-tag + 2 niche tags + 1 micro-tag. No spam-only #fyp.'),
    (Icons.chat_bubble_outline,   '💬 Ask a question',    "Caption CTAs ('Comment below!') spike engagement in the first hour."),
    (Icons.bar_chart_rounded,     '📈 First-hour push',   'TikTok tests your video with ~300 users. High ER → 3 K → 30 K+ batches.'),
  ];

  /// Rates the hook (first sentence) and returns (label, color).
  static (String, Color) _hookRating(String hook) {
    final h = hook.toLowerCase();
    int score = 0;
    if (h.contains('?')) score++;
    if (RegExp(r'^(stop|wait|you|this|why|how|what|here|pov|imagine)').hasMatch(h)) score++;
    if (hook.length < 90) score++;
    if (score >= 3) return ('✅ Strong hook', const Color(0xFF4CAF50));
    if (score == 2) return ('⚠️ Good hook — add a question or bolder opener', Colors.orange);
    return ('❌ Weak hook — rewrite the opening to grab attention', const Color(0xFFEF5350));
  }

  @override
  Widget build(BuildContext context) {
    String? hook;
    String? hookRatingLabel;
    Color hookRatingColor = Colors.white54;
    if (scriptContent != null && scriptContent!.isNotEmpty) {
      // Prefer the labelled [HOOK] section produced by the algo-optimised prompt.
      // Fall back to the first sentence if the script is unstructured.
      final hookMatch = RegExp(r'\[HOOK\]\s*([\s\S]*?)(?=\[|$)', caseSensitive: false)
          .firstMatch(scriptContent!);
      if (hookMatch != null) {
        hook = hookMatch.group(1)?.trim() ?? '';
      } else {
        final parts = scriptContent!.split(RegExp(r'[.!?\n]'));
        hook = parts.firstWhere((s) => s.trim().length > 10, orElse: () => '').trim();
      }
      if (hook != null && hook.length > 110) hook = '${hook.substring(0, 110)}…';
      if (hook != null && hook.isNotEmpty) {
        final (label, color) = _hookRating(hook);
        hookRatingLabel = label;
        hookRatingColor = color;
      }
    }

    const tikTokRed = Color(0xFFFF0050);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: tikTokRed.withValues(alpha: 0.30)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: tikTokRed.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.bolt_rounded, color: tikTokRed, size: 14),
            ),
            const SizedBox(width: 10),
            const Text(
              'TIKTOK ALGO TIPS',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.3, color: tikTokRed),
            ),
          ]),

          // Hook quality card (only when script is generated)
          if (hook != null && hook.isNotEmpty && hookRatingLabel != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: hookRatingColor.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: hookRatingColor.withValues(alpha: 0.25)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Your Opening Hook',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white70)),
                  const SizedBox(height: 6),
                  Text('"$hook"',
                      style: const TextStyle(fontSize: 12, color: Colors.white60, fontStyle: FontStyle.italic, height: 1.4)),
                  const SizedBox(height: 8),
                  Text(hookRatingLabel,
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: hookRatingColor)),
                ],
              ),
            ),
          ],

          // Best posting times
          const SizedBox(height: 18),
          const Text('Best Posting Times (audience ET)',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white60)),
          const SizedBox(height: 10),
          Row(
            children: _postingWindows.map((w) {
              final isLast = w == _postingWindows.last;
              return Expanded(
                child: Container(
                  margin: EdgeInsets.only(right: isLast ? 0 : 8),
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                  decoration: BoxDecoration(
                    color: tikTokRed.withValues(alpha: 0.09),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: tikTokRed.withValues(alpha: 0.22)),
                  ),
                  child: Column(
                    children: [
                      Text(w.$2, style: const TextStyle(fontSize: 13)),
                      const SizedBox(height: 3),
                      Text(w.$1,
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white)),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),

          // Algo tips list
          const SizedBox(height: 18),
          const Text('Algorithm Checklist',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white60)),
          const SizedBox(height: 10),
          ..._tips.map((t) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 28, height: 28,
                  decoration: BoxDecoration(
                    color: tikTokRed.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: Icon(t.$1, size: 14, color: tikTokRed),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(t.$2,
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
                      const SizedBox(height: 2),
                      Text(t.$3,
                          style: const TextStyle(fontSize: 11, color: Colors.white54, height: 1.35)),
                    ],
                  ),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }
}

// ── Platform multi-select chip row ──────────────────────────────────────────
class _PlatformSelector extends StatelessWidget {
  const _PlatformSelector({required this.selected, required this.onChanged});
  final Set<String> selected;
  final ValueChanged<Set<String>> onChanged;

  static const _platforms = [
    ('tiktok',    'TikTok',    Color(0xFFFF0050), Icons.music_note_rounded),
    ('instagram', 'Instagram', Color(0xFFE1306C), Icons.camera_alt_rounded),
    ('youtube',   'YouTube',   Color(0xFFFF0000), Icons.play_circle_fill_rounded),
    ('facebook',  'Facebook',  Color(0xFF1877F2), Icons.facebook_rounded),
  ];

  void _toggle(String key) {
    final next = Set<String>.from(selected);
    if (key == 'all') {
      if (next.length == _platforms.length) {
        next.clear();
      } else {
        next.addAll(_platforms.map((p) => p.$1));
      }
    } else {
      next.contains(key) ? next.remove(key) : next.add(key);
    }
    onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final allSelected = selected.length == _platforms.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.send_rounded, size: 15, color: AppColors.primary),
            const SizedBox(width: 8),
            const Text(
              'PUBLIER SUR',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
                color: AppColors.primary,
              ),
            ),
            const Spacer(),
            // "All" toggle
            GestureDetector(
              onTap: () => _toggle('all'),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  gradient: allSelected ? AppColors.gradientPrimary : null,
                  color: allSelected ? null : Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: allSelected
                        ? Colors.transparent
                        : Colors.white.withValues(alpha: 0.15),
                  ),
                ),
                child: Text(
                  'Tout',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: allSelected ? Colors.white : AppColors.textMuted,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: _platforms.map((meta) {
            final key = meta.$1;
            final label = meta.$2;
            final color = meta.$3;
            final icon = meta.$4;
            final active = selected.contains(key);
            return GestureDetector(
              onTap: () => _toggle(key),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                decoration: BoxDecoration(
                  color: active
                      ? color.withValues(alpha: 0.18)
                      : Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: active
                        ? color.withValues(alpha: 0.7)
                        : Colors.white.withValues(alpha: 0.1),
                    width: active ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 16, color: active ? color : Colors.white38),
                    const SizedBox(width: 7),
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: active ? color : AppColors.textMuted,
                      ),
                    ),
                    if (active) ...[
                      const SizedBox(width: 6),
                      Icon(Icons.check_circle_rounded, size: 14, color: color),
                    ],
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
