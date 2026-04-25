// Auth User model — mirrors backend UserProfileSerializer response.
class UserModel {
  final int id;
  final String email;
  final String name;
  final List<String> categories;
  final String plan;
  final String accessToken;
  final String refreshToken;
  final bool tiktokConnected;

  // Used by n8n workflow screens to identify the creator
  String get creatorId => id.toString();

  const UserModel({
    required this.id,
    required this.email,
    required this.name,
    required this.categories,
    required this.plan,
    required this.accessToken,
    required this.refreshToken,
    this.tiktokConnected = false,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    final tokens = json['tokens'] as Map<String, dynamic>? ?? {};
    return UserModel(
      id: json['id'] as int,
      email: json['email'] as String,
      name: json['name'] as String,
      categories: List<String>.from(json['categories'] ?? []),
      plan: json['plan'] as String? ?? 'free',
      accessToken: tokens['access'] as String? ?? '',
      refreshToken: tokens['refresh'] as String? ?? '',
    );
  }

  UserModel copyWith({bool? tiktokConnected, List<String>? categories}) => UserModel(
        id: id,
        email: email,
        name: name,
        categories: categories ?? this.categories,
        plan: plan,
        accessToken: accessToken,
        refreshToken: refreshToken,
        tiktokConnected: tiktokConnected ?? this.tiktokConnected,
      );
}

/// Trend model — mirrors backend TrendSerializer response.
class TrendModel {
  final int id;
  final String hashtag;
  final String platform;
  final double score;
  final double growth;
  final String views;
  final String type; // hashtag | audio | video
  final String colorStart;
  final String colorEnd;
  final List<String> analysis;
  final String targetAudience;
  final String avgVideoLength;
  final String dominantFormat;
  final String bestPostingTime;
  final int totalViews;
  final int totalLikes;
  final int totalShares;
  final List<Map<String, dynamic>> chartData;
  final bool isSaved;

  const TrendModel({
    required this.id,
    required this.hashtag,
    required this.platform,
    required this.score,
    required this.growth,
    required this.views,
    required this.type,
    required this.colorStart,
    required this.colorEnd,
    required this.analysis,
    required this.targetAudience,
    required this.avgVideoLength,
    required this.dominantFormat,
    required this.bestPostingTime,
    required this.totalViews,
    required this.totalLikes,
    required this.totalShares,
    required this.chartData,
    required this.isSaved,
  });

  factory TrendModel.fromJson(Map<String, dynamic> json) {
    return TrendModel(
      id: json['id'] as int,
      hashtag: json['hashtag'] as String,
      platform: json['platform'] as String,
      score: (json['score'] as num).toDouble(),
      growth: (json['growth'] as num).toDouble(),
      views: json['views'] as String,
      type: json['type'] as String,
      colorStart: json['color_start'] as String? ?? '#6C5CE7',
      colorEnd: json['color_end'] as String? ?? '#00C6FF',
      analysis: List<String>.from(json['analysis'] ?? []),
      targetAudience: json['target_audience'] as String? ?? '',
      avgVideoLength: json['avg_video_length'] as String? ?? '',
      dominantFormat: json['dominant_format'] as String? ?? '',
      bestPostingTime: json['best_posting_time'] as String? ?? '',
      totalViews: json['total_views'] as int? ?? 0,
      totalLikes: json['total_likes'] as int? ?? 0,
      totalShares: json['total_shares'] as int? ?? 0,
      chartData: List<Map<String, dynamic>>.from(json['chart_data'] ?? []),
      isSaved: json['is_saved'] as bool? ?? false,
    );
  }

  TrendModel copyWith({bool? isSaved}) => TrendModel(
        id: id, hashtag: hashtag, platform: platform, score: score,
        growth: growth, views: views, type: type, colorStart: colorStart,
        colorEnd: colorEnd, analysis: analysis, targetAudience: targetAudience,
        avgVideoLength: avgVideoLength, dominantFormat: dominantFormat,
        bestPostingTime: bestPostingTime, totalViews: totalViews,
        totalLikes: totalLikes, totalShares: totalShares, chartData: chartData,
        isSaved: isSaved ?? this.isSaved,
      );
}

/// AIScript model — mirrors backend AIScriptSerializer response.
class AIScriptModel {
  final int id;
  final String prompt;
  final String style;
  final String duration;
  final String platform;
  final String hook;
  final String script;
  final String cta;
  final List<String> hashtags;
  final String createdAt;

  const AIScriptModel({
    required this.id,
    required this.prompt,
    required this.style,
    required this.duration,
    required this.platform,
    required this.hook,
    required this.script,
    required this.cta,
    required this.hashtags,
    required this.createdAt,
  });

  factory AIScriptModel.fromJson(Map<String, dynamic> json) {
    return AIScriptModel(
      id: json['id'] as int,
      prompt: json['prompt'] as String,
      style: json['style'] as String,
      duration: json['duration'] as String,
      platform: json['platform'] as String,
      hook: json['hook'] as String? ?? '',
      script: json['script'] as String? ?? '',
      cta: json['cta'] as String? ?? '',
      hashtags: List<String>.from(json['hashtags'] ?? []),
      createdAt: json['created_at'] as String? ?? '',
    );
  }
}

/// FacebookReel model — mirrors backend FacebookReelSerializer response.
class FacebookReelModel {
  final int id;
  final String reelId;
  final String? reelUrl;
  final String? pageUrl;
  final String? text;
  final String? createdAt;
  final int playCount;
  final int durationMs;
  final String? niche;
  final String status;
  final String? thumbnailUrl;

  const FacebookReelModel({
    required this.id,
    required this.reelId,
    this.reelUrl,
    this.pageUrl,
    this.text,
    this.createdAt,
    this.playCount = 0,
    this.durationMs = 0,
    this.niche,
    this.status = 'scraped',
    this.thumbnailUrl,
  });

  factory FacebookReelModel.fromJson(Map<String, dynamic> json) {
    return FacebookReelModel(
      id: json['id'] as int,
      reelId: json['reel_id'] as String,
      reelUrl: json['reel_url'] as String?,
      pageUrl: json['page_url'] as String?,
      text: json['text'] as String?,
      createdAt: json['created_at'] as String?,
      playCount: json['play_count'] as int? ?? 0,
      durationMs: json['duration_ms'] as int? ?? 0,
      niche: json['niche'] as String?,
      status: json['status'] as String? ?? 'scraped',
      thumbnailUrl: json['thumbnail_url'] as String?,
    );
  }
}

/// YouTubeVideo model — mirrors backend YouTubeVideoSerializer response.
class YouTubeVideoModel {
  final int id;
  final String videoId;
  final String? titre;
  final String? description;
  final String? tags;
  final int vues;
  final String? niche;
  final String region;
  final String? scrapedAt;

  const YouTubeVideoModel({
    required this.id,
    required this.videoId,
    this.titre,
    this.description,
    this.tags,
    this.vues = 0,
    this.niche,
    this.region = 'TN',
    this.scrapedAt,
  });

  factory YouTubeVideoModel.fromJson(Map<String, dynamic> json) {
    return YouTubeVideoModel(
      id: json['id'] as int,
      videoId: json['video_id'] as String,
      titre: json['titre'] as String?,
      description: json['description'] as String?,
      tags: json['tags'] as String?,
      vues: json['vues'] as int? ?? 0,
      niche: json['niche'] as String?,
      region: json['region'] as String? ?? 'TN',
      scrapedAt: json['scraped_at'] as String?,
    );
  }
}

/// ThreadsPost model — mirrors backend Threads post response.
class ThreadsPostModel {
  final int id;
  final String postId;
  final String? username;
  final String? text;
  final String? thumbnailUrl;
  final String? postUrl;
  final int likeCount;
  final String? niche;
  final String? createdAt;

  const ThreadsPostModel({
    required this.id,
    required this.postId,
    this.username,
    this.text,
    this.thumbnailUrl,
    this.postUrl,
    this.likeCount = 0,
    this.niche,
    this.createdAt,
  });

  factory ThreadsPostModel.fromJson(Map<String, dynamic> json) {
    return ThreadsPostModel(
      id: json['id'] as int,
      postId: json['post_id'] as String,
      username: json['username'] as String?,
      text: json['text'] as String?,
      thumbnailUrl: json['thumbnail_url'] as String?,
      postUrl: json['post_url'] as String?,
      likeCount: json['like_count'] as int? ?? 0,
      niche: json['niche'] as String?,
      createdAt: json['created_at'] as String?,
    );
  }
}
