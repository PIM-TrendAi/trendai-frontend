/// AI Script Generator screen — prompt + style/duration/platform selectors,
/// calls POST /api/scripts/generate/ and displays the structured result.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../shared/widgets/shared_widgets.dart';
import '../../auth/data/models.dart';

final _generatedScriptProvider = StateProvider<AIScriptModel?>((_) => null);

class AIGeneratorScreen extends ConsumerStatefulWidget {
  const AIGeneratorScreen({super.key});
  @override
  ConsumerState<AIGeneratorScreen> createState() => _AIGeneratorScreenState();
}

class _AIGeneratorScreenState extends ConsumerState<AIGeneratorScreen> {
  final _promptCtrl = TextEditingController();
  String _style = 'Informative';
  String _duration = '60s';
  String _platform = 'TikTok';
  bool _loading = false;

  final styles = ['Funny', 'Informative', 'Dramatic', 'Casual'];
  final durations = ['30s', '60s', '90s'];
  final platforms = ['TikTok', 'Instagram', 'YouTube', 'Facebook'];

  @override
  void dispose() {
    _promptCtrl.dispose();
    super.dispose();
  }

  Future<void> _generate() async {
    if (_promptCtrl.text.trim().isEmpty) return;
    setState(() => _loading = true);
    try {
      final dio = ref.read(dioProvider);
      final res = await dio.post('/scripts/generate/', data: {
        'prompt': _promptCtrl.text.trim(),
        'style': _style,
        'duration': _duration,
        'platform': _platform,
      });
      final script = AIScriptModel.fromJson(res.data as Map<String, dynamic>);
      ref.read(_generatedScriptProvider.notifier).state = script;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Script generation failed. Is the server running?')),
        );
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final script = ref.watch(_generatedScriptProvider);

    return Scaffold(
      body: Stack(
        children: [
          const AnimatedParticleBackground(),
          Column(
            children: [
              TrendAIAppBar(title: 'AI Script Generator', subtitle: 'Powered by TrendAI'),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Idea input
                      GlassCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              Icon(Icons.lightbulb_outline_rounded, color: AppColors.primary),
                              const SizedBox(width: 8),
                              const Text('Your Idea', style: TextStyle(fontWeight: FontWeight.w700)),
                            ]),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _promptCtrl,
                              maxLines: 4,
                              decoration: const InputDecoration(
                                hintText: 'Describe what you want to create a script about...',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Style
                      _SectionLabel(label: '🎬 Style'),
                      _ChipRow(options: styles, selected: _style, onSelect: (v) => setState(() => _style = v)),
                      const SizedBox(height: 16),

                      // Duration
                      _SectionLabel(label: '⏱ Duration'),
                      _ChipRow(options: durations, selected: _duration, onSelect: (v) => setState(() => _duration = v)),
                      const SizedBox(height: 16),

                      // Platform
                      _SectionLabel(label: '📱 Platform'),
                      _ChipRow(options: platforms, selected: _platform, onSelect: (v) => setState(() => _platform = v)),
                      const SizedBox(height: 24),

                      // Generate button
                      GradientButton(
                        label: 'Generate Script ✨',
                        onPressed: _generate,
                        isLoading: _loading,
                      ),

                      // Generated script output
                      if (script != null) ...[
                        const SizedBox(height: 28),
                        _ScriptOutput(script: script),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
          Positioned(
            left: 0, right: 0, bottom: 0,
            child: const TrendAIBottomNav(currentIndex: 2),
          ),
        ],
      ),
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
      child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
    );
  }
}

class _ChipRow extends StatelessWidget {
  const _ChipRow({required this.options, required this.selected, required this.onSelect});
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
              border: Border.all(color: Colors.white.withValues(alpha: active ? 0 : 0.12)),
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

class _ScriptOutput extends StatelessWidget {
  const _ScriptOutput({required this.script});
  final AIScriptModel script;

  void _copy(BuildContext context, String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Copied to clipboard!'), duration: Duration(seconds: 1)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Icon(Icons.auto_awesome_rounded, color: AppColors.primary),
          const SizedBox(width: 8),
          GradientText('Your Generated Script', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
        ]),
        const SizedBox(height: 16),
        _Block(label: '🎣 Hook', content: script.hook, context: context, onCopy: _copy),
        const SizedBox(height: 12),
        _Block(label: '📝 Script', content: script.script, context: context, onCopy: _copy),
        const SizedBox(height: 12),
        _Block(label: '📣 Call-to-Action', content: script.cta, context: context, onCopy: _copy),
        const SizedBox(height: 16),
        GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('#️⃣ Hashtags', style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: script.hashtags.map((h) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(h, style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600, fontSize: 12)),
                )).toList(),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Block extends StatelessWidget {
  const _Block({required this.label, required this.content, required this.context, required this.onCopy});
  final String label;
  final String content;
  final BuildContext context;
  final void Function(BuildContext, String) onCopy;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
              IconButton(
                icon: const Icon(Icons.copy_rounded, size: 18),
                onPressed: () => onCopy(context, content),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(content, style: TextStyle(color: AppColors.textMuted.withValues(alpha: 0.9), fontSize: 14, height: 1.6)),
        ],
      ),
    );
  }
}
