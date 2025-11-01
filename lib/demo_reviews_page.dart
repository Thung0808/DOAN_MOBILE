import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'models/room_model.dart';
import 'owner_reviews_page.dart';

class DemoReviewsPage extends StatefulWidget {
  const DemoReviewsPage({super.key});

  @override
  State<DemoReviewsPage> createState() => _DemoReviewsPageState();
}

class _DemoReviewsPageState extends State<DemoReviewsPage> {
  final user = FirebaseAuth.instance.currentUser!;
  final dbRef = FirebaseDatabase.instance.ref();
  List<Room> _myRooms = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMyRooms();
  }

  Future<void> _loadMyRooms() async {
    try {
      final snapshot = await dbRef
          .child('rooms')
          .orderByChild('ownerId')
          .equalTo(user.uid)
          .get();

      if (!snapshot.exists) {
        setState(() {
          _myRooms = [];
          _isLoading = false;
        });
        return;
      }

      final data = snapshot.value as Map;
      final rooms = <Room>[];

      data.forEach((key, value) {
        if (value != null) {
          rooms.add(Room.fromMap(key, Map<String, dynamic>.from(value as Map)));
        }
      });

      setState(() {
        _myRooms = rooms;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi tải phòng: ${e.toString()}'),
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
        title: const Text('Demo - Quản lý đánh giá'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _myRooms.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.home_outlined, size: 80, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'Bạn chưa có phòng nào',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Hãy đăng phòng để có thể quản lý đánh giá',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _myRooms.length,
              itemBuilder: (context, index) {
                final room = _myRooms[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.blue[100],
                      child: Icon(Icons.home, color: Colors.blue[700]),
                    ),
                    title: Text(
                      room.title,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(room.address),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.star,
                              size: 16,
                              color:
                                  room.reviewCount > 0 && room.averageRating > 0
                                  ? Colors.amber
                                  : Colors.grey[400],
                            ),
                            const SizedBox(width: 4),
                            Text(
                              room.reviewCount > 0 && room.averageRating > 0
                                  ? '${room.averageRating.toStringAsFixed(1)} (${room.reviewCount})'
                                  : 'Chưa có đánh giá',
                              style: TextStyle(
                                fontSize: 12,
                                color:
                                    room.reviewCount > 0 &&
                                        room.averageRating > 0
                                    ? Colors.amber[700]
                                    : Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    trailing: ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => OwnerReviewsPage(room: room),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                      ),
                      child: const Text('Xem đánh giá'),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
