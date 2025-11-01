import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';
import '../models/review_model.dart';
import '../models/room_model.dart';
import '../all_reviews_page.dart';
import '../review_detail_page.dart';

class RoomReviewsWidget extends StatefulWidget {
  final Room room;
  final int maxDisplayCount;

  const RoomReviewsWidget({
    super.key,
    required this.room,
    this.maxDisplayCount = 3,
  });

  @override
  State<RoomReviewsWidget> createState() => _RoomReviewsWidgetState();
}

class _RoomReviewsWidgetState extends State<RoomReviewsWidget> {
  final user = FirebaseAuth.instance.currentUser!;
  final dbRef = FirebaseDatabase.instance.ref();
  List<RoomReview> _reviews = [];
  bool _isLoading = true;
  double _averageRating = 0.0;
  int _totalReviews = 0;
  bool _canReview = false;
  bool _hasExistingReview = false;

  @override
  void initState() {
    super.initState();
    _loadReviews();
    _checkCanReview();
  }

  Future<void> _loadReviews() async {
    try {

      final snapshot = await dbRef
          .child('reviews')
          .orderByChild('roomId')
          .equalTo(widget.room.id)
          .get();


      if (!snapshot.exists) {
        print('❌ Không tìm thấy đánh giá nào');
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
        return;
      }

      final data = snapshot.value as Map;
      final reviews = <RoomReview>[];

      data.forEach((key, value) {
        if (value != null) {
          reviews.add(
            RoomReview.fromMap(key, Map<String, dynamic>.from(value as Map)),
          );
        }
      });

      // Sắp xếp theo thời gian (mới nhất lên đầu)
      reviews.sort((a, b) => b.timestamp.compareTo(a.timestamp));

      // Tính điểm trung bình
      double totalRating = 0;
      for (final review in reviews) {
        totalRating += review.rating;
      }
      final averageRating = reviews.isNotEmpty
          ? totalRating / reviews.length
          : 0.0;


      if (mounted) {
        setState(() {
          _reviews = reviews;
          _averageRating = averageRating;
          _totalReviews = reviews.length;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
      print('❌ Lỗi tải đánh giá: $e');

      // Hiển thị thông báo lỗi permission
      if (e.toString().contains('permission-denied')) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Lỗi quyền truy cập Firebase. Không thể tải đánh giá.',
              ),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 5),
            ),
          );
        }
      }
    }
  }

  Widget _buildStarRating(double rating) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        return Icon(
          index < rating.floor()
              ? Icons.star
              : index < rating
              ? Icons.star_half
              : Icons.star_border,
          size: 16,
          color: Colors.amber,
        );
      }),
    );
  }

  Widget _buildReviewCard(RoomReview review) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  ReviewDetailPage(room: widget.room, review: review),
            ),
          ).then((result) {
            if (result == true) {
              _loadReviews(); // Refresh danh sách nếu có thay đổi
            }
          });
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header với tên người đánh giá và sao
              Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: Colors.blue[100],
                    child: Text(
                      review.reviewerName.isNotEmpty
                          ? review.reviewerName[0].toUpperCase()
                          : '?',
                      style: TextStyle(
                        color: Colors.blue[700],
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          review.reviewerName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            _buildStarRating(review.rating.toDouble()),
                            const SizedBox(width: 8),
                            Text(
                              review.ratingText,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: _getRatingColor(review.rating),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Text(
                    DateFormat('dd/MM/yyyy').format(
                      DateTime.fromMillisecondsSinceEpoch(review.timestamp),
                    ),
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Nội dung đánh giá
              if (review.comment.isNotEmpty) ...[
                Text(
                  review.comment,
                  style: const TextStyle(fontSize: 14, height: 1.4),
                ),
                const SizedBox(height: 8),
              ],

              // Thông tin xác minh (nếu có)
              if (review.isVerified) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green[200]!),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.verified, size: 14, color: Colors.green[600]),
                      const SizedBox(width: 4),
                      Text(
                        'Đã xác minh',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.green[700],
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Color _getRatingColor(int rating) {
    if (rating >= 4) return Colors.green;
    if (rating >= 3) return Colors.orange;
    return Colors.red;
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

      // Kiểm tra xem người dùng đã có đánh giá cho phòng này chưa
      bool hasExistingReview = false;
      if (hasCompletedBooking) {
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
          _hasExistingReview = hasExistingReview;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _canReview = false;
        });
      }
      print('❌ Lỗi kiểm tra quyền đánh giá: $e');

      // Hiển thị thông báo lỗi permission
      if (e.toString().contains('permission-denied')) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Lỗi quyền truy cập Firebase. Vui lòng kiểm tra cài đặt.',
              ),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 5),
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        padding: const EdgeInsets.all(16),
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_reviews.isEmpty) {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: Column(
          children: [
            Icon(Icons.star_border, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 12),
            Text(
              'Chưa có đánh giá nào',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _canReview
                  ? 'Hãy là người đầu tiên đánh giá phòng này!'
                  : 'Chỉ người đã hoàn thành xem phòng mới có thể đánh giá.',
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
              textAlign: TextAlign.center,
            ),
            if (_canReview) ...[
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AllReviewsPage(room: widget.room),
                    ),
                  );
                },
                icon: const Icon(Icons.star),
                label: const Text('Đánh giá ngay'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber,
                  foregroundColor: Colors.white,
                ),
              ),
            ] else if (_hasExistingReview) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green[200]!),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.check_circle,
                      color: Colors.green[600],
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Bạn đã đánh giá phòng này. Vào trang đánh giá để xem/sửa đánh giá của bạn.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.green[700],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange[200]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info, color: Colors.orange[600], size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Để đánh giá, bạn cần hoàn thành việc xem phòng và được chủ trọ xác nhận.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.orange[700],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      );
    }

    final displayReviews = _reviews.take(widget.maxDisplayCount).toList();
    final hasMoreReviews = _reviews.length > widget.maxDisplayCount;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header với thống kê đánh giá
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue[200]!),
            ),
            child: Row(
              children: [
                Icon(Icons.star, color: Colors.amber[600], size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Đánh giá phòng',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue[800],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          _buildStarRating(_averageRating),
                          const SizedBox(width: 8),
                          Text(
                            '${_averageRating.toStringAsFixed(1)}/5',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue[700],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '(${_totalReviews} đánh giá)',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.blue[600],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Danh sách đánh giá
          ...displayReviews.map((review) => _buildReviewCard(review)),

          // Nút xem thêm (nếu có nhiều đánh giá hơn)
          if (hasMoreReviews) ...[
            const SizedBox(height: 8),
            Center(
              child: TextButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AllReviewsPage(room: widget.room),
                    ),
                  );
                },
                icon: const Icon(Icons.visibility),
                label: Text(
                  'Xem tất cả ${_totalReviews} đánh giá',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.blue[700],
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
