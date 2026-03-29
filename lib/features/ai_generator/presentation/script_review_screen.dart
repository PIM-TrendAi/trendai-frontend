/// Script Review Screen — polls for the generated script, lets user accept or reject.
/// If rejected, re-triggers generation and resets polling.
/// If accepted, navigates to VideoReviewScreen.
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../shared/widgets/shared_widgets.dart';

class ScriptReviewScreen extends ConsumerStatefulWidget {
  final String reelId;
  final String prompt;
  final String niche;

  const ScriptReviewScreen({
    super.key,
    required this.reelId,
    required this.prompt,
    required this.niche,
  });

  @override
  ConsumerState<ScriptReviewScreen> createState() => _ScriptReviewScreenState();
}

class _ScriptReviewScreenState extends ConsumerState<ScriptReviewScreen> {
  Timer? _timer;
  DateTime _triggerTime = DateTime.now();
  Map<String, dynamic>? _videoRecord;
  Map<String, dynamic>? _scriptData;
  String _status = 'polling'; // polling | ready | rejecting | approving | error
  String? _errorMsg;
  int _pollCount = 0;
  static const _maxPolls = 40; // 40 × 3s = 2 min timeout

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
    // Use UTC with a 20s back-buffer to account for server clock drift
    _triggerTime = DateTime.now().toUtc().subtract(const Duration(seconds: 20));
    _pollCount = 0;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 3), (_) => _poll());
    _poll(); // immediate first check
  }

  Future<void> _poll() async {
    if (_status == 'rejecting' || _status == 'approving') return;
    _pollCount++;
    if (_pollCount > _maxPolls) {
      _timer?.cancel();
      if (mounted) setState(() { _status = 'error'; _errorMsg = 'Timeout: la génération a pris trop de temps. Vérifiez n8n.'; });
      return;
    }

    try {
      final dio = ref.read(dioProvider);
      final res = await dio.get('/scripts/videos/');
      final dynamic data = res.data;
      final List<dynamic> all = data is List ? data : (data['results'] as List? ?? []);

      // Find the most recent record matching our reel_id created after trigger (UTC comparison)
      Map<String, dynamic>? found;
      for (final item in all) {
        final map = item as Map<String, dynamic>;
        final rid = map['reel_id'] as String? ?? map['reel'] as String? ?? '';
        if (rid != widget.reelId) continue;
        final createdStr = map['created_at'] as String? ?? '';
        if (createdStr.isNotEmpty) {
          final created = DateTime.tryParse(createdStr)?.toUtc();
          if (created != null && created.isAfter(_triggerTime)) {
            found = map;
            break; // list is ordered by -created_at, first match is newest
          }
        }
      }

      if (found != null) {
        final scriptRaw = found['script'] as String? ?? '';
        Map<String, dynamic>? scriptJson;
        if (scriptRaw.isNotEmpty) {
          try {
            final cleaned = scriptRaw.replaceAll('```json', '').replaceAll('```', '').trim();
            scriptJson = json.decode(cleaned) as Map<String, dynamic>;
          } catch (_) {}
        }
        _timer?.cancel();
        if (mounted) {
          setState(() {
            _videoRecord = found;
            _scriptData = scriptJson;
            _status = 'ready';
          });
        }
      }
    } catch (_) {
      // ignore transient errors, keep polling
    }
  }

  Future<void> _reject() async {
    if (_videoRecord == null) return;
    setState(() => _status = 'rejecting');
    try {
      final dio = ref.read(dioProvider);
      final id = _videoRecord!['id'];
      await dio.post('/scripts/videos/$id/reject/');
      // Re-trigger generation
      await dio.post('/scripts/videos/generate/', data: {
        'reel_id': widget.reelId,
        'prompt': widget.prompt,
        'niche': widget.niche,
      });
    } catch (_) {}
    if (mounted) {
      setState(() {
        _videoRecord = null;
        _scriptData = null;
        _status = 'polling';
      });
      _startPolling();
    }
  }

  void _approve() {
    if (_videoRecord == null) return;
    final id = _videoRecord!['id'] as int;
    context.push('/video-review/$id');
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
                            const Text('Script Review',
                                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.auto_awesome, size: 12, color: AppColors.primary),
                                const SizedBox(width: 4),
                                Text('Review your AI-generated script',
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
        return _buildScriptReady(isDark);
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
              child: CircularProgressIndicator(
                strokeWidth: 3,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 28),
            Text(
              'Generating your script...',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Gemini AI is analyzing your reel\nand crafting a video script.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textMuted, fontSize: 14, height: 1.6),
            ),
            const SizedBox(height: 32),
            _StepIndicator(step: _pollCount, maxSteps: _maxPolls),
          ],
        ),
      ),
    );
  }

  Widget _buildRejecting(bool isDark) {
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
            const SizedBox(height: 24),
            Text('Regenerating script...',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : Colors.black87)),
          ],
        ),
      ),
    );
  }

  Widget _buildScriptReady(bool isDark) {
    final title = _scriptData?['title'] as String? ??
        _videoRecord?['script_text'] as String? ??
        'Generated Video';
    final videoPrompt = _scriptData?['video_prompt'] as String? ??
        _videoRecord?['script_text'] as String? ??
        '';
    final negPrompt = _scriptData?['negative_prompt'] as String? ?? 'blur, dark, realistic';
    final niche = _videoRecord?['niche'] as String? ?? widget.niche;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                colors: [AppColors.primary.withValues(alpha: 0.8), AppColors.accent.withValues(alpha: 0.7)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                    const SizedBox(width: 8),
                    const Text('Script Ready!',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text('#$niche',
                          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(title,
                    style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800, height: 1.3)),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ── Video prompt
          _SectionCard(
            isDark: isDark,
            icon: Icons.videocam_rounded,
            label: 'Video Prompt',
            child: Text(
              videoPrompt.isNotEmpty ? videoPrompt : 'No video prompt available.',
              style: TextStyle(
                fontSize: 15,
                color: isDark ? Colors.white.withValues(alpha: 0.9) : Colors.black87,
                height: 1.6,
              ),
            ),
          ),
          const SizedBox(height: 14),

          // ── Negative prompt
          _SectionCard(
            isDark: isDark,
            icon: Icons.block_rounded,
            label: 'Negative Prompt',
            child: Text(
              negPrompt,
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textMuted,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
          const SizedBox(height: 14),

          // ── Source reel info
          _SectionCard(
            isDark: isDark,
            icon: Icons.info_outline_rounded,
            label: 'Source',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _InfoRow(label: 'Reel ID', value: widget.reelId),
                const SizedBox(height: 4),
                _InfoRow(label: 'Your prompt', value: widget.prompt.isNotEmpty ? widget.prompt : '(default)'),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // ── Action buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _reject,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Regenerate'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                    side: BorderSide(color: AppColors.error.withValues(alpha: 0.6)),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                flex: 2,
                child: GradientButton(
                  label: 'Approve Script',
                  onPressed: _approve,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Center(
            child: Text(
              'Approving will start video generation',
              style: TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
          ),
        ],
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
            Text(_errorMsg ?? 'Something went wrong.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 24),
            GradientButton(
              label: 'Try Again',
              onPressed: () {
                setState(() { _status = 'polling'; _errorMsg = null; });
                _startPolling();
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ── Helpers

class _StepIndicator extends StatelessWidget {
  const _StepIndicator({required this.step, required this.maxSteps});
  final int step;
  final int maxSteps;

  @override
  Widget build(BuildContext context) {
    final pct = (step / maxSteps).clamp(0.0, 1.0);
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: pct,
            minHeight: 4,
            backgroundColor: AppColors.primary.withValues(alpha: 0.15),
            valueColor: AlwaysStoppedAnimation(AppColors.primary),
          ),
        ),
        const SizedBox(height: 8),
        Text('${(pct * 100).toInt()}%',
            style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.isDark,
    required this.icon,
    required this.label,
    required this.child,
  });
  final bool isDark;
  final IconData icon;
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade50,
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.grey.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: AppColors.primary),
              const SizedBox(width: 6),
              Text(label,
                  style: TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5)),
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        children: [
          TextSpan(
            text: '$label: ',
            style: TextStyle(color: AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.w600),
          ),
          TextSpan(
            text: value,
            style: TextStyle(color: AppColors.textMuted, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
