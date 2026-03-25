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

  UserModel copyWith({bool? tiktokConnected}) => UserModel(
        id: id,
        email: email,
        name: name,
        categories: categories,
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
