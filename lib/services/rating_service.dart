import 'package:firebase_database/firebase_database.dart';

class RatingService {
  static final RatingService _instance = RatingService._internal();
  factory RatingService() => _instance;
  RatingService._internal();

  final dbRef = FirebaseDatabase.instance.ref();

  /// Tính toán rating trung bình cho một phòng
  Future<Map<String, dynamic>> calculateRoomRating(String roomId) async {
    try {
      final reviewsSnapshot = await dbRef
          .child('reviews')
          .orderByChild('roomId')
          .equalTo(roomId)
          .get();

      if (!reviewsSnapshot.exists || reviewsSnapshot.value == null) {
        return {'averageRating': 0.0, 'reviewCount': 0};
      }

      final reviews = reviewsSnapshot.value as Map;
      double totalRating = 0.0;
      int count = 0;

      for (var review in reviews.values) {
        final reviewData = review as Map;
        final rating = (reviewData['rating'] ?? 0).toDouble();
        if (rating > 0) {
          totalRating += rating;
          count++;
        }
      }

      final averageRating = count > 0 ? totalRating / count : 0.0;

      return {'averageRating': averageRating, 'reviewCount': count};
    } catch (e) {
      print('❌ Lỗi tính rating: $e');
      return {'averageRating': 0.0, 'reviewCount': 0};
    }
  }

  /// Cập nhật rating cho một phòng
  Future<void> updateRoomRating(String roomId) async {
    try {
      final ratingData = await calculateRoomRating(roomId);

      await dbRef.child('rooms').child(roomId).update({
        'averageRating': ratingData['averageRating'],
        'reviewCount': ratingData['reviewCount'],
      });

      print(
        '✅ Đã cập nhật rating cho phòng $roomId: ${ratingData['averageRating']} (${ratingData['reviewCount']} đánh giá)',
      );
    } catch (e) {
      print('❌ Lỗi cập nhật rating: $e');
    }
  }

  /// Cập nhật rating cho tất cả phòng
  Future<void> updateAllRoomRatings() async {
    try {
      final roomsSnapshot = await dbRef.child('rooms').get();

      if (!roomsSnapshot.exists || roomsSnapshot.value == null) {
        return;
      }

      final rooms = roomsSnapshot.value as Map;
      final updates = <String, dynamic>{};

      for (var roomId in rooms.keys) {
        final ratingData = await calculateRoomRating(roomId);
        updates['rooms/$roomId/averageRating'] = ratingData['averageRating'];
        updates['rooms/$roomId/reviewCount'] = ratingData['reviewCount'];
      }

      await dbRef.update(updates);
    } catch (e) {
      print('❌ Lỗi cập nhật tất cả rating: $e');
    }
  }

  /// Kiểm tra và sửa dữ liệu rating không nhất quán
  Future<void> fixInconsistentRatings() async {
    try {
      final roomsSnapshot = await dbRef.child('rooms').get();

      if (!roomsSnapshot.exists || roomsSnapshot.value == null) {
        return;
      }

      final rooms = roomsSnapshot.value as Map;
      final updates = <String, dynamic>{};
      int fixedCount = 0;

      for (var roomId in rooms.keys) {
        final roomData = rooms[roomId] as Map;
        final storedReviewCount = roomData['reviewCount'] ?? 0;
        final storedAverageRating = (roomData['averageRating'] ?? 0.0)
            .toDouble();

        // Tính toán rating thực tế
        final actualRatingData = await calculateRoomRating(roomId);
        final actualReviewCount = actualRatingData['reviewCount'];
        final actualAverageRating = actualRatingData['averageRating'];

        // Kiểm tra sự không nhất quán
        if (storedReviewCount != actualReviewCount ||
            (storedAverageRating - actualAverageRating).abs() > 0.01) {
          updates['rooms/$roomId/reviewCount'] = actualReviewCount;
          updates['rooms/$roomId/averageRating'] = actualAverageRating;
          fixedCount++;

          print(
            '🔧 Sửa phòng $roomId: $storedReviewCount → $actualReviewCount, $storedAverageRating → $actualAverageRating',
          );
        }
      }

      if (updates.isNotEmpty) {
        await dbRef.update(updates);
        print('✅ Đã sửa $fixedCount phòng có dữ liệu rating không nhất quán');
      } else {
        print('✅ Tất cả dữ liệu rating đã nhất quán');
      }
    } catch (e) {
      print('❌ Lỗi sửa dữ liệu rating: $e');
    }
  }

  /// Lấy rating của một phòng
  Future<Map<String, dynamic>> getRoomRating(String roomId) async {
    try {
      final roomSnapshot = await dbRef.child('rooms').child(roomId).get();

      if (!roomSnapshot.exists || roomSnapshot.value == null) {
        return {'averageRating': 0.0, 'reviewCount': 0};
      }

      final roomData = roomSnapshot.value as Map;
      return {
        'averageRating': (roomData['averageRating'] ?? 0.0).toDouble(),
        'reviewCount': roomData['reviewCount'] ?? 0,
      };
    } catch (e) {
      print('❌ Lỗi lấy rating: $e');
      return {'averageRating': 0.0, 'reviewCount': 0};
    }
  }
}
