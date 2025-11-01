import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';
import 'models/notification_model.dart';
import 'models/review_model.dart';
import 'models/room_model.dart';
import 'review_reply_page.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  final dbRef = FirebaseDatabase.instance.ref();
  Set<String> _readNotifications = {};

  User? get currentUser => FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    _loadReadNotifications();
  }

  Future<void> _loadReadNotifications() async {
    if (currentUser == null) return;

    final snapshot = await dbRef
        .child('users')
        .child(currentUser!.uid)
        .child('readNotifications')
        .get();

    if (snapshot.exists && snapshot.value != null) {
      final readSet = <String>{};

      // 🔥 Xử lý cả List và Map
      if (snapshot.value is List) {
        final list = snapshot.value as List;
        for (var item in list) {
          if (item != null && item is String) {
            readSet.add(item);
          }
        }
      } else if (snapshot.value is Map) {
        final map = snapshot.value as Map;
        for (var value in map.values) {
          if (value != null && value is String) {
            readSet.add(value);
          }
        }
      }

      setState(() {
        _readNotifications = readSet;
      });
    }
  }

  Future<void> _markAsRead(String notificationId) async {
    if (currentUser == null) return;

    if (_readNotifications.contains(notificationId)) return;

    setState(() {
      _readNotifications.add(notificationId);
    });

    await dbRef
        .child('users')
        .child(currentUser!.uid)
        .child('readNotifications')
        .set(_readNotifications.toList());
  }

  Future<void> _deleteNotification(String notificationId) async {
    if (currentUser == null) return;

    try {
      // Xóa thông báo khỏi database
      await dbRef
          .child('users')
          .child(currentUser!.uid)
          .child('notifications')
          .child(notificationId)
          .remove();

      // Xóa khỏi danh sách đã đọc nếu có
      if (_readNotifications.contains(notificationId)) {
        setState(() {
          _readNotifications.remove(notificationId);
        });

        await dbRef
            .child('users')
            .child(currentUser!.uid)
            .child('readNotifications')
            .set(_readNotifications.toList());
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.delete, color: Colors.white),
                const SizedBox(width: 12),
                const Expanded(child: Text('Đã xóa thông báo')),
              ],
            ),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Lỗi xóa thông báo: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _markAllAsRead(List<AppNotification> notifications) async {
    if (currentUser == null) return;

    final allIds = notifications.map((n) => n.id).toSet();

    setState(() {
      _readNotifications.addAll(allIds);
    });

    await dbRef
        .child('users')
        .child(currentUser!.uid)
        .child('readNotifications')
        .set(_readNotifications.toList());

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.done_all, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Đã đánh dấu ${notifications.length} thông báo là đã đọc',
                ),
              ),
            ],
          ),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _clearAllReadNotifications() async {
    if (currentUser == null) return;

    try {
      // Lấy danh sách thông báo hiện tại
      final notificationsSnapshot = await dbRef
          .child('users')
          .child(currentUser!.uid)
          .child('notifications')
          .get();

      if (notificationsSnapshot.exists && notificationsSnapshot.value != null) {
        final notifications = notificationsSnapshot.value as Map;
        final readNotificationIds = _readNotifications.toList();

        // Xóa từng thông báo đã đọc
        for (String notificationId in readNotificationIds) {
          if (notifications.containsKey(notificationId)) {
            await dbRef
                .child('users')
                .child(currentUser!.uid)
                .child('notifications')
                .child(notificationId)
                .remove();
          }
        }
      }

      // Xóa danh sách readNotifications
      await dbRef
          .child('users')
          .child(currentUser!.uid)
          .child('readNotifications')
          .remove();

      setState(() {
        _readNotifications.clear();
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.delete_forever, color: Colors.white),
                const SizedBox(width: 12),
                const Expanded(child: Text('Đã xóa tất cả thông báo đã đọc')),
              ],
            ),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Lỗi: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  IconData _getNotificationIcon(String type) {
    switch (type) {
      case 'new_review':
        return Icons.star;
      case 'review_reply':
        return Icons.reply;
      case 'booking':
        return Icons.event;
      case 'admin':
      default:
        return Icons.notifications;
    }
  }

  Color _getNotificationColor(String type, bool isRead) {
    if (isRead) return Colors.grey;

    switch (type) {
      case 'new_review':
        return Colors.amber;
      case 'review_reply':
        return Colors.green;
      case 'booking':
        return Colors.blue;
      case 'admin':
      default:
        return Colors.blue;
    }
  }

  Future<void> _handleNotificationTap(AppNotification notification) async {
    if (notification.type == 'review_reply' &&
        notification.roomId != null &&
        notification.reviewId != null) {
      // Điều hướng đến trang trả lời đánh giá
      try {
        // Lấy thông tin phòng và đánh giá
        final roomSnapshot = await dbRef
            .child('rooms')
            .child(notification.roomId!)
            .get();
        final reviewSnapshot = await dbRef
            .child('reviews')
            .child(notification.reviewId!)
            .get();

        if (roomSnapshot.exists && reviewSnapshot.exists) {
          final room = Room.fromMap(
            notification.roomId!,
            Map<String, dynamic>.from(roomSnapshot.value as Map),
          );
          final review = RoomReview.fromMap(
            notification.reviewId!,
            Map<String, dynamic>.from(reviewSnapshot.value as Map),
          );

          if (mounted) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ReviewReplyPage(review: review, room: room),
              ),
            );
          }
        } else {
          _showNotificationDialog(notification);
        }
      } catch (e) {
        print('❌ Lỗi điều hướng: $e');
        _showNotificationDialog(notification);
      }
    } else if (notification.type == 'new_review' &&
        notification.roomId != null &&
        notification.reviewId != null) {
      // Điều hướng đến trang trả lời đánh giá cho đánh giá mới
      try {
        // Lấy thông tin phòng và đánh giá
        final roomSnapshot = await dbRef
            .child('rooms')
            .child(notification.roomId!)
            .get();
        final reviewSnapshot = await dbRef
            .child('reviews')
            .child(notification.reviewId!)
            .get();

        if (roomSnapshot.exists && reviewSnapshot.exists) {
          final room = Room.fromMap(
            notification.roomId!,
            Map<String, dynamic>.from(roomSnapshot.value as Map),
          );
          final review = RoomReview.fromMap(
            notification.reviewId!,
            Map<String, dynamic>.from(reviewSnapshot.value as Map),
          );

          if (mounted) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ReviewReplyPage(review: review, room: room),
              ),
            );
          }
        } else {
          _showNotificationDialog(notification);
        }
      } catch (e) {
        print('❌ Lỗi điều hướng: $e');
        _showNotificationDialog(notification);
      }
    } else {
      // Hiển thị dialog thông báo thông thường
      _showNotificationDialog(notification);
    }
  }

  void _showNotificationDialog(AppNotification notification) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.notifications_active, color: Colors.blue),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                notification.title,
                style: const TextStyle(fontSize: 18),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(notification.content),
              const SizedBox(height: 16),
              Divider(color: Colors.grey[300]),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.person, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    notification.fromUserName ?? notification.adminName,
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    _formatTime(notification.timestamp),
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Đóng'),
          ),
        ],
      ),
    );
  }

  String _formatTime(int timestamp) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inMinutes < 1) {
      return 'Vừa xong';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes} phút trước';
    } else if (difference.inDays < 1) {
      return '${difference.inHours} giờ trước';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} ngày trước';
    } else {
      return DateFormat('dd/MM/yyyy HH:mm').format(date);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.notifications_active,
                color: Colors.amber,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Thông báo',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Text(
                  'Cập nhật mới nhất',
                  style: TextStyle(fontSize: 12, color: Colors.white70),
                ),
              ],
            ),
          ],
        ),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.orange.shade600, Colors.deepOrange.shade400],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        foregroundColor: Colors.white,
        elevation: 4,
        shadowColor: Colors.orange.withOpacity(0.5),
        actions: [
          // Nút xóa tất cả thông báo
          Container(
            margin: const EdgeInsets.only(right: 4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              onPressed: _clearAllReadNotifications,
              icon: const Icon(Icons.delete_forever, color: Colors.white),
              tooltip: 'Xóa tất cả thông báo',
            ),
          ),
          // Nút đọc tất cả
          if (currentUser != null)
            StreamBuilder(
              stream: dbRef
                  .child('users')
                  .child(currentUser!.uid)
                  .child('notifications')
                  .onValue,
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const SizedBox.shrink();

                final data = (snapshot.data?.snapshot.value ?? {}) as Map?;
                if (data == null || data.isEmpty)
                  return const SizedBox.shrink();

                final notifications = data.entries
                    .map((e) => AppNotification.fromMap(e.key, e.value))
                    .toList();

                final unreadCount = notifications
                    .where((n) => !_readNotifications.contains(n.id))
                    .length;

                if (unreadCount == 0) return const SizedBox.shrink();

                return Container(
                  margin: const EdgeInsets.only(right: 8),
                  child: TextButton.icon(
                    onPressed: () => _markAllAsRead(notifications),
                    style: TextButton.styleFrom(
                      backgroundColor: Colors.white.withOpacity(0.2),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(
                      Icons.done_all,
                      color: Colors.white,
                      size: 18,
                    ),
                    label: const Text(
                      'Đọc tất cả',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                );
              },
            ),
        ],
      ),
      body: currentUser == null
          ? const Center(child: Text('Vui lòng đăng nhập'))
          : StreamBuilder(
              stream: dbRef
                  .child('users')
                  .child(currentUser!.uid)
                  .child('notifications')
                  .onValue,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error, size: 64, color: Colors.red),
                        const SizedBox(height: 16),
                        Text('Lỗi: ${snapshot.error}'),
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
                        TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0.0, end: 1.0),
                          duration: const Duration(milliseconds: 800),
                          curve: Curves.elasticOut,
                          builder: (context, value, child) {
                            return Transform.scale(
                              scale: value,
                              child: Container(
                                padding: const EdgeInsets.all(24),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.orange.shade50,
                                      Colors.deepOrange.shade50,
                                    ],
                                  ),
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.orange.withOpacity(0.2),
                                      blurRadius: 20,
                                      spreadRadius: 5,
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  Icons.notifications_off,
                                  size: 80,
                                  color: Colors.orange.shade300,
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'Chưa có thông báo nào',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[800],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Thông báo mới sẽ hiển thị ở đây',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  );
                }

                // Parse và sắp xếp thông báo (mới nhất lên đầu)
                final notifications =
                    data.entries
                        .map(
                          (entry) =>
                              AppNotification.fromMap(entry.key, entry.value),
                        )
                        .toList()
                      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

                final unreadCount = notifications
                    .where((n) => !_readNotifications.contains(n.id))
                    .length;

                return Column(
                  children: [
                    // Stats Bar - Show Unread Count
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.orange.shade50,
                            Colors.deepOrange.shade50,
                          ],
                        ),
                        border: Border(
                          bottom: BorderSide(color: Colors.orange.shade100),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: unreadCount > 0
                                  ? Colors.orange.shade100
                                  : Colors.green.shade100,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              unreadCount > 0
                                  ? Icons.notifications_active
                                  : Icons.notifications_none,
                              color: unreadCount > 0
                                  ? Colors.orange.shade700
                                  : Colors.green.shade700,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${notifications.length} thông báo',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.orange.shade900,
                                    fontSize: 15,
                                  ),
                                ),
                                if (unreadCount > 0)
                                  Text(
                                    '$unreadCount chưa đọc',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          if (unreadCount > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.orange.shade400,
                                    Colors.deepOrange.shade400,
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.orange.withOpacity(0.3),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.fiber_manual_record,
                                    color: Colors.white,
                                    size: 10,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '$unreadCount',
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
                    ),

                    // Danh sách thông báo
                    Expanded(
                      child: ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: notifications.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final notification = notifications[index];
                          final isRead = _readNotifications.contains(
                            notification.id,
                          );

                          return Dismissible(
                            key: Key(notification.id),
                            direction: DismissDirection.endToStart,
                            background: Container(
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 20),
                              color: Colors.red,
                              child: const Icon(
                                Icons.delete,
                                color: Colors.white,
                                size: 24,
                              ),
                            ),
                            confirmDismiss: (direction) async {
                              return await showDialog<bool>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text('Xác nhận xóa'),
                                  content: const Text(
                                    'Bạn có chắc muốn xóa thông báo này?',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(context, false),
                                      child: const Text('Hủy'),
                                    ),
                                    ElevatedButton(
                                      onPressed: () =>
                                          Navigator.pop(context, true),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.red,
                                      ),
                                      child: const Text('Xóa'),
                                    ),
                                  ],
                                ),
                              );
                            },
                            onDismissed: (direction) {
                              _deleteNotification(notification.id);
                            },
                            child: InkWell(
                              onTap: () {
                                _markAsRead(notification.id);
                                _handleNotificationTap(notification);
                              },
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: isRead
                                      ? Colors.white
                                      : Colors.blue.withValues(alpha: 0.05),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isRead
                                        ? Colors.grey[300]!
                                        : Colors.blue.withValues(alpha: 0.3),
                                    width: isRead ? 1 : 2,
                                  ),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Icon
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: isRead
                                            ? Colors.grey[200]
                                            : Colors.blue.withValues(
                                                alpha: 0.1,
                                              ),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        _getNotificationIcon(notification.type),
                                        color: _getNotificationColor(
                                          notification.type,
                                          isRead,
                                        ),
                                        size: 24,
                                      ),
                                    ),
                                    const SizedBox(width: 12),

                                    // Content
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            notification.title,
                                            style: TextStyle(
                                              fontWeight: isRead
                                                  ? FontWeight.normal
                                                  : FontWeight.bold,
                                              fontSize: 16,
                                              color: isRead
                                                  ? Colors.grey[600]
                                                  : Colors.black87,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            notification.content,
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: Colors.grey[600],
                                            ),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 8),
                                          Row(
                                            children: [
                                              Icon(
                                                Icons.person,
                                                size: 16,
                                                color: Colors.grey[600],
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                notification.fromUserName ??
                                                    notification.adminName,
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.grey[600],
                                                ),
                                              ),
                                              const SizedBox(width: 16),
                                              Icon(
                                                Icons.access_time,
                                                size: 16,
                                                color: Colors.grey[600],
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                _formatTime(
                                                  notification.timestamp,
                                                ),
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.grey[600],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),

                                    // Unread indicator
                                    if (!isRead)
                                      Container(
                                        width: 8,
                                        height: 8,
                                        decoration: const BoxDecoration(
                                          color: Colors.blue,
                                          shape: BoxShape.circle,
                                        ),
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
                );
              },
            ),
    );
  }
}
