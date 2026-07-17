import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/routes.dart';
import '../../providers/auth_provider.dart';
import '../../providers/logs_provider.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshStats();
    });
  }

  Future<void> _refreshStats() async {
    final logsProvider = Provider.of<LogsProvider>(context, listen: false);
    await logsProvider.fetchStats();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authProvider = Provider.of<AuthProvider>(context);
    final logsProvider = Provider.of<LogsProvider>(context);

    // Stats values from provider
    final stats = logsProvider.stats;
    final totalUsers = stats['total_users'] ?? 0;
    final todayAttempts = stats['today_attempts'] ?? 0;
    final grantedCount = stats['granted_count'] ?? 0;
    final deniedCount = stats['denied_count'] ?? 0;

    double grantedPercent = 0.0;
    if (todayAttempts > 0) {
      grantedPercent = (grantedCount / todayAttempts) * 100;
    }

    final recentAttempts = stats['recent_attempts'] as List<dynamic>? ?? [];

    return Scaffold(
      appBar: AppBar(
        title: const Text("Admin Dashboard"),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await authProvider.logout();
              if (context.mounted) {
                Navigator.pushReplacementNamed(context, AppRoutes.scan);
              }
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshStats,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Welcome Text
              Text(
                "Welcome, ${authProvider.currentUser?.fullName ?? 'Administrator'}",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: theme.textTheme.headlineMedium?.color,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                "Biometric terminal management console",
                style: TextStyle(
                  fontSize: 13,
                  color: theme.textTheme.bodyMedium?.color?.withOpacity(0.6),
                ),
              ),
              const SizedBox(height: 24),

              // Grid of 4 Stats Cards
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: 1.4,
                children: [
                  _buildStatCard(
                    context: context,
                    title: "Total Users",
                    value: totalUsers.toString(),
                    icon: Icons.people_outline,
                    color: Colors.blueAccent,
                  ),
                  _buildStatCard(
                    context: context,
                    title: "Today's Scans",
                    value: todayAttempts.toString(),
                    icon: Icons.qr_code_scanner,
                    color: Colors.amberAccent,
                  ),
                  _buildStatCard(
                    context: context,
                    title: "Granted Count",
                    value: grantedCount.toString(),
                    icon: Icons.check_circle_outline,
                    color: Color(0xFF10B981),
                  ),
                  _buildStatCard(
                    context: context,
                    title: "Denied Count",
                    value: deniedCount.toString(),
                    icon: Icons.cancel_outlined,
                    color: Colors.redAccent,
                  ),
                ],
              ),
              const SizedBox(height: 28),

              // Quick Actions
              Text(
                "Quick Management Actions",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: theme.textTheme.titleMedium?.color,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildActionButton(
                      context: context,
                      label: "Enroll User",
                      icon: Icons.add_a_photo_outlined,
                      route: AppRoutes.adminEnroll,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildActionButton(
                      context: context,
                      label: "View Users",
                      icon: Icons.people,
                      route: AppRoutes.adminUserList,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildActionButton(
                      context: context,
                      label: "Audit Logs",
                      icon: Icons.assignment_outlined,
                      route: AppRoutes.adminLogs,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),

              // Recent Activity Feed
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Recent Access Activity",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: theme.textTheme.titleMedium?.color,
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pushNamed(context, AppRoutes.adminLogs),
                    child: const Text("View All Logs"),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              if (logsProvider.isLoading && recentAttempts.isEmpty)
                const Center(child: Padding(padding: EdgeInsets.all(16.0), child: CircularProgressIndicator()))
              else if (recentAttempts.isEmpty)
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: theme.dividerTheme.color ?? const Color(0xFFE2E8F0)),
                  ),
                  child: Center(
                    child: Text("No access attempts recorded yet.", style: TextStyle(color: theme.hintColor)),
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: recentAttempts.length > 5 ? 5 : recentAttempts.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final log = recentAttempts[index];
                    final isGranted = log['result'] == 'granted';
                    final timeStr = log['timestamp'] != null
                        ? _formatTime(log['timestamp'])
                        : '';
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: theme.dividerTheme.color ?? const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isGranted ? Icons.check_circle : Icons.cancel,
                            color: isGranted ? Color(0xFF10B981) : Colors.redAccent,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  log['user_name'] ?? 'Unknown Person',
                                  style: TextStyle(fontWeight: FontWeight.w600, color: theme.textTheme.bodyLarge?.color),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  log['reason'] ?? '',
                                  style: TextStyle(fontSize: 12, color: theme.textTheme.bodySmall?.color?.withOpacity(0.6)),
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                timeStr,
                                style: TextStyle(fontSize: 11, color: theme.textTheme.bodySmall?.color?.withOpacity(0.6)),
                              ),
                              if (log['confidence_score'] != null) ...[
                                const SizedBox(height: 2),
                                Text(
                                  "${((log['confidence_score'] as double) * 100).toStringAsFixed(1)}% match",
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isGranted ? Color(0xFF10B981) : Colors.redAccent,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required BuildContext context,
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerTheme.color ?? const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: color, size: 24),
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(shape: BoxShape.circle, color: color),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: theme.textTheme.displayMedium?.color,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                title,
                style: TextStyle(
                  fontSize: 11,
                  color: theme.textTheme.bodyMedium?.color?.withOpacity(0.6),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required BuildContext context,
    required String label,
    required IconData icon,
    required String route,
  }) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, route).then((_) => _refreshStats()),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: theme.dividerTheme.color ?? const Color(0xFFE2E8F0)),
        ),
        child: Column(
          children: [
            Icon(icon, color: theme.colorScheme.secondary, size: 28),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: theme.textTheme.bodyLarge?.color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(String timestampStr) {
    try {
      final dt = DateTime.parse(timestampStr).toLocal();
      final now = DateTime.now();
      final diff = now.difference(dt);

      if (diff.inMinutes < 1) {
        return "just now";
      } else if (diff.inHours < 1) {
        return "${diff.inMinutes}m ago";
      } else if (diff.inDays < 1) {
        return "${diff.inHours}h ago";
      } else {
        return "${dt.day}/${dt.month}";
      }
    } catch (_) {
      return '';
    }
  }
}
