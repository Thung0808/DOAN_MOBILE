import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';
import 'models/room_model.dart';
import 'models/review_model.dart';
import 'services/rating_service.dart';

class ReviewPage extends StatefulWidget {
  final Room room;
  final String? bookingId; // ID của lịch hẹn đã xem (nếu có)
  final RoomReview? existingReview; // Đánh giá hiện có để chỉnh sửa

  const ReviewPage({
    super.key,
    required this.room,
    this.bookingId,
    this.existingReview,
  });

  @override
  State<ReviewPage> createState() => _ReviewPageState();
}

class _ReviewPageState extends State<ReviewPage> {
  final user = FirebaseAuth.instance.currentUser!;
  final dbRef = FirebaseDatabase.instance.ref();
  final _commentController = TextEditingController();
  int _selectedRating = 0;
  bool _isLoading = false;
  bool _canReview = true;

  @override
  void initState() {
    super.initState();
    // Load dữ liệu đánh giá hiện có nếu đang chỉnh sửa
    if (widget.existingReview != null) {
      _selectedRating = widget.existingReview!.rating;
      _commentController.text = widget.existingReview!.comment;
    } else {
      // Kiểm tra quyền đánh giá nếu đang thêm mới
      _checkCanReview();
    }
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _checkCanReview() async {
    try {
      // Kiểm tra xem người dùng có lịch hẹn đã hoàn thành cho phòng này không
      final bookingsSnapshot = await dbRef
          .child('bookings')
          .orderByChild('tenantId')
          .equalTo(user.uid)
          .get();

      if (!bookingsSnapshot.exists) {
        if (mounted) {
          setState(() {
            _canReview = false;
          });
        }
        return;
      }

      final bookings = bookingsSnapshot.value as Map;
      bool hasCompletedBooking = false;

      bookings.forEach((key, value) {
        if (value != null) {
          final booking = value as Map;
          if (booking['roomId'] == widget.room.id &&
              booking['status'] == 'completed') {
            hasCompletedBooking = true;
          }
        }
      });

      // Kiểm tra xem người dùng đã có đánh giá cho phòng này chưa (chỉ kiểm tra khi tạo mới)
      bool hasExistingReview = false;
      if (hasCompletedBooking && widget.existingReview == null) {
        final reviewsSnapshot = await dbRef
            .child('reviews')
            .orderByChild('roomId')
            .equalTo(widget.room.id)
            .get();

        if (reviewsSnapshot.exists) {
          final reviews = reviewsSnapshot.value as Map;
          reviews.forEach((key, value) {
            if (value != null) {
              final review = value as Map;
              if (review['reviewerId'] == user.uid) {
                hasExistingReview = true;
              }
            }
          });
        }
      }

      if (mounted) {
        setState(() {
          _canReview = hasCompletedBooking && !hasExistingReview;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _canReview = false;
        });
      }
      print('❌ Lỗi kiểm tra quyền đánh giá: $e');
    }
  }

  Future<void> _submitReview() async {
    // Kiểm tra quyền đánh giá trước
    if (!_canReview) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Bạn không có quyền đánh giá phòng này. Vui lòng hoàn thành việc xem phòng trước.',
          ),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 4),
        ),
      );
      return;
    }

    if (_selectedRating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng chọn số sao đánh giá'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_commentController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng nhập nhận xét'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Lấy thông tin người dùng
      final userSnapshot = await dbRef.child('users').child(user.uid).get();
      if (!userSnapshot.exists) {
        throw Exception('Không tìm thấy thông tin người dùng');
      }

      final userData = userSnapshot.value as Map;
      final userName = userData['name'] ?? user.displayName ?? 'Người dùng';
      final userEmail = user.email ?? '';

      // Tạo hoặc cập nhật review
      final reviewId =
          widget.existingReview?.id ?? dbRef.child('reviews').push().key!;
      final reviewRef = dbRef.child('reviews').child(reviewId);

      final review = RoomReview(
        id: reviewId,
        roomId: widget.room.id,
        roomTitle: widget.room.title,
        reviewerId: user.uid,
        reviewerName: userName,
        reviewerEmail: userEmail,
        rating: _selectedRating,
        comment: _commentController.text.trim(),
        timestamp:
            widget.existingReview?.timestamp ??
            DateTime.now().millisecondsSinceEpoch,
        bookingId: widget.bookingId ?? widget.existingReview?.bookingId,
        isVerified:
            widget.bookingId != null ||
            widget.existingReview?.isVerified == true,
      );

      // Lưu review vào Firebase
      await reviewRef.set(review.toMap());

      // Lưu review vào phòng
      await dbRef
          .child('rooms')
          .child(widget.room.id)
          .child('reviews')
          .child(reviewId)
          .set(review.toMap());

      // Lưu review vào profile người dùng
      await dbRef
          .child('users')
          .child(user.uid)
          .child('reviews')
          .child(reviewId)
          .set(review.toMap());

      // Cập nhật thống kê đánh giá của phòng
      await _updateRoomRatingStats();

      // Tạo thông báo cho chủ phòng (chỉ khi là đánh giá mới)
      if (widget.existingReview == null) {
        await _createReviewNotification(review);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    widget.existingReview != null
                        ? 'Đã cập nhật đánh giá thành công!'
                        : 'Cảm ơn bạn đã đánh giá! Đánh giá của bạn đã được ghi nhận.',
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );

        Navigator.pop(context, true); // Trả về true để refresh
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(child: Text('Lỗi đánh giá: ${e.toString()}')),
              ],
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
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

  Future<void> _createReviewNotification(RoomReview review) async {
    try {
      // Lấy thông tin người đánh giá
      final reviewerSnapshot = await dbRef.child('users').child(user.uid).get();
      final reviewerData = reviewerSnapshot.value as Map?;
      final reviewerName =
          reviewerData?['name'] ?? reviewerData?['displayName'] ?? 'Người dùng';

      // Tạo thông báo
      final notificationId = dbRef.child('notifications').push().key!;
      final notification = {
        'id': notificationId,
        'type': 'new_review',
        'title': 'Có đánh giá mới cho phòng của bạn',
        'content':
            '$reviewerName đã đánh giá ${review.rating} sao cho phòng "${widget.room.title}"',
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'roomId': widget.room.id,
        'reviewId': review.id,
        'fromUserId': user.uid,
        'fromUserName': reviewerName,
        'adminId': '', // Không phải từ admin
        'adminName': '', // Không phải từ admin
      };

      // Lưu thông báo cho chủ phòng (không cần kiểm tra ownerSnapshot.exists)
      await dbRef
          .child('users')
          .child(widget.room.ownerId)
          .child('notifications')
          .child(notificationId)
          .set(notification);

    } catch (e) {
      print('❌ Lỗi tạo thông báo đánh giá: $e');
    }
  }

  Future<void> _updateRoomRatingStats() async {
    try {
      // Sử dụng RatingService để cập nhật rating
      await RatingService().updateRoomRating(widget.room.id);
    } catch (e) {
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.existingReview != null
              ? 'Chỉnh sửa đánh giá'
              : 'Đánh giá phòng trọ',
        ),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: !_canReview && widget.existingReview == null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.block, size: 80, color: Colors.red[400]),
                    const SizedBox(height: 16),
                    Text(
                      'Không thể đánh giá',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.red[600],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Bạn chỉ có thể đánh giá sau khi hoàn thành việc xem phòng và được chủ trọ xác nhận.',
                      style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Quay lại'),
                    ),
                  ],
                ),
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Thông tin phòng
                  Card(
                    elevation: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.room.title,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${widget.room.address}, ${widget.room.ward}, ${widget.room.district}',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${NumberFormat('#,###').format(widget.room.price)} VNĐ/tháng',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Chọn sao đánh giá
                  const Text(
                    'Đánh giá của bạn:',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),

                  // Hiển thị sao
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (index) {
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedRating = index + 1;
                          });
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Icon(
                            index < _selectedRating
                                ? Icons.star
                                : Icons.star_border,
                            size: 40,
                            color: index < _selectedRating
                                ? Colors.amber
                                : Colors.grey[400],
                          ),
                        ),
                      );
                    }),
                  ),

                  const SizedBox(height: 16),

                  // Hiển thị mô tả đánh giá
                  if (_selectedRating > 0)
                    Center(
                      child: Text(
                        _getRatingDescription(_selectedRating),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: _getRatingColor(_selectedRating),
                        ),
                      ),
                    ),

                  const SizedBox(height: 32),

                  // Nhập nhận xét
                  const Text(
                    'Nhận xét chi tiết:',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),

                  TextField(
                    controller: _commentController,
                    maxLines: 5,
                    decoration: const InputDecoration(
                      hintText:
                          'Hãy chia sẻ trải nghiệm của bạn về phòng trọ này...',
                      border: OutlineInputBorder(),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.blue, width: 2),
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Nút gửi đánh giá
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _submitReview,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: _isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text(
                              'Gửi đánh giá',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Lưu ý
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info, color: Colors.blue, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Đánh giá của bạn sẽ được hiển thị công khai và giúp người khác có cái nhìn chính xác về phòng trọ này.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.blue[700],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  String _getRatingDescription(int rating) {
    switch (rating) {
      case 1:
        return '😞 Rất tệ - Không hài lòng';
      case 2:
        return '😕 Tệ - Không tốt lắm';
      case 3:
        return '😐 Bình thường - Ổn';
      case 4:
        return '😊 Tốt - Hài lòng';
      case 5:
        return '😍 Rất tốt - Cực kỳ hài lòng';
      default:
        return '';
    }
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
}
