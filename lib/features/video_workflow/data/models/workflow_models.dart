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
      videoId: json['video_id'] as String? ?? json['id'] as String? ?? '',
      title: json['title'] as String? ?? json['desc'] as String? ?? 'Trending Video',
      author: json['author'] as String? ?? json['author_name'] as String?
          ?? json['unique_id'] as String? ?? '',
      thumbnailUrl: json['thumbnail_url'] as String? ?? json['cover'] as String?
          ?? json['origin_cover'] as String? ?? '',
      // Try every name TikTok/n8n might use for view count
      views: _pickCount(json, const [
        'views', 'play_count', 'playCount', 'view_count', 'viewCount',
        'plays', 'video_play_count',
      ]),
      // Try every name TikTok/n8n might use for like count
      likes: _pickCount(json, const [
        'likes', 'digg_count', 'diggCount', 'like_count', 'likeCount',
        'heart', 'hearts',
      ]),
      niche: json['category'] as String? ?? json['niche'] as String? ?? '',
      hashtags: _parseHashtags(json['hashtags'] ?? json['challenges']),
      tiktokUrl: json['tiktok_url'] as String? ?? json['url'] as String? ?? '',
    );
  }

  /// Returns the first non-zero value found among [keys], formatted as K/M/B.
  static String _pickCount(Map<String, dynamic> json, List<String> keys) {
    for (final key in keys) {
      final raw = json[key];
      if (raw == null) continue;
      final formatted = _parseCountField(raw);
      if (formatted != '0') return formatted;
    }
    // All were null or zero — return the raw value of the first present key
    for (final key in keys) {
      if (json.containsKey(key)) return _parseCountField(json[key]);
    }
    return '0';
  }

  /// Accepts String ("1.2M"), int (1_200_000), or double.
  static String _parseCountField(dynamic value) {
    if (value == null) return '0';
    if (value is String) {
      final s = value.trim();
      if (s.isEmpty || s == '0') return '0';
      return s; // already formatted ("1.2M") — trust it
    }
    final n = (value as num).toDouble();
    if (n >= 1e9) return '${(n / 1e9).toStringAsFixed(1)}B';
    if (n >= 1e6) return '${(n / 1e6).toStringAsFixed(1)}M';
    if (n >= 1e3) return '${(n / 1e3).toStringAsFixed(1)}K';
    return n.toInt().toString();
  }

  static List<String> _parseHashtags(dynamic value) {
    if (value == null) return [];
    if (value is List) return value.map((e) => e.toString()).toList();
    if (value is String) {
      // PostgreSQL array format: "{#tag1,#tag2}" → ["#tag1", "#tag2"]
      final cleaned = value.replaceAll(RegExp(r'[{}"]'), '').trim();
      if (cleaned.isEmpty) return [];
      // Split by comma then strip any internal quotes
      return cleaned.split(',').map((e) => e.trim().replaceAll(RegExp(r'^"|"$'), '')).toList();
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
      sessionId: json['sessionId'] as String? ?? json['session_id'] as String? ?? '',
      scriptContent: json['scriptContent'] as String? ?? json['script_content'] as String? ?? '',
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
