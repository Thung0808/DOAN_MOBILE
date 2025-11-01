import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import '../services/trust_score_service.dart';

class DatabaseMigrationPage extends StatefulWidget {
  const DatabaseMigrationPage({super.key});

  @override
  State<DatabaseMigrationPage> createState() => _DatabaseMigrationPageState();
}

class _DatabaseMigrationPageState extends State<DatabaseMigrationPage> {
  final dbRef = FirebaseDatabase.instance.ref();
  bool _isLoading = false;
  String _statusMessage = '';
  int _roomsUpdated = 0;
  int _bookingsUpdated = 0;
  int _usersUpdated = 0;

  Future<void> _migrateRooms() async {
    setState(() {
      _isLoading = true;
      _statusMessage = '🔄 Đang cập nhật phòng...';
      _roomsUpdated = 0;
    });

    try {
      final snapshot = await dbRef.child('rooms').get();

      if (!snapshot.exists) {
        setState(() {
          _statusMessage = '⚠️ Không có phòng nào trong database';
          _isLoading = false;
        });
        return;
      }

      final roomsMap = snapshot.value as Map;
      int updated = 0;

      for (var entry in roomsMap.entries) {
        final roomId = entry.key;
        final roomData = entry.value as Map;

        // Chỉ cập nhật nếu chưa có trường availabilityStatus
        if (!roomData.containsKey('availabilityStatus')) {
          await dbRef.child('rooms').child(roomId).update({
            'availabilityStatus': 'DangMo', // Mặc định là đang mở
          });
          updated++;

          if (mounted) {
            setState(() {
              _roomsUpdated = updated;
              _statusMessage = '🔄 Đang cập nhật phòng... ($updated phòng)';
            });
          }
        }
      }

      if (mounted) {
        setState(() {
          _statusMessage = '✅ Đã cập nhật $updated phòng thành công!';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _statusMessage = '❌ Lỗi: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _migrateBookings() async {
    setState(() {
      _isLoading = true;
      _statusMessage = '🔄 Đang cập nhật bookings...';
      _bookingsUpdated = 0;
    });

    try {
      final snapshot = await dbRef.child('bookings').get();

      if (!snapshot.exists) {
        setState(() {
          _statusMessage = '⚠️ Không có booking nào trong database';
          _isLoading = false;
        });
        return;
      }

      final bookingsMap = snapshot.value as Map;
      int updated = 0;

      for (var entry in bookingsMap.entries) {
        final bookingId = entry.key;
        final bookingData = entry.value as Map;

        // Chỉ cập nhật nếu chưa có trường bookingType
        if (!bookingData.containsKey('bookingType')) {
          // Xác định loại booking dựa trên paymentStatus
          final paymentStatus = bookingData['paymentStatus'] ?? 'unpaid';
          final bookingType =
              paymentStatus == 'partial' || paymentStatus == 'paid'
              ? 'deposit'
              : 'viewing';

          await dbRef.child('bookings').child(bookingId).update({
            'bookingType': bookingType,
          });
          updated++;

          if (mounted) {
            setState(() {
              _bookingsUpdated = updated;
              _statusMessage =
                  '🔄 Đang cập nhật bookings... ($updated bookings)';
            });
          }
        }
      }

      if (mounted) {
        setState(() {
          _statusMessage = '✅ Đã cập nhật $updated bookings thành công!';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _statusMessage = '❌ Lỗi: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _migrateTrustScores() async {
    setState(() {
      _isLoading = true;
      _statusMessage = '🔄 Đang cập nhật điểm uy tín...';
      _usersUpdated = 0;
    });

    try {
      final snapshot = await dbRef.child('users').get();

      if (!snapshot.exists) {
        setState(() {
          _statusMessage = '⚠️ Không có user nào trong database';
          _isLoading = false;
        });
        return;
      }

      final usersMap = snapshot.value as Map;
      int updated = 0;

      for (var entry in usersMap.entries) {
        final userId = entry.key;
        final userData = entry.value as Map;

        // Chỉ cập nhật nếu chưa có trường trustScore
        if (!userData.containsKey('trustScore')) {
          await dbRef.child('users').child(userId).update({
            'trustScore': TrustScoreService.INITIAL_SCORE,
            'lastTrustScoreUpdate': DateTime.now().millisecondsSinceEpoch,
          });
          updated++;

          if (mounted) {
            setState(() {
              _usersUpdated = updated;
              _statusMessage = '🔄 Đang cập nhật users... ($updated users)';
            });
          }
        }
      }

      if (mounted) {
        setState(() {
          _statusMessage = '✅ Đã cập nhật $updated users thành công!';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _statusMessage = '❌ Lỗi: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _migrateAll() async {
    setState(() {
      _isLoading = true;
      _statusMessage = '🔄 Bắt đầu migration toàn bộ database...';
    });

    // Migrate rooms trước
    await _migrateRooms();

    // Đợi 1 giây
    await Future.delayed(const Duration(seconds: 1));

    // Migrate bookings
    await _migrateBookings();

    // Đợi 1 giây
    await Future.delayed(const Duration(seconds: 1));

    // Migrate trust scores
    await _migrateTrustScores();

    if (mounted) {
      setState(() {
        _statusMessage =
            '✅ Hoàn tất!\n'
            '📊 Phòng: $_roomsUpdated cập nhật\n'
            '📊 Bookings: $_bookingsUpdated cập nhật\n'
            '📊 Users (Trust Score): $_usersUpdated cập nhật';
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Migration hoàn tất thành công!'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Database Migration'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Warning card
            Card(
              color: Colors.orange.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.warning_amber_rounded, color: Colors.orange),
                        const SizedBox(width: 8),
                        Text(
                          'Cảnh báo',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.orange.shade900,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Migration này sẽ cập nhật tất cả phòng và booking trong database:\n\n'
                      '• Phòng: Thêm trường "availabilityStatus" = "DangMo"\n'
                      '• Bookings: Thêm trường "bookingType" (viewing/deposit)\n\n'
                      'Chỉ chạy một lần duy nhất!',
                      style: TextStyle(color: Colors.orange.shade900),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Status message
            if (_statusMessage.isNotEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Trạng thái:',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(_statusMessage, style: TextStyle(fontSize: 14)),
                      if (_roomsUpdated > 0 || _bookingsUpdated > 0) ...[
                        const SizedBox(height: 12),
                        const Divider(),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            Column(
                              children: [
                                Text(
                                  '$_roomsUpdated',
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue,
                                  ),
                                ),
                                Text('Phòng'),
                              ],
                            ),
                            Column(
                              children: [
                                Text(
                                  '$_bookingsUpdated',
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green,
                                  ),
                                ),
                                Text('Bookings'),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),

            const Spacer(),

            // Buttons
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _migrateRooms,
              icon: const Icon(Icons.hotel),
              label: const Text(
                'Migrate Phòng',
                style: TextStyle(fontSize: 16),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
            const SizedBox(height: 12),

            ElevatedButton.icon(
              onPressed: _isLoading ? null : _migrateBookings,
              icon: const Icon(Icons.event),
              label: const Text(
                'Migrate Bookings',
                style: TextStyle(fontSize: 16),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
            const SizedBox(height: 12),

            ElevatedButton.icon(
              onPressed: _isLoading ? null : _migrateTrustScores,
              icon: const Icon(Icons.verified_user),
              label: const Text(
                'Migrate Điểm Uy Tín',
                style: TextStyle(fontSize: 16),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
            const SizedBox(height: 12),

            ElevatedButton.icon(
              onPressed: _isLoading ? null : _migrateAll,
              icon: _isLoading
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Icon(Icons.sync),
              label: Text(
                _isLoading ? 'Đang xử lý...' : 'Migrate Tất Cả',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
