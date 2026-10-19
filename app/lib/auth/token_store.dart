import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Persists the JWT pair and small onboarding flags on the device.
abstract interface class TokenStore {
  Future<({String access, String refresh})?> readTokens();
  Future<void> writeTokens({required String access, required String refresh});
  Future<bool> readFlag(String name);
  Future<void> writeFlag(String name, bool value);
  Future<void> clear();
}

class SecureTokenStore implements TokenStore {
  SecureTokenStore([FlutterSecureStorage? storage])
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  @override
  Future<({String access, String refresh})?> readTokens() async {
    final access = await _storage.read(key: 'access');
    final refresh = await _storage.read(key: 'refresh');
    if (access == null || refresh == null) return null;
    return (access: access, refresh: refresh);
  }

  @override
  Future<void> writeTokens({required String access, required String refresh}) async {
    await _storage.write(key: 'access', value: access);
    await _storage.write(key: 'refresh', value: refresh);
  }

  @override
  Future<bool> readFlag(String name) async => await _storage.read(key: 'flag.$name') == '1';

  @override
  Future<void> writeFlag(String name, bool value) =>
      _storage.write(key: 'flag.$name', value: value ? '1' : '0');

  @override
  Future<void> clear() => _storage.deleteAll();
}

final tokenStoreProvider = Provider<TokenStore>((ref) => SecureTokenStore());
