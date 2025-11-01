import 'package:firebase_database/firebase_database.dart';

/// Service để tự động mở lại phòng nếu đặt cọc quá hạn (> 24h không xác nhận)
class DepositAutoReleaseService {
  static final dbRef = FirebaseDatabase.instance.ref();

  /// Check và tự động release các phòng đã quá hạn đặt cọc
  static Future<void> checkAndReleaseExpiredDeposits() async {
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      const timeoutDuration = 24 * 60 * 60 * 1000; // 24 giờ

      // 1. Lấy tất cả bookings với trạng thái pending và type deposit
      final bookingsSnapshot = await dbRef.child('bookings').get();

      if (!bookingsSnapshot.exists) return;

      final bookingsMap = bookingsSnapshot.value as Map;
      final expiredBookings = <String, Map<String, dynamic>>{};

      for (var entry in bookingsMap.entries) {
        final bookingId = entry.key;
        final bookingData = entry.value as Map;

        final status = bookingData['status'] ?? '';
        final bookingType = bookingData['bookingType'] ?? '';
        final createdAt = bookingData['createdAt'] ?? 0;

        // Kiểm tra nếu là booking đặt cọc, đang pending và đã quá 24h
        if (status == 'pending' &&
            bookingType == 'deposit' &&
            (now - createdAt) > timeoutDuration) {
          expiredBookings[bookingId] = {
            'roomId': bookingData['roomId'],
            'tenantId': bookingData['tenantId'],
            'tenantName': bookingData['tenantName'] ?? 'Unknown',
            'roomTitle': bookingData['roomTitle'] ?? 'Unknown Room',
          };
        }
      }

      // 2. Xử lý từng booking đã quá hạn
      for (var entry in expiredBookings.entries) {
        final bookingId = entry.key;
        final bookingInfo = entry.value;

        await _releaseExpiredDeposit(
          bookingId: bookingId,
          roomId: bookingInfo['roomId'],
          tenantId: bookingInfo['tenantId'],
          tenantName: bookingInfo['tenantName'],
          roomTitle: bookingInfo['roomTitle'],
        );
      }

      if (expiredBookings.isNotEmpty) {
        print('✅ Auto-released ${expiredBookings.length} expired deposits');
      }
    } catch (e) {
      print('❌ Error in auto-release service: $e');
    }
  }

  /// Release một booking đã quá hạn
  static Future<void> _releaseExpiredDeposit({
    required String bookingId,
    required String roomId,
    required String tenantId,
    required String tenantName,
    required String roomTitle,
  }) async {
    try {
      // 1. Cập nhật booking status thành "expired"
      await dbRef.child('bookings').child(bookingId).update({
        'status': 'expired',
        'expiredAt': DateTime.now().millisecondsSinceEpoch,
        'autoReleased': true,
        'expireReason':
            'Chủ trọ không xác nhận trong 24h, tự động hoàn tiền và mở lại phòng',
      });

      // 2. Mở lại phòng (chuyển về DangMo)
      await dbRef.child('rooms').child(roomId).update({
        'availabilityStatus': 'DangMo',
      });

      // 3. Tạo yêu cầu hoàn tiền
      await _createAutoRefundRequest(
        bookingId: bookingId,
        roomId: roomId,
        roomTitle: roomTitle,
        tenantId: tenantId,
        tenantName: tenantName,
      );

      // 4. Gửi thông báo cho người thuê
      await _notifyTenantAutoRelease(tenantId: tenantId, roomTitle: roomTitle);

      print('✅ Released expired deposit: $bookingId for room: $roomId');
    } catch (e) {
      print('❌ Error releasing deposit $bookingId: $e');
    }
  }

  /// Tạo yêu cầu hoàn tiền tự động
  static Future<void> _createAutoRefundRequest({
    required String bookingId,
    required String roomId,
    required String roomTitle,
    required String tenantId,
    required String tenantName,
  }) async {
    try {
      final refundRef = dbRef.child('refund_requests').push();

      await refundRef.set({
        'bookingId': bookingId,
        'roomId': roomId,
        'roomTitle': roomTitle,
        'tenantId': tenantId,
        'tenantName': tenantName,
        'amount': 0, // TODO: Get from payment
        'reason': 'Tự động hoàn tiền - Chủ trọ không xác nhận trong 24h',
        'status': 'auto_approved', // Tự động phê duyệt
        'type': 'auto_refund',
        'createdAt': DateTime.now().millisecondsSinceEpoch,
      });
    } catch (e) {
      print('❌ Error creating auto refund: $e');
    }
  }

  /// Gửi thông báo cho người thuê về việc tự động release
  static Future<void> _notifyTenantAutoRelease({
    required String tenantId,
    required String roomTitle,
  }) async {
    try {
      final notificationRef = dbRef
          .child('users')
          .child(tenantId)
          .child('notifications')
          .push();

      await notificationRef.set({
        'title': '⏰ Đặt cọc hết hạn',
        'content':
            'Rất tiếc! Chủ trọ không xác nhận đặt cọc của bạn cho phòng "$roomTitle" trong 24h.\n'
            'Phòng đã được mở lại và tiền đặt cọc sẽ được hoàn trả trong 3-5 ngày làm việc.',
        'type': 'deposit_expired',
        'roomTitle': roomTitle,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'adminId': 'system',
        'adminName': 'Hệ thống',
      });
    } catch (e) {
      print('❌ Error sending notification: $e');
    }
  }

  /// Check và release định kỳ (gọi từ app khi user mở app)
  static Future<void> scheduleAutoRelease() async {
    // Kiểm tra và release ngay khi được gọi
    await checkAndReleaseExpiredDeposits();

    // TODO: Có thể thêm periodic check nếu cần
    // Ví dụ: Mỗi 1 giờ check 1 lần khi app đang chạy
  }
}
