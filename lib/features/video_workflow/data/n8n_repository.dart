import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/n8n_service.dart';
import 'models/workflow_models.dart';

final n8nRepositoryProvider = Provider<N8nRepository>((ref) {
  return N8nRepository(ref.read(n8nServiceProvider));
});

class N8nRepository {
  const N8nRepository(this._service);
  final N8nService _service;

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
  }) =>
      _service.startWorkflow(
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
