/// AI Script Generator screen
/// Top section: "Pick a Trend" grid from n8n-scraped YouTube videos
/// Bottom section: prompt + style/duration/platform selectors + generate button
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../shared/widgets/shared_widgets.dart';
import '../../auth/data/models.dart';

// ── Providers
final _generatedScriptProvider = StateProvider<AIScriptModel?>((_) => null);
final _selectedTrendProvider = StateProvider<Map<String, dynamic>?>((_) => null);

final _scrapedVideosProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final res = await ref.read(dioProvider).get('/trends/', queryParameters: {'sort': 'growth'});
  final data = res.data;
  List list = [];
  if (data is Map && data['results'] != null) {
    list = data['results'] as List;
  } else if (data is List) {
    list = data;
  }
  return list.map((e) => e as Map<String, dynamic>).take(10).toList();
});

class AIGeneratorScreen extends ConsumerStatefulWidget {
  const AIGeneratorScreen({super.key});
  @override
  ConsumerState<AIGeneratorScreen> createState() => _AIGeneratorScreenState();
}

class _AIGeneratorScreenState extends ConsumerState<AIGeneratorScreen>
    with SingleTickerProviderStateMixin {
  final _promptCtrl = TextEditingController();
  String _style = 'Informative';
  String _duration = '60s';
  String _platform = 'YouTube';
  bool _loading = false;
  late TabController _tabController;

  final styles = ['Funny', 'Informative', 'Dramatic', 'Casual'];
  final durations = ['30s', '60s', '90s'];
  final platforms = ['TikTok', 'Instagram', 'YouTube', 'Facebook'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _promptCtrl.dispose();
    _tabController.dispose();
    super.dispose();
  }

  void _selectTrend(Map<String, dynamic> trend) {
    ref.read(_selectedTrendProvider.notifier).state = trend;
    final hashtag = (trend['hashtag'] as String? ?? '').replaceAll('#', '');
    _promptCtrl.text = 'Create a viral video about $hashtag — ${trend['views'] ?? ''} views trending';
    _tabController.animateTo(1);
  }

  Future<void> _generate() async {
    if (_promptCtrl.text.trim().isEmpty) return;
    setState(() => _loading = true);
    try {
      final dio = ref.read(dioProvider);
      // Generate script inline for ALL platforms (including YouTube)
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
          SnackBar(content: Text('Generation failed: ${e.toString()}')),
        );
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _publishToYouTube() async {
    if (_promptCtrl.text.trim().isEmpty) return;
    final selected = ref.read(_selectedTrendProvider);
    setState(() => _loading = true);
    try {
      final dio = ref.read(dioProvider);
      await dio.post('/scripts/youtube/generate/', data: {
        'prompt': _promptCtrl.text.trim(),
        'niche': 'tech',
        'trend_id': selected?['id'],
      });
      if (mounted) {
        showDialog(
          context: context,
          builder: (c) => AlertDialog(
            backgroundColor: const Color(0xFF0F111E),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(children: [
              Icon(Icons.auto_awesome_rounded, color: AppColors.primary),
              const SizedBox(width: 8),
              const Text('AI Agent Triggered!', style: TextStyle(color: Colors.white)),
            ]),
            content: const Text(
              'Your YouTube video generation has begun.\nCheck your email to approve and publish the video!',
              style: TextStyle(color: Colors.white70),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(c),
                child: Text('Got it', style: TextStyle(color: AppColors.primary)),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Publish failed: ${e.toString()}')),
        );
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final script = ref.watch(_generatedScriptProvider);
    final selected = ref.watch(_selectedTrendProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Stack(
        children: [
          const AnimatedParticleBackground(),
          Column(
            children: [
              TrendAIAppBar(
                title: 'AI Generator',
                subtitle: '✨ Pick a trend or write your own idea',
              ),
              // Tab bar
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: TabBar(
                  controller: _tabController,
                  indicator: BoxDecoration(
                    gradient: AppColors.gradientPrimary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  labelColor: Colors.white,
                  unselectedLabelColor: AppColors.textMuted,
                  labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                  tabs: const [
                    Tab(text: '🔥 Pick a Trend'),
                    Tab(text: '✏️ Custom Prompt'),
                  ],
                ),
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    // ── Tab 1: Scraped videos grid
                    _ScrapedVideosTab(onSelect: _selectTrend),
                    // ── Tab 2: Custom prompt + generate
                    SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Selected trend badge
                          if (selected != null) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.trending_up_rounded, color: AppColors.primary, size: 16),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Based on: ${selected['hashtag'] ?? ''} · ${selected['views'] ?? ''}',
                                      style: TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: () {
                                      ref.read(_selectedTrendProvider.notifier).state = null;
                                      _promptCtrl.clear();
                                    },
                                    child: Icon(Icons.close_rounded, color: AppColors.primary, size: 16),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 14),
                          ],

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

                          _SectionLabel(label: '🎬 Style'),
                          _ChipRow(options: styles, selected: _style, onSelect: (v) => setState(() => _style = v)),
                          const SizedBox(height: 16),

                          _SectionLabel(label: '⏱ Duration'),
                          _ChipRow(options: durations, selected: _duration, onSelect: (v) => setState(() => _duration = v)),
                          const SizedBox(height: 16),

                          _SectionLabel(label: '📱 Platform'),
                          _ChipRow(options: platforms, selected: _platform, onSelect: (v) => setState(() => _platform = v)),
                          const SizedBox(height: 24),

                          GradientButton(
                            label: 'Generate Script ✨',
                            onPressed: _generate,
                            isLoading: _loading,
                          ),

                          // YouTube publish button
                          if (_platform == 'YouTube') ...[
                            const SizedBox(height: 12),
                            GestureDetector(
                              onTap: _loading ? null : _publishToYouTube,
                              child: Container(
                                height: 52,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFF0000).withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: const Color(0xFFFF0000).withValues(alpha: 0.40),
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: const BoxDecoration(
                                        color: Color(0xFFFF0000),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.play_arrow_rounded,
                                          color: Colors.white, size: 14),
                                    ),
                                    const SizedBox(width: 10),
                                    const Text(
                                      'Publish via AI Agent 🤖',
                                      style: TextStyle(
                                        color: Color(0xFFFF0000),
                                        fontWeight: FontWeight.w700,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Center(
                              child: Text(
                                'Triggers n8n workflow → generates & sends for email approval',
                                style: TextStyle(color: AppColors.textMuted, fontSize: 10),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],

                          if (script != null) ...[
                            const SizedBox(height: 28),
                            _ScriptOutput(script: script),
                          ],
                        ],
                      ),
                    ),
                  ],
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

// ── Scraped Videos Tab
class _ScrapedVideosTab extends ConsumerWidget {
  const _ScrapedVideosTab({required this.onSelect});
  final void Function(Map<String, dynamic>) onSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final videosAsync = ref.watch(_scrapedVideosProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return videosAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.wifi_off_rounded, color: AppColors.textMuted, size: 48),
            const SizedBox(height: 12),
            Text('Could not load trends', style: TextStyle(color: AppColors.textMuted)),
          ],
        ),
      ),
      data: (trends) => trends.isEmpty
          ? Center(
              child: Text('No scraped videos yet. Run your n8n workflow!',
                  style: TextStyle(color: AppColors.textMuted)),
            )
          : RefreshIndicator(
              onRefresh: () async => ref.invalidate(_scrapedVideosProvider),
              child: GridView.builder(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 0.78,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                itemCount: trends.length,
                itemBuilder: (_, i) => _TrendVideoCard(
                  trend: trends[i],
                  onTap: () => onSelect(trends[i]),
                ),
              ),
            ),
    );
  }
}

class _TrendVideoCard extends StatelessWidget {
  const _TrendVideoCard({required this.trend, required this.onTap});
  final Map<String, dynamic> trend;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hashtag = trend['hashtag'] as String? ?? '';
    final views = trend['views'] as String? ?? '0';
    final growth = trend['growth'];
    final thumbUrl = trend['thumbnail_url'] as String?;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.grey.shade200,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thumbnail / gradient placeholder
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: thumbUrl != null && thumbUrl.isNotEmpty
                    ? Image.network(
                        thumbUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _gradientPlaceholder(hashtag),
                      )
                    : _gradientPlaceholder(hashtag),
              ),
            ),
            // Info
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      hashtag,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                    ),
                    Row(
                      children: [
                        Icon(Icons.remove_red_eye_outlined, size: 11, color: AppColors.textMuted),
                        const SizedBox(width: 3),
                        Text(views, style: TextStyle(fontSize: 10, color: AppColors.textMuted)),
                        const Spacer(),
                        if (growth != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.success.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '↑${growth is double ? growth.toStringAsFixed(0) : growth}%',
                              style: TextStyle(
                                  fontSize: 9, color: AppColors.success, fontWeight: FontWeight.w700),
                            ),
                          ),
                      ],
                    ),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      decoration: BoxDecoration(
                        gradient: AppColors.gradientPrimary,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Center(
                        child: Text('Use this trend',
                            style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _gradientPlaceholder(String hashtag) {
    return Container(
      decoration: BoxDecoration(gradient: AppColors.gradientPrimary),
      child: Center(
        child: Text(
          hashtag.isNotEmpty ? hashtag[0].toUpperCase() : '🎬',
          style: const TextStyle(fontSize: 28, color: Colors.white, fontWeight: FontWeight.w800),
        ),
      ),
    );
  }
}

// ── Reusable widgets (kept same as original)
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
