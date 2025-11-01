import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';
import 'room_detail_stats_page.dart';
import 'vip_packages_page_user.dart';

class OwnerDashboardPage extends StatefulWidget {
  const OwnerDashboardPage({super.key});

  @override
  State<OwnerDashboardPage> createState() => _OwnerDashboardPageState();
}

class _OwnerDashboardPageState extends State<OwnerDashboardPage> {
  final user = FirebaseAuth.instance.currentUser!;
  final dbRef = FirebaseDatabase.instance.ref();

  bool _isLoading = true;
  List<RoomStats> _roomStats = [];
  DashboardSummary? _summary;
  bool _isUserVip = false; // Chỉ Premium (level 2) mới true

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    setState(() => _isLoading = true);

    try {
      print('📊 Loading dashboard for user: ${user.uid}');

      // 1. Check xem user có phải Premium không (CHỈ Premium level 2 mới được)
      final userSnapshot = await dbRef.child('users').child(user.uid).get();
      if (userSnapshot.exists) {
        final userData = userSnapshot.value as Map;
        final vipLevel = userData['vipLevel'] ?? 0;
        final vipEndDate = userData['vipEndDate'];

        // Check Premium còn active: vipLevel == 2 (chỉ Premium) VÀ chưa hết hạn
        final isPremiumActive =
            vipLevel == 2 &&
            vipEndDate != null &&
            DateTime.now().millisecondsSinceEpoch < vipEndDate;

        _isUserVip = isPremiumActive;
        print(
          '👤 User Premium Status: $_isUserVip (vipLevel: $vipLevel, endDate: $vipEndDate)',
        );
      }

      // 2. Load tất cả phòng của chủ trọ VÀ tất cả bookings song song
      print('🔄 Loading rooms and bookings in parallel...');
      final results = await Future.wait([
        dbRef.child('rooms').orderByChild('ownerId').equalTo(user.uid).get(),
        dbRef.child('bookings').get(),
      ]);

      final roomsSnapshot = results[0];
      final allBookingsSnapshot = results[1];

      if (!roomsSnapshot.exists) {
        print('⚠️ No rooms found for this owner');
        setState(() {
          _isLoading = false;
          _summary = DashboardSummary(
            totalRooms: 0,
            totalViews: 0,
            totalViewingBookings: 0,
            totalDepositBookings: 0,
            avgConversionRate: 0,
            vipRooms: 0,
            normalRooms: 0,
          );
        });
        return;
      }

      print('✅ Found ${(roomsSnapshot.value as Map).length} rooms');

      // Parse tất cả bookings vào Map để lookup nhanh
      final allBookings = <String, List<Map>>{};
      if (allBookingsSnapshot.exists) {
        final bookingsMap = allBookingsSnapshot.value as Map;
        for (var bookingEntry in bookingsMap.values) {
          final booking = bookingEntry as Map;
          final roomId = booking['roomId'] as String?;
          if (roomId != null) {
            allBookings.putIfAbsent(roomId, () => []).add(booking);
          }
        }
      }

      print('✅ Loaded ${allBookings.length} room bookings');

      final roomsMap = roomsSnapshot.value as Map;
      final roomStatsList = <RoomStats>[];

      int totalViews = 0;
      int totalViewingBookings = 0;
      int totalDepositBookings = 0;

      // Nếu user Premium (level 2) → tất cả phòng là Premium
      // Nếu user không Premium → không có phòng Premium
      int vipRooms = 0;
      int normalRooms = 0;

      // 3. Xử lý từng phòng
      int processedRooms = 0;
      int skippedRooms = 0;

      for (var entry in roomsMap.entries) {
        final roomId = entry.key;
        final roomData = entry.value as Map;

        final roomTitle = roomData['title'] ?? 'Unknown';
        final viewCount = (roomData['viewCount'] ?? 0) as int;
        final status = roomData['status'] ?? '';
        final availabilityStatus =
            roomData['availabilityStatus'] ?? 'DangMo'; // Default cho phòng cũ

        if (status != 'approved') {
          skippedRooms++;
          print('⏭️ Skipped room "$roomTitle" (status: $status)');
          continue; // Chỉ tính phòng đã duyệt
        }

        processedRooms++;
        print(
          '✓ Processing room: $roomTitle (views: $viewCount, userPremium(level 2): $_isUserVip)',
        );

        // User Premium (level 2) → tất cả phòng đều Premium
        if (_isUserVip) {
          vipRooms++;
        } else {
          normalRooms++;
        }

        // 3. Đếm số lượng bookings cho phòng này từ Map (KHÔNG query)
        int viewingBookings = 0;
        int depositBookings = 0;

        final roomBookings = allBookings[roomId] ?? [];
        for (var booking in roomBookings) {
          final bookingType = booking['bookingType'] ?? '';

          if (bookingType == 'viewing') {
            viewingBookings++;
          } else if (bookingType == 'deposit') {
            depositBookings++;
          }
        }

        // 4. Tính conversion rate
        final conversionRate = viewCount > 0
            ? ((depositBookings / viewCount) * 100)
            : 0.0;

        roomStatsList.add(
          RoomStats(
            roomId: roomId,
            roomTitle: roomTitle,
            viewCount: viewCount,
            viewingBookings: viewingBookings,
            depositBookings: depositBookings,
            conversionRate: conversionRate,
            isVip: _isUserVip, // Dùng Premium status của user, không phải phòng
            availabilityStatus: availabilityStatus,
          ),
        );

        totalViews += viewCount;
        totalViewingBookings += viewingBookings;
        totalDepositBookings += depositBookings;
      }

      // 5. Tính tổng conversion rate
      final avgConversionRate = totalViews > 0
          ? ((totalDepositBookings / totalViews) * 100)
          : 0.0;

      // 6. Sắp xếp theo view count
      roomStatsList.sort((a, b) => b.viewCount.compareTo(a.viewCount));

      print('📊 Dashboard Summary:');
      print('   - Processed: $processedRooms rooms');
      print('   - Skipped: $skippedRooms rooms');
      print('   - Total Views: $totalViews');
      print('   - Viewing Bookings: $totalViewingBookings');
      print('   - Deposit Bookings: $totalDepositBookings');
      print('   - Avg CR: ${avgConversionRate.toStringAsFixed(2)}%');

      if (mounted) {
        setState(() {
          _roomStats = roomStatsList;
          _summary = DashboardSummary(
            totalRooms: roomStatsList.length,
            totalViews: totalViews,
            totalViewingBookings: totalViewingBookings,
            totalDepositBookings: totalDepositBookings,
            avgConversionRate: avgConversionRate,
            vipRooms: vipRooms,
            normalRooms: normalRooms,
          );
          _isLoading = false;
        });
      }
    } catch (e) {
      print('❌ Error loading dashboard: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi tải dữ liệu: $e'),
            backgroundColor: Colors.red,
            action: SnackBarAction(
              label: 'Thử lại',
              textColor: Colors.white,
              onPressed: _loadDashboardData,
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard Thống Kê'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: _loadDashboardData,
            icon: const Icon(Icons.refresh),
            tooltip: 'Làm mới',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : !_isUserVip
          ? _buildUpgradeRequiredScreen()
          : _summary == null || _summary!.totalRooms == 0
          ? _buildEmptyState()
          : RefreshIndicator(
              onRefresh: _loadDashboardData,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSummaryCards(),
                    const SizedBox(height: 24),
                    _buildConversionFunnel(),
                    const SizedBox(height: 24),
                    _buildRoomsList(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildUpgradeRequiredScreen() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Animated lock icon
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: const Duration(milliseconds: 800),
              curve: Curves.elasticOut,
              builder: (context, value, child) {
                return Transform.scale(
                  scale: value,
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.deepPurple.shade600,
                          Colors.deepPurple.shade400,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.deepPurple.withOpacity(0.4),
                          blurRadius: 30,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.lock_outline,
                      size: 80,
                      color: Colors.white,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 32),

            // Title
            Text(
              'Dashboard Premium',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.deepPurple.shade700,
              ),
            ),
            const SizedBox(height: 16),

            // Description
            Text(
              'Chức năng Dashboard Thống Kê chỉ dành cho tài khoản Premium',
              style: TextStyle(fontSize: 16, color: Colors.grey[700]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),

            // Features card
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.deepPurple.shade50,
                    Colors.deepPurple.shade100.withOpacity(0.3),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.deepPurple.shade200, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.deepPurple.withOpacity(0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(Icons.star_rounded, color: Colors.amber, size: 28),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Tính năng Dashboard Premium',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.deepPurple.shade800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _buildFeatureItem(
                    Icons.analytics_rounded,
                    'Thống kê chi tiết số lượt xem',
                    Colors.blue,
                  ),
                  const SizedBox(height: 12),
                  _buildFeatureItem(
                    Icons.calendar_today_rounded,
                    'Thống kê lịch đặt xem phòng',
                    Colors.green,
                  ),
                  const SizedBox(height: 12),
                  _buildFeatureItem(
                    Icons.payment_rounded,
                    'Thống kê đặt cọc',
                    Colors.orange,
                  ),
                  const SizedBox(height: 12),
                  _buildFeatureItem(
                    Icons.trending_up_rounded,
                    'Tỷ lệ chuyển đổi (Conversion Rate)',
                    Colors.purple,
                  ),
                  const SizedBox(height: 12),
                  _buildFeatureItem(
                    Icons.insights_rounded,
                    'Hiểu rõ hiệu quả bài đăng',
                    Colors.teal,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Upgrade button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const VipPackagesPageUser(),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Colors.deepPurple.shade600,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 8,
                  shadowColor: Colors.deepPurple.withOpacity(0.4),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.diamond_rounded, size: 24),
                    const SizedBox(width: 8),
                    const Text(
                      'Nâng cấp lên Premium ngay',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Back button
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('Trở lại', style: TextStyle(fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureItem(IconData icon, String text, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 15,
              color: Colors.grey[800],
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.analytics_outlined, size: 80, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'Chưa có dữ liệu thống kê',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Dashboard chỉ hiển thị các phòng đã được Admin duyệt',
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: Colors.blue.shade700,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Có thể do:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildEmptyStateReason('1', 'Bạn chưa đăng phòng nào'),
                  _buildEmptyStateReason('2', 'Phòng đang chờ Admin duyệt'),
                  _buildEmptyStateReason('3', 'Phòng bị từ chối hoặc bị ẩn'),
                ],
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
              },
              icon: const Icon(Icons.home),
              label: const Text('Về trang chủ'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyStateReason(String number, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: Colors.blue.shade100,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                number,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade700,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 14, color: Colors.grey[700]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCards() {
    final summary = _summary!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Tổng Quan',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                title: 'Lượt xem',
                value: NumberFormat.decimalPattern().format(summary.totalViews),
                icon: Icons.visibility,
                color: Colors.blue,
                subtitle: '${summary.totalRooms} phòng',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                title: 'Đặt lịch xem',
                value: summary.totalViewingBookings.toString(),
                icon: Icons.event,
                color: Colors.orange,
                subtitle: 'Lịch hẹn',
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                title: 'Đặt cọc',
                value: summary.totalDepositBookings.toString(),
                icon: Icons.account_balance_wallet,
                color: Colors.green,
                subtitle: 'Tiềm năng',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                title: 'Tỷ lệ chuyển đổi',
                value: '${summary.avgConversionRate.toStringAsFixed(1)}%',
                icon: Icons.trending_up,
                color: Colors.purple,
                subtitle: 'Conversion Rate',
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 4,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const Spacer(),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[700],
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            subtitle,
            style: TextStyle(fontSize: 10, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Widget _buildConversionFunnel() {
    final summary = _summary!;
    final totalViews = summary.totalViews;
    final viewingBookings = summary.totalViewingBookings;
    final depositBookings = summary.totalDepositBookings;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 4,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.filter_list, color: Colors.deepPurple),
              SizedBox(width: 8),
              Text(
                'Phễu Chuyển Đổi',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildFunnelStep(
            label: '👀 Người xem',
            value: totalViews,
            maxValue: totalViews,
            color: Colors.blue,
            percentage: 100,
          ),
          const SizedBox(height: 12),
          _buildFunnelStep(
            label: '📅 Đặt lịch xem',
            value: viewingBookings,
            maxValue: totalViews,
            color: Colors.orange,
            percentage: totalViews > 0
                ? (viewingBookings / totalViews * 100)
                : 0,
          ),
          const SizedBox(height: 12),
          _buildFunnelStep(
            label: '💰 Đặt cọc',
            value: depositBookings,
            maxValue: totalViews,
            color: Colors.green,
            percentage: totalViews > 0
                ? (depositBookings / totalViews * 100)
                : 0,
          ),
        ],
      ),
    );
  }

  Widget _buildFunnelStep({
    required String label,
    required int value,
    required int maxValue,
    required Color color,
    required double percentage,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            Text(
              '$value (${percentage.toStringAsFixed(1)}%)',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: maxValue > 0 ? value / maxValue : 0,
            backgroundColor: Colors.grey[200],
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 8,
          ),
        ),
      ],
    );
  }

  Widget _buildRoomsList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.list, color: Colors.deepPurple),
            SizedBox(width: 8),
            Text(
              'Chi Tiết Từng Phòng',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _roomStats.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final stats = _roomStats[index];
            return _buildRoomStatCard(stats);
          },
        ),
      ],
    );
  }

  Widget _buildRoomStatCard(RoomStats stats) {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => RoomDetailStatsPage(
              roomId: stats.roomId,
              roomTitle: stats.roomTitle,
            ),
          ),
        );
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: stats.isVip ? Colors.amber.shade300 : Colors.grey.shade200,
            width: stats.isVip ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              spreadRadius: 1,
              blurRadius: 4,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    stats.roomTitle,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (stats.isVip)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.deepPurple.shade400,
                          Colors.purple.shade400,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      children: [
                        Icon(
                          Icons.workspace_premium,
                          color: Colors.white,
                          size: 14,
                        ),
                        SizedBox(width: 4),
                        Text(
                          'Premium',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildMiniStat(
                    icon: Icons.visibility,
                    label: 'Lượt xem',
                    value: stats.viewCount.toString(),
                    color: Colors.blue,
                  ),
                ),
                Expanded(
                  child: _buildMiniStat(
                    icon: Icons.event,
                    label: 'Đặt lịch',
                    value: stats.viewingBookings.toString(),
                    color: Colors.orange,
                  ),
                ),
                Expanded(
                  child: _buildMiniStat(
                    icon: Icons.account_balance_wallet,
                    label: 'Đặt cọc',
                    value: stats.depositBookings.toString(),
                    color: Colors.green,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.trending_up, size: 16, color: Colors.purple),
                    const SizedBox(width: 4),
                    Text(
                      'CR: ${stats.conversionRate.toStringAsFixed(1)}%',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.purple,
                      ),
                    ),
                  ],
                ),
                _buildStatusBadge(stats.availabilityStatus),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniStat({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(label, style: TextStyle(fontSize: 10, color: Colors.grey[600])),
      ],
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    String text;

    switch (status) {
      case 'DangMo':
        color = Colors.green;
        text = 'Đang mở';
        break;
      case 'DaDatLich':
        color = Colors.orange;
        text = 'Có lịch xem';
        break;
      case 'DaDatCoc':
        color = Colors.blue;
        text = 'Đã đặt cọc';
        break;
      case 'DaThue':
        color = Colors.grey;
        text = 'Đã thuê';
        break;
      default:
        color = Colors.grey;
        text = status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

// Models
class RoomStats {
  final String roomId;
  final String roomTitle;
  final int viewCount;
  final int viewingBookings;
  final int depositBookings;
  final double conversionRate;
  final bool isVip;
  final String availabilityStatus;

  RoomStats({
    required this.roomId,
    required this.roomTitle,
    required this.viewCount,
    required this.viewingBookings,
    required this.depositBookings,
    required this.conversionRate,
    required this.isVip,
    required this.availabilityStatus,
  });
}

class DashboardSummary {
  final int totalRooms;
  final int totalViews;
  final int totalViewingBookings;
  final int totalDepositBookings;
  final double avgConversionRate;
  final int vipRooms;
  final int normalRooms;

  DashboardSummary({
    required this.totalRooms,
    required this.totalViews,
    required this.totalViewingBookings,
    required this.totalDepositBookings,
    required this.avgConversionRate,
    required this.vipRooms,
    required this.normalRooms,
  });
}
