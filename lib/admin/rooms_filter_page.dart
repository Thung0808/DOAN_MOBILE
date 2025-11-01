import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';
import '../room_detail_page.dart';
import '../models/room_model.dart';

class RoomsFilterPage extends StatefulWidget {
  final String filterType; // 'all', 'approved', 'rejected', 'pending', 'today'
  final String title;

  const RoomsFilterPage({
    super.key,
    required this.filterType,
    required this.title,
  });

  @override
  State<RoomsFilterPage> createState() => _RoomsFilterPageState();
}

class _RoomsFilterPageState extends State<RoomsFilterPage> {
  final dbRef = FirebaseDatabase.instance.ref();

  Future<void> _deleteRoom(String roomId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xác nhận xóa'),
        content: const Text('Bạn có chắc muốn xóa bài đăng này?'),
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
      await dbRef.child('rooms').child(roomId).remove();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('✅ Đã xóa bài đăng')));
      }
    }
  }

  Future<void> _changeStatus(String roomId, String newStatus) async {
    await dbRef.child('rooms').child(roomId).update({'status': newStatus});
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            newStatus == 'approved'
                ? '✅ Đã duyệt bài'
                : newStatus == 'rejected'
                ? '❌ Đã từ chối'
                : '⏳ Chuyển về chờ duyệt',
          ),
        ),
      );
    }
  }

  List<MapEntry> _filterRooms(Map rooms) {
    final now = DateTime.now();
    final todayStart = DateTime(
      now.year,
      now.month,
      now.day,
    ).millisecondsSinceEpoch;

    return rooms.entries.where((entry) {
      final room = entry.value as Map;
      final status = room['status'] ?? 'pending';
      final timestamp = room['timestamp'] ?? 0;

      switch (widget.filterType) {
        case 'all':
          return true;
        case 'approved':
          return status == 'approved';
        case 'rejected':
          return status == 'rejected';
        case 'pending':
          return status == 'pending';
        case 'today':
          return timestamp >= todayStart;
        default:
          return true;
      }
    }).toList()..sort((a, b) {
      final aTime = a.value['timestamp'] ?? 0;
      final bTime = b.value['timestamp'] ?? 0;
      return bTime.compareTo(aTime);
    });
  }

  @override
  Widget build(BuildContext context) {
    final formatter = NumberFormat.currency(locale: 'vi_VN', symbol: '₫');

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: StreamBuilder(
          stream: dbRef.child('rooms').onValue,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline, size: 60, color: Colors.red[300]),
                    const SizedBox(height: 16),
                    Text('Lỗi tải dữ liệu: ${snapshot.error}'),
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
                    Icon(
                      Icons.home_outlined,
                      size: 80,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Chưa có bài đăng nào',
                      style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                    ),
                  ],
                ),
              );
            }

            final filteredRooms = _filterRooms(data);

            if (filteredRooms.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.search_off, size: 80, color: Colors.grey[400]),
                    const SizedBox(height: 16),
                    Text(
                      'Không có bài đăng nào phù hợp',
                      style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                    ),
                  ],
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: filteredRooms.length,
              itemBuilder: (context, index) {
                final roomId = filteredRooms[index].key;
                final roomData = filteredRooms[index].value as Map;
                final room = Room.fromMap(roomId, roomData);

                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  child: InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => RoomDetailPage(room: room),
                        ),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Image
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: room.images.isNotEmpty
                                ? Image.network(
                                    room.images[0],
                                    width: 100,
                                    height: 100,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Container(
                                      width: 80,
                                      height: 80,
                                      color: Colors.grey[300],
                                      child: const Icon(Icons.home),
                                    ),
                                  )
                                : Container(
                                    width: 100,
                                    height: 100,
                                    color: Colors.grey[300],
                                    child: const Icon(Icons.home, size: 40),
                                  ),
                          ),
                          const SizedBox(width: 12),

                          // Info
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  room.title,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  formatter.format(room.price),
                                  style: const TextStyle(
                                    color: Colors.red,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '📍 ${room.district}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                _buildStatusChip(room.status),
                              ],
                            ),
                          ),

                          // Actions
                          PopupMenuButton<String>(
                            onSelected: (value) {
                              if (value == 'view') {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => RoomDetailPage(room: room),
                                  ),
                                );
                              } else if (value == 'approve') {
                                _changeStatus(roomId, 'approved');
                              } else if (value == 'reject') {
                                _changeStatus(roomId, 'rejected');
                              } else if (value == 'pending') {
                                _changeStatus(roomId, 'pending');
                              } else if (value == 'delete') {
                                _deleteRoom(roomId);
                              }
                            },
                            itemBuilder: (context) => [
                              const PopupMenuItem(
                                value: 'view',
                                child: Row(
                                  children: [
                                    Icon(Icons.visibility, size: 20),
                                    SizedBox(width: 8),
                                    Text('Xem chi tiết'),
                                  ],
                                ),
                              ),
                              if (room.status != 'approved')
                                const PopupMenuItem(
                                  value: 'approve',
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.check,
                                        size: 20,
                                        color: Colors.green,
                                      ),
                                      SizedBox(width: 8),
                                      Text('Duyệt bài'),
                                    ],
                                  ),
                                ),
                              if (room.status != 'rejected')
                                const PopupMenuItem(
                                  value: 'reject',
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.close,
                                        size: 20,
                                        color: Colors.red,
                                      ),
                                      SizedBox(width: 8),
                                      Text('Từ chối'),
                                    ],
                                  ),
                                ),
                              if (room.status != 'pending')
                                const PopupMenuItem(
                                  value: 'pending',
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.hourglass_empty,
                                        size: 20,
                                        color: Colors.orange,
                                      ),
                                      SizedBox(width: 8),
                                      Text('Chờ duyệt'),
                                    ],
                                  ),
                                ),
                              const PopupMenuItem(
                                value: 'delete',
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.delete,
                                      size: 20,
                                      color: Colors.red,
                                    ),
                                    SizedBox(width: 8),
                                    Text(
                                      'Xóa',
                                      style: TextStyle(color: Colors.red),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color color;
    String text;
    IconData icon;

    switch (status) {
      case 'approved':
        color = Colors.green;
        text = 'Đang hiển thị';
        icon = Icons.check_circle;
        break;
      case 'rejected':
        color = Colors.red;
        text = 'Bị từ chối';
        icon = Icons.cancel;
        break;
      default:
        color = Colors.orange;
        text = 'Chờ duyệt';
        icon = Icons.hourglass_empty;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
