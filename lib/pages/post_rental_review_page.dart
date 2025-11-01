import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import '../services/trust_score_service.dart';

/// Trang đánh giá sau khi thuê phòng thành công
class PostRentalReviewPage extends StatefulWidget {
  final String bookingId;
  final String roomId;
  final String roomTitle;
  final String ownerId;
  final String ownerName;

  const PostRentalReviewPage({
    super.key,
    required this.bookingId,
    required this.roomId,
    required this.roomTitle,
    required this.ownerId,
    required this.ownerName,
  });

  @override
  State<PostRentalReviewPage> createState() => _PostRentalReviewPageState();
}

class _PostRentalReviewPageState extends State<PostRentalReviewPage> {
  final user = FirebaseAuth.instance.currentUser!;
  final dbRef = FirebaseDatabase.instance.ref();

  int _rating = 5;
  final TextEditingController _reviewController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _reviewController.dispose();
    super.dispose();
  }

  Future<void> _submitReview() async {
    if (_reviewController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng nhập nội dung đánh giá'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      // 1. Lấy thông tin user
      final userSnapshot = await dbRef.child('users').child(user.uid).get();
      if (!userSnapshot.exists) {
        throw Exception('User not found');
      }

      final userData = userSnapshot.value as Map;
      final userName = userData['name'] ?? 'Unknown';

      // 2. Tạo review
      final reviewRef = dbRef.child('reviews').push();
      await reviewRef.set({
        'reviewId': reviewRef.key,
        'roomId': widget.roomId,
        'roomTitle': widget.roomTitle,
        'reviewerId': user.uid,
        'reviewerName': userName,
        'ownerId': widget.ownerId,
        'ownerName': widget.ownerName,
        'rating': _rating,
        'reviewText': _reviewController.text.trim(),
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'bookingId': widget.bookingId,
        'type': 'post_rental', // Đánh giá sau thuê
      });

      // 3. Cập nhật booking đã review
      await dbRef.child('bookings').child(widget.bookingId).update({
        'hasReviewed': true,
        'reviewedAt': DateTime.now().millisecondsSinceEpoch,
      });

      // 4. Cập nhật điểm trung bình của phòng
      await _updateRoomAverageRating();

      // 5. Cập nhật điểm uy tín của chủ trọ dựa trên rating
      await TrustScoreService.updateFromReview(widget.ownerId, _rating);

      // 6. Gửi thông báo cho chủ trọ
      await _notifyOwner();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 12),
                Expanded(child: Text('✅ Cảm ơn bạn đã đánh giá!')),
              ],
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );

        // Quay lại trang trước
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Lỗi: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> _updateRoomAverageRating() async {
    try {
      // Lấy tất cả reviews của phòng này
      final reviewsSnapshot = await dbRef
          .child('reviews')
          .orderByChild('roomId')
          .equalTo(widget.roomId)
          .get();

      if (!reviewsSnapshot.exists) return;

      final reviewsMap = reviewsSnapshot.value as Map;
      int totalRating = 0;
      int count = 0;

      for (var entry in reviewsMap.values) {
        final reviewData = entry as Map;
        totalRating += (reviewData['rating'] ?? 0) as int;
        count++;
      }

      final averageRating = count > 0 ? totalRating / count : 0.0;

      // Cập nhật vào room
      await dbRef.child('rooms').child(widget.roomId).update({
        'averageRating': averageRating,
        'reviewCount': count,
      });
    } catch (e) {
      print('❌ Error updating room rating: $e');
    }
  }

  Future<void> _notifyOwner() async {
    try {
      final notificationRef = dbRef
          .child('users')
          .child(widget.ownerId)
          .child('notifications')
          .push();

      await notificationRef.set({
        'title': '⭐ Có đánh giá mới',
        'content':
            'Người thuê đã đánh giá phòng "${widget.roomTitle}" của bạn với $_rating sao.',
        'type': 'new_review',
        'roomId': widget.roomId,
        'roomTitle': widget.roomTitle,
        'rating': _rating,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'adminId': 'system',
        'adminName': 'Hệ thống',
      });
    } catch (e) {
      print('❌ Error sending notification: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Đánh giá sau thuê'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Room info card
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.deepPurple.shade50,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.home,
                            color: Colors.deepPurple,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Phòng đã thuê',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                              Text(
                                widget.roomTitle,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Chủ trọ: ${widget.ownerName}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
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

            const SizedBox(height: 24),

            // Rating section
            const Text(
              'Đánh giá của bạn',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Bạn cảm thấy hài lòng như thế nào về phòng trọ này?',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 16),

            // Star rating
            Center(
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.1),
                      spreadRadius: 2,
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(5, (index) {
                        return GestureDetector(
                          onTap: () => setState(() => _rating = index + 1),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Icon(
                              index < _rating ? Icons.star : Icons.star_border,
                              color: Colors.amber,
                              size: 40,
                            ),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _getRatingText(_rating),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: _getRatingColor(_rating),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Review text
            const Text(
              'Chia sẻ trải nghiệm của bạn',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _reviewController,
              maxLines: 6,
              maxLength: 500,
              decoration: InputDecoration(
                hintText:
                    'Hãy chia sẻ trải nghiệm của bạn về phòng trọ, chủ trọ, vị trí, tiện ích...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.deepPurple, width: 2),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Submit button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submitReview,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.send, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'Gửi đánh giá',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
              ),
            ),

            const SizedBox(height: 16),

            // Skip button
            Center(
              child: TextButton(
                onPressed: _isSubmitting
                    ? null
                    : () => Navigator.pop(context, false),
                child: const Text('Bỏ qua'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getRatingText(int rating) {
    switch (rating) {
      case 1:
        return 'Rất tệ';
      case 2:
        return 'Tệ';
      case 3:
        return 'Bình thường';
      case 4:
        return 'Tốt';
      case 5:
        return 'Rất tốt';
      default:
        return '';
    }
  }

  Color _getRatingColor(int rating) {
    switch (rating) {
      case 1:
      case 2:
        return Colors.red;
      case 3:
        return Colors.orange;
      case 4:
      case 5:
        return Colors.green;
      default:
        return Colors.grey;
    }
  }
}
