import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../models/user_profile.dart';
import '../services/vip_service_user.dart';
import 'vip_packages_page_user.dart';

/// Trang hiển thị thông tin VIP của USER
class UserVipInfoPage extends StatefulWidget {
  const UserVipInfoPage({super.key});

  @override
  State<UserVipInfoPage> createState() => _UserVipInfoPageState();
}

class _UserVipInfoPageState extends State<UserVipInfoPage> {
  final VipServiceUser _vipService = VipServiceUser();
  final user = FirebaseAuth.instance.currentUser!;

  UserProfile? _userProfile;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      final profile = await _vipService.getCurrentUserProfile();

      setState(() {
        _userProfile = profile;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi tải dữ liệu: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _navigateToUpgrade() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const VipPackagesPageUser()),
    );

    if (result == true) {
      // Reload data after successful purchase
      _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Thông tin VIP'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Current VIP Status Card
                    _buildCurrentVipCard(),

                    const SizedBox(height: 24),

                    // VIP Benefits
                    if (_userProfile?.isVipActive == true) _buildVipBenefits(),

                    const SizedBox(height: 24),

                    // Upgrade button
                    if (_userProfile?.isVipActive != true)
                      _buildUpgradeSection()
                    else
                      _buildRenewSection(),

                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildCurrentVipCard() {
    final isVip = _userProfile?.isVipActive ?? false;
    final vipType = _userProfile?.vipType ?? 'free';
    final vipIcon = _userProfile?.vipIcon ?? '';
    final vipName = _userProfile?.vipName ?? 'Free';
    final daysRemaining = _userProfile?.vipDaysRemaining ?? 0;
    final isExpiringSoon = _userProfile?.isVipExpiringSoon ?? false;

    Color gradientStart;
    Color gradientEnd;

    if (vipType == 'premium') {
      gradientStart = const Color(0xFF00FFFF);
      gradientEnd = const Color(0xFF0080FF);
    } else if (vipType == 'vip') {
      gradientStart = const Color(0xFFFFD700);
      gradientEnd = const Color(0xFFFF8C00);
    } else {
      gradientStart = Colors.grey[400]!;
      gradientEnd = Colors.grey[600]!;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [gradientStart, gradientEnd],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: gradientStart.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          if (isVip)
            Text(vipIcon, style: const TextStyle(fontSize: 64))
          else
            const Icon(Icons.person, size: 64, color: Colors.white),
          const SizedBox(height: 16),
          Text(
            isVip ? 'Tài khoản $vipName' : 'Tài khoản Free',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          if (isVip) ...[
            if (isExpiringSoon)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.orange,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '⚠️ Còn $daysRemaining ngày',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              )
            else
              Text(
                'Còn $daysRemaining ngày',
                style: const TextStyle(fontSize: 16, color: Colors.white70),
              ),
            const SizedBox(height: 8),
            Text(
              'Hết hạn: ${DateFormat('dd/MM/yyyy').format(DateTime.fromMillisecondsSinceEpoch(_userProfile!.vipEndDate!))}',
              style: const TextStyle(fontSize: 14, color: Colors.white60),
            ),
          ] else ...[
            const Text(
              'Chưa có gói VIP',
              style: TextStyle(fontSize: 16, color: Colors.white70),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildVipBenefits() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quyền lợi hiện tại',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        _buildBenefitItem(
          Icons.star,
          Colors.amber,
          'Tất cả phòng có huy hiệu ${_userProfile!.vipIcon}',
        ),
        _buildBenefitItem(
          Icons.arrow_upward,
          Colors.green,
          'Ưu tiên hiển thị trên danh sách tìm kiếm',
        ),
        _buildBenefitItem(
          Icons.palette,
          Colors.blue,
          'Highlight màu nổi bật cho tất cả phòng',
        ),
        if (_userProfile!.vipType == 'premium') ...[
          _buildBenefitItem(
            Icons.analytics,
            Colors.purple,
            'Phân tích chi tiết lượt xem',
          ),
          _buildBenefitItem(
            Icons.support_agent,
            Colors.orange,
            'Hỗ trợ ưu tiên 24/7',
          ),
        ],
      ],
    );
  }

  Widget _buildBenefitItem(IconData icon, Color color, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 14))),
        ],
      ),
    );
  }

  Widget _buildUpgradeSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Nâng cấp VIP ngay!',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
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
              const Text(
                '✨ Với gói VIP, bạn sẽ nhận được:',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                '• Tất cả phòng có huy hiệu VIP/Premium\n'
                '• Ưu tiên hiển thị cao nhất\n'
                '• Tăng tỷ lệ cho thuê lên 3-5 lần\n'
                '• Tiết kiệm thời gian tìm khách',
                style: TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _navigateToUpgrade,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    '🚀 Nâng cấp VIP ngay',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRenewSection() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _navigateToUpgrade,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.orange,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: const Text(
          '🔄 Gia hạn hoặc Nâng cấp',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
