import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import '../services/rating_service.dart';
import '../test_notification_page.dart';
import '../demo_reviews_page.dart';

class UpdateRatingsPage extends StatefulWidget {
  const UpdateRatingsPage({super.key});

  @override
  State<UpdateRatingsPage> createState() => _UpdateRatingsPageState();
}

class _UpdateRatingsPageState extends State<UpdateRatingsPage> {
  final dbRef = FirebaseDatabase.instance.ref();
  bool _isLoading = false;
  String _status = '';

  Future<void> _updateAllRatings() async {
    setState(() {
      _isLoading = true;
      _status = 'Đang cập nhật rating cho tất cả phòng...';
    });

    try {
      await RatingService().updateAllRoomRatings();

      setState(() {
        _status = '✅ Đã cập nhật rating thành công cho tất cả phòng!';
      });
    } catch (e) {
      setState(() {
        _status = '❌ Lỗi: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _fixInconsistentRatings() async {
    setState(() {
      _isLoading = true;
      _status = 'Đang kiểm tra dữ liệu rating...';
    });

    try {
      await RatingService().fixInconsistentRatings();

      setState(() {
        _status = '✅ Đã kiểm tra và sửa dữ liệu rating không nhất quán!';
      });
    } catch (e) {
      setState(() {
        _status = '❌ Lỗi: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cập nhật Rating'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Cập nhật Rating cho tất cả phòng',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Tính toán lại rating trung bình và số lượng đánh giá cho tất cả phòng trong hệ thống.',
                      style: TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isLoading ? null : _updateAllRatings,
                        icon: _isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.update),
                        label: Text(
                          _isLoading ? 'Đang cập nhật...' : 'Cập nhật tất cả',
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
                      'Sửa dữ liệu rating không nhất quán',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Kiểm tra và sửa các phòng có dữ liệu rating không khớp với số lượng review thực tế.',
                      style: TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isLoading ? null : _fixInconsistentRatings,
                        icon: _isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.build),
                        label: Text(
                          _isLoading ? 'Đang kiểm tra...' : 'Kiểm tra và sửa',
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
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
            if (_status.isNotEmpty)
              Card(
                color: _status.contains('✅')
                    ? Colors.green[50]
                    : _status.contains('❌')
                    ? Colors.red[50]
                    : Colors.blue[50],
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(
                        _status.contains('✅')
                            ? Icons.check_circle
                            : _status.contains('❌')
                            ? Icons.error
                            : Icons.info,
                        color: _status.contains('✅')
                            ? Colors.green
                            : _status.contains('❌')
                            ? Colors.red
                            : Colors.blue,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _status,
                          style: TextStyle(
                            color: _status.contains('✅')
                                ? Colors.green[800]
                                : _status.contains('❌')
                                ? Colors.red[800]
                                : Colors.blue[800],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 16),

            // Test thông báo
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Test thông báo',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Test hệ thống thông báo để đảm bảo hoạt động đúng.',
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const TestNotificationPage(),
                            ),
                          );
                        },
                        icon: const Icon(Icons.notifications_active),
                        label: const Text('Test thông báo'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.purple,
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

            // Demo quản lý đánh giá
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Demo quản lý đánh giá',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Xem demo trang quản lý đánh giá với hiển thị trả lời ngắn gọn.',
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const DemoReviewsPage(),
                            ),
                          );
                        },
                        icon: const Icon(Icons.rate_review),
                        label: const Text('Demo quản lý đánh giá'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
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
