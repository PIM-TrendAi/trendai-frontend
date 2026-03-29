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
          iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
        );

  final FlutterSecureStorage _storage;

  Future<void> writeAccessToken(String token) async {
    try {
      await _storage.write(key: _keyAccess, value: token);
    } catch (e) {
      // Ignored for simulator
    }
  }

  Future<void> writeRefreshToken(String token) async {
    try {
      await _storage.write(key: _keyRefresh, value: token);
    } catch (e) {
      // Ignored for simulator
    }
  }

  Future<String?> readAccessToken() async {
    try {
      return await _storage.read(key: _keyAccess);
    } catch (e) {
      return null;
    }
  }

  Future<String?> readRefreshToken() async {
    try {
      return await _storage.read(key: _keyRefresh);
    } catch (e) {
      return null;
    }
  }

  Future<bool> hasTokens() async {
    final access = await readAccessToken();
    return access != null;
  }

  Future<void> clearAll() => _storage.deleteAll();
}
