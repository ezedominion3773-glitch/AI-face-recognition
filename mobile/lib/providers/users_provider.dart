import 'package:flutter/material.dart';
import '../models/user.dart';
import '../services/api_service.dart';

class UsersProvider extends ChangeNotifier {
  final ApiService _apiService = ApiService();

  List<User> _users = [];
  List<User> get users => _users;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  int _currentPage = 1;
  int get currentPage => _currentPage;

  bool _hasMore = true;
  bool get hasMore => _hasMore;

  Future<void> fetchUsers({bool refresh = false, String? search}) async {
    if (_isLoading) return;

    if (refresh) {
      _currentPage = 1;
      _users = [];
      _hasMore = true;
    }

    if (!_hasMore) return;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final responseList = await _apiService.getUsers(
        page: _currentPage,
        limit: 20,
        search: search,
      );

      final newUsers = responseList.map((json) => User.fromJson(json)).toList();

      if (newUsers.length < 20) {
        _hasMore = false;
      }

      _users.addAll(newUsers);
      _currentPage++;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> enrollUser({
    required String fullName,
    String? email,
    String? staffId,
    required List<int> imageBytes,
    required String fileName,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _apiService.enrollUser(
        fullName: fullName,
        email: email,
        staffId: staffId,
        imageBytes: imageBytes,
        fileName: fileName,
      );
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteUser(String id) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _apiService.deleteUser(id);
      _users.removeWhere((user) => user.id == id);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }
}
