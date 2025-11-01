import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'user_chat_page.dart';

class MyChatsPage extends StatefulWidget {
  const MyChatsPage({super.key});

  @override
  State<MyChatsPage> createState() => _MyChatsPageState();
}

class _MyChatsPageState extends State<MyChatsPage> {
  final dbRef = FirebaseDatabase.instance.ref();
  final currentUser = FirebaseAuth.instance.currentUser!;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tin nhắn của tôi'),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blue.shade600, Colors.cyan.shade600],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: StreamBuilder(
        stream: dbRef.child('user_conversations').onValue,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data?.snapshot.value == null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.chat_bubble_outline,
                    size: 80,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Chưa có tin nhắn nào',
                    style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Nhắn tin với chủ trọ khi xem chi tiết phòng',
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
                  ),
                ],
              ),
            );
          }

          final conversationsMap = snapshot.data!.snapshot.value as Map;
          final myConversations = <MapEntry>[];

          // Lọc conversations của user hiện tại
          conversationsMap.forEach((key, value) {
            if (value == null) return;

            final conv = value as Map;
            final user1Id = conv['user1Id']?.toString() ?? '';
            final user2Id = conv['user2Id']?.toString() ?? '';

            // Chỉ lấy conversations mà user hiện tại tham gia
            if (user1Id == currentUser.uid || user2Id == currentUser.uid) {
              myConversations.add(MapEntry(key, conv));
            }
          });

          if (myConversations.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.chat_bubble_outline,
                    size: 80,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Chưa có tin nhắn nào',
                    style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
                  ),
                ],
              ),
            );
          }

          // Sắp xếp theo thời gian tin nhắn cuối
          myConversations.sort((a, b) {
            final aTime = _parseTime(a.value['lastMessageTime']);
            final bTime = _parseTime(b.value['lastMessageTime']);
            return bTime.compareTo(aTime);
          });

          return ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: myConversations.length,
            itemBuilder: (context, index) {
              final entry = myConversations[index];
              return _buildConversationCard(entry.key, entry.value);
            },
          );
        },
      ),
    );
  }

  int _parseTime(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.toInt();
    return 0;
  }

  Widget _buildConversationCard(String conversationId, Map conversation) {
    // Xác định ai là người chat với mình
    final user1Id = conversation['user1Id']?.toString() ?? '';
    final user2Id = conversation['user2Id']?.toString() ?? '';
    final isUser1 = currentUser.uid == user1Id;

    final otherUserId = isUser1 ? user2Id : user1Id;
    final otherUserName = isUser1
        ? (conversation['user2Name']?.toString() ?? 'User')
        : (conversation['user1Name']?.toString() ?? 'User');
    final otherUserEmail = isUser1
        ? (conversation['user2Email']?.toString() ?? '')
        : (conversation['user1Email']?.toString() ?? '');

    final roomTitle = conversation['roomTitle']?.toString() ?? '';
    final lastMessage = conversation['lastMessage']?.toString() ?? '';
    final lastMessageTime = _parseTime(conversation['lastMessageTime']);
    final lastSenderId = conversation['lastSenderId']?.toString() ?? '';

    // Unread count cho user hiện tại
    final myUnreadCount = isUser1
        ? _parseInt(conversation['user1UnreadCount'])
        : _parseInt(conversation['user2UnreadCount']);

    // 🔥 CHỈ hiển thị unread nếu tin nhắn cuối KHÔNG phải do user hiện tại gửi
    final hasUnread = myUnreadCount > 0 && lastSenderId != currentUser.uid;
    final lastMessageTime2 = DateTime.fromMillisecondsSinceEpoch(
      lastMessageTime,
    );

    return Dismissible(
      key: Key(conversationId),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.delete, color: Colors.white, size: 30),
            SizedBox(height: 4),
            Text(
              'Xóa',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
      confirmDismiss: (direction) async {
        return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Xóa cuộc trò chuyện'),
            content: Text(
              'Bạn có chắc chắn muốn xóa cuộc trò chuyện với $otherUserName?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Hủy'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('Xóa'),
              ),
            ],
          ),
        );
      },
      onDismissed: (direction) async {
        await _deleteConversation(conversationId);
      },
      child: Card(
        elevation: hasUnread ? 8 : 2,
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        // 🔴 Viền đỏ rõ ràng cho card có tin nhắn mới
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: hasUnread
              ? BorderSide(color: Colors.red.shade400, width: 2)
              : BorderSide.none,
        ),
        child: InkWell(
          onTap: () async {
            // Reset unread count khi vào đọc tin nhắn
            await _resetUnreadCount(conversationId, isUser1);

            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => UserChatPage(
                  receiverId: otherUserId,
                  receiverName: otherUserName,
                  receiverEmail: otherUserEmail,
                  roomTitle: roomTitle,
                ),
              ),
            );
          },
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: hasUnread
                  ? LinearGradient(
                      colors: [Colors.cyan.shade50, Colors.blue.shade50],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : null,
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  // Avatar với dấu chấm đỏ nổi bật
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          // 🔴 Viền đỏ nếu có tin nhắn mới
                          border: hasUnread
                              ? Border.all(color: Colors.red, width: 3)
                              : null,
                          boxShadow: hasUnread
                              ? [
                                  BoxShadow(
                                    color: Colors.red.withOpacity(0.3),
                                    blurRadius: 8,
                                    spreadRadius: 2,
                                  ),
                                ]
                              : null,
                        ),
                        child: CircleAvatar(
                          radius: 28,
                          backgroundColor: Colors.cyan.shade100,
                          child: Text(
                            otherUserName.isNotEmpty
                                ? otherUserName[0].toUpperCase()
                                : 'U',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.cyan.shade700,
                            ),
                          ),
                        ),
                      ),
                      // 🔴 Dấu chấm đỏ TO và nổi bật
                      if (hasUnread)
                        Positioned(
                          right: -4,
                          top: -4,
                          child: Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 3),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.red.withOpacity(0.6),
                                  blurRadius: 8,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            // 🔥 Hiển thị số tin nhắn chưa đọc
                            child: Center(
                              child: Text(
                                myUnreadCount > 9 ? '9+' : '$myUnreadCount',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 12),

                  // Thông tin
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                otherUserName,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: hasUnread
                                      ? FontWeight.bold
                                      : FontWeight.w600,
                                  color: Colors.black87,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(
                              _formatTime(lastMessageTime2),
                              style: TextStyle(
                                fontSize: 12,
                                color: hasUnread
                                    ? Colors.cyan.shade700
                                    : Colors.grey.shade600,
                                fontWeight: hasUnread
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        if (roomTitle.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.cyan.shade100,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              roomTitle,
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.cyan.shade800,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            if (lastSenderId == currentUser.uid)
                              Icon(
                                Icons.done_all,
                                size: 14,
                                color: Colors.grey.shade600,
                              ),
                            if (lastSenderId == currentUser.uid)
                              const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                lastMessage,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: hasUnread
                                      ? Colors.black87
                                      : Colors.grey.shade700,
                                  fontWeight: hasUnread
                                      ? FontWeight.w600
                                      : FontWeight.normal,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Mũi tên
                  Icon(
                    Icons.chevron_right,
                    color: hasUnread
                        ? Colors.cyan.shade700
                        : Colors.grey.shade400,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  int _parseInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.toInt();
    return 0;
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inMinutes < 1) {
      return 'Vừa xong';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes} phút trước';
    } else if (difference.inDays < 1) {
      return '${difference.inHours} giờ trước';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} ngày trước';
    } else {
      return '${time.day}/${time.month}/${time.year}';
    }
  }

  Future<void> _resetUnreadCount(String conversationId, bool isUser1) async {
    try {
      final myUnreadField = isUser1 ? 'user1UnreadCount' : 'user2UnreadCount';
      await dbRef
          .child('user_conversations/$conversationId/$myUnreadField')
          .set(0);
    } catch (e) {
      print('❌ Lỗi reset unread count: $e');
    }
  }

  Future<void> _deleteConversation(String conversationId) async {
    try {
      // Xóa tất cả tin nhắn trong conversation
      final messagesSnapshot = await dbRef
          .child('user_messages')
          .orderByChild('conversationId')
          .equalTo(conversationId)
          .get();

      if (messagesSnapshot.exists) {
        final messagesMap = messagesSnapshot.value as Map?;
        if (messagesMap != null) {
          for (String messageId in messagesMap.keys) {
            await dbRef.child('user_messages').child(messageId).remove();
          }
        }
      }

      // Xóa conversation
      await dbRef.child('user_conversations').child(conversationId).remove();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã xóa cuộc trò chuyện'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('❌ Lỗi xóa cuộc trò chuyện: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi xóa cuộc trò chuyện: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
