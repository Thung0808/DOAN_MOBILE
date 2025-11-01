import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'models/room_model.dart';
import 'widgets/room_card.dart';
import 'widgets/room_reviews_widget.dart';
import 'user_chat_page.dart';
import 'room_map_page.dart';
import 'booking_page.dart';
import 'review_page.dart';
import 'services/favorite_service.dart';
import 'services/trust_score_service.dart';
import 'widgets/trust_score_badge.dart';
import 'widgets/room_image_carousel.dart';

class RoomDetailPage extends StatefulWidget {
  final Room room;

  const RoomDetailPage({super.key, required this.room});

  @override
  State<RoomDetailPage> createState() => _RoomDetailPageState();
}

class _RoomDetailPageState extends State<RoomDetailPage> {
  final user = FirebaseAuth.instance.currentUser!;
  final dbRef = FirebaseDatabase.instance.ref();
  final favoriteService = FavoriteService();
  List<Room> _suggestedRooms = [];
  int _currentViewCount = 0; // 🚀 Track current view count

  // 🔥 Cache owner VIP info với TTL
  final Map<String, Map<String, dynamic>> _ownerVipCache = {};
  static const int _cacheExpirySeconds = 30;

  // 🔥 Helper: Load owner VIP info with cache + TTL
  Future<Map<String, dynamic>> _loadOwnerVipInfo(String ownerId) async {
    if (_ownerVipCache.containsKey(ownerId)) {
      final cached = _ownerVipCache[ownerId]!;
      final cachedTime = cached['_cachedAt'] as int? ?? 0;
      final now = DateTime.now().millisecondsSinceEpoch;
      final expiryTime = _cacheExpirySeconds * 1000;

      if (now - cachedTime < expiryTime) {
        return cached;
      }
      _ownerVipCache.remove(ownerId);
    }

    try {
      final ownerSnap = await dbRef.child('users').child(ownerId).get();
      if (ownerSnap.exists) {
        final ownerData = ownerSnap.value as Map;
        final vipLevel = ownerData['vipLevel'] ?? 0;
        final vipType = ownerData['vipType'] ?? 'free';
        final vipEndDate = ownerData['vipEndDate'];

        final isActive =
            vipLevel > 0 &&
            vipEndDate != null &&
            DateTime.now().millisecondsSinceEpoch < vipEndDate;

        final result = {
          'vipLevel': isActive ? vipLevel : 0,
          'vipType': isActive ? vipType : 'free',
          'isVip': isActive,
          '_cachedAt': DateTime.now().millisecondsSinceEpoch,
        };

        _ownerVipCache[ownerId] = result;
        return result;
      }
    } catch (e) {
      print('❌ Error loading owner VIP: $e');
    }

    final defaultResult = {
      'vipLevel': 0,
      'vipType': 'free',
      'isVip': false,
      '_cachedAt': DateTime.now().millisecondsSinceEpoch,
    };
    _ownerVipCache[ownerId] = defaultResult;
    return defaultResult;
  }

  Future<void> _loadOwnerVipInfoBatch(List<Room> rooms) async {
    final ownerIds = rooms.map((r) => r.ownerId).toSet();
    await Future.wait(ownerIds.map((id) => _loadOwnerVipInfo(id)));
  }

  @override
  void initState() {
    super.initState();
    _currentViewCount = widget.room.viewCount; // Initialize with current count
    _loadSuggestedRooms();
    _incrementViewCount();
    _addToViewedHistory();
  }

  void _showFullscreenImage(BuildContext context, int initialIndex) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _FullscreenImageViewer(
          images: widget.room.images,
          initialIndex: initialIndex,
          roomId: widget.room.id,
        ),
      ),
    );
  }

  Future<void> _incrementViewCount() async {
    try {
      // 🚀 Optimistic update - tăng ngay lập tức
      if (mounted) {
        setState(() {
          _currentViewCount++;
        });
      }

      // 🚀 Dùng transaction để tăng view count an toàn
      final viewCountRef = dbRef
          .child('rooms')
          .child(widget.room.id)
          .child('viewCount');

      await viewCountRef.runTransaction((currentValue) {
        // Nếu chưa có viewCount, khởi tạo = 0
        int current = 0;
        if (currentValue != null) {
          if (currentValue is int) {
            current = currentValue;
          } else if (currentValue is double) {
            current = currentValue.toInt();
          }
        }

        // Tăng lên 1
        return Transaction.success(current + 1);
      });

      print(
        '✅ Đã tăng view count: ${widget.room.title} - View count: $_currentViewCount',
      );
    } catch (e) {
      print('❌ Lỗi tăng view count: $e');
      // Rollback on error
      if (mounted) {
        setState(() {
          _currentViewCount = widget.room.viewCount;
        });
      }
    }
  }

  Future<void> _addToViewedHistory() async {
    try {
      // Thêm vào lịch sử xem của user
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      await dbRef
          .child('users')
          .child(user.uid)
          .child('viewedRooms')
          .child(widget.room.id)
          .set({
            'roomId': widget.room.id,
            'roomTitle': widget.room.title,
            'roomAddress': widget.room.address,
            'roomPrice': widget.room.price,
            'viewedAt': timestamp,
          });
    } catch (e) {
      print('❌ Lỗi thêm vào lịch sử xem: $e');
    }
  }

  Future<void> _loadSuggestedRooms() async {
    try {
      // Load user favorites
      // Không cần load favorites nữa vì đã sử dụng StreamBuilder

      // Load all approved rooms
      final roomsSnapshot = await dbRef
          .child('rooms')
          .orderByChild('status')
          .equalTo('approved')
          .get();

      if (!roomsSnapshot.exists || roomsSnapshot.value == null) return;

      final roomsMap = roomsSnapshot.value as Map;
      final allRooms = <Room>[];

      roomsMap.forEach((key, value) {
        if (value != null && key != widget.room.id) {
          allRooms.add(Room.fromMap(key, value as Map));
        }
      });

      // Filter rooms by same district
      final sameCityRooms = allRooms.where((room) {
        return room.district == widget.room.district;
      }).toList();

      // Sort by price similarity
      sameCityRooms.sort((a, b) {
        final aDiff = (a.price - widget.room.price).abs();
        final bDiff = (b.price - widget.room.price).abs();
        return aDiff.compareTo(bDiff);
      });

      // Take top 10
      final suggestedRooms = sameCityRooms.take(10).toList();

      // 🔥 Load owner VIP info
      await _loadOwnerVipInfoBatch(suggestedRooms);

      if (mounted) {
        setState(() {
          _suggestedRooms = suggestedRooms;
        });
      }
    } catch (e) {
      print('❌ Lỗi load bài đăng đề xuất: $e');
    }
  }

  Future<void> _toggleSuggestedFavorite(String roomId) async {
    try {
      await favoriteService.toggleFavorite(roomId);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Có lỗi xảy ra, vui lòng thử lại'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _toggleFavorite() async {
    try {
      final isNowFavorite = await favoriteService.toggleFavorite(
        widget.room.id,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isNowFavorite ? 'Đã thêm vào yêu thích' : 'Đã xóa khỏi yêu thích',
            ),
            duration: const Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Có lỗi xảy ra, vui lòng thử lại'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback? onPressed, // 🔥 Allow null for disabled state
  }) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(
        label,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: color.withValues(alpha: 0.1),
        foregroundColor: color,
        elevation: 0,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: color.withValues(alpha: 0.3)),
        ),
        disabledBackgroundColor: Colors.grey.withValues(
          alpha: 0.1,
        ), // 🔥 Disabled style
        disabledForegroundColor: Colors.grey,
      ),
    );
  }

  void _reportRoom() {
    String? selectedReason;
    final descriptionController = TextEditingController();
    final reasons = [
      'Thông tin không chính xác',
      'Hình ảnh giả mạo',
      'Giá cả không hợp lý',
      'Lừa đảo',
      'Nội dung không phù hợp',
      'Trùng lặp bài đăng',
      'Spam',
      'Khác',
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 20,
            right: 20,
            top: 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.flag, color: Colors.red, size: 28),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Báo cáo bài đăng',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Vui lòng chọn lý do báo cáo',
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 20),
                // Reasons list
                ...reasons.map((reason) {
                  return RadioListTile<String>(
                    value: reason,
                    groupValue: selectedReason,
                    title: Text(reason),
                    activeColor: Colors.red,
                    contentPadding: EdgeInsets.zero,
                    onChanged: (value) {
                      setModalState(() {
                        selectedReason = value;
                      });
                    },
                  );
                }).toList(),
                const SizedBox(height: 16),
                // Description
                TextField(
                  controller: descriptionController,
                  maxLines: 4,
                  decoration: InputDecoration(
                    labelText: 'Mô tả chi tiết (không bắt buộc)',
                    hintText: 'Nhập thông tin chi tiết về vấn đề...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                // Submit button
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: selectedReason == null
                        ? null
                        : () async {
                            try {
                              // Save report to Firebase
                              final reportRef = dbRef.child('reports').push();
                              await reportRef.set({
                                'roomId': widget.room.id,
                                'roomTitle': widget.room.title,
                                'reporterId': user.uid,
                                'reporterName':
                                    user.displayName ?? 'Người dùng',
                                'reporterEmail': user.email ?? '',
                                'reason': selectedReason,
                                'description': descriptionController.text
                                    .trim(),
                                'timestamp':
                                    DateTime.now().millisecondsSinceEpoch,
                                'status': 'pending',
                              });

                              if (mounted) {
                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Row(
                                      children: [
                                        Icon(
                                          Icons.check_circle,
                                          color: Colors.white,
                                        ),
                                        SizedBox(width: 12),
                                        Expanded(
                                          child: Text(
                                            'Đã gửi báo cáo thành công!\nAdmin sẽ xem xét trong thời gian sớm nhất.',
                                          ),
                                        ),
                                      ],
                                    ),
                                    backgroundColor: Colors.green,
                                    duration: Duration(seconds: 4),
                                  ),
                                );
                              }
                            } catch (e) {
                              if (mounted) {
                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Row(
                                      children: [
                                        const Icon(
                                          Icons.error,
                                          color: Colors.white,
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Text(
                                            'Lỗi gửi báo cáo: ${e.toString()}\n'
                                            'Vui lòng kiểm tra kết nối và thử lại.',
                                          ),
                                        ),
                                      ],
                                    ),
                                    backgroundColor: Colors.red,
                                    duration: const Duration(seconds: 5),
                                    action: SnackBarAction(
                                      label: 'Đóng',
                                      textColor: Colors.white,
                                      onPressed: () {},
                                    ),
                                  ),
                                );
                              }
                            }
                          },
                    icon: const Icon(Icons.send),
                    label: const Text(
                      'Gửi báo cáo',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final formatter = NumberFormat.currency(locale: 'vi_VN', symbol: '₫');

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // Image Carousel AppBar
            SliverAppBar(
              expandedHeight: 250,
              pinned: true,
              backgroundColor: Colors.blue.shade600,
              iconTheme: const IconThemeData(color: Colors.white),
              leading: IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                tooltip: 'Quay lại',
              ),
              flexibleSpace: FlexibleSpaceBar(
                background: RoomImageCarousel(
                  images: widget.room.images,
                  roomId: widget.room.id,
                  height: 350,
                  onImageTap: (index) {
                    _showFullscreenImage(context, index);
                  },
                ),
              ),
            ),

            // Content
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Price & Area
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            formatter.format(widget.room.price),
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.red,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.blue[50],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${widget.room.area} m²',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // 🔥 Availability Status Badge
                    if (widget.room.availabilityStatus == 'DaDatLich')
                      Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.orange.withValues(alpha: 0.5),
                            width: 1.5,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.schedule,
                              size: 18,
                              color: Colors.orange[700],
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Phòng đã có người đặt lịch xem - Bạn vẫn có thể đặt lịch hoặc đặt cọc trước',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.orange[700],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (widget.room.availabilityStatus == 'DaDatCoc')
                      Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.red.withValues(alpha: 0.5),
                            width: 1.5,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.lock, size: 18, color: Colors.red[700]),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Phòng đã được đặt cọc - Không thể đặt lịch hoặc đặt cọc thêm',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.red[700],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                    // Title
                    Text(
                      widget.room.title,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Location
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on,
                          color: Colors.red,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${widget.room.address}, ${widget.room.ward}, ${widget.room.district}, ${widget.room.province}',
                            style: const TextStyle(fontSize: 15),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Google Maps (if location available)
                    if (widget.room.latitude != null &&
                        widget.room.longitude != null) ...[
                      Container(
                        height: 200,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey[300]!),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: FlutterMap(
                            options: MapOptions(
                              initialCenter: LatLng(
                                widget.room.latitude!,
                                widget.room.longitude!,
                              ),
                              initialZoom: 15.0,
                              interactionOptions: const InteractionOptions(
                                flags: InteractiveFlag.all,
                              ),
                            ),
                            children: [
                              TileLayer(
                                urlTemplate:
                                    'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                userAgentPackageName: 'com.example.demo',
                              ),
                              MarkerLayer(
                                markers: [
                                  Marker(
                                    point: LatLng(
                                      widget.room.latitude!,
                                      widget.room.longitude!,
                                    ),
                                    width: 80,
                                    height: 80,
                                    child: const Icon(
                                      Icons.location_on,
                                      color: Colors.red,
                                      size: 40,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],

                    // Description
                    const Text(
                      'Mô tả',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.room.description,
                      style: const TextStyle(fontSize: 15, height: 1.5),
                    ),
                    const SizedBox(height: 24),

                    // Amenities
                    if (widget.room.amenities.isNotEmpty) ...[
                      const Text(
                        'Tiện nghi',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: widget.room.amenities.map((amenity) {
                          return Chip(
                            label: Text(amenity),
                            avatar: const Icon(Icons.check, size: 16),
                            backgroundColor: Colors.green[50],
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 24),
                    ],

                    // Action Buttons
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey[200]!),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Hành động',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              // Yêu thích
                              Expanded(
                                child: ValueListenableBuilder<Set<String>>(
                                  valueListenable:
                                      favoriteService.favoritesNotifier,
                                  builder: (context, favorites, child) {
                                    final isFavorite = favorites.contains(
                                      widget.room.id,
                                    );
                                    return _buildActionButton(
                                      icon: isFavorite
                                          ? Icons.favorite
                                          : Icons.favorite_border,
                                      label: isFavorite
                                          ? 'Đã yêu thích'
                                          : 'Yêu thích',
                                      color: isFavorite
                                          ? Colors.red
                                          : Colors.grey,
                                      onPressed: _toggleFavorite,
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              // Báo cáo
                              Expanded(
                                child: _buildActionButton(
                                  icon: Icons.flag,
                                  label: 'Báo cáo',
                                  color: Colors.orange,
                                  onPressed: _reportRoom,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              // Xem bản đồ
                              Expanded(
                                child: _buildActionButton(
                                  icon: Icons.map,
                                  label: 'Xem bản đồ',
                                  color: Colors.blue,
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            RoomMapPage(room: widget.room),
                                      ),
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              // Nhắn tin - chỉ hiện khi không phải phòng của mình
                              if (widget.room.ownerId != user.uid)
                                Expanded(
                                  child: _buildActionButton(
                                    icon: Icons.chat_bubble,
                                    label: 'Nhắn tin',
                                    color: Colors.green,
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => UserChatPage(
                                            receiverId: widget.room.ownerId,
                                            receiverName: widget.room.ownerName,
                                            receiverEmail:
                                                widget.room.ownerPhone,
                                            roomTitle: widget.room.title,
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                )
                              else
                                const Expanded(child: SizedBox()),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              // Đặt lịch - chỉ hiện khi không phải phòng của mình và phòng chưa được đặt cọc
                              if (widget.room.ownerId != user.uid)
                                Expanded(
                                  child: _buildActionButton(
                                    icon:
                                        widget.room.availabilityStatus ==
                                            'DaDatCoc'
                                        ? Icons.lock
                                        : Icons.event,
                                    label:
                                        widget.room.availabilityStatus ==
                                            'DaDatCoc'
                                        ? 'Đã đặt cọc'
                                        : 'Đặt lịch xem',
                                    color:
                                        widget.room.availabilityStatus ==
                                            'DaDatCoc'
                                        ? Colors.grey
                                        : Colors.orange,
                                    onPressed:
                                        widget.room.availabilityStatus ==
                                            'DaDatCoc'
                                        ? null // Vô hiệu hóa khi đã đặt cọc
                                        : () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (_) => BookingPage(
                                                  room: widget.room,
                                                ),
                                              ),
                                            ).then((result) {
                                              if (result == true) {
                                                // Refresh logic if needed
                                              }
                                            });
                                          },
                                  ),
                                )
                              else
                                const Expanded(child: SizedBox()),
                              const SizedBox(width: 8),
                              // Đánh giá - chỉ hiện khi không phải phòng của mình
                              if (widget.room.ownerId != user.uid)
                                Expanded(
                                  child: _buildActionButton(
                                    icon: Icons.star,
                                    label: 'Đánh giá',
                                    color: Colors.amber,
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              ReviewPage(room: widget.room),
                                        ),
                                      ).then((result) {
                                        if (result == true) {
                                          // Refresh logic if needed
                                        }
                                      });
                                    },
                                  ),
                                )
                              else
                                const Expanded(child: SizedBox()),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Owner Info
                    const Text(
                      'Thông tin liên hệ',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                const CircleAvatar(
                                  radius: 25,
                                  backgroundColor: Colors.blue,
                                  child: Icon(
                                    Icons.person,
                                    color: Colors.white,
                                    size: 30,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              widget.room.ownerName,
                                              style: const TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                          FutureBuilder<int>(
                                            future:
                                                TrustScoreService.getTrustScore(
                                                  widget.room.ownerId,
                                                ),
                                            builder: (context, snapshot) {
                                              if (snapshot.hasData) {
                                                return TrustScoreBadge(
                                                  score: snapshot.data!,
                                                  showLabel: false,
                                                  compact: true,
                                                );
                                              }
                                              return const SizedBox.shrink();
                                            },
                                          ),
                                        ],
                                      ),
                                      Text(
                                        widget.room.ownerPhone,
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.blue.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: Colors.blue.withValues(alpha: 0.3),
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.info_outline,
                                    color: Colors.blue,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Để liên hệ với người đăng bài, hãy sử dụng nút "Nhắn tin" ở phía trên.',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.blue[700],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Đánh giá phòng
                    RoomReviewsWidget(room: widget.room),

                    // Bài đăng đề xuất
                    if (_suggestedRooms.isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          children: [
                            Container(
                              width: 4,
                              height: 24,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFF4A90E2),
                                    Color(0xFF50C9FF),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Text(
                              'Bài đăng tương tự',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFF4A90E2),
                                    Color(0xFF50C9FF),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '${_suggestedRooms.length} phòng',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      ..._suggestedRooms.map(
                        (room) => ValueListenableBuilder<Set<String>>(
                          valueListenable: favoriteService.favoritesNotifier,
                          builder: (context, favorites, child) {
                            final isFavorite = favorites.contains(room.id);

                            // 🔥 Get owner VIP from cache
                            final ownerVip =
                                _ownerVipCache[room.ownerId] ??
                                {
                                  'vipLevel': 0,
                                  'vipType': 'free',
                                  'isVip': false,
                                };

                            return RoomCard(
                              room: room,
                              isFavorite: isFavorite,
                              ownerVipLevel: ownerVip['vipLevel'],
                              ownerVipType: ownerVip['vipType'],
                              onTap: () {
                                Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => RoomDetailPage(room: room),
                                  ),
                                );
                              },
                              onFavoriteToggle: () =>
                                  _toggleSuggestedFavorite(room.id),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],

                    const SizedBox(height: 100), // Space for bottom buttons
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Widget để xem ảnh fullscreen với zoom
class _FullscreenImageViewer extends StatefulWidget {
  final List<String> images;
  final int initialIndex;
  final String roomId;

  const _FullscreenImageViewer({
    required this.images,
    required this.initialIndex,
    required this.roomId,
  });

  @override
  State<_FullscreenImageViewer> createState() => _FullscreenImageViewerState();
}

class _FullscreenImageViewerState extends State<_FullscreenImageViewer> {
  late PageController _pageController;
  late TransformationController _transformationController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
    _transformationController = TransformationController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _transformationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Image viewer với zoom
          PageView.builder(
            controller: _pageController,
            itemCount: widget.images.length,
            onPageChanged: (index) {
              setState(() {
                _currentIndex = index;
                // Reset zoom khi chuyển ảnh
                _transformationController.value = Matrix4.identity();
              });
            },
            itemBuilder: (context, index) {
              return Hero(
                tag: 'room_image_${widget.roomId}_$index',
                child: InteractiveViewer(
                  transformationController: _transformationController,
                  minScale: 0.5,
                  maxScale: 4.0,
                  child: Center(
                    child: Image.network(
                      widget.images[index],
                      fit: BoxFit.contain,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Center(
                          child: CircularProgressIndicator(
                            value: loadingProgress.expectedTotalBytes != null
                                ? loadingProgress.cumulativeBytesLoaded /
                                      loadingProgress.expectedTotalBytes!
                                : null,
                            color: Colors.white,
                          ),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) {
                        return const Center(
                          child: Icon(
                            Icons.image_not_supported,
                            size: 100,
                            color: Colors.grey,
                          ),
                        );
                      },
                    ),
                  ),
                ),
              );
            },
          ),

          // Top bar with gradient
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.black.withOpacity(0.7), Colors.transparent],
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Close button
                  Container(
                    margin: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.5),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 26,
                      ),
                    ),
                  ),
                  // Image counter
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.black.withOpacity(0.6),
                          Colors.black.withOpacity(0.4),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.white24, width: 1),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.photo_library,
                          color: Colors.white,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${_currentIndex + 1}/${widget.images.length}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 56), // Balance for close button
                ],
              ),
            ),
          ),

          // Bottom instructions with animation
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Center(
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: const Duration(milliseconds: 800),
                builder: (context, value, child) {
                  return Opacity(
                    opacity: value,
                    child: Transform.translate(
                      offset: Offset(0, 20 * (1 - value)),
                      child: child,
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.black.withOpacity(0.7),
                        Colors.black.withOpacity(0.5),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: Colors.white24, width: 1),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.4),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.swipe, color: Colors.white70, size: 20),
                      SizedBox(width: 10),
                      Text(
                        'Vuốt để chuyển',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(width: 20),
                      Icon(Icons.zoom_in, color: Colors.white70, size: 20),
                      SizedBox(width: 10),
                      Text(
                        'Pinch để zoom',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
