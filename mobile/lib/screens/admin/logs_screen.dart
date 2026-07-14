import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../providers/logs_provider.dart';

class AdminLogsScreen extends StatefulWidget {
  const AdminLogsScreen({super.key});

  @override
  State<AdminLogsScreen> createState() => _AdminLogsScreenState();
}

class _AdminLogsScreenState extends State<AdminLogsScreen> {
  final _scrollController = ScrollController();
  String? _selectedResult; // null (All), 'granted', 'denied'

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchLogs(refresh: true);
    });
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      _fetchLogs();
    }
  }

  Future<void> _fetchLogs({bool refresh = false}) async {
    final provider = Provider.of<LogsProvider>(context, listen: false);
    await provider.fetchLogs(refresh: refresh, result: _selectedResult);
  }

  void _onFilterChanged(String? result) {
    setState(() {
      _selectedResult = result;
    });
    _fetchLogs(refresh: true);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final logsProvider = Provider.of<LogsProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Access Logs"),
      ),
      body: Column(
        children: [
          // Filter Chips
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
            child: Row(
              children: [
                _buildFilterChip(label: "All", result: null),
                const SizedBox(width: 8),
                _buildFilterChip(label: "Granted", result: "granted"),
                const SizedBox(width: 8),
                _buildFilterChip(label: "Denied", result: "denied"),
              ],
            ),
          ),

          // Logs List
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => _fetchLogs(refresh: true),
              child: logsProvider.logs.isEmpty && !logsProvider.isLoading
                  ? const Center(
                      child: Text("No access logs found.", style: TextStyle(color: Colors.white30)),
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: logsProvider.logs.length + (logsProvider.isLoading ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == logsProvider.logs.length) {
                          return const Center(
                            child: Padding(
                              padding: EdgeInsets.all(16.0),
                              child: CircularProgressIndicator(),
                            ),
                          );
                        }

                        final log = logsProvider.logs[index];
                        final isGranted = log.result == 'granted';
                        final formattedTime = DateFormat('yyyy-MM-dd HH:mm:ss').format(log.timestamp.toLocal());
                        final confidencePercent = log.confidenceScore != null
                            ? "${(log.confidenceScore! * 100).toStringAsFixed(1)}%"
                            : "N/A";

                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: Icon(
                              isGranted ? Icons.check_circle : Icons.cancel,
                              color: isGranted ? Color(0xFF10B981) : Colors.redAccent,
                              size: 28,
                            ),
                            title: Text(
                              log.userName ?? 'Unknown Person',
                              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 2),
                                Text(
                                  "Reason: ${log.reason} (${isGranted ? 'Match' : 'No Match'})",
                                  style: const TextStyle(fontSize: 12, color: Colors.white70),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  formattedTime,
                                  style: const TextStyle(fontSize: 11, color: Colors.white38),
                                ),
                              ],
                            ),
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                const Text(
                                  "Confidence",
                                  style: TextStyle(fontSize: 10, color: Colors.white38),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  confidencePercent,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: isGranted ? Color(0xFF10B981) : Colors.redAccent,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({required String label, required String? result}) {
    final theme = Theme.of(context);
    final isSelected = _selectedResult == result;

    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          _onFilterChanged(result);
        }
      },
      selectedColor: theme.colorScheme.primary,
      backgroundColor: theme.colorScheme.surface,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : Colors.white60,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }
}
