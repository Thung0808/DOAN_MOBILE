import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'models/room_model.dart';
import 'widgets/room_card.dart';
import 'room_detail_page.dart';
import 'services/favorite_service.dart';

class FavoritePage extends StatefulWidget {
  const FavoritePage({super.key});

  @override
  State<FavoritePage> createState() => _FavoritePageState();
}

class _FavoritePageState extends State<FavoritePage> {
  final user = FirebaseAuth.instance.currentUser!;
  final dbRef = FirebaseDatabase.instance.ref();
  final favoriteService = FavoriteService();

  // 🚀 Cache data
  List<Room> _favoriteRooms = [];
  bool _isLoading = true;
  Timer? _debounceTimer;
  Set<String> _previousFavoriteIds = {};

  // 🔥 Cache owner VIP info với TTL
  final Map<String, Map<String, dynamic>> _ownerVipCache = {};
  static const int _cacheExpirySeconds = 30;

  @override
  void initState() {
    super.initState();
    // 🚀 Listen to favorites changes
    favoriteService.favoritesNotifier.addListener(_onFavoritesChanged);
    // Load initial data
    _loadFavoriteRooms();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    favoriteService.favoritesNotifier.removeListener(_onFavoritesChanged);
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

  Future<void> _loadOwnerVipInfoBatch(List<Room> rooms) async {
    final ownerIds = rooms.map((r) => r.ownerId).toSet();
    await Future.wait(ownerIds.map((id) => _loadOwnerVipInfo(id)));
  }

  /// 🚀 Được gọi mỗi khi favorites thay đổi (realtime!)
  void _onFavoritesChanged() {
    final currentFavorites = favoriteService.currentFavorites;

    // So sánh với previous để biết đã thêm hay xóa
    final added = currentFavorites.difference(_previousFavoriteIds);
    final removed = _previousFavoriteIds.difference(currentFavorites);

    print(
      '📱 FAVORITE PAGE: Favorites changed - Added: ${added.length}, Removed: ${removed.length}',
    );

    if (removed.isNotEmpty) {
      // 🚀 Chỉ xóa khỏi list, không reload (instant!)
      setState(() {
        _favoriteRooms.removeWhere((room) => removed.contains(room.id));
      });
      _previousFavoriteIds = currentFavorites;
    } else if (added.isNotEmpty) {
      // 🚀 Có item mới được thêm → reload để fetch data
      _debounceTimer?.cancel();
      _debounceTimer = Timer(const Duration(milliseconds: 300), () {
        if (mounted) {
          _loadFavoriteRooms();
        }
      });
    }
  }

  // 🚀 Load chỉ các rooms được yêu thích (dùng cache từ service)
  Future<void> _loadFavoriteRooms() async {
    setState(() => _isLoading = true);
    _ownerVipCache.clear(); // Clear cache để load fresh data

    try {
      // 1. 🚀 Lấy danh sách favorites từ service cache (instant!)
      final favoriteIds = favoriteService.currentFavorites.toList();

      if (favoriteIds.isEmpty) {
        setState(() {
          _favoriteRooms = [];
          _isLoading = false;
        });
        return;
      }

      // 2. 🚀 Fetch song song chỉ các rooms được yêu thích
      final roomFutures = favoriteIds
          .map((roomId) => dbRef.child('rooms').child(roomId).get())
          .toList();

      final roomSnapshots = await Future.wait(roomFutures);

      final rooms = <Room>[];
      for (var i = 0; i < favoriteIds.length; i++) {
        if (roomSnapshots[i].exists) {
          final room = Room.fromMap(
            favoriteIds[i],
            roomSnapshots[i].value as Map,
          );
          rooms.add(room);
        }
      }

      // 🔥 Load owner VIP info
      await _loadOwnerVipInfoBatch(rooms);

      // 🚀 Sắp xếp VIP rooms lên trên cùng (check từ owner cache)
      rooms.sort((a, b) {
        // VIP rooms lên đầu (từ owner VIP cache)
        final aVip = _ownerVipCache[a.ownerId]?['isVip'] == true;
        final bVip = _ownerVipCache[b.ownerId]?['isVip'] == true;
        if (aVip && !bVip) return -1;
        if (!aVip && bVip) return 1;

        // Sau đó sort theo thứ tự trong favorites list (giữ nguyên thứ tự)
        final indexA = favoriteIds.indexOf(a.id);
        final indexB = favoriteIds.indexOf(b.id);
        return indexA.compareTo(indexB);
      });

      if (mounted) {
        setState(() {
          _favoriteRooms = rooms;
          _isLoading = false;
        });
        // 🚀 Update previous để track changes
        _previousFavoriteIds = favoriteService.currentFavorites;
      }
    } catch (e) {
      print('❌ Lỗi load favorite rooms: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        _previousFavoriteIds = favoriteService.currentFavorites;
      }
    }
  }

  Future<void> _toggleFavorite(String roomId) async {
    try {
      // 🚀 Service tự động optimistic update và broadcast
      final isNowFavorite = await favoriteService.toggleFavorite(roomId);

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.favorite, color: Colors.pink, size: 24),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Phòng yêu thích',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Text(
                  '${_favoriteRooms.length} phòng đã lưu',
                  style: const TextStyle(fontSize: 12, color: Colors.white70),
                ),
              ],
            ),
          ],
        ),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.pink.shade400, Colors.red.shade300],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        foregroundColor: Colors.white,
        elevation: 4,
        shadowColor: Colors.pink.withOpacity(0.5),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              onPressed: _loadFavoriteRooms,
              icon: const Icon(Icons.refresh),
              tooltip: 'Làm mới',
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _favoriteRooms.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0.0, end: 1.0),
                      duration: const Duration(milliseconds: 800),
                      curve: Curves.elasticOut,
                      builder: (context, value, child) {
                        return Transform.scale(
                          scale: value,
                          child: Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.pink.shade50,
                                  Colors.red.shade50,
                                ],
                              ),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.pink.withOpacity(0.2),
                                  blurRadius: 20,
                                  spreadRadius: 5,
                                ),
                              ],
                            ),
                            child: Icon(
                              Icons.favorite_border,
                              size: 80,
                              color: Colors.pink.shade300,
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Chưa có phòng yêu thích',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Nhấn vào biểu tượng ❤️ để lưu phòng',
                      style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                    ),
                  ],
                ),
              )
            : Column(
                children: [
                  // Stats Bar
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.pink.shade50, Colors.red.shade50],
                      ),
                      border: Border(
                        bottom: BorderSide(color: Colors.pink.shade100),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.pink.shade100,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            Icons.favorite,
                            color: Colors.pink.shade700,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Bạn đã lưu ${_favoriteRooms.length} phòng yêu thích',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.pink.shade900,
                              fontSize: 15,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.pink.shade400,
                                Colors.red.shade400,
                              ],
                            ),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.pink.withOpacity(0.3),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Text(
                            '${_favoriteRooms.length}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: _loadFavoriteRooms,
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 8,
                        ),
                        itemCount: _favoriteRooms.length,
                        // 🚀 Optimize scroll
                        cacheExtent: 500,
                        itemBuilder: (context, index) {
                          final room = _favoriteRooms[index];
                          // 🚀 ValueListenableBuilder để realtime update icon
                          return ValueListenableBuilder<Set<String>>(
                            valueListenable: favoriteService.favoritesNotifier,
                            builder: (context, favorites, child) {
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
                                isFavorite: favorites.contains(room.id),
                                ownerVipLevel: ownerVip['vipLevel'],
                                ownerVipType: ownerVip['vipType'],
                                onTap: () async {
                                  await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          RoomDetailPage(room: room),
                                    ),
                                  );
                                },
                                onFavoriteToggle: () =>
                                    _toggleFavorite(room.id),
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
