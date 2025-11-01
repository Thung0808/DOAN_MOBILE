class RoomReview {
  final String id;
  final String roomId;
  final String roomTitle;
  final String reviewerId;
  final String reviewerName;
  final String reviewerEmail;
  final int rating; // 1-5 sao
  final String comment;
  final int timestamp;
  final String? bookingId; // ID của lịch hẹn đã xem (nếu có)
  final bool isVerified; // Đánh giá đã được xác minh
  final String? reply; // Trả lời từ chủ phòng
  final int? replyTimestamp; // Thời gian trả lời
  final String? replyUserId; // ID người trả lời (chủ phòng)

  RoomReview({
    required this.id,
    required this.roomId,
    required this.roomTitle,
    required this.reviewerId,
    required this.reviewerName,
    required this.reviewerEmail,
    required this.rating,
    required this.comment,
    required this.timestamp,
    this.bookingId,
    this.isVerified = false,
    this.reply,
    this.replyTimestamp,
    this.replyUserId,
  });

  factory RoomReview.fromMap(String id, Map<String, dynamic> map) {
    return RoomReview(
      id: id,
      roomId: map['roomId'] ?? '',
      roomTitle: map['roomTitle'] ?? '',
      reviewerId: map['reviewerId'] ?? '',
      reviewerName: map['reviewerName'] ?? '',
      reviewerEmail: map['reviewerEmail'] ?? '',
      rating: map['rating'] ?? 0,
      comment: map['comment'] ?? '',
      timestamp: map['timestamp'] ?? 0,
      bookingId: map['bookingId'],
      isVerified: map['isVerified'] ?? false,
      reply: map['reply'],
      replyTimestamp: map['replyTimestamp'],
      replyUserId: map['replyUserId'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'roomId': roomId,
      'roomTitle': roomTitle,
      'reviewerId': reviewerId,
      'reviewerName': reviewerName,
      'reviewerEmail': reviewerEmail,
      'rating': rating,
      'comment': comment,
      'timestamp': timestamp,
      'bookingId': bookingId,
      'isVerified': isVerified,
      'reply': reply,
      'replyTimestamp': replyTimestamp,
      'replyUserId': replyUserId,
    };
  }

  // Helper methods
  String get ratingText {
    switch (rating) {
      case 1:
        return 'Rất tệ';
      case 2:
        return 'Tệ';
      case 3:
        return 'Bình thường';
      case 4:
        return 'Tốt';
      case 5:
        return 'Rất tốt';
      default:
        return 'Chưa đánh giá';
    }
  }

  String get ratingEmoji {
    switch (rating) {
      case 1:
        return '😞';
      case 2:
        return '😕';
      case 3:
        return '😐';
      case 4:
        return '😊';
      case 5:
        return '😍';
      default:
        return '⭐';
    }
  }

  bool get hasValidRating => rating >= 1 && rating <= 5;
  bool get hasComment => comment.trim().isNotEmpty;
  bool get hasReply => reply != null && reply!.trim().isNotEmpty;
}
