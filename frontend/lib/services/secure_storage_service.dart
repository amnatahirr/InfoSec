import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorageService {
  static const _storage = FlutterSecureStorage();

  // Keys for secure storage
  static const String _encryptionPasswordKey = 'encryption_password';
  static const String _sessionTokenKey = 'session_token';
  static const String _userIdKey = 'user_id';

  // Store encryption password securely
  static Future<void> storeEncryptionPassword(String password) async {
    await _storage.write(
      key: _encryptionPasswordKey,
      value: password,
    );
  }

  // Retrieve encryption password
  static Future<String?> getEncryptionPassword() async {
    return await _storage.read(key: _encryptionPasswordKey);
  }

  // Clear encryption password
  static Future<void> clearEncryptionPassword() async {
    await _storage.delete(key: _encryptionPasswordKey);
  }

  // Store session token
  static Future<void> storeSessionToken(String token) async {
    await _storage.write(
      key: _sessionTokenKey,
      value: token,
    );
  }

  // Retrieve session token
  static Future<String?> getSessionToken() async {
    return await _storage.read(key: _sessionTokenKey);
  }

  // Store user ID
  static Future<void> storeUserId(String userId) async {
    await _storage.write(
      key: _userIdKey,
      value: userId,
    );
  }

  // Retrieve user ID
  static Future<String?> getUserId() async {
    return await _storage.read(key: _userIdKey);
  }

  // Clear all secure data (logout)
  static Future<void> clearAll() async {
    await _storage.deleteAll();
  }

  // Check if password is stored
  static Future<bool> hasEncryptionPassword() async {
    final password = await _storage.read(key: _encryptionPasswordKey);
    return password != null && password.isNotEmpty;
  }
}
