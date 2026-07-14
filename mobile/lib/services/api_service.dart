import 'dart:convert';
import 'package:dio/dio.dart';
import '../config/api_config.dart';
import 'auth_service.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;

  late final Dio _dio;

  ApiService._internal() {
    _dio = Dio(
      BaseOptions(
        baseUrl: ApiConfig.baseUrl,
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
        sendTimeout: const Duration(seconds: 30),
        headers: {
          'Accept': 'application/json',
        },
      ),
    );

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await AuthService().getToken();
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          return handler.next(options);
        },
        onError: (error, handler) {
          return handler.next(error);
        },
      ),
    );
  }

  // ── Authentication ──
  Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      final response = await _dio.post(
        ApiConfig.login,
        data: {
          'email': email,
          'password': password,
        },
        options: Options(contentType: 'application/json'),
      );
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // ── User Enrollment ──
  Future<Map<String, dynamic>> enrollUser({
    required String fullName,
    String? email,
    String? staffId,
    required List<int> imageBytes,
    required String fileName,
  }) async {
    try {
      final formData = FormData.fromMap({
        'full_name': fullName,
        if (email != null && email.isNotEmpty) 'email': email,
        if (staffId != null && staffId.isNotEmpty) 'staff_id': staffId,
        'image': MultipartFile.fromBytes(
          imageBytes,
          filename: fileName,
        ),
      });

      final response = await _dio.post(
        ApiConfig.enroll,
        data: formData,
        options: Options(contentType: 'multipart/form-data'),
      );
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // ── Face Verification ──
  Future<Map<String, dynamic>> verifyFace(List<List<int>> framesList) async {
    try {
      final formData = FormData();
      for (int i = 0; i < framesList.length; i++) {
        formData.files.add(
          MapEntry(
            'frames',
            MultipartFile.fromBytes(
              framesList[i],
              filename: 'frame_$i.jpg',
            ),
          ),
        );
      }

      final response = await _dio.post(
        ApiConfig.verify,
        data: formData,
        options: Options(contentType: 'multipart/form-data'),
      );
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // ── Users ──
  Future<List<dynamic>> getUsers({
    int page = 1,
    int limit = 20,
    String? search,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'page': page,
        'limit': limit,
      };
      if (search != null && search.isNotEmpty) {
        queryParams['search'] = search;
      }

      final response = await _dio.get(
        ApiConfig.users,
        queryParameters: queryParams,
      );

      if (response.data is List) {
        return response.data as List<dynamic>;
      } else if (response.data is Map) {
        if (response.data['items'] != null) {
          return response.data['items'] as List<dynamic>;
        } else if (response.data['users'] != null) {
          return response.data['users'] as List<dynamic>;
        }
      }
      return [];
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // ── Delete User ──
  Future<void> deleteUser(String id) async {
    try {
      await _dio.delete('${ApiConfig.users}/$id');
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // ── Access Logs ──
  Future<Map<String, dynamic>> getLogs({
    int page = 1,
    int limit = 20,
    String? result,
    String? startDate,
    String? endDate,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'page': page,
        'limit': limit,
      };
      if (result != null && result.isNotEmpty) {
        queryParams['result'] = result;
      }
      if (startDate != null) queryParams['start_date'] = startDate;
      if (endDate != null) queryParams['end_date'] = endDate;

      final response = await _dio.get(
        ApiConfig.logs,
        queryParameters: queryParams,
      );

      if (response.data is List) {
        return {'logs': response.data, 'total': (response.data as List).length};
      }
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // ── Stats ──
  Future<Map<String, dynamic>> getStats() async {
    try {
      final response = await _dio.get(ApiConfig.stats);
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // ── Error Handler ──
  String _handleError(DioException e) {
    if (e.response != null) {
      final data = e.response?.data;
      if (data is Map<String, dynamic>) {
        final detail = data['detail'];
        if (detail is List) {
          return detail.map((d) => d is Map ? (d['msg'] ?? d.toString()) : d.toString()).join('; ');
        }
        return detail?.toString() ?? data['message']?.toString() ?? 'Request failed';
      }
      if (data is String) return data;
      switch (e.response?.statusCode) {
        case 401:
          return 'Invalid credentials. Please try again.';
        case 403:
          return 'Access forbidden. Insufficient permissions.';
        case 404:
          return 'Resource not found.';
        case 422:
          return 'Invalid data provided.';
        case 500:
          return 'Server error. Please try again later.';
        default:
          return 'Request failed with status ${e.response?.statusCode}';
      }
    }

    switch (e.type) {
      case DioExceptionType.connectionTimeout:
        return 'Connection timed out. Check your network.';
      case DioExceptionType.receiveTimeout:
        return 'Server took too long to respond.';
      case DioExceptionType.sendTimeout:
        return 'Request timed out while sending data.';
      case DioExceptionType.connectionError:
        return 'Cannot connect to server. Is the backend running?';
      default:
        return 'Network error. Please check your connection.';
    }
  }
}
