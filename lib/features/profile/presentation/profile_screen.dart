/// Profile screen — user info, plan, connected platforms, settings, logout.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../shared/widgets/shared_widgets.dart';
import '../../auth/auth_repository.dart';

final _platformsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final res = await ref.read(dioProvider).get('/platforms/');
  return List<Map<String, dynamic>>.from(res.data);
});

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});
  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _notifications = true;
  bool _darkMode = true;

  Future<void> _togglePlatform(Map<String, dynamic> platform) async {
    try {
      await ref.read(dioProvider).patch('/platforms/${platform['id']}/');
      ref.invalidate(_platformsProvider);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authNotifierProvider);
    final user = auth.valueOrNull;
    final platformsAsync = ref.watch(_platformsProvider);

    return Scaffold(
      body: Stack(
        children: [
          const AnimatedParticleBackground(),
          Column(
            children: [
              const TrendAIAppBar(title: 'Profile', subtitle: 'Manage your account'),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
                  child: Column(
                    children: [
                      // ── Avatar + Name
                      GlassCard(
                        child: Row(
                          children: [
                            Container(
                              width: 64,
                              height: 64,
                              decoration: BoxDecoration(
                                gradient: AppColors.gradientPrimary,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Center(
                                child: Text(
                                  user?.name.isNotEmpty == true ? user!.name[0].toUpperCase() : '?',
                                  style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: Colors.white),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(user?.name ?? 'Loading...',
                                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
                                Text(user?.email ?? '',
                                    style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
                                const SizedBox(height: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                  decoration: BoxDecoration(
                                    gradient: AppColors.gradientPrimary,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text('${(user?.plan ?? 'free').toUpperCase()} Plan',
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 11)),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // ── Connected Platforms
                      GlassCard(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Connected Platforms',
                                style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                            const SizedBox(height: 14),
                            platformsAsync.when(
                              data: (platforms) => Column(
                                children: platforms.map((p) {
                                  final connected = p['connected'] as bool? ?? false;
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: Row(
                                      children: [
                                        PlatformBadge(platform: p['platform_name'] as String),
                                        const Spacer(),
                                        Switch.adaptive(
                                          value: connected,
                                          onChanged: (_) => _togglePlatform(p),
                                          activeColor: AppColors.primary,
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ),
                              loading: () => const Center(child: CircularProgressIndicator()),
                              error: (_, __) => Text('Could not load platforms',
                                  style: TextStyle(color: AppColors.textMuted)),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // ── Settings
                      GlassCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Settings',
                                style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                            const SizedBox(height: 12),
                            _SettingRow(
                              icon: Icons.notifications_rounded,
                              label: 'Notifications',
                              child: Switch.adaptive(
                                value: _notifications,
                                onChanged: (v) => setState(() => _notifications = v),
                                activeColor: AppColors.primary,
                              ),
                            ),
                            const Divider(color: Colors.white10),
                            _SettingRow(
                              icon: Icons.dark_mode_rounded,
                              label: 'Dark Mode',
                              child: Switch.adaptive(
                                value: _darkMode,
                                onChanged: (v) => setState(() => _darkMode = v),
                                activeColor: AppColors.primary,
                              ),
                            ),
                            const Divider(color: Colors.white10),
                            _SettingRow(
                              icon: Icons.data_usage_rounded,
                              label: 'Data Refresh',
                              child: Text('15 min', style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // ── Upgrade to Pro (if free)
                      if (user?.plan == 'free')
                        GlassCard(
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    GradientText('🚀 Upgrade to Pro',
                                        style: const TextStyle(fontWeight: FontWeight.w700)),
                                    const SizedBox(height: 4),
                                    Text('Unlimited scripts, advanced analytics, priority AI',
                                        style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                decoration: BoxDecoration(
                                  gradient: AppColors.gradientPrimary,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Text('Upgrade',
                                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 16),

                      // ── Logout
                      GestureDetector(
                        onTap: () async {
                          await ref.read(authNotifierProvider.notifier).logout();
                          if (context.mounted) context.go('/login');
                        },
                        child: Container(
                          width: double.infinity,
                          height: 56,
                          decoration: BoxDecoration(
                            color: AppColors.error.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Icon(Icons.logout_rounded, color: AppColors.error),
                              SizedBox(width: 10),
                              Text('Log Out', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.w600, fontSize: 15)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          Positioned(
            left: 0, right: 0, bottom: 0,
            child: const TrendAIBottomNav(currentIndex: 4),
          ),
        ],
      ),
    );
  }
}

class _SettingRow extends StatelessWidget {
  const _SettingRow({required this.icon, required this.label, required this.child});
  final IconData icon;
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primary, size: 20),
          const SizedBox(width: 12),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
          const Spacer(),
          child,
        ],
      ),
    );
  }
}
