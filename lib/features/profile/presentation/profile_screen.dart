// Profile screen — user info, plan, connected platforms, settings, logout.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/network/dio_client.dart';
import '../../../../core/storage/secure_storage.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/theme_provider.dart';
import '../../../../shared/widgets/shared_widgets.dart';
import '../../auth/auth_repository.dart';
import '../../video_workflow/data/n8n_repository.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});
  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _notifications = true;
  bool _tiktokLoading = false;
  bool _instagramLoading = false;
  bool _instagramConnected = false;
  final _scrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    _checkInstagramStatus();
  }

  Future<void> _checkInstagramStatus() async {
    try {
      final dio = ref.read(dioProvider);
      final res = await dio.get('/platforms/instagram/status/');
      if (mounted) setState(() => _instagramConnected = res.data['connected'] == true);
    } catch (_) {}
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authNotifierProvider);
    final user = auth.valueOrNull;
    final tiktokConnected = user?.tiktokConnected ?? false;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final themeMode = ref.watch(themeModeProvider);

    return Scaffold(
      body: Stack(
        children: [
          if (isDark) const AnimatedParticleBackground(),
          Column(
            children: [
              const TrendAIAppBar(title: 'Profile', subtitle: 'Manage your account • Preferences'),
              Expanded(
                child: SingleChildScrollView(
                  controller: _scrollCtrl,
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // ── Avatar + Name Card
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF0F111E) : Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: isDark
                              ? [BoxShadow(color: AppColors.primary.withValues(alpha: 0.15), blurRadius: 40)]
                              : [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 20)],
                          border: Border.all(
                            color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.transparent,
                          ),
                        ),
                        child: Column(
                          children: [
                            Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                gradient: AppColors.gradientPrimary,
                                shape: BoxShape.circle,
                                border: Border.all(color: AppColors.primary.withValues(alpha: 0.3), width: 3),
                                boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.3), blurRadius: 20)],
                              ),
                              child: Center(
                                child: Text(
                                  user?.name.isNotEmpty == true ? user!.name[0].toUpperCase() : '?',
                                  style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w700, color: Colors.white),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(user?.name ?? 'Loading...',
                                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 20)),
                            const SizedBox(height: 4),
                            Text(user?.email ?? '',
                                style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // ── Pro Plan Card
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.grey.shade200),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AppColors.warning,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [BoxShadow(color: AppColors.warning.withValues(alpha: 0.3), blurRadius: 10)],
                              ),
                              child: const Icon(Icons.workspace_premium_rounded, color: Colors.white, size: 24),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Text('Pro Plan', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(color: AppColors.success, borderRadius: BorderRadius.circular(10)),
                                        child: const Text('Active', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  const Text('Unlimited access', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                color: isDark ? Colors.white.withValues(alpha: 0.15) : AppColors.backgroundLight,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text('Upgrade', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: isDark ? Colors.white : AppColors.textLight)),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // ── Connected Platforms
                      Text('Connected Platforms',
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 12),
                      Column(
                        children: [
                          _PlatformCard(
                            name: 'TikTok',
                            isConnected: tiktokConnected,
                            iconColor: AppColors.tikTok,
                            iconData: Icons.link_rounded,
                            isPrimaryAction: !tiktokConnected,
                            isLoading: _tiktokLoading,
                            onAction: () async {
                              if (_tiktokLoading) return;
                              setState(() => _tiktokLoading = true);
                              try {
                                if (tiktokConnected) {
                                  // ── Disconnect
                                  await ref.read(dioProvider).post('/platforms/tiktok/disconnect/');
                                  await ref.read(secureStorageProvider).setTikTokConnected(false);
                                  ref.read(authNotifierProvider.notifier).setTikTokConnected(connected: false);
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('TikTok disconnected.')),
                                    );
                                  }
                                } else {
                                  // ── Connect
                                  final creatorId = user?.creatorId ?? '';
                                  final authUrl = await ref
                                      .read(n8nRepositoryProvider)
                                      .startTikTokOAuth(creatorId);
                                  final uri = Uri.parse(authUrl);
                                  if (await canLaunchUrl(uri)) {
                                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('Authorize TikTok in your browser, then return here.'),
                                          duration: Duration(seconds: 4),
                                        ),
                                      );
                                    }
                                  }
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Error: $e')),
                                  );
                                }
                              } finally {
                                if (mounted) setState(() => _tiktokLoading = false);
                              }
                            },
                          ),
                          const SizedBox(height: 8),
                          _PlatformCard(
                            name: 'Instagram',
                            isConnected: _instagramConnected,
                            iconColor: const Color(0xFFE1306C),
                            iconData: Icons.camera_alt_rounded,
                            isPrimaryAction: !_instagramConnected,
                            isLoading: _instagramLoading,
                            onAction: () async {
                              if (_instagramLoading) return;
                              setState(() => _instagramLoading = true);
                              try {
                                final dio = ref.read(dioProvider);
                                if (_instagramConnected) {
                                  await dio.post('/platforms/instagram/disconnect/');
                                  setState(() => _instagramConnected = false);
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Instagram disconnected.')),
                                    );
                                  }
                                } else {
                                  await dio.post('/platforms/instagram/connect/');
                                  setState(() => _instagramConnected = true);
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Instagram connected! 🎉')),
                                    );
                                  }
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Error: $e')),
                                  );
                                }
                              } finally {
                                if (mounted) setState(() => _instagramLoading = false);
                              }
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Text('Settings',
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 12),
                      Container(
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.grey.shade200),
                        ),
                        child: Column(
                          children: [
                            _SettingRow(
                              icon: Icons.notifications_none_rounded,
                              label: 'Notifications',
                              child: Switch.adaptive(
                                value: _notifications,
                                onChanged: (v) => setState(() => _notifications = v),
                                activeThumbColor: AppColors.primary,
                              ),
                            ),
                            Divider(color: isDark ? Colors.white10 : Colors.grey.shade200, height: 1),
                            _SettingRow(
                              icon: Icons.light_mode_outlined,
                              label: 'Dark Mode',
                              child: Switch.adaptive(
                                value: themeMode == ThemeMode.dark,
                                onChanged: (v) {
                                  ref.read(themeModeProvider.notifier).state = v ? ThemeMode.dark : ThemeMode.light;
                                },
                                activeThumbColor: AppColors.primary,
                              ),
                            ),
                            Divider(color: isDark ? Colors.white10 : Colors.grey.shade200, height: 1),
                            _SettingRow(
                              icon: Icons.sync_rounded,
                              label: 'Data Refresh Interval',
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: isDark ? Colors.white.withValues(alpha: 0.05) : AppColors.backgroundLight,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text('15 min', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                                    SizedBox(width: 4),
                                    Icon(Icons.keyboard_arrow_down_rounded, size: 16),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // ── My Videos
                      GestureDetector(
                        onTap: () => context.push('/my-videos'),
                        child: Container(
                          width: double.infinity,
                          height: 56,
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.primary.withValues(alpha: 0.12) : AppColors.primary.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.video_library_rounded, color: AppColors.primary),
                              SizedBox(width: 10),
                              Text('My Videos', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600, fontSize: 15)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // ── Change Niche
                      GestureDetector(
                        onTap: () => context.push('/category-selection?from=profile'),
                        child: Container(
                          width: double.infinity,
                          height: 56,
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.grey.shade200),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.category_rounded, color: AppColors.textMuted),
                              SizedBox(width: 10),
                              Text('Change Niche', style: TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.w600, fontSize: 15)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

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
                            color: isDark ? AppColors.error.withValues(alpha: 0.12) : AppColors.error.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.logout_rounded, color: AppColors.error),
                              SizedBox(width: 10),
                              Text('Logout', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.w600, fontSize: 15)),
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
            child: TrendAIBottomNav(currentIndex: 4, scrollController: _scrollCtrl),
          ),
        ],
      ),
    );
  }
}

class _PlatformCard extends StatelessWidget {
  const _PlatformCard({
    required this.name,
    required this.isConnected,
    required this.iconColor,
    required this.iconData,
    required this.onAction,
    this.isPrimaryAction = false,
    this.isLoading = false,
  });

  final String name;
  final bool isConnected;
  final Color iconColor;
  final IconData iconData;
  final VoidCallback onAction;
  final bool isPrimaryAction;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: iconColor, borderRadius: BorderRadius.circular(12)),
            child: Icon(iconData, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: isConnected ? AppColors.success : AppColors.textMuted,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      isConnected ? 'Connected' : 'Not connected',
                      style: TextStyle(
                        color: isConnected ? AppColors.success : AppColors.textMuted,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: onAction,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: isPrimaryAction ? AppColors.primary : (isDark ? Colors.white.withValues(alpha: 0.1) : AppColors.backgroundLight),
                borderRadius: BorderRadius.circular(12),
              ),
              child: isLoading
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Text(
                      isPrimaryAction ? 'Connect' : 'Disconnect',
                      style: TextStyle(
                        color: isPrimaryAction ? Colors.white : (isDark ? Colors.white : AppColors.textLight),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
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
          Icon(icon, color: Theme.of(context).brightness == Brightness.dark ? AppColors.textMuted : AppColors.textMuted, size: 20),
          const SizedBox(width: 12),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 15)),
          const Spacer(),
          child,
        ],
      ),
    );
  }
}
