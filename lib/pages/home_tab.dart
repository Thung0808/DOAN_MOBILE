import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';
import '../models/room_model.dart';
import '../widgets/room_card.dart';
import '../room_detail_page.dart';
import '../room_list_page_new.dart';
import '../services/favorite_service.dart';

class HomeTabNew extends StatefulWidget {
  const HomeTabNew({super.key});

  @override
  State<HomeTabNew> createState() => _HomeTabNewState();
}

class _HomeTabNewState extends State<HomeTabNew> {
  final user = FirebaseAuth.instance.currentUser!;
  final dbRef = FirebaseDatabase.instance.ref();
  final favoriteService = FavoriteService();
  List<Room> _viewedRooms = [];
  int _currentPage = 1;
  static const int _roomsPerPage = 5;
  final ScrollController _scrollController = ScrollController();

  StreamSubscription? _viewedRoomsSubscription;

  // 🔥 Cache owner VIP info với TTL
  final Map<String, Map<String, dynamic>> _ownerVipCache = {};
  static const int _cacheExpirySeconds = 30;

  @override
  void initState() {
    super.initState();
    _setupViewedRoomsListener();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _viewedRoomsSubscription?.cancel();
    super.dispose();
  }

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

  void _setupViewedRoomsListener() {
    // Lắng nghe real-time changes từ viewedRooms
    _viewedRoomsSubscription = dbRef
        .child('users')
        .child(user.uid)
        .child('viewedRooms')
        .onValue
        .listen((event) async {
          try {
            if (!event.snapshot.exists) {
              if (mounted) {
                setState(() {
                  _viewedRooms = [];
                });
              }
              return;
            }

            final viewedMap = event.snapshot.value as Map;
            final viewedRooms = <Room>[];
            final now = DateTime.now().millisecondsSinceEpoch;
            final oneHourAgo = now - (60 * 60 * 1000);

            // Lấy danh sách roomId và sắp xếp theo thời gian xem (mới nhất trước)
            final sortedEntries = viewedMap.entries.toList()
              ..sort((a, b) {
                final aTime = (a.value as Map)['viewedAt'] as int? ?? 0;
                final bTime = (b.value as Map)['viewedAt'] as int? ?? 0;
                return bTime.compareTo(aTime); // Mới nhất trước
              });

            // Lấy tối đa 10 phòng gần đây nhất
            for (var entry in sortedEntries.take(10)) {
              final roomId = entry.key;
              final data = entry.value as Map;
              final viewedAt = data['viewedAt'] as int? ?? 0;

              if (viewedAt > oneHourAgo) {
                // Lấy thông tin phòng từ Firebase
                final roomSnapshot = await dbRef
                    .child('rooms')
                    .child(roomId)
                    .get();
                if (roomSnapshot.exists) {
                  final room = Room.fromMap(roomId, roomSnapshot.value as Map);
                  viewedRooms.add(room);
                }
              } else {
                // Xóa phòng đã cũ hơn 1 giờ
                dbRef
                    .child('users')
                    .child(user.uid)
                    .child('viewedRooms')
                    .child(roomId)
                    .remove();
              }
            }

            if (mounted) {
              setState(() {
                _viewedRooms = viewedRooms;
              });
            }
          } catch (e) {
            print('❌ Lỗi load viewed rooms: $e');
          }
        });
  }

  Future<void> _toggleFavorite(String roomId) async {
    try {
      await favoriteService.toggleFavorite(roomId);
    } catch (e) {
      print('❌ Lỗi toggle favorite: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder(
        stream: dbRef.child('rooms').onValue,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return const Center(child: Text('Lỗi tải dữ liệu'));
          }

          final data = (snapshot.data?.snapshot.value ?? {}) as Map?;
          final allRooms =
              data?.entries
                  .map((entry) => Room.fromMap(entry.key, entry.value))
                  .where((room) => room.status == 'approved')
                  .toList() ??
              [];

          allRooms.sort((a, b) {
            final viewCompare = b.viewCount.compareTo(a.viewCount);
            if (viewCompare != 0) return viewCompare;
            return b.timestamp.compareTo(a.timestamp);
          });

          final totalRooms = allRooms.length;
          final totalPages = (totalRooms / _roomsPerPage).ceil();

          if (_currentPage > totalPages && totalPages > 0) {
            _currentPage = totalPages;
          }
          if (_currentPage < 1) {
            _currentPage = 1;
          }

          final startIndex = (_currentPage - 1) * _roomsPerPage;
          final endIndex = (startIndex + _roomsPerPage).clamp(0, totalRooms);
          final currentPageRooms = allRooms.sublist(
            startIndex.clamp(0, totalRooms),
            endIndex,
          );

          return CustomScrollView(
            controller: _scrollController,
            slivers: [
              // App Bar - Cố định không cuộn
              SliverAppBar(
                expandedHeight: 140,
                floating: false,
                pinned: true,
                backgroundColor: Colors.blue.shade600,
                elevation: 0,
                flexibleSpace: FlexibleSpaceBar(
                  centerTitle: false,
                  titlePadding: const EdgeInsets.only(
                    left: 16,
                    right: 16,
                    bottom: 12,
                  ),
                  title: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.home_work_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Tìm Trọ',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Nhanh chóng - Tiện lợi',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  background: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.blue.shade600, Colors.blue.shade500],
                      ),
                    ),
                  ),
                ),
              ),

              // Header và thanh tìm kiếm
              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Search Button
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: InkWell(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const RoomListPageNew(
                                showRoomListDirectly: true,
                              ),
                            ),
                          );
                        },
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 20,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.blue.shade100,
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.blue.withValues(alpha: 0.1),
                                spreadRadius: 1,
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.search,
                                color: Colors.blue.shade600,
                                size: 22,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Tìm kiếm phòng trọ...',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  Icons.tune,
                                  color: Colors.blue.shade600,
                                  size: 18,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Banner Thông báo
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                            colors: [
                              Colors.blue.shade600,
                              Colors.blue.shade400,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.blue.withValues(alpha: 0.3),
                              spreadRadius: 1,
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.campaign,
                              color: Colors.white,
                              size: 32,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Text(
                                    'Thông báo',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    'Đăng phòng miễn phí - Tìm trọ nhanh chóng!',
                                    style: TextStyle(
                                      color: Colors.white.withValues(
                                        alpha: 0.9,
                                      ),
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),

              // Widget 1: Danh sách phòng nổi bật
              _buildTrendingSection(allRooms),

              // Tiêu đề danh sách phòng trọ
              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 24),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  Icons.list_alt,
                                  color: Colors.blue.shade600,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'Danh sách phòng trọ',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue.shade700,
                                ),
                              ),
                            ],
                          ),
                          TextButton.icon(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const RoomListPageNew(
                                    showRoomListDirectly: true,
                                  ),
                                ),
                              );
                            },
                            icon: Icon(
                              Icons.arrow_forward,
                              color: Colors.blue.shade600,
                              size: 18,
                            ),
                            label: Text(
                              'Xem tất cả',
                              style: TextStyle(
                                color: Colors.blue.shade600,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        'Hiển thị 5/$totalRooms phòng - Bấm "Xem tất cả" để xem thêm',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),

              // Widget 2: Danh sách bài đăng thường (chỉ 5 bài đầu)
              _buildRegularRoomsSection(currentPageRooms.take(5).toList()),

              // Widget 3: Danh sách bài đăng đã xem (đặt cuối cùng)
              _buildViewedRoomsSection(),

              const SliverToBoxAdapter(child: SizedBox(height: 80)),
            ],
          );
        },
      ),
    );
  }

  // Widget 1: Danh sách phòng nổi bật
  Widget _buildTrendingSection(List<Room> allRooms) {
    // Lọc các phòng có lượt xem > 10, sau đó lấy 4 phòng đầu
    final trendingRooms = allRooms
        .where((room) => room.viewCount > 10)
        .take(4)
        .toList();

    if (trendingRooms.isEmpty) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    return SliverToBoxAdapter(
      child: Container(
        margin: const EdgeInsets.all(16),
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
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.trending_up,
                        color: Colors.blue.shade600,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Phòng nổi bật',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade700,
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
                    Icons.arrow_forward,
                    color: Colors.blue.shade600,
                    size: 18,
                  ),
                  label: Text(
                    'Xem tất cả',
                    style: TextStyle(
                      color: Colors.blue.shade600,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 300,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: trendingRooms.length,
                itemBuilder: (context, index) {
                  final room = trendingRooms[index];
                  return Container(
                    width: 200,
                    margin: const EdgeInsets.only(right: 12),
                    child: GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => RoomDetailPage(room: room),
                          ),
                        );
                      },
                      child: Card(
                        elevation: 4,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Hình ảnh
                            ClipRRect(
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(12),
                              ),
                              child: Container(
                                height: 120,
                                width: double.infinity,
                                color: Colors.grey[200],
                                child: room.images.isNotEmpty
                                    ? Image.network(
                                        room.images.first,
                                        fit: BoxFit.cover,
                                        errorBuilder:
                                            (context, error, stackTrace) {
                                              return const Icon(
                                                Icons.home,
                                                size: 50,
                                                color: Colors.grey,
                                              );
                                            },
                                      )
                                    : const Icon(
                                        Icons.home,
                                        size: 50,
                                        color: Colors.grey,
                                      ),
                              ),
                            ),
                            // Thông tin
                            Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    room.title,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    room.address,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.visibility,
                                        size: 12,
                                        color: Colors.blue[600],
                                      ),
                                      const SizedBox(width: 2),
                                      Text(
                                        '${room.viewCount}',
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: Colors.blue[600],
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Icon(
                                        Icons.star,
                                        size: 12,
                                        color:
                                            room.reviewCount > 0 &&
                                                room.averageRating > 0
                                            ? Colors.amber
                                            : Colors.grey[400],
                                      ),
                                      const SizedBox(width: 2),
                                      Expanded(
                                        child: Text(
                                          room.reviewCount > 0 &&
                                                  room.averageRating > 0
                                              ? '${room.averageRating.toStringAsFixed(1)} (${room.reviewCount})'
                                              : 'Chưa có đánh giá',
                                          style: TextStyle(
                                            fontSize: 10,
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
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          '${NumberFormat('#,###').format(room.price)}đ/tháng',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.blue[600],
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Flexible(
                                        child: ValueListenableBuilder<Set<String>>(
                                          valueListenable:
                                              favoriteService.favoritesNotifier,
                                          builder: (context, favorites, child) {
                                            final isFavorite = favorites
                                                .contains(room.id);
                                            return Material(
                                              color: Colors.transparent,
                                              child: InkWell(
                                                onTap: () {
                                                  _toggleFavorite(room.id);
                                                },
                                                borderRadius:
                                                    BorderRadius.circular(20),
                                                child: Padding(
                                                  padding: const EdgeInsets.all(
                                                    4,
                                                  ),
                                                  child: Icon(
                                                    isFavorite
                                                        ? Icons.favorite
                                                        : Icons.favorite_border,
                                                    color: isFavorite
                                                        ? Colors.red
                                                        : Colors.grey,
                                                    size: 20,
                                                  ),
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
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

  // Widget 2: Danh sách bài đăng thường
  Widget _buildRegularRoomsSection(List<Room> rooms) {
    return SliverList(
      delegate: SliverChildBuilderDelegate((context, index) {
        final room = rooms[index];
        return ValueListenableBuilder<Set<String>>(
          valueListenable: favoriteService.favoritesNotifier,
          builder: (context, favorites, child) {
            final isFavorite = favorites.contains(room.id);

            return FutureBuilder<Map<String, dynamic>>(
              future: _loadOwnerVipInfo(room.ownerId),
              builder: (context, vipSnapshot) {
                final ownerVip =
                    vipSnapshot.data ??
                    {'vipLevel': 0, 'vipType': 'free', 'isVip': false};

                return RoomCard(
                  room: room,
                  isFavorite: isFavorite,
                  ownerVipLevel: ownerVip['vipLevel'],
                  ownerVipType: ownerVip['vipType'],
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => RoomDetailPage(room: room),
                      ),
                    );
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

  // Widget 3: Danh sách bài đăng đã xem
  Widget _buildViewedRoomsSection() {
    if (_viewedRooms.isEmpty) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    return SliverToBoxAdapter(
      child: Container(
        margin: const EdgeInsets.all(16),
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
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.history,
                        color: Colors.blue.shade600,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Đã xem gần đây',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade700,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    '${_viewedRooms.length} phòng',
                    style: TextStyle(
                      color: Colors.blue.shade600,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 300,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _viewedRooms.length,
                itemBuilder: (context, index) {
                  final room = _viewedRooms[index];
                  return Container(
                    width: 200,
                    margin: const EdgeInsets.only(right: 12),
                    child: GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => RoomDetailPage(room: room),
                          ),
                        );
                      },
                      child: Card(
                        elevation: 4,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Hình ảnh
                            ClipRRect(
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(12),
                              ),
                              child: Container(
                                height: 120,
                                width: double.infinity,
                                color: Colors.grey[200],
                                child: room.images.isNotEmpty
                                    ? Image.network(
                                        room.images.first,
                                        fit: BoxFit.cover,
                                        errorBuilder:
                                            (context, error, stackTrace) {
                                              return const Icon(
                                                Icons.home,
                                                size: 50,
                                                color: Colors.grey,
                                              );
                                            },
                                      )
                                    : const Icon(
                                        Icons.home,
                                        size: 50,
                                        color: Colors.grey,
                                      ),
                              ),
                            ),
                            // Thông tin
                            Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    room.title,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    room.address,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.visibility,
                                        size: 12,
                                        color: Colors.blue[600],
                                      ),
                                      const SizedBox(width: 2),
                                      Text(
                                        '${room.viewCount}',
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: Colors.blue[600],
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Icon(
                                        Icons.star,
                                        size: 12,
                                        color:
                                            room.reviewCount > 0 &&
                                                room.averageRating > 0
                                            ? Colors.amber
                                            : Colors.grey[400],
                                      ),
                                      const SizedBox(width: 2),
                                      Expanded(
                                        child: Text(
                                          room.reviewCount > 0 &&
                                                  room.averageRating > 0
                                              ? '${room.averageRating.toStringAsFixed(1)} (${room.reviewCount})'
                                              : 'Chưa có đánh giá',
                                          style: TextStyle(
                                            fontSize: 10,
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
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          '${NumberFormat('#,###').format(room.price)}đ/tháng',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.blue[600],
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Flexible(
                                        child: ValueListenableBuilder<Set<String>>(
                                          valueListenable:
                                              favoriteService.favoritesNotifier,
                                          builder: (context, favorites, child) {
                                            final isFavorite = favorites
                                                .contains(room.id);
                                            return Material(
                                              color: Colors.transparent,
                                              child: InkWell(
                                                onTap: () {
                                                  _toggleFavorite(room.id);
                                                },
                                                borderRadius:
                                                    BorderRadius.circular(20),
                                                child: Padding(
                                                  padding: const EdgeInsets.all(
                                                    4,
                                                  ),
                                                  child: Icon(
                                                    isFavorite
                                                        ? Icons.favorite
                                                        : Icons.favorite_border,
                                                    color: isFavorite
                                                        ? Colors.red
                                                        : Colors.grey,
                                                    size: 20,
                                                  ),
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
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
