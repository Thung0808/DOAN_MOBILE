import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';
import 'pages/post_rental_review_page.dart';

class MyBookingsPage extends StatefulWidget {
  const MyBookingsPage({super.key});

  @override
  State<MyBookingsPage> createState() => _MyBookingsPageState();
}

class _MyBookingsPageState extends State<MyBookingsPage> {
  final user = FirebaseAuth.instance.currentUser!;
  final dbRef = FirebaseDatabase.instance.ref();

  Future<void> _cancelBooking(String bookingId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xác nhận hủy lịch hẹn'),
        content: const Text('Bạn có chắc muốn hủy lịch hẹn này?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Không'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Có, hủy lịch hẹn'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        // Cập nhật trạng thái booking
        await dbRef.child('bookings').child(bookingId).update({
          'status': 'cancelled',
          'cancelledAt': DateTime.now().millisecondsSinceEpoch,
        });

        // Cập nhật trong user bookings
        await dbRef
            .child('users')
            .child(user.uid)
            .child('bookings')
            .child(bookingId)
            .update({'status': 'cancelled'});

        // Cập nhật trong owner bookings
        final bookingSnapshot = await dbRef
            .child('bookings')
            .child(bookingId)
            .get();
        if (bookingSnapshot.exists) {
          final bookingData = bookingSnapshot.value as Map;
          final ownerId = bookingData['ownerId'] as String;

          await dbRef
              .child('users')
              .child(ownerId)
              .child('ownerBookings')
              .child(bookingId)
              .update({'status': 'cancelled'});
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Đã hủy lịch hẹn thành công'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Lỗi hủy lịch hẹn: ${e.toString()}'),
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
        // Lấy tất cả lịch hẹn của người dùng
        final userBookingsSnapshot = await dbRef
            .child('users')
            .child(user.uid)
            .child('bookings')
            .get();

        if (!userBookingsSnapshot.exists) {
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

        final userBookings = userBookingsSnapshot.value as Map;
        int deletedCount = 0;

        // Lọc và xóa các lịch hẹn đã hoàn thành hoặc hủy
        for (final bookingId in userBookings.keys) {
          try {
            final bookingData = userBookings[bookingId] as Map?;
            if (bookingData == null) continue;

            final status = bookingData['status'] as String?;
            final ownerId = bookingData['ownerId'] as String?;

            if (status == null) continue;

            if (status == 'completed' ||
                status == 'cancelled' ||
                status == 'rejected') {
              // Xóa khỏi tất cả các node
              await dbRef.child('bookings').child(bookingId).remove();

              // Xóa khỏi user bookings
              await dbRef
                  .child('users')
                  .child(user.uid)
                  .child('bookings')
                  .child(bookingId)
                  .remove();

              // Chỉ xóa khỏi owner bookings nếu có ownerId
              if (ownerId != null) {
                await dbRef
                    .child('users')
                    .child(ownerId)
                    .child('ownerBookings')
                    .child(bookingId)
                    .remove();
              }

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
        title: const Text('Lịch hẹn của tôi'),
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
        stream: dbRef.child('users').child(user.uid).child('bookings').onValue,
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
                    'Hãy đặt lịch xem phòng để bắt đầu!',
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
              final createdAt = bookingData['createdAt'] ?? 0;
              final hasReviewed = bookingData['hasReviewed'] ?? false;
              final roomId = bookingData['roomId'] ?? '';
              final ownerId = bookingData['ownerId'] ?? '';
              final ownerName = bookingData['ownerName'] ?? '';

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
                              color: _getStatusColor(
                                status,
                              ).withValues(alpha: 0.1),
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
                      const SizedBox(height: 8),

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
                      if (status == 'pending' || status == 'confirmed') ...[
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            if (status == 'pending')
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () => _cancelBooking(bookingId),
                                  icon: const Icon(Icons.cancel, size: 16),
                                  label: const Text('Hủy lịch hẹn'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.red,
                                    side: const BorderSide(color: Colors.red),
                                  ),
                                ),
                              ),
                            if (status == 'confirmed') ...[
                              if (!hasReviewed)
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: () async {
                                      // Mở trang đánh giá
                                      final result = await Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => PostRentalReviewPage(
                                            bookingId: bookingId,
                                            roomId: roomId,
                                            roomTitle: roomTitle,
                                            ownerId: ownerId,
                                            ownerName: ownerName,
                                          ),
                                        ),
                                      );

                                      // Refresh nếu đã đánh giá
                                      if (result == true && mounted) {
                                        setState(() {});
                                      }
                                    },
                                    icon: const Icon(Icons.star, size: 16),
                                    label: const Text('Đánh giá'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.amber,
                                      foregroundColor: Colors.white,
                                    ),
                                  ),
                                ),
                              if (hasReviewed)
                                Expanded(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.green.shade50,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: Colors.green),
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.check_circle,
                                          size: 16,
                                          color: Colors.green,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          'Đã đánh giá',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.green,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                            ],
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
