import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';

/// Trang hiển thị thống kê chi tiết cho một phòng cụ thể
class RoomDetailStatsPage extends StatefulWidget {
  final String roomId;
  final String roomTitle;

  const RoomDetailStatsPage({
    super.key,
    required this.roomId,
    required this.roomTitle,
  });

  @override
  State<RoomDetailStatsPage> createState() => _RoomDetailStatsPageState();
}

class _RoomDetailStatsPageState extends State<RoomDetailStatsPage> {
  final dbRef = FirebaseDatabase.instance.ref();

  bool _isLoading = true;
  int _viewCount = 0;
  List<Map<String, dynamic>> _viewingBookings = [];
  List<Map<String, dynamic>> _depositBookings = [];

  @override
  void initState() {
    super.initState();
    _loadRoomStats();
  }

  Future<void> _loadRoomStats() async {
    setState(() => _isLoading = true);

    try {
      // 1. Load room info
      final roomSnapshot = await dbRef
          .child('rooms')
          .child(widget.roomId)
          .get();
      if (roomSnapshot.exists) {
        final roomData = roomSnapshot.value as Map;
        _viewCount = (roomData['viewCount'] ?? 0) as int;
      }

      // 2. Load bookings
      final bookingsSnapshot = await dbRef
          .child('bookings')
          .orderByChild('roomId')
          .equalTo(widget.roomId)
          .get();

      if (bookingsSnapshot.exists) {
        final bookingsMap = bookingsSnapshot.value as Map;

        final viewingList = <Map<String, dynamic>>[];
        final depositList = <Map<String, dynamic>>[];

        for (var entry in bookingsMap.entries) {
          final bookingData = Map<String, dynamic>.from(entry.value as Map);
          bookingData['id'] = entry.key;

          if (bookingData['bookingType'] == 'viewing') {
            viewingList.add(bookingData);
          } else if (bookingData['bookingType'] == 'deposit') {
            depositList.add(bookingData);
          }
        }

        // Sort by created date
        viewingList.sort(
          (a, b) => (b['createdAt'] ?? 0).compareTo(a['createdAt'] ?? 0),
        );
        depositList.sort(
          (a, b) => (b['createdAt'] ?? 0).compareTo(a['createdAt'] ?? 0),
        );

        setState(() {
          _viewingBookings = viewingList;
          _depositBookings = depositList;
        });
      }

      setState(() => _isLoading = false);
    } catch (e) {
      print('❌ Error loading room stats: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chi Tiết Thống Kê'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Room title
                  Text(
                    widget.roomTitle,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Stats cards
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          'Lượt xem',
                          _viewCount.toString(),
                          Icons.visibility,
                          Colors.blue,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildStatCard(
                          'Đặt lịch',
                          _viewingBookings.length.toString(),
                          Icons.event,
                          Colors.orange,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          'Đặt cọc',
                          _depositBookings.length.toString(),
                          Icons.account_balance_wallet,
                          Colors.green,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildStatCard(
                          'Tỷ lệ CR',
                          '${(_viewCount > 0 ? (_depositBookings.length / _viewCount * 100) : 0).toStringAsFixed(1)}%',
                          Icons.trending_up,
                          Colors.purple,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Viewing bookings
                  if (_viewingBookings.isNotEmpty) ...[
                    _buildSectionTitle(
                      'Đặt Lịch Xem (${_viewingBookings.length})',
                    ),
                    const SizedBox(height: 12),
                    ..._viewingBookings
                        .take(5)
                        .map(
                          (booking) =>
                              _buildBookingCard(booking, Colors.orange),
                        ),
                    if (_viewingBookings.length > 5)
                      Center(
                        child: Text(
                          '+ ${_viewingBookings.length - 5} lịch xem khác',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                      ),
                    const SizedBox(height: 24),
                  ],

                  // Deposit bookings
                  if (_depositBookings.isNotEmpty) ...[
                    _buildSectionTitle('Đặt Cọc (${_depositBookings.length})'),
                    const SizedBox(height: 12),
                    ..._depositBookings.map(
                      (booking) => _buildBookingCard(booking, Colors.green),
                    ),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 4,
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(title, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 20,
          decoration: BoxDecoration(
            color: Colors.deepPurple,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildBookingCard(Map<String, dynamic> booking, Color color) {
    final tenantName = booking['tenantName'] ?? 'Unknown';
    final tenantPhone = booking['tenantPhone'] ?? '';
    final createdAt = booking['createdAt'] ?? 0;
    final status = booking['status'] ?? 'pending';
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.person, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tenantName,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (tenantPhone.isNotEmpty)
                  Text(
                    tenantPhone,
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                Text(
                  dateFormat.format(
                    DateTime.fromMillisecondsSinceEpoch(createdAt),
                  ),
                  style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                ),
              ],
            ),
          ),
          _buildStatusBadge(status),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    String text;

    switch (status) {
      case 'pending':
        color = Colors.orange;
        text = 'Chờ';
        break;
      case 'confirmed':
        color = Colors.green;
        text = 'Đã xác nhận';
        break;
      case 'rejected':
        color = Colors.red;
        text = 'Từ chối';
        break;
      case 'cancelled':
        color = Colors.grey;
        text = 'Hủy';
        break;
      default:
        color = Colors.grey;
        text = status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}
