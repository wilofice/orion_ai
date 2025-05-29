import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class TokenStorage {
  static const _accessTokenKey = 'backend_access_token';
  static const _expiryKey = 'backend_token_expiry';
  static const _userIdKey = 'backend_user_id';

  final FlutterSecureStorage _storage;

  const TokenStorage({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  Future<void> saveToken({
    required String accessToken,
    required int expiresIn,
    required String userId,
  }) async {
    await _storage.write(key: _accessTokenKey, value: accessToken);
    final expiry =
        DateTime.now().add(Duration(seconds: expiresIn)).toIso8601String();
    await _storage.write(key: _expiryKey, value: expiry);
    await _storage.write(key: _userIdKey, value: userId);
  }

  Future<String?> readAccessToken() => _storage.read(key: _accessTokenKey);

  Future<DateTime?> readExpiry() async {
    final value = await _storage.read(key: _expiryKey);
    return value != null ? DateTime.tryParse(value) : null;
  }

  Future<String?> readUserId() => _storage.read(key: _userIdKey);

  Future<void> clear() async {
    await _storage.delete(key: _accessTokenKey);
    await _storage.delete(key: _expiryKey);
    await _storage.delete(key: _userIdKey);
  }
}
