import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'models/message_model.dart';

class UserChatPage extends StatefulWidget {
  final String receiverId;
  final String receiverName;
  final String receiverEmail;
  final String roomTitle; // Tên phòng đang chat về

  const UserChatPage({
    super.key,
    required this.receiverId,
    required this.receiverName,
    required this.receiverEmail,
    required this.roomTitle,
  });

  @override
  State<UserChatPage> createState() => _UserChatPageState();
}

class _UserChatPageState extends State<UserChatPage>
    with SingleTickerProviderStateMixin {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final dbRef = FirebaseDatabase.instance.ref();

  String? _conversationId;
  User? _currentUser;
  String _userName = '';
  String _userEmail = '';
  bool _isLoading = true;

  late AnimationController _sendButtonAnimationController;

  // 🔴 Lưu số tin nhắn chưa đọc và IDs của chúng
  int _initialUnreadCount = 0;
  final Set<String> _unreadMessageIds = {};
  bool _hasMarkedUnread = false; // Flag để biết đã đánh dấu chưa

  @override
  void initState() {
    super.initState();
    _sendButtonAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _initializeChat();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _sendButtonAnimationController.dispose();
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

      // Lấy thông tin user hiện tại
      final userSnapshot = await dbRef
          .child('users/${_currentUser!.uid}')
          .get();
      if (userSnapshot.exists && userSnapshot.value != null) {
        final userData = userSnapshot.value as Map;
        _userName =
            userData['name']?.toString() ??
            userData['fullName']?.toString() ??
            'User';
        _userEmail = userData['email']?.toString() ?? _currentUser!.email ?? '';
      } else {
        _userName = _currentUser!.displayName ?? 'User';
        _userEmail = _currentUser!.email ?? '';
      }

      // Tìm conversation giữa 2 users (sắp xếp ID để đảm bảo unique)
      final conversationKey = _generateConversationKey(
        _currentUser!.uid,
        widget.receiverId,
      );

      final conversationSnapshot = await dbRef
          .child('user_conversations/$conversationKey')
          .get();

      if (conversationSnapshot.exists) {
        _conversationId = conversationKey;

        // 🔴 Lưu số tin nhắn chưa đọc TRƯỚC KHI reset
        final isUser1 = _currentUser!.uid == conversationKey.split('_')[0];
        final myUnreadField = isUser1 ? 'user1UnreadCount' : 'user2UnreadCount';

        final conversationData = conversationSnapshot.value as Map;
        final unreadCount = conversationData[myUnreadField] ?? 0;
        _initialUnreadCount = (unreadCount is int)
            ? unreadCount
            : (unreadCount is double)
            ? unreadCount.toInt()
            : 0;

        // Reset unread count cho user hiện tại
        await dbRef
            .child('user_conversations/$conversationKey/$myUnreadField')
            .set(0);
      } else {
        // Tạo conversation mới
        _conversationId = conversationKey;

        await dbRef.child('user_conversations/$conversationKey').set({
          'user1Id': _currentUser!.uid,
          'user1Name': _userName,
          'user1Email': _userEmail,
          'user2Id': widget.receiverId,
          'user2Name': widget.receiverName,
          'user2Email': widget.receiverEmail,
          'roomTitle': widget.roomTitle,
          'lastMessage': 'Bắt đầu cuộc trò chuyện',
          'lastMessageTime': ServerValue.timestamp,
          'lastSenderId': _currentUser!.uid,
          'user1UnreadCount': 0,
          'user2UnreadCount': 0,
          'createdAt': ServerValue.timestamp,
        });
      }

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        // Scroll xuống khi vào màn hình lần đầu
        _scrollToBottom(animated: false);
      }
    } catch (e) {
      print('❌ Lỗi khởi tạo chat: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi khởi tạo chat: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  String _generateConversationKey(String userId1, String userId2) {
    // Sắp xếp để đảm bảo key luôn giống nhau bất kể thứ tự
    final ids = [userId1, userId2]..sort();
    return '${ids[0]}_${ids[1]}';
  }

  void _scrollToBottom({bool animated = true}) {
    if (!_scrollController.hasClients) return;

    // 🔥 Tăng delay để đảm bảo ListView đã render xong
    Future.delayed(const Duration(milliseconds: 500), () {
      if (!mounted || !_scrollController.hasClients) return;

      try {
        if (animated) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOutCubic,
          );
        } else {
          // Jump ngay lập tức (dùng khi vào màn hình lần đầu)
          _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
        }
      } catch (e) {
        print('❌ Lỗi scroll: $e');
      }
    });
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty || _conversationId == null) {
      return;
    }

    final content = _messageController.text.trim();
    _messageController.clear();

    try {
      final messageRef = dbRef.child('user_messages').push();
      final timestamp = DateTime.now().millisecondsSinceEpoch;

      await messageRef.set({
        'conversationId': _conversationId,
        'senderId': _currentUser!.uid,
        'senderName': _userName,
        'content': content,
        'timestamp': timestamp,
        'isRead': false,
      });

      // 🔥 FIX: Phải lấy user1Id/user2Id từ Firebase, không phải từ conversationId!
      final convSnapshot = await dbRef
          .child('user_conversations/$_conversationId')
          .get();

      if (convSnapshot.exists && convSnapshot.value != null) {
        final convData = convSnapshot.value as Map;
        final user1Id = convData['user1Id']?.toString() ?? '';

        final isUser1 = _currentUser!.uid == user1Id;
        final myUnreadField = isUser1 ? 'user1UnreadCount' : 'user2UnreadCount';
        final otherUserUnreadField = isUser1
            ? 'user2UnreadCount'
            : 'user1UnreadCount';

        await dbRef.child('user_conversations/$_conversationId').update({
          'lastMessage': content,
          'lastMessageTime': timestamp,
          'lastSenderId': _currentUser!.uid,
          // 🔥 Tăng unread count cho người nhận
          otherUserUnreadField: ServerValue.increment(1),
          // 🔥 Reset unread count của người gửi về 0
          myUnreadField: 0,
        });
      }

      // Scroll xuống sau khi gửi tin nhắn (có animation)
      _scrollToBottom(animated: true);
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
    if (_conversationId == null) return;

    try {
      // Lấy tất cả tin nhắn chưa đọc
      final messagesSnapshot = await dbRef
          .child('user_messages')
          .orderByChild('conversationId')
          .equalTo(_conversationId)
          .get();

      if (messagesSnapshot.exists && messagesSnapshot.value != null) {
        final messages = messagesSnapshot.value as Map;
        final updates = <String, dynamic>{};

        for (var entry in messages.entries) {
          final messageData = entry.value as Map;
          final senderId = messageData['senderId']?.toString() ?? '';
          final isRead = messageData['isRead'] ?? false;

          // Chỉ đánh dấu tin nhắn từ người khác và chưa đọc
          if (senderId != _currentUser!.uid && !isRead) {
            updates['user_messages/${entry.key}/isRead'] = true;
          }
        }

        if (updates.isNotEmpty) {
          await dbRef.update(updates);
        }
      }

      // Reset unread count
      final myUnreadField = _currentUser!.uid == _conversationId!.split('_')[0]
          ? 'user1UnreadCount'
          : 'user2UnreadCount';
      await dbRef
          .child('user_conversations/$_conversationId/$myUnreadField')
          .set(0);
    } catch (e) {
      print('❌ Lỗi đánh dấu đã đọc: $e');
    }
  }

  Future<void> _deleteMessage(String messageId) async {
    try {
      // Xóa tin nhắn thật sự khỏi Firebase
      await dbRef.child('user_messages').child(messageId).remove();

      // Cập nhật lại conversation sau khi xóa tin nhắn
      await _updateConversationAfterDelete();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã xóa tin nhắn'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('❌ Lỗi xóa tin nhắn: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi xóa tin nhắn: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _updateConversationAfterDelete() async {
    try {
      if (_conversationId == null) return;

      // Lấy tất cả tin nhắn còn lại trong conversation
      final messagesSnapshot = await dbRef
          .child('user_messages')
          .orderByChild('conversationId')
          .equalTo(_conversationId)
          .get();

      if (!messagesSnapshot.exists) {
        // Nếu không còn tin nhắn nào, xóa conversation
        await dbRef
            .child('user_conversations')
            .child(_conversationId!)
            .remove();
        return;
      }

      final messagesMap = messagesSnapshot.value as Map?;
      if (messagesMap == null || messagesMap.isEmpty) {
        // Nếu không còn tin nhắn nào, xóa conversation
        await dbRef
            .child('user_conversations')
            .child(_conversationId!)
            .remove();
        return;
      }

      // Tìm tin nhắn cuối cùng
      Message? lastMessage;
      int latestTime = 0;

      messagesMap.forEach((key, value) {
        if (value != null) {
          final message = Message.fromMap(key, value as Map);
          if (message.timestamp > latestTime) {
            latestTime = message.timestamp;
            lastMessage = message;
          }
        }
      });

      // Cập nhật conversation với tin nhắn cuối cùng
      if (lastMessage != null) {
        await dbRef.child('user_conversations').child(_conversationId!).update({
          'lastMessage': lastMessage!.content,
          'lastMessageTime': lastMessage!.timestamp,
          'lastSenderId': lastMessage!.senderId,
          'user1UnreadCount': 0,
          'user2UnreadCount': 0,
        });
      }
    } catch (e) {
      print('❌ Lỗi cập nhật conversation: $e');
    }
  }

  Future<void> _deleteAllMessages() async {
    try {
      final messagesSnapshot = await dbRef
          .child('user_messages')
          .orderByChild('conversationId')
          .equalTo(_conversationId)
          .get();

      if (messagesSnapshot.exists) {
        final messages = messagesSnapshot.value as Map;
        for (final key in messages.keys) {
          await dbRef.child('user_messages').child(key).remove();
        }
      }

      // Cập nhật conversation
      await dbRef.child('user_conversations/$_conversationId').update({
        'lastMessage': '',
        'lastMessageTime': 0,
        'lastSenderId': '',
        'user1UnreadCount': 0,
        'user2UnreadCount': 0,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã xóa tất cả tin nhắn'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi xóa tin nhắn: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _showMessageOptionsDialog(
    String messageId,
    String currentContent,
  ) async {
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        contentPadding: const EdgeInsets.all(8),
        content: SizedBox(
          width: 100,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              InkWell(
                onTap: () => Navigator.pop(context, 'edit'),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 8,
                    horizontal: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.edit, color: Colors.blue.shade600, size: 16),
                      const SizedBox(width: 6),
                      const Text('Sửa', style: TextStyle(fontSize: 12)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 6),
              InkWell(
                onTap: () => Navigator.pop(context, 'delete'),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 8,
                    horizontal: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.delete, color: Colors.red.shade600, size: 16),
                      const SizedBox(width: 6),
                      const Text('Xóa', style: TextStyle(fontSize: 12)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (result == 'edit') {
      await _editMessage(messageId, currentContent);
    } else if (result == 'delete') {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Xóa tin nhắn'),
          content: const Text('Bạn có chắc chắn muốn xóa tin nhắn này?'),
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

      if (confirmed == true) {
        await _deleteMessage(messageId);
      }
    }
  }

  Future<void> _editMessage(String messageId, String currentContent) async {
    final controller = TextEditingController(text: currentContent);

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Chỉnh sửa tin nhắn'),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'Nhập nội dung mới...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Lưu'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty && result != currentContent) {
      try {
        await dbRef.child('user_messages').child(messageId).update({
          'content': result,
          'editedAt': DateTime.now().millisecondsSinceEpoch,
          'isEdited': true,
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Đã cập nhật tin nhắn'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Lỗi cập nhật tin nhắn: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.receiverName, style: const TextStyle(fontSize: 18)),
            Text(
              widget.roomTitle,
              style: const TextStyle(fontSize: 12),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blue.shade600, Colors.cyan.shade600],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) async {
              if (value == 'delete_all') {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Xóa tất cả tin nhắn'),
                    content: const Text(
                      'Bạn có chắc chắn muốn xóa tất cả tin nhắn? Hành động này không thể hoàn tác.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Hủy'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.red,
                        ),
                        child: const Text('Xóa'),
                      ),
                    ],
                  ),
                );
                if (confirmed == true) {
                  await _deleteAllMessages();
                }
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'delete_all',
                child: Row(
                  children: [
                    Icon(Icons.delete_sweep, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Xóa tất cả tin nhắn'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _conversationId == null
          ? const Center(child: Text('Không thể khởi tạo chat'))
          : Column(
              children: [
                Expanded(
                  child: StreamBuilder(
                    stream: dbRef
                        .child('user_messages')
                        .orderByChild('conversationId')
                        .equalTo(_conversationId)
                        .onValue,
                    builder: (context, snapshot) {
                      if (!snapshot.hasData ||
                          snapshot.data?.snapshot.value == null) {
                        return const Center(
                          child: Text('Chưa có tin nhắn nào'),
                        );
                      }

                      final messagesMap = snapshot.data!.snapshot.value as Map;
                      final messages = <Message>[];

                      messagesMap.forEach((key, value) {
                        if (value != null) {
                          messages.add(Message.fromMap(key, value as Map));
                        }
                      });

                      messages.sort(
                        (a, b) => a.timestamp.compareTo(b.timestamp),
                      );

                      // 🔴 Đánh dấu X tin nhắn cuối từ người khác là "chưa đọc"
                      if (_initialUnreadCount > 0 && !_hasMarkedUnread) {
                        // Lấy X tin nhắn cuối từ người gửi (không phải mình)
                        final otherMessages = messages
                            .where((m) => m.senderId != _currentUser!.uid)
                            .toList();

                        if (otherMessages.isNotEmpty) {
                          final unreadMessages =
                              otherMessages.length > _initialUnreadCount
                              ? otherMessages.sublist(
                                  otherMessages.length - _initialUnreadCount,
                                )
                              : otherMessages;

                          // Đánh dấu ngay lập tức
                          _unreadMessageIds.addAll(
                            unreadMessages.map((m) => m.id),
                          );
                          _hasMarkedUnread = true;
                        }
                      }

                      // Đánh dấu tin nhắn đã đọc
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        _markMessagesAsRead();
                      });

                      // 📜 Auto-scroll xuống tin nhắn mới nhất sau khi build xong
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        _scrollToBottom(animated: false);
                      });

                      return ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(16),
                        itemCount: messages.length,
                        itemBuilder: (context, index) {
                          final message = messages[index];
                          final isMe = message.senderId == _currentUser!.uid;
                          final isUnread = _unreadMessageIds.contains(
                            message.id,
                          );

                          return _buildMessageBubble(message, isMe, isUnread);
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

  Widget _buildMessageBubble(Message message, bool isMe, bool isUnread) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: isMe
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        children: [
          if (!isMe)
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.cyan.withOpacity(0.2),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: CircleAvatar(
                    radius: 16,
                    backgroundColor: Colors.cyan.shade100,
                    child: Text(
                      widget.receiverName.isNotEmpty
                          ? widget.receiverName[0].toUpperCase()
                          : 'U',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.cyan.shade700,
                      ),
                    ),
                  ),
                ),
                // 🔴 Dấu chấm đỏ cho tin nhắn mới
                if (isUnread)
                  Positioned(
                    right: -2,
                    top: -2,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.red.withOpacity(0.5),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          const SizedBox(width: 8),
          Flexible(
            child: GestureDetector(
              onLongPress: isMe
                  ? () => _showMessageOptionsDialog(message.id, message.content)
                  : null,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  gradient: isMe
                      ? LinearGradient(
                          colors: [Colors.blue.shade400, Colors.cyan.shade400],
                        )
                      : null,
                  color: isMe ? null : Colors.grey.shade200,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(16),
                    topRight: const Radius.circular(16),
                    bottomLeft: Radius.circular(isMe ? 16 : 0),
                    bottomRight: Radius.circular(isMe ? 0 : 16),
                  ),
                  // 🔴 Border đỏ cho tin nhắn mới (người khác gửi)
                  border: (!isMe && isUnread)
                      ? Border.all(color: Colors.red.shade400, width: 2)
                      : null,
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
                          color: Colors.cyan.shade700,
                        ),
                      ),
                    if (!isMe) const SizedBox(height: 4),
                    Text(
                      message.content,
                      style: TextStyle(
                        color: isMe ? Colors.white : Colors.black87,
                        fontSize: 15,
                        fontStyle: message.isEdited
                            ? FontStyle.italic
                            : FontStyle.normal,
                      ),
                    ),
                    if (message.isEdited)
                      const Text(
                        ' (đã chỉnh sửa)',
                        style: TextStyle(
                          fontSize: 10,
                          fontStyle: FontStyle.italic,
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
                                ? Colors.lightBlue.shade100
                                : Colors.white70,
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          if (isMe)
            CircleAvatar(
              radius: 16,
              backgroundColor: Colors.blue.shade100,
              child: Icon(Icons.person, size: 18, color: Colors.blue.shade700),
            ),
        ],
      ),
    );
  }

  Widget _buildMessageInput() {
    return AnimatedBuilder(
      animation: _sendButtonAnimationController,
      builder: (context, child) {
        final gradientValue = _sendButtonAnimationController.value;
        return Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.white,
                Color.lerp(
                  Colors.white,
                  Colors.blue.shade50,
                  gradientValue * 0.3,
                )!,
                Colors.white,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 8,
                offset: const Offset(0, -2),
              ),
              BoxShadow(
                color: Colors.blue.withOpacity(0.05 + (0.05 * gradientValue)),
                blurRadius: 15,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: child,
        );
      },
      child: Row(
        children: [
          Expanded(
            child: AnimatedBuilder(
              animation: _sendButtonAnimationController,
              builder: (context, child) {
                return Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.blue.withOpacity(
                          0.1 + (0.1 * _sendButtonAnimationController.value),
                        ),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: child,
                );
              },
              child: TextField(
                controller: _messageController,
                decoration: InputDecoration(
                  hintText: '💬 Nhập tin nhắn...',
                  hintStyle: TextStyle(color: Colors.grey.shade400),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide(
                      color: Colors.grey.shade200,
                      width: 1,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide(
                      color: Colors.grey.shade300,
                      width: 1.5,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide(
                      color: Colors.blue.shade400,
                      width: 2.5,
                    ),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 14,
                  ),
                  suffixIcon: Icon(
                    Icons.emoji_emotions_outlined,
                    color: Colors.grey.shade400,
                  ),
                ),
                maxLines: null,
                style: const TextStyle(fontSize: 15),
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
          ),
          const SizedBox(width: 8),
          AnimatedBuilder(
            animation: _sendButtonAnimationController,
            builder: (context, child) {
              final value = _sendButtonAnimationController.value;
              final scale = 1.0 + (0.2 * value);
              final glowIntensity = 0.3 + (0.4 * value);
              return Transform.scale(
                scale: scale,
                child: Transform.rotate(
                  angle: 0.1 * value - 0.05,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.blue.shade400, Colors.cyan.shade400],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.blue.withOpacity(glowIntensity),
                          blurRadius: 12 + (8 * value),
                          spreadRadius: 2 + (3 * value),
                          offset: const Offset(0, 2),
                        ),
                        BoxShadow(
                          color: Colors.cyan.withOpacity(glowIntensity * 0.6),
                          blurRadius: 20 + (10 * value),
                          spreadRadius: 3 + (5 * value),
                          offset: const Offset(0, 0),
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: _sendMessage,
                        customBorder: const CircleBorder(),
                        splashColor: Colors.white.withOpacity(0.3),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Icon(
                            Icons.send_rounded,
                            color: Colors.white,
                            size: 26,
                            shadows: [
                              Shadow(
                                color: Colors.black.withOpacity(0.4),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
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
