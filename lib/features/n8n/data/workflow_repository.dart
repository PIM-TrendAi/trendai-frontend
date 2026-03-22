import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/dio_client.dart';
import 'workflow_models.dart';

final workflowRepositoryProvider = Provider<WorkflowRepository>((ref) {
  return WorkflowRepository(ref.read(dioProvider));
});

class WorkflowRepository {
  final Dio _dio;

  WorkflowRepository(this._dio);

  Future<List<TrendingVideo>> getTrendingVideos({String? niche}) async {
    final queryParams = niche != null && niche.isNotEmpty ? {'niche': niche} : null;
    final response = await _dio.get('/n8n/trending_videos/', queryParameters: queryParams);
    final List data = response.data is List ? response.data : response.data['results'] ?? [];
    return data.map((e) => TrendingVideo.fromJson(e)).toList();
  }

  Future<void> triggerScrape({String? niche}) async {
    try {
      final data = (niche != null && niche.isNotEmpty) ? {'niche': niche} : null;
      await _dio.post('/n8n/trigger-scrape/', data: data);
    } catch (e) {
      // Best effort, ignore errors (it might already be scraping)
    }
  }

  Future<void> startWorkflow(String niche, String selectedVideoId) async {
    await _dio.post('/n8n/start/', data: {
      'niche': niche,
      'selected_video_id': selectedVideoId,
    });
  }

  Future<String?> getLatestSessionId() async {
    final response = await _dio.get('/n8n/sessions/latest/');
    return response.data['session_id'];
  }

  Future<WorkflowSession> getSession(String sessionId) async {
    final response = await _dio.get('/n8n/sessions/$sessionId/');
    return WorkflowSession.fromJson(response.data);
  }

  Future<void> approveScript(String sessionId, String scriptId, bool approved) async {
    await _dio.post('/n8n/approve/script/', data: {
      'session_id': sessionId,
      'script_id': scriptId,
      'approved': approved,
    });
  }

  Future<void> approveVideo(String sessionId, String videoId, bool approved) async {
    await _dio.post('/n8n/approve/video/', data: {
      'session_id': sessionId,
      'video_id': videoId,
      'approved': approved,
    });
  }
}

// Removing workflowSessionsProvider since the new view relies on a single session flow.
// We will manage state inside the screens using getLatestSessionId and getSession.
