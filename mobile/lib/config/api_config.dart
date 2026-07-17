import 'package:flutter/foundation.dart';

class ApiConfig {
  // Use secure locked subdomain localtunnel URL for Web, and direct local Wi-Fi for physical mobile apps
  static final String baseUrl = 'https://ai-face-recognition-2.onrender.com';

  static const String login = '/auth/login';
  static const String enroll = '/users/enroll';
  static const String users = '/users/';
  static const String verify = '/access/verify';
  static const String logs = '/access/logs';
  static const String stats = '/access/logs/stats';
}
