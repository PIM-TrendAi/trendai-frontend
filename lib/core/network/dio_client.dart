/// TrendAI API — Dio HTTP client with JWT auth interceptor.
/// Automatically injects Bearer token and handles 401 by refreshing.
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../storage/secure_storage.dart';

// Change to your machine's IP when testing on physical device
// Android emulator: 10.0.2.2, iOS simulator: 127.0.0.1
final _baseUrl = Platform.isAndroid ? 'http://10.0.2.2:8000/api' : 'http://127.0.0.1:8000/api';

final dioProvider = Provider<Dio>((ref) {
  final dio = Dio(BaseOptions(
    baseUrl: _baseUrl,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 15),
    headers: {'Content-Type': 'application/json'},
  ));

  dio.interceptors.add(_AuthInterceptor(ref, dio));
  return dio;
});

/// Injects JWT token and handles 401 → refresh → retry.
class _AuthInterceptor extends Interceptor {
  _AuthInterceptor(this._ref, this._dio);
  final Ref _ref;
  final Dio _dio;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (options.path.contains('/auth/refresh')) {
      return handler.next(options);
    }

    final storage = _ref.read(secureStorageProvider);
    final token = await storage.readAccessToken();
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    if (err.requestOptions.path.contains('/auth/refresh')) {
      await _ref.read(secureStorageProvider).clearAll();
      return handler.next(err);
    }

    if (err.response?.statusCode == 401) {
      // Try refreshing the token
      try {
        final storage = _ref.read(secureStorageProvider);
        final refresh = await storage.readRefreshToken();
        if (refresh == null) {
          handler.next(err);
          return;
        }
        final response = await _dio.post(
          '/auth/refresh/',
          data: {'refresh': refresh},
          options: Options(headers: {}), // no auth header to avoid loop
        );
        final newAccess = response.data['access'] as String;
        await storage.writeAccessToken(newAccess);
        // Retry original request
        final retried = await _dio.fetch(
          err.requestOptions..headers['Authorization'] = 'Bearer $newAccess',
        );
        handler.resolve(retried);
        return;
      } catch (_) {
        // Refresh also failed — clear tokens and let the app redirect to login
        await _ref.read(secureStorageProvider).clearAll();
      }
    }
    handler.next(err);
  }
}
