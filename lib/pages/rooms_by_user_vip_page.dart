import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/room_with_owner.dart';
import '../services/room_service.dart';
import '../room_detail_page.dart';

/// Page demo: Hiển thị rooms với VIP từ owner
class RoomsByUserVipPage extends StatefulWidget {
  const RoomsByUserVipPage({super.key});

  @override
  State<RoomsByUserVipPage> createState() => _RoomsByUserVipPageState();
}

class _RoomsByUserVipPageState extends State<RoomsByUserVipPage> {
  final RoomService _roomService = RoomService();
  List<RoomWithOwner> _rooms = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRooms();
  }

  Future<void> _loadRooms() async {
    setState(() => _isLoading = true);

    try {
      final rooms = await _roomService.loadRoomsWithOwners(limit: 20);
      setState(() {
        _rooms = rooms;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi tải dữ liệu: $e'),
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
        title: const Text('Phòng trọ (sắp xếp theo VIP User)'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadRooms,
              child: _rooms.isEmpty
                  ? const Center(child: Text('Không có phòng nào'))
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _rooms.length,
                      itemBuilder: (context, index) {
                        final roomWithOwner = _rooms[index];
                        return _buildRoomCard(roomWithOwner);
                      },
                    ),
            ),
    );
  }

  Widget _buildRoomCard(RoomWithOwner roomWithOwner) {
    final room = roomWithOwner.room;
    final isOwnerVip = roomWithOwner.isOwnerVip;
    final vipIcon = roomWithOwner.ownerVipIcon;
    final vipName = roomWithOwner.ownerVipName;
    final vipColor = Color(roomWithOwner.ownerVipColor);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isOwnerVip ? vipColor.withOpacity(0.05) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isOwnerVip ? vipColor.withOpacity(0.3) : Colors.grey[300]!,
          width: isOwnerVip ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => RoomDetailPage(room: room),
              ),
            );
          },
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header với VIP badge
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        room.title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isOwnerVip) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: vipColor,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: vipColor.withOpacity(0.3),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(vipIcon, style: const TextStyle(fontSize: 16)),
                            const SizedBox(width: 4),
                            Text(
                              vipName.toUpperCase(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),

                const SizedBox(height: 12),

                // Price & Area
                Row(
                  children: [
                    Icon(
                      Icons.attach_money,
                      size: 18,
                      color: Colors.green[700],
                    ),
                    const SizedBox(width: 4),
                    Text(
                      NumberFormat.currency(
                        locale: 'vi_VN',
                        symbol: '₫',
                      ).format(room.price),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.green[700],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Icon(Icons.straighten, size: 18, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Text(
                      '${room.area}m²',
                      style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                    ),
                  ],
                ),

                const SizedBox(height: 8),

                // Location
                Row(
                  children: [
                    Icon(Icons.location_on, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        '${room.ward}, ${room.district}',
                        style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),

                // Owner VIP info (for debug)
                if (isOwnerVip) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: vipColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Chủ nhà $vipName - Phòng được ưu tiên hiển thị',
                      style: TextStyle(
                        fontSize: 11,
                        color: vipColor.withOpacity(0.8),
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
