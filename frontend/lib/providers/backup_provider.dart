import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/secure_storage_service.dart';

class BackupProvider extends ChangeNotifier {
  final ApiService _apiService = ApiService();

  List<dynamic> _configs = [];
  List<dynamic> _backupHistory = [];
  bool _isLoading = false;
  String? _error;
  Map<String, dynamic>? _passwordStrength;

  List<dynamic> get configs => _configs;
  List<dynamic> get backupHistory => _backupHistory;
  bool get isLoading => _isLoading;
  String? get error => _error;
  Map<String, dynamic>? get passwordStrength => _passwordStrength;

  Future<void> storeEncryptionPassword(String password) async {
    await SecureStorageService.storeEncryptionPassword(password);
  }

  Future<String?> getEncryptionPassword() async {
    return await SecureStorageService.getEncryptionPassword();
  }

  Future<bool> hasEncryptionPassword() async {
    return await SecureStorageService.hasEncryptionPassword();
  }

  Future<bool> validatePassword(String password, String token) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _apiService.post(
        '/backup/validate-password',
        {'password': password},
        token: token,
      );

      _passwordStrength = {
        'isValid': response['isValid'] ?? false,
        'score': response['score'] ?? 0,
        'feedback': response['feedback'] ?? [],
      };

      _isLoading = false;
      notifyListeners();
      return response['isValid'] ?? false;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> createBackupConfig({
    required String name,
    required List<String> sourcePaths,
    required String backupFolder,
    required String scheduleType,
    required String scheduleTime,
    required int retentionDays,
    required String token,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _apiService.post(
        '/backup/config',
        {
          'name': name,
          'sourcePaths': sourcePaths,
          'backupFolder': backupFolder,
          'scheduleType': scheduleType,
          'scheduleTime': scheduleTime,
          'retentionDays': retentionDays,
        },
        token: token,
      );

      _isLoading = false;
      notifyListeners();
      return response['success'] ?? false;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> fetchBackupConfigs(String token) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _apiService.get('/backup/configs', token: token);
      _configs = response['configs'] ?? [];
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>?> getBackupStats(String configId, String token) async {
    try {
      final response = await _apiService.get('/backup/stats/$configId', token: token);
      return response['stats'];
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return null;
    }
  }

  Future<bool> performBackup(String configId, String password, String token) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _apiService.post(
        '/backup/perform/$configId',
        {'password': password},
        token: token,
      );

      if (response['success'] == false) {
        _error = response['message'] ?? response['error'] ?? 'Backup failed';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      _isLoading = false;
      notifyListeners();
      return response['success'] ?? false;
    } catch (e) {
      _error = 'Backup Error: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> fetchBackupHistory(String configId, String token) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _apiService.get('/backup/history/$configId', token: token);
      _backupHistory = response['history'] ?? [];
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> restoreBackup(String backupId, String password, String restorePath, String token) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _apiService.post(
        '/backup/restore/$backupId',
        {
          'password': password,
          'restorePath': restorePath,
        },
        token: token,
      );

      _isLoading = false;
      notifyListeners();
      return response['success'] ?? false;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteBackupConfig(String configId, String token) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _apiService.delete(
        '/backup/config/$configId',
        token: token,
      );

      _isLoading = false;
      notifyListeners();
      return response['success'] ?? false;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<Map<String, dynamic>?> decryptFilePreview(String encryptedFilePath, String password, String token) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _apiService.post(
        '/decrypt/preview',
        {
          'encryptedFilePath': encryptedFilePath,
          'password': password,
        },
        token: token,
      );

      _isLoading = false;
      notifyListeners();
      return response;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }

  Future<bool> decryptFile(String encryptedFilePath, String password, String outputPath, String token) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _apiService.post(
        '/decrypt/file',
        {
          'encryptedFilePath': encryptedFilePath,
          'password': password,
          'outputPath': outputPath,
        },
        token: token,
      );

      _isLoading = false;
      notifyListeners();
      return response['success'] ?? false;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<List<dynamic>?> listEncryptedFiles(String directoryPath, String token) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _apiService.post(
        '/decrypt/list',
        {'directoryPath': directoryPath},
        token: token,
      );

      _isLoading = false;
      notifyListeners();
      return response['files'];
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }
}
