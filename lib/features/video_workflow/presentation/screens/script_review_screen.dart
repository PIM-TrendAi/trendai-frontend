import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/shared_widgets.dart';
import '../providers/workflow_provider.dart';

class ScriptReviewScreen extends ConsumerWidget {
  const ScriptReviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(workflowProvider);
    final isLoading = state.status == WorkflowStatus.generatingScript ||
        state.status == WorkflowStatus.generatingVideo;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Review Script'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
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
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 6),
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
                      child: state.status == WorkflowStatus.generatingScript
                          ? const Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  CircularProgressIndicator(),
                                  SizedBox(height: 16),
                                  Text('Regenerating script...',
                                      style: TextStyle(
                                          color: AppColors.textMuted)),
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
                      // Decline
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: isLoading
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
                      // Approve
                      Expanded(
                        flex: 2,
                        child: GradientButton(
                          label: 'Approve & Generate Video',
                          onPressed: isLoading
                              ? () {}
                              : () async {
                                  await ref
                                      .read(workflowProvider.notifier)
                                      .approveScript();
                                  if (context.mounted) {
                                    context.go('/video-generation');
                                  }
                                },
                          isLoading: state.status ==
                              WorkflowStatus.generatingVideo,
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
