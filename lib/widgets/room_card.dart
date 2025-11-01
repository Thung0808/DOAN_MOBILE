import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/room_model.dart';

class RoomCard extends StatelessWidget {
  final Room room;
  final bool isFavorite;
  final VoidCallback? onTap;
  final VoidCallback? onFavoriteToggle;
  // Owner VIP info (từ UserProfile)
  final int ownerVipLevel;
  final String ownerVipType;

  const RoomCard({
    super.key,
    required this.room,
    this.isFavorite = false,
    this.onTap,
    this.onFavoriteToggle,
    this.ownerVipLevel = 0,
    this.ownerVipType = 'free',
  });

  // Check if owner has VIP
  bool get isOwnerVip => ownerVipLevel > 0;

  Color _getVipColor() {
    switch (ownerVipType) {
      case 'vip':
        return const Color(0xFFFFD700); // Gold
      case 'premium':
        return const Color(0xFF00FFFF); // Aqua
      default:
        return Colors.grey;
    }
  }

  String _getVipIcon() {
    switch (ownerVipType) {
      case 'vip':
        return '👑'; // VIP badge
      case 'premium':
        return '💎'; // Premium badge
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final formatter = NumberFormat.currency(locale: 'vi_VN', symbol: '₫');

    // 🚀 Removed debug logs for performance

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      elevation: isOwnerVip ? 4 : 2,
      clipBehavior: Clip.antiAlias,
      shape: isOwnerVip
          ? RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: _getVipColor(), width: 2.5),
            )
          : RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      shadowColor: isOwnerVip
          ? _getVipColor().withValues(alpha: 0.3)
          : Colors.black.withValues(alpha: 0.15),
      child: Container(
        decoration: isOwnerVip
            ? BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.white,
                    _getVipColor().withValues(alpha: 0.03),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              )
            : null,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Image on the left
              GestureDetector(
                onTap: onTap,
                child: Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(isOwnerVip ? 14 : 14),
                        bottomLeft: Radius.circular(isOwnerVip ? 14 : 14),
                      ),
                      child: Container(
                        width: 130,
                        height: 150,
                        color: Colors.grey[300],
                        child: room.images.isNotEmpty
                            ? Image.network(
                                room.images.first,
                                fit: BoxFit.cover,
                                // 🚀 Enable caching
                                cacheWidth: 400, // Giảm kích thước cache
                                cacheHeight: 400,
                                loadingBuilder:
                                    (context, child, loadingProgress) {
                                      if (loadingProgress == null) return child;
                                      return Center(
                                        child: CircularProgressIndicator(
                                          value:
                                              loadingProgress
                                                      .expectedTotalBytes !=
                                                  null
                                              ? loadingProgress
                                                        .cumulativeBytesLoaded /
                                                    loadingProgress
                                                        .expectedTotalBytes!
                                              : null,
                                          strokeWidth: 2,
                                        ),
                                      );
                                    },
                                errorBuilder: (context, error, stackTrace) {
                                  return const Center(
                                    child: Icon(
                                      Icons.image_not_supported,
                                      size: 40,
                                    ),
                                  );
                                },
                              )
                            : const Center(
                                child: Icon(
                                  Icons.home,
                                  size: 40,
                                  color: Colors.grey,
                                ),
                              ),
                      ),
                    ),
                    // VIP Badge (emoji)
                    if (isOwnerVip)
                      Positioned(
                        top: 6,
                        left: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: _getVipColor(),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: _getVipColor().withValues(alpha: 0.5),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Text(
                            _getVipIcon(),
                            style: const TextStyle(fontSize: 16),
                          ),
                        ),
                      ),
                    // 🔥 Availability Status Badge
                    if (room.availabilityStatus == 'DaDatLich')
                      Positioned(
                        bottom: 6,
                        left: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.orange.withValues(alpha: 0.9),
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.orange.withValues(alpha: 0.4),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.schedule,
                                size: 12,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Có lịch xem',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    // Favorite button
                    Positioned(
                      top: 4,
                      right: 4,
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: onFavoriteToggle,
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.black38,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Icon(
                              isFavorite
                                  ? Icons.favorite
                                  : Icons.favorite_border,
                              color: isFavorite ? Colors.red : Colors.white,
                              size: 22,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Info on the right
              Expanded(
                child: InkWell(
                  onTap: onTap,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Title - Large font
                        Text(
                          room.title,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        // Location
                        Row(
                          children: [
                            const Icon(
                              Icons.location_on,
                              size: 12,
                              color: Colors.grey,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                room.province.isNotEmpty
                                    ? '${room.ward}, ${room.district}, ${room.province}'
                                    : '${room.ward}, ${room.district}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey[600],
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        // Price and Area
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                formatter.format(room.price),
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.red,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.blue[50],
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '${room.area} m²',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.blue,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        // Rating and View Count combined
                        Row(
                          children: [
                            // Rating
                            Icon(
                              Icons.star,
                              size: 12,
                              color:
                                  room.reviewCount > 0 && room.averageRating > 0
                                  ? Colors.amber
                                  : Colors.grey[400],
                            ),
                            const SizedBox(width: 2),
                            Text(
                              room.reviewCount > 0 && room.averageRating > 0
                                  ? '${room.averageRating.toStringAsFixed(1)} (${room.reviewCount})'
                                  : 'Chưa có đánh giá',
                              style: TextStyle(
                                fontSize: 11,
                                color:
                                    room.reviewCount > 0 &&
                                        room.averageRating > 0
                                    ? Colors.amber[700]
                                    : Colors.grey[600],
                                fontWeight:
                                    room.reviewCount > 0 &&
                                        room.averageRating > 0
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                              ),
                            ),
                            // View Count for VIP
                            if (isOwnerVip) ...[
                              const SizedBox(width: 8),
                              const Text(
                                '•',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Icon(
                                Icons.visibility,
                                size: 11,
                                color: _getVipColor(),
                              ),
                              const SizedBox(width: 2),
                              Text(
                                '${room.viewCount}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: _getVipColor(),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
