import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

class CreateNotificationPage extends StatefulWidget {
  const CreateNotificationPage({super.key});

  @override
  State<CreateNotificationPage> createState() => _CreateNotificationPageState();
}

class _CreateNotificationPageState extends State<CreateNotificationPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  final dbRef = FirebaseDatabase.instance.ref();
  final user = FirebaseAuth.instance.currentUser!;
  bool _isLoading = false;

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _createNotification() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // Lấy thông tin admin
      final userSnapshot = await dbRef.child('users').child(user.uid).get();
      final userData = userSnapshot.value as Map?;
      final adminName = userData?['name'] ?? 'Admin';

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final notificationData = {
        'title': _titleController.text.trim(),
        'content': _contentController.text.trim(),
        'timestamp': timestamp,
        'adminId': user.uid,
        'adminName': adminName,
        'type': 'admin_notification',
      };

      // Lấy danh sách tất cả user
      final usersSnapshot = await dbRef.child('users').get();

      if (usersSnapshot.exists && usersSnapshot.value != null) {
        final users = usersSnapshot.value as Map;
        final updates = <String, dynamic>{};

        // Tạo thông báo cho từng user
        for (var userId in users.keys) {
          final notificationId = dbRef
              .child('users')
              .child(userId)
              .child('notifications')
              .push()
              .key;
          updates['users/$userId/notifications/$notificationId'] =
              notificationData;
        }

        // Lưu thông báo vào node chung để admin có thể quản lý
        final globalNotificationId = dbRef.child('notifications').push().key;
        updates['notifications/$globalNotificationId'] = notificationData;

        // Thực hiện tất cả cập nhật cùng lúc
        await dbRef.update(updates);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '✅ Đã gửi thông báo đến ${users.length} người dùng!',
              ),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context);
        }
      } else {
        throw Exception('Không tìm thấy người dùng nào');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Lỗi: $e'), backgroundColor: Colors.red),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tạo thông báo mới'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Icon
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.notifications_active,
                size: 64,
                color: Colors.blue,
              ),
            ),
            const SizedBox(height: 24),

            // Tiêu đề
            Text(
              'Thông báo sẽ được gửi đến tất cả người dùng',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
            const SizedBox(height: 32),

            // Title
            TextFormField(
              controller: _titleController,
              decoration: InputDecoration(
                labelText: 'Tiêu đề thông báo',
                prefixIcon: const Icon(Icons.title),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.grey[100],
              ),
              maxLength: 100,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Vui lòng nhập tiêu đề';
                }
                if (value.trim().length < 5) {
                  return 'Tiêu đề phải có ít nhất 5 ký tự';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Content
            TextFormField(
              controller: _contentController,
              decoration: InputDecoration(
                labelText: 'Nội dung thông báo',
                prefixIcon: const Icon(Icons.message),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.grey[100],
                alignLabelWithHint: true,
              ),
              maxLines: 8,
              maxLength: 500,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Vui lòng nhập nội dung';
                }
                if (value.trim().length < 10) {
                  return 'Nội dung phải có ít nhất 10 ký tự';
                }
                return null;
              },
            ),
            const SizedBox(height: 32),

            // Submit button
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _createNotification,
              icon: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.send),
              label: Text(
                _isLoading ? 'Đang gửi...' : 'Gửi thông báo',
                style: const TextStyle(fontSize: 16),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
