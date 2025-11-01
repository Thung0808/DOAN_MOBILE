import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/vip_package_model.dart';
import '../services/vip_service_user.dart';
import 'vip_payment_page_user.dart';

/// Trang hiển thị danh sách các gói VIP cho USER
/// VIP áp dụng cho TẤT CẢ phòng của user
class VipPackagesPageUser extends StatefulWidget {
  const VipPackagesPageUser({super.key});

  @override
  State<VipPackagesPageUser> createState() => _VipPackagesPageUserState();
}

class _VipPackagesPageUserState extends State<VipPackagesPageUser> {
  final VipServiceUser _vipService = VipServiceUser();
  List<VipPackage> _packages = [];
  bool _isLoading = true;

  // 🔥 User VIP info
  int _currentVipLevel = 0; // 0=free, 1=vip, 2=premium
  bool _isVipActive = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      // Load packages
      final packages = _vipService.getAvailablePackages();

      // 🔥 Load current user VIP info
      final userProfile = await _vipService.getCurrentUserProfile();
      final vipLevel = userProfile?.vipLevel ?? 0;
      final vipEndDate = userProfile?.vipEndDate;

      final isActive =
          vipLevel > 0 &&
          vipEndDate != null &&
          DateTime.now().millisecondsSinceEpoch < vipEndDate;

      setState(() {
        _packages = packages;
        _currentVipLevel = isActive ? vipLevel : 0;
        _isVipActive = isActive;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi tải gói VIP: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // 🔥 Kiểm tra gói có được mua không
  bool _canPurchasePackage(VipPackage package) {
    if (!_isVipActive) return true; // Chưa có VIP thì mua được

    final packageLevel = package.type == 'premium' ? 2 : 1;

    // Không mua được nếu:
    // 1. Đang có gói này active
    // 2. Đang có gói cao hơn
    if (packageLevel <= _currentVipLevel) {
      return false;
    }

    return true;
  }

  String _getDisabledReason(VipPackage package) {
    if (!_isVipActive) return '';

    final packageLevel = package.type == 'premium' ? 2 : 1;

    if (packageLevel == _currentVipLevel) {
      return 'Bạn đang sử dụng gói này';
    } else if (packageLevel < _currentVipLevel) {
      return 'Bạn đang dùng gói cao hơn';
    }

    return '';
  }

  void _onPackageSelected(VipPackage package) {
    // 🔥 Kiểm tra có thể mua không
    if (!_canPurchasePackage(package)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_getDisabledReason(package)),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => VipPaymentPageUser(package: package),
      ),
    ).then((success) {
      if (success == true && mounted) {
        // Thanh toán thành công, quay lại trang trước
        Navigator.pop(context, true);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nâng cấp tài khoản VIP'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header info
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF2196F3), Color(0xFF00BCD4)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.diamond,
                                color: Colors.white,
                                size: 32,
                              ),
                            ),
                            const SizedBox(width: 16),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Nâng cấp VIP',
                                    style: TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    'Áp dụng cho TẤT CẢ phòng của bạn',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.white70,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.check_circle,
                                color: Colors.white,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Một lần mua, tất cả phòng đều được hưởng ưu đãi!',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.white.withOpacity(0.9),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Packages list grouped by type
                  _buildVipPackages(),
                  const SizedBox(height: 16),
                  _buildPremiumPackages(),
                ],
              ),
            ),
    );
  }

  Widget _buildVipPackages() {
    final vipPackages = _packages.where((p) => p.type == 'vip').toList();

    if (vipPackages.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Text('👑', style: TextStyle(fontSize: 24)),
            SizedBox(width: 8),
            Text(
              'Gói VIP',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Tất cả phòng của bạn có huy hiệu VIP và ưu tiên hiển thị',
          style: TextStyle(fontSize: 14, color: Colors.grey[600]),
        ),
        const SizedBox(height: 16),
        ...vipPackages.map(
          (package) => _buildPackageCard(
            package,
            canPurchase: _canPurchasePackage(package),
            disabledReason: _getDisabledReason(package),
          ),
        ),
      ],
    );
  }

  Widget _buildPremiumPackages() {
    final premiumPackages = _packages
        .where((p) => p.type == 'premium')
        .toList();

    if (premiumPackages.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('💎', style: TextStyle(fontSize: 24)),
            const SizedBox(width: 8),
            const Text(
              'Gói Premium',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.orange,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'RECOMMENDED',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Ưu tiên tuyệt đối + Analytics cho tất cả phòng của bạn',
          style: TextStyle(fontSize: 14, color: Colors.grey[600]),
        ),
        const SizedBox(height: 16),
        ...premiumPackages.map(
          (package) => _buildPackageCard(
            package,
            isRecommended: true,
            canPurchase: _canPurchasePackage(package),
            disabledReason: _getDisabledReason(package),
          ),
        ),
      ],
    );
  }

  Widget _buildPackageCard(
    VipPackage package, {
    bool isRecommended = false,
    bool canPurchase = true,
    String disabledReason = '',
  }) {
    final color = _getPackageColor(package.type);

    return Opacity(
      opacity: canPurchase ? 1.0 : 0.5,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: canPurchase
                ? (isRecommended ? color : Colors.grey[300]!)
                : Colors.grey[400]!,
            width: isRecommended ? 3 : 1,
          ),
          gradient: isRecommended && canPurchase
              ? LinearGradient(
                  colors: [color.withOpacity(0.1), Colors.white],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: isRecommended ? null : Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.2),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Stack(
          children: [
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: canPurchase ? () => _onPackageSelected(package) : null,
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Row(
                        children: [
                          Text(
                            package.icon,
                            style: const TextStyle(fontSize: 40),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  package.name,
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  package.description,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),

                      // Price
                      Row(
                        children: [
                          Text(
                            NumberFormat.currency(
                              locale: 'vi_VN',
                              symbol: '₫',
                            ).format(package.price),
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: color,
                            ),
                          ),
                          Text(
                            ' / ${package.durationDays} ngày',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                          if (package.durationDays == 30) ...[
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.green,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Text(
                                'TIẾT KIỆM',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),

                      const SizedBox(height: 20),

                      // Features
                      ...package.features.entries.map((entry) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Row(
                            children: [
                              Icon(Icons.check_circle, color: color, size: 20),
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

                      const SizedBox(height: 20),

                      // Button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: canPurchase
                              ? () => _onPackageSelected(package)
                              : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: canPurchase ? color : Colors.grey,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                package.icon,
                                style: const TextStyle(fontSize: 20),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                canPurchase ? 'Nâng cấp ngay' : disabledReason,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
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
            ),
            // 🔥 Badge "Đang sử dụng" ở góc trên phải
            if (!canPurchase)
              Positioned(
                top: 12,
                right: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.orange,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.orange.withOpacity(0.4),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.check_circle,
                        color: Colors.white,
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        disabledReason,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
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
}
