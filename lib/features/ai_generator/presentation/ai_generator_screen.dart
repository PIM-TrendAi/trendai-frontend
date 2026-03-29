/// AI Generator screen — Pick a trend (Facebook Reels grid) + prompt + Generate Script.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../shared/widgets/shared_widgets.dart';
import '../../auth/data/models.dart';

// ── Providers
final _fbReelsProvider = FutureProvider.autoDispose<List<FacebookReelModel>>((ref) async {
  final dio = ref.read(dioProvider);
  final res = await dio.get('/trends/reels/');
  final data = res.data;
  final List<dynamic> raw = (data is Map) ? (data['results'] as List? ?? []) : (data as List? ?? []);
  return raw.map((e) {
    try { return FacebookReelModel.fromJson(e as Map<String, dynamic>); }
    catch (_) { return null; }
  }).whereType<FacebookReelModel>().where((r) => r.reelId != null).toList();
});

class AIGeneratorScreen extends ConsumerStatefulWidget {
  const AIGeneratorScreen({super.key});
  @override
  ConsumerState<AIGeneratorScreen> createState() => _AIGeneratorScreenState();
}

class _AIGeneratorScreenState extends ConsumerState<AIGeneratorScreen> {
  final _promptCtrl = TextEditingController();
  FacebookReelModel? _selectedTrend;
  bool _loading = false;

  @override
  void dispose() {
    _promptCtrl.dispose();
    super.dispose();
  }

  Future<void> _generateScript() async {
    if (_promptCtrl.text.trim().isEmpty && _selectedTrend == null) return;
    setState(() => _loading = true);
    try {
      final dio = ref.read(dioProvider);
      final reelId = _selectedTrend != null && _selectedTrend!.reelId != null
          ? _selectedTrend!.reelId!
          : 'app-gen-${DateTime.now().millisecondsSinceEpoch}';

      final promptText = _promptCtrl.text.trim();
      final defaultPrompt = _selectedTrend?.text ?? 'Create a viral Facebook video';

      final niche = _selectedTrend?.niche ?? 'Facebook';
      final finalPrompt = promptText.isNotEmpty ? promptText : defaultPrompt;

      await dio.post('/scripts/videos/generate/', data: {
        'reel_id': reelId,
        'prompt': finalPrompt,
        'niche': niche,
      });

      if (mounted) {
        _promptCtrl.clear();
        setState(() => _selectedTrend = null);
        context.push('/script-review', extra: {
          'reel_id': reelId,
          'prompt': finalPrompt,
          'niche': niche,
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to trigger generation: ${e.toString()}'),
            backgroundColor: const Color(0xFFE17055),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final reelsAsync = ref.watch(_fbReelsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Stack(
        children: [
          if (isDark) const AnimatedParticleBackground(),
          Column(
            children: [
              const TrendAIAppBar(title: 'Pick a Trend', subtitle: 'Select a reel • Write your prompt'),

              Expanded(
                child: reelsAsync.when(
                  data: (reels) => _buildContent(context, reels, isDark),
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (_, __) => _buildContent(context, [], isDark),
                ),
              ),
            ],
          ),

          // ── Generate Script button pinned above bottom nav
          Positioned(
            left: 20, right: 20, bottom: 100,
            child: GradientButton(
              label: 'Generate Script',
              onPressed: _generateScript,
              isLoading: _loading,
            ),
          ),

          Positioned(
            left: 0, right: 0, bottom: 0,
            child: const TrendAIBottomNav(currentIndex: 2),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context, List<FacebookReelModel> reels, bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 180),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Prompt field
          Text(
            'Your prompt',
            style: TextStyle(color: AppColors.textMuted, fontSize: 13, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.6), width: 1.5),
              color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.white,
            ),
            child: TextField(
              controller: _promptCtrl,
              maxLines: 3,
              style: const TextStyle(fontSize: 15),
              decoration: InputDecoration(
                hintText: 'e.g. Focus on morning routines for busy people',
                hintStyle: TextStyle(color: AppColors.textMuted.withValues(alpha: 0.6), fontSize: 14),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.all(16),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // ── Trend grid
          if (reels.isNotEmpty) ...[
            Text(
              'Trending Facebook Reels',
              style: TextStyle(color: AppColors.textMuted, fontSize: 13, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 12),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.82,
              ),
              itemCount: reels.length > 6 ? 6 : reels.length,
              itemBuilder: (_, i) => _ReelCard(
                reel: reels[i],
                isSelected: _selectedTrend?.id == reels[i].id,
                onTap: () => setState(() {
                  _selectedTrend = (_selectedTrend?.id == reels[i].id) ? null : reels[i];
                }),
              ),
            ),
          ] else ...[
            // Empty state – show placeholder cards
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.82,
              ),
              itemCount: 4,
              itemBuilder: (_, i) => _PlaceholderReelCard(index: i),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Reel card (real data)
class _ReelCard extends StatelessWidget {
  const _ReelCard({required this.reel, required this.isSelected, required this.onTap});
  final FacebookReelModel reel;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // Create a compact views text
    String viewsText = '${reel.playCount} views';
    if (reel.playCount >= 1000000) {
      viewsText = '${(reel.playCount / 1000000).toStringAsFixed(1)}M views';
    } else if (reel.playCount >= 1000) {
      viewsText = '${(reel.playCount / 1000).toStringAsFixed(1)}K views';
    }

    // Extract first hashtag or use default
    String displayTag = '#Trending';
    if (reel.text != null && reel.text!.contains('#')) {
      final tags = reel.text!.split(' ').where((w) => w.startsWith('#')).toList();
      if (tags.isNotEmpty) displayTag = tags.first;
    } else if (reel.niche != null) {
      displayTag = '#${reel.niche}';
    }
    
    final hasImage = reel.thumbnailUrl != null && reel.thumbnailUrl!.isNotEmpty;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppColors.primary : Colors.transparent,
            width: isSelected ? 2.5 : 0,
          ),
          color: const Color(0xFF0F111E),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Gradient always visible as base — visible while image loads or on error
              _buildGradientFallback(reel.id),

              // Network image on top of gradient (transparent until loaded)
              if (hasImage)
                Image.network(
                  reel.thumbnailUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),

              // Dark overlay for text readability
              Container(color: Colors.black.withValues(alpha: 0.35)),

              // Play button
              const Center(
                child: Icon(Icons.play_circle_outline_rounded, color: Colors.white, size: 36),
              ),

              // Selected checkmark
              if (isSelected)
                Positioned(
                  top: 8, left: 8,
                  child: Container(
                    width: 22, height: 22,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.check, color: Colors.white, size: 14),
                  ),
                ),

              // Bottom info
              Positioned(
                left: 0, right: 0, bottom: 0,
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.transparent, Colors.black.withValues(alpha: 0.9)],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        displayTag,
                        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        viewsText,
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 10, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGradientFallback(int id) {
    // Pick deterministic gradient colors based on ID
    final colors = [
      [const Color(0xFF6C5CE7), const Color(0xFF00C6FF)],
      [const Color(0xFFFF7675), const Color(0xFFD63031)],
      [const Color(0xFF00B894), const Color(0xFF00CEC9)],
      [const Color(0xFFE84393), const Color(0xFFFD79A8)],
    ];
    final colorPair = colors[id % colors.length];
    
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: colorPair,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
    );
  }
}

// ── Placeholder reel card when no trends loaded
class _PlaceholderReelCard extends StatelessWidget {
  const _PlaceholderReelCard({required this.index});
  final int index;

  static const _labels = ['#trending #viral', '#lifestyle', '#tech #viral', '#motivation'];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: const Color(0xFF1A1C2E),
      ),
      child: Stack(
        children: [
          const Center(
            child: Icon(Icons.play_circle_outline_rounded, color: Colors.white54, size: 36),
          ),
          Positioned(
            left: 0, right: 0, bottom: 0,
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.transparent, Colors.black.withValues(alpha: 0.8)],
                  begin: Alignment.topCenter, end: Alignment.bottomCenter,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_labels[index % _labels.length],
                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text('0 views', style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 10)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
