import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'services/stripe_service.dart';

class StripePaymentPage extends StatefulWidget {
  final double amount;
  final String? bookingId;
  final String? roomId;
  final String? roomTitle;
  final bool isDeposit; // Đặt cọc hay thanh toán toàn bộ
  final double? fullPrice; // Giá đầy đủ (nếu là đặt cọc)

  const StripePaymentPage({
    super.key,
    required this.amount,
    this.bookingId,
    this.roomId,
    this.roomTitle,
    this.isDeposit = false,
    this.fullPrice,
  });

  @override
  State<StripePaymentPage> createState() => _StripePaymentPageState();
}

class _StripePaymentPageState extends State<StripePaymentPage> {
  final StripeService _stripeService = StripeService();
  bool _isProcessing = false;

  Future<void> _handlePayment() async {
    setState(() => _isProcessing = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('Bạn cần đăng nhập');
      }

      // 1. Tạo Payment Intent từ backend
      final description = widget.isDeposit
          ? (widget.roomTitle != null
                ? 'Đặt cọc 30% - ${widget.roomTitle}'
                : 'Đặt cọc 30% phòng')
          : (widget.roomTitle != null
                ? 'Thanh toán ${widget.roomTitle}'
                : 'Thanh toán đặt phòng');

      final paymentIntentData = await _stripeService.createPaymentIntent(
        amount: widget.amount,
        currency: 'vnd',
        description: description,
        bookingId: widget.bookingId,
        roomId: widget.roomId,
      );

      if (paymentIntentData == null) {
        throw Exception('Không thể tạo payment intent');
      }

      final clientSecret = paymentIntentData['clientSecret'] as String;
      final paymentIntentId = paymentIntentData['paymentIntentId'] as String;

      // 2. Initialize Payment Sheet
      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          paymentIntentClientSecret: clientSecret,
          merchantDisplayName: 'Tìm Trọ',
          style: ThemeMode.light,
        ),
      );

      // 3. Present Payment Sheet
      await Stripe.instance.presentPaymentSheet();

      // 4. Payment thành công - Lưu vào Firebase
      await _stripeService.saveSuccessfulPayment(
        paymentIntentId: paymentIntentId,
        amount: widget.amount,
        bookingId: widget.bookingId,
        roomId: widget.roomId,
        roomTitle: widget.roomTitle,
      );

      setState(() => _isProcessing = false);

      if (mounted) {
        _showSuccessDialog();
      }
    } on StripeException catch (e) {
      setState(() => _isProcessing = false);

      if (mounted) {
        if (e.error.code == FailureCode.Canceled) {
          // User đã cancel
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Đã hủy thanh toán'),
              backgroundColor: Colors.orange,
            ),
          );
        } else {
          // Lỗi khác
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
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 32),
            SizedBox(width: 12),
            Text('Thành công!'),
          ],
        ),
        content: Text(
          widget.isDeposit
              ? 'Đặt cọc 30% đã được xử lý thành công. Bạn sẽ trả 70% còn lại khi nhận phòng.'
              : 'Thanh toán đã được xử lý thành công.',
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
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isDeposit ? 'Đặt cọc 30%' : 'Thanh toán Stripe'),
        backgroundColor: const Color(0xFF635BFF), // Stripe color
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Amount display
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF635BFF), Color(0xFF00D4FF)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF635BFF).withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Text(
                    widget.isDeposit ? 'Đặt cọc 30%' : 'Số tiền thanh toán',
                    style: const TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    NumberFormat.currency(
                      locale: 'vi_VN',
                      symbol: '₫',
                    ).format(widget.amount),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (widget.isDeposit && widget.fullPrice != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Tổng giá: ${NumberFormat.currency(locale: 'vi_VN', symbol: '₫').format(widget.fullPrice!)}',
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      'Còn lại 70%: ${NumberFormat.currency(locale: 'vi_VN', symbol: '₫').format((widget.fullPrice! * 0.7).round())} (trả khi nhận phòng)',
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 12,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                  if (widget.roomTitle != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      widget.roomTitle!,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Info về Payment Sheet
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue[700], size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Nhấn nút thanh toán để mở form nhập thẻ an toàn của Stripe',
                      style: TextStyle(fontSize: 14, color: Colors.grey[800]),
                    ),
                  ),
                ],
              ),
            ),

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
                  _buildTestCardInfo('Thất bại:', '4000 0000 0000 0002'),
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
                  backgroundColor: const Color(0xFF635BFF),
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
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.lock_outline),
                          SizedBox(width: 8),
                          Text(
                            'Thanh toán ngay',
                            style: TextStyle(
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
                  'Powered by',
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
}
