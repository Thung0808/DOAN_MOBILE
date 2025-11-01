class Message {
  final String id;
  final String conversationId;
  final String senderId;
  final String senderName;
  final String senderRole; // 'user' or 'admin'
  final String content;
  final int timestamp;
  final bool isRead;
  final bool isEdited;
  final bool deletedBySender;

  Message({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.senderName,
    required this.senderRole,
    required this.content,
    required this.timestamp,
    this.isRead = false,
    this.isEdited = false,
    this.deletedBySender = false,
  });

  factory Message.fromMap(String id, Map<dynamic, dynamic> map) {
    // Safe parse helpers
    String parseString(dynamic value, String defaultValue) {
      if (value == null) return defaultValue;
      return value.toString();
    }

    int parseTimestamp(dynamic value) {
      if (value == null) return 0;
      if (value is int) return value;
      if (value is double) return value.toInt();
      if (value is String) return int.tryParse(value) ?? 0;
      return 0;
    }

    bool parseBool(dynamic value) {
      if (value == null) return false;
      if (value is bool) return value;
      if (value is int) return value != 0;
      if (value is String) return value.toLowerCase() == 'true';
      return false;
    }

    return Message(
      id: id,
      conversationId: parseString(map['conversationId'], ''),
      senderId: parseString(map['senderId'], ''),
      senderName: parseString(map['senderName'], ''),
      senderRole: parseString(map['senderRole'], 'user'),
      content: parseString(map['content'], ''),
      timestamp: parseTimestamp(map['timestamp']),
      isRead: parseBool(map['isRead']),
      isEdited: parseBool(map['isEdited']),
      deletedBySender: parseBool(map['deletedBySender']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'conversationId': conversationId,
      'senderId': senderId,
      'senderName': senderName,
      'senderRole': senderRole,
      'content': content,
      'timestamp': timestamp,
      'isRead': isRead,
      'isEdited': isEdited,
      'deletedBySender': deletedBySender,
    };
  }

  Message copyWith({
    String? id,
    String? conversationId,
    String? senderId,
    String? senderName,
    String? senderRole,
    String? content,
    int? timestamp,
    bool? isRead,
  }) {
    return Message(
      id: id ?? this.id,
      conversationId: conversationId ?? this.conversationId,
      senderId: senderId ?? this.senderId,
      senderName: senderName ?? this.senderName,
      senderRole: senderRole ?? this.senderRole,
      content: content ?? this.content,
      timestamp: timestamp ?? this.timestamp,
      isRead: isRead ?? this.isRead,
    );
  }
}
