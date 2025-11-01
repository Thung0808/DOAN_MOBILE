import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'approve_posts_page.dart';
import 'manage_users_page.dart';
import 'manage_reports_page.dart';
import 'manage_vip_page.dart';
import 'manage_transactions_page.dart';
import 'debug_reports_page.dart';
import 'rooms_filter_page.dart';
import 'users_filter_page.dart';
import 'admin_chats_page.dart';
import 'create_notification_page.dart';
import 'update_ratings_page.dart';
import 'database_migration_page.dart';
import '../login_page.dart';
import '../services/auth_service.dart';

class AdminPanel extends StatefulWidget {
  const AdminPanel({super.key});

  @override
  State<AdminPanel> createState() => _AdminPanelState();
}

class _AdminPanelState extends State<AdminPanel> {
  final user = FirebaseAuth.instance.currentUser!;
  final dbRef = FirebaseDatabase.instance.ref();

  int _pendingPostsCount = 0;
  int _totalUsersCount = 0;
  int _totalRoomsCount = 0;
  int _approvedRoomsCount = 0;
  int _rejectedPostsCount = 0;
  int _adminCount = 0;
  int _todayPostsCount = 0;
  int _todayUsersCount = 0;
  int _totalReportsCount = 0;
  int _pendingReportsCount = 0;
  int _resolvedReportsCount = 0;
  int _dismissedReportsCount = 0;
  int _unreadMessagesCount = 0;
  int _totalVipUsers = 0;
  int _totalPremiumUsers = 0;
  int _totalTransactions = 0;
  // ignore: unused_field
  double _totalRevenue = 0;

  @override
  void initState() {
    super.initState();
    _loadStatistics();
  }

  Future<void> _loadStatistics() async {
    try {
      // Reset tất cả về 0
      _pendingPostsCount = 0;
      _totalUsersCount = 0;
      _totalRoomsCount = 0;
      _approvedRoomsCount = 0;
      _rejectedPostsCount = 0;
      _adminCount = 0;
      _todayPostsCount = 0;
      _todayUsersCount = 0;
      _totalReportsCount = 0;
      _pendingReportsCount = 0;
      _resolvedReportsCount = 0;
      _dismissedReportsCount = 0;
      _unreadMessagesCount = 0;

      final now = DateTime.now();
      final todayStart = DateTime(
        now.year,
        now.month,
        now.day,
      ).millisecondsSinceEpoch;

      // Load rooms statistics
      try {
        final roomsSnapshot = await dbRef.child('rooms').get();
        if (roomsSnapshot.exists && roomsSnapshot.value != null) {
          final rooms = roomsSnapshot.value as Map;
          _totalRoomsCount = rooms.length;

          int pending = 0, approved = 0, rejected = 0, today = 0;

          for (var room in rooms.values) {
            if (room == null) continue;

            final status = room['status']?.toString() ?? '';
            final timestamp = room['timestamp'];

            // Đếm theo status
            if (status == 'pending') pending++;
            if (status == 'approved') approved++;
            if (status == 'rejected') rejected++;

            // Đếm bài đăng hôm nay
            if (timestamp != null) {
              final ts = (timestamp is int)
                  ? timestamp
                  : (timestamp is double)
                  ? timestamp.toInt()
                  : 0;
              if (ts >= todayStart) today++;
            }
          }

          _pendingPostsCount = pending;
          _approvedRoomsCount = approved;
          _rejectedPostsCount = rejected;
          _todayPostsCount = today;

          print(
            '📊 Rooms: Total=$_totalRoomsCount, Pending=$pending, Approved=$approved, Rejected=$rejected, Today=$today',
          );
        }
      } catch (e) {
        print('❌ Lỗi load rooms: $e');
      }

      // Load users statistics
      try {
        final usersSnapshot = await dbRef.child('users').get();
        if (usersSnapshot.exists && usersSnapshot.value != null) {
          final users = usersSnapshot.value as Map;
          _totalUsersCount = users.length;

          int admin = 0, todayUsers = 0;

          for (var userEntry in users.entries) {
            final userData = userEntry.value;
            if (userData == null || userData is! Map) continue;

            final role = userData['role']?.toString() ?? '';
            final createdAt = userData['createdAt'];

            // Đếm admin
            if (role == 'admin') admin++;

            // Đếm user đăng ký hôm nay
            if (createdAt != null) {
              final ts = (createdAt is int)
                  ? createdAt
                  : (createdAt is double)
                  ? createdAt.toInt()
                  : 0;
              if (ts >= todayStart) todayUsers++;
            }
          }

          _adminCount = admin;
          _todayUsersCount = todayUsers;

          print(
            '👥 Users: Total=$_totalUsersCount, Admin=$admin, Today=$todayUsers',
          );
        }
      } catch (e) {
        print('❌ Lỗi load users: $e');
      }

      // Load reports statistics
      try {
        final reportsSnapshot = await dbRef.child('reports').get();
        if (reportsSnapshot.exists && reportsSnapshot.value != null) {
          final reports = reportsSnapshot.value as Map;
          _totalReportsCount = reports.length;

          int pending = 0, resolved = 0, dismissed = 0;

          for (var report in reports.values) {
            if (report == null) continue;

            final status = report['status']?.toString() ?? '';

            if (status == 'pending') pending++;
            if (status == 'resolved') resolved++;
            if (status == 'dismissed') dismissed++;
          }

          _pendingReportsCount = pending;
          _resolvedReportsCount = resolved;
          _dismissedReportsCount = dismissed;

          print(
            '🚩 Reports: Total=$_totalReportsCount, Pending=$pending, Resolved=$resolved, Dismissed=$dismissed',
          );
        }
      } catch (e) {
        print('❌ Lỗi load reports: $e');
      }

      // Load chat statistics
      try {
        final conversationsSnapshot = await dbRef.child('conversations').get();
        if (conversationsSnapshot.exists &&
            conversationsSnapshot.value != null) {
          final conversations = conversationsSnapshot.value as Map;
          int totalUnread = 0;

          for (var conv in conversations.values) {
            if (conv == null) continue;

            final unreadCount = conv['unreadCount'];
            if (unreadCount != null) {
              final count = (unreadCount is int)
                  ? unreadCount
                  : (unreadCount is double)
                  ? unreadCount.toInt()
                  : 0;
              totalUnread += count;
            }
          }

          _unreadMessagesCount = totalUnread;
        }
      } catch (e) {
        print('❌ Lỗi load chats: $e');
      }

      // Load VIP statistics
      try {
        final usersSnapshot = await dbRef.child('users').get();
        if (usersSnapshot.exists && usersSnapshot.value != null) {
          final users = usersSnapshot.value as Map;
          int vipCount = 0;
          int premiumCount = 0;

          for (var user in users.values) {
            if (user == null) continue;

            final vipLevel = user['vipLevel'];
            final vipEndDate = user['vipEndDate'];

            // Check if VIP is active
            if (vipLevel != null && vipLevel > 0 && vipEndDate != null) {
              final endDate = (vipEndDate is int)
                  ? vipEndDate
                  : (vipEndDate is double)
                  ? vipEndDate.toInt()
                  : 0;

              if (endDate > DateTime.now().millisecondsSinceEpoch) {
                if (vipLevel == 2) {
                  premiumCount++;
                } else if (vipLevel == 1) {
                  vipCount++;
                }
              }
            }
          }

          _totalVipUsers = vipCount;
          _totalPremiumUsers = premiumCount;
        }
      } catch (e) {
        print('❌ Lỗi load VIP stats: $e');
      }

      // Load Transaction statistics
      try {
        final paymentsSnapshot = await dbRef.child('payments').get();
        if (paymentsSnapshot.exists && paymentsSnapshot.value != null) {
          final payments = paymentsSnapshot.value as Map;
          _totalTransactions = 0;
          _totalRevenue = 0;

          for (var payment in payments.values) {
            if (payment == null) continue;

            final status = payment['status']?.toString() ?? '';
            if (status == 'success') {
              _totalTransactions++;
              final amount = payment['amount'];
              if (amount != null) {
                final amountDouble = (amount is int)
                    ? amount.toDouble()
                    : (amount is double)
                    ? amount
                    : 0.0;
                _totalRevenue += amountDouble;
              }
            }
          }
        }
      } catch (e) {
        print('❌ Lỗi load payment stats: $e');
      }

      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      print('❌ Lỗi load statistics: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi tải thống kê: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _signOut() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xác nhận đăng xuất'),
        content: const Text('Bạn có chắc muốn đăng xuất khỏi Admin Panel?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Đăng xuất'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      // Xóa thông tin đăng nhập đã lưu
      await AuthService.clearLoginState();
      await FirebaseAuth.instance.signOut();
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const LoginPage()),
          (route) => false,
        );
      }
    }
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
    VoidCallback? onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color.withOpacity(0.1), color.withOpacity(0.05)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.3), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.2),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon với background tròn
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 24, color: color),
              ),
              const SizedBox(height: 6),
              // Animated value
              TweenAnimationBuilder<int>(
                tween: IntTween(begin: 0, end: int.tryParse(value) ?? 0),
                duration: const Duration(milliseconds: 800),
                curve: Curves.easeOutCubic,
                builder: (context, animValue, child) {
                  return Text(
                    animValue.toString(),
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  );
                },
              ),
              const SizedBox(height: 2),
              // Title
              Text(
                title,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[700],
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMenuCard(
    String title,
    String subtitle,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withOpacity(0.08), color.withOpacity(0.03)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2), width: 1),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.15),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 28),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: Colors.grey[800],
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(fontSize: 13, color: Colors.grey[600]),
        ),
        trailing: Icon(
          Icons.arrow_forward_ios,
          size: 18,
          color: color.withOpacity(0.7),
        ),
        onTap: onTap,
      ),
    );
  }

  Widget _buildChatMenuCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.green.withOpacity(0.08),
            Colors.green.withOpacity(0.03),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.green.withOpacity(0.2), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withOpacity(0.15),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.chat, color: Colors.green, size: 28),
            ),
            if (_unreadMessagesCount > 0)
              Positioned(
                right: -4,
                top: -4,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 20,
                    minHeight: 20,
                  ),
                  child: Text(
                    _unreadMessagesCount > 99 ? '99+' : '$_unreadMessagesCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        ),
        title: Row(
          children: [
            Text(
              'Quản lý Chat',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Colors.grey[800],
              ),
            ),
            if (_unreadMessagesCount > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$_unreadMessagesCount tin mới',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
        subtitle: Text(
          'Trả lời tin nhắn từ người dùng',
          style: TextStyle(fontSize: 13, color: Colors.grey[600]),
        ),
        trailing: Icon(
          Icons.arrow_forward_ios,
          size: 18,
          color: Colors.green.withOpacity(0.7),
        ),
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AdminChatsPage()),
          );
          _loadStatistics();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Panel'),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: _loadStatistics,
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const DebugReportsPage()),
              );
            },
            icon: const Icon(Icons.bug_report),
            tooltip: 'Debug Reports',
          ),
          IconButton(onPressed: _signOut, icon: const Icon(Icons.logout)),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadStatistics,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Welcome message
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.orange.shade400, Colors.red.shade400],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.admin_panel_settings,
                        color: Colors.white,
                        size: 40,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Chào mừng Admin!',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              user.email ?? '',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.9),
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // 📊 Thống kê tổng quan - Grid đồng nhất
                const Text(
                  'Thống kê tổng quan',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 3,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 0.85,
                  children: [
                    // 👑 VIP/Premium gộp chung
                    _buildStatCard(
                      '👑 VIP/Premium',
                      (_totalVipUsers + _totalPremiumUsers).toString(),
                      Icons.workspace_premium,
                      const Color(0xFFFFD700),
                      () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ManageVipPage(),
                          ),
                        );
                        _loadStatistics();
                      },
                    ),
                    // 💰 Giao dịch
                    _buildStatCard(
                      '💰 Giao dịch',
                      _totalTransactions.toString(),
                      Icons.receipt_long,
                      Colors.green,
                      () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ManageTransactionsPage(),
                          ),
                        );
                        _loadStatistics();
                      },
                    ),

                    // Thống kê bài đăng
                    _buildStatCard(
                      'Tổng bài',
                      _totalRoomsCount.toString(),
                      Icons.home,
                      Colors.blue,
                      () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const RoomsFilterPage(
                              filterType: 'all',
                              title: 'Tất cả bài đăng',
                            ),
                          ),
                        ).then((_) => _loadStatistics());
                      },
                    ),
                    _buildStatCard(
                      'Chờ duyệt',
                      _pendingPostsCount.toString(),
                      Icons.hourglass_empty,
                      Colors.orange,
                      () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const RoomsFilterPage(
                              filterType: 'pending',
                              title: 'Bài chờ duyệt',
                            ),
                          ),
                        ).then((_) => _loadStatistics());
                      },
                    ),
                    _buildStatCard(
                      'Đã duyệt',
                      _approvedRoomsCount.toString(),
                      Icons.check_circle,
                      Colors.green,
                      () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const RoomsFilterPage(
                              filterType: 'approved',
                              title: 'Bài đã duyệt',
                            ),
                          ),
                        ).then((_) => _loadStatistics());
                      },
                    ),
                    _buildStatCard(
                      'Bị từ chối',
                      _rejectedPostsCount.toString(),
                      Icons.cancel,
                      Colors.red,
                      () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const RoomsFilterPage(
                              filterType: 'rejected',
                              title: 'Bài bị từ chối',
                            ),
                          ),
                        ).then((_) => _loadStatistics());
                      },
                    ),
                    _buildStatCard(
                      'Đăng hôm nay',
                      _todayPostsCount.toString(),
                      Icons.today,
                      Colors.purple,
                      () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const RoomsFilterPage(
                              filterType: 'today',
                              title: 'Bài đăng hôm nay',
                            ),
                          ),
                        ).then((_) => _loadStatistics());
                      },
                    ),

                    // Thống kê người dùng
                    _buildStatCard(
                      'Người dùng',
                      _totalUsersCount.toString(),
                      Icons.people,
                      Colors.cyan,
                      () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const UsersFilterPage(
                              filterType: 'all',
                              title: 'Tất cả người dùng',
                            ),
                          ),
                        ).then((_) => _loadStatistics());
                      },
                    ),
                    _buildStatCard(
                      'Admin',
                      _adminCount.toString(),
                      Icons.admin_panel_settings,
                      Colors.deepOrange,
                      () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const UsersFilterPage(
                              filterType: 'admin',
                              title: 'Danh sách Admin',
                            ),
                          ),
                        ).then((_) => _loadStatistics());
                      },
                    ),
                    _buildStatCard(
                      'User mới',
                      _todayUsersCount.toString(),
                      Icons.person_add,
                      Colors.teal,
                      () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const UsersFilterPage(
                              filterType: 'today',
                              title: 'User đăng ký hôm nay',
                            ),
                          ),
                        ).then((_) => _loadStatistics());
                      },
                    ),
                    _buildStatCard(
                      'User thường',
                      (_totalUsersCount - _adminCount).toString(),
                      Icons.people_outline,
                      Colors.indigo,
                      () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const UsersFilterPage(
                              filterType: 'regular',
                              title: 'User thường',
                            ),
                          ),
                        ).then((_) => _loadStatistics());
                      },
                    ),

                    // Thống kê báo cáo
                    _buildStatCard(
                      'Tổng báo cáo',
                      _totalReportsCount.toString(),
                      Icons.flag,
                      Colors.red,
                      () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ManageReportsPage(),
                          ),
                        );
                        _loadStatistics();
                      },
                    ),
                    _buildStatCard(
                      'Chờ xử lý',
                      _pendingReportsCount.toString(),
                      Icons.pending_actions,
                      Colors.amber,
                      () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ManageReportsPage(),
                          ),
                        );
                        _loadStatistics();
                      },
                    ),
                    _buildStatCard(
                      'Đã xử lý',
                      (_resolvedReportsCount + _dismissedReportsCount)
                          .toString(),
                      Icons.check_circle_outline,
                      Colors.lightGreen,
                      () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ManageReportsPage(),
                          ),
                        );
                        _loadStatistics();
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 40),

                // Menu Quản lý
                const Text(
                  'Quản lý hệ thống',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                _buildMenuCard(
                  'Duyệt bài đăng',
                  'Phê duyệt hoặc từ chối bài đăng',
                  Icons.approval,
                  Colors.orange,
                  () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ApprovePostsPage(),
                      ),
                    );
                    _loadStatistics();
                  },
                ),
                const SizedBox(height: 8),
                _buildMenuCard(
                  'Quản lý báo cáo',
                  'Xem và xử lý báo cáo từ người dùng',
                  Icons.flag,
                  Colors.red,
                  () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ManageReportsPage(),
                      ),
                    );
                    _loadStatistics();
                  },
                ),
                const SizedBox(height: 8),
                _buildMenuCard(
                  'Gửi thông báo',
                  'Tạo và gửi thông báo đến tất cả người dùng',
                  Icons.notifications_active,
                  Colors.purple,
                  () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const CreateNotificationPage(),
                      ),
                    );
                    _loadStatistics();
                  },
                ),
                const SizedBox(height: 8),
                _buildMenuCard(
                  'Quản lý VIP',
                  'Quản lý VIP/Premium subscriptions',
                  Icons.diamond,
                  Colors.cyan,
                  () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ManageVipPage()),
                    );
                    _loadStatistics();
                  },
                ),
                const SizedBox(height: 8),
                _buildMenuCard(
                  'Quản lý giao dịch',
                  'Xem lịch sử thanh toán và doanh thu',
                  Icons.receipt_long,
                  Colors.green,
                  () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ManageTransactionsPage(),
                      ),
                    );
                    _loadStatistics();
                  },
                ),
                const SizedBox(height: 8),
                _buildMenuCard(
                  'Cập nhật Rating',
                  'Tính toán lại rating cho tất cả phòng',
                  Icons.star_rate,
                  Colors.amber,
                  () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const UpdateRatingsPage(),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 8),
                _buildMenuCard(
                  '🔧 Database Migration',
                  'Cập nhật dữ liệu cũ với trường mới (chỉ chạy 1 lần)',
                  Icons.storage,
                  Colors.deepPurple,
                  () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const DatabaseMigrationPage(),
                      ),
                    );
                    _loadStatistics();
                  },
                ),
                const SizedBox(height: 8),
                _buildChatMenuCard(),
                const SizedBox(height: 8),
                _buildMenuCard(
                  'Quản lý người dùng',
                  'Xem và quản lý người dùng',
                  Icons.people,
                  Colors.blue,
                  () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ManageUsersPage(),
                      ),
                    );
                    _loadStatistics();
                  },
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
