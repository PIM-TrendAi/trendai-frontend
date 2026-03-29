/// GoRouter configuration for TrendAI.
/// Checks token in SecureStorage for auth guard — if no token, redirects to splash.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/presentation/screens/splash_screen.dart';
import '../../features/auth/presentation/screens/onboarding_screen.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/signup_screen.dart';
import '../../features/auth/presentation/screens/category_selection_screen.dart';
import '../../features/dashboard/presentation/dashboard_screen.dart';
import '../../features/trends/presentation/screens/trends_list_screen.dart';
import '../../features/trends/presentation/screens/trend_detail_screen.dart';
import '../../features/ai_generator/presentation/ai_generator_screen.dart';
import '../../features/ai_generator/presentation/script_review_screen.dart';
import '../../features/ai_generator/presentation/video_review_screen.dart';
import '../../features/analytics/presentation/analytics_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../../features/profile/presentation/my_videos_screen.dart';
import '../storage/secure_storage.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/splash',
    redirect: (context, state) async {
      final storage = ref.read(secureStorageProvider);
      final hasToken = await storage.hasTokens();
      final isAuthPage = state.matchedLocation == '/splash' ||
          state.matchedLocation == '/onboarding-1' ||
          state.matchedLocation == '/onboarding-2' ||
          state.matchedLocation == '/onboarding-3' ||
          state.matchedLocation == '/login' ||
          state.matchedLocation == '/signup' ||
          state.matchedLocation == '/category-selection';
          
      // If not logged in and not on an auth page, send to splash
      if (!hasToken && !isAuthPage) return '/splash';
      
      // If logged in but trying to access an auth page (like splash or login), send to dashboard
      // (Except when they are specifically navigating through splash for initialization)
      // Actually, since splash screen handles its own 2-second delay and then context.go(),
      // we shouldn't force redirect away from splash, otherwise the animation is skipped.
      if (hasToken && isAuthPage && state.matchedLocation != '/splash') return '/dashboard';
      
      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (_, __) => const SplashScreen()),
      GoRoute(path: '/onboarding-1', builder: (_, __) => const OnboardingScreen(page: 1)),
      GoRoute(path: '/onboarding-2', builder: (_, __) => const OnboardingScreen(page: 2)),
      GoRoute(path: '/onboarding-3', builder: (_, __) => const OnboardingScreen(page: 3)),
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/signup', builder: (_, __) => const SignUpScreen()),
      GoRoute(path: '/category-selection', builder: (_, __) => const CategorySelectionScreen()),
      GoRoute(path: '/dashboard', builder: (_, __) => const DashboardScreen()),
      GoRoute(path: '/trends', builder: (_, __) => const TrendsListScreen()),
      GoRoute(
        path: '/trend/:id',
        builder: (_, state) => TrendDetailScreen(id: int.parse(state.pathParameters['id']!)),
      ),
      GoRoute(path: '/ai-generator', builder: (_, __) => const AIGeneratorScreen()),
      GoRoute(
        path: '/script-review',
        builder: (_, state) {
          final extra = state.extra as Map<String, dynamic>;
          return ScriptReviewScreen(
            reelId: extra['reel_id'] as String,
            prompt: extra['prompt'] as String,
            niche: extra['niche'] as String,
          );
        },
      ),
      GoRoute(
        path: '/video-review/:id',
        builder: (_, state) => VideoReviewScreen(
          videoId: int.parse(state.pathParameters['id']!),
        ),
      ),
      GoRoute(path: '/analytics', builder: (_, __) => const AnalyticsScreen()),
      GoRoute(path: '/profile', builder: (_, __) => const ProfileScreen()),
      GoRoute(path: '/my-videos', builder: (_, __) => const MyVideosScreen()),
    ],
  );
});
