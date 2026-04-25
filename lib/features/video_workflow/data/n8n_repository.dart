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

  Future<List<TrendingVideoModel>> fetchTrendingVideos({String? niche, String platform = 'tiktok'}) =>
      _service.fetchTrendingVideos(niche: niche, platform: platform);

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

  Future<ScriptActionResponse> approveScript(String sessionId, {String platform = 'tiktok'}) async {
    if (platform == 'tiktok') {
      return _service.submitScriptDecision(sessionId: sessionId, action: 'approve');
    }
    final res = await _djangoDio.post(
      '/n8n/approve/script/',
      data: {'session_id': sessionId, 'approved': true},
    );
    return ScriptActionResponse.fromJson(res.data as Map<String, dynamic>);
  }
  
  Future<ScriptActionResponse> declineScript(String sessionId, {String platform = 'tiktok'}) async {
    if (platform == 'tiktok') {
      return _service.submitScriptDecision(sessionId: sessionId, action: 'decline');
    }
    final res = await _djangoDio.post(
      '/n8n/approve/script/',
      data: {'session_id': sessionId, 'approved': false},
    );
    return ScriptActionResponse.fromJson(res.data as Map<String, dynamic>);
  }

  Future<VideoActionResponse> approveVideo(String sessionId, {String? videoId, String platform = 'tiktok'}) async {
    if (platform == 'tiktok') {
      return _service.submitVideoDecision(sessionId: sessionId, action: 'approve');
    }
    final res = await _djangoDio.post(
      '/n8n/approve/video/',
      data: {
        'session_id': sessionId,
        'video_id': videoId,
        'approved': true,
        'platform': platform,
      },
    );
    return VideoActionResponse.fromJson(res.data as Map<String, dynamic>);
  }

  Future<VideoActionResponse> declineVideo(String sessionId, {String? videoId, String platform = 'tiktok'}) async {
    if (platform == 'tiktok') {
      return _service.submitVideoDecision(sessionId: sessionId, action: 'decline');
    }
    final res = await _djangoDio.post(
      '/n8n/approve/video/',
      data: {
        'session_id': sessionId,
        'video_id': videoId,
        'approved': false,
        'platform': platform,
      },
    );
    return VideoActionResponse.fromJson(res.data as Map<String, dynamic>);
  }

  Future<VideoStatusResponse> checkVideoStatus(String sessionId, {String platform = 'tiktok'}) async {
    if (platform == 'tiktok') {
      return _service.checkVideoStatus(sessionId: sessionId);
    }
    final res = await _djangoDio.get('/n8n/sessions/$sessionId/');
    return VideoStatusResponse.fromJson(res.data as Map<String, dynamic>);
  }

  Future<List<CreatorVideoModel>> fetchMyVideos(String creatorId) =>
      _service.fetchMyVideos(creatorId: creatorId);

  Future<String> startTikTokOAuth(String creatorId) =>
      _service.startTikTokOAuth(creatorId: creatorId);
}
