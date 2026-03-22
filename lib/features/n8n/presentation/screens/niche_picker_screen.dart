import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/shared_widgets.dart';
import '../../data/workflow_repository.dart';
import '../../data/workflow_models.dart';

class NichePickerScreen extends ConsumerStatefulWidget {
  const NichePickerScreen({super.key});
  @override
  ConsumerState<NichePickerScreen> createState() => _NichePickerScreenState();
}

class _NichePickerScreenState extends ConsumerState<NichePickerScreen> {
  final _nicheCtrl = TextEditingController();
  String _selectedNiche = 'Tech & Gadgets';
  String? _selectedVideoId;
  bool _loading = false;
  List<TrendingVideo> _trendingVideos = [];

  final defaultNiches = [
    'Tech & Gadgets',
    'Comedy & Skits',
    'Fitness & Health',
    'Food & Recipes',
    'Motivation & Business',
    'Travel & Lifestyle'
  ];

  @override
  void initState() {
    super.initState();
    // Fire and forget: general scrape on open to warm up DB
    ref.read(workflowRepositoryProvider).triggerScrape();
    _fetchTrending();
  }

  Future<void> _triggerAndFetch({required String niche}) async {
    setState(() => _loading = true);
    // 1. Trigger a niche-specific scrape on n8n
    await ref.read(workflowRepositoryProvider).triggerScrape(niche: niche);
    // 2. Wait a few seconds for n8n to scrape + save to DB
    await Future.delayed(const Duration(seconds: 4));
    // 3. Fetch the freshly saved niche videos
    await _fetchTrending(customNiche: niche);
  }

  Future<void> _fetchTrending({String? customNiche}) async {
    setState(() => _loading = true);
    final nicheToSearch = customNiche ?? 
      (_nicheCtrl.text.trim().isNotEmpty ? _nicheCtrl.text.trim() : _selectedNiche);
      
    try {
      final videos = await ref.read(workflowRepositoryProvider).getTrendingVideos(niche: nicheToSearch);
      if (mounted) {
        setState(() {
          _trendingVideos = videos;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load trending videos: $e')),
        );
        setState(() => _loading = false);
      }
    }
  }

  @override
  void dispose() {
    _nicheCtrl.dispose();
    super.dispose();
  }

  Future<void> _startWorkflow() async {
    final niche = _nicheCtrl.text.trim().isNotEmpty ? _nicheCtrl.text.trim() : _selectedNiche;
    if (niche.isEmpty) return;
    if (_selectedVideoId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a reference video first.')),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      await ref.read(workflowRepositoryProvider).startWorkflow(niche, _selectedVideoId!);
      
      // Workflow started in N8N. Now we poll or fetch latest session
      // Wait 2 seconds for n8n to insert the creator_session row
      await Future.delayed(const Duration(seconds: 2));
      
      final sessionId = await ref.read(workflowRepositoryProvider).getLatestSessionId();
      if (sessionId != null && mounted) {
        context.push('/n8n-status/$sessionId');
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Workflow started, but could not get session ID yet. Check your dashboard later.')),
        );
        setState(() => _loading = false);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to start workflow: $e')),
        );
        setState(() => _loading = false);
      }
    }
  }

  Widget _buildVideoGrid() {
    if (_trendingVideos.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Text('No trending videos found. Is the cron job running?', style: TextStyle(color: Colors.white54)),
      );
    }
    return SizedBox(
      height: 180,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _trendingVideos.length,
        itemBuilder: (context, index) {
          final video = _trendingVideos[index];
          final isSelected = video.videoId == _selectedVideoId;
          
          return GestureDetector(
            onTap: () => setState(() => _selectedVideoId = video.videoId),
            child: Container(
              width: 120,
              margin: const EdgeInsets.only(right: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected ? AppColors.primary : Colors.transparent,
                  width: 3,
                ),
                image: DecorationImage(
                  image: NetworkImage(video.thumbnail.isNotEmpty ? video.thumbnail : 'https://placehold.co/120x160/2a2a2a/FFFFFF.png?text=No+Thumb'),
                  fit: BoxFit.cover,
                ),
              ),
              child: isSelected 
                ? Container(
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: const Center(child: Icon(Icons.check_circle, color: Colors.greenAccent, size: 32)),
                  )
                : const SizedBox(),
            ),
          );
        },
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
              const TrendAIAppBar(title: 'Fully Automated Agent', subtitle: 'Powered by n8n & PostgreSQL'),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      GlassCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(children: [
                              Icon(Icons.video_library_rounded, color: AppColors.primary),
                              SizedBox(width: 8),
                              Text('1. Choose Reference Video', style: TextStyle(fontWeight: FontWeight.w700)),
                            ]),
                            const SizedBox(height: 12),
                            const Text(
                              'Select a trending TikTok video for the agent to base the new script upon.',
                              style: TextStyle(color: AppColors.textMuted, fontSize: 13, height: 1.5),
                            ),
                            const SizedBox(height: 16),
                            _loading && _trendingVideos.isEmpty
                              ? const Center(child: CircularProgressIndicator())
                              : _buildVideoGrid(),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      GlassCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(children: [
                              Icon(Icons.category_rounded, color: AppColors.primary),
                              SizedBox(width: 8),
                              Text('2. Pick a Target Niche', style: TextStyle(fontWeight: FontWeight.w700)),
                            ]),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: defaultNiches.map((n) {
                                final active = n == _selectedNiche && _nicheCtrl.text.isEmpty;
                                return GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _selectedNiche = n;
                                      _nicheCtrl.clear();
                                      _selectedVideoId = null;
                                    });
                                    _triggerAndFetch(niche: n);
                                  },
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                    decoration: BoxDecoration(
                                      gradient: active ? AppColors.gradientPrimary : null,
                                      color: active ? null : Colors.white.withValues(alpha: 0.06),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(color: Colors.white.withValues(alpha: active ? 0 : 0.12)),
                                    ),
                                    child: Text(n, style: TextStyle(
                                      color: active ? Colors.white : AppColors.textLight,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                    )),
                                  ),
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: 24),
                            const Text('Or type your own:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                            const SizedBox(height: 10),
                            TextField(
                              controller: _nicheCtrl,
                              decoration: const InputDecoration(
                                hintText: 'e.g. Vintage Watches',
                                border: OutlineInputBorder(),
                                suffixIcon: Icon(Icons.search),
                              ),
                              onChanged: (v) => setState(() {}),
                              onSubmitted: (v) {
                                setState(() => _selectedVideoId = null);
                                _triggerAndFetch(niche: v);
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),
                      GradientButton(
                        label: 'Start AI Agent 🤖',
                        onPressed: _startWorkflow,
                        isLoading: _loading,
                      ),
                      const SizedBox(height: 40),
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
