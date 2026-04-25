import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

/// Mobile implementation using video_player plugin.
class WebVideoPlayer extends StatefulWidget {
  final String url;
  const WebVideoPlayer({super.key, required this.url});

  @override
  State<WebVideoPlayer> createState() => _WebVideoPlayerState();
}

class _WebVideoPlayerState extends State<WebVideoPlayer> {
  late VideoPlayerController _controller;
  bool _initialized = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url));
      await _controller.initialize();
      if (!mounted) return;
      
      setState(() {
        _initialized = true;
      });
      
      _controller.setLooping(true);
      _controller.setVolume(0); // Start muted like TikTok
      _controller.play();
    } catch (e) {
      if (mounted) {
        setState(() => _error = 'Preview failed to load');
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Center(child: Text(_error!, style: const TextStyle(color: Colors.redAccent, fontSize: 13)));
    }

    if (!_initialized) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }

    return Stack(
      alignment: Alignment.center,
      children: [
        SizedBox.expand(
          child: FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width: _controller.value.size.width,
              height: _controller.value.size.height,
              child: VideoPlayer(_controller),
            ),
          ),
        ),
        // Play pause toggle on tap
        GestureDetector(
          onTap: () {
            if (_controller.value.isPlaying) {
              _controller.pause();
            } else {
              _controller.play();
            }
            setState(() {});
          },
          child: Container(
            color: Colors.transparent,
            child: _controller.value.isPlaying 
              ? null 
              : const Icon(Icons.play_circle_outline, size: 60, color: Colors.white54),
          ),
        ),
        
        // Mute toggle bottom right
        Positioned(
          bottom: 12, right: 12,
          child: IconButton(
            icon: Icon(
              _controller.value.volume == 0 ? Icons.volume_off_rounded : Icons.volume_up_rounded,
              color: Colors.white70,
              size: 20,
            ),
            onPressed: () {
              _controller.setVolume(_controller.value.volume == 0 ? 1 : 0);
              setState(() {});
            },
          ),
        ),
      ],
    );
  }
}
