import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import '../models/message_model.dart';
import '../models/conversation_model.dart';

class AdminChatDetailPage extends StatefulWidget {
  final Conversation conversation;

  const AdminChatDetailPage({super.key, required this.conversation});

  @override
  State<AdminChatDetailPage> createState() => _AdminChatDetailPageState();
}

class _AdminChatDetailPageState extends State<AdminChatDetailPage> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final dbRef = FirebaseDatabase.instance.ref();

  User? _currentUser;
  String _adminName = 'Admin';

  @override
  void initState() {
    super.initState();
    _initializeChat();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _initializeChat() async {
    try {
      _currentUser = FirebaseAuth.instance.currentUser;
      if (_currentUser == null) {
        if (mounted) {
          Navigator.pop(context);
        }
        return;
      }

      // Lấy thông tin admin
      final userSnapshot = await dbRef
          .child('users/${_currentUser!.uid}')
          .get();
      if (userSnapshot.exists && userSnapshot.value != null) {
        final userData = userSnapshot.value as Map;
        _adminName =
            userData['name']?.toString() ??
            userData['fullName']?.toString() ??
            'Admin';
      }

      // Xóa tin nhắn cũ hơn 24h
      await _deleteOldMessages();

      // Reset admin unread count
      await dbRef
          .child('conversations/${widget.conversation.id}/unreadCount')
          .set(0);

      if (mounted) {
        setState(() {});
      }
      _scrollToBottom();
    } catch (e) {
      print('❌ Lỗi khởi tạo chat: $e');
    }
  }

  /// Xóa tin nhắn cũ hơn 24 giờ
  Future<void> _deleteOldMessages() async {
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      final twentyFourHoursAgo =
          now - (24 * 60 * 60 * 1000); // 24h = 86400000ms

      // Lấy tất cả tin nhắn của conversation này
      final messagesSnapshot = await dbRef
          .child('messages')
          .orderByChild('conversationId')
          .equalTo(widget.conversation.id)
          .get();

      if (messagesSnapshot.exists && messagesSnapshot.value != null) {
        final messages = messagesSnapshot.value as Map;
        final messagesToDelete = <String>[];

        for (var entry in messages.entries) {
          final messageData = entry.value as Map;
          final timestamp = messageData['timestamp'] as int? ?? 0;

          // Đánh dấu tin nhắn cũ hơn 24h để xóa
          if (timestamp < twentyFourHoursAgo) {
            messagesToDelete.add(entry.key);
          }
        }

        // Xóa các tin nhắn cũ
        if (messagesToDelete.isNotEmpty) {
          for (var messageId in messagesToDelete) {
            await dbRef.child('messages/$messageId').remove();
          }

          // Cập nhật lastMessage nếu cần
          final remainingMessages = messages.entries
              .where((e) => !messagesToDelete.contains(e.key))
              .toList();

          if (remainingMessages.isEmpty) {
            // Không còn tin nhắn nào, reset conversation
            await dbRef
                .child('conversations/${widget.conversation.id}')
                .update({
                  'lastMessage': 'Đã bắt đầu cuộc trò chuyện mới',
                  'lastMessageTime': now,
                });
          } else {
            // Cập nhật lastMessage với tin nhắn mới nhất còn lại
            remainingMessages.sort((a, b) {
              final aTime = (a.value as Map)['timestamp'] as int? ?? 0;
              final bTime = (b.value as Map)['timestamp'] as int? ?? 0;
              return bTime.compareTo(aTime); // Mới nhất lên đầu
            });
            final latestMessage = remainingMessages.first.value as Map;
            await dbRef
                .child('conversations/${widget.conversation.id}')
                .update({
                  'lastMessage': latestMessage['content'] ?? '',
                  'lastMessageTime': latestMessage['timestamp'] ?? now,
                });
          }
        }
      }
    } catch (e) {
      print('❌ Lỗi xóa tin nhắn cũ: $e');
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      Future.delayed(const Duration(milliseconds: 300), () {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty || _currentUser == null) {
      return;
    }

    final content = _messageController.text.trim();
    _messageController.clear();

    try {
      final messageRef = dbRef.child('messages').push();
      final timestamp = DateTime.now().millisecondsSinceEpoch;

      await messageRef.set({
        'conversationId': widget.conversation.id,
        'senderId': _currentUser!.uid,
        'senderName': _adminName,
        'senderRole': 'admin',
        'content': content,
        'timestamp': timestamp,
        'isRead': false,
      });

      // Cập nhật conversation
      await dbRef.child('conversations/${widget.conversation.id}').update({
        'lastMessage': content,
        'lastMessageTime': timestamp,
        'lastSenderId': _currentUser!.uid,
        'userUnreadCount': ServerValue.increment(1), // Tăng unread cho user
        'unreadCount': 0, // Reset về 0 cho admin gửi
      });

      // Xóa tin nhắn cũ hơn 24h sau khi gửi
      _deleteOldMessages();

      _scrollToBottom();
    } catch (e) {
      print('❌ Lỗi gửi tin nhắn: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi gửi tin nhắn: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _markMessagesAsRead() async {
    try {
      // Lấy tất cả tin nhắn chưa đọc của admin
      final messagesSnapshot = await dbRef
          .child('messages')
          .orderByChild('conversationId')
          .equalTo(widget.conversation.id)
          .get();

      if (messagesSnapshot.exists && messagesSnapshot.value != null) {
        final messages = messagesSnapshot.value as Map;
        final updates = <String, dynamic>{};

        for (var entry in messages.entries) {
          final messageData = entry.value as Map;
          final senderId = messageData['senderId']?.toString() ?? '';
          final isRead = messageData['isRead'] ?? false;

          // Chỉ đánh dấu tin nhắn từ user và chưa đọc
          if (senderId != _currentUser!.uid && !isRead) {
            updates['messages/${entry.key}/isRead'] = true;
          }
        }

        if (updates.isNotEmpty) {
          await dbRef.update(updates);
        }
      }

      // Reset admin unread count
      await dbRef
          .child('conversations/${widget.conversation.id}/unreadCount')
          .set(0);
    } catch (e) {
      print('❌ Lỗi đánh dấu đã đọc: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.conversation.userName,
              style: const TextStyle(fontSize: 18),
            ),
            Text(
              widget.conversation.userEmail,
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blue.shade600, Colors.purple.shade600],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder(
              stream: dbRef
                  .child('messages')
                  .orderByChild('conversationId')
                  .equalTo(widget.conversation.id)
                  .onValue,
              builder: (context, snapshot) {
                if (!snapshot.hasData ||
                    snapshot.data?.snapshot.value == null) {
                  return const Center(child: Text('Chưa có tin nhắn nào'));
                }

                final messagesMap = snapshot.data!.snapshot.value as Map;
                final messages = <Message>[];

                messagesMap.forEach((key, value) {
                  if (value != null) {
                    messages.add(Message.fromMap(key, value as Map));
                  }
                });

                messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));

                // Đánh dấu tin nhắn đã đọc
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _markMessagesAsRead();
                });

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    final isMe = message.senderId == _currentUser!.uid;

                    return _buildMessageBubble(message, isMe);
                  },
                );
              },
            ),
          ),
          _buildMessageInput(),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(Message message, bool isMe) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: isMe
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        children: [
          if (!isMe)
            CircleAvatar(
              radius: 16,
              backgroundColor: Colors.blue.shade100,
              child: Icon(Icons.person, size: 18, color: Colors.blue.shade700),
            ),
          const SizedBox(width: 8),
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                gradient: isMe
                    ? LinearGradient(
                        colors: [
                          Colors.purple.shade400,
                          Colors.purple.shade600,
                        ],
                      )
                    : null,
                color: isMe ? null : Colors.grey.shade200,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isMe ? 16 : 0),
                  bottomRight: Radius.circular(isMe ? 0 : 16),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!isMe)
                    Text(
                      message.senderName,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade700,
                      ),
                    ),
                  if (!isMe) const SizedBox(height: 4),
                  Text(
                    message.content,
                    style: TextStyle(
                      color: isMe ? Colors.white : Colors.black87,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _formatTime(message.timestamp),
                        style: TextStyle(
                          fontSize: 10,
                          color: isMe ? Colors.white70 : Colors.grey.shade600,
                        ),
                      ),
                      if (isMe) ...[
                        const SizedBox(width: 4),
                        Icon(
                          message.isRead ? Icons.done_all : Icons.done,
                          size: 14,
                          color: message.isRead
                              ? Colors.lightBlue
                              : Colors.white70,
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          if (isMe)
            CircleAvatar(
              radius: 16,
              backgroundColor: Colors.purple.shade100,
              child: Icon(
                Icons.admin_panel_settings,
                size: 18,
                color: Colors.purple.shade700,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              decoration: InputDecoration(
                hintText: 'Trả lời tin nhắn...',
                filled: true,
                fillColor: Colors.grey.shade100,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
              ),
              maxLines: null,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.purple.shade400, Colors.blue.shade400],
              ),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: const Icon(Icons.send, color: Colors.white),
              onPressed: _sendMessage,
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(int timestamp) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final now = DateTime.now();

    if (date.year == now.year &&
        date.month == now.month &&
        date.day == now.day) {
      return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } else {
      return '${date.day}/${date.month} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    }
  }
}
