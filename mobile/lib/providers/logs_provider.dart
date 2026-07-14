import 'package:flutter/material.dart';
import '../models/access_log.dart';
import '../services/api_service.dart';

class LogsProvider extends ChangeNotifier {
  final ApiService _apiService = ApiService();

  List<AccessLog> _logs = [];
  List<AccessLog> get logs => _logs;

  Map<String, dynamic> _stats = {};
  Map<String, dynamic> get stats => _stats;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  int _currentPage = 1;
  int get currentPage => _currentPage;

  bool _hasMore = true;
  bool get hasMore => _hasMore;

  Future<void> fetchLogs({
    bool refresh = false,
    String? result,
    String? startDate,
    String? endDate,
  }) async {
    if (_isLoading) return;

    if (refresh) {
      _currentPage = 1;
      _logs = [];
      _hasMore = true;
    }

    if (!_hasMore) return;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final data = await _apiService.getLogs(
        page: _currentPage,
        limit: 20,
        result: result,
        startDate: startDate,
        endDate: endDate,
      );

      final List<dynamic> logsJson = data['items'] ?? data['logs'] ?? [];
      final newLogs = logsJson.map((json) => AccessLog.fromJson(json)).toList();

      if (newLogs.length < 20) {
        _hasMore = false;
      }

      _logs.addAll(newLogs);
      _currentPage++;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchStats() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final statsData = await _apiService.getStats();
      _stats = statsData;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }
}
