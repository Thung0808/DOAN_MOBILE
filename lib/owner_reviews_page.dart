import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';
import 'models/review_model.dart';
import 'models/room_model.dart';
import 'review_reply_page.dart';

class OwnerReviewsPage extends StatefulWidget {
  final Room room;

  const OwnerReviewsPage({super.key, required this.room});

  @override
  State<OwnerReviewsPage> createState() => _OwnerReviewsPageState();
}

class _OwnerReviewsPageState extends State<OwnerReviewsPage> {
  final user = FirebaseAuth.instance.currentUser!;
  final dbRef = FirebaseDatabase.instance.ref();
  List<RoomReview> _reviews = [];
  bool _isLoading = true;
  bool _isOwner = false;

  @override
  void initState() {
    super.initState();
    _checkPermissions();
    _loadReviews();
  }

  Future<void> _checkPermissions() async {
    try {
      // Kiểm tra xem người dùng có phải là chủ phòng không
      final roomSnapshot = await dbRef
          .child('rooms')
          .child(widget.room.id)
          .get();
      if (roomSnapshot.exists) {
        final roomData = roomSnapshot.value as Map;
        _isOwner = roomData['ownerId'] == user.uid;
      }
      setState(() {});
    } catch (e) {
      print('❌ Lỗi kiểm tra quyền: $e');
      setState(() {
        _isOwner = false;
      });
    }
  }

  Future<void> _loadReviews() async {
    try {
      final snapshot = await dbRef
          .child('reviews')
          .orderByChild('roomId')
          .equalTo(widget.room.id)
          .get();

      if (!snapshot.exists) {
        setState(() {
          _reviews = [];
          _isLoading = false;
        });
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

      setState(() {
        _reviews = reviews;
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

  bool _isTextOverflow(String text, int maxLines) {
    // Ước tính số ký tự trên mỗi dòng (khoảng 50-60 ký tự cho font size 14)
    const int charsPerLine = 55;
    final int estimatedLines = (text.length / charsPerLine).ceil();
    return estimatedLines > maxLines;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Đánh giá phòng'),
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
                    'Chưa có đánh giá nào',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Đánh giá sẽ xuất hiện ở đây khi có người đánh giá phòng của bạn',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                  ),
                ],
              ),
            )
          : Column(
              children: [
                // Header với thống kê
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  color: Colors.blue[50],
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          Column(
                            children: [
                              Text(
                                '${_reviews.length}',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue[700],
                                ),
                              ),
                              Text(
                                'Đánh giá',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.blue[600],
                                ),
                              ),
                            ],
                          ),
                          Column(
                            children: [
                              Text(
                                widget.room.averageRating.toStringAsFixed(1),
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.amber[700],
                                ),
                              ),
                              Text(
                                'Điểm TB',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.amber[600],
                                ),
                              ),
                            ],
                          ),
                          Column(
                            children: [
                              Text(
                                '${_reviews.where((r) => r.hasReply).length}',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green[700],
                                ),
                              ),
                              Text(
                                'Đã trả lời',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.green[600],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Danh sách đánh giá
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _reviews.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final review = _reviews[index];
                      return Card(
                        elevation: 2,
                        child: InkWell(
                          onTap: _isOwner
                              ? () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => ReviewReplyPage(
                                        review: review,
                                        room: widget.room,
                                      ),
                                    ),
                                  ).then((result) {
                                    if (result == true) {
                                      _loadReviews(); // Refresh danh sách
                                    }
                                  });
                                }
                              : null,
                          borderRadius: BorderRadius.circular(8),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Header với avatar và rating
                                Row(
                                  children: [
                                    CircleAvatar(
                                      backgroundColor: Colors.blue[100],
                                      child: Text(
                                        review.reviewerName.isNotEmpty
                                            ? review.reviewerName[0]
                                                  .toUpperCase()
                                            : 'U',
                                        style: TextStyle(
                                          color: Colors.blue[700],
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            review.reviewerName,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                            ),
                                          ),
                                          Text(
                                            _formatTime(review.timestamp),
                                            style: TextStyle(
                                              color: Colors.grey[600],
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: _getRatingColor(review.rating),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(
                                            Icons.star,
                                            color: Colors.white,
                                            size: 16,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            '${review.rating}',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),

                                // Comment
                                if (review.comment.isNotEmpty) ...[
                                  Text(
                                    review.comment,
                                    style: const TextStyle(fontSize: 15),
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 12),
                                ],

                                // Verified badge
                                if (review.isVerified)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.green[100],
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.verified,
                                          color: Colors.green[700],
                                          size: 16,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          'Đã xác minh',
                                          style: TextStyle(
                                            color: Colors.green[700],
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                // Reply của chủ phòng (nếu có)
                                if (review.hasReply) ...[
                                  const SizedBox(height: 12),
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.blue[50],
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: Colors.blue[200]!,
                                        width: 1,
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.reply,
                                              size: 16,
                                              color: Colors.blue[700],
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              'Trả lời của bạn',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.blue[700],
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          review.reply!,
                                          style: const TextStyle(fontSize: 14),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        // Hiển thị dấu ... nếu nội dung dài hơn 2 dòng
                                        if (_isTextOverflow(
                                          review.reply!,
                                          2,
                                        )) ...[
                                          const SizedBox(height: 4),
                                          Text(
                                            '...',
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: Colors.grey[600],
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ],

                                // Reply status và nút xem chi tiết
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Icon(
                                      review.hasReply
                                          ? Icons.reply
                                          : Icons.reply_outlined,
                                      size: 16,
                                      color: review.hasReply
                                          ? Colors.green
                                          : Colors.grey,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      review.hasReply
                                          ? 'Đã trả lời'
                                          : 'Chưa trả lời',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: review.hasReply
                                            ? Colors.green
                                            : Colors.grey,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const Spacer(),
                                    if (_isOwner) ...[
                                      Text(
                                        'Nhấn để ${review.hasReply ? 'xem/sửa' : 'trả lời'}',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.blue[600],
                                          fontStyle: FontStyle.italic,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Icon(
                                        Icons.arrow_forward_ios,
                                        size: 12,
                                        color: Colors.grey[400],
                                      ),
                                    ] else ...[
                                      Text(
                                        'Chỉ chủ phòng mới có thể trả lời',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey[500],
                                          fontStyle: FontStyle.italic,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}
