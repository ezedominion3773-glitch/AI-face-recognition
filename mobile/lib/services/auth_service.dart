import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;

  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  
  // Fallback in-memory storage for insecure web environments (e.g. testing over IP via HTTP)
  final Map<String, String> _webMemoryStorage = {};

  AuthService._internal();

  Future<void> saveToken(String token) async {
    if (kIsWeb) {
      _webMemoryStorage['auth_token'] = token;
      return;
    }
    try {
      await _storage.write(key: 'auth_token', value: token);
    } catch (e) {
      rethrow;
    }
  }

  Future<String?> getToken() async {
    if (kIsWeb) {
      return _webMemoryStorage['auth_token'];
    }
    try {
      return await _storage.read(key: 'auth_token');
    } catch (e) {
      rethrow;
    }
  }

  Future<void> deleteToken() async {
    if (kIsWeb) {
      _webMemoryStorage.remove('auth_token');
      return;
    }
    try {
      await _storage.delete(key: 'auth_token');
    } catch (e) {
      rethrow;
    }
  }

  Future<bool> isLoggedIn() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }
}

