/// SecureStorage service wrapping flutter_secure_storage.
/// Stores JWT access + refresh tokens with AES encryption on Android,
/// Keychain on iOS.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const _keyAccess = 'access_token';
const _keyRefresh = 'refresh_token';

final secureStorageProvider = Provider<SecureStorageService>(
  (_) => SecureStorageService(),
);

class SecureStorageService {
  SecureStorageService()
      : _storage = const FlutterSecureStorage(
          aOptions: AndroidOptions(encryptedSharedPreferences: true),
        );

  final FlutterSecureStorage _storage;

  Future<void> writeAccessToken(String token) =>
      _storage.write(key: _keyAccess, value: token);

  Future<void> writeRefreshToken(String token) =>
      _storage.write(key: _keyRefresh, value: token);

  Future<String?> readAccessToken() => _storage.read(key: _keyAccess);

  Future<String?> readRefreshToken() => _storage.read(key: _keyRefresh);

  Future<bool> hasTokens() async {
    final access = await readAccessToken();
    return access != null;
  }

  Future<void> clearAll() => _storage.deleteAll();
}
