import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

class TestNotificationPage extends StatefulWidget {
  const TestNotificationPage({super.key});

  @override
  State<TestNotificationPage> createState() => _TestNotificationPageState();
}

class _TestNotificationPageState extends State<TestNotificationPage> {
  final user = FirebaseAuth.instance.currentUser!;
  final dbRef = FirebaseDatabase.instance.ref();
  bool _isLoading = false;

  Future<void> _createTestNotification() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Tạo thông báo test
      final notificationId = dbRef.child('notifications').push().key!;
      final notification = {
        'id': notificationId,
        'type': 'new_review',
        'title': 'Test: Có đánh giá mới cho phòng của bạn',
        'content': 'Test: Người dùng đã đánh giá 5 sao cho phòng "Test Room"',
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'roomId': 'test_room_id',
        'reviewId': 'test_review_id',
        'fromUserId': user.uid,
        'fromUserName': 'Test User',
        'adminId': '',
        'adminName': '',
      };

      // Lưu thông báo cho user hiện tại
      await dbRef
          .child('users')
          .child(user.uid)
          .child('notifications')
          .child(notificationId)
          .set(notification);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Đã tạo thông báo test thành công!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Lỗi tạo thông báo: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _checkNotifications() async {
    try {
      final snapshot = await dbRef
          .child('users')
          .child(user.uid)
          .child('notifications')
          .get();

      if (snapshot.exists) {
        final data = snapshot.value as Map;
        data.forEach((key, value) {
        });
      } else {
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Đã kiểm tra thông báo (xem console)'),
            backgroundColor: Colors.blue,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Lỗi kiểm tra: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Test Thông báo'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Test Thông báo',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Tạo thông báo test để kiểm tra hệ thống thông báo có hoạt động không.',
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isLoading ? null : _createTestNotification,
                        icon: _isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.notifications_active),
                        label: Text(
                          _isLoading ? 'Đang tạo...' : 'Tạo thông báo test',
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Kiểm tra thông báo',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Kiểm tra số lượng thông báo hiện có trong database.',
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _checkNotifications,
                        icon: const Icon(Icons.search),
                        label: const Text('Kiểm tra thông báo'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Hướng dẫn',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '1. Nhấn "Tạo thông báo test" để tạo thông báo\n'
                      '2. Nhấn "Kiểm tra thông báo" để xem số lượng\n'
                      '3. Vào trang Thông báo để xem thông báo\n'
                      '4. Test đánh giá phòng để tạo thông báo thật',
                      style: TextStyle(fontSize: 14),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
