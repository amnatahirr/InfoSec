import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../services/secure_storage_service.dart';

class AuthProvider extends ChangeNotifier {
  final SharedPreferences prefs;
  final ApiService _apiService = ApiService();

  String? _token;
  String? _userId;
  bool _isLoading = false;
  String? _error;

  AuthProvider(this.prefs) {
    _loadToken();
  }

  String? get token => _token;
  String? get userId => _userId;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isAuthenticated => _token != null;

  void _loadToken() {
    _token = prefs.getString('auth_token');
    _userId = prefs.getString('user_id');
    notifyListeners();
  }

  Future<bool> register(String username, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _apiService.post('/auth/register', {
        'username': username,
        'password': password,
      });

      _token = response['token'];
      _userId = response['userId'].toString();

      await prefs.setString('auth_token', _token!);
      await prefs.setString('user_id', _userId!);

      await SecureStorageService.storeSessionToken(_token!);
      await SecureStorageService.storeUserId(_userId!);

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> login(String username, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _apiService.post('/auth/login', {
        'username': username,
        'password': password,
      });

      _token = response['token'];
      _userId = response['userId'].toString();

      await prefs.setString('auth_token', _token!);
      await prefs.setString('user_id', _userId!);

      await SecureStorageService.storeSessionToken(_token!);
      await SecureStorageService.storeUserId(_userId!);

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    _token = null;
    _userId = null;
    await prefs.remove('auth_token');
    await prefs.remove('user_id');

    await SecureStorageService.clearAll();

    notifyListeners();
  }
}
