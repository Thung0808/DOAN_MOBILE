import 'package:flutter/material.dart';

/// Widget hiển thị huy hiệu VIP cho phòng
/// Note: VIP hiện tại theo USER, không theo phòng
class VipBadge extends StatelessWidget {
  final String vipType;
  final bool showLabel;
  final double size;

  const VipBadge({
    super.key,
    required this.vipType,
    this.showLabel = true,
    this.size = 24,
  });

  @override
  Widget build(BuildContext context) {
    String icon, label;
    Color color;

    switch (vipType) {
      case 'premium':
        icon = '💎';
        label = 'PREMIUM';
        color = const Color(0xFF00FFFF); // Aqua
        break;
      case 'badge':
        icon = '👑';
        label = 'VIP';
        color = const Color(0xFFFFD700); // Gold
        break;
      case 'boost':
        icon = '🚀';
        label = 'Đẩy tin';
        color = const Color(0xFFFFA500); // Orange
        break;
      default:
        return const SizedBox.shrink();
    }

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: showLabel ? 10 : 6,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.4),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(icon, style: TextStyle(fontSize: size)),
          if (showLabel) ...[
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Widget hiển thị thẻ VIP với thông tin chi tiết
class VipInfoCard extends StatelessWidget {
  final String vipType;
  final DateTime endDate;
  final VoidCallback? onRenew;

  const VipInfoCard({
    super.key,
    required this.vipType,
    required this.endDate,
    this.onRenew,
  });

  @override
  Widget build(BuildContext context) {
    final daysRemaining = endDate.difference(DateTime.now()).inDays;
    final isExpiringSoon = daysRemaining <= 3;

    String packageName;
    Color color;
    String icon;

    switch (vipType) {
      case 'premium':
        packageName = 'Premium';
        color = const Color(0xFF00FFFF);
        icon = '💎';
        break;
      case 'badge':
        packageName = 'VIP Badge';
        color = const Color(0xFFFFD700);
        icon = '👑';
        break;
      case 'boost':
        packageName = 'Boost';
        color = const Color(0xFFFFA500);
        icon = '🚀';
        break;
      default:
        packageName = 'Unknown';
        color = Colors.grey;
        icon = '⭐';
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withOpacity(0.2), color.withOpacity(0.05)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.5), width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(icon, style: const TextStyle(fontSize: 24)),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Gói $packageName',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      daysRemaining > 0
                          ? 'Còn $daysRemaining ngày'
                          : 'Đã hết hạn',
                      style: TextStyle(
                        fontSize: 14,
                        color: isExpiringSoon ? Colors.red : Colors.grey[700],
                        fontWeight: isExpiringSoon
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
              if (isExpiringSoon && onRenew != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.orange,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    '⚠️ Sắp hết',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Hết hạn: ${_formatDate(endDate)}',
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
          if (onRenew != null) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onRenew,
                style: ElevatedButton.styleFrom(
                  backgroundColor: color,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  isExpiringSoon ? '🔄 Gia hạn ngay' : '🚀 Nâng cấp',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }
}
