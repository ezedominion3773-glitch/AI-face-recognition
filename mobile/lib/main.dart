import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'config/app_theme.dart';
import 'config/routes.dart';
import 'providers/auth_provider.dart';
import 'providers/users_provider.dart';
import 'providers/logs_provider.dart';
import 'screens/splash_screen.dart';
import 'screens/user/scan_screen.dart';
import 'screens/user/result_screen.dart';
import 'screens/admin/login_screen.dart';
import 'screens/admin/dashboard_screen.dart';
import 'screens/admin/enroll_screen.dart';
import 'screens/admin/user_list_screen.dart';
import 'screens/admin/logs_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const FaceAccessApp());
}

class FaceAccessApp extends StatelessWidget {
  const FaceAccessApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => UsersProvider()),
        ChangeNotifierProvider(create: (_) => LogsProvider()),
      ],
      child: MaterialApp(
        title: 'FaceGuard Access Control',
        theme: AppTheme.darkTheme,
        debugShowCheckedModeBanner: false,
        initialRoute: AppRoutes.splash,
        routes: {
          AppRoutes.splash: (context) => const SplashScreen(),
          AppRoutes.scan: (context) => const ScanScreen(),
          AppRoutes.result: (context) => const ResultScreen(),
          AppRoutes.adminLogin: (context) => const AdminLoginScreen(),
          AppRoutes.adminDashboard: (context) => const AdminDashboardScreen(),
          AppRoutes.adminEnroll: (context) => const AdminEnrollScreen(),
          AppRoutes.adminUserList: (context) => const AdminUserListScreen(),
          AppRoutes.adminLogs: (context) => const AdminLogsScreen(),
        },
      ),
    );
  }
}
