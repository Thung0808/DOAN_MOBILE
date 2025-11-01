class Conversation {
  final String id;
  final String userId;
  final String userName;
  final String userEmail;
  final String lastMessage;
  final int lastMessageTime;
  final String lastSenderId;
  final int unreadCount; // Số tin nhắn chưa đọc bởi admin
  final int userUnreadCount; // Số tin nhắn chưa đọc bởi user
  final int createdAt;

  Conversation({
    required this.id,
    required this.userId,
    required this.userName,
    required this.userEmail,
    required this.lastMessage,
    required this.lastMessageTime,
    required this.lastSenderId,
    this.unreadCount = 0,
    this.userUnreadCount = 0,
    required this.createdAt,
  });

  factory Conversation.fromMap(String id, Map<dynamic, dynamic> map) {
    // Safe parse helpers
    String parseString(dynamic value, String defaultValue) {
      if (value == null) return defaultValue;
      return value.toString();
    }

    int parseInt(dynamic value) {
      if (value == null) return 0;
      if (value is int) return value;
      if (value is double) return value.toInt();
      if (value is String) return int.tryParse(value) ?? 0;
      return 0;
    }

    return Conversation(
      id: id,
      userId: parseString(map['userId'], ''),
      userName: parseString(map['userName'], ''),
      userEmail: parseString(map['userEmail'], ''),
      lastMessage: parseString(map['lastMessage'], ''),
      lastMessageTime: parseInt(map['lastMessageTime']),
      lastSenderId: parseString(map['lastSenderId'], ''),
      unreadCount: parseInt(map['unreadCount']),
      userUnreadCount: parseInt(map['userUnreadCount']),
      createdAt: parseInt(map['createdAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'userName': userName,
      'userEmail': userEmail,
      'lastMessage': lastMessage,
      'lastMessageTime': lastMessageTime,
      'lastSenderId': lastSenderId,
      'unreadCount': unreadCount,
      'userUnreadCount': userUnreadCount,
      'createdAt': createdAt,
    };
  }

  Conversation copyWith({
    String? id,
    String? userId,
    String? userName,
    String? userEmail,
    String? lastMessage,
    int? lastMessageTime,
    String? lastSenderId,
    int? unreadCount,
    int? userUnreadCount,
    int? createdAt,
  }) {
    return Conversation(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      userEmail: userEmail ?? this.userEmail,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageTime: lastMessageTime ?? this.lastMessageTime,
      lastSenderId: lastSenderId ?? this.lastSenderId,
      unreadCount: unreadCount ?? this.unreadCount,
      userUnreadCount: userUnreadCount ?? this.userUnreadCount,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
