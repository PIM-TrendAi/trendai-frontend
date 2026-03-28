// Global providers for trending TikTok videos.
// Keeping this in a separate file lets the splash screen pre-warm the cache
// before the user navigates to the Trends screen.
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/n8n_service.dart';
import '../../../core/storage/secure_storage.dart';
import '../../video_workflow/data/models/workflow_models.dart';

/// Keywords associated with each niche for loose client-side matching.
/// A video matches if ANY keyword appears in its title, niche field, or hashtags.
const nicheKeywords = <String, List<String>>{
  'entertainment': ['entertainment', 'funny', 'comedy', 'viral', 'fun', 'meme', 'prank', 'challenge', 'skit'],
  'education':     ['education', 'learn', 'tutorial', 'howto', 'tips', 'facts', 'science', 'history', 'study'],
  'business':      ['business', 'entrepreneur', 'startup', 'marketing', 'sales', 'ceo', 'hustle', 'success'],
  'finance':       ['finance', 'money', 'investing', 'stocks', 'crypto', 'budget', 'wealth', 'financial', 'income'],
  'fitness':       ['fitness', 'workout', 'gym', 'health', 'exercise', 'diet', 'nutrition', 'training', 'muscle'],
  'motivation':    ['motivation', 'mindset', 'inspire', 'success', 'goals', 'growth', 'positivity', 'mindfulness'],
  'gaming':        ['gaming', 'gamer', 'game', 'gameplay', 'esports', 'twitch', 'ps5', 'xbox', 'minecraft', 'fortnite'],
  'art':           ['art', 'design', 'drawing', 'painting', 'creative', 'artist', 'illustration', 'sketch', 'digital'],
  'fashion':       ['fashion', 'style', 'outfit', 'ootd', 'clothing', 'beauty', 'makeup', 'skincare', 'aesthetic'],
  'cooking':       ['cooking', 'food', 'recipe', 'chef', 'baking', 'meal', 'kitchen', 'eat', 'delicious'],
  'travel':        ['travel', 'adventure', 'explore', 'trip', 'vacation', 'wanderlust', 'destination', 'vlog'],
  'tech':          ['tech', 'technology', 'coding', 'programming', 'ai', 'software', 'developer', 'gadget', 'review'],
  'podcast':       ['podcast', 'interview', 'talk', 'discussion', 'story', 'storytelling', 'narration'],
  'news':          ['news', 'politics', 'world', 'breaking', 'update', 'current', 'economy', 'report'],
  'storytelling':  ['story', 'storytelling', 'narrative', 'tale', 'sharing', 'life', 'experience'],
  // Niche-chip aliases used in trends_list_screen
  'comedy':        ['comedy', 'funny', 'meme', 'prank', 'humor', 'skit', 'laugh'],
  'beauty':        ['beauty', 'makeup', 'skincare', 'glow', 'cosmetic', 'hair', 'nails'],
  'food':          ['food', 'recipe', 'cooking', 'eat', 'chef', 'baking', 'meal', 'delicious'],
  'music':         ['music', 'song', 'singer', 'rap', 'dance', 'beat', 'album', 'artist'],
};

bool _matchesNiche(TrendingVideoModel v, String niche) {
  final keywords = nicheKeywords[niche.toLowerCase()] ?? [niche.toLowerCase()];
  final haystack = [v.title, v.niche, ...v.hashtags].join(' ').toLowerCase();
  return keywords.any((kw) => haystack.contains(kw));
}

/// The user's saved niches from secure storage.
final userNichesProvider = FutureProvider<List<String>>((ref) async {
  return ref.read(secureStorageProvider).readCreatorNiches();
});

/// Trending TikTok videos, parameterised by niche ('' = all).
/// Always fetches ALL videos from n8n then filters client-side with loose
/// keyword matching — so related hashtags are included, not just exact matches.
/// Falls back to showing all videos if no keyword matches are found.
final tiktokVideosProvider =
    FutureProvider.family<List<TrendingVideoModel>, String>((ref, niche) async {
  final all = await ref.read(n8nServiceProvider).fetchTrendingVideos(niche: null);
  if (niche.isEmpty) return all;
  final filtered = all.where((v) => _matchesNiche(v, niche)).toList();
  return filtered.isNotEmpty ? filtered : all;
});
