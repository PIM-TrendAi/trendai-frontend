// Auth repository — Django REST API backend.
// Stores JWT tokens in SecureStorage. Also writes creatorId so n8n workflow
// screens can read it without going through the auth provider.
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/dio_client.dart';
import '../../core/storage/secure_storage.dart';
import 'data/models.dart';

export 'data/models.dart' show UserModel;

final authNotifierProvider =
    AsyncNotifierProvider<AuthNotifier, UserModel?>(() => AuthNotifier());

class AuthNotifier extends AsyncNotifier<UserModel?> {
  late final Dio _dio;
  late final SecureStorageService _storage;

  @override
  Future<UserModel?> build() async {
    _dio = ref.read(dioProvider);
    _storage = ref.read(secureStorageProvider);

    final token = await _storage.readAccessToken();
    if (token == null) return null;

    // Restore user from locally cached profile (avoids extra network call).
    final profile = await _storage.readCreatorProfile();
    if (profile['id'] == null) return null;

    final tiktok = await _storage.isTikTokConnected();
    return UserModel(
      id: int.tryParse(profile['id']!) ?? 0,
      email: profile['email'] ?? '',
      name: profile['name'] ?? '',
      categories: const [],
      plan: 'free',
      accessToken: token,
      refreshToken: await _storage.readRefreshToken() ?? '',
      tiktokConnected: tiktok,
    );
  }

  Future<void> login(String email, String password) async {
    state = const AsyncValue.loading();
    try {
      final res = await _dio.post('/auth/login/', data: {
        'email': email,
        'password': password,
      });
      final user = UserModel.fromJson(res.data as Map<String, dynamic>);
      await _saveSession(user);
      state = AsyncValue.data(user);
    } on DioException catch (e, st) {
      state = AsyncValue.error(_errorMsg(e), st);
    }
  }

  Future<void> register(String name, String email, String password) async {
    state = const AsyncValue.loading();
    try {
      final res = await _dio.post('/auth/register/', data: {
        'name': name,
        'email': email,
        'password': password,
      });
      final user = UserModel.fromJson(res.data as Map<String, dynamic>);
      await _saveSession(user);
      state = AsyncValue.data(user);
    } on DioException catch (e, st) {
      state = AsyncValue.error(_errorMsg(e), st);
    }
  }

  Future<void> saveNiches(List<String> niches) async {
    try {
      await _dio.patch('/auth/profile/', data: {'categories': niches});
      await _storage.writeCreatorNiches(niches);
    } catch (_) {
      // Best-effort — store locally even if backend call fails
      await _storage.writeCreatorNiches(niches);
    }
  }

  Future<void> setTikTokConnected() async {
    await _storage.setTikTokConnected(true);
    final current = state.valueOrNull;
    if (current != null) {
      state = AsyncValue.data(current.copyWith(tiktokConnected: true));
    }
  }

  Future<void> logout() async {
    await _storage.clearAll();
    state = const AsyncValue.data(null);
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  Future<void> _saveSession(UserModel user) async {
    // Write JWT tokens (access_token key used by router guard)
    await _storage.writeAccessToken(user.accessToken);
    await _storage.writeRefreshToken(user.refreshToken);
    // Cache profile locally for fast restore on next app launch
    await _storage.writeCreatorProfile(
      id: user.id.toString(),
      name: user.name,
      email: user.email,
    );
    // Overwrite access_token back to JWT (writeCreatorProfile sets it to id)
    await _storage.writeAccessToken(user.accessToken);
  }

  String _errorMsg(DioException e) {
    final data = e.response?.data;
    if (data is Map) {
      final vals =
          data.values.whereType<List>().expand((v) => v).toList();
      if (vals.isNotEmpty) return vals.first.toString();
      final nonList = data.values.whereType<String>().toList();
      if (nonList.isNotEmpty) return nonList.first;
    }
    return 'Network error. Check your connection.';
  }
}
