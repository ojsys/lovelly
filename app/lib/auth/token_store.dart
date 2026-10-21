import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Persists the JWT pair and small settings (onboarding flags, chosen filters) on the device.
abstract interface class TokenStore {
  Future<({String access, String refresh})?> readTokens();
  Future<void> writeTokens({required String access, required String refresh});
  Future<bool> readFlag(String name);
  Future<void> writeFlag(String name, bool value);
  Future<String?> readValue(String name);
  Future<void> writeValue(String name, String value);
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
  Future<String?> readValue(String name) => _storage.read(key: 'value.$name');

  @override
  Future<void> writeValue(String name, String value) =>
      _storage.write(key: 'value.$name', value: value);

  @override
  Future<void> clear() => _storage.deleteAll();
}

final tokenStoreProvider = Provider<TokenStore>((ref) => SecureTokenStore());
