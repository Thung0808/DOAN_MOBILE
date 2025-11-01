import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../models/room_model.dart';
import '../models/review_model.dart';

class ReviewDetailPage extends StatefulWidget {
  final Room room;
  final RoomReview review;

  const ReviewDetailPage({Key? key, required this.room, required this.review})
    : super(key: key);

  @override
  State<ReviewDetailPage> createState() => _ReviewDetailPageState();
}

class _ReviewDetailPageState extends State<ReviewDetailPage> {
  final user = FirebaseAuth.instance.currentUser!;
  final dbRef = FirebaseDatabase.instance.ref();
  bool _isLoading = false;
  final TextEditingController _replyController = TextEditingController();
  bool _isReplying = false;
  List<Map<String, dynamic>> _replies = [];
  bool _isOwner = false;

  @override
  void initState() {
    super.initState();
    _loadReplies();
    _checkPermissions();
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

  @override
  void dispose() {
    _replyController.dispose();
    super.dispose();
  }

  Future<void> _loadReplies() async {
    try {

      final repliesSnapshot = await dbRef
          .child('reviewReplies')
          .orderByChild('reviewId')
          .equalTo(widget.review.id)
          .get();


      if (repliesSnapshot.exists) {
        final repliesData = repliesSnapshot.value as Map;
        final repliesList = <Map<String, dynamic>>[];

        repliesData.forEach((key, value) {
          if (value != null) {
            repliesList.add({
              'id': key,
              ...Map<String, dynamic>.from(value as Map),
            });
          }
        });

        // Sắp xếp theo thời gian (cũ nhất lên đầu)
        repliesList.sort(
          (a, b) => (a['timestamp'] as int).compareTo(b['timestamp'] as int),
        );

        setState(() {
          _replies = repliesList;
        });
      } else {
        print('❌ Không tìm thấy trả lời nào');
        setState(() {
          _replies = [];
        });
      }
    } catch (e) {
    }
  }

  Future<void> _submitReply() async {
    // Kiểm tra quyền trước khi cho phép gửi trả lời
    if (!_isOwner) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bạn không có quyền trả lời đánh giá này'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_replyController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng nhập nội dung trả lời'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isReplying = true;
    });

    try {
      final replyId = dbRef.child('reviewReplies').push().key;
      final replyData = {
        'id': replyId,
        'reviewId': widget.review.id,
        'roomId': widget.room.id,
        'replierId': user.uid,
        'replierName': user.displayName ?? 'Người dùng',
        'content': _replyController.text.trim(),
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };

      await dbRef.child('reviewReplies').child(replyId!).set(replyData);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã gửi trả lời thành công'),
            backgroundColor: Colors.green,
          ),
        );
        _replyController.clear();
        setState(() {
          _isReplying = false;
        });
        // Tải lại danh sách trả lời
        _loadReplies();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi gửi trả lời: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() {
          _isReplying = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chi tiết đánh giá'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Thông tin phòng
                  Card(
                    elevation: 3,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Colors.green[50]!, Colors.green[100]!],
                        ),
                      ),
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.home,
                                color: Colors.green[600],
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'Thông tin phòng',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            widget.room.title,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(
                                Icons.location_on,
                                size: 16,
                                color: Colors.grey[600],
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  '${widget.room.address}, ${widget.room.ward}, ${widget.room.district}',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[700],
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: Colors.green[200]!,
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.attach_money,
                                  color: Colors.green[600],
                                  size: 18,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${NumberFormat('#,###').format(widget.room.price)} VNĐ/tháng',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green[700],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Thông tin đánh giá
                  Card(
                    elevation: 3,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Colors.white, Colors.grey[50]!],
                        ),
                      ),
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header với sao và tên người đánh giá
                          Row(
                            children: [
                              // Avatar
                              CircleAvatar(
                                backgroundColor: Colors.blue[100],
                                radius: 24,
                                child: Text(
                                  widget.review.reviewerName.isNotEmpty
                                      ? widget.review.reviewerName[0]
                                            .toUpperCase()
                                      : 'U',
                                  style: TextStyle(
                                    color: Colors.blue[700],
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      widget.review.reviewerName,
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black87,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.access_time,
                                          size: 14,
                                          color: Colors.grey[600],
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          DateFormat('dd/MM/yyyy HH:mm').format(
                                            DateTime.fromMillisecondsSinceEpoch(
                                              widget.review.timestamp,
                                            ),
                                          ),
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[600],
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              // Hiển thị sao
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.amber[50],
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: Colors.amber[200]!,
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: List.generate(5, (index) {
                                    return Icon(
                                      index < widget.review.rating
                                          ? Icons.star
                                          : Icons.star_border,
                                      size: 16,
                                      color: index < widget.review.rating
                                          ? Colors.amber[600]
                                          : Colors.grey[400],
                                    );
                                  }),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 16),

                          // Đánh giá sao
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: _getRatingColor(
                                widget.review.rating,
                              ).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: _getRatingColor(
                                  widget.review.rating,
                                ).withValues(alpha: 0.3),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.star,
                                  size: 20,
                                  color: _getRatingColor(widget.review.rating),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '${widget.review.rating}/5',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: _getRatingColor(
                                      widget.review.rating,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    widget.review.ratingText,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: _getRatingColor(
                                        widget.review.rating,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          if (widget.review.comment.isNotEmpty) ...[
                            const SizedBox(height: 20),
                            Row(
                              children: [
                                Icon(
                                  Icons.comment,
                                  size: 16,
                                  color: Colors.grey[600],
                                ),
                                const SizedBox(width: 8),
                                const Text(
                                  'Nhận xét:',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.grey[50],
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.grey[300]!,
                                  width: 1,
                                ),
                              ),
                              child: Text(
                                widget.review.comment,
                                style: const TextStyle(
                                  fontSize: 14,
                                  height: 1.5,
                                  color: Colors.black87,
                                ),
                              ),
                            ),
                          ],

                          // Hiển thị trả lời ngay dưới đánh giá
                          if (_replies.isNotEmpty) ...[
                            const SizedBox(height: 20),
                            Row(
                              children: [
                                Icon(
                                  Icons.reply,
                                  size: 16,
                                  color: Colors.purple[600],
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Trả lời (${_replies.length})',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.purple[700],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            ...(_replies
                                .map(
                                  (reply) => Container(
                                    margin: const EdgeInsets.only(bottom: 8),
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.purple[50],
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: Colors.purple[200]!,
                                        width: 1,
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            CircleAvatar(
                                              backgroundColor:
                                                  Colors.purple[100],
                                              radius: 12,
                                              child: Text(
                                                (reply['replierName'] as String)
                                                        .isNotEmpty
                                                    ? (reply['replierName']
                                                              as String)[0]
                                                          .toUpperCase()
                                                    : 'U',
                                                style: TextStyle(
                                                  color: Colors.purple[700],
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 10,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    reply['replierName']
                                                        as String,
                                                    style: const TextStyle(
                                                      fontSize: 12,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: Colors.black87,
                                                    ),
                                                  ),
                                                  Text(
                                                    DateFormat(
                                                      'dd/MM/yyyy HH:mm',
                                                    ).format(
                                                      DateTime.fromMillisecondsSinceEpoch(
                                                        reply['timestamp']
                                                            as int,
                                                      ),
                                                    ),
                                                    style: TextStyle(
                                                      fontSize: 10,
                                                      color: Colors.grey[600],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          reply['content'] as String,
                                          style: const TextStyle(
                                            fontSize: 13,
                                            color: Colors.black87,
                                            height: 1.4,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                                .toList()),
                          ],
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Phần trả lời đánh giá - chỉ hiển thị form cho chủ phòng
                  if (_isOwner) ...[
                    Card(
                      elevation: 3,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Colors.purple[50]!, Colors.purple[100]!],
                          ),
                        ),
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.reply,
                                  color: Colors.purple[600],
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                const Text(
                                  'Trả lời đánh giá',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.purple[200]!,
                                  width: 1,
                                ),
                              ),
                              child: TextField(
                                controller: _replyController,
                                maxLines: 3,
                                decoration: InputDecoration(
                                  hintText: 'Nhập nội dung trả lời của bạn...',
                                  hintStyle: TextStyle(
                                    color: Colors.grey[500],
                                    fontSize: 14,
                                  ),
                                  border: InputBorder.none,
                                  contentPadding: const EdgeInsets.all(16),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: _isReplying ? null : _submitReply,
                                icon: _isReplying
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                Colors.white,
                                              ),
                                        ),
                                      )
                                    : const Icon(Icons.send),
                                label: Text(
                                  _isReplying ? 'Đang gửi...' : 'Gửi trả lời',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.purple[600],
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 10,
                                    horizontal: 20,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  elevation: 2,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ] else ...[
                    // Hiển thị thông báo cho người dùng không phải chủ phòng
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          color: Colors.grey[50],
                        ),
                        padding: const EdgeInsets.all(20),
                        child: Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              color: Colors.grey[600],
                              size: 24,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Chỉ có chủ phòng mới có thể trả lời đánh giá này.',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[700],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }

  Color _getRatingColor(int rating) {
    if (rating >= 4) return Colors.green;
    if (rating >= 3) return Colors.orange;
    return Colors.red;
  }
}
