class AppNotification {
  final String id;
  final String title;
  final String content;
  final int timestamp;
  final String adminId;
  final String adminName;
  final String type; // 'admin', 'review_reply', 'booking', etc.
  final String? roomId; // ID phòng liên quan
  final String? reviewId; // ID đánh giá liên quan
  final String? fromUserId; // ID người gửi thông báo
  final String? fromUserName; // Tên người gửi thông báo

  AppNotification({
    required this.id,
    required this.title,
    required this.content,
    required this.timestamp,
    required this.adminId,
    required this.adminName,
    this.type = 'admin',
    this.roomId,
    this.reviewId,
    this.fromUserId,
    this.fromUserName,
  });

  factory AppNotification.fromMap(String id, Map<dynamic, dynamic> map) {
    return AppNotification(
      id: id,
      title: map['title'] ?? '',
      content: map['content'] ?? '',
      timestamp: map['timestamp'] ?? 0,
      adminId: map['adminId'] ?? '',
      adminName: map['adminName'] ?? '',
      type: map['type'] ?? 'admin',
      roomId: map['roomId'],
      reviewId: map['reviewId'],
      fromUserId: map['fromUserId'],
      fromUserName: map['fromUserName'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'content': content,
      'timestamp': timestamp,
      'adminId': adminId,
      'adminName': adminName,
      'type': type,
      'roomId': roomId,
      'reviewId': reviewId,
      'fromUserId': fromUserId,
      'fromUserName': fromUserName,
    };
  }
}
