// TrendAI — Dio client for Django REST API.
// Server address is centralised in core/config/server_config.dart — edit there.
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/server_config.dart';
import '../storage/secure_storage.dart';

final dioProvider = Provider<Dio>((ref) {
  final dio = Dio(BaseOptions(
    baseUrl: ServerConfig.httpBase,
    connectTimeout: const Duration(seconds: 30),
    receiveTimeout: const Duration(seconds: 60),
    headers: {
      'Content-Type': 'application/json',
      'Bypass-Tunnel-Reminder': 'true',
    },
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
          final refreshDio = Dio(BaseOptions(baseUrl: ServerConfig.httpBase));
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
