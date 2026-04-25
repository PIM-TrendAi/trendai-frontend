import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_client.dart';
import '../../../core/network/n8n_service.dart';
import 'models/workflow_models.dart';

final n8nRepositoryProvider = Provider<N8nRepository>((ref) {
  return N8nRepository(ref.read(n8nServiceProvider), ref.read(dioProvider));
});

class N8nRepository {
  const N8nRepository(this._service, this._djangoDio);
  final N8nService _service;
  final Dio _djangoDio;

  Future<List<TrendingVideoModel>> fetchTrendingVideos({String? niche, String platform = 'tiktok'}) async {
    // 1. TikTok: uses direct n8n webhook (legacy behavior)
    if (platform == 'tiktok') {
      return _service.fetchTrendingVideos(niche: niche, platform: platform);
    }

    // 2. Facebook: uses /api/trends/reels/
    if (platform == 'facebook') {
      final res = await _djangoDio.get('/trends/reels/', queryParameters: {
        if (niche != null) 'niche': niche,
      });
      final List list = (res.data is Map) ? (res.data['results'] ?? []) : (res.data as List);
      return list.map((json) {
        // Map Facebook specific names to ones TrendingVideoModel.fromJson recognizes
        final Map<String, dynamic> data = Map<String, dynamic>.from(json);
        data['video_id'] = data['reel_id'];
        data['title'] = data['text'];
        data['view_count'] = data['play_count'];
        data['thumbnail_url'] = data['thumbnail_url'];
        data['author'] = 'Facebook Reel';
        return TrendingVideoModel.fromJson(data);
      }).toList();
    }

    // 3. YouTube: uses /api/trends/youtube-videos/
    if (platform == 'youtube') {
      final res = await _djangoDio.get('/trends/youtube-videos/', queryParameters: {
        if (niche != null) 'niche': niche,
      });
      final List list = (res.data is Map) ? (res.data['results'] ?? []) : (res.data as List);
      return list.map((json) {
        // Map YouTube specific names to ones TrendingVideoModel.fromJson recognizes
        final Map<String, dynamic> data = Map<String, dynamic>.from(json);
        data['title'] = data['titre'];
        data['view_count'] = data['vues'];
        data['author'] = 'YouTube Video';
        data['thumbnail_url'] = 'https://img.youtube.com/vi/${data['video_id']}/0.jpg';
        data['hashtags'] = (data['tags'] as String? ?? '').split(',').where((s) => s.isNotEmpty).toList();
        return TrendingVideoModel.fromJson(data);
      }).toList();
    }

    // 4. Instagram: uses dedicated /api/n8n/instagram-reels/
    if (platform == 'instagram') {
      final res = await _djangoDio.get('/n8n/instagram-reels/', queryParameters: {
        if (niche != null) 'niche': niche,
      });
      final List list = (res.data is Map) ? (res.data['results'] ?? []) : (res.data as List);
      return list.map((json) {
        final Map<String, dynamic> data = Map<String, dynamic>.from(json);
        // Map instagram_reels fields → TrendingVideoModel fields
        data['video_id'] = data['reel_id'] ?? '';
        data['title'] = data['caption'] ?? 'Trending Reel';
        data['views'] = (data['views'] ?? 0).toString();
        data['likes'] = (data['likes'] ?? 0).toString();
        data['author'] = data['author'] ?? '@unknown';
        data['thumbnail_url'] = data['thumbnail_url'] ?? '';
        data['category'] = data['niche'] ?? '';
        data['tiktok_url'] = data['reel_url'] ?? '';
        // Parse hashtags from comma-separated string
        final rawHashtags = data['hashtags'];
        if (rawHashtags is String && rawHashtags.isNotEmpty) {
          data['hashtags'] = rawHashtags.split(',').map((h) => h.trim()).where((h) => h.isNotEmpty).toList();
        }
        return TrendingVideoModel.fromJson(data);
      }).toList();
    }

    // 5. Other platforms: uses /api/n8n/trending_videos/
    final response = await _djangoDio.get('/n8n/trending_videos/', queryParameters: {
      if (niche != null) 'niche': niche,
      'platform': platform,
    });
    
    final data = response.data;
    final List list = (data is Map) ? (data['results'] ?? []) : (data as List);
    
    return list.map((e) => TrendingVideoModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<WorkflowStartResponse> startWorkflow({
    required String creatorId,
    required String selectedVideoId,
    required String videoTitle,
    required String videoAuthor,
    required List<String> videoHashtags,
    required String videoViews,
    required String videoLikes,
    required String niche,
    required String userPrompt,
    String platform = 'tiktok',
  }) async {
    // TikTok: direct n8n webhook (existing behavior)
    if (platform == 'tiktok') {
      return _service.startWorkflow(
        creatorId: creatorId,
        selectedVideoId: selectedVideoId,
        videoTitle: videoTitle,
        videoAuthor: videoAuthor,
        videoHashtags: videoHashtags,
        videoViews: videoViews,
        videoLikes: videoLikes,
        niche: niche,
        userPrompt: userPrompt,
      );
    }

    // Instagram / YouTube / Facebook: route through Django which proxies to
    // the correct n8n webhook and creates sessions as needed.
    final res = await _djangoDio.post(
      '/n8n/start/',
      data: {
        'niche': niche,
        'selected_video_id': selectedVideoId,
        'platform': platform,
        'custom_prompt': userPrompt,
        'title': videoTitle,
      },
    );
    final data = res.data as Map<String, dynamic>;
    // Django returns { success, message } — no session_id or script yet.
    // The script review screen will poll /n8n/sessions/latest/ to find the
    // session once n8n creates it.
    return WorkflowStartResponse(
      sessionId: data['session_id'] as String? ?? '',
      scriptContent: data['script_content'] as String? ?? '',
      status: 'started',
    );
  }

  Future<ScriptActionResponse> approveScript(String sessionId) =>
      _service.submitScriptDecision(sessionId: sessionId, action: 'approve');

  Future<ScriptActionResponse> declineScript(String sessionId) =>
      _service.submitScriptDecision(sessionId: sessionId, action: 'decline');

  Future<VideoActionResponse> approveVideo(String sessionId) =>
      _service.submitVideoDecision(sessionId: sessionId, action: 'approve');

  Future<VideoActionResponse> declineVideo(String sessionId) =>
      _service.submitVideoDecision(sessionId: sessionId, action: 'decline');

  Future<VideoStatusResponse> checkVideoStatus(String sessionId) =>
      _service.checkVideoStatus(sessionId: sessionId);

  Future<List<CreatorVideoModel>> fetchMyVideos(String creatorId) =>
      _service.fetchMyVideos(creatorId: creatorId);

  Future<String> startTikTokOAuth(String creatorId) =>
      _service.startTikTokOAuth(creatorId: creatorId);
}
