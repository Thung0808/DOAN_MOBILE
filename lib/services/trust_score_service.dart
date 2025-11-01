import 'package:firebase_database/firebase_database.dart';

/// Service quản lý điểm uy tín (Trust Score) của người dùng
class TrustScoreService {
  static final dbRef = FirebaseDatabase.instance.ref();

  // Các hằng số điểm
  static const int INITIAL_SCORE = 80; // Điểm khởi tạo
  static const int MAX_SCORE = 100;
  static const int MIN_SCORE = 0;

  // Điểm thưởng/phạt
  static const int COMPLETE_DEPOSIT_POINTS = 10; // Hoàn tất đặt cọc
  static const int CANCEL_BOOKING_PENALTY = -10; // Hủy booking
  static const int LATE_CANCEL_PENALTY = -15; // Hủy gần ngày hẹn
  static const int NO_SHOW_PENALTY = -20; // Không xuất hiện
  static const int GOOD_REVIEW_POINTS = 5; // Đánh giá tốt (4-5 sao)
  static const int BAD_REVIEW_PENALTY = -5; // Đánh giá kém (1-2 sao)
  static const int REPORT_PENALTY = -25; // Bị báo cáo vi phạm

  /// Lấy điểm uy tín của user
  static Future<int> getTrustScore(String userId) async {
    try {
      final snapshot = await dbRef.child('users').child(userId).get();
      if (snapshot.exists) {
        final userData = snapshot.value as Map;
        return userData['trustScore'] ?? INITIAL_SCORE;
      }
      return INITIAL_SCORE;
    } catch (e) {
      print('❌ Error getting trust score: $e');
      return INITIAL_SCORE;
    }
  }

  /// Cập nhật điểm uy tín
  static Future<void> updateTrustScore(
    String userId,
    int points,
    String reason,
  ) async {
    try {
      final currentScore = await getTrustScore(userId);
      final newScore = (currentScore + points).clamp(MIN_SCORE, MAX_SCORE);

      await dbRef.child('users').child(userId).update({
        'trustScore': newScore,
        'lastTrustScoreUpdate': DateTime.now().millisecondsSinceEpoch,
      });

      // Ghi log lịch sử thay đổi điểm
      await _logTrustScoreChange(
        userId: userId,
        oldScore: currentScore,
        newScore: newScore,
        points: points,
        reason: reason,
      );

      print('✅ Updated trust score: $userId ($currentScore → $newScore)');
    } catch (e) {
      print('❌ Error updating trust score: $e');
    }
  }

  /// Ghi log lịch sử thay đổi điểm
  static Future<void> _logTrustScoreChange({
    required String userId,
    required int oldScore,
    required int newScore,
    required int points,
    required String reason,
  }) async {
    try {
      final logRef = dbRef
          .child('users')
          .child(userId)
          .child('trustScoreHistory')
          .push();

      await logRef.set({
        'oldScore': oldScore,
        'newScore': newScore,
        'points': points,
        'reason': reason,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });
    } catch (e) {
      print('❌ Error logging trust score change: $e');
    }
  }

  /// Thưởng điểm khi hoàn tất đặt cọc
  static Future<void> rewardCompleteDeposit(String userId) async {
    await updateTrustScore(
      userId,
      COMPLETE_DEPOSIT_POINTS,
      'Hoàn tất đặt cọc đúng hẹn',
    );
  }

  /// Phạt điểm khi hủy booking
  static Future<void> penalizeCancelBooking(
    String userId, {
    bool isLateCancel = false,
  }) async {
    final points = isLateCancel ? LATE_CANCEL_PENALTY : CANCEL_BOOKING_PENALTY;
    final reason = isLateCancel ? 'Hủy lịch hẹn gần ngày hẹn' : 'Hủy lịch hẹn';

    await updateTrustScore(userId, points, reason);
  }

  /// Phạt điểm khi không xuất hiện
  static Future<void> penalizeNoShow(String userId) async {
    await updateTrustScore(
      userId,
      NO_SHOW_PENALTY,
      'Không xuất hiện theo lịch hẹn',
    );
  }

  /// Cập nhật điểm dựa trên đánh giá
  static Future<void> updateFromReview(String userId, int rating) async {
    if (rating >= 4) {
      await updateTrustScore(
        userId,
        GOOD_REVIEW_POINTS,
        'Nhận đánh giá tốt ($rating sao)',
      );
    } else if (rating <= 2) {
      await updateTrustScore(
        userId,
        BAD_REVIEW_PENALTY,
        'Nhận đánh giá kém ($rating sao)',
      );
    }
  }

  /// Phạt điểm khi bị báo cáo
  static Future<void> penalizeReport(String userId, String reportReason) async {
    await updateTrustScore(userId, REPORT_PENALTY, 'Bị báo cáo: $reportReason');
  }

  /// Lấy label và màu dựa trên điểm
  static TrustScoreLevel getScoreLevel(int score) {
    if (score >= 90) {
      return TrustScoreLevel(
        label: 'Xuất sắc',
        description: 'Người dùng rất đáng tin cậy',
        emoji: '🌟',
        color: 0xFF4CAF50, // Green
      );
    } else if (score >= 75) {
      return TrustScoreLevel(
        label: 'Tốt',
        description: 'Người dùng đáng tin cậy',
        emoji: '✅',
        color: 0xFF8BC34A, // Light Green
      );
    } else if (score >= 60) {
      return TrustScoreLevel(
        label: 'Trung bình',
        description: 'Cần cải thiện uy tín',
        emoji: '⚠️',
        color: 0xFFFFC107, // Amber
      );
    } else if (score >= 40) {
      return TrustScoreLevel(
        label: 'Kém',
        description: 'Cần thận trọng khi giao dịch',
        emoji: '⚠️',
        color: 0xFFFF9800, // Orange
      );
    } else {
      return TrustScoreLevel(
        label: 'Rất kém',
        description: 'Không nên giao dịch',
        emoji: '❌',
        color: 0xFFF44336, // Red
      );
    }
  }

  /// Kiểm tra xem user có thể đặt booking không
  static Future<bool> canMakeBooking(String userId) async {
    final score = await getTrustScore(userId);
    return score >= 30; // Ngưỡng tối thiểu để đặt booking
  }

  /// Lấy thống kê trust score của user
  static Future<Map<String, dynamic>> getTrustScoreStats(String userId) async {
    try {
      final score = await getTrustScore(userId);
      final level = getScoreLevel(score);

      // Đếm số lần thay đổi điểm
      final historySnapshot = await dbRef
          .child('users')
          .child(userId)
          .child('trustScoreHistory')
          .get();

      int totalChanges = 0;
      int positiveChanges = 0;
      int negativeChanges = 0;

      if (historySnapshot.exists) {
        final history = historySnapshot.value as Map;
        totalChanges = history.length;

        for (var entry in history.values) {
          final data = entry as Map;
          final points = data['points'] ?? 0;
          if (points > 0) {
            positiveChanges++;
          } else if (points < 0) {
            negativeChanges++;
          }
        }
      }

      return {
        'score': score,
        'level': level.label,
        'description': level.description,
        'emoji': level.emoji,
        'color': level.color,
        'totalChanges': totalChanges,
        'positiveChanges': positiveChanges,
        'negativeChanges': negativeChanges,
        'canMakeBooking': score >= 30,
      };
    } catch (e) {
      print('❌ Error getting trust score stats: $e');
      return {
        'score': INITIAL_SCORE,
        'level': 'Tốt',
        'description': 'Người dùng đáng tin cậy',
        'emoji': '✅',
        'color': 0xFF8BC34A,
        'totalChanges': 0,
        'positiveChanges': 0,
        'negativeChanges': 0,
        'canMakeBooking': true,
      };
    }
  }
}

/// Model cho level của trust score
class TrustScoreLevel {
  final String label;
  final String description;
  final String emoji;
  final int color;

  TrustScoreLevel({
    required this.label,
    required this.description,
    required this.emoji,
    required this.color,
  });
}
