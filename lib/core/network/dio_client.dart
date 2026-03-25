// TrendAI — Dio client for Django REST API.
// Base URL targets physical device WiFi (PC IP: 192.168.1.112).
// AuthInterceptor injects JWT and handles token refresh automatically.
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../storage/secure_storage.dart';

const _baseUrl = 'http://192.168.1.112:8000/api';

final dioProvider = Provider<Dio>((ref) {
  final dio = Dio(BaseOptions(
    baseUrl: _baseUrl,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 15),
    headers: {'Content-Type': 'application/json'},
  ));
  dio.interceptors.add(_AuthInterceptor(ref.read(secureStorageProvider)));
  return dio;
});

class _AuthInterceptor extends Interceptor {
  _AuthInterceptor(this._storage);
  final SecureStorageService _storage;

  @override
  void onRequest(
      RequestOptions options, RequestInterceptorHandler handler) async {
    final token = await _storage.readAccessToken();
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    if (err.response?.statusCode == 401) {
      final refresh = await _storage.readRefreshToken();
      if (refresh != null) {
        try {
          final refreshDio = Dio(BaseOptions(baseUrl: _baseUrl));
          final res = await refreshDio
              .post('/auth/refresh/', data: {'refresh': refresh});
          final newAccess = res.data['access'] as String;
          await _storage.writeAccessToken(newAccess);
          final opts = err.requestOptions;
          opts.headers['Authorization'] = 'Bearer $newAccess';
          final response = await refreshDio.fetch(opts);
          return handler.resolve(response);
        } catch (_) {
          await _storage.clearAll();
        }
      }
    }
    handler.next(err);
  }
}
