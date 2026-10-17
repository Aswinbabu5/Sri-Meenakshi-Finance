import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../models/backup_model.dart';
import 'loan_repository.dart';

import 'database_helper.dart';

class BackupApiService {
  static final BackupApiService _instance = BackupApiService._internal();
  factory BackupApiService() => _instance;

  late final Dio _dio;
  String _baseUrl = 'https://sri-meenakshi-finance.onrender.com';

  BackupApiService._internal() {
    _initDio();
    loadSavedBaseUrl();
  }

  BackupApiService.custom({Dio? dio, String? baseUrl}) {
    _dio = dio ?? Dio();
    if (baseUrl != null) _baseUrl = baseUrl;
  }

  void _initDio() {
    // Detect environment default baseUrl
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      _baseUrl = 'http://10.0.2.2:5000';
    } else {
      _baseUrl = 'https://sri-meenakshi-finance.onrender.com';
    }

    _dio = Dio(
      BaseOptions(
        baseUrl: _baseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 30),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );
  }

  Future<void> loadSavedBaseUrl() async {
    try {
      final saved = await DatabaseHelper.instance.getSetting('backend_base_url');
      if (saved != null && saved.trim().isNotEmpty) {
        updateBaseUrl(saved.trim());
      }
    } catch (e) {
      debugPrint('Error loading saved base URL: $e');
    }
  }

  Future<void> saveBaseUrl(String newUrl) async {
    updateBaseUrl(newUrl);
    try {
      await DatabaseHelper.instance.setSetting('backend_base_url', newUrl);
    } catch (e) {
      debugPrint('Error saving base URL: $e');
    }
  }

  void updateBaseUrl(String newUrl) {
    _baseUrl = newUrl;
    _dio.options.baseUrl = newUrl;
  }

  String get baseUrl => _baseUrl;

  Options _getAuthOptions(LoanRepository repo) {
    return Options(
      headers: {
        'X-User-Role': 'admin',
      },
    );
  }

  Future<BackupOverviewModel> getOverview(LoanRepository repo) async {
    try {
      final response = await _dio.get(
        '/api/backup/overview',
        options: _getAuthOptions(repo),
      );
      return BackupOverviewModel.fromJson(response.data);
    } catch (e) {
      debugPrint('Error fetching backup overview: $e');
      rethrow;
    }
  }

  Future<List<BackupModel>> getHistory(LoanRepository repo, {int limit = 50, String? status}) async {
    try {
      final response = await _dio.get(
        '/api/backup/history',
        queryParameters: {
          'limit': limit,
          'status': ?status,
        },
        options: _getAuthOptions(repo),
      );
      final List data = response.data;
      return data.map((json) => BackupModel.fromJson(json)).toList();
    } catch (e) {
      debugPrint('Error fetching backup history: $e');
      rethrow;
    }
  }

  Future<BackupModel> getBackupDetails(LoanRepository repo, String backupId) async {
    try {
      final response = await _dio.get(
        '/api/backup/$backupId/details',
        options: _getAuthOptions(repo),
      );
      return BackupModel.fromJson(response.data);
    } catch (e) {
      debugPrint('Error fetching backup details: $e');
      rethrow;
    }
  }

  Future<BackupModel> createBackup(LoanRepository repo, {String? notes}) async {
    try {
      final response = await _dio.post(
        '/api/backup/create',
        data: {
          'triggerType': 'Manual',
          'initiatedBy': repo.currentUser?.name ?? 'Admin',
          'notes': notes,
        },
        options: _getAuthOptions(repo),
      );
      final backupJson = response.data['backup'];
      return BackupModel.fromJson(backupJson);
    } catch (e) {
      debugPrint('Error creating backup: $e');
      rethrow;
    }
  }

  Future<bool> validateBackup(LoanRepository repo, String backupId) async {
    try {
      final response = await _dio.post(
        '/api/backup/$backupId/validate',
        options: _getAuthOptions(repo),
      );
      return response.data['isValid'] == true;
    } catch (e) {
      debugPrint('Error validating backup: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> restoreBackup(
    LoanRepository repo,
    String backupId, {
    required bool confirm,
    String? adminPassword,
  }) async {
    try {
      final response = await _dio.post(
        '/api/backup/$backupId/restore',
        data: {
          'confirm': confirm,
          'adminPassword': adminPassword ?? 'admin123',
          'restoredBy': repo.currentUser?.name ?? 'Admin',
        },
        options: _getAuthOptions(repo),
      );
      return Map<String, dynamic>.from(response.data);
    } catch (e) {
      debugPrint('Error restoring backup: $e');
      rethrow;
    }
  }

  Future<List<RestoreHistoryModel>> getRestoreHistory(LoanRepository repo) async {
    try {
      final response = await _dio.get(
        '/api/backup/restore-history',
        options: _getAuthOptions(repo),
      );
      final List data = response.data;
      return data.map((json) => RestoreHistoryModel.fromJson(json)).toList();
    } catch (e) {
      debugPrint('Error fetching restore history: $e');
      rethrow;
    }
  }
}
