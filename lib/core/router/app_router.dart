// GoRouter configuration for TrendAI.
// Checks token in SecureStorage for auth guard — if no token, redirects to splash.
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
import '../../features/analytics/presentation/analytics_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../../features/video_workflow/presentation/screens/video_picker_screen.dart';
import '../../features/video_workflow/presentation/screens/script_review_screen.dart';
import '../../features/video_workflow/presentation/screens/video_generation_screen.dart';
import '../../features/video_workflow/presentation/screens/video_review_screen.dart';
import '../../features/my_videos/presentation/my_videos_screen.dart';
import '../../features/tiktok_stats/presentation/tiktok_stats_screen.dart';
import '../../features/instagram/presentation/screens/instagram_trends_screen.dart';
import '../../features/facebook/presentation/screens/facebook_engine_screen.dart';
import '../../features/youtube/presentation/screens/youtube_engine_screen.dart';
import '../../features/ai_generator/presentation/ai_generator_screen.dart';
import '../../features/auth/presentation/screens/forgot_password_screen.dart';
import '../../features/auth/presentation/screens/reset_password_screen.dart';
import '../storage/secure_storage.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/splash',
    onException: (_, GoRouterState state, GoRouter router) {
      // Deep link callbacks (trendai://callback) have no route — send to profile
      router.go('/profile');
    },
    redirect: (context, state) async {
      final storage = ref.read(secureStorageProvider);
      final hasToken = await storage.hasTokens();
      final isAuthPage = state.matchedLocation == '/splash' ||
          state.matchedLocation == '/onboarding-1' ||
          state.matchedLocation == '/onboarding-2' ||
          state.matchedLocation == '/onboarding-3' ||
          state.matchedLocation == '/login' ||
          state.matchedLocation == '/signup' ||
          state.matchedLocation == '/forgot-password' ||
          state.matchedLocation == '/reset-password' ||
          state.matchedLocation == '/category-selection';
      if (!hasToken && !isAuthPage) return '/splash';
      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (_, __) => const SplashScreen()),
      GoRoute(path: '/onboarding-1', builder: (_, __) => const OnboardingScreen(page: 1)),
      GoRoute(path: '/onboarding-2', builder: (_, __) => const OnboardingScreen(page: 2)),
      GoRoute(path: '/onboarding-3', builder: (_, __) => const OnboardingScreen(page: 3)),
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/signup', builder: (_, __) => const SignUpScreen()),
      GoRoute(path: '/forgot-password', builder: (_, __) => const ForgotPasswordScreen()),
      GoRoute(
        path: '/reset-password',
        builder: (_, state) => ResetPasswordScreen(
          uid: state.uri.queryParameters['uid'] ?? '',
          token: state.uri.queryParameters['token'] ?? '',
        ),
      ),
      GoRoute(
        path: '/category-selection',
        builder: (_, state) => CategorySelectionScreen(
          fromProfile: state.uri.queryParameters['from'] == 'profile',
        ),
      ),
      GoRoute(path: '/dashboard', builder: (_, __) => const DashboardScreen()),
      GoRoute(path: '/trends', builder: (_, __) => const TrendsListScreen()),
      GoRoute(
        path: '/trend/:id',
        builder: (_, state) => TrendDetailScreen(id: int.parse(state.pathParameters['id']!)),
      ),
      GoRoute(
        path: '/ai-generator',
        builder: (_, state) => AIGeneratorScreen(
          niche: state.uri.queryParameters['niche'],
          selectedVideoId: state.uri.queryParameters['selectedVideoId'],
          platform: state.uri.queryParameters['platform'],
        ),
      ),
      GoRoute(path: '/analytics', builder: (_, __) => const AnalyticsScreen()),
      GoRoute(path: '/profile', builder: (_, __) => const ProfileScreen()),
      GoRoute(path: '/video-picker', builder: (_, __) => const VideoPickerScreen()),
      GoRoute(path: '/script-review', builder: (_, __) => const ScriptReviewScreen()),
      GoRoute(path: '/video-generation', builder: (_, __) => const VideoGenerationScreen()),
      GoRoute(path: '/video-review', builder: (_, __) => const VideoReviewScreen()),
      GoRoute(path: '/my-videos', builder: (_, __) => const MyVideosScreen()),
      GoRoute(path: '/tiktok-stats', builder: (_, __) => const TikTokStatsScreen()),
      GoRoute(path: '/instagram-engine', builder: (_, __) => const InstagramTrendsScreen()),
      GoRoute(path: '/facebook-engine', builder: (_, __) => const FacebookEngineScreen()),
      GoRoute(path: '/youtube-engine', builder: (_, __) => const YouTubeEngineScreen()),
    ],
  );
});
