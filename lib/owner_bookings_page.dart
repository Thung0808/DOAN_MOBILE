import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';

class OwnerBookingsPage extends StatefulWidget {
  const OwnerBookingsPage({super.key});

  @override
  State<OwnerBookingsPage> createState() => _OwnerBookingsPageState();
}

class _OwnerBookingsPageState extends State<OwnerBookingsPage> {
  final user = FirebaseAuth.instance.currentUser!;
  final dbRef = FirebaseDatabase.instance.ref();

  Future<void> _confirmBooking(String bookingId) async {
    try {
      // Lấy thông tin booking trước
      final bookingSnapshot = await dbRef
          .child('bookings')
          .child(bookingId)
          .get();

      if (!bookingSnapshot.exists) {
        throw Exception('Không tìm thấy thông tin lịch hẹn');
      }

      final bookingData = bookingSnapshot.value as Map;
      final tenantId = bookingData['tenantId'] as String;

      // Cập nhật trạng thái booking
      await dbRef.child('bookings').child(bookingId).update({
        'status': 'confirmed',
        'confirmedAt': DateTime.now().millisecondsSinceEpoch,
      });

      // Cập nhật trong user bookings
      await dbRef
          .child('users')
          .child(tenantId)
          .child('bookings')
          .child(bookingId)
          .update({'status': 'confirmed'});

      // Cập nhật trong owner bookings
      await dbRef
          .child('users')
          .child(user.uid)
          .child('ownerBookings')
          .child(bookingId)
          .update({'status': 'confirmed'});

      // Tạo thông báo riêng cho người đặt lịch
      final tenantNotificationRef = dbRef
          .child('users')
          .child(tenantId)
          .child('notifications')
          .push();
      await tenantNotificationRef.set({
        'title': '✅ Lịch hẹn đã được xác nhận',
        'content':
            'Chủ trọ đã xác nhận lịch hẹn xem phòng của bạn. Vui lòng liên hệ chủ trọ để xác nhận thời gian cụ thể.',
        'type': 'booking_confirmed',
        'bookingId': bookingId,
        'tenantId': tenantId,
        'ownerId': user.uid,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'adminId': 'system',
        'adminName': 'Hệ thống',
      });

      // Tạo thông báo riêng cho chủ trọ
      final ownerNotificationRef = dbRef
          .child('users')
          .child(user.uid)
          .child('notifications')
          .push();
      await ownerNotificationRef.set({
        'title': '✅ Đã xác nhận lịch hẹn',
        'content':
            'Bạn đã xác nhận lịch hẹn xem phòng. Vui lòng liên hệ với người đặt lịch để sắp xếp thời gian.',
        'type': 'booking_confirmed_owner',
        'bookingId': bookingId,
        'tenantId': tenantId,
        'ownerId': user.uid,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'adminId': 'system',
        'adminName': 'Hệ thống',
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã xác nhận lịch hẹn thành công'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi xác nhận lịch hẹn: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _completeBooking(String bookingId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xác nhận hoàn thành'),
        content: const Text(
          'Bạn có chắc chắn rằng người xem phòng đã hoàn thành việc xem phòng? '
          'Sau khi hoàn thành, người xem phòng sẽ có thể đánh giá phòng này.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
            child: const Text('Hoàn thành'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        // Lấy thông tin booking trước
        final bookingSnapshot = await dbRef
            .child('bookings')
            .child(bookingId)
            .get();

        if (!bookingSnapshot.exists) {
          throw Exception('Không tìm thấy thông tin lịch hẹn');
        }

        final bookingData = bookingSnapshot.value as Map;
        final tenantId = bookingData['tenantId'] as String;

        // Cập nhật trạng thái booking
        await dbRef.child('bookings').child(bookingId).update({
          'status': 'completed',
          'completedAt': DateTime.now().millisecondsSinceEpoch,
        });

        // Cập nhật trong user bookings
        await dbRef
            .child('users')
            .child(tenantId)
            .child('bookings')
            .child(bookingId)
            .update({'status': 'completed'});

        // Cập nhật trong owner bookings
        await dbRef
            .child('users')
            .child(user.uid)
            .child('ownerBookings')
            .child(bookingId)
            .update({'status': 'completed'});

        // Tạo thông báo cho người đặt lịch
        final tenantNotificationRef = dbRef
            .child('users')
            .child(tenantId)
            .child('notifications')
            .push();
        await tenantNotificationRef.set({
          'title': '✅ Lịch hẹn đã hoàn thành',
          'content':
              'Lịch hẹn xem phòng đã được hoàn thành. Bạn có thể đánh giá phòng này.',
          'type': 'booking_completed',
          'bookingId': bookingId,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
          'isRead': false,
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Đã hoàn thành lịch hẹn! Người xem phòng có thể đánh giá.',
                    ),
                  ),
                ],
              ),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 3),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Lỗi hoàn thành lịch hẹn: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _rejectBooking(String bookingId) async {
    String? rejectionReason;
    final reasonController = TextEditingController();

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Từ chối lịch hẹn'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Vui lòng nhập lý do từ chối:'),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Nhập lý do từ chối...',
                border: OutlineInputBorder(),
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
            onPressed: () {
              rejectionReason = reasonController.text.trim();
              Navigator.pop(context, true);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Từ chối'),
          ),
        ],
      ),
    );

    if (confirm == true &&
        rejectionReason != null &&
        rejectionReason!.isNotEmpty) {
      try {
        // Lấy thông tin booking trước
        final bookingSnapshot = await dbRef
            .child('bookings')
            .child(bookingId)
            .get();

        if (!bookingSnapshot.exists) {
          throw Exception('Không tìm thấy thông tin lịch hẹn');
        }

        final bookingData = bookingSnapshot.value as Map;
        final tenantId = bookingData['tenantId'] as String;

        // Cập nhật trạng thái booking
        await dbRef.child('bookings').child(bookingId).update({
          'status': 'rejected',
          'rejectedAt': DateTime.now().millisecondsSinceEpoch,
          'rejectionReason': rejectionReason,
        });

        // Cập nhật trong user bookings
        await dbRef
            .child('users')
            .child(tenantId)
            .child('bookings')
            .child(bookingId)
            .update({'status': 'rejected'});

        // Cập nhật trong owner bookings
        await dbRef
            .child('users')
            .child(user.uid)
            .child('ownerBookings')
            .child(bookingId)
            .update({'status': 'rejected'});

        // Tạo thông báo riêng cho người đặt lịch
        final tenantNotificationRef = dbRef
            .child('users')
            .child(tenantId)
            .child('notifications')
            .push();
        await tenantNotificationRef.set({
          'title': '❌ Lịch hẹn bị từ chối',
          'content':
              'Chủ trọ đã từ chối lịch hẹn xem phòng của bạn. Lý do: $rejectionReason',
          'type': 'booking_rejected',
          'bookingId': bookingId,
          'tenantId': tenantId,
          'ownerId': user.uid,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
          'adminId': 'system',
          'adminName': 'Hệ thống',
        });

        // Tạo thông báo riêng cho chủ trọ
        final ownerNotificationRef = dbRef
            .child('users')
            .child(user.uid)
            .child('notifications')
            .push();
        await ownerNotificationRef.set({
          'title': '❌ Đã từ chối lịch hẹn',
          'content':
              'Bạn đã từ chối lịch hẹn xem phòng. Lý do: $rejectionReason',
          'type': 'booking_rejected_owner',
          'bookingId': bookingId,
          'tenantId': tenantId,
          'ownerId': user.uid,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
          'adminId': 'system',
          'adminName': 'Hệ thống',
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Đã từ chối lịch hẹn'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Lỗi từ chối lịch hẹn: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _deleteBooking(String bookingId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xóa lịch hẹn'),
        content: const Text(
          'Bạn có chắc chắn muốn xóa lịch hẹn này? Hành động này không thể hoàn tác!',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        // Lấy thông tin booking trước
        final bookingSnapshot = await dbRef
            .child('bookings')
            .child(bookingId)
            .get();

        if (!bookingSnapshot.exists) {
          throw Exception('Không tìm thấy thông tin lịch hẹn');
        }

        final bookingData = bookingSnapshot.value as Map;
        final tenantId = bookingData['tenantId'] as String;

        // Xóa booking khỏi tất cả các node
        await dbRef.child('bookings').child(bookingId).remove();
        await dbRef
            .child('users')
            .child(tenantId)
            .child('bookings')
            .child(bookingId)
            .remove();
        await dbRef
            .child('users')
            .child(user.uid)
            .child('ownerBookings')
            .child(bookingId)
            .remove();

        // Tạo thông báo cho người đặt lịch
        final tenantNotificationRef = dbRef
            .child('users')
            .child(tenantId)
            .child('notifications')
            .push();
        await tenantNotificationRef.set({
          'title': '🗑️ Lịch hẹn đã bị xóa',
          'content': 'Chủ trọ đã xóa lịch hẹn xem phòng của bạn.',
          'type': 'booking_deleted',
          'bookingId': bookingId,
          'tenantId': tenantId,
          'ownerId': user.uid,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
          'adminId': 'system',
          'adminName': 'Hệ thống',
        });

        // Tạo thông báo cho chủ trọ
        final ownerNotificationRef = dbRef
            .child('users')
            .child(user.uid)
            .child('notifications')
            .push();
        await ownerNotificationRef.set({
          'title': '🗑️ Đã xóa lịch hẹn',
          'content': 'Bạn đã xóa lịch hẹn xem phòng.',
          'type': 'booking_deleted_owner',
          'bookingId': bookingId,
          'tenantId': tenantId,
          'ownerId': user.uid,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
          'adminId': 'system',
          'adminName': 'Hệ thống',
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Đã xóa lịch hẹn thành công'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Lỗi xóa lịch hẹn: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _deleteAllCompletedBookings() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xóa tất cả lịch hẹn đã hoàn thành/hủy'),
        content: const Text(
          'Bạn có chắc chắn muốn xóa tất cả lịch hẹn đã hoàn thành hoặc hủy? Hành động này không thể hoàn tác!',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Xóa tất cả'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      // Hiển thị loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Text('Đang xóa lịch hẹn...'),
            ],
          ),
        ),
      );
      try {
        // Lấy tất cả lịch hẹn của chủ trọ
        final ownerBookingsSnapshot = await dbRef
            .child('users')
            .child(user.uid)
            .child('ownerBookings')
            .get();

        if (!ownerBookingsSnapshot.exists) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Không có lịch hẹn nào để xóa'),
                backgroundColor: Colors.orange,
              ),
            );
          }
          return;
        }

        final ownerBookings = ownerBookingsSnapshot.value as Map;
        int deletedCount = 0;

        // Lọc và xóa các lịch hẹn đã hoàn thành hoặc hủy
        for (final bookingId in ownerBookings.keys) {
          try {
            final bookingData = ownerBookings[bookingId] as Map?;
            if (bookingData == null) continue;

            final status = bookingData['status'] as String?;
            final tenantId = bookingData['tenantId'] as String?;

            if (status == null) continue;

            if (status == 'completed' ||
                status == 'cancelled' ||
                status == 'rejected') {
              // Xóa khỏi tất cả các node
              await dbRef.child('bookings').child(bookingId).remove();

              // Chỉ xóa khỏi user bookings nếu có tenantId
              if (tenantId != null) {
                await dbRef
                    .child('users')
                    .child(tenantId)
                    .child('bookings')
                    .child(bookingId)
                    .remove();
              }

              // Xóa khỏi owner bookings
              await dbRef
                  .child('users')
                  .child(user.uid)
                  .child('ownerBookings')
                  .child(bookingId)
                  .remove();

              deletedCount++;
            }
          } catch (e) {
            continue;
          }
        }

        // Không tạo thông báo cho xóa lịch hẹn

        if (mounted) {
          Navigator.pop(context); // Đóng loading dialog
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Đã xóa $deletedCount lịch hẹn đã hoàn thành/hủy'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          Navigator.pop(context); // Đóng loading dialog
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Lỗi xóa hàng loạt: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  String _formatDateTime(int timestamp) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    return DateFormat('dd/MM/yyyy HH:mm').format(date);
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'confirmed':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      case 'completed':
        return Colors.blue;
      case 'cancelled':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'pending':
        return 'Chờ xác nhận';
      case 'confirmed':
        return 'Đã xác nhận';
      case 'rejected':
        return 'Đã từ chối';
      case 'completed':
        return 'Hoàn thành';
      case 'cancelled':
        return 'Đã hủy';
      default:
        return 'Không xác định';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quản lý lịch hẹn'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: _deleteAllCompletedBookings,
            icon: const Icon(Icons.delete_sweep),
            tooltip: 'Xóa tất cả lịch hẹn đã hoàn thành/hủy',
          ),
        ],
      ),
      body: StreamBuilder(
        stream: dbRef
            .child('users')
            .child(user.uid)
            .child('ownerBookings')
            .onValue,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('Lỗi: ${snapshot.error}'),
                ],
              ),
            );
          }

          final data = (snapshot.data?.snapshot.value ?? {}) as Map?;
          if (data == null || data.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.event_busy, size: 80, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'Chưa có lịch hẹn nào',
                    style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Các yêu cầu xem phòng sẽ hiển thị ở đây',
                    style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                  ),
                ],
              ),
            );
          }

          // Parse và sắp xếp bookings (mới nhất lên đầu)
          final bookings =
              data.entries
                  .map(
                    (entry) => MapEntry(
                      entry.key,
                      Map<String, dynamic>.from(entry.value as Map),
                    ),
                  )
                  .toList()
                ..sort(
                  (a, b) => (b.value['createdAt'] ?? 0).compareTo(
                    a.value['createdAt'] ?? 0,
                  ),
                );

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: bookings.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final bookingData = bookings[index].value;
              final bookingId = bookings[index].key;
              final status = bookingData['status'] ?? 'pending';
              final roomTitle = bookingData['roomTitle'] ?? '';
              final bookingDateTime = bookingData['bookingDateTime'] ?? 0;
              final tenantName = bookingData['tenantName'] ?? '';
              final tenantPhone = bookingData['tenantPhone'] ?? '';
              final createdAt = bookingData['createdAt'] ?? 0;

              return Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header với status
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              roomTitle,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: _getStatusColor(status).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: _getStatusColor(status),
                                width: 1,
                              ),
                            ),
                            child: Text(
                              _getStatusText(status),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: _getStatusColor(status),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Thông tin người đặt lịch
                      Row(
                        children: [
                          Icon(Icons.person, size: 16, color: Colors.grey[600]),
                          const SizedBox(width: 8),
                          Text(
                            'Người đặt: $tenantName',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[700],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),

                      if (tenantPhone.isNotEmpty) ...[
                        Row(
                          children: [
                            Icon(
                              Icons.phone,
                              size: 16,
                              color: Colors.grey[600],
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'SĐT: $tenantPhone',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[700],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                      ],

                      // Thông tin lịch hẹn
                      Row(
                        children: [
                          Icon(Icons.event, size: 16, color: Colors.grey[600]),
                          const SizedBox(width: 8),
                          Text(
                            'Xem phòng: ${_formatDateTime(bookingDateTime)}',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[700],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),

                      Row(
                        children: [
                          Icon(
                            Icons.access_time,
                            size: 16,
                            color: Colors.grey[600],
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Đặt lịch: ${_formatDateTime(createdAt)}',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[700],
                            ),
                          ),
                        ],
                      ),

                      // Actions
                      if (status == 'pending') ...[
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => _rejectBooking(bookingId),
                                icon: const Icon(Icons.cancel, size: 16),
                                label: const Text('Từ chối'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.red,
                                  side: const BorderSide(color: Colors.red),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () => _confirmBooking(bookingId),
                                icon: const Icon(Icons.check, size: 16),
                                label: const Text('Xác nhận'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            OutlinedButton.icon(
                              onPressed: () => _deleteBooking(bookingId),
                              icon: const Icon(Icons.delete, size: 16),
                              label: const Text('Xóa'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.red,
                                side: const BorderSide(color: Colors.red),
                              ),
                            ),
                          ],
                        ),
                      ] else if (status == 'confirmed') ...[
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.green[50],
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.green[200]!),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.info,
                                      color: Colors.green[700],
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Lịch hẹn đã được xác nhận. Hãy liên hệ với người xem phòng.',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.green[700],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () => _completeBooking(bookingId),
                                icon: const Icon(Icons.check_circle, size: 16),
                                label: const Text('Hoàn thành'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue,
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            OutlinedButton.icon(
                              onPressed: () => _deleteBooking(bookingId),
                              icon: const Icon(Icons.delete, size: 16),
                              label: const Text('Xóa'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.red,
                                side: const BorderSide(color: Colors.red),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
