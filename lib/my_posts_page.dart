import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';
import 'models/room_model.dart';
import 'models/user_profile.dart';
import 'edit_room_page.dart';
import 'pages/user_vip_info_page.dart';
import 'services/vip_service_user.dart';

class MyPostsPage extends StatefulWidget {
  const MyPostsPage({super.key});

  @override
  State<MyPostsPage> createState() => _MyPostsPageState();
}

class _MyPostsPageState extends State<MyPostsPage> {
  final user = FirebaseAuth.instance.currentUser!;
  final dbRef = FirebaseDatabase.instance.ref();
  final vipServiceUser = VipServiceUser();

  // User VIP profile
  UserProfile? _userProfile;

  Future<void> _deletePost(String postId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xác nhận xóa'),
        content: const Text('Bạn có chắc muốn xóa bài đăng này?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await dbRef.child('rooms').child(postId).remove();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Đã xóa bài đăng')));
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    try {
      final profile = await vipServiceUser.getCurrentUserProfile();
      if (mounted) {
        setState(() {
          _userProfile = profile;
        });
      }
    } catch (e) {
      print('❌ Error loading user profile: $e');
    }
  }

  Widget _buildStatusChip(String status) {
    Color color;
    String text;
    IconData icon;

    switch (status) {
      case 'approved':
        color = Colors.green;
        text = 'Đang hiển thị';
        icon = Icons.check_circle;
        break;
      case 'rejected':
        color = Colors.red;
        text = 'Từ chối';
        icon = Icons.cancel;
        break;
      default:
        color = Colors.orange;
        text = 'Chờ duyệt';
        icon = Icons.hourglass_empty;
    }

    return Chip(
      avatar: Icon(icon, size: 16, color: Colors.white),
      label: Text(text, style: const TextStyle(color: Colors.white)),
      backgroundColor: color,
      padding: EdgeInsets.zero,
    );
  }

  Widget _buildUserVipCard(int roomCount) {
    if (_userProfile == null) return const SizedBox.shrink();

    final isVip = _userProfile!.isVipActive;
    final vipIcon = _userProfile!.vipIcon;
    final vipName = _userProfile!.vipName;
    final vipColor = Color(_userProfile!.vipColor);
    final daysRemaining = _userProfile!.vipDaysRemaining;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isVip
              ? [vipColor, vipColor.withOpacity(0.7)]
              : [Colors.grey[400]!, Colors.grey[600]!],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: (isVip ? vipColor : Colors.grey).withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (isVip)
                Text(vipIcon, style: const TextStyle(fontSize: 32))
              else
                const Icon(Icons.person, size: 32, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isVip ? 'Tài khoản $vipName' : 'Tài khoản Free',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (isVip) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Còn $daysRemaining ngày',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (isVip)
            Text(
              '✨ Tất cả $roomCount phòng của bạn đều có huy hiệu $vipIcon',
              style: const TextStyle(color: Colors.white, fontSize: 14),
            )
          else
            const Text(
              'Nâng cấp VIP để tất cả phòng được ưu tiên hiển thị!',
              style: TextStyle(color: Colors.white, fontSize: 14),
            ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const UserVipInfoPage(),
                  ),
                );
                if (result == true && mounted) {
                  _loadUserProfile(); // Refresh user profile
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: isVip ? vipColor : Colors.grey[700],
              ),
              child: Text(isVip ? '🔄 Gia hạn VIP' : '🚀 Nâng cấp VIP'),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final formatter = NumberFormat.currency(locale: 'vi_VN', symbol: '₫');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bài đăng của tôi'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: StreamBuilder(
          stream: dbRef
              .child('rooms')
              .orderByChild('ownerId')
              .equalTo(user.uid)
              .onValue,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return const Center(child: Text('Lỗi tải dữ liệu'));
            }

            final data = (snapshot.data?.snapshot.value ?? {}) as Map?;
            if (data == null || data.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.post_add, size: 80, color: Colors.grey[400]),
                    const SizedBox(height: 16),
                    Text(
                      'Bạn chưa có bài đăng nào',
                      style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                    ),
                  ],
                ),
              );
            }

            final posts = data.entries.toList()
              ..sort(
                (a, b) => b.value['timestamp'].compareTo(a.value['timestamp']),
              );

            return Column(
              children: [
                // ⭐ User VIP Card
                _buildUserVipCard(posts.length),

                // ⭐ Room List
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    itemCount: posts.length,
                    itemBuilder: (context, index) {
                      final postId = posts[index].key;
                      final room = Room.fromMap(postId, posts[index].value);

                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        elevation: 1,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      room.title,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  _buildStatusChip(room.status),
                                ],
                              ),
                              const SizedBox(height: 8),

                              Row(
                                children: [
                                  const Icon(
                                    Icons.location_on,
                                    size: 16,
                                    color: Colors.grey,
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      '${room.ward}, ${room.district}',
                                      style: TextStyle(color: Colors.grey[600]),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    formatter.format(room.price),
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.red,
                                    ),
                                  ),
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.visibility,
                                        size: 16,
                                        color: Colors.grey,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        '${room.viewCount}',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Text(
                                        '${room.area} m²',
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                          color: Colors.blue,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),

                              // Buttons row
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  // ⭐ VIP button removed - VIP theo user, hiển thị ở User VIP Card
                                  OutlinedButton.icon(
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              EditRoomPage(room: room),
                                        ),
                                      );
                                    },
                                    icon: const Icon(Icons.edit, size: 18),
                                    label: const Text('Sửa'),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.orange,
                                    ),
                                  ),
                                  OutlinedButton.icon(
                                    onPressed: () => _deletePost(postId),
                                    icon: const Icon(Icons.delete, size: 18),
                                    label: const Text('Xóa'),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.red,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ), // End Expanded
              ], // End Column children
            ); // End Column
          },
        ),
      ),
    );
  }

  // ⭐ DEPRECATED: _getVipColor không còn dùng cho VIP user-based
}
