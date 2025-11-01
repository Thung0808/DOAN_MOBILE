class Report {
  final String id;
  final String roomId;
  final String roomTitle;
  final String reporterId;
  final String reporterName;
  final String reporterEmail;
  final String reason;
  final String description;
  final int timestamp;
  final String status; // 'pending', 'resolved', 'dismissed'
  final String? adminNote;
  final String? resolvedBy;
  final int? resolvedAt;

  Report({
    required this.id,
    required this.roomId,
    required this.roomTitle,
    required this.reporterId,
    required this.reporterName,
    required this.reporterEmail,
    required this.reason,
    required this.description,
    required this.timestamp,
    this.status = 'pending',
    this.adminNote,
    this.resolvedBy,
    this.resolvedAt,
  });

  factory Report.fromMap(String id, Map<dynamic, dynamic> map) {
    // Safe parse for timestamp
    int parseTimestamp(dynamic value) {
      if (value == null) return 0;
      if (value is int) return value;
      if (value is double) return value.toInt();
      if (value is String) return int.tryParse(value) ?? 0;
      return 0;
    }

    // Safe parse for nullable timestamp
    int? parseNullableTimestamp(dynamic value) {
      if (value == null) return null;
      if (value is int) return value;
      if (value is double) return value.toInt();
      if (value is String) return int.tryParse(value);
      return null;
    }

    // Safe parse for string
    String parseString(dynamic value, String defaultValue) {
      if (value == null) return defaultValue;
      return value.toString();
    }

    // Safe parse for nullable string
    String? parseNullableString(dynamic value) {
      if (value == null) return null;
      if (value.toString().isEmpty) return null;
      return value.toString();
    }

    return Report(
      id: id,
      roomId: parseString(map['roomId'], ''),
      roomTitle: parseString(map['roomTitle'], ''),
      reporterId: parseString(map['reporterId'], ''),
      reporterName: parseString(map['reporterName'], ''),
      reporterEmail: parseString(map['reporterEmail'], ''),
      reason: parseString(map['reason'], ''),
      description: parseString(map['description'], ''),
      timestamp: parseTimestamp(map['timestamp']),
      status: parseString(map['status'], 'pending'),
      adminNote: parseNullableString(map['adminNote']),
      resolvedBy: parseNullableString(map['resolvedBy']),
      resolvedAt: parseNullableTimestamp(map['resolvedAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'roomId': roomId,
      'roomTitle': roomTitle,
      'reporterId': reporterId,
      'reporterName': reporterName,
      'reporterEmail': reporterEmail,
      'reason': reason,
      'description': description,
      'timestamp': timestamp,
      'status': status,
      'adminNote': adminNote,
      'resolvedBy': resolvedBy,
      'resolvedAt': resolvedAt,
    };
  }
}
