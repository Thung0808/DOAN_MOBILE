import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';
import '../models/room_model.dart';
import '../widgets/room_card.dart';
import '../room_detail_page.dart';
import '../room_list_page_new.dart';
import '../services/favorite_service.dart';
import 'vip_packages_page_user.dart';

class HomeTabNew extends StatefulWidget {
  // Remove const to allow rebuild with VIP data
  HomeTabNew({super.key}) {
    print('🏠 HOME TAB: Constructor called!');
  }

  @override
  State<HomeTabNew> createState() {
    print('🏠 HOME TAB: createState called!');
    return _HomeTabNewState();
  }
}

class _HomeTabNewState extends State<HomeTabNew> {
  final user = FirebaseAuth.instance.currentUser!;
  final dbRef = FirebaseDatabase.instance.ref();
  final favoriteService = FavoriteService();
  List<Room> _trendingRooms = [];
  List<Room> _viewedRooms = [];
  List<Room> _displayRooms = []; // 🚀 Rooms to display in main list
  bool _isLoading = true;

  // 🔥 Cache owner VIP info với timestamp
  final Map<String, Map<String, dynamic>> _ownerVipCache = {};
  static const int _cacheExpirySeconds = 30; // Cache expire sau 30 giây

  @override
  void initState() {
    super.initState();
    print('🏠 HOME TAB: initState called!');
    _loadAllData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    print('🏠 HOME TAB: didChangeDependencies called!');
  }

  // 🚀 Load all data once
  Future<void> _loadAllData() async {
    setState(() => _isLoading = true);
    _ownerVipCache.clear(); // Clear cache để load fresh data
    await Future.wait([
      _loadDisplayRooms(), // Load main display rooms
      _loadTrendingRooms(),
      _loadViewedRooms(),
    ]);
    setState(() => _isLoading = false);
  }

  // 🚀 Load rooms for main display
  // 🔥 Helper: Load owner VIP info with cache + TTL
  Future<Map<String, dynamic>> _loadOwnerVipInfo(String ownerId) async {
    // Check cache first (với TTL)
    if (_ownerVipCache.containsKey(ownerId)) {
      final cached = _ownerVipCache[ownerId]!;
      final cachedTime = cached['_cachedAt'] as int? ?? 0;
      final now = DateTime.now().millisecondsSinceEpoch;
      final expiryTime = _cacheExpirySeconds * 1000; // Convert to milliseconds

      // Nếu cache chưa expire, dùng cache
      if (now - cachedTime < expiryTime) {
        return cached;
      }
      // Cache đã expire, xóa và load lại
      _ownerVipCache.remove(ownerId);
    }

    try {
      final ownerSnap = await dbRef.child('users').child(ownerId).get();
      if (ownerSnap.exists) {
        final ownerData = ownerSnap.value as Map;
        final vipLevel = ownerData['vipLevel'] ?? 0;
        final vipType = ownerData['vipType'] ?? 'free';
        final vipEndDate = ownerData['vipEndDate'];

        // Check if VIP is active
        final isActive =
            vipLevel > 0 &&
            vipEndDate != null &&
            DateTime.now().millisecondsSinceEpoch < vipEndDate;

        final result = {
          'vipLevel': isActive ? vipLevel : 0,
          'vipType': isActive ? vipType : 'free',
          'isVip': isActive,
          '_cachedAt': DateTime.now().millisecondsSinceEpoch, // TTL timestamp
        };

        // Cache the result
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

  // 🔥 Load VIP info for multiple rooms at once
  Future<void> _loadOwnerVipInfoBatch(List<Room> rooms) async {
    final ownerIds = rooms.map((r) => r.ownerId).toSet();
    await Future.wait(ownerIds.map((id) => _loadOwnerVipInfo(id)));
  }

  Future<void> _loadDisplayRooms() async {
    try {
      final snapshot = await dbRef
          .child('rooms')
          .orderByChild('status')
          .equalTo('approved')
          .limitToFirst(10) // 🚀 Chỉ load 10 rooms
          .get();

      if (snapshot.exists) {
        final roomsMap = snapshot.value as Map;
        final rooms = <Room>[];

        roomsMap.forEach((key, value) {
          if (value != null) {
            final room = Room.fromMap(key, value as Map);
            // 🔥 Chỉ hiển thị phòng có trạng thái 'DangMo' hoặc 'DaDatLich'
            if (room.availabilityStatus == 'DangMo' ||
                room.availabilityStatus == 'DaDatLich') {
              rooms.add(room);
            }
          }
        });

        // 🔥 Load owner VIP info
        await _loadOwnerVipInfoBatch(rooms);

        // Sort với VIP priority (VIP theo USER - từ cache)
        rooms.sort((a, b) {
          final aVip = _ownerVipCache[a.ownerId]?['isVip'] == true;
          final bVip = _ownerVipCache[b.ownerId]?['isVip'] == true;
          if (aVip && !bVip) return -1;
          if (!aVip && bVip) return 1;

          final viewCompare = b.viewCount.compareTo(a.viewCount);
          if (viewCompare != 0) return viewCompare;

          return b.timestamp.compareTo(a.timestamp);
        });

        if (mounted) {
          setState(() {
            _displayRooms = rooms.take(5).toList();
          });
        }
      }
    } catch (e) {
      print('❌ Lỗi load display rooms: $e');
    }
  }

  // 🚀 Load favorites once
  // ❌ REMOVED: Không cần load favorites nữa, dùng service realtime

  Future<void> _loadTrendingRooms() async {
    try {
      // 🚀 CHỈ load 10 rooms thay vì tất cả
      final snapshot = await dbRef
          .child('rooms')
          .orderByChild('status')
          .equalTo('approved')
          .limitToFirst(10) // 🚀 Giới hạn ngay từ query
          .get();

      if (snapshot.exists) {
        final roomsMap = snapshot.value as Map;
        final rooms = <Room>[];

        roomsMap.forEach((key, value) {
          if (value != null) {
            final room = Room.fromMap(key, value as Map);
            // 🔥 Chỉ hiển thị phòng có trạng thái 'DangMo' hoặc 'DaDatLich'
            if (room.availabilityStatus == 'DangMo' ||
                room.availabilityStatus == 'DaDatLich') {
              rooms.add(room);
            }
          }
        });

        // 🔥 Load owner VIP info
        await _loadOwnerVipInfoBatch(rooms);

        // Sort với VIP priority (VIP theo USER - từ cache)
        rooms.sort((a, b) {
          // VIP rooms first (kiểm tra từ owner VIP cache)
          final aVip = _ownerVipCache[a.ownerId]?['isVip'] == true;
          final bVip = _ownerVipCache[b.ownerId]?['isVip'] == true;
          if (aVip && !bVip) return -1;
          if (!aVip && bVip) return 1;

          // Then by view count
          return b.viewCount.compareTo(a.viewCount);
        });

        if (mounted) {
          setState(() {
            _trendingRooms = rooms.take(4).toList();
          });
        }
      }
    } catch (e) {
      print('❌ Lỗi load trending rooms: $e');
    }
  }

  Future<void> _loadViewedRooms() async {
    try {
      // 🚀 Giới hạn chỉ load 5 rooms gần nhất
      final snapshot = await dbRef
          .child('users')
          .child(user.uid)
          .child('viewedRooms')
          .orderByChild('viewedAt')
          .limitToLast(5) // 🚀 Chỉ lấy 5 rooms mới nhất
          .get();

      if (!snapshot.exists) {
        if (mounted) setState(() => _viewedRooms = []);
        return;
      }

      final viewedMap = snapshot.value as Map;
      final now = DateTime.now().millisecondsSinceEpoch;
      final oneHourAgo = now - (60 * 60 * 1000);

      // 🚀 Lấy danh sách roomId valid
      final validRoomIds = <String>[];
      viewedMap.forEach((roomId, data) {
        if (data != null) {
          final viewedAt = data['viewedAt'] as int? ?? 0;
          if (viewedAt > oneHourAgo) {
            validRoomIds.add(roomId);
          }
        }
      });

      if (validRoomIds.isEmpty) {
        if (mounted) setState(() => _viewedRooms = []);
        return;
      }

      // 🚀 Fetch song song tất cả rooms cùng lúc
      final roomFutures = validRoomIds
          .map((roomId) => dbRef.child('rooms').child(roomId).get())
          .toList();

      final roomSnapshots = await Future.wait(roomFutures);

      final viewedRooms = <Room>[];
      for (var i = 0; i < validRoomIds.length; i++) {
        if (roomSnapshots[i].exists) {
          final room = Room.fromMap(
            validRoomIds[i],
            roomSnapshots[i].value as Map,
          );
          viewedRooms.add(room);
        }
      }

      // 🔥 Load owner VIP info
      await _loadOwnerVipInfoBatch(viewedRooms);

      if (mounted) {
        setState(() {
          _viewedRooms = viewedRooms;
        });
      }
    } catch (e) {
      print('❌ Lỗi load viewed rooms: $e');
    }
  }

  Future<void> _toggleFavorite(String roomId) async {
    try {
      // 🚀 Service tự động optimistic update và broadcast realtime
      await favoriteService.toggleFavorite(roomId);
    } catch (e) {
      print('❌ Lỗi toggle favorite: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    print('🏠 HOME TAB BUILD: Widget is building...');

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadAllData,
              child: CustomScrollView(
                slivers: [
                  _buildSearchBar(),
                  _buildNotificationBanner(),
                  _buildTrendingSection(),
                  _buildRoomsListHeader(_displayRooms.length),
                  _buildRegularRoomsSection(_displayRooms),
                  _buildViewedRoomsSection(),
                  const SliverToBoxAdapter(child: SizedBox(height: 80)),
                ],
              ),
            ),
    );
  }

  // 1. Search Bar - Thanh tìm kiếm hiện đại
  Widget _buildSearchBar() {
    return SliverToBoxAdapter(
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF4A90E2), Color(0xFF50C9FF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.home_work_rounded,
                      color: Colors.white,
                      size: 28,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Tìm Trọ',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Tìm phòng trọ phù hợp với bạn',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.9),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Search Box
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            const RoomListPageNew(showRoomListDirectly: true),
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 10,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.search,
                          color: Colors.grey.shade600,
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Tìm kiếm theo địa điểm, giá...',
                            style: TextStyle(
                              color: Colors.grey.shade500,
                              fontSize: 15,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Color(0xFF4A90E2), Color(0xFF50C9FF)],
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.tune,
                            color: Colors.white,
                            size: 18,
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
    );
  }

  // 2. Notification Banner
  Widget _buildNotificationBanner() {
    return SliverToBoxAdapter(
      child: InkWell(
        onTap: () {
          // Navigate đến trang mua VIP
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const VipPackagesPageUser()),
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFFF9A9E), Color(0xFFFECFEF)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.pink.withValues(alpha: 0.2),
                blurRadius: 10,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.campaign_rounded,
                    color: Colors.white,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Thông báo đặc biệt!',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Giảm giá 20% cho phòng VIP trong tháng này',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.95),
                          fontSize: 12,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(Icons.arrow_forward_ios, color: Colors.white, size: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Card cho phòng nổi bật
  Widget _buildTrendingCard(Room room, bool isFavorite) {
    final formatter = NumberFormat.currency(locale: 'vi_VN', symbol: '₫');

    // 🔥 Get owner VIP info from cache
    final ownerVipInfo =
        _ownerVipCache[room.ownerId] ??
        {'vipLevel': 0, 'vipType': 'free', 'isVip': false};
    final isOwnerVip = ownerVipInfo['isVip'] == true;
    final ownerVipType = ownerVipInfo['vipType'] as String;

    // 🔥 VIP theo USER (Gold/Aqua)
    Color getVipColor() {
      switch (ownerVipType) {
        case 'vip':
          return const Color(0xFFFFD700); // Gold (Vàng)
        case 'premium':
          return const Color(0xFF00FFFF); // Aqua (Xanh ngọc)
        default:
          return Colors.grey;
      }
    }

    String getVipIcon() {
      switch (ownerVipType) {
        case 'vip':
          return '👑'; // VIP badge
        case 'premium':
          return '💎'; // Premium badge
        default:
          return '';
      }
    }

    return GestureDetector(
      onTap: () async {
        // 🚀 Navigate và refresh khi quay lại
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => RoomDetailPage(room: room)),
        );
        // 🚀 Chỉ refresh phần cần thiết
        if (mounted) {
          _loadDisplayRooms();
          _loadTrendingRooms();
        }
      },
      child: Card(
        elevation: isOwnerVip ? 4 : 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: isOwnerVip
              ? BorderSide(color: getVipColor(), width: 2)
              : BorderSide.none,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Hình ảnh
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
                  child: Container(
                    height: 120,
                    width: double.infinity,
                    color: Colors.grey[300],
                    child: room.images.isNotEmpty
                        ? Image.network(
                            room.images.first,
                            fit: BoxFit.cover,
                            // 🚀 Enable caching
                            cacheWidth: 400,
                            cacheHeight: 300,
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return Center(
                                child: CircularProgressIndicator(
                                  value:
                                      loadingProgress.expectedTotalBytes != null
                                      ? loadingProgress.cumulativeBytesLoaded /
                                            loadingProgress.expectedTotalBytes!
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
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: getVipColor(),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: getVipColor().withValues(alpha: 0.5),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Text(
                        getVipIcon(),
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                  ),
                // Favorite button
                Positioned(
                  top: 8,
                  right: 8,
                  child: InkWell(
                    onTap: () => _toggleFavorite(room.id),
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.black38,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Icon(
                        isFavorite ? Icons.favorite : Icons.favorite_border,
                        color: isFavorite ? Colors.red : Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            // Thông tin
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Tiêu đề
                    Text(
                      room.title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    // Địa chỉ
                    Row(
                      children: [
                        Icon(
                          Icons.location_on,
                          size: 12,
                          color: Colors.grey[600],
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            '${room.district}, ${room.province}',
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
                    const Spacer(),
                    // Giá và diện tích
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            formatter.format(room.price),
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Colors.red,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
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
                            '${room.area}m²',
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
                    // Lượt xem và đánh giá
                    Row(
                      children: [
                        Icon(
                          Icons.visibility,
                          size: 12,
                          color: Colors.blue[600],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${room.viewCount}',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.blue[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Icon(
                          Icons.star,
                          size: 12,
                          color: room.reviewCount > 0
                              ? Colors.amber
                              : Colors.grey[400],
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            room.reviewCount > 0
                                ? '${room.averageRating.toStringAsFixed(1)} (${room.reviewCount})'
                                : 'Chưa có đánh giá',
                            style: TextStyle(
                              fontSize: 11,
                              color: room.reviewCount > 0
                                  ? Colors.amber[700]
                                  : Colors.grey[600],
                              fontWeight: room.reviewCount > 0
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
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

  // Header cho danh sách bài đăng
  Widget _buildRoomsListHeader(int totalRooms) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.apartment_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Tất cả bài đăng',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade800,
                      ),
                    ),
                  ],
                ),
                TextButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            const RoomListPageNew(showRoomListDirectly: true),
                      ),
                    );
                  },
                  icon: Icon(
                    Icons.arrow_forward_ios,
                    size: 14,
                    color: Color(0xFF4A90E2),
                  ),
                  label: Text(
                    'Xem tất cả',
                    style: TextStyle(
                      color: Color(0xFF4A90E2),
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.only(left: 4.0),
              child: Text(
                'Hiển thị 5/$totalRooms phòng - Bấm "Xem tất cả" để xem thêm',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Widget 3: Phòng nổi bật - Thiết kế đẹp mắt
  Widget _buildTrendingSection() {
    if (_trendingRooms.isEmpty)
      return const SliverToBoxAdapter(child: SizedBox.shrink());

    return SliverToBoxAdapter(
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 20, 16, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFFFF6B6B), Color(0xFFFFD93D)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.star_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Phòng nổi bật',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade800,
                      ),
                    ),
                  ],
                ),
                TextButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            const RoomListPageNew(showRoomListDirectly: true),
                      ),
                    );
                  },
                  icon: Icon(
                    Icons.arrow_forward_ios,
                    size: 14,
                    color: Color(0xFF4A90E2),
                  ),
                  label: Text(
                    'Xem tất cả',
                    style: TextStyle(
                      color: Color(0xFF4A90E2),
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 260,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: _trendingRooms.length,
                itemBuilder: (context, index) {
                  final room = _trendingRooms[index];
                  return Container(
                    width: 200,
                    margin: EdgeInsets.only(
                      right: 12,
                      left: index == 0 ? 4 : 0,
                    ),
                    // 🚀 ValueListenableBuilder để realtime update
                    child: ValueListenableBuilder<Set<String>>(
                      valueListenable: favoriteService.favoritesNotifier,
                      builder: (context, favorites, child) {
                        return _buildTrendingCard(
                          room,
                          favorites.contains(room.id),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Widget 4: Danh sách bài đăng thường
  Widget _buildRegularRoomsSection(List<Room> rooms) {
    return SliverList(
      delegate: SliverChildBuilderDelegate((context, index) {
        final room = rooms[index];

        // 🚀 ValueListenableBuilder để realtime update
        return ValueListenableBuilder<Set<String>>(
          valueListenable: favoriteService.favoritesNotifier,
          builder: (context, favorites, child) {
            return FutureBuilder<Map<String, dynamic>>(
              future: _loadOwnerVipInfo(room.ownerId),
              builder: (context, vipSnapshot) {
                final vipInfo =
                    vipSnapshot.data ?? {'vipLevel': 0, 'vipType': 'free'};

                return RoomCard(
                  room: room,
                  isFavorite: favorites.contains(room.id),
                  ownerVipLevel: vipInfo['vipLevel'],
                  ownerVipType: vipInfo['vipType'],
                  onTap: () async {
                    // 🚀 Navigate và refresh khi quay lại
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => RoomDetailPage(room: room),
                      ),
                    );
                    // 🚀 Chỉ refresh display rooms để cập nhật view count
                    if (mounted) {
                      _loadDisplayRooms();
                    }
                  },
                  onFavoriteToggle: () => _toggleFavorite(room.id),
                );
              },
            );
          },
        );
      }, childCount: rooms.length),
    );
  }

  // Widget 5: Bài đăng đã xem - Thiết kế đẹp mắt
  Widget _buildViewedRoomsSection() {
    if (_viewedRooms.isEmpty)
      return const SliverToBoxAdapter(child: SizedBox.shrink());

    return SliverToBoxAdapter(
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 20, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF11998E), Color(0xFF38EF7D)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.history_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Đã xem gần đây',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.only(left: 4.0),
              child: Text(
                'Các phòng bạn vừa xem trong 1 giờ qua',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 260,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: _viewedRooms.length,
                itemBuilder: (context, index) {
                  final room = _viewedRooms[index];
                  return Container(
                    width: 200,
                    margin: EdgeInsets.only(
                      right: 12,
                      left: index == 0 ? 4 : 0,
                    ),
                    // 🚀 ValueListenableBuilder để realtime update favorites
                    child: ValueListenableBuilder<Set<String>>(
                      valueListenable: favoriteService.favoritesNotifier,
                      builder: (context, favorites, child) {
                        // 🔥 FutureBuilder để realtime update VIP info
                        return FutureBuilder<Map<String, dynamic>>(
                          future: _loadOwnerVipInfo(room.ownerId),
                          builder: (context, vipSnapshot) {
                            // Refresh cache mỗi lần build
                            if (vipSnapshot.hasData) {
                              _ownerVipCache[room.ownerId] = vipSnapshot.data!;
                            }

                            return _buildTrendingCard(
                              room,
                              favorites.contains(room.id),
                            );
                          },
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
