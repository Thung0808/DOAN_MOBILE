import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';
import 'models/room_model.dart';
import 'models/room_with_owner.dart';
import 'widgets/room_card.dart';
import 'room_detail_page.dart';
import 'data/vietnam_locations.dart';
import 'services/favorite_service.dart';
import 'services/room_service.dart';

class RoomListPageNew extends StatefulWidget {
  final bool showRoomListDirectly;

  const RoomListPageNew({super.key, this.showRoomListDirectly = false});

  @override
  State<RoomListPageNew> createState() => _RoomListPageNewState();
}

class _RoomListPageNewState extends State<RoomListPageNew>
    with SingleTickerProviderStateMixin {
  final user = FirebaseAuth.instance.currentUser!;
  final dbRef = FirebaseDatabase.instance.ref();
  final favoriteService = FavoriteService();
  final roomService = RoomService(); // ⭐ NEW
  final searchController = TextEditingController();
  late AnimationController _filterButtonController;

  String _searchQuery = '';
  List<RoomWithOwner> _allRoomsWithOwners = []; // 🔥 NEW: Lưu owner info
  List<Room> _allRooms = [];
  List<Room> _filteredRooms = [];
  bool _isLoading = true;

  // Filter options
  double _minPrice = 0;
  double _maxPrice = 10000000;
  double _minArea = 0;
  double _maxArea = 100;
  String? _selectedProvince;
  String? _selectedDistrict;
  List<String> _selectedAmenities = [];

  // Advanced search options
  String? _sortBy;
  bool _hasImages = false;
  bool _hasDescription = false;

  // Pagination
  int _currentPage = 1;
  static const int _roomsPerPage = 5;

  // Bottom Navigation
  int _currentIndex = 0;

  // Flag to show room list page directly
  bool _showRoomListDirectly = false;

  final List<String> amenitiesList = [
    'Wi-Fi',
    'Điều hoà',
    'Tủ lạnh',
    'Máy giặt',
    'Nóng lạnh',
    'Thang máy',
    'Chỗ để xe',
    'Bảo vệ',
    'Giường',
    'Tủ quần áo',
  ];

  @override
  void initState() {
    super.initState();
    _filterButtonController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _showRoomListDirectly = widget.showRoomListDirectly;
    _loadAllDataParallel(); // 🚀 Load song song
  }

  // 🚀 Load tất cả data song song
  Future<void> _loadAllDataParallel() async {
    setState(() => _isLoading = true);

    // 🚀 Clear cache để load fresh data
    roomService.clearCache();

    // 🚀 Load chỉ rooms (favorites được manage bởi service realtime)
    // Location data load sau (lazy load khi cần dùng filter)
    await _loadRoomsOnce(); // 🚀 Load 1 lần thay vì stream

    // 🚀 Location data load trong background (không block UI)
    _loadLocationData(); // Không await!

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadLocationData() async {
    // 🚀 Load trong background, không block UI
    await VietnamLocations.loadData();
  }

  @override
  void dispose() {
    _filterButtonController.dispose();
    _roomsSubscription?.cancel();
    searchController.dispose();
    super.dispose();
  }

  StreamSubscription? _roomsSubscription;

  // 🚀 Load rooms 1 lần (không realtime) với owner VIP info
  Future<void> _loadRoomsOnce() async {
    try {
      // ⭐ NEW: Dùng RoomService để load rooms với owner VIP info
      // Rooms đã được sort theo owner VIP level trong service
      final roomsWithOwners = await roomService.loadRoomsWithOwners(limit: 20);

      if (roomsWithOwners.isNotEmpty) {
        // 🔥 Lưu cả RoomWithOwner để dùng owner VIP info
        final rooms = roomsWithOwners.map((rwo) => rwo.room).toList();

        if (mounted) {
          _allRoomsWithOwners = roomsWithOwners; // 🔥 Lưu owner info
          _allRooms = rooms;
          _filteredRooms = List.from(rooms);
          _sortAndUpdate();
        }
      } else {
        if (mounted) {
          setState(() {
            _allRoomsWithOwners = [];
            _allRooms = [];
            _filteredRooms = [];
          });
        }
      }
    } catch (e) {
      print('❌ Lỗi load rooms: $e');
      if (mounted) {
        setState(() {
          _allRooms = [];
          _filteredRooms = [];
        });
      }
    }
  }

  // 🚀 Tối ưu: Load favorites 1 lần
  // 🚀 Tối ưu: Dùng service để toggle favorite (realtime sync)
  Future<void> _toggleFavorite(String roomId) async {
    try {
      await favoriteService.toggleFavorite(roomId);
    } catch (e) {
      print('❌ Lỗi toggle favorite: $e');
    }
  }

  void _performSearch() {
    setState(() {});

    final query = _searchQuery.toLowerCase();
    _filteredRooms = _allRooms.where((room) {
      // Tìm kiếm theo từ khóa
      if (query.isNotEmpty) {
        final matchesSearch =
            room.title.toLowerCase().contains(query) ||
            room.province.toLowerCase().contains(query) ||
            room.district.toLowerCase().contains(query) ||
            room.ward.toLowerCase().contains(query) ||
            room.address.toLowerCase().contains(query);
        if (!matchesSearch) return false;
      }

      // Lọc theo giá
      if (room.price < _minPrice || room.price > _maxPrice) return false;

      // Lọc theo diện tích
      if (room.area < _minArea || room.area > _maxArea) return false;

      // Lọc theo tỉnh/thành phố
      if (_selectedProvince != null && room.province != _selectedProvince) {
        return false;
      }

      // Lọc theo quận/huyện
      if (_selectedDistrict != null && room.district != _selectedDistrict) {
        return false;
      }

      // Lọc theo tiện nghi
      for (final amenity in _selectedAmenities) {
        if (!room.amenities.contains(amenity)) return false;
      }

      // Lọc theo loại phòng (tạm thời bỏ qua vì Room model chưa có roomType)

      // Lọc theo có hình ảnh
      if (_hasImages && room.images.isEmpty) return false;

      // Lọc theo có mô tả
      if (_hasDescription &&
          (room.description.isEmpty || room.description == 'Không có mô tả')) {
        return false;
      }

      return true;
    }).toList();

    // 🚀 Sort và update UI sau khi filter
    _sortResults();
    setState(() {}); // Update UI một lần
  }

  void _sortResults() {
    if (_sortBy == null) {
      // ⭐ Sort theo VIP priority trước, sau đó timestamp
      _filteredRooms.sort((a, b) {
        final vipCompare = _compareVipPriority(a, b);
        if (vipCompare != 0) return vipCompare;
        // Sort theo timestamp (mới nhất lên đầu)
        return b.timestamp.compareTo(a.timestamp);
      });
    } else {
      switch (_sortBy) {
        case 'Giá tăng dần':
          _filteredRooms.sort((a, b) {
            final vipCompare = _compareVipPriority(a, b);
            if (vipCompare != 0) return vipCompare;
            return a.price.compareTo(b.price);
          });
          break;
        case 'Giá giảm dần':
          _filteredRooms.sort((a, b) {
            final vipCompare = _compareVipPriority(a, b);
            if (vipCompare != 0) return vipCompare;
            return b.price.compareTo(a.price);
          });
          break;
        case 'Diện tích tăng dần':
          _filteredRooms.sort((a, b) {
            final vipCompare = _compareVipPriority(a, b);
            if (vipCompare != 0) return vipCompare;
            return a.area.compareTo(b.area);
          });
          break;
        case 'Diện tích giảm dần':
          _filteredRooms.sort((a, b) {
            final vipCompare = _compareVipPriority(a, b);
            if (vipCompare != 0) return vipCompare;
            return b.area.compareTo(a.area);
          });
          break;
        case 'Mới nhất':
          _filteredRooms.sort((a, b) {
            final vipCompare = _compareVipPriority(a, b);
            if (vipCompare != 0) return vipCompare;
            return b.timestamp.compareTo(a.timestamp);
          });
          break;
        case 'Cũ nhất':
          _filteredRooms.sort((a, b) {
            final vipCompare = _compareVipPriority(a, b);
            if (vipCompare != 0) return vipCompare;
            return a.timestamp.compareTo(b.timestamp);
          });
          break;
        case 'Xem nhiều nhất':
          _filteredRooms.sort((a, b) {
            final vipCompare = _compareVipPriority(a, b);
            if (vipCompare != 0) return vipCompare;
            final viewCompare = b.viewCount.compareTo(a.viewCount);
            if (viewCompare != 0) return viewCompare;
            return b.timestamp.compareTo(a.timestamp);
          });
          break;
      }
    }

    // Reset về trang đầu khi sắp xếp
    _currentPage = 1;
    setState(() {});
  }

  // Helper function to compare VIP priority
  int _compareVipPriority(Room a, Room b) {
    // ⭐ NEW: So sánh VIP priority từ owner (user-based VIP)
    // Tìm owner info từ _allRoomsWithOwners cache
    final aWithOwner = _allRoomsWithOwners.firstWhere(
      (rwo) => rwo.room.id == a.id,
      orElse: () => RoomWithOwner(room: a, owner: null),
    );
    final bWithOwner = _allRoomsWithOwners.firstWhere(
      (rwo) => rwo.room.id == b.id,
      orElse: () => RoomWithOwner(room: b, owner: null),
    );

    // So sánh owner VIP level (Premium=2 > VIP=1 > Free=0)
    return bWithOwner.ownerVipLevel.compareTo(aWithOwner.ownerVipLevel);
  }

  // Sort và update UI
  void _sortAndUpdate() {
    // Sort rooms với VIP priority
    _sortResults();

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
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
              child: const Icon(Icons.home_work, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 12),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Danh sách phòng trọ',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Text(
                  'Tìm kiếm và lọc phòng',
                  style: TextStyle(fontSize: 12, color: Colors.white70),
                ),
              ],
            ),
          ],
        ),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blue.shade700, Colors.cyan.shade500],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        foregroundColor: Colors.white,
        elevation: 4,
        shadowColor: Colors.blue.withOpacity(0.5),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              onPressed: () {
                Navigator.pop(context);
              },
              icon: const Icon(Icons.close),
              tooltip: 'Đóng',
            ),
          ),
        ],
      ),
      bottomNavigationBar: _showRoomListDirectly
          ? null
          : BottomNavigationBar(
              type: BottomNavigationBarType.fixed,
              currentIndex: _currentIndex,
              onTap: (index) {
                setState(() {
                  _currentIndex = index;
                });
              },
              items: const [
                BottomNavigationBarItem(
                  icon: Icon(Icons.home),
                  label: 'Trang chủ',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.favorite),
                  label: 'Yêu thích',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.chat),
                  label: 'Tin nhắn',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.notifications),
                  label: 'Thông báo',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.person),
                  label: 'Cá nhân',
                ),
              ],
            ),
      // 🚀 Inline body để tránh function call không cần thiết
      body: _buildRoomListPage(),
    );
  }

  Widget _buildRoomListPage() {
    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          // Search và Filter Section
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withValues(alpha: 0.1),
                  spreadRadius: 1,
                  blurRadius: 3,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                // Search Bar
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.grey[300]!,
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.blue.withOpacity(0.1),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: TextField(
                            controller: searchController,
                            decoration: InputDecoration(
                              hintText: '🔍 Tìm theo địa điểm, tiêu đề...',
                              hintStyle: TextStyle(
                                color: Colors.grey[400],
                                fontSize: 15,
                              ),
                              prefixIcon: Container(
                                margin: const EdgeInsets.all(8),
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade50,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(
                                  Icons.search,
                                  color: Colors.blue,
                                  size: 22,
                                ),
                              ),
                              border: InputBorder.none,
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide(
                                  color: Colors.blue.shade400,
                                  width: 2,
                                ),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                            ),
                            style: const TextStyle(fontSize: 15),
                            onChanged: (value) {
                              setState(() {
                                _searchQuery = value;
                              });
                              _performSearch();
                            },
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      AnimatedBuilder(
                        animation: _filterButtonController,
                        builder: (context, child) {
                          final value = _filterButtonController.value;
                          final scale = 1.0 + (0.15 * value);
                          final glowIntensity = 0.2 + (0.3 * value);
                          return Transform.scale(
                            scale: scale,
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.blue.shade600,
                                    Colors.cyan.shade400,
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.blue.withOpacity(
                                      glowIntensity,
                                    ),
                                    blurRadius: 12 + (8 * value),
                                    spreadRadius: 2 + (3 * value),
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: _showFilterDialog,
                                  borderRadius: BorderRadius.circular(16),
                                  child: Padding(
                                    padding: const EdgeInsets.all(14),
                                    child: Icon(
                                      Icons.tune,
                                      color: Colors.white,
                                      size: 24,
                                      shadows: [
                                        Shadow(
                                          color: Colors.black.withOpacity(0.3),
                                          blurRadius: 4,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),

                // Stats Bar - Show Results Count
                if (_filteredRooms.isNotEmpty || _searchQuery.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.blue.shade50, Colors.cyan.shade50],
                      ),
                      border: Border(
                        top: BorderSide(color: Colors.blue.shade100),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade100,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            Icons.check_circle,
                            color: Colors.blue.shade700,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Tìm thấy ${_filteredRooms.length} phòng',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue.shade900,
                                  fontSize: 15,
                                ),
                              ),
                              if (_searchQuery.isNotEmpty)
                                Text(
                                  'Kết quả cho "$_searchQuery"',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                            ],
                          ),
                        ),
                        if (_filteredRooms.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade600,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.blue.withOpacity(0.3),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Text(
                              '${_filteredRooms.length}',
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

                // Sort Section
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border(top: BorderSide(color: Colors.grey[200]!)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.sort,
                          color: Colors.orange.shade700,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Sắp xếp:',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.grey[300]!,
                              width: 1.5,
                            ),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _sortBy,
                              isExpanded: true,
                              hint: const Text(
                                'Chọn cách sắp xếp',
                                style: TextStyle(fontSize: 14),
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: 'Mới nhất',
                                  child: Text('Mới nhất'),
                                ),
                                DropdownMenuItem(
                                  value: 'Cũ nhất',
                                  child: Text('Cũ nhất'),
                                ),
                                DropdownMenuItem(
                                  value: 'Giá tăng dần',
                                  child: Text('Giá tăng dần'),
                                ),
                                DropdownMenuItem(
                                  value: 'Giá giảm dần',
                                  child: Text('Giá giảm dần'),
                                ),
                                DropdownMenuItem(
                                  value: 'Diện tích tăng dần',
                                  child: Text('Diện tích tăng dần'),
                                ),
                                DropdownMenuItem(
                                  value: 'Diện tích giảm dần',
                                  child: Text('Diện tích giảm dần'),
                                ),
                                DropdownMenuItem(
                                  value: 'Xem nhiều nhất',
                                  child: Text('Xem nhiều nhất'),
                                ),
                              ],
                              onChanged: (value) {
                                setState(() {
                                  _sortBy = value;
                                });
                                _sortResults();
                              },
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Results Section
          Expanded(
            child: _isLoading
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('Đang tải danh sách phòng...'),
                      ],
                    ),
                  )
                : _filteredRooms.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.search_off,
                            size: 64,
                            color: Colors.grey[400],
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'Không tìm thấy phòng trọ nào',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[700],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Thử thay đổi từ khóa tìm kiếm hoặc bộ lọc',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[500],
                          ),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: () {
                            setState(() {
                              _searchQuery = '';
                              _minPrice = 0;
                              _maxPrice = 10000000;
                              _minArea = 0;
                              _maxArea = 100;
                              _selectedProvince = null;
                              _selectedDistrict = null;
                              _selectedAmenities.clear();
                              _sortBy = null;
                              searchController.clear();
                            });
                            _performSearch();
                          },
                          icon: const Icon(Icons.refresh),
                          label: const Text('Làm mới'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                : Column(
                    children: [
                      // Danh sách phòng với phân trang
                      Expanded(
                        child: ListView.builder(
                          padding: EdgeInsets.only(
                            left: 16,
                            right: 16,
                            top: 16,
                            bottom: _showRoomListDirectly
                                ? 16
                                : 80, // Thêm padding cho bottom bar
                          ),
                          itemCount: _getCurrentPageRooms().length,
                          // 🚀 Optimize with cacheExtent
                          cacheExtent: 500, // Pre-render 500px ahead
                          itemBuilder: (context, index) {
                            final room = _getCurrentPageRooms()[index];

                            return Container(
                              margin: const EdgeInsets.only(bottom: 16),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.grey.withValues(alpha: 0.1),
                                    spreadRadius: 1,
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              // 🚀 ValueListenableBuilder để realtime update
                              child: ValueListenableBuilder<Set<String>>(
                                valueListenable:
                                    favoriteService.favoritesNotifier,
                                builder: (context, favorites, child) {
                                  // 🔥 Tìm owner info từ _allRoomsWithOwners
                                  final roomWithOwner = _allRoomsWithOwners
                                      .firstWhere(
                                        (rwo) => rwo.room.id == room.id,
                                        orElse: () => RoomWithOwner(
                                          room: room,
                                          owner: null,
                                        ),
                                      );

                                  return RoomCard(
                                    room: room,
                                    isFavorite: favorites.contains(room.id),
                                    ownerVipLevel: roomWithOwner.ownerVipLevel,
                                    ownerVipType: roomWithOwner.ownerVipType,
                                    onFavoriteToggle: () =>
                                        _toggleFavorite(room.id),
                                    onTap: () async {
                                      // 🚀 Navigate và refresh khi quay lại
                                      await Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              RoomDetailPage(room: room),
                                        ),
                                      );
                                      // 🚀 Chỉ refresh rooms để cập nhật view count
                                      if (mounted) {
                                        _loadRoomsOnce();
                                      }
                                    },
                                  );
                                },
                              ),
                            );
                          },
                        ),
                      ),
                      // Phân trang
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: _buildPaginationSection(),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  // Lấy phòng cho trang hiện tại
  List<Room> _getCurrentPageRooms() {
    final startIndex = (_currentPage - 1) * _roomsPerPage;
    final endIndex = (startIndex + _roomsPerPage).clamp(
      0,
      _filteredRooms.length,
    );
    return _filteredRooms.sublist(
      startIndex.clamp(0, _filteredRooms.length),
      endIndex,
    );
  }

  // Widget phân trang - nằm dưới danh sách bài đăng
  Widget _buildPaginationSection() {
    final totalPages = (_filteredRooms.length / _roomsPerPage).ceil();
    if (totalPages <= 1) return const SizedBox.shrink();

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Nút Previous
        _buildPaginationButton(
          icon: Icons.chevron_left,
          isEnabled: _currentPage > 1,
          onPressed: _currentPage > 1
              ? () {
                  setState(() {
                    _currentPage--;
                  });
                }
              : null,
          tooltip: 'Trang trước',
        ),

        const SizedBox(width: 6),

        // Số trang
        if (totalPages <= 7)
          // Hiển thị tất cả trang nếu ít hơn 7 trang
          ...List.generate(totalPages, (index) {
            final pageNum = index + 1;
            return _buildPageNumberButton(pageNum, totalPages);
          })
        else
          // Hiển thị trang thông minh cho nhiều trang
          ..._buildSmartPageNumbers(totalPages),

        const SizedBox(width: 6),

        // Nút Next
        _buildPaginationButton(
          icon: Icons.chevron_right,
          isEnabled: _currentPage < totalPages,
          onPressed: _currentPage < totalPages
              ? () {
                  setState(() {
                    _currentPage++;
                  });
                }
              : null,
          tooltip: 'Trang sau',
        ),
      ],
    );
  }

  Widget _buildPaginationButton({
    required IconData icon,
    required bool isEnabled,
    required VoidCallback? onPressed,
    required String tooltip,
  }) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: isEnabled ? Colors.blue : Colors.grey[200],
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isEnabled ? Colors.blue : Colors.grey[300]!,
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            width: 40,
            height: 40,
            child: Icon(icon, color: Colors.white, size: 20),
          ),
        ),
      ),
    );
  }

  Widget _buildPageNumberButton(int pageNum, int totalPages) {
    final isCurrentPage = _currentPage == pageNum;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 1),
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: isCurrentPage ? Colors.blue : Colors.white,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isCurrentPage ? Colors.blue : Colors.grey[300]!,
            width: 1,
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              setState(() {
                _currentPage = pageNum;
              });
            },
            borderRadius: BorderRadius.circular(6),
            child: Center(
              child: Text(
                '$pageNum',
                style: TextStyle(
                  color: isCurrentPage ? Colors.white : Colors.black87,
                  fontWeight: isCurrentPage ? FontWeight.bold : FontWeight.w500,
                  fontSize: 12,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildSmartPageNumbers(int totalPages) {
    final List<Widget> pageNumbers = [];

    // Luôn hiển thị trang đầu
    pageNumbers.add(_buildPageNumberButton(1, totalPages));

    if (_currentPage > 3) {
      pageNumbers.add(
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            '...',
            style: TextStyle(color: Colors.grey, fontSize: 16),
          ),
        ),
      );
    }

    // Hiển thị các trang xung quanh trang hiện tại
    final startPage = (_currentPage - 1).clamp(2, totalPages - 1);
    final endPage = (_currentPage + 1).clamp(2, totalPages - 1);

    for (int i = startPage; i <= endPage; i++) {
      if (i != 1 && i != totalPages) {
        pageNumbers.add(_buildPageNumberButton(i, totalPages));
      }
    }

    if (_currentPage < totalPages - 2) {
      pageNumbers.add(
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            '...',
            style: TextStyle(color: Colors.grey, fontSize: 16),
          ),
        ),
      );
    }

    // Luôn hiển thị trang cuối (nếu không phải trang đầu)
    if (totalPages > 1) {
      pageNumbers.add(_buildPageNumberButton(totalPages, totalPages));
    }

    return pageNumbers;
  }

  void _showFilterDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Bộ lọc nâng cao',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),

              // Giá
              Text(
                'Giá thuê (${NumberFormat('#,###').format(_minPrice)} - ${NumberFormat('#,###').format(_maxPrice)}đ)',
              ),
              RangeSlider(
                values: RangeValues(_minPrice, _maxPrice),
                min: 0,
                max: 10000000,
                divisions: 100,
                onChanged: (values) {
                  setModalState(() {
                    _minPrice = values.start;
                    _maxPrice = values.end;
                  });
                },
              ),

              // Diện tích
              Text('Diện tích (${_minArea.toInt()} - ${_maxArea.toInt()}m²)'),
              RangeSlider(
                values: RangeValues(_minArea, _maxArea),
                min: 0,
                max: 100,
                divisions: 20,
                onChanged: (values) {
                  setModalState(() {
                    _minArea = values.start;
                    _maxArea = values.end;
                  });
                },
              ),

              // Tỉnh/thành phố
              DropdownButtonFormField<String>(
                value: _selectedProvince,
                decoration: const InputDecoration(labelText: 'Tỉnh/Thành phố'),
                items: VietnamLocations.getProvinceNames().map((province) {
                  return DropdownMenuItem(
                    value: province,
                    child: Text(province),
                  );
                }).toList(),
                onChanged: (value) {
                  setModalState(() {
                    _selectedProvince = value;
                    _selectedDistrict = null;
                  });
                },
              ),

              // Quận/huyện
              if (_selectedProvince != null)
                DropdownButtonFormField<String>(
                  value: _selectedDistrict,
                  decoration: const InputDecoration(labelText: 'Quận/Huyện'),
                  items: VietnamLocations.getDistrictNames(_selectedProvince!)
                      .map((district) {
                        return DropdownMenuItem(
                          value: district,
                          child: Text(district),
                        );
                      })
                      .toList(),
                  onChanged: (value) {
                    setModalState(() {
                      _selectedDistrict = value;
                    });
                  },
                ),

              // Tiện nghi
              const Text(
                'Tiện nghi:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Wrap(
                children: amenitiesList.map((amenity) {
                  return FilterChip(
                    label: Text(amenity),
                    selected: _selectedAmenities.contains(amenity),
                    onSelected: (selected) {
                      setModalState(() {
                        if (selected) {
                          _selectedAmenities.add(amenity);
                        } else {
                          _selectedAmenities.remove(amenity);
                        }
                      });
                    },
                  );
                }).toList(),
              ),

              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        setModalState(() {
                          _minPrice = 0;
                          _maxPrice = 10000000;
                          _minArea = 0;
                          _maxArea = 100;
                          _selectedProvince = null;
                          _selectedDistrict = null;
                          _selectedAmenities.clear();
                        });
                      },
                      child: const Text('Đặt lại'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _performSearch();
                      },
                      child: const Text('Áp dụng'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
