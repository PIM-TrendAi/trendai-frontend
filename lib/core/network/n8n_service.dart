import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/video_workflow/data/models/workflow_models.dart';
export '../../features/video_workflow/data/models/workflow_models.dart' show CreatorVideoModel;

const _n8nBase = 'https://noncartelized-delightsomely-donetta.ngrok-free.dev';

// n8n webhook paths
const _pathStartWorkflow = '/webhook/205b7271-5246-4e81-80b4-7b93579ab006';
const _pathScriptDecision = '/webhook/0ec65146-238d-4c79-a441-25721e9373e7';
const _pathVideoDecision = '/webhook/35bda5a4-5875-4ce6-b33f-3bea2ca0dc8a';
const _pathOAuthStart = '/webhook/c0a80001-0000-0000-0000-000000000001';
// These two are added in Phase 3 (new n8n webhooks):
const _pathGetTrends = '/webhook/d1b90001-0000-0000-0000-000000000001';
const _pathVideoStatus = '/webhook/d1b90001-0000-0000-0000-000000000002';
const _pathMyVideos = '/webhook/e1c90001-0000-0000-0000-000000000001';

final n8nServiceProvider = Provider<N8nService>((_) => N8nService());

class N8nService {
  N8nService()
      : _dio = Dio(BaseOptions(
          baseUrl: _n8nBase,
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 60),
          headers: {
            'Content-Type': 'application/json',
            'ngrok-skip-browser-warning': 'true',
          },
        ));

  final Dio _dio;

  Future<List<TrendingVideoModel>> fetchTrendingVideos({String? niche, String platform = 'tiktok'}) async {
    final queryParams = <String, dynamic>{'platform': platform};
    if (niche != null) queryParams['niche'] = niche;
    final response = await _dio.get(
      _pathGetTrends,
      queryParameters: queryParams,
      options: Options(receiveTimeout: const Duration(seconds: 10)),
    );
    final data = response.data;
    if (data is List) {
      if (data.isNotEmpty) {
        // Print first item's keys so we can confirm the exact field names
        debugPrint('[n8n] trending video keys: ${(data.first as Map).keys.toList()}');
        debugPrint('[n8n] first item: ${data.first}');
      }
      return data
          .map((e) => TrendingVideoModel.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    return [];
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
  }) async {
    final response = await _dio.post(
      _pathStartWorkflow,
      data: {
        'creatorId': creatorId,
        'selectedVideoId': selectedVideoId,
        'videoTitle': videoTitle,
        'videoAuthor': videoAuthor,
        'videoHashtags': videoHashtags,
        'videoViews': videoViews,
        'videoLikes': videoLikes,
        'niche': niche,
        'userPrompt': userPrompt,
      },
    );
    return WorkflowStartResponse.fromJson(response.data as Map<String, dynamic>);
  }

  Future<ScriptActionResponse> submitScriptDecision({
    required String sessionId,
    required String action, // 'approve' or 'decline'
  }) async {
    final response = await _dio.post(
      _pathScriptDecision,
      data: {'sessionId': sessionId, 'action': action},
      // Decline triggers a full regeneration via Ollama (~60-90s) before
      // n8n responds — give enough headroom so we don't timeout mid-generation.
      options: Options(receiveTimeout: const Duration(seconds: 150)),
    );
    return ScriptActionResponse.fromJson(response.data as Map<String, dynamic>);
  }

  Future<VideoActionResponse> submitVideoDecision({
    required String sessionId,
    required String action, // 'approve' or 'decline'
  }) async {
    final response = await _dio.post(
      _pathVideoDecision,
      data: {'sessionId': sessionId, 'action': action},
    );
    return VideoActionResponse.fromJson(response.data as Map<String, dynamic>);
  }

  Future<VideoStatusResponse> checkVideoStatus({
    required String sessionId,
  }) async {
    final response = await _dio.get(
      _pathVideoStatus,
      queryParameters: {'sessionId': sessionId},
      options: Options(receiveTimeout: const Duration(seconds: 10)),
    );
    return VideoStatusResponse.fromJson(response.data as Map<String, dynamic>);
  }

  Future<List<CreatorVideoModel>> fetchMyVideos({required String creatorId}) async {
    final response = await _dio.get(
      _pathMyVideos,
      queryParameters: {'creatorId': creatorId},
      options: Options(receiveTimeout: const Duration(seconds: 15)),
    );
    final data = response.data;
    if (data is List) {
      return data
          .map((e) => CreatorVideoModel.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    return [];
  }

  Future<String> startTikTokOAuth({required String creatorId}) async {
    final response = await _dio.get(
      _pathOAuthStart,
      queryParameters: {'creatorId': creatorId},
      options: Options(receiveTimeout: const Duration(seconds: 10)),
    );
    final data = response.data as Map<String, dynamic>;
    return data['authUrl'] as String;
  }
}
