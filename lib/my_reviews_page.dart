import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';
import 'models/review_model.dart';
import 'models/room_model.dart';
import 'services/rating_service.dart';

class MyReviewsPage extends StatefulWidget {
  const MyReviewsPage({super.key});

  @override
  State<MyReviewsPage> createState() => _MyReviewsPageState();
}

class _MyReviewsPageState extends State<MyReviewsPage> {
  final user = FirebaseAuth.instance.currentUser!;
  final dbRef = FirebaseDatabase.instance.ref();
  List<RoomReview> _reviews = [];
  Map<String, Room> _rooms = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMyReviews();
  }

  Future<void> _loadMyReviews() async {
    try {
      // Lấy tất cả đánh giá của user hiện tại
      final reviewsSnapshot = await dbRef
          .child('reviews')
          .orderByChild('reviewerId')
          .equalTo(user.uid)
          .get();

      if (!reviewsSnapshot.exists) {
        setState(() {
          _reviews = [];
          _isLoading = false;
        });
        return;
      }

      final reviewsData = reviewsSnapshot.value as Map;
      final reviews = <RoomReview>[];
      final roomIds = <String>{};

      // Parse đánh giá và thu thập room IDs
      reviewsData.forEach((key, value) {
        if (value != null) {
          final review = RoomReview.fromMap(
            key,
            Map<String, dynamic>.from(value as Map),
          );
          reviews.add(review);
          roomIds.add(review.roomId);
        }
      });

      // Lấy thông tin phòng
      final rooms = <String, Room>{};
      for (final roomId in roomIds) {
        try {
          final roomSnapshot = await dbRef.child('rooms').child(roomId).get();
          if (roomSnapshot.exists) {
            rooms[roomId] = Room.fromMap(
              roomId,
              Map<String, dynamic>.from(roomSnapshot.value as Map),
            );
          }
        } catch (e) {
      // Handle error silently
    }
      }

      // Sắp xếp theo thời gian (mới nhất lên đầu)
      reviews.sort((a, b) => b.timestamp.compareTo(a.timestamp));

      setState(() {
        _reviews = reviews;
        _rooms = rooms;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi tải đánh giá: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteReview(String reviewId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xóa đánh giá'),
        content: const Text('Bạn có chắc chắn muốn xóa đánh giá này?'),
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
      try {
        // Lấy thông tin review để biết roomId trước khi xóa
        final reviewSnapshot = await dbRef
            .child('reviews')
            .child(reviewId)
            .get();
        String? roomId;
        if (reviewSnapshot.exists) {
          final reviewData = reviewSnapshot.value as Map;
          roomId = reviewData['roomId'] as String?;
        }

        // Xóa review từ Firebase
        await dbRef.child('reviews').child(reviewId).remove();

        // Xóa review từ profile người dùng
        await dbRef
            .child('users')
            .child(user.uid)
            .child('reviews')
            .child(reviewId)
            .remove();

        // Cập nhật rating của phòng
        if (roomId != null) {
          await RatingService().updateRoomRating(roomId);
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Đã xóa đánh giá thành công'),
              backgroundColor: Colors.green,
            ),
          );
          _loadMyReviews(); // Refresh danh sách
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Lỗi xóa đánh giá: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  String _formatTime(int timestamp) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    return DateFormat('dd/MM/yyyy HH:mm').format(date);
  }

  Color _getRatingColor(int rating) {
    switch (rating) {
      case 1:
        return Colors.red;
      case 2:
        return Colors.orange;
      case 3:
        return Colors.yellow[700]!;
      case 4:
        return Colors.lightGreen;
      case 5:
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Đánh giá của tôi'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _reviews.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.star_border, size: 80, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'Bạn chưa có đánh giá nào',
                    style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Hãy đánh giá phòng trọ bạn đã xem!',
                    style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _reviews.length,
              itemBuilder: (context, index) {
                final review = _reviews[index];
                final room = _rooms[review.roomId];

                return Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Thông tin phòng
                        if (room != null) ...[
                          Text(
                            room.title,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${room.address}, ${room.ward}, ${room.district}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${NumberFormat('#,###').format(room.price)} VNĐ/tháng',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                        ] else ...[
                          Text(
                            'Phòng trọ ID: ${review.roomId}',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],

                        const SizedBox(height: 12),

                        // Đánh giá
                        Row(
                          children: [
                            Row(
                              children: List.generate(5, (i) {
                                return Icon(
                                  i < review.rating
                                      ? Icons.star
                                      : Icons.star_border,
                                  size: 16,
                                  color: i < review.rating
                                      ? Colors.amber
                                      : Colors.grey[400],
                                );
                              }),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              review.ratingText,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: _getRatingColor(review.rating),
                              ),
                            ),
                            const Spacer(),
                            Text(
                              _formatTime(review.timestamp),
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),

                        if (review.comment.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.grey[50],
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey[300]!),
                            ),
                            child: Text(
                              review.comment,
                              style: const TextStyle(fontSize: 14),
                            ),
                          ),
                        ],

                        const SizedBox(height: 12),

                        // Nút xóa
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton.icon(
                              onPressed: () => _deleteReview(review.id),
                              icon: const Icon(Icons.delete, size: 16),
                              label: const Text('Xóa'),
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.red,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
