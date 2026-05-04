# TrendAI Frontend

Flutter app for the TrendAI platform — multi-platform trend discovery and AI-powered video content generation for TikTok, Instagram, Facebook, YouTube, and Threads.

---

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Framework | Flutter 3.x (Dart ≥ 3.0) |
| State Management | Riverpod 2 (AsyncNotifier + StateNotifier) |
| Navigation | GoRouter 14 |
| HTTP Client | Dio 5 with JWT auto-refresh interceptor |
| Secure Storage | flutter_secure_storage (JWT tokens) |
| Charts | fl_chart |
| Animations | flutter_animate |
| Typography | Google Fonts — Inter |
| Deep Linking | app_links |

---

## Project Structure

```
trendai-frontend/
├── lib/
│   ├── core/
│   │   ├── config/          # Server config, base URLs, auto-discovery
│   │   ├── network/         # Dio client, auth interceptor, N8N service
│   │   ├── router/          # GoRouter routes + auth guard
│   │   └── theme/           # AppColors, typography, component styles
│   └── features/
│       ├── auth/            # Splash, onboarding, login, signup, password reset, category selection
│       ├── dashboard/       # Home screen, platform cards, recommendations, tutorial
│       ├── trends/          # Trends list + detail, multi-platform filtering
│       ├── video_workflow/  # Video picker → script review → video generation → video review
│       ├── ai_generator/    # Standalone AI script generator
│       ├── analytics/       # Engagement heatmap, viral score, platform stats
│       ├── profile/         # Account settings, connected platforms, dark mode
│       ├── instagram/       # Instagram trends engine
│       ├── facebook/        # Facebook trends engine
│       ├── youtube/         # YouTube trends engine
│       ├── threads/         # Threads trends engine
│       └── my_videos/       # Created/drafted videos grid
├── android/
├── ios/
├── macos/
├── web/
├── linux/
├── windows/
└── pubspec.yaml
```

---

## Features

### Authentication
- Email/password login and registration (with reCAPTCHA via WebView)
- JWT access + refresh token storage (encrypted, `flutter_secure_storage`)
- Forgot password / reset password flow
- Multi-niche category selection on first login
- Auto-navigation based on token presence

### Dashboard
- Viral score card + trending videos from all platforms
- Platform engagement heatmap
- AI-powered personalized recommendations (based on selected niches)
- Background Facebook scrape trigger on app load
- Interactive onboarding tutorial system

### Trends
- Multi-platform trend feed: TikTok, Instagram, YouTube, Facebook, Threads
- Filter by platform and niche; sort by views / likes / date
- Momentum badges: Hot / Rising / Steady
- Manual scrape triggers per platform
- Trend detail with 7-day chart, engagement metrics, target audience info

### Video Workflow (AI Engine)
1. **Video Picker** — Browse trending videos, write a custom AI prompt, select AI model (GPT-4o, Claude, Gemini, Llama, Mistral)
2. **Script Review** — Read generated script, approve or decline to regenerate
3. **Video Generation** — Polling status (every 3 s) with animated loading screen
4. **Video Review** — Watch generated video, approve for posting or regenerate

### Analytics
- Summary cards: views, likes, followers, shares
- 7-day engagement line chart
- Best posting-time heatmap
- Instagram and Facebook live stats

### Profile
- Edit name, profile image
- Connected platforms overview (TikTok, Instagram, Facebook, YouTube, Threads)
- Dark/light mode toggle
- Niche preferences editor
- Logout

---

## Screens & Routes

| Route | Screen |
|-------|--------|
| `/splash` | SplashScreen |
| `/onboarding-1` `/onboarding-2` `/onboarding-3` | OnboardingScreen |
| `/login` | LoginScreen |
| `/signup` | SignUpScreen |
| `/forgot-password` | ForgotPasswordScreen |
| `/reset-password?uid=&token=` | ResetPasswordScreen |
| `/category-selection?from=profile` | CategorySelectionScreen |
| `/dashboard` | DashboardScreen |
| `/trends` | TrendsListScreen |
| `/trend/:id` | TrendDetailScreen |
| `/video-picker` | VideoPickerScreen |
| `/script-review` | ScriptReviewScreen |
| `/video-generation` | VideoGenerationScreen |
| `/video-review` | VideoReviewScreen |
| `/my-videos` | MyVideosScreen |
| `/ai-generator` | AIGeneratorScreen |
| `/analytics` | AnalyticsScreen |
| `/profile` | ProfileScreen |
| `/instagram-engine` | InstagramTrendsScreen |
| `/facebook-engine` | FacebookEngineScreen |
| `/youtube-engine` | YouTubeEngineScreen |
| `/threads-engine` | ThreadsEngineScreen |

---

## State Management

**Riverpod 2** with `AsyncNotifierProvider` and `StateNotifierProvider` patterns.

| Provider | Type | Purpose |
|----------|------|---------|
| `authNotifierProvider` | AsyncNotifier | Login, register, token refresh, TikTok status |
| `workflowProvider` | StateNotifier | Full video generation workflow state |
| `dioProvider` | Provider | Configured Dio client with JWT interceptor |
| `secureStorageProvider` | Provider | Encrypted token/profile storage |
| `themeModeProvider` | StateProvider | Dark/light mode toggle |
| `tiktokVideosProvider` | FutureProvider | Trending TikTok videos |
| `n8nServiceProvider` | Provider | N8N webhook service |

---

## Network Layer

**Base URL** auto-discovered at runtime by scanning the WiFi subnet (`192.168.x.x:8000/api/health/`) in parallel. Falls back to the compile-time constant in `lib/core/config/server_config.dart`.

**Auth interceptor** — attaches `Authorization: Bearer <token>` to every request; automatically calls `/auth/refresh/` on 401 and retries.

**N8N webhooks** — base URL configured in `lib/core/network/n8n_service.dart` (ngrok URL for local dev).

---

## Key Dependencies

```yaml
# State & Navigation
flutter_riverpod: ^2.6.1
go_router: ^14.6.2

# Networking
dio: ^5.8.0+1
app_links: ^6.3.4           # Deep linking (TikTok OAuth callback)

# Storage
flutter_secure_storage: ^9.2.2
shared_preferences: ^2.3.5

# UI
google_fonts: ^6.2.1
flutter_animate: ^4.5.2
fl_chart: ^0.70.2
cupertino_icons: ^1.0.8

# Media
video_player: ^2.9.2
image_picker: ^1.1.2
url_launcher: ^6.3.2
webview_flutter: ^4.10.0    # reCAPTCHA

# Utilities
uuid: ^4.5.1
web_socket_channel: ^2.4.0
```

---

## Design System

**Colors**

| Token | Value | Usage |
|-------|-------|-------|
| Background | `#050508` | App background |
| Primary | `#6C5CE7` | Buttons, highlights |
| Accent | `#00C6FF` | Gradient end |
| TikTok | `#EC4899` | Platform badge |
| Instagram | `#F97316` | Platform badge |
| YouTube | `#EF4444` | Platform badge |
| Facebook | `#3B82F6` | Platform badge |
| Threads | `#0EA5E9` | Platform badge |

**Components**
- `TrendAIAppBar` — Sticky header with gradient title
- `TrendAIBottomNav` — Floating glassmorphic 5-tab navigation pill
- `GlassCard` — Semi-transparent card with subtle border
- `GradientButton` — Primary CTA button
- `AnimatedParticleBackground` — Background particle effect
- `GradientText` — Shader-masked gradient text

---

## Local Setup

**Prerequisites:** Flutter SDK ≥ 3.0, Dart ≥ 3.0, Xcode 15+ (iOS/macOS) or Android Studio (Android)

```bash
# 1. Install dependencies
flutter pub get

# 2. Generate Riverpod code
dart run build_runner build

# 3. Run on device/simulator
flutter run -d iphone        # iOS
flutter run -d android       # Android
flutter run -d macos         # macOS
flutter run -d chrome        # Web
```

**Server config** — edit `lib/core/config/server_config.dart` to set the fallback backend IP and port if auto-discovery doesn't work on your network.

---

## Build

```bash
flutter build ios --release
flutter build apk --release
flutter build web --release
```

---

## Platform Support

| Platform | Status |
|----------|--------|
| iOS | Full support |
| Android | Full support |
| macOS | Full support |
| Web | Basic support |
| Linux | Basic support |
| Windows | Basic support |

---

## Deep Linking

TikTok OAuth redirects back to the app via the `trendai://` scheme:

```
trendai://callback?tiktok=success
```

Test on Android:
```bash
adb shell am start -a android.intent.action.VIEW -d "trendai://callback?tiktok=success"
```
