import 'package:firebase_database/firebase_database.dart';
import '../models/room_model.dart';
import '../models/user_profile.dart';
import '../models/room_with_owner.dart';

/// Service để load rooms kèm owner VIP info
class RoomService {
  final _dbRef = FirebaseDatabase.instance.ref();

  // Singleton
  static final RoomService _instance = RoomService._internal();
  factory RoomService() => _instance;
  RoomService._internal();

  // 🚀 Cache owner profiles (TTL: 30 seconds)
  final Map<String, Map<String, dynamic>> _ownerCache = {};
  static const int _cacheExpirySeconds = 30;

  /// Load tất cả rooms approved kèm owner info
  Future<List<RoomWithOwner>> loadRoomsWithOwners({int limit = 30}) async {
    try {
      // 1. Load rooms
      final roomsSnapshot = await _dbRef
          .child('rooms')
          .orderByChild('status')
          .equalTo('approved')
          .limitToFirst(limit)
          .get();

      if (!roomsSnapshot.exists || roomsSnapshot.value == null) {
        return [];
      }

      final roomsMap = roomsSnapshot.value as Map;
      final List<Room> rooms = [];

      // 2. Parse rooms trước - 🔥 chỉ lấy phòng có availabilityStatus 'DangMo' hoặc 'DaDatLich'
      for (final entry in roomsMap.entries) {
        final roomData = entry.value as Map;
        final room = Room.fromMap(entry.key, roomData);
        // 🔥 Chỉ thêm phòng có trạng thái đang mở hoặc đã đặt lịch
        if (room.availabilityStatus == 'DangMo' ||
            room.availabilityStatus == 'DaDatLich') {
          rooms.add(room);
        }
      }

      // 3. 🚀 Load owner profiles SONG SONG (batch loading)
      final uniqueOwnerIds = rooms.map((r) => r.ownerId).toSet().toList();

      // Load tất cả owner profiles cùng lúc
      final ownerFutures = uniqueOwnerIds.map((id) => _loadOwnerProfile(id));
      final ownerProfiles = await Future.wait(ownerFutures);

      // Map ownerId -> UserProfile
      final ownerMap = <String, UserProfile?>{};
      for (var i = 0; i < uniqueOwnerIds.length; i++) {
        ownerMap[uniqueOwnerIds[i]] = ownerProfiles[i];
      }

      // 4. Kết hợp rooms với owner info
      final List<RoomWithOwner> roomsWithOwners = [];
      for (final room in rooms) {
        final ownerProfile = ownerMap[room.ownerId];
        roomsWithOwners.add(RoomWithOwner(room: room, owner: ownerProfile));
      }

      // 5. Sắp xếp theo owner VIP level
      _sortRoomsByOwnerVip(roomsWithOwners);

      return roomsWithOwners;
    } catch (e) {
      print('❌ Error loading rooms with owners: $e');
      return [];
    }
  }

  /// Load owner profile từ userId (with cache)
  Future<UserProfile?> _loadOwnerProfile(String userId) async {
    // 🚀 Check cache first
    if (_ownerCache.containsKey(userId)) {
      final cached = _ownerCache[userId]!;
      final cachedTime = cached['_cachedAt'] as int? ?? 0;
      final now = DateTime.now().millisecondsSinceEpoch;
      final expiryTime = _cacheExpirySeconds * 1000;

      if (now - cachedTime < expiryTime) {
        // Return cached UserProfile
        return cached['profile'] as UserProfile?;
      }
      _ownerCache.remove(userId);
    }

    try {
      final snapshot = await _dbRef.child('users').child(userId).get();

      if (snapshot.exists && snapshot.value != null) {
        final profile = UserProfile.fromMap(userId, snapshot.value as Map);

        // 🚀 Cache the result
        _ownerCache[userId] = {
          'profile': profile,
          '_cachedAt': DateTime.now().millisecondsSinceEpoch,
        };

        return profile;
      }

      return null;
    } catch (e) {
      print('❌ Error loading owner profile: $e');
      return null;
    }
  }

  /// Clear cache (gọi khi cần fresh data)
  void clearCache() {
    _ownerCache.clear();
  }

  /// Sắp xếp rooms theo owner VIP level
  void _sortRoomsByOwnerVip(List<RoomWithOwner> rooms) {
    rooms.sort((a, b) {
      // BƯỚC 1: So sánh owner VIP level (Premium > VIP > Free)
      final vipCompare = b.ownerVipLevel.compareTo(a.ownerVipLevel);
      if (vipCompare != 0) return vipCompare;

      // BƯỚC 2: Cùng VIP level → sắp xếp theo timestamp (mới → cũ)
      return b.room.timestamp.compareTo(a.room.timestamp);
    });

    // Debug log
    print('✅ Sorted ${rooms.length} rooms by owner VIP:');
    for (var i = 0; i < rooms.length && i < 5; i++) {
      print(
        '   [$i] ${rooms[i].room.title} - Owner VIP: ${rooms[i].ownerVipName} (level ${rooms[i].ownerVipLevel})',
      );
    }
  }

  /// Load single room với owner info
  Future<RoomWithOwner?> loadRoomWithOwner(String roomId) async {
    try {
      final roomSnapshot = await _dbRef.child('rooms').child(roomId).get();

      if (!roomSnapshot.exists || roomSnapshot.value == null) {
        return null;
      }

      final room = Room.fromMap(roomId, roomSnapshot.value as Map);
      final owner = await _loadOwnerProfile(room.ownerId);

      return RoomWithOwner(room: room, owner: owner);
    } catch (e) {
      print('❌ Error loading room with owner: $e');
      return null;
    }
  }

  /// Load rooms của một owner cụ thể
  Future<List<RoomWithOwner>> loadOwnerRooms(String ownerId) async {
    try {
      final roomsSnapshot = await _dbRef
          .child('rooms')
          .orderByChild('ownerId')
          .equalTo(ownerId)
          .get();

      if (!roomsSnapshot.exists || roomsSnapshot.value == null) {
        return [];
      }

      final roomsMap = roomsSnapshot.value as Map;
      final ownerProfile = await _loadOwnerProfile(ownerId);
      final List<RoomWithOwner> roomsWithOwners = [];

      for (final entry in roomsMap.entries) {
        final room = Room.fromMap(entry.key, entry.value as Map);
        roomsWithOwners.add(RoomWithOwner(room: room, owner: ownerProfile));
      }

      // Sắp xếp theo timestamp (mới nhất lên đầu)
      roomsWithOwners.sort(
        (a, b) => b.room.timestamp.compareTo(a.room.timestamp),
      );

      return roomsWithOwners;
    } catch (e) {
      print('❌ Error loading owner rooms: $e');
      return [];
    }
  }
}
