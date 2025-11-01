import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';
import 'models/review_model.dart';
import 'models/room_model.dart';

class ReviewReplyPage extends StatefulWidget {
  final RoomReview review;
  final Room room;

  const ReviewReplyPage({super.key, required this.review, required this.room});

  @override
  State<ReviewReplyPage> createState() => _ReviewReplyPageState();
}

class _ReviewReplyPageState extends State<ReviewReplyPage> {
  final user = FirebaseAuth.instance.currentUser!;
  final dbRef = FirebaseDatabase.instance.ref();
  final _replyController = TextEditingController();
  bool _isLoading = false;
  bool _isOwner = false;
  bool _canEditReply = false;

  @override
  void initState() {
    super.initState();
    if (widget.review.reply != null) {
      _replyController.text = widget.review.reply!;
    }
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

      // Kiểm tra xem người dùng có thể sửa trả lời không
      // Chỉ cho phép sửa nếu:
      // 1. Là chủ phòng VÀ
      // 2. (Chưa có trả lời HOẶC người dùng hiện tại là người đã tạo trả lời)
      if (_isOwner) {
        if (widget.review.reply == null) {
          // Chưa có trả lời, có thể tạo mới
          _canEditReply = true;
        } else {
          // Đã có trả lời, chỉ cho phép sửa nếu là người đã tạo trả lời
          _canEditReply = widget.review.replyUserId == user.uid;
        }
      }

      setState(() {});
    } catch (e) {
      print('❌ Lỗi kiểm tra quyền: $e');
      setState(() {
        _isOwner = false;
        _canEditReply = false;
      });
    }
  }

  @override
  void dispose() {
    _replyController.dispose();
    super.dispose();
  }

  Future<void> _submitReply() async {
    // Kiểm tra quyền trước khi cho phép gửi trả lời
    if (!_canEditReply) {
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
      _isLoading = true;
    });

    try {
      // Lấy thông tin người dùng
      final userSnapshot = await dbRef.child('users').child(user.uid).get();
      final userData = userSnapshot.value as Map?;
      final userName =
          userData?['name'] ?? userData?['displayName'] ?? 'Chủ phòng';

      // Cập nhật reply vào review
      await dbRef.child('reviews').child(widget.review.id).update({
        'reply': _replyController.text.trim(),
        'replyTimestamp': DateTime.now().millisecondsSinceEpoch,
        'replyUserId': user.uid,
      });

      // Cập nhật reply trong phòng
      await dbRef
          .child('rooms')
          .child(widget.room.id)
          .child('reviews')
          .child(widget.review.id)
          .update({
            'reply': _replyController.text.trim(),
            'replyTimestamp': DateTime.now().millisecondsSinceEpoch,
            'replyUserId': user.uid,
          });

      // Cập nhật reply trong profile người đánh giá
      await dbRef
          .child('users')
          .child(widget.review.reviewerId)
          .child('reviews')
          .child(widget.review.id)
          .update({
            'reply': _replyController.text.trim(),
            'replyTimestamp': DateTime.now().millisecondsSinceEpoch,
            'replyUserId': user.uid,
          });

      // Tạo thông báo cho người đánh giá
      await _createReplyNotification(userName);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã trả lời đánh giá thành công!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi trả lời đánh giá: ${e.toString()}'),
            backgroundColor: Colors.red,
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

  Future<void> _createReplyNotification(String ownerName) async {
    try {
      final notificationId = dbRef.child('notifications').push().key!;
      final notification = {
        'id': notificationId,
        'type': 'review_reply',
        'title': 'Chủ phòng đã trả lời đánh giá của bạn',
        'content':
            '$ownerName đã trả lời đánh giá về phòng "${widget.room.title}"',
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'roomId': widget.room.id,
        'reviewId': widget.review.id,
        'fromUserId': user.uid,
        'fromUserName': ownerName,
      };

      // Lưu thông báo cho người đánh giá
      await dbRef
          .child('users')
          .child(widget.review.reviewerId)
          .child('notifications')
          .child(notificationId)
          .set(notification);
    } catch (e) {
      print('❌ Lỗi tạo thông báo: $e');
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
        title: const Text('Trả lời đánh giá'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thông tin phòng
            Card(
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
                      widget.room.address,
                      style: TextStyle(color: Colors.grey[600], fontSize: 14),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Đánh giá
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: Colors.blue[100],
                          child: Text(
                            widget.review.reviewerName.isNotEmpty
                                ? widget.review.reviewerName[0].toUpperCase()
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
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.review.reviewerName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              Text(
                                _formatTime(widget.review.timestamp),
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
                            color: _getRatingColor(widget.review.rating),
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
                                '${widget.review.rating}',
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
                    if (widget.review.comment.isNotEmpty) ...[
                      Text(
                        widget.review.comment,
                        style: const TextStyle(fontSize: 15),
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (widget.review.isVerified)
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
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Trả lời hiện tại (nếu có)
            if (widget.review.hasReply) ...[
              Card(
                color: Colors.blue[50],
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.reply, color: Colors.blue[700], size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Trả lời của bạn',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.blue[700],
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        widget.review.reply!,
                        style: const TextStyle(fontSize: 15),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _formatTime(widget.review.replyTimestamp!),
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Form trả lời - chỉ hiển thị cho chủ phòng
            if (_isOwner) ...[
              if (_canEditReply) ...[
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.review.hasReply
                              ? 'Chỉnh sửa trả lời'
                              : 'Trả lời đánh giá',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _replyController,
                          maxLines: 4,
                          decoration: const InputDecoration(
                            hintText: 'Nhập nội dung trả lời...',
                            border: OutlineInputBorder(),
                            labelText: 'Nội dung trả lời',
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _isLoading ? null : _submitReply,
                            icon: _isLoading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.send),
                            label: Text(
                              _isLoading
                                  ? 'Đang gửi...'
                                  : widget.review.hasReply
                                  ? 'Cập nhật trả lời'
                                  : 'Gửi trả lời',
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ] else ...[
                // Hiển thị thông báo nếu là chủ phòng nhưng không thể sửa trả lời
                Card(
                  color: Colors.orange[50],
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Icon(Icons.info, color: Colors.orange[700], size: 24),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Bạn không thể sửa trả lời này vì nó được tạo bởi người khác.',
                            style: TextStyle(
                              color: Colors.orange[700],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ] else ...[
              // Hiển thị thông báo cho người không phải chủ phòng
              Card(
                color: Colors.grey[50],
                child: Padding(
                  padding: const EdgeInsets.all(16),
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
}
