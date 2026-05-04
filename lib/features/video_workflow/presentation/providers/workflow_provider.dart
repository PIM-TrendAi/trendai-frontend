import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/n8n_repository.dart';

enum WorkflowStatus {
  idle,
  generatingScript,
  pendingScriptReview,
  generatingVideo,
  pendingVideoReview,
  posting,
  done,
  error,
}

class WorkflowState {
  const WorkflowState({
    this.sessionId,
    this.scriptContent,
    this.videoUrl,
    this.videoId,
    this.platform,
    this.status = WorkflowStatus.idle,
    this.errorMessage,
    this.isFallback = false,
  });

  final String? sessionId;
  final String? scriptContent;
  final String? videoUrl;
  final String? videoId;
  final String? platform;
  final WorkflowStatus status;
  final String? errorMessage;
  final bool isFallback;

  WorkflowState copyWith({
    String? sessionId,
    String? scriptContent,
    String? videoUrl,
    String? videoId,
    String? platform,
    WorkflowStatus? status,
    String? errorMessage,
    bool? isFallback,
  }) {
    return WorkflowState(
      sessionId: sessionId ?? this.sessionId,
      scriptContent: scriptContent ?? this.scriptContent,
      videoUrl: videoUrl ?? this.videoUrl,
      videoId: videoId ?? this.videoId,
      platform: platform ?? this.platform,
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
      isFallback: isFallback ?? this.isFallback,
    );
  }
}

final workflowProvider = StateNotifierProvider<WorkflowNotifier, WorkflowState>(
  (ref) => WorkflowNotifier(ref.read(n8nRepositoryProvider)),
);

class WorkflowNotifier extends StateNotifier<WorkflowState> {
  WorkflowNotifier(this._repo) : super(const WorkflowState());

  final N8nRepository _repo;

  Future<void> startWorkflow({
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
    state = state.copyWith(status: WorkflowStatus.generatingScript, platform: platform);
    try {
      final res = await _repo.startWorkflow(
        creatorId: creatorId,
        selectedVideoId: selectedVideoId,
        videoTitle: videoTitle,
        videoAuthor: videoAuthor,
        videoHashtags: videoHashtags,
        videoViews: videoViews,
        videoLikes: videoLikes,
        niche: niche,
        userPrompt: userPrompt,
        platform: platform,
      );
      state = state.copyWith(
        sessionId: res.sessionId,
        scriptContent: res.scriptContent,
        status: WorkflowStatus.pendingScriptReview,
      );
    } catch (e) {
      state = state.copyWith(
        status: WorkflowStatus.error,
        errorMessage: e.toString(),
      );
    }
  }

  Future<void> approveScript() async {
    final sessionId = state.sessionId;
    if (sessionId == null) return;
    state = state.copyWith(status: WorkflowStatus.generatingVideo);
    try {
      await _repo.approveScript(sessionId, platform: state.platform ?? 'tiktok');
      // status stays generatingVideo — polling screen takes over
    } catch (e) {
      state = state.copyWith(
        status: WorkflowStatus.error,
        errorMessage: e.toString(),
      );
    }
  }

  Future<void> declineScript() async {
    final sessionId = state.sessionId;
    if (sessionId == null) return;
    state = state.copyWith(status: WorkflowStatus.generatingScript, scriptContent: null);
    try {
      await _repo.declineScript(sessionId, platform: state.platform ?? 'tiktok');
      // status stays generatingScript — polling screen takes over
    } catch (e) {
      state = state.copyWith(
        status: WorkflowStatus.error,
        errorMessage: e.toString(),
      );
    }
  }

  Future<void> pollVideoStatus() async {
    final sessionId = state.sessionId;
    if (sessionId == null) return;
    try {
      final res = await _repo.checkVideoStatus(sessionId, platform: state.platform ?? 'tiktok');
      if ((res.status == 'ready' || res.status == 'video_pending') && res.videoUrl != null) {
        state = state.copyWith(
          videoUrl: res.videoUrl,
          videoId: res.videoId,
          isFallback: res.isFallback,
          status: WorkflowStatus.pendingVideoReview,
        );
      } else {
        // Keep isFallback updated even while still generating
        if (res.isFallback) {
          state = state.copyWith(isFallback: true);
        }
      }
    } catch (_) {
      // polling errors are silent — the screen handles timeout
    }
  }

  Future<void> approveVideo() async {
    final sessionId = state.sessionId;
    if (sessionId == null) return;
    state = state.copyWith(status: WorkflowStatus.posting);
    try {
      await _repo.approveVideo(sessionId, videoId: state.videoId, platform: state.platform ?? 'tiktok');
      state = state.copyWith(status: WorkflowStatus.done);
    } catch (e) {
      state = state.copyWith(
        status: WorkflowStatus.error,
        errorMessage: e.toString(),
      );
    }
  }

  Future<void> declineVideo() async {
    final sessionId = state.sessionId;
    if (sessionId == null) return;
    state = state.copyWith(status: WorkflowStatus.generatingVideo);
    try {
      await _repo.declineVideo(sessionId, videoId: state.videoId, platform: state.platform ?? 'tiktok');
      // goes back to polling
    } catch (e) {
      state = state.copyWith(
        status: WorkflowStatus.error,
        errorMessage: e.toString(),
      );
    }
  }

  void setScriptContent(String content) {
    state = state.copyWith(
      scriptContent: content,
      status: WorkflowStatus.pendingScriptReview,
    );
  }

  void setSessionId(String sessionId) {
    state = state.copyWith(sessionId: sessionId);
  }

  void reset() => state = const WorkflowState();
}
