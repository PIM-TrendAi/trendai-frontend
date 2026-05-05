import 'package:flutter/material.dart';

class WebVideoPlayer extends StatelessWidget {
  final String url;
  const WebVideoPlayer({super.key, required this.url});

  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('Video player not available on this platform'));
  }
}
