class AccessLog {
  final String id;
  final String? userId;
  final String? userName;
  final DateTime timestamp;
  final String result;
  final double? confidenceScore;
  final String? reason;

  AccessLog({
    required this.id,
    this.userId,
    this.userName,
    required this.timestamp,
    required this.result,
    this.confidenceScore,
    this.reason,
  });

  factory AccessLog.fromJson(Map<String, dynamic> json) {
    return AccessLog(
      id: json['id']?.toString() ?? '',
      userId: json['user_id']?.toString(),
      userName: json['user_name'] ?? json['userName'],
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'])
          : DateTime.now(),
      result: json['result'] ?? 'denied',
      confidenceScore: json['confidence_score'] != null
          ? (json['confidence_score'] as num).toDouble()
          : null,
      reason: json['reason'],
    );
  }

  bool get isGranted => result.toLowerCase() == 'granted';

  String get formattedConfidence {
    if (confidenceScore == null) return 'N/A';
    return '${(confidenceScore! * 100).toStringAsFixed(1)}%';
  }
}
