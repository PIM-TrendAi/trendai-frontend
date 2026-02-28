/// Auth repository — wraps Dio calls for register, login, profile.
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/network/dio_client.dart';
import '../../core/storage/secure_storage.dart';
import 'data/models.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref.read(dioProvider), ref.read(secureStorageProvider));
});

class AuthRepository {
  AuthRepository(this._dio, this._storage);
  final Dio _dio;
  final SecureStorageService _storage;

  Future<UserModel> register({
    required String name,
    required String email,
    required String password,
  }) async {
    final res = await _dio.post('/auth/register/', data: {
      'name': name,
      'email': email,
      'password': password,
      'confirm_password': password,
    });
    final user = UserModel.fromJson(res.data as Map<String, dynamic>);
    await _storage.writeAccessToken(user.accessToken);
    await _storage.writeRefreshToken(user.refreshToken);
    return user;
  }

  Future<UserModel> login({required String email, required String password}) async {
    final res = await _dio.post('/auth/login/', data: {'email': email, 'password': password});
    final user = UserModel.fromJson(res.data as Map<String, dynamic>);
    await _storage.writeAccessToken(user.accessToken);
    await _storage.writeRefreshToken(user.refreshToken);
    return user;
  }

  Future<UserModel> getProfile() async {
    final res = await _dio.get('/auth/profile/');
    // Profile endpoint doesn't return tokens, build a partial model
    final data = Map<String, dynamic>.from(res.data);
    data['tokens'] = {};
    return UserModel.fromJson(data);
  }

  Future<void> logout() async => _storage.clearAll();
}

/// Auth Riverpod provider (AsyncNotifier).
final authNotifierProvider =
    AsyncNotifierProvider<AuthNotifier, UserModel?>(AuthNotifier.new);

class AuthNotifier extends AsyncNotifier<UserModel?> {
  @override
  Future<UserModel?> build() async {
    // On app start, try to restore session from stored tokens
    final storage = ref.read(secureStorageProvider);
    final hasToken = await storage.hasTokens();
    if (!hasToken) return null;
    try {
      return await ref.read(authRepositoryProvider).getProfile();
    } catch (_) {
      return null;
    }
  }

  Future<void> register(String name, String email, String password) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(authRepositoryProvider).register(
            name: name, email: email, password: password,
          ),
    );
  }

  Future<void> login(String email, String password) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(authRepositoryProvider).login(email: email, password: password),
    );
  }

  Future<void> logout() async {
    await ref.read(authRepositoryProvider).logout();
    state = const AsyncData(null);
  }
}
