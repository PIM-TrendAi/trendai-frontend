import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../shared/widgets/shared_widgets.dart';
import '../../../auth/data/models.dart';
import '../../../video_workflow/data/models/workflow_models.dart';
import '../../../video_workflow/data/n8n_repository.dart';
import '../../../auth/auth_repository.dart';
import 'package:video_player/video_player.dart';
import 'package:flutter/services.dart';

final _selectedNicheProvider = StateProvider<String>((ref) => 'ALL');

final _threadsDraftsProvider = FutureProvider.autoDispose<List<CreatorVideoModel>>((ref) async {
  final user = ref.watch(authNotifierProvider).valueOrNull;
  if (user == null) return [];
  final videos = await ref.read(n8nRepositoryProvider).fetchMyVideos(user.creatorId);
  return videos.where((v) => (v.niche.toLowerCase() == 'threads' || v.sessionId.startsWith('threads_')) && v.status == 'draft').toList();
});

final _threadsPostsProvider = FutureProvider<List<ThreadsPostModel>>((ref) async {
  final niche = ref.watch(_selectedNicheProvider);
  final dio = ref.read(dioProvider);
  
  String url = '/trends/threads-posts/';
  if (niche != 'ALL') {
    url += '?niche=${Uri.encodeComponent(niche)}';
  }
  
  final res = await dio.get(url);
  final list = res.data['results'] as List? ?? res.data as List;
  return list.map((e) => ThreadsPostModel.fromJson(e as Map<String, dynamic>)).toList();
});

class ThreadsEngineScreen extends ConsumerStatefulWidget {
  const ThreadsEngineScreen({super.key});

  @override
  ConsumerState<ThreadsEngineScreen> createState() => _ThreadsEngineScreenState();
}

class _ThreadsEngineScreenState extends ConsumerState<ThreadsEngineScreen> {
  int _tabIndex = 0;
  bool _isScraping = false;
  Timer? _pollTimer;
  int _pollCount = 0;
  static const int _maxPollAttempts = 20;

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  static const List<String> _niches = [
    'ALL',
    'Fitness',
    'Tech',
    'Business',
    'Luxe',
    'Cuisine',
    'Humour',
  ];

  Future<void> _triggerScrape() async {
    final selectedNiche = ref.read(_selectedNicheProvider);
    final nicheToScrape = selectedNiche == 'ALL' ? 'General' : selectedNiche;

    setState(() {
      _isScraping = true;
      _pollCount = 0;
    });
    try {
      final dio = ref.read(dioProvider);
      await dio.post('/trends/threads-scrape/', data: {"niche": nicheToScrape});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Scraping Threads "$nicheToScrape" lancé...'),
            backgroundColor: AppColors.primary,
          ),
        );
      }

      ref.invalidate(_threadsPostsProvider);

      _pollTimer?.cancel();
      _pollTimer = Timer.periodic(const Duration(seconds: 4), (timer) async {
        if (!mounted) {
          timer.cancel();
          return;
        }
        _pollCount++;

        if (_pollCount >= _maxPollAttempts) {
          timer.cancel();
          if (mounted) setState(() => _isScraping = false);
          return;
        }

        try {
          final newPosts = await ref.refresh(_threadsPostsProvider.future);
          if (newPosts.isNotEmpty && newPosts.any((p) => p.postId != 'undefined')) {
            timer.cancel();
            if (mounted) setState(() => _isScraping = false);
          }
        } catch (_) {}
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isScraping = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final postsAsync = ref.watch(_threadsPostsProvider);

    return Scaffold(
      body: Stack(
        children: [
          const AnimatedParticleBackground(),
          Column(
            children: [
              const TrendAIAppBar(
                title: 'Threads Engine',
                subtitle: 'Viral Video Discovery',
                showBack: true,
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  child: Column(
                    children: [
                      // Tab Switcher
                      Container(
                        margin: const EdgeInsets.only(bottom: 25),
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white10,
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: () => setState(() => _tabIndex = 0),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  decoration: BoxDecoration(
                                    color: _tabIndex == 0 ? AppColors.primary : Colors.transparent,
                                    borderRadius: BorderRadius.circular(30),
                                    boxShadow: _tabIndex == 0 ? [BoxShadow(color: AppColors.primary.withValues(alpha: 0.3), blurRadius: 10)] : [],
                                  ),
                                  child: Center(
                                    child: Text('Scraper', style: TextStyle(fontWeight: FontWeight.bold, color: _tabIndex == 0 ? Colors.white : AppColors.textMuted)),
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              child: GestureDetector(
                                onTap: () => setState(() => _tabIndex = 1),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  decoration: BoxDecoration(
                                    color: _tabIndex == 1 ? AppColors.primary : Colors.transparent,
                                    borderRadius: BorderRadius.circular(30),
                                    boxShadow: _tabIndex == 1 ? [BoxShadow(color: AppColors.primary.withValues(alpha: 0.3), blurRadius: 10)] : [],
                                  ),
                                  child: Center(
                                    child: Text('Mes Brouillons', style: TextStyle(fontWeight: FontWeight.bold, color: _tabIndex == 1 ? Colors.white : AppColors.textMuted)),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      if (_tabIndex == 0) ...[
                        // Header Card
                      GlassCard(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: Colors.white10,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(Icons.auto_graph_rounded, color: AppColors.primary),
                                ),
                                const SizedBox(width: 15),
                                const Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Threads Viral Trends',
                                          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
                                      Text('Scrapez les vidéos les plus virales en un clic.',
                                          style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            SizedBox(
                              width: double.infinity,
                              child: GradientButton(
                                label: _isScraping ? 'Scraping en cours...' : 'Lancer le Scraping 🚀',
                                onPressed: _isScraping ? () {} : () => _triggerScrape(),
                                isLoading: _isScraping,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 25),

                      // Niche Selector
                      _buildNicheSelector(),
                      const SizedBox(height: 5),

                      // Stats Row
                      const SizedBox(height: 30),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildStatItem('Vidéos total', postsAsync.whenData((p) => p.length.toString()).value ?? '0'),
                          _buildStatItem('Niche active', ref.watch(_selectedNicheProvider)),
                          _buildStatItem('Status', _isScraping ? 'Scanning' : 'Ready'),
                        ],
                      ),
                      const SizedBox(height: 25),

                      // Grid Results
                      postsAsync.when(
                        data: (posts) => posts.isEmpty
                            ? _buildEmptyState()
                            : GridView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  crossAxisSpacing: 15,
                                  mainAxisSpacing: 15,
                                  childAspectRatio: 0.7,
                                ),
                                itemCount: posts.length,
                                itemBuilder: (context, index) => _ThreadVideoCard(post: posts[index]),
                              ),
                        loading: () => const Center(child: CircularProgressIndicator()),
                        error: (e, _) => const Text('Erreur de chargement'),
                      ),
                      ] else ...[
                        _buildDraftsSection(),
                      ],
                      const SizedBox(height: 100),
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

  Widget _buildStatItem(String label, String value) {
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        children: [
          Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 10)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        ],
      ),
    );
  }

  Widget _buildNicheSelector() {
    final selectedNiche = ref.watch(_selectedNicheProvider);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: _niches.map((niche) {
          final isSelected = selectedNiche == niche;
          return Padding(
            padding: const EdgeInsets.only(right: 10),
            child: GestureDetector(
              onTap: () {
                ref.read(_selectedNicheProvider.notifier).state = niche;
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  gradient: isSelected
                      ? AppColors.gradientPrimary
                      : const LinearGradient(colors: [Colors.white10, Colors.white10]),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(
                    color: isSelected ? Colors.transparent : Colors.white24,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          )
                        ]
                      : [],
                ),
                child: Text(
                  niche,
                  style: TextStyle(
                    color: isSelected ? Colors.white : AppColors.textMuted,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.only(top: 40),
        child: Column(
          children: [
            Icon(Icons.video_library_outlined, size: 64, color: Colors.white.withValues(alpha: 0.1)),
            const SizedBox(height: 16),
            const Text('Aucune vidéo trouvée', style: TextStyle(color: AppColors.textMuted)),
          ],
        ),
      ),
    );
  }

  Widget _buildDraftsSection() {
    final draftsAsync = ref.watch(_threadsDraftsProvider);
    return draftsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => const Center(child: Text('Erreur de chargement', style: TextStyle(color: AppColors.error))),
      data: (drafts) {
        if (drafts.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.only(top: 40),
              child: Column(
                children: [
                  Icon(Icons.drafts_outlined, size: 64, color: Colors.white.withValues(alpha: 0.1)),
                  const SizedBox(height: 16),
                  const Text('Aucun brouillon trouvé', style: TextStyle(color: AppColors.textMuted)),
                ],
              ),
            ),
          );
        }
        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: drafts.length,
          itemBuilder: (context, index) => _DraftVideoCard(video: drafts[index]),
        );
      },
    );
  }
}

class _ThreadVideoCard extends StatelessWidget {
  const _ThreadVideoCard({required this.post});
  final ThreadsPostModel post;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push(
        '/ai-generator?niche=${Uri.encodeComponent(post.niche ?? "Threads")}&selectedVideoId=${post.postId}&platform=threads',
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Thumbnail
            (post.thumbnailUrl != null && post.thumbnailUrl!.isNotEmpty)
                ? Image.network(post.thumbnailUrl!, fit: BoxFit.cover)
                : Container(color: Colors.white.withValues(alpha: 0.05)),
            
            // Overlay Gradient
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black87],
                ),
              ),
            ),

            // Video Badge
            if (post.hasVideo)
              Positioned(
                top: 10,
                right: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00C853),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text('VIDEO', style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold)),
                ),
              ),

            // Play Button
            const Center(
              child: Icon(Icons.play_circle_fill_rounded, color: Colors.white, size: 48),
            ),

            // Info
            Positioned(
              left: 12,
              right: 12,
              bottom: 12,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '@${post.username ?? "user"}',
                    style: const TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    post.text ?? 'Threads video',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontSize: 11, height: 1.2),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.favorite_rounded, color: Colors.white70, size: 12),
                      const SizedBox(width: 4),
                      Text(post.likeCount.toString(), style: const TextStyle(color: Colors.white70, fontSize: 10)),
                      const SizedBox(width: 12),
                      const Icon(Icons.category_rounded, color: Colors.white70, size: 12),
                      const SizedBox(width: 4),
                      Text(post.niche ?? 'Niche', style: const TextStyle(color: Colors.white70, fontSize: 10)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DraftVideoCard extends StatelessWidget {
  const _DraftVideoCard({required this.video});
  final CreatorVideoModel video;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: video.videoUrl.isNotEmpty ? () => showDialog(
        context: context,
        barrierColor: Colors.black,
        builder: (_) => _DraftVideoPlayerDialog(url: video.videoUrl),
      ) : null,
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0F111E) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.grey.shade200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (video.videoUrl.isNotEmpty)
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                child: SizedBox(
                  height: 160,
                  width: double.infinity,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Container(color: Colors.black),
                      const Center(child: Icon(Icons.play_circle_fill_rounded, color: Colors.white, size: 48)),
                    ],
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.grey.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.grey.withValues(alpha: 0.4)),
                        ),
                        child: const Text('Brouillon', style: TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(video.scriptContent.isNotEmpty ? video.scriptContent : 'Vidéo générée (Threads)', maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, color: isDark ? Colors.white70 : Colors.black87)),
                  const SizedBox(height: 10),
                  Text('Session: ${video.sessionId}', style: const TextStyle(color: AppColors.textMuted, fontSize: 10)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DraftVideoPlayerDialog extends StatefulWidget {
  const _DraftVideoPlayerDialog({required this.url});
  final String url;
  @override
  State<_DraftVideoPlayerDialog> createState() => _DraftVideoPlayerDialogState();
}

class _DraftVideoPlayerDialogState extends State<_DraftVideoPlayerDialog> {
  late VideoPlayerController _ctrl;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp, DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
    _ctrl = VideoPlayerController.networkUrl(Uri.parse(widget.url));
    _ctrl.initialize().then((_) {
      if (mounted) {
        setState(() => _ready = true);
        _ctrl.play();
        _ctrl.setLooping(true);
      }
    });
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Center(
            child: _ready ? GestureDetector(
              onTap: () => setState(() { _ctrl.value.isPlaying ? _ctrl.pause() : _ctrl.play(); }),
              child: AspectRatio(aspectRatio: _ctrl.value.aspectRatio, child: VideoPlayer(_ctrl)),
            ) : const CircularProgressIndicator(color: Colors.white),
          ),
          if (_ready) Positioned(bottom: 48, left: 16, right: 16, child: VideoProgressIndicator(_ctrl, allowScrubbing: true, colors: const VideoProgressColors(playedColor: AppColors.primary, bufferedColor: Colors.white24, backgroundColor: Colors.white12))),
          Positioned(
            top: MediaQuery.of(context).padding.top + 8, left: 12,
            child: GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.close_rounded, color: Colors.white, size: 22)),
            ),
          ),
        ],
      ),
    );
  }
}
