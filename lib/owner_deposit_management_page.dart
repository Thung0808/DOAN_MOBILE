import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';
import 'models/booking_model.dart';

class OwnerDepositManagementPage extends StatefulWidget {
  const OwnerDepositManagementPage({super.key});

  @override
  State<OwnerDepositManagementPage> createState() =>
      _OwnerDepositManagementPageState();
}

class _OwnerDepositManagementPageState
    extends State<OwnerDepositManagementPage> {
  final user = FirebaseAuth.instance.currentUser!;
  final dbRef = FirebaseDatabase.instance.ref();
  List<RoomBooking> _depositBookings = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDepositBookings();
  }

  Future<void> _loadDepositBookings() async {
    setState(() => _isLoading = true);

    try {
      final snapshot = await dbRef
          .child('bookings')
          .orderByChild('ownerId')
          .equalTo(user.uid)
          .get();

      if (!snapshot.exists) {
        setState(() {
          _depositBookings = [];
          _isLoading = false;
        });
        return;
      }

      final bookingsMap = snapshot.value as Map;
      final deposits = <RoomBooking>[];

      for (var entry in bookingsMap.entries) {
        final bookingData = entry.value as Map;
        final booking = RoomBooking.fromMap(entry.key, bookingData);

        // Chỉ lấy booking có đặt cọc (bookingType = 'deposit')
        if (booking.bookingType == 'deposit' && booking.status == 'pending') {
          deposits.add(booking);
        }
      }

      // Sắp xếp theo thời gian tạo (mới nhất trước)
      deposits.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      if (mounted) {
        setState(() {
          _depositBookings = deposits;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('❌ Lỗi load deposit bookings: $e');
      if (mounted) {
        setState(() {
          _depositBookings = [];
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _confirmDeposit(RoomBooking booking) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xác nhận cho thuê'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Bạn xác nhận cho thuê phòng "${booking.roomTitle}" cho:'),
            const SizedBox(height: 8),
            Text(
              '👤 ${booking.tenantName}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            Text('📞 ${booking.tenantPhone}'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                '⚠️ Sau khi xác nhận, phòng sẽ chuyển sang trạng thái "Đã thuê" và không hiển thị trên hệ thống nữa.',
                style: TextStyle(fontSize: 12),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Xác nhận cho thuê'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _processConfirmation(booking);
    }
  }

  Future<void> _processConfirmation(RoomBooking booking) async {
    try {
      // 🔒 ATOMIC: Dùng transaction để đảm bảo chỉ confirm khi phòng đang DaDatCoc
      final transactionResult = await dbRef
          .child('rooms')
          .child(booking.roomId)
          .child('availabilityStatus')
          .runTransaction((currentValue) {
            final currentStatus = currentValue as String? ?? 'DangMo';

            // Chỉ cho phép confirm nếu phòng đang ở trạng thái DaDatCoc
            if (currentStatus == 'DaDatCoc') {
              return Transaction.success('DaThue');
            } else {
              // Phòng không ở trạng thái đặt cọc - không thể confirm
              return Transaction.abort();
            }
          });

      if (!transactionResult.committed) {
        // Transaction failed - phòng không ở trạng thái đặt cọc
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                '❌ Không thể xác nhận! Phòng không ở trạng thái đặt cọc.',
              ),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 4),
            ),
          );
        }
        return;
      }

      // 1. Transaction thành công - cập nhật booking status
      await dbRef.child('bookings').child(booking.id).update({
        'status': 'confirmed',
        'confirmedAt': DateTime.now().millisecondsSinceEpoch,
      });

      // 2. Cập nhật thông tin người thuê
      await dbRef.child('rooms').child(booking.roomId).update({
        'rentedBy': booking.tenantId,
        'rentedAt': DateTime.now().millisecondsSinceEpoch,
      });

      // 3. Gửi thông báo cho người thuê
      await _notifyTenantConfirmed(booking);

      // 4. Hủy các booking khác của phòng này
      await _cancelOtherBookings(booking.roomId, booking.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 12),
                Expanded(child: Text('✅ Đã xác nhận cho thuê thành công!')),
              ],
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );

        _loadDepositBookings(); // Refresh list
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Lỗi: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _rejectDeposit(RoomBooking booking) async {
    final TextEditingController reasonController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Từ chối đặt cọc'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Bạn muốn từ chối đặt cọc của "${booking.tenantName}"?'),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Lý do từ chối',
                hintText: 'Nhập lý do...',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                '⚠️ Tiền đặt cọc sẽ được hoàn trả cho người thuê và phòng sẽ mở lại.',
                style: TextStyle(fontSize: 12),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Từ chối'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _processRejection(booking, reasonController.text.trim());
    }
  }

  Future<void> _processRejection(RoomBooking booking, String reason) async {
    try {
      // 1. Cập nhật booking status
      await dbRef.child('bookings').child(booking.id).update({
        'status': 'rejected',
        'rejectedAt': DateTime.now().millisecondsSinceEpoch,
        'rejectionReason': reason.isEmpty ? 'Không phù hợp' : reason,
      });

      // 🔒 ATOMIC: Dùng transaction để mở lại phòng an toàn
      // Chỉ mở lại nếu phòng vẫn đang DaDatCoc (chưa ai confirm)
      await dbRef
          .child('rooms')
          .child(booking.roomId)
          .child('availabilityStatus')
          .runTransaction((currentValue) {
            final currentStatus = currentValue as String? ?? 'DangMo';

            // Chỉ set về DangMo nếu phòng đang DaDatCoc
            if (currentStatus == 'DaDatCoc') {
              return Transaction.success('DangMo');
            } else {
              // Phòng đã ở trạng thái khác (DaThue, DaDatLich) - không đổi
              return Transaction.success(currentStatus);
            }
          });

      // 3. Tạo yêu cầu hoàn tiền
      await _createRefundRequest(booking, reason);

      // 4. Gửi thông báo cho người thuê
      await _notifyTenantRejected(booking, reason);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 12),
                Expanded(child: Text('✅ Đã từ chối và tạo yêu cầu hoàn tiền!')),
              ],
            ),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 3),
          ),
        );

        _loadDepositBookings(); // Refresh list
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Lỗi: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // Helper: Gửi thông báo cho người thuê khi xác nhận
  Future<void> _notifyTenantConfirmed(RoomBooking booking) async {
    try {
      final notificationRef = dbRef
          .child('users')
          .child(booking.tenantId)
          .child('notifications')
          .push();

      await notificationRef.set({
        'title': '🎉 Chúc mừng! Đặt cọc được xác nhận',
        'content':
            'Chủ trọ đã xác nhận cho bạn thuê phòng "${booking.roomTitle}". Vui lòng liên hệ chủ trọ để hoàn tất thủ tục và nhận phòng.',
        'type': 'deposit_confirmed',
        'bookingId': booking.id,
        'roomId': booking.roomId,
        'roomTitle': booking.roomTitle,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'adminId': 'system',
        'adminName': 'Hệ thống',
      });
    } catch (e) {
      print('❌ Lỗi gửi thông báo: $e');
    }
  }

  // Helper: Gửi thông báo cho người thuê khi từ chối
  Future<void> _notifyTenantRejected(RoomBooking booking, String reason) async {
    try {
      final notificationRef = dbRef
          .child('users')
          .child(booking.tenantId)
          .child('notifications')
          .push();

      await notificationRef.set({
        'title': '⚠️ Đặt cọc bị từ chối',
        'content':
            'Rất tiếc! Chủ trọ đã từ chối đặt cọc của bạn cho phòng "${booking.roomTitle}".\n'
            'Lý do: $reason\n'
            'Tiền đặt cọc sẽ được hoàn trả trong 3-5 ngày làm việc.',
        'type': 'deposit_rejected',
        'bookingId': booking.id,
        'roomId': booking.roomId,
        'roomTitle': booking.roomTitle,
        'rejectionReason': reason,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'adminId': 'system',
        'adminName': 'Hệ thống',
      });
    } catch (e) {
      print('❌ Lỗi gửi thông báo: $e');
    }
  }

  // Helper: Tạo yêu cầu hoàn tiền
  Future<void> _createRefundRequest(RoomBooking booking, String reason) async {
    try {
      final refundRef = dbRef.child('refund_requests').push();

      await refundRef.set({
        'bookingId': booking.id,
        'roomId': booking.roomId,
        'roomTitle': booking.roomTitle,
        'tenantId': booking.tenantId,
        'tenantName': booking.tenantName,
        'ownerId': booking.ownerId,
        'ownerName': booking.ownerName,
        'amount': (booking.roomTitle.contains('₫')
            ? 0
            : 1000000), // TODO: Get from booking
        'reason': reason,
        'status': 'pending', // pending, approved, completed
        'createdAt': DateTime.now().millisecondsSinceEpoch,
      });
    } catch (e) {
      print('❌ Lỗi tạo refund request: $e');
    }
  }

  // Helper: Hủy các booking khác của cùng phòng
  Future<void> _cancelOtherBookings(String roomId, String confirmedId) async {
    try {
      final snapshot = await dbRef
          .child('bookings')
          .orderByChild('roomId')
          .equalTo(roomId)
          .get();

      if (!snapshot.exists) return;

      final bookingsMap = snapshot.value as Map;

      for (var entry in bookingsMap.entries) {
        final bookingId = entry.key;
        final bookingData = entry.value as Map;

        // Bỏ qua booking đã confirm
        if (bookingId == confirmedId) continue;

        final status = bookingData['status'] ?? '';
        if (status == 'pending') {
          // Hủy booking
          await dbRef.child('bookings').child(bookingId).update({
            'status': 'cancelled',
            'cancelledAt': DateTime.now().millisecondsSinceEpoch,
            'cancelReason': 'Phòng đã được cho thuê',
          });

          // Gửi thông báo
          final tenantId = bookingData['tenantId'];
          if (tenantId != null) {
            await _notifyBookingCancelled(
              tenantId,
              bookingData['roomTitle'] ?? '',
            );
          }
        }
      }
    } catch (e) {
      print('❌ Lỗi hủy bookings khác: $e');
    }
  }

  Future<void> _notifyBookingCancelled(
    String tenantId,
    String roomTitle,
  ) async {
    try {
      final notificationRef = dbRef
          .child('users')
          .child(tenantId)
          .child('notifications')
          .push();

      await notificationRef.set({
        'title': '❌ Lịch xem phòng bị hủy',
        'content':
            'Rất tiếc! Phòng "$roomTitle" đã được cho thuê. Lịch xem phòng của bạn đã bị hủy.',
        'type': 'booking_cancelled',
        'roomTitle': roomTitle,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'adminId': 'system',
        'adminName': 'Hệ thống',
      });
    } catch (e) {
      print('❌ Lỗi gửi thông báo hủy: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quản lý Đặt cọc'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _depositBookings.isEmpty
          ? _buildEmptyState()
          : RefreshIndicator(
              onRefresh: _loadDepositBookings,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _depositBookings.length,
                itemBuilder: (context, index) {
                  final booking = _depositBookings[index];
                  return _buildDepositCard(booking);
                },
              ),
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.event_busy, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'Chưa có đặt cọc nào',
            style: TextStyle(fontSize: 18, color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          Text(
            'Khi có người đặt cọc phòng, sẽ hiển thị ở đây',
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildDepositCard(RoomBooking booking) {
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');

    // Calculate time since deposit
    final now = DateTime.now().millisecondsSinceEpoch;
    final depositTime = booking.createdAt;
    final hoursSinceDeposit = (now - depositTime) / (1000 * 60 * 60);
    final shouldAutoRelease = hoursSinceDeposit > 24;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.deepPurple.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.account_balance_wallet,
                    color: Colors.deepPurple,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        booking.roomTitle,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        booking.roomAddress,
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 24),

            // Tenant info
            Row(
              children: [
                Icon(Icons.person, size: 18, color: Colors.grey[600]),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        booking.tenantName,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        booking.tenantPhone,
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Deposit time
            Row(
              children: [
                Icon(Icons.access_time, size: 18, color: Colors.grey[600]),
                const SizedBox(width: 8),
                Text(
                  'Đặt cọc lúc: ${dateFormat.format(DateTime.fromMillisecondsSinceEpoch(depositTime))}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                ),
              ],
            ),

            // Auto-release warning
            if (shouldAutoRelease)
              Container(
                margin: const EdgeInsets.only(top: 12),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning, color: Colors.red, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '⚠️ Đã quá 24h! Vui lòng xác nhận hoặc từ chối ngay.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.red[700],
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 16),

            // Action buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _rejectDeposit(booking),
                    icon: const Icon(Icons.close, size: 18),
                    label: const Text('Từ chối'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _confirmDeposit(booking),
                    icon: const Icon(Icons.check, size: 18),
                    label: const Text('Xác nhận'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
