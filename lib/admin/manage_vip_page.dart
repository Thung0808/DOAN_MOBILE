import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';
import '../models/vip_subscription_model.dart';

/// Admin page để quản lý VIP subscriptions
class ManageVipPage extends StatefulWidget {
  const ManageVipPage({super.key});

  @override
  State<ManageVipPage> createState() => _ManageVipPageState();
}

class _ManageVipPageState extends State<ManageVipPage> {
  final dbRef = FirebaseDatabase.instance.ref();

  List<VipSubscription> _allSubscriptions = [];
  List<VipSubscription> _filteredSubscriptions = [];
  bool _isLoading = true;

  // Filters
  String _statusFilter = 'all'; // all, active, expired, cancelled
  String _typeFilter = 'all'; // all, vip, premium

  // Statistics
  int _totalVipUsers = 0;
  int _totalPremiumUsers = 0;
  int _activeSubscriptions = 0;
  int _expiredSubscriptions = 0;
  double _totalRevenue = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      // Load all VIP subscriptions
      final subsSnapshot = await dbRef.child('vipSubscriptions').get();

      if (subsSnapshot.exists) {
        final subsMap = subsSnapshot.value as Map;
        _allSubscriptions =
            subsMap.entries
                .map((e) => VipSubscription.fromMap(e.key, e.value as Map))
                .toList()
              ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      } else {
        _allSubscriptions = [];
      }

      // Calculate statistics (async now)
      await _calculateStatistics();

      // Apply filters
      _applyFilters();
    } catch (e) {
      print('Error loading VIP data: $e');
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _calculateStatistics() async {
    _activeSubscriptions = _allSubscriptions.where((s) => s.isActive).length;
    _expiredSubscriptions = _allSubscriptions
        .where((s) => s.status == 'expired')
        .length;

    // 🔥 Đếm đúng theo vipLevel của user (không theo packageType)
    // Lấy danh sách unique userId từ active subscriptions
    final activeUserIds = _allSubscriptions
        .where((s) => s.isActive)
        .map((s) => s.userId)
        .toSet();

    int vipCount = 0;
    int premiumCount = 0;

    // Đọc vipLevel thực tế từ user profile
    for (var userId in activeUserIds) {
      try {
        final userSnapshot = await dbRef.child('users').child(userId).get();
        if (userSnapshot.exists) {
          final userData = userSnapshot.value as Map;
          final vipLevel = userData['vipLevel'] ?? 0;
          final vipEndDate = userData['vipEndDate'];

          // Check VIP còn active
          if (vipLevel > 0 && vipEndDate != null) {
            final endDate = (vipEndDate is int)
                ? vipEndDate
                : (vipEndDate is double)
                ? vipEndDate.toInt()
                : 0;

            final now = DateTime.now().millisecondsSinceEpoch;
            final isActive = endDate > now;

            if (isActive) {
              if (vipLevel == 2) {
                premiumCount++; // Priority 2 = Premium
              } else if (vipLevel == 1) {
                vipCount++; // Priority 1 = VIP
              }
            }
          }
        }
      } catch (e) {
        print('Error checking user $userId VIP status: $e');
      }
    }

    _totalVipUsers = vipCount;
    _totalPremiumUsers = premiumCount;

    _totalRevenue = _allSubscriptions
        .where((s) => s.status == 'active' || s.status == 'expired')
        .fold(0, (sum, s) => sum + s.price);
  }

  void _applyFilters() {
    _filteredSubscriptions = _allSubscriptions.where((sub) {
      // Status filter
      if (_statusFilter != 'all') {
        if (_statusFilter == 'active' && !sub.isActive) return false;
        if (_statusFilter == 'expired' && sub.status != 'expired') return false;
        if (_statusFilter == 'cancelled' && sub.status != 'cancelled')
          return false;
      }

      // Type filter
      if (_typeFilter != 'all' && sub.packageType != _typeFilter) {
        return false;
      }

      return true;
    }).toList();
  }

  Future<void> _cancelSubscription(VipSubscription sub) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xác nhận hủy VIP'),
        content: Text(
          'Bạn có chắc muốn hủy gói ${sub.packageName} của user này?\n\n'
          'User sẽ ngay lập tức mất quyền VIP.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Không'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Hủy VIP'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      // Update subscription status
      await dbRef.child('vipSubscriptions').child(sub.id).update({
        'status': 'cancelled',
      });

      // Update user profile
      await dbRef.child('users').child(sub.userId).update({
        'vipLevel': 0,
        'vipType': 'free',
        'vipEndDate': null,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã hủy VIP thành công'),
            backgroundColor: Colors.green,
          ),
        );
        _loadData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _bulkDeleteInactive() async {
    final inactiveSubscriptions = _allSubscriptions
        .where((sub) => sub.status == 'expired' || sub.status == 'cancelled')
        .toList();

    if (inactiveSubscriptions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Không có VIP đã hủy/hết hạn nào để xóa'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning, color: Colors.red),
            SizedBox(width: 8),
            Text('Xóa hàng loạt'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Bạn có chắc muốn xóa TẤT CẢ ${inactiveSubscriptions.length} subscription đã hủy/hết hạn?',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '• Đã hết hạn: ${inactiveSubscriptions.where((s) => s.status == 'expired').length}',
                  ),
                  Text(
                    '• Đã hủy: ${inactiveSubscriptions.where((s) => s.status == 'cancelled').length}',
                  ),
                  Text(
                    '• Tổng cộng: ${inactiveSubscriptions.length} subscription',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.red, size: 16),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Hành động này KHÔNG THỂ hoàn tác!',
                      style: TextStyle(
                        color: Colors.red,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Xóa tất cả'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      int deletedCount = 0;

      for (var sub in inactiveSubscriptions) {
        // Xóa subscription khỏi database
        await dbRef.child('vipSubscriptions').child(sub.id).remove();

        // Xóa khỏi lịch sử VIP của user
        await dbRef
            .child('users')
            .child(sub.userId)
            .child('vipPurchases')
            .child(sub.id)
            .remove();

        deletedCount++;
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 12),
                Text('Đã xóa $deletedCount subscription thành công'),
              ],
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
        _loadData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi khi xóa hàng loạt: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteSubscription(VipSubscription sub) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning, color: Colors.red),
            SizedBox(width: 8),
            Text('Xác nhận xóa'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Bạn có chắc muốn XÓA VĨNH VIỄN subscription này?',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Gói: ${sub.packageName}'),
                  Text('User ID: ${sub.userId}'),
                  Text('Trạng thái: ${sub.status}'),
                  Text(
                    'Hết hạn: ${_formatDate(sub.endDate.millisecondsSinceEpoch)}',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.red, size: 16),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Hành động này KHÔNG THỂ hoàn tác!',
                      style: TextStyle(
                        color: Colors.red,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Xóa vĩnh viễn'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      // Xóa subscription khỏi database
      await dbRef.child('vipSubscriptions').child(sub.id).remove();

      // Xóa khỏi lịch sử VIP của user
      await dbRef
          .child('users')
          .child(sub.userId)
          .child('vipPurchases')
          .child(sub.id)
          .remove();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 12),
                Text('Đã xóa subscription thành công'),
              ],
            ),
            backgroundColor: Colors.green,
          ),
        );
        _loadData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi khi xóa: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _extendSubscription(VipSubscription sub) async {
    int? days = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Gia hạn VIP'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Gia hạn thêm bao nhiêu ngày?'),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, 7),
                  child: const Text('7 ngày'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, 30),
                  child: const Text('30 ngày'),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
        ],
      ),
    );

    if (days == null) return;

    try {
      final newEndDate = sub.endDate.add(Duration(days: days));

      // Update subscription
      await dbRef.child('vipSubscriptions').child(sub.id).update({
        'endDate': newEndDate.millisecondsSinceEpoch,
        'status': 'active',
      });

      // Update user profile
      await dbRef.child('users').child(sub.userId).update({
        'vipEndDate': newEndDate.millisecondsSinceEpoch,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Đã gia hạn thêm $days ngày thành công'),
            backgroundColor: Colors.green,
          ),
        );
        _loadData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final formatter = NumberFormat.currency(locale: 'vi_VN', symbol: '₫');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Quản lý VIP'),
        backgroundColor: Colors.purple,
        foregroundColor: Colors.white,
        actions: [
          // Nút xóa hàng loạt
          IconButton(
            onPressed: _bulkDeleteInactive,
            icon: const Icon(Icons.delete_sweep),
            tooltip: 'Xóa tất cả VIP đã hủy/hết hạn',
          ),
          IconButton(
            onPressed: _loadData,
            icon: const Icon(Icons.refresh),
            tooltip: 'Làm mới',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Statistics Cards
                    _buildStatisticsSection(formatter),

                    const SizedBox(height: 24),

                    // Filters
                    _buildFiltersSection(),

                    const SizedBox(height: 16),

                    // Subscriptions List
                    _buildSubscriptionsList(formatter),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildStatisticsSection(NumberFormat formatter) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Thống kê VIP',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                '👑 VIP',
                _totalVipUsers.toString(),
                Colors.amber,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                '💎 Premium',
                _totalPremiumUsers.toString(),
                Colors.cyan,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                'Đang hoạt động',
                _activeSubscriptions.toString(),
                Colors.green,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                'Đã hết hạn',
                _expiredSubscriptions.toString(),
                Colors.grey,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _buildStatCard(
          'Tổng doanh thu',
          formatter.format(_totalRevenue),
          Colors.blue,
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              color: color.withOpacity(0.8),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFiltersSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Bộ lọc',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _statusFilter,
                    decoration: const InputDecoration(
                      labelText: 'Trạng thái',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'all', child: Text('Tất cả')),
                      DropdownMenuItem(
                        value: 'active',
                        child: Text('Hoạt động'),
                      ),
                      DropdownMenuItem(
                        value: 'expired',
                        child: Text('Hết hạn'),
                      ),
                      DropdownMenuItem(
                        value: 'cancelled',
                        child: Text('Đã hủy'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _statusFilter = value;
                          _applyFilters();
                        });
                      }
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _typeFilter,
                    decoration: const InputDecoration(
                      labelText: 'Loại gói',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'all', child: Text('Tất cả')),
                      DropdownMenuItem(value: 'vip', child: Text('👑 VIP')),
                      DropdownMenuItem(
                        value: 'premium',
                        child: Text('💎 Premium'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _typeFilter = value;
                          _applyFilters();
                        });
                      }
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubscriptionsList(NumberFormat formatter) {
    if (_filteredSubscriptions.isEmpty) {
      return Center(
        child: Column(
          children: [
            Icon(Icons.diamond, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'Không có subscription nào',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Danh sách (${_filteredSubscriptions.length})',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        ..._filteredSubscriptions.map(
          (sub) => _buildSubscriptionCard(sub, formatter),
        ),
      ],
    );
  }

  Widget _buildSubscriptionCard(VipSubscription sub, NumberFormat formatter) {
    final icon = sub.packageType == 'premium' ? '💎' : '👑';
    final color = sub.packageType == 'premium'
        ? const Color(0xFF00FFFF)
        : const Color(0xFFFFD700);
    final isActive = sub.isActive;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: isActive ? 4 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isActive ? BorderSide(color: color, width: 2) : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(icon, style: const TextStyle(fontSize: 32)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        sub.packageName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'User ID: ${sub.userId.substring(0, 8)}...',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: isActive ? Colors.green : Colors.grey[300],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    isActive ? 'Hoạt động' : 'Hết hạn',
                    style: TextStyle(
                      color: isActive ? Colors.white : Colors.grey[700],
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildInfoItem('Giá', formatter.format(sub.price)),
                _buildInfoItem(
                  'Còn lại',
                  isActive ? '${sub.daysRemaining} ngày' : 'Đã hết',
                ),
                _buildInfoItem(
                  'Hết hạn',
                  _formatDate(sub.endDate.millisecondsSinceEpoch),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (isActive) ...[
              // Nút cho VIP đang hoạt động
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _extendSubscription(sub),
                      icon: const Icon(Icons.add_circle_outline, size: 18),
                      label: const Text('Gia hạn'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.blue,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _cancelSubscription(sub),
                      icon: const Icon(Icons.cancel_outlined, size: 18),
                      label: const Text('Hủy VIP'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                      ),
                    ),
                  ),
                ],
              ),
            ] else ...[
              // Nút XÓA cho VIP đã hủy/hết hạn
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _deleteSubscription(sub),
                  icon: const Icon(Icons.delete_forever, size: 18),
                  label: const Text('Xóa vĩnh viễn'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red.shade700,
                    side: BorderSide(color: Colors.red.shade300),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  String _formatDate(int timestamp) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }
}
