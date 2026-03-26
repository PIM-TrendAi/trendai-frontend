// TikTok Live Stats screen — real-time engagement via WebSocket.
// Connects to ws://host/ws/tiktok-stats/?token=<JWT>, polls TikTok API
// every 30 s on the backend and streams results to this screen.
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../../core/config/server_config.dart' show ServerConfig;
import '../../../core/storage/secure_storage.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/shared_widgets.dart';

// ── WebSocket host — resolved at runtime via ServerConfig
String get _wsBase => '${ServerConfig.wsBase}/ws/tiktok-stats/';
const _reconnectDelay = Duration(seconds: 5);

// ─────────────────────────────────────────────
// Screen
// ─────────────────────────────────────────────
class TikTokStatsScreen extends ConsumerStatefulWidget {
  const TikTokStatsScreen({super.key});

  @override
  ConsumerState<TikTokStatsScreen> createState() => _TikTokStatsScreenState();
}

class _TikTokStatsScreenState extends ConsumerState<TikTokStatsScreen> {
  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _sub;
  Timer? _reconnectTimer;

  List<Map<String, dynamic>> _videos = [];
  bool _connected = false;
  bool _loading = true;
  String? _error;
  String? _lastUpdated;

  @override
  void initState() {
    super.initState();
    _connectAfterJwt();
  }

  @override
  void dispose() {
    _reconnectTimer?.cancel();
    _sub?.cancel();
    _channel?.sink.close();
    super.dispose();
  }

  // ── Connect ────────────────────────────────

  Future<void> _connectAfterJwt() async {
    final jwt = await ref.read(secureStorageProvider).readAccessToken();
    if (!mounted) return;
    if (jwt == null) {
      setState(() {
        _loading = false;
        _error = 'Not authenticated';
      });
      return;
    }
    _connect(jwt);
  }

  void _connect(String jwt) {
    final uri = Uri.parse('$_wsBase?token=$jwt');
    _channel = WebSocketChannel.connect(uri);

    setState(() {
      _connected = true;
      _loading = _videos.isEmpty;
      _error = null;
    });

    _sub?.cancel();
    _sub = _channel!.stream.listen(
      _onMessage,
      onError: (_) => _onDisconnected(),
      onDone: _onDisconnected,
      cancelOnError: true,
    );
  }

  void _onMessage(dynamic raw) {
    if (!mounted) return;
    final Map<String, dynamic> data;
    try {
      data = jsonDecode(raw as String) as Map<String, dynamic>;
    } catch (_) {
      return;
    }

    if (data.containsKey('error')) {
      setState(() {
        _error = _errorMessage(data['error'] as String);
        _loading = false;
        _connected = false;
      });
      return;
    }

    setState(() {
      _videos = List<Map<String, dynamic>>.from(data['videos'] as List);
      _lastUpdated = data['last_updated'] as String?;
      _loading = false;
      _connected = true;
      _error = null;
    });
  }

  void _onDisconnected() {
    if (!mounted) return;
    setState(() => _connected = false);
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(_reconnectDelay, _connectAfterJwt);
  }

  String _errorMessage(String code) {
    switch (code) {
      case 'tiktok_token_expired':
        return 'TikTok session expired — reconnect TikTok in Profile';
      case 'tiktok_not_connected':
        return 'TikTok not connected — go to Profile to connect';
      case 'tiktok_api_unavailable':
        return 'TikTok API unavailable — retrying…';
      default:
        return 'Connection error: $code';
    }
  }

  // ── Build ───────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const AnimatedParticleBackground(),
          Column(
            children: [
              TrendAIAppBar(
                title: 'TikTok Live Stats',
                subtitle: 'Real-time engagement',
                showBack: true,
                action: _PulseIndicator(connected: _connected),
              ),
              Expanded(child: _buildBody()),
            ],
          ),
          const Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: TrendAIBottomNav(currentIndex: 3),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null && _videos.isEmpty) {
      return _ErrorPlaceholder(message: _error!, onRetry: _connectAfterJwt);
    }

    return RefreshIndicator(
      onRefresh: () async {
        if (_channel != null) {
          _channel!.sink.add(jsonEncode({'action': 'refresh'}));
        }
      },
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
        itemCount: _videos.length + (_lastUpdated != null ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == 0 && _lastUpdated != null) {
            return _LastUpdatedBanner(
              iso: _lastUpdated!,
              connected: _connected,
            );
          }
          final videoIndex = _lastUpdated != null ? index - 1 : index;
          return _VideoStatCard(video: _videos[videoIndex]);
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Pulse indicator — live connection dot
// ─────────────────────────────────────────────
class _PulseIndicator extends StatelessWidget {
  const _PulseIndicator({required this.connected});
  final bool connected;

  @override
  Widget build(BuildContext context) {
    final color = connected ? AppColors.success : AppColors.textMuted;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        )
            .animate(
              onPlay: (c) => c.repeat(),
            )
            .scaleXY(
              begin: 1.0,
              end: connected ? 1.5 : 1.0,
              duration: 700.ms,
              curve: Curves.easeInOut,
            )
            .then()
            .scaleXY(begin: 1.5, end: 1.0, duration: 700.ms),
        const SizedBox(width: 6),
        Text(
          connected ? 'LIVE' : 'Reconnecting…',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: color,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────
// Last updated banner
// ─────────────────────────────────────────────
class _LastUpdatedBanner extends StatelessWidget {
  const _LastUpdatedBanner({required this.iso, required this.connected});
  final String iso;
  final bool connected;

  @override
  Widget build(BuildContext context) {
    final dt = DateTime.tryParse(iso);
    final label = dt != null
        ? 'Updated ${_timeAgo(dt)}'
        : 'Updating…';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        label,
        style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
        textAlign: TextAlign.center,
      ),
    );
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().toUtc().difference(dt.toUtc());
    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    return '${diff.inHours}h ago';
  }
}

// ─────────────────────────────────────────────
// Video stat card
// ─────────────────────────────────────────────
class _VideoStatCard extends StatelessWidget {
  const _VideoStatCard({required this.video});
  final Map<String, dynamic> video;

  @override
  Widget build(BuildContext context) {
    final title = video['title'] as String? ?? 'Untitled';
    final thumbnail = video['thumbnail_url'] as String? ?? '';
    final views = video['views'] as int? ?? 0;
    final likes = video['likes'] as int? ?? 0;
    final comments = video['comments'] as int? ?? 0;
    final shares = video['shares'] as int? ?? 0;
    final avgWatch = (video['avg_watch_time_seconds'] as num?)?.toDouble() ?? 0.0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GlassCard(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thumbnail
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: thumbnail.isNotEmpty
                  ? Image.network(
                      thumbnail,
                      width: 80,
                      height: 80,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _thumbnailFallback(),
                    )
                  : _thumbnailFallback(),
            ),
            const SizedBox(width: 12),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      _StatChip(icon: Icons.play_arrow_rounded, value: _fmt(views), label: 'views'),
                      _StatChip(icon: Icons.favorite_rounded, value: _fmt(likes), label: 'likes', color: AppColors.tikTok),
                      _StatChip(icon: Icons.comment_rounded, value: _fmt(comments), label: 'comments'),
                      _StatChip(icon: Icons.share_rounded, value: _fmt(shares), label: 'shares'),
                      _StatChip(
                        icon: Icons.timer_rounded,
                        value: '${avgWatch.toStringAsFixed(1)}s',
                        label: 'avg watch',
                        color: AppColors.accent,
                      ),
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

  Widget _thumbnailFallback() {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        color: AppColors.tikTok.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Icon(Icons.play_circle_outline_rounded,
          color: AppColors.tikTok, size: 32),
    );
  }

  String _fmt(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return n.toString();
  }
}

// ─────────────────────────────────────────────
// Stat chip
// ─────────────────────────────────────────────
class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.icon,
    required this.value,
    required this.label,
    this.color = AppColors.textMuted,
  });

  final IconData icon;
  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 3),
        Text(
          '$value $label',
          style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────
// Error placeholder
// ─────────────────────────────────────────────
class _ErrorPlaceholder extends StatelessWidget {
  const _ErrorPlaceholder({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded,
                size: 48, color: AppColors.textMuted),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textMuted, fontSize: 14),
            ),
            const SizedBox(height: 24),
            GradientButton(label: 'Retry', onPressed: onRetry),
          ],
        ),
      ),
    );
  }
}
