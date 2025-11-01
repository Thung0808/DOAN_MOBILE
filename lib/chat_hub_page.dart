import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'chat_page.dart';
import 'my_chats_page.dart';

class ChatHubPage extends StatefulWidget {
  const ChatHubPage({super.key});

  @override
  State<ChatHubPage> createState() => _ChatHubPageState();
}

class _ChatHubPageState extends State<ChatHubPage> {
  final user = FirebaseAuth.instance.currentUser!;
  final dbRef = FirebaseDatabase.instance.ref();
  int _adminUnreadCount = 0;
  int _userChatsUnreadCount = 0;

  @override
  void initState() {
    super.initState();
    _listenToUnreadMessages();
  }

  void _listenToUnreadMessages() {
    // Lắng nghe tin nhắn chưa đọc từ Admin - chỉ kiểm tra CÓ hay KHÔNG
    dbRef.child('conversations').onValue.listen((event) {
      if (!mounted) return;

      if (event.snapshot.exists && event.snapshot.value != null) {
        final conversations = event.snapshot.value as Map;
        bool hasAdminUnread = false;

        for (var conv in conversations.values) {
          if (conv == null) continue;
          if (conv['userId'] == user.uid) {
            // 🔥 Kiểm tra có tin nhắn chưa đọc KHÔNG phải do user hiện tại gửi
            final lastSenderId = conv['lastSenderId'];
            final userUnreadCount = conv['userUnreadCount'] ?? 0;
            final count = (userUnreadCount is int)
                ? userUnreadCount
                : (userUnreadCount is double)
                ? userUnreadCount.toInt()
                : 0;

            // Có tin nhắn chưa đọc VÀ không phải do user gửi
            if (count > 0 && lastSenderId != user.uid) {
              hasAdminUnread = true;
              break; // Chỉ cần biết CÓ tin nhắn chưa đọc
            }
          }
        }

        if (mounted) {
          setState(() {
            _adminUnreadCount = hasAdminUnread ? 1 : 0;
          });
        }
      }
    });

    // Lắng nghe tin nhắn chưa đọc từ user conversations - chỉ kiểm tra CÓ hay KHÔNG
    dbRef.child('user_conversations').onValue.listen((event) {
      if (!mounted) return;

      if (event.snapshot.exists && event.snapshot.value != null) {
        final conversations = event.snapshot.value as Map;
        bool hasUserUnread = false;

        for (var conv in conversations.values) {
          if (conv == null) continue;

          // 🔥 Kiểm tra có tin nhắn chưa đọc KHÔNG phải do user hiện tại gửi
          final lastSenderId = conv['lastSenderId'];

          // Lấy unread count của user hiện tại
          int myUnread = 0;
          if (conv['user1Id'] == user.uid) {
            final count = conv['user1UnreadCount'] ?? 0;
            myUnread = (count is int)
                ? count
                : (count is double)
                ? count.toInt()
                : 0;
          } else if (conv['user2Id'] == user.uid) {
            final count = conv['user2UnreadCount'] ?? 0;
            myUnread = (count is int)
                ? count
                : (count is double)
                ? count.toInt()
                : 0;
          }

          // Có tin nhắn chưa đọc VÀ không phải do user gửi
          if (myUnread > 0 && lastSenderId != user.uid) {
            hasUserUnread = true;
            break; // Chỉ cần biết CÓ tin nhắn chưa đọc
          }
        }

        if (mounted) {
          setState(() {
            _userChatsUnreadCount = hasUserUnread ? 1 : 0;
          });
        }
      }
    });
  }

  Future<void> _resetAdminUnreadCount() async {
    try {
      // Reset unread count cho tất cả conversations với admin
      final conversationsSnapshot = await dbRef.child('conversations').get();
      if (conversationsSnapshot.exists && conversationsSnapshot.value != null) {
        final conversations = conversationsSnapshot.value as Map;

        for (var entry in conversations.entries) {
          final conv = entry.value as Map;
          if (conv['userId'] == user.uid) {
            await dbRef
                .child('conversations/${entry.key}/userUnreadCount')
                .set(0);
          }
        }
      }
    } catch (e) {
      print('❌ Lỗi reset admin unread count: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalUnread = _adminUnreadCount + _userChatsUnreadCount;

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
                Icons.chat_bubble_rounded,
                color: Colors.lightGreen,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Tin nhắn',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    totalUnread > 0
                        ? '$totalUnread tin nhắn mới'
                        : 'Không có tin nhắn mới',
                    style: const TextStyle(fontSize: 12, color: Colors.white70),
                  ),
                ],
              ),
            ),
            if (totalUnread > 0)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.red.withOpacity(0.5),
                      blurRadius: 8,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Text(
                  '$totalUnread',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
          ],
        ),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blue.shade600, Colors.lightBlue.shade400],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        foregroundColor: Colors.white,
        elevation: 4,
        shadowColor: Colors.blue.withOpacity(0.5),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.blue.shade50, Colors.white],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // Stats Header - chỉ hiển thị khi có tin nhắn mới
              if (totalUnread > 0) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.blue.shade50, Colors.lightBlue.shade50],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue.shade100),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade100,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.forum_rounded,
                          color: Colors.blue.shade700,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Bạn có $totalUnread cuộc trò chuyện mới',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade900,
                            fontSize: 15,
                          ),
                        ),
                      ),
                      Icon(Icons.mark_chat_unread, color: Colors.red, size: 24),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // Chat Options with animations
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: const Duration(milliseconds: 600),
                curve: Curves.easeOutBack,
                builder: (context, value, child) {
                  return Transform.translate(
                    offset: Offset(0, 30 * (1 - value)),
                    child: Opacity(opacity: value, child: child),
                  );
                },
                child: _buildChatOption(
                  icon: Icons.support_agent_rounded,
                  title: 'Chat với Admin',
                  subtitle: 'Liên hệ với quản trị viên',
                  color: Colors.green,
                  unreadCount: _adminUnreadCount,
                  onTap: () async {
                    await _resetAdminUnreadCount();
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ChatPage()),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: const Duration(milliseconds: 800),
                curve: Curves.easeOutBack,
                builder: (context, value, child) {
                  return Transform.translate(
                    offset: Offset(0, 30 * (1 - value)),
                    child: Opacity(opacity: value, child: child),
                  );
                },
                child: _buildChatOption(
                  icon: Icons.people_rounded,
                  title: 'Liên hệ của tôi',
                  subtitle: 'Chat với chủ nhà và người thuê',
                  color: Colors.blue,
                  unreadCount: _userChatsUnreadCount,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const MyChatsPage()),
                    );
                  },
                ),
              ),

              const Spacer(),

              // Info footer with animation
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: const Duration(milliseconds: 1000),
                curve: Curves.easeOut,
                builder: (context, value, child) {
                  return Opacity(opacity: value, child: child);
                },
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.blue.shade50, Colors.lightBlue.shade50],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue.shade200, width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.blue.withOpacity(0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade100,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.tips_and_updates,
                          color: Colors.blue.shade700,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Tin nhắn giúp bạn liên lạc dễ dàng với Admin và các thành viên khác',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.blue[800],
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChatOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required int unreadCount,
    required VoidCallback onTap,
  }) {
    final hasUnread = unreadCount > 0;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: hasUnread
                ? LinearGradient(
                    colors: [Colors.white, Colors.red.shade50.withOpacity(0.3)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            color: hasUnread ? null : Colors.white,
            borderRadius: BorderRadius.circular(20),
            // 🔴 Viền đỏ nếu có tin nhắn mới
            border: hasUnread
                ? Border.all(color: Colors.red, width: 3)
                : Border.all(color: Colors.grey[200]!, width: 1.5),
            boxShadow: hasUnread
                ? [
                    BoxShadow(
                      color: Colors.red.withOpacity(0.3),
                      blurRadius: 15,
                      spreadRadius: 3,
                      offset: const Offset(0, 4),
                    ),
                    BoxShadow(
                      color: Colors.red.withOpacity(0.1),
                      blurRadius: 30,
                      spreadRadius: 5,
                      offset: const Offset(0, 0),
                    ),
                  ]
                : [
                    BoxShadow(
                      color: color.withOpacity(0.15),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
          ),
          child: Row(
            children: [
              // Icon with gradient background
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [color.withOpacity(0.2), color.withOpacity(0.1)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: color.withOpacity(0.3), width: 1),
                  boxShadow: [
                    BoxShadow(
                      color: color.withOpacity(0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 28,
                  shadows: [
                    Shadow(color: color.withOpacity(0.5), blurRadius: 4),
                  ],
                ),
              ),
              const SizedBox(width: 16),

              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (unreadCount > 0) ...[
                          const SizedBox(width: 8),
                          // 🔴 Badge đỏ nổi bật với animation
                          TweenAnimationBuilder<double>(
                            tween: Tween(begin: 0.0, end: 1.0),
                            duration: const Duration(milliseconds: 1000),
                            builder: (context, value, child) {
                              final pulse = value < 0.5
                                  ? value * 2
                                  : (1 - value) * 2;
                              final scale = 1.0 + (0.1 * pulse);
                              return Transform.scale(
                                scale: scale,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [Colors.red, Colors.redAccent],
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.red.withOpacity(
                                          0.5 + (0.2 * pulse),
                                        ),
                                        blurRadius: 8 + (4 * pulse),
                                        spreadRadius: 2 + (1 * pulse),
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.fiber_manual_record,
                                        color: Colors.white,
                                        size: 8,
                                        shadows: [
                                          Shadow(
                                            color: Colors.black.withOpacity(
                                              0.3,
                                            ),
                                            blurRadius: 2,
                                          ),
                                        ],
                                      ),
                                      const SizedBox(width: 4),
                                      const Text(
                                        'Mới',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          shadows: [
                                            Shadow(
                                              color: Colors.black26,
                                              blurRadius: 2,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),

              // Arrow
              Icon(
                Icons.arrow_forward_ios_rounded,
                color: Colors.grey[400],
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
