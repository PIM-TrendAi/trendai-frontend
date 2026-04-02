import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/network/dio_client.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/shared_widgets.dart';
import '../providers/workflow_provider.dart';

class ScriptReviewScreen extends ConsumerStatefulWidget {
  const ScriptReviewScreen({super.key});

  @override
  ConsumerState<ScriptReviewScreen> createState() => _ScriptReviewScreenState();
}

class _ScriptReviewScreenState extends ConsumerState<ScriptReviewScreen> {
  Timer? _pollTimer;
  int _pollAttempts = 0;
  int _sessionLookupAttempts = 0;
  bool _pollingFailed = false;
  bool _resolvingSession = false;

  static const int _maxPollAttempts = 40;
  static const int _maxSessionLookupAttempts = 10;

  @override
  void initState() {
    super.initState();
    // If script is empty on arrival, poll Django until it's ready.
    WidgetsBinding.instance.addPostFrameCallback((_) => _pollIfNeeded());
  }

  @override
  void didUpdateWidget(covariant ScriptReviewScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    _pollIfNeeded();
  }

  void _pollIfNeeded() {
    final state = ref.read(workflowProvider);
    final hasScript =
        state.scriptContent != null && state.scriptContent!.isNotEmpty;
    final hasSession = state.sessionId != null && state.sessionId!.isNotEmpty;

    if (hasScript) {
      _pollTimer?.cancel();
      _pollTimer = null;
      if (_pollingFailed && mounted) {
        setState(() => _pollingFailed = false);
      }
      return;
    }

    if (!hasScript && hasSession) {
      // Avoid restarting the timer on every rebuild.
      if (_pollTimer == null || !_pollTimer!.isActive) {
        _pollAttempts = 0;
        if (_pollingFailed && mounted) {
          setState(() => _pollingFailed = false);
        } else {
          _pollingFailed = false;
        }
        _startPolling(state.sessionId!);
      }
      return;
    }

    // If start endpoint did not return session_id, recover it from latest session.
    if (!hasScript &&
        !hasSession &&
        state.status != WorkflowStatus.generatingScript) {
      if (_sessionLookupAttempts < _maxSessionLookupAttempts) {
        if (_pollingFailed && mounted) {
          setState(() => _pollingFailed = false);
        }
        unawaited(_resolveLatestSession());
        return;
      }

      if (!_pollingFailed && mounted) {
        setState(() => _pollingFailed = true);
      }
    }
  }

  Future<void> _resolveLatestSession() async {
    if (_resolvingSession || !mounted) return;

    setState(() => _resolvingSession = true);
    _sessionLookupAttempts += 1;

    try {
      final dio = ref.read(dioProvider);
      final platform = ref.read(workflowProvider).platform ?? 'tiktok';
      final res = await dio.get(
        '/n8n/sessions/latest/',
        queryParameters: {'platform': platform},
      );
      final data = res.data as Map<String, dynamic>;
      final sessionId =
          (data['session_id'] ?? data['sessionId'])?.toString().trim();

      if (sessionId != null && sessionId.isNotEmpty) {
        ref.read(workflowProvider.notifier).setSessionId(sessionId);
        if (mounted) {
          setState(() {
            _pollingFailed = false;
          });
        }
        _startPolling(sessionId);
        return;
      }

      if (mounted && _sessionLookupAttempts < _maxSessionLookupAttempts) {
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) _pollIfNeeded();
        });
      }
    } catch (_) {
      if (mounted && _sessionLookupAttempts < _maxSessionLookupAttempts) {
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) _pollIfNeeded();
        });
      }
    } finally {
      if (mounted) {
        setState(() => _resolvingSession = false);
      }
    }
  }

  void _startPolling(String sessionId) {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (timer) async {
      if (!mounted) {
        timer.cancel();
        return;
      }
      _pollAttempts += 1;
      if (_pollAttempts >= _maxPollAttempts) {
        timer.cancel();
        _pollTimer = null;
        if (mounted) {
          setState(() => _pollingFailed = true);
        }
        return;
      }

      try {
        final dio = ref.read(dioProvider);
        final res = await dio.get('/n8n/sessions/$sessionId/');
        final data = res.data as Map<String, dynamic>;
        final script =
            (data['script_content'] ?? data['scriptContent'])?.toString();
        if (script != null && script.isNotEmpty) {
          timer.cancel();
          _pollTimer = null;
          if (mounted) {
            setState(() => _pollingFailed = false);
          }
          ref.read(workflowProvider.notifier).setScriptContent(script);
        }
      } catch (_) {
        if (_pollAttempts >= 8) {
          timer.cancel();
          _pollTimer = null;
          if (mounted) {
            setState(() => _pollingFailed = true);
          }
        }
      }
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(workflowProvider);

    // Session and script can arrive after this screen is mounted.
    WidgetsBinding.instance.addPostFrameCallback((_) => _pollIfNeeded());

    final isLoading = state.status == WorkflowStatus.generatingScript ||
        state.status == WorkflowStatus.generatingVideo;
    final hasScript =
        state.scriptContent != null && state.scriptContent!.isNotEmpty;
    final hasSession = state.sessionId != null && state.sessionId!.isNotEmpty;
    final isPolling = !hasScript &&
        (_resolvingSession ||
            hasSession && state.status != WorkflowStatus.generatingScript) &&
        !_pollingFailed;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Review Script'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        leading: IconButton(
          icon:
              const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () {
            _pollTimer?.cancel();
            ref.read(workflowProvider.notifier).reset();
            context.go('/video-picker');
          },
        ),
      ),
      body: Stack(
        children: [
          const AnimatedParticleBackground(count: 8),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
                  // Header badge
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      gradient: AppColors.gradientPrimary,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text('AI Generated Script',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600)),
                  ),
                  const SizedBox(height: 16),

                  // Script content
                  Expanded(
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.10)),
                      ),
                      child: (state.status == WorkflowStatus.generatingScript ||
                              isPolling)
                          ? Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const CircularProgressIndicator(),
                                  const SizedBox(height: 16),
                                  Text(
                                    state.status ==
                                            WorkflowStatus.generatingScript
                                        ? 'Regenerating script...'
                                        : 'Generating your script...',
                                    style: const TextStyle(
                                        color: AppColors.textMuted),
                                  ),
                                ],
                              ),
                            )
                          : (!hasScript && _pollingFailed)
                              ? Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        hasSession
                                            ? 'Could not load the generated script.'
                                            : 'Could not find a workflow session yet. Please retry.',
                                        style: const TextStyle(
                                            color: AppColors.textMuted),
                                        textAlign: TextAlign.center,
                                      ),
                                      const SizedBox(height: 10),
                                      TextButton(
                                        onPressed: _pollIfNeeded,
                                        child: const Text('Retry'),
                                      ),
                                    ],
                                  ),
                                )
                              : SingleChildScrollView(
                                  child: Text(
                                    state.scriptContent ?? '',
                                    style: const TextStyle(
                                        fontSize: 15, height: 1.6),
                                  ),
                                ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Approve / Decline buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: (isLoading || isPolling)
                              ? null
                              : () async {
                                  await ref
                                      .read(workflowProvider.notifier)
                                      .declineScript();
                                },
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('Regenerate'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            side: const BorderSide(
                                color: AppColors.textMuted, width: 1),
                            foregroundColor: AppColors.textMuted,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: GradientButton(
                          label: 'Approve & Generate Video',
                          onPressed: (isLoading || isPolling)
                              ? () {}
                              : () async {
                                  await ref
                                      .read(workflowProvider.notifier)
                                      .approveScript();
                                  if (context.mounted) {
                                    context.go('/video-generation');
                                  }
                                },
                          isLoading:
                              state.status == WorkflowStatus.generatingVideo,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
