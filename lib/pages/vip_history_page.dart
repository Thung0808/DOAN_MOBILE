import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/vip_subscription_model.dart';
import '../services/vip_service_user.dart';

class VipHistoryPage extends StatefulWidget {
  const VipHistoryPage({super.key});

  @override
  State<VipHistoryPage> createState() => _VipHistoryPageState();
}

class _VipHistoryPageState extends State<VipHistoryPage> {
  final vipService = VipServiceUser();
  List<VipSubscription> _subscriptions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final history = await vipService.getUserVipHistory();
      if (mounted) {
        setState(() {
          _subscriptions = history;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi tải lịch sử: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Color _getPackageColor(String type) {
    // 🔥 VIP mới: Gold (VIP) và Aqua (Premium)
    // Map các loại cũ (boost, badge) về VIP (Gold)
    switch (type) {
      case 'vip':
      case 'badge': // VIP cũ
      case 'boost': // VIP cũ
        return const Color(0xFFFFD700); // Gold
      case 'premium':
        return const Color(0xFF00FFFF); // Aqua
      default:
        return Colors.grey;
    }
  }

  String _getPackageIcon(String type) {
    // 🔥 VIP mới: Emoji badge
    switch (type) {
      case 'vip':
      case 'badge': // VIP cũ
      case 'boost': // VIP cũ
        return '👑'; // VIP badge
      case 'premium':
        return '💎'; // Premium badge
      default:
        return '';
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'active':
        return 'Đang hoạt động';
      case 'expired':
        return 'Đã hết hạn';
      case 'cancelled':
        return 'Đã hủy';
      default:
        return 'Không xác định';
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'active':
        return Colors.green;
      case 'expired':
        return Colors.grey;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final formatter = NumberFormat.currency(locale: 'vi_VN', symbol: '₫');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Lịch Sử Gói VIP'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: _loadHistory,
            icon: const Icon(Icons.refresh),
            tooltip: 'Làm mới',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _subscriptions.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history, size: 80, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  Text(
                    'Chưa có gói VIP nào',
                    style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Nâng cấp VIP ngay để tăng hiệu quả!',
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _subscriptions.length,
              itemBuilder: (context, index) {
                final sub = _subscriptions[index];
                final color = _getPackageColor(sub.packageType);
                final isActive = sub.isActive;

                return Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  elevation: isActive ? 4 : 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: isActive
                        ? BorderSide(color: color, width: 2)
                        : BorderSide.none,
                  ),
                  child: Container(
                    decoration: isActive
                        ? BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            gradient: LinearGradient(
                              colors: [color.withOpacity(0.05), Colors.white],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          )
                        : null,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header with status
                          Row(
                            children: [
                              // Icon
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: color.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  _getPackageIcon(sub.packageType),
                                  style: const TextStyle(fontSize: 24),
                                ),
                              ),
                              const SizedBox(width: 12),
                              // Package name
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      sub.packageName,
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: color,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      formatter.format(sub.price),
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.black87,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // Status badge
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: _getStatusColor(
                                    sub.status,
                                  ).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: _getStatusColor(sub.status),
                                    width: 1,
                                  ),
                                ),
                                child: Text(
                                  _getStatusText(sub.status),
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: _getStatusColor(sub.status),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Divider
                          Divider(color: Colors.grey.shade200),
                          const SizedBox(height: 12),

                          // Details
                          _buildInfoRow(
                            'Thời gian bắt đầu',
                            _formatDate(sub.startDate),
                            Icons.calendar_today,
                          ),
                          const SizedBox(height: 8),
                          _buildInfoRow(
                            'Thời gian kết thúc',
                            _formatDate(sub.endDate),
                            Icons.event,
                          ),
                          const SizedBox(height: 8),
                          _buildInfoRow(
                            'Phương thức thanh toán',
                            _getPaymentMethodText(sub.paymentMethod),
                            Icons.payment,
                          ),

                          // Active subscription details
                          if (isActive) ...[
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.green.shade50,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.green.shade200,
                                ),
                              ),
                              child: Column(
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.access_time,
                                        color: Colors.green.shade700,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'Còn ${sub.daysRemaining} ngày',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.green.shade700,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  // Progress bar
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: LinearProgressIndicator(
                                      value: sub.usagePercent / 100,
                                      minHeight: 8,
                                      backgroundColor: Colors.green.shade100,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.green.shade600,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${sub.usagePercent.toStringAsFixed(0)}% đã sử dụng',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.green.shade700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }

  Widget _buildInfoRow(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey.shade600),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
            textAlign: TextAlign.end,
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    return DateFormat('dd/MM/yyyy HH:mm').format(date);
  }

  String _getPaymentMethodText(String method) {
    switch (method) {
      case 'vnpay':
        return 'VNPay';
      case 'momo':
        return 'MoMo';
      case 'zalopay':
        return 'ZaloPay';
      case 'bank_transfer':
        return 'Chuyển khoản';
      default:
        return method;
    }
  }
}
