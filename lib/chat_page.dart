import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'models/message_model.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final dbRef = FirebaseDatabase.instance.ref();

  String? _conversationId;
  User? _currentUser;
  String _userName = '';
  String _userEmail = '';
  bool _isLoading = true;

  // 🔴 Lưu số tin nhắn chưa đọc và IDs của chúng
  int _initialUnreadCount = 0;
  final Set<String> _unreadMessageIds = {};
  bool _hasMarkedUnread = false; // Flag để biết đã đánh dấu chưa

  @override
  void initState() {
    super.initState();
    _initializeChat();
    // _setupNotificationListener();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // void _setupNotificationListener() {
  //   // Lắng nghe tin nhắn mới từ admin
  //   if (_conversationId != null && _currentUser != null) {
  //     dbRef
  //         .child('messages')
  //         .orderByChild('conversationId')
  //         .equalTo(_conversationId)
  //         .onChildAdded
  //         .listen((event) {
  //       if (event.snapshot.value != null) {
  //         final messageData = event.snapshot.value as Map;
  //         final senderId = messageData['senderId']?.toString() ?? '';
  //         final senderRole = messageData['senderRole']?.toString() ?? '';

  //         // Chỉ hiển thị notification cho tin nhắn từ admin
  //         if (senderId != _currentUser!.uid && senderRole == 'admin') {
  //           _showInAppNotification(
  //             senderName: messageData['senderName']?.toString() ?? 'Admin',
  //             content: messageData['content']?.toString() ?? '',
  //             senderId: senderId,
  //           );
  //         }
  //       }
  //     });
  //   }
  // }

  // void _showInAppNotification({
  //   required String senderName,
  //   required String content,
  //   required String senderId,
  // }) {
  //   if (!mounted) return;

  //   // Hiển thị notification overlay
  //   ChatNotificationOverlay.show(
  //     context: context,
  //     conversationId: _conversationId ?? '',
  //     senderName: senderName,
  //     content: content,
  //     senderId: senderId,
  //     onTap: () {
  //       // Navigate to chat page hoặc scroll to bottom
  //       _scrollToBottom();
  //     },
  //   );
  // }

  Future<void> _initializeChat() async {
    try {
      _currentUser = FirebaseAuth.instance.currentUser;
      if (_currentUser == null) {
        if (mounted) {
          Navigator.pop(context);
        }
        return;
      }

      // Lấy thông tin user
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

      // Tìm conversation của user này
      String? existingConvId;
      final allConversationsSnapshot = await dbRef.child('conversations').get();

      if (allConversationsSnapshot.exists &&
          allConversationsSnapshot.value != null) {
        final allConversations = allConversationsSnapshot.value as Map;
        for (var entry in allConversations.entries) {
          final conv = entry.value as Map;
          if (conv['userId'] == _currentUser!.uid) {
            existingConvId = entry.key;
            break;
          }
        }
      }

      if (existingConvId != null) {
        _conversationId = existingConvId;

        // Xóa tin nhắn cũ hơn 24h
        await _deleteOldMessages();

        // 🔴 Lưu số tin nhắn chưa đọc TRƯỚC KHI reset
        final convSnapshot = await dbRef
            .child('conversations/$_conversationId')
            .get();
        if (convSnapshot.exists && convSnapshot.value != null) {
          final convData = convSnapshot.value as Map;
          final unreadCount = convData['userUnreadCount'] ?? 0;
          _initialUnreadCount = (unreadCount is int)
              ? unreadCount
              : (unreadCount is double)
              ? unreadCount.toInt()
              : 0;
        }

        // Reset user unread count
        await dbRef
            .child('conversations/$_conversationId/userUnreadCount')
            .set(0);
      } else {
        // Tạo conversation mới
        final newConvRef = dbRef.child('conversations').push();
        _conversationId = newConvRef.key;

        await newConvRef.set({
          'userId': _currentUser!.uid,
          'userName': _userName,
          'userEmail': _userEmail,
          'lastMessage': 'Bắt đầu cuộc trò chuyện',
          'lastMessageTime': ServerValue.timestamp,
          'lastSenderId': _currentUser!.uid,
          'unreadCount': 0,
          'userUnreadCount': 0,
          'createdAt': ServerValue.timestamp,
        });
      }

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        // Scroll xuống khi vào màn hình lần đầu
        _scrollToBottom(animated: false);
        // Setup notification listener sau khi có conversationId
        // _setupNotificationListener();
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

  /// Xóa tin nhắn cũ hơn 24 giờ
  Future<void> _deleteOldMessages() async {
    if (_conversationId == null) return;

    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      final twentyFourHoursAgo =
          now - (24 * 60 * 60 * 1000); // 24h = 86400000ms

      // Lấy tất cả tin nhắn của conversation này
      final messagesSnapshot = await dbRef
          .child('messages')
          .orderByChild('conversationId')
          .equalTo(_conversationId)
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
            await dbRef.child('conversations/$_conversationId').update({
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
            await dbRef.child('conversations/$_conversationId').update({
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

  Future<void> _deleteMessage(String messageId) async {
    try {
      // Xóa tin nhắn thật sự khỏi Firebase
      await dbRef.child('messages').child(messageId).remove();

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
          .child('messages')
          .orderByChild('conversationId')
          .equalTo(_conversationId)
          .get();

      if (!messagesSnapshot.exists) {
        // Nếu không còn tin nhắn nào, xóa conversation
        await dbRef.child('conversations').child(_conversationId!).remove();
        return;
      }

      final messagesMap = messagesSnapshot.value as Map?;
      if (messagesMap == null || messagesMap.isEmpty) {
        // Nếu không còn tin nhắn nào, xóa conversation
        await dbRef.child('conversations').child(_conversationId!).remove();
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
        await dbRef.child('conversations').child(_conversationId!).update({
          'lastMessage': lastMessage!.content,
          'lastMessageTime': lastMessage!.timestamp,
          'lastSenderId': lastMessage!.senderId,
          'userUnreadCount': 0,
          'adminUnreadCount': 0,
        });
      }
    } catch (e) {
      print('❌ Lỗi cập nhật conversation: $e');
    }
  }

  Future<void> _deleteAllMessages() async {
    try {
      final messagesSnapshot = await dbRef
          .child('messages')
          .orderByChild('conversationId')
          .equalTo(_conversationId)
          .get();

      if (messagesSnapshot.exists) {
        final messages = messagesSnapshot.value as Map;
        for (final key in messages.keys) {
          await dbRef.child('messages').child(key).remove();
        }
      }

      // Cập nhật conversation
      await dbRef.child('conversations/$_conversationId').update({
        'lastMessage': '',
        'lastMessageTime': 0,
        'lastSenderId': '',
        'unreadCount': 0,
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
      final messageRef = dbRef.child('messages').push();
      final timestamp = DateTime.now().millisecondsSinceEpoch;

      await messageRef.set({
        'conversationId': _conversationId,
        'senderId': _currentUser!.uid,
        'senderName': _userName,
        'senderRole': 'user',
        'content': content,
        'timestamp': timestamp,
        'isRead': false,
      });

      // Cập nhật conversation
      await dbRef.child('conversations/$_conversationId').update({
        'lastMessage': content,
        'lastMessageTime': timestamp,
        'lastSenderId': _currentUser!.uid,
        'unreadCount': ServerValue.increment(1), // Tăng unread cho admin
        'userUnreadCount': 0, // Reset về 0 cho user gửi
      });

      // Xóa tin nhắn cũ hơn 24h sau khi gửi
      _deleteOldMessages();

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
      // Lấy tất cả tin nhắn chưa đọc của user
      final messagesSnapshot = await dbRef
          .child('messages')
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

          // Chỉ đánh dấu tin nhắn từ admin và chưa đọc
          if (senderId != _currentUser!.uid && !isRead) {
            updates['messages/${entry.key}/isRead'] = true;
          }
        }

        if (updates.isNotEmpty) {
          await dbRef.update(updates);
        }
      }

      // Reset user unread count
      await dbRef
          .child('conversations/$_conversationId/userUnreadCount')
          .set(0);
    } catch (e) {
      print('❌ Lỗi đánh dấu đã đọc: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chat với Admin'),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blue.shade600, Colors.purple.shade600],
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
                        .child('messages')
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

                      // 🔴 Đánh dấu X tin nhắn cuối từ Admin là "chưa đọc"
                      if (_initialUnreadCount > 0 && !_hasMarkedUnread) {
                        // Lấy X tin nhắn cuối từ Admin (không phải mình)
                        final adminMessages = messages
                            .where((m) => m.senderId != _currentUser!.uid)
                            .toList();

                        if (adminMessages.isNotEmpty) {
                          final unreadMessages =
                              adminMessages.length > _initialUnreadCount
                              ? adminMessages.sublist(
                                  adminMessages.length - _initialUnreadCount,
                                )
                              : adminMessages;

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
        await dbRef.child('messages').child(messageId).update({
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
                CircleAvatar(
                  radius: 16,
                  backgroundColor: Colors.purple.shade100,
                  child: Icon(
                    Icons.admin_panel_settings,
                    size: 18,
                    color: Colors.purple.shade700,
                  ),
                ),
                // 🔴 Dấu chấm đỏ cho tin nhắn mới từ Admin
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
                          colors: [Colors.blue.shade400, Colors.blue.shade600],
                        )
                      : null,
                  color: isMe ? null : Colors.grey.shade200,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(16),
                    topRight: const Radius.circular(16),
                    bottomLeft: Radius.circular(isMe ? 16 : 0),
                    bottomRight: Radius.circular(isMe ? 0 : 16),
                  ),
                  // 🔴 Border đỏ cho tin nhắn mới từ Admin
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
                          color: Colors.purple.shade700,
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
                    Text(
                      _formatTime(message.timestamp),
                      style: TextStyle(
                        fontSize: 10,
                        color: isMe ? Colors.white70 : Colors.grey.shade600,
                      ),
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
                hintText: 'Nhập tin nhắn...',
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
                colors: [Colors.blue.shade400, Colors.purple.shade400],
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
