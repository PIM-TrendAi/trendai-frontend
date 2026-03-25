import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/storage/secure_storage.dart';
import '../../data/creator_model.dart';

final authProvider =
    StateNotifierProvider<AuthNotifier, AsyncValue<CreatorModel?>>(
  (ref) => AuthNotifier(ref.read(secureStorageProvider)),
);

class AuthNotifier extends StateNotifier<AsyncValue<CreatorModel?>> {
  AuthNotifier(this._storage) : super(const AsyncValue.loading()) {
    _init();
  }

  final SecureStorageService _storage;

  Future<void> _init() async {
    final profile = await _storage.readCreatorProfile();
    if (profile['id'] != null) {
      final niches = await _storage.readCreatorNiches();
      final tiktok = await _storage.isTikTokConnected();
      state = AsyncValue.data(CreatorModel(
        creatorId: profile['id']!,
        name: profile['name'] ?? '',
        email: profile['email'] ?? '',
        niches: niches,
        tiktokConnected: tiktok,
      ));
    } else {
      state = const AsyncValue.data(null);
    }
  }

  Future<void> signUp({
    required String name,
    required String email,
  }) async {
    state = const AsyncValue.loading();
    try {
      final creatorId = const Uuid().v4();
      await _storage.writeCreatorProfile(id: creatorId, name: name, email: email);
      state = AsyncValue.data(CreatorModel(
        creatorId: creatorId,
        name: name,
        email: email,
      ));
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> login({required String email}) async {
    state = const AsyncValue.loading();
    try {
      final profile = await _storage.readCreatorProfile();
      if (profile['id'] == null || profile['email'] != email) {
        throw Exception('No account found for $email. Please sign up first.');
      }
      final niches = await _storage.readCreatorNiches();
      final tiktok = await _storage.isTikTokConnected();
      state = AsyncValue.data(CreatorModel(
        creatorId: profile['id']!,
        name: profile['name'] ?? '',
        email: profile['email'] ?? '',
        niches: niches,
        tiktokConnected: tiktok,
      ));
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> saveNiches(List<String> niches) async {
    await _storage.writeCreatorNiches(niches);
    final current = state.valueOrNull;
    if (current != null) {
      state = AsyncValue.data(current.copyWith(niches: niches));
    }
  }

  Future<void> setTikTokConnected() async {
    await _storage.setTikTokConnected(true);
    final current = state.valueOrNull;
    if (current != null) {
      state = AsyncValue.data(current.copyWith(tiktokConnected: true));
    }
  }

  Future<void> signOut() async {
    await _storage.clearAll();
    state = const AsyncValue.data(null);
  }
}
