enum WorkflowStatus {
  scraping,
  scriptGeneration,
  scriptPending,
  scriptApproved,
  scriptDeclined,
  videoPending,
  videoApproved,
  videoDeclined,
  posted,
  failed,
}

WorkflowStatus _parseStatus(String status) {
  switch (status) {
    case 'scraping':
      return WorkflowStatus.scraping;
    case 'script_generation':
      return WorkflowStatus.scriptGeneration;
    case 'script_pending':
      return WorkflowStatus.scriptPending;
    case 'script_approved':
      return WorkflowStatus.scriptApproved;
    case 'script_declined':
      return WorkflowStatus.scriptDeclined;
    case 'video_pending':
      return WorkflowStatus.videoPending;
    case 'video_approved':
      return WorkflowStatus.videoApproved;
    case 'video_declined':
      return WorkflowStatus.videoDeclined;
    case 'posted':
      return WorkflowStatus.posted;
    case 'failed':
      return WorkflowStatus.failed;
    default:
      return WorkflowStatus.scraping;
  }
}

class TrendingVideo {
  final String videoId;
  final String title;
  final String author;
  final String views;
  final String thumbnail;

  TrendingVideo({
    required this.videoId,
    required this.title,
    required this.author,
    required this.views,
    required this.thumbnail,
  });

  factory TrendingVideo.fromJson(Map<String, dynamic> json) {
    return TrendingVideo(
      videoId: json['video_id'] ?? '',
      title: json['title'] ?? 'Unknown',
      author: json['author'] ?? '@unknown',
      views: json['views'] ?? '0',
      thumbnail: json['thumbnail_url'] ?? '',
    );
  }
}

class WorkflowSession {
  final String sessionId;
  final String creatorId;
  final String niche;
  final WorkflowStatus status;
  final String selectedVideoId;

  final String? scriptId;
  final String? scriptContent;
  final String? scriptStatus;

  final String? videoId;
  final String? videoUrl;
  final String? videoThumbnail;
  final String? videoStatus;

  final String? tiktokPostUrl;

  WorkflowSession({
    required this.sessionId,
    required this.creatorId,
    required this.niche,
    required this.status,
    required this.selectedVideoId,
    this.scriptId,
    this.scriptContent,
    this.scriptStatus,
    this.videoId,
    this.videoUrl,
    this.videoThumbnail,
    this.videoStatus,
    this.tiktokPostUrl,
  });

  factory WorkflowSession.fromJson(Map<String, dynamic> json) {
    return WorkflowSession(
      sessionId: json['session_id'] ?? '',
      creatorId: json['creator_id'] ?? '',
      niche: json['niche'] ?? '',
      status: _parseStatus(json['status'] ?? 'scraping'),
      selectedVideoId: json['selected_video_id'] ?? '',
      scriptId: json['script_id'],
      scriptContent: json['script_content'],
      scriptStatus: json['script_status'],
      videoId: json['video_id'],
      videoUrl: json['video_url'],
      videoThumbnail: json['video_thumbnail'],
      videoStatus: json['video_status'],
      tiktokPostUrl: json['tiktok_post_url'],
    );
  }
}
