// SecureStorage service wrapping flutter_secure_storage.
// Stores creator profile locally (MVP auth) and JWT tokens for future use.
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const _keyAccess = 'access_token';
const _keyRefresh = 'refresh_token';
const _keyCreatorId = 'creator_id';
const _keyCreatorName = 'creator_name';
const _keyCreatorEmail = 'creator_email';
const _keyCreatorNiches = 'creator_niches'; // JSON-encoded List<String>
const _keyTikTokConnected = 'tiktok_connected';

final secureStorageProvider = Provider<SecureStorageService>(
  (_) => SecureStorageService(),
);

class SecureStorageService {
  SecureStorageService()
      : _storage = const FlutterSecureStorage(
          aOptions: AndroidOptions(encryptedSharedPreferences: true),
        );

  final FlutterSecureStorage _storage;

  // --- JWT (kept for future Supabase migration) ---
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

  // --- Creator profile (MVP local auth) ---
  Future<void> writeCreatorId(String id) async {
    await _storage.write(key: _keyCreatorId, value: id);
    // Also write to access_token slot so the router guard works unchanged
    await _storage.write(key: _keyAccess, value: id);
  }

  Future<String?> readCreatorId() => _storage.read(key: _keyCreatorId);

  Future<bool> hasCreatorId() async {
    final id = await readCreatorId();
    return id != null;
  }

  Future<void> writeCreatorProfile({
    required String id,
    required String name,
    required String email,
  }) async {
    await writeCreatorId(id);
    await _storage.write(key: _keyCreatorName, value: name);
    await _storage.write(key: _keyCreatorEmail, value: email);
  }

  Future<Map<String, String?>> readCreatorProfile() async {
    return {
      'id': await _storage.read(key: _keyCreatorId),
      'name': await _storage.read(key: _keyCreatorName),
      'email': await _storage.read(key: _keyCreatorEmail),
    };
  }

  Future<void> writeCreatorNiches(List<String> niches) =>
      _storage.write(key: _keyCreatorNiches, value: jsonEncode(niches));

  Future<List<String>> readCreatorNiches() async {
    final raw = await _storage.read(key: _keyCreatorNiches);
    if (raw == null) return [];
    return List<String>.from(jsonDecode(raw) as List);
  }

  Future<void> setTikTokConnected(bool value) =>
      _storage.write(key: _keyTikTokConnected, value: value.toString());

  Future<bool> isTikTokConnected() async {
    final v = await _storage.read(key: _keyTikTokConnected);
    return v == 'true';
  }

  Future<void> clearAll() => _storage.deleteAll();
}
