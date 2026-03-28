// Category Selection screen — user picks up to 5 content categories after signup.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/storage/secure_storage.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/shared_widgets.dart';
import '../../auth_repository.dart';

const _categories = [
  ('entertainment', '🎭', 'Entertainment'),
  ('education', '📚', 'Education'),
  ('business', '💼', 'Business'),
  ('finance', '💰', 'Finance'),
  ('fitness', '🏋️', 'Fitness'),
  ('motivation', '🧠', 'Motivation'),
  ('gaming', '🎮', 'Gaming'),
  ('art', '🎨', 'Art & Design'),
  ('fashion', '👗', 'Fashion'),
  ('cooking', '🍳', 'Cooking'),
  ('travel', '🌍', 'Travel'),
  ('tech', '🧪', 'Tech'),
  ('podcast', '🎤', 'Podcast'),
  ('news', '📰', 'News'),
  ('storytelling', '📖', 'Storytelling'),
];

class CategorySelectionScreen extends ConsumerStatefulWidget {
  const CategorySelectionScreen({super.key, this.fromProfile = false});
  final bool fromProfile;
  @override
  ConsumerState<CategorySelectionScreen> createState() =>
      _CategorySelectionScreenState();
}

class _CategorySelectionScreenState
    extends ConsumerState<CategorySelectionScreen> {
  final Set<String> _selected = {};
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadSaved();
  }

  Future<void> _loadSaved() async {
    final niches = await ref.read(secureStorageProvider).readCreatorNiches();
    if (niches.isNotEmpty && mounted) {
      setState(() => _selected.addAll(niches));
    }
  }

  Future<void> _continue() async {
    if (_selected.isEmpty) return;
    setState(() => _saving = true);
    await ref.read(authNotifierProvider.notifier).saveNiches(_selected.toList());
    if (!mounted) return;
    if (widget.fromProfile) {
      context.pop();
    } else {
      context.go('/dashboard');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const AnimatedParticleBackground(),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Back button
                      GestureDetector(
                        onTap: () => context.canPop() ? context.pop() : context.go('/dashboard'),
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                          ),
                          child: const Icon(Icons.arrow_back_ios_new, size: 16, color: Colors.white),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Progress bar (step 2 of 3)
                      Row(
                        children: List.generate(3, (i) => Expanded(
                          child: Container(
                            height: 4,
                            margin: const EdgeInsets.symmetric(horizontal: 2),
                            decoration: BoxDecoration(
                              color: i <= 1 ? AppColors.primary : Colors.white12,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        )),
                      ),
                      const SizedBox(height: 20),
                      Text('Define Your Content Universe 🌐',
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
                      const SizedBox(height: 6),
                      const Text('Select the content you create (up to 5)',
                          style: TextStyle(color: AppColors.textMuted)),
                      if (_selected.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            gradient: AppColors.gradientPrimary,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text('${_selected.length}/5 selected',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ],
                  ),
                ),
                Expanded(
                  child: GridView.builder(
                    padding: const EdgeInsets.all(20),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 1.6,
                    ),
                    itemCount: _categories.length,
                    itemBuilder: (ctx, i) {
                      final (id, emoji, title) = _categories[i];
                      final selected = _selected.contains(id);
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            if (selected) {
                              _selected.remove(id);
                            } else if (_selected.length < 5) {
                              _selected.add(id);
                            }
                          });
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          decoration: BoxDecoration(
                            gradient: selected ? AppColors.gradientPrimary : null,
                            color: selected ? null : Colors.white.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: selected ? Colors.transparent : Colors.white.withValues(alpha: 0.10),
                              width: 1.5,
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(emoji, style: const TextStyle(fontSize: 28)),
                              const SizedBox(height: 4),
                              Text(title,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: selected ? Colors.white : null,
                                    fontSize: 12,
                                  )),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
                  child: GradientButton(
                    label: 'Continue',
                    onPressed: _continue,
                    isLoading: _saving,
                    enabled: _selected.isNotEmpty,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
