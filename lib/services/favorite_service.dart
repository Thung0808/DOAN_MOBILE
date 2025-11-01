import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';

/// 🚀 Singleton service quản lý favorites với realtime sync
class FavoriteService {
  static final FavoriteService _instance = FavoriteService._internal();
  factory FavoriteService() => _instance;
  FavoriteService._internal() {
    _initStream();
  }

  final dbRef = FirebaseDatabase.instance.ref();
  final user = FirebaseAuth.instance.currentUser!;

  // 🚀 Cache favorites trong memory để truy cập nhanh
  final ValueNotifier<Set<String>> _favoritesNotifier = ValueNotifier({});

  // Public getter để listen
  ValueListenable<Set<String>> get favoritesNotifier => _favoritesNotifier;

  // Stream subscription
  StreamSubscription? _favoritesSubscription;

  /// Khởi tạo stream để lắng nghe thay đổi từ Firebase
  void _initStream() {
    _favoritesSubscription = dbRef
        .child('users')
        .child(user.uid)
        .child('favorites')
        .onValue
        .listen(
          (event) {
            if (event.snapshot.exists && event.snapshot.value is List) {
              final favorites = List<String>.from(event.snapshot.value as List);
              _favoritesNotifier.value = favorites.toSet();
              print(
                '🔄 FAVORITES: Updated from Firebase - ${favorites.length} items',
              );
            } else {
              _favoritesNotifier.value = {};
              print('🔄 FAVORITES: Cleared (no data)');
            }
          },
          onError: (error) {
            print('❌ FAVORITES: Stream error - $error');
          },
        );
  }

  /// Lấy danh sách favorites hiện tại (sync từ cache)
  Set<String> get currentFavorites => _favoritesNotifier.value;

  /// Kiểm tra room có trong favorites không (sync từ cache)
  bool isFavorite(String roomId) {
    return _favoritesNotifier.value.contains(roomId);
  }

  /// Toggle favorite cho một room
  /// Returns: true nếu đã thêm, false nếu đã xóa
  Future<bool> toggleFavorite(String roomId) async {
    try {
      final currentSet = Set<String>.from(_favoritesNotifier.value);
      final wasFavorite = currentSet.contains(roomId);

      if (wasFavorite) {
        currentSet.remove(roomId);
        print('❌ FAVORITES: Removing $roomId');
      } else {
        currentSet.add(roomId);
        print('✅ FAVORITES: Adding $roomId');
      }

      // 🚀 Optimistic update - cập nhật UI ngay lập tức
      _favoritesNotifier.value = currentSet;

      // Lưu vào Firebase
      await dbRef
          .child('users')
          .child(user.uid)
          .child('favorites')
          .set(currentSet.toList());

      return !wasFavorite;
    } catch (e) {
      print('❌ Lỗi toggle favorite: $e');
      // Rollback on error - Firebase stream sẽ tự động sync lại
      rethrow;
    }
  }

  /// Load favorites một lần (fallback nếu stream chưa ready)
  Future<void> loadFavorites() async {
    try {
      final snapshot = await dbRef
          .child('users')
          .child(user.uid)
          .child('favorites')
          .get();

      if (snapshot.exists && snapshot.value is List) {
        final favorites = List<String>.from(snapshot.value as List);
        _favoritesNotifier.value = favorites.toSet();
      } else {
        _favoritesNotifier.value = {};
      }
    } catch (e) {
      print('❌ Lỗi load favorites: $e');
    }
  }

  /// Dispose resources
  void dispose() {
    _favoritesSubscription?.cancel();
    _favoritesNotifier.dispose();
  }
}
