// main.dart — App entry point.
// Wraps app in ProviderScope (Riverpod) and MaterialApp.router with GoRouter.
import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_provider.dart';
import 'core/router/app_router.dart';
import 'core/storage/secure_storage.dart';
import 'features/auth/auth_repository.dart';

void main() {
  runApp(const ProviderScope(child: TrendAIApp()));
}

class TrendAIApp extends ConsumerStatefulWidget {
  const TrendAIApp({super.key});

  @override
  ConsumerState<TrendAIApp> createState() => _TrendAIAppState();
}

class _TrendAIAppState extends ConsumerState<TrendAIApp> {
  late final AppLinks _appLinks;
  StreamSubscription<Uri>? _linkSub;

  @override
  void initState() {
    super.initState();
    _appLinks = AppLinks();
    _linkSub = _appLinks.uriLinkStream.listen(_onDeepLink);
  }

  Future<void> _onDeepLink(Uri uri) async {
    // trendai://callback?tiktok=success  — sent by n8n after TikTok OAuth
    if (uri.scheme == 'trendai' &&
        uri.host == 'callback' &&
        uri.queryParameters['tiktok'] == 'success') {
      // Write directly to storage first so it survives app restarts
      await ref.read(secureStorageProvider).setTikTokConnected(true);
      // Then update in-memory state
      ref.read(authNotifierProvider.notifier).setTikTokConnected();
    }
  }

  @override
  void dispose() {
    _linkSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      title: 'TrendAI',
      debugShowCheckedModeBanner: false,
      themeMode: themeMode,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      routerConfig: router,
    );
  }
}
