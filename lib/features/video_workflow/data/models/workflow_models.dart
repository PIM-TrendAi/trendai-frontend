class TrendingVideoModel {
  const TrendingVideoModel({
    required this.videoId,
    required this.title,
    required this.author,
    required this.thumbnailUrl,
    required this.views,
    required this.likes,
    required this.niche,
    this.hashtags = const [],
    this.tiktokUrl = '',
  });

  final String videoId;
  final String title;
  final String author;
  final String thumbnailUrl;
  final String views;
  final String likes;
  final String niche;
  final List<String> hashtags;
  final String tiktokUrl;

  factory TrendingVideoModel.fromJson(Map<String, dynamic> json) {
    return TrendingVideoModel(
      videoId: json['video_id'] as String? ?? '',
      title: json['title'] as String? ?? 'Trending Video',
      author: json['author'] as String? ?? '',
      thumbnailUrl: json['thumbnail_url'] as String? ?? '',
      views: json['views'] as String? ?? '0',
      likes: json['likes'] as String? ?? '0',
      niche: json['category'] as String? ?? '',
      hashtags: _parseHashtags(json['hashtags']),
      tiktokUrl: json['tiktok_url'] as String? ?? '',
    );
  }

  static List<String> _parseHashtags(dynamic value) {
    if (value == null) return [];
    if (value is List) return value.map((e) => e.toString()).toList();
    if (value is String) {
      // PostgreSQL array format: "{#tag1,#tag2}" → ["#tag1", "#tag2"]
      final cleaned = value.replaceAll(RegExp(r'[{}"]'), '').trim();
      if (cleaned.isEmpty) return [];
      return cleaned.split(',').map((e) => e.trim()).toList();
    }
    return [];
  }
}

class WorkflowStartResponse {
  const WorkflowStartResponse({
    required this.sessionId,
    required this.scriptContent,
    required this.status,
  });

  final String sessionId;
  final String scriptContent;
  final String status;

  factory WorkflowStartResponse.fromJson(Map<String, dynamic> json) {
    return WorkflowStartResponse(
      sessionId: json['sessionId'] as String? ?? '',
      scriptContent: json['scriptContent'] as String? ?? '',
      status: json['status'] as String? ?? '',
    );
  }
}

class ScriptActionResponse {
  const ScriptActionResponse({
    required this.sessionId,
    required this.status,
    this.scriptContent,
  });

  final String sessionId;
  final String status;
  final String? scriptContent; // present on decline/regenerate

  factory ScriptActionResponse.fromJson(Map<String, dynamic> json) {
    return ScriptActionResponse(
      sessionId: json['sessionId'] as String? ?? '',
      status: json['status'] as String? ?? '',
      scriptContent: json['scriptContent'] as String?,
    );
  }
}

class VideoActionResponse {
  const VideoActionResponse({
    required this.sessionId,
    required this.status,
  });

  final String sessionId;
  final String status;

  factory VideoActionResponse.fromJson(Map<String, dynamic> json) {
    return VideoActionResponse(
      sessionId: json['sessionId'] as String? ?? '',
      status: json['status'] as String? ?? '',
    );
  }
}

class CreatorVideoModel {
  const CreatorVideoModel({
    required this.videoId,
    required this.sessionId,
    required this.videoUrl,
    required this.status,
    required this.createdAt,
    this.caption = '',
    this.scriptContent = '',
    this.thumbnailUrl = '',
  });

  final String videoId;
  final String sessionId;
  final String videoUrl;
  final String status; // pending_approval | approved | declined
  final String createdAt;
  final String caption;
  final String scriptContent;
  final String thumbnailUrl;

  factory CreatorVideoModel.fromJson(Map<String, dynamic> json) {
    return CreatorVideoModel(
      videoId: json['video_id'] as String? ?? '',
      sessionId: json['session_id'] as String? ?? '',
      videoUrl: json['video_url'] as String? ?? '',
      status: json['status'] as String? ?? 'pending_approval',
      createdAt: json['created_at'] as String? ?? '',
      caption: json['caption'] as String? ?? '',
      scriptContent: json['script_content'] as String? ?? '',
      thumbnailUrl: json['thumbnail_url'] as String? ?? '',
    );
  }
}

class VideoStatusResponse {
  const VideoStatusResponse({
    required this.sessionId,
    required this.status,
    this.videoUrl,
  });

  final String sessionId;
  final String status; // 'generating' | 'ready' | 'error'
  final String? videoUrl;

  factory VideoStatusResponse.fromJson(Map<String, dynamic> json) {
    return VideoStatusResponse(
      sessionId: json['sessionId'] as String? ?? '',
      status: json['status'] as String? ?? 'generating',
      videoUrl: json['videoUrl'] as String?,
    );
  }
}
