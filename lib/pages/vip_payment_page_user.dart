import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:intl/intl.dart';
import '../models/vip_package_model.dart';
import '../services/stripe_service.dart';
import '../services/vip_service_user.dart';

/// Trang thanh toán VIP Package cho USER qua Stripe
class VipPaymentPageUser extends StatefulWidget {
  final VipPackage package;

  const VipPaymentPageUser({super.key, required this.package});

  @override
  State<VipPaymentPageUser> createState() => _VipPaymentPageUserState();
}

class _VipPaymentPageUserState extends State<VipPaymentPageUser> {
  final StripeService _stripeService = StripeService();
  final VipServiceUser _vipService = VipServiceUser();
  bool _isProcessing = false;

  Future<void> _handlePayment() async {
    setState(() => _isProcessing = true);

    try {
      // BƯỚC 1: Tạo Payment Intent cho User VIP
      final paymentData = await _stripeService.createVipPaymentIntent(
        packageId: widget.package.id,
        packageName: widget.package.name,
        packageType: widget.package.type,
        amount: widget.package.price.toDouble(),
        roomId: 'user_vip', // Không cần roomId cho user VIP
        roomTitle: 'Nâng cấp tài khoản ${widget.package.name}',
      );

      if (paymentData == null) {
        throw Exception('Không thể tạo payment intent');
      }

      final clientSecret = paymentData['clientSecret'] as String;
      final paymentIntentId = paymentData['paymentIntentId'] as String;

      // BƯỚC 2: Initialize Payment Sheet
      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          paymentIntentClientSecret: clientSecret,
          merchantDisplayName: 'Tìm Trọ',
          style: ThemeMode.light,
        ),
      );

      // BƯỚC 3: Present Payment Sheet
      await Stripe.instance.presentPaymentSheet();

      // BƯỚC 4: Thanh toán thành công → Kích hoạt VIP cho USER
      await _vipService.purchaseVipPackage(
        package: widget.package,
        paymentMethod: 'stripe',
        paymentId: paymentIntentId,
      );

      // BƯỚC 5: Lưu payment record
      await _stripeService.saveSuccessfulPayment(
        paymentIntentId: paymentIntentId,
        amount: widget.package.price.toDouble(),
        roomId: 'user_vip',
        roomTitle: 'Nâng cấp ${widget.package.name}',
      );

      setState(() => _isProcessing = false);

      if (mounted) {
        _showSuccessDialog();
      }
    } on StripeException catch (e) {
      setState(() => _isProcessing = false);

      if (mounted) {
        if (e.error.code == FailureCode.Canceled) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Đã hủy thanh toán'),
              backgroundColor: Colors.orange,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Lỗi thanh toán: ${e.error.message}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      setState(() => _isProcessing = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Text(widget.package.icon, style: const TextStyle(fontSize: 32)),
            const SizedBox(width: 12),
            const Text('Chúc mừng!'),
          ],
        ),
        content: Text(
          'Bạn đã nâng cấp thành công "${widget.package.name}"!\n\n'
          '✅ Tất cả phòng của bạn đều được hưởng quyền lợi VIP\n'
          '✅ Hiệu lực: ${widget.package.durationDays} ngày\n'
          '✅ Phòng sẽ được ưu tiên hiển thị ngay!',
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context); // Đóng dialog
              Navigator.pop(context, true); // Về trang trước với success
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: const Text('Tuyệt vời!'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Nâng cấp ${widget.package.name}'),
        backgroundColor: _getPackageColor(widget.package.type),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Package info card với gradient
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: _getGradientColors(widget.package.type),
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: _getPackageColor(
                      widget.package.type,
                    ).withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Text(
                    widget.package.icon,
                    style: const TextStyle(fontSize: 56),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    widget.package.name,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    NumberFormat.currency(
                      locale: 'vi_VN',
                      symbol: '₫',
                    ).format(widget.package.price),
                    style: const TextStyle(
                      fontSize: 40,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Hiệu lực: ${widget.package.durationDays} ngày',
                    style: const TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Áp dụng cho tất cả phòng
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF4CAF50), Color(0xFF45A049)],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Áp dụng cho TẤT CẢ phòng',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Một lần mua, tất cả phòng đều được hưởng ưu đãi!',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.white.withOpacity(0.9),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Features list
            const Text(
              'Quyền lợi bạn nhận được:',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ...widget.package.features.entries.map((entry) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.check_circle,
                        color: Colors.green,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _getFeatureLabel(entry.key),
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),

            const SizedBox(height: 24),

            // Test card info
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: Colors.blue[700],
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Thẻ test (Stripe Test Mode)',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue[900],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildTestCardInfo('Thành công:', '4242 4242 4242 4242'),
                  const SizedBox(height: 4),
                  _buildTestCardInfo('MM/YY:', 'Bất kỳ (tương lai)'),
                  const SizedBox(height: 4),
                  _buildTestCardInfo('CVC:', 'Bất kỳ 3 số'),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Pay button
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _isProcessing ? null : _handlePayment,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _getPackageColor(widget.package.type),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                ),
                child: _isProcessing
                    ? const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          ),
                          SizedBox(width: 12),
                          Text('Đang xử lý...'),
                        ],
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.lock_outline),
                          const SizedBox(width: 8),
                          Text(
                            'Thanh toán ${NumberFormat.currency(locale: 'vi_VN', symbol: '₫').format(widget.package.price)}',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
              ),
            ),

            const SizedBox(height: 16),

            // Powered by Stripe
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Thanh toán an toàn bởi',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
                const SizedBox(width: 4),
                Text(
                  'Stripe',
                  style: TextStyle(
                    color: Colors.grey[800],
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(Icons.security, size: 14, color: Colors.grey[600]),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTestCardInfo(String label, String value) {
    return Row(
      children: [
        SizedBox(
          width: 90,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.blue[700],
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Text(
          value,
          style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
        ),
      ],
    );
  }

  String _getFeatureLabel(String featureKey) {
    const Map<String, String> labels = {
      'topPosition': 'Ưu tiên hiển thị cao nhất',
      'vipBadge': 'Huy hiệu VIP/Premium trên tất cả phòng',
      'highlight': 'Highlight màu nổi bật',
      'showViews': 'Hiển thị số lượt xem chi tiết',
      'priorityDisplay': 'Phòng lên đầu danh sách tìm kiếm',
      'prioritySupport': 'Hỗ trợ ưu tiên từ admin',
      'autoBoost': 'Tự động làm mới vị trí hàng ngày',
      'analytics': 'Phân tích chi tiết (views, clicks, traffic)',
    };
    return labels[featureKey] ?? featureKey;
  }

  Color _getPackageColor(String type) {
    switch (type) {
      case 'premium':
        return const Color(0xFF00FFFF); // Aqua
      case 'vip':
        return const Color(0xFFFFD700); // Gold
      default:
        return Colors.blue;
    }
  }

  List<Color> _getGradientColors(String type) {
    switch (type) {
      case 'premium':
        return [const Color(0xFF00FFFF), const Color(0xFF0080FF)];
      case 'vip':
        return [const Color(0xFFFFD700), const Color(0xFFFF8C00)];
      default:
        return [Colors.blue, Colors.blue[700]!];
    }
  }
}
