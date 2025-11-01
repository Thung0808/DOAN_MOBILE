import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';

class DebugReportsPage extends StatefulWidget {
  const DebugReportsPage({super.key});

  @override
  State<DebugReportsPage> createState() => _DebugReportsPageState();
}

class _DebugReportsPageState extends State<DebugReportsPage> {
  final dbRef = FirebaseDatabase.instance.ref();
  final user = FirebaseAuth.instance.currentUser!;
  String _debugInfo = 'Đang kiểm tra...';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkReports();
  }

  Future<void> _checkReports() async {
    setState(() {
      _isLoading = true;
      _debugInfo = 'Đang kiểm tra Firebase...\n\n';
    });

    try {
      // Check current user
      _debugInfo += '👤 User hiện tại:\n';
      _debugInfo += '   UID: ${user.uid}\n';
      _debugInfo += '   Email: ${user.email}\n\n';

      // Check user role
      final userSnapshot = await dbRef.child('users').child(user.uid).get();
      if (userSnapshot.exists) {
        final userData = userSnapshot.value as Map;
        _debugInfo += '👔 Role: ${userData['role'] ?? 'user'}\n\n';
      } else {
        _debugInfo += '⚠️ Không tìm thấy thông tin user trong database\n\n';
      }

      // Check reports node
      _debugInfo += '📊 Kiểm tra node reports:\n';
      final reportsSnapshot = await dbRef.child('reports').get();

      if (reportsSnapshot.exists) {
        final reportsData = reportsSnapshot.value as Map;
        _debugInfo += '   ✅ Node reports tồn tại\n';
        _debugInfo += '   📈 Số lượng báo cáo: ${reportsData.length}\n\n';

        // List all reports
        _debugInfo += '📝 Danh sách báo cáo:\n';
        reportsData.forEach((key, value) {
          final report = value as Map;
          _debugInfo += '\n   ID: $key\n';
          _debugInfo += '   Room: ${report['roomTitle']}\n';
          _debugInfo += '   Reporter: ${report['reporterName']}\n';
          _debugInfo += '   Reason: ${report['reason']}\n';
          _debugInfo += '   Status: ${report['status']}\n';
          final timestamp = (report['timestamp'] is int)
              ? report['timestamp']
              : (report['timestamp'] as num?)?.toInt() ?? 0;
          _debugInfo +=
              '   Timestamp: ${DateTime.fromMillisecondsSinceEpoch(timestamp)}\n';
        });
      } else {
        _debugInfo += '   ❌ Node reports KHÔNG tồn tại\n';
        _debugInfo += '   💡 Nguyên nhân có thể:\n';
        _debugInfo += '      1. Chưa có báo cáo nào được gửi\n';
        _debugInfo += '      2. Firebase Rules chưa cho phép đọc\n';
        _debugInfo += '      3. Tài khoản không phải admin\n\n';

        // Try to create a test report
        _debugInfo += '🧪 Thử tạo báo cáo test...\n';
        try {
          final testRef = dbRef.child('reports').push();
          await testRef.set({
            'roomId': 'test_room',
            'roomTitle': 'Test Report',
            'reporterId': user.uid,
            'reporterName': user.displayName ?? 'Test User',
            'reporterEmail': user.email ?? '',
            'reason': 'Test',
            'description': 'This is a test report',
            'timestamp': DateTime.now().millisecondsSinceEpoch,
            'status': 'pending',
          });
          _debugInfo += '   ✅ Tạo báo cáo test thành công!\n';
          _debugInfo += '   Test ID: ${testRef.key}\n';

          // Verify
          final verifySnapshot = await testRef.get();
          if (verifySnapshot.exists) {
            _debugInfo += '   ✅ Xác nhận: Có thể đọc lại báo cáo test\n';
          } else {
            _debugInfo += '   ⚠️ Không thể đọc lại báo cáo test\n';
          }
        } catch (e) {
          _debugInfo += '   ❌ LỖI tạo báo cáo test: $e\n';
          _debugInfo += '\n🔧 Khắc phục:\n';
          _debugInfo +=
              '   1. Kiểm tra Firebase Rules (xem file FIREBASE_DATABASE_RULES_REPORTS.md)\n';
          _debugInfo += '   2. Đảm bảo rules cho phép ghi vào node reports\n';
          _debugInfo += '   3. Đảm bảo tài khoản có quyền admin để đọc\n';
        }
      }
    } catch (e) {
      _debugInfo += '\n❌ LỖI: $e\n';
      _debugInfo += '\n🔧 Khắc phục:\n';
      _debugInfo += '1. Kiểm tra kết nối Internet\n';
      _debugInfo += '2. Kiểm tra Firebase Rules\n';
      _debugInfo += '3. Kiểm tra quyền của tài khoản\n';
    }

    setState(() {
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Debug Báo cáo'),
        backgroundColor: Colors.purple,
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _checkReports),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: SelectableText(
                      _debugInfo,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 13,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    '💡 Hướng dẫn:',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '1. Xem thông tin debug ở trên\n'
                    '2. Nếu node reports không tồn tại hoặc không đọc được, cập nhật Firebase Rules\n'
                    '3. Mở file FIREBASE_DATABASE_RULES_REPORTS.md để xem hướng dẫn chi tiết\n'
                    '4. Sau khi cập nhật rules, nhấn nút refresh ở trên',
                    style: TextStyle(fontSize: 14, height: 1.5),
                  ),
                ],
              ),
            ),
    );
  }
}
