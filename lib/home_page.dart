import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'pages/home_tab_new.dart';
import 'add_room_page.dart';
import 'favorite_page.dart';
import 'profile_page.dart';
import 'chat_hub_page.dart';
import 'notifications_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentIndex = 0;
  int _unreadMessagesCount = 0;
  int _unreadNotificationsCount = 0;
  final dbRef = FirebaseDatabase.instance.ref();
  final user = FirebaseAuth.instance.currentUser!;

  StreamSubscription? _conversationsSubscription;
  StreamSubscription? _userConversationsSubscription;
  StreamSubscription? _notificationsSubscription;
  StreamSubscription? _readNotificationsSubscription;

  @override
  void initState() {
    super.initState();
    print('📱 HOMEPAGE: initState called!');
    _listenToUnreadMessages();
    _listenToUnreadNotifications();
  }

  @override
  void dispose() {
    _conversationsSubscription?.cancel();
    _userConversationsSubscription?.cancel();
    _notificationsSubscription?.cancel();
    _readNotificationsSubscription?.cancel();
    super.dispose();
  }

  void _listenToUnreadMessages() {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    // 🚀 CHỈ lắng nghe conversations của user hiện tại
    _conversationsSubscription = dbRef
        .child('conversations')
        .orderByChild('userId')
        .equalTo(currentUser.uid)
        .onValue
        .listen((event) {
          if (!mounted) return;
          _updateUnreadFromConversations(event.snapshot.value);
        });

    // 🚀 Lắng nghe user_conversations - không thay đổi (cần kiểm tra cả 2 field)
    _userConversationsSubscription = dbRef
        .child('user_conversations')
        .onValue
        .listen((event) {
          if (!mounted) return;
          _updateUnreadFromUserConversations(event.snapshot.value);
        });
  }

  // 🚀 Tối ưu: Chỉ kiểm tra CÓ hay KHÔNG có tin nhắn chưa đọc (hiển thị dấu chấm)
  void _updateUnreadFromConversations(dynamic data) {
    if (data == null) {
      _updateUnreadTotal(0, isFromConversations: true);
      return;
    }

    bool hasUnread = false;
    if (data is Map) {
      for (var conv in data.values) {
        if (conv != null && conv['userId'] == user.uid) {
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
            hasUnread = true;
            break; // Chỉ cần biết CÓ tin nhắn chưa đọc, không cần đếm
          }
        }
      }
    }

    _updateUnreadTotal(hasUnread ? 1 : 0, isFromConversations: true);
  }

  void _updateUnreadFromUserConversations(dynamic data) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null || data == null) {
      _updateUnreadTotal(0, isFromConversations: false);
      return;
    }

    bool hasUnread = false;
    if (data is Map) {
      for (var conv in data.values) {
        if (conv == null) continue;

        // 🔥 Kiểm tra có tin nhắn chưa đọc KHÔNG phải do user hiện tại gửi
        final lastSenderId = conv['lastSenderId'];

        // Lấy unread count của user hiện tại
        int myUnread = 0;
        if (conv['user1Id'] == currentUser.uid) {
          final c = conv['user1UnreadCount'] ?? 0;
          myUnread = (c is int)
              ? c
              : (c is double)
              ? c.toInt()
              : 0;
        } else if (conv['user2Id'] == currentUser.uid) {
          final c = conv['user2UnreadCount'] ?? 0;
          myUnread = (c is int)
              ? c
              : (c is double)
              ? c.toInt()
              : 0;
        }

        // Có tin nhắn chưa đọc VÀ không phải do user gửi
        if (myUnread > 0 && lastSenderId != currentUser.uid) {
          hasUnread = true;
          break; // Chỉ cần biết CÓ tin nhắn chưa đọc
        }
      }
    }

    _updateUnreadTotal(hasUnread ? 1 : 0, isFromConversations: false);
  }

  int _conversationsUnread = 0;
  int _userConversationsUnread = 0;

  void _updateUnreadTotal(int count, {required bool isFromConversations}) {
    if (isFromConversations) {
      _conversationsUnread = count;
    } else {
      _userConversationsUnread = count;
    }

    if (mounted) {
      setState(() {
        _unreadMessagesCount = _conversationsUnread + _userConversationsUnread;
      });
    }
  }

  void _listenToUnreadNotifications() {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    // 🔥 Lắng nghe thay đổi trong notifications
    _notificationsSubscription = dbRef
        .child('users')
        .child(currentUser.uid)
        .child('notifications')
        .onValue
        .listen((event) async {
          if (!mounted) return;
          await _updateUnreadNotificationsCount();
        });

    // 🔥 Lắng nghe thay đổi trong readNotifications (khi user đọc thông báo)
    _readNotificationsSubscription = dbRef
        .child('users')
        .child(currentUser.uid)
        .child('readNotifications')
        .onValue
        .listen((event) async {
          if (!mounted) return;
          await _updateUnreadNotificationsCount();
        });
  }

  Future<void> _updateUnreadNotificationsCount() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    try {
      // 🚀 Fetch song song readNotifications và notifications
      final results = await Future.wait([
        dbRef
            .child('users')
            .child(currentUser.uid)
            .child('readNotifications')
            .get(),
        dbRef
            .child('users')
            .child(currentUser.uid)
            .child('notifications')
            .get(),
      ]);

      final readSnapshot = results[0];
      final notificationsSnapshot = results[1];

      final readNotifications = <String>{};
      if (readSnapshot.exists && readSnapshot.value != null) {
        // 🔥 Xử lý cả List và Map
        if (readSnapshot.value is List) {
          final list = readSnapshot.value as List;
          for (var item in list) {
            if (item != null && item is String) {
              readNotifications.add(item);
            }
          }
        } else if (readSnapshot.value is Map) {
          final map = readSnapshot.value as Map;
          for (var value in map.values) {
            if (value != null && value is String) {
              readNotifications.add(value);
            }
          }
        }
      }

      // 🔴 Chỉ kiểm tra CÓ hay KHÔNG có thông báo chưa đọc (không đếm số)
      bool hasUnread = false;
      if (notificationsSnapshot.exists && notificationsSnapshot.value != null) {
        final notifications = notificationsSnapshot.value as Map;
        hasUnread = notifications.keys.any(
          (id) => !readNotifications.contains(id),
        );
      }

      if (mounted) {
        setState(() {
          _unreadNotificationsCount = hasUnread ? 1 : 0; // 1 = có, 0 = không
        });
      }
    } catch (e) {
      print('❌ Lỗi đếm thông báo chưa đọc: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    print('📱 HOMEPAGE BUILD: currentIndex = $_currentIndex');

    // 🚀 Dùng IndexedStack để cache tất cả các tab
    return Scaffold(
      extendBody: true,
      body: SafeArea(
        child: IndexedStack(
          index: _currentIndex,
          children: [
            HomeTabNew(), // 🚀 Bỏ ValueKey để giữ state
            const FavoritePage(),
            const ChatHubPage(),
            const NotificationsPage(),
            const ProfilePage(),
          ],
        ),
      ),

      // 🌟 Floating Action Button - Add Room và Test Notification
      floatingActionButton: _buildFloatingButtons(),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,

      // Bottom Navigation Bar (bỏ floatingActionButton cũ, giờ dùng Stack)
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.white, Colors.blue.shade50],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.blue.withValues(alpha: 0.15),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              height: 65,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.white.withValues(alpha: 0.9),
                    Colors.blue.shade50.withValues(alpha: 0.8),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildNavItem(Icons.home_rounded, 'Trang chủ', 0),
                  _buildNavItem(Icons.favorite_rounded, 'Yêu thích', 1),
                  _buildNavItemWithBadge(
                    Icons.chat_bubble_rounded,
                    'Chat',
                    2,
                    _unreadMessagesCount,
                  ),
                  _buildNavItemWithBadge(
                    Icons.notifications_rounded,
                    'Thông báo',
                    3,
                    _unreadNotificationsCount,
                  ),
                  _buildNavItem(Icons.person_rounded, 'Cá nhân', 4),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Widget nút thêm phòng
  Widget _buildFloatingButtons() {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF4A90E2), Color(0xFF50C9FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withValues(alpha: 0.4),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: FloatingActionButton(
        backgroundColor: Colors.transparent,
        elevation: 0,
        onPressed: () async {
          // Navigate và chờ kết quả
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddRoomPage()),
          );

          // Nếu đăng bài thành công, chuyển về tab Home
          if (result == true && mounted) {
            setState(() => _currentIndex = 0);
          }
        },
        child: const Icon(Icons.add, color: Colors.white, size: 32),
      ),
    );
  }

  // Widget mục trong thanh điều hướng
  Widget _buildNavItem(IconData icon, String label, int index) {
    final bool isSelected = _currentIndex == index;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _currentIndex = index),
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  gradient: isSelected
                      ? const LinearGradient(
                          colors: [Color(0xFF4A90E2), Color(0xFF50C9FF)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : null,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: Colors.blue.withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Icon(
                  icon,
                  size: 24,
                  color: isSelected ? Colors.white : Colors.grey.shade500,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected
                      ? const Color(0xFF4A90E2)
                      : Colors.grey.shade600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Widget mục với badge (cho Chat và Thông báo)
  Widget _buildNavItemWithBadge(
    IconData icon,
    String label,
    int index,
    int badgeCount,
  ) {
    final bool isSelected = _currentIndex == index;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _currentIndex = index),
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      gradient: isSelected
                          ? const LinearGradient(
                              colors: [Color(0xFF4A90E2), Color(0xFF50C9FF)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            )
                          : null,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: Colors.blue.withValues(alpha: 0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ]
                          : null,
                    ),
                    child: Icon(
                      icon,
                      size: 24,
                      color: isSelected ? Colors.white : Colors.grey.shade500,
                    ),
                  ),
                  // 🔥 Badge đỏ (dấu chấm) - chỉ hiện khi có tin nhắn mới
                  if (badgeCount > 0)
                    Positioned(
                      right: -2,
                      top: -2,
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.red.withOpacity(0.5),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 3),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected
                      ? const Color(0xFF4A90E2)
                      : Colors.grey.shade600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
