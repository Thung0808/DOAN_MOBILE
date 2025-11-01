import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import '../models/vip_package_model.dart';
import '../models/vip_subscription_model.dart';
import '../models/user_profile.dart';

/// VipService mới - VIP theo USER (không theo phòng)
class VipServiceUser {
  final _auth = FirebaseAuth.instance;
  final _dbRef = FirebaseDatabase.instance.ref();

  // Singleton pattern
  static final VipServiceUser _instance = VipServiceUser._internal();
  factory VipServiceUser() => _instance;
  VipServiceUser._internal();

  // Lấy tất cả gói VIP
  List<VipPackage> getAvailablePackages() {
    return VipPackage.getDefaultPackages();
  }

  // Lấy VIP subscription đang hoạt động của user
  Future<VipSubscription?> getActiveVipForUser(String userId) async {
    try {
      final snapshot = await _dbRef
          .child('vipSubscriptions')
          .orderByChild('userId')
          .equalTo(userId)
          .get();

      if (!snapshot.exists || snapshot.value == null) return null;

      final data = snapshot.value as Map;

      // Tìm subscription còn hiệu lực
      for (final entry in data.entries) {
        final sub = VipSubscription.fromMap(entry.key, entry.value as Map);
        if (sub.isActive) {
          return sub;
        }
      }

      return null;
    } catch (e) {
      print('❌ Lỗi lấy VIP subscription: $e');
      return null;
    }
  }

  // Lấy UserProfile hiện tại với VIP info
  Future<UserProfile?> getCurrentUserProfile() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return null;

      final snapshot = await _dbRef.child('users').child(user.uid).get();

      if (snapshot.exists && snapshot.value != null) {
        return UserProfile.fromMap(user.uid, snapshot.value as Map);
      }

      return null;
    } catch (e) {
      print('❌ Lỗi lấy UserProfile: $e');
      return null;
    }
  }

  // Mua gói VIP cho USER
  Future<String> purchaseVipPackage({
    required VipPackage package,
    required String paymentMethod,
    String? paymentId,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('Chưa đăng nhập');

      // 1. Nếu không có paymentId (demo payment), tạo demo ID
      final finalPaymentId =
          paymentId ?? 'DEMO_${DateTime.now().millisecondsSinceEpoch}';

      if (paymentId == null) {
        // Simulate payment cho demo methods
        await Future.delayed(const Duration(seconds: 1));
      }

      // 2. Tạo VIP Subscription cho USER
      final now = DateTime.now();
      final endDate = now.add(Duration(days: package.durationDays));

      final subscriptionRef = _dbRef.child('vipSubscriptions').push();
      final subscriptionId = subscriptionRef.key!;

      final subscription = VipSubscription(
        id: subscriptionId,
        userId: user.uid,
        packageId: package.id,
        packageName: package.name,
        packageType: package.type,
        packagePriority: package.priority,
        price: package.price,
        startDate: now,
        endDate: endDate,
        status: 'active',
        paymentId: finalPaymentId,
        paymentMethod: paymentMethod,
        createdAt: DateTime.now().millisecondsSinceEpoch,
        features: package.features,
      );

      await subscriptionRef.set(subscription.toMap());

      // 3. Cập nhật VIP info vào USER profile
      await _dbRef.child('users').child(user.uid).update({
        'vipLevel': package.priority,
        'vipType': package.type,
        'vipEndDate': endDate.millisecondsSinceEpoch,
      });

      print('✅ VIP activated for user ${user.uid}:');
      print('   - Type: ${package.type}');
      print('   - Level: ${package.priority}');
      print('   - End: $endDate');

      // 4. Lưu vào lịch sử user
      await _dbRef
          .child('users')
          .child(user.uid)
          .child('vipPurchases')
          .child(subscriptionId)
          .set({
            'packageName': package.name,
            'packageType': package.type,
            'price': package.price,
            'startDate': now.millisecondsSinceEpoch,
            'endDate': endDate.millisecondsSinceEpoch,
            'createdAt': DateTime.now().millisecondsSinceEpoch,
          });

      // 5. Tạo thông báo
      final notificationRef = _dbRef
          .child('users')
          .child(user.uid)
          .child('notifications')
          .push();

      await notificationRef.set({
        'title': '✅ Mua gói VIP thành công',
        'content':
            'Bạn đã kích hoạt "${package.name}". Tất cả phòng của bạn sẽ được ưu tiên hiển thị đến ${_formatDate(endDate)}.',
        'type': 'vip_purchase',
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'isRead': false,
      });

      return subscriptionId;
    } catch (e) {
      print('❌ Lỗi mua gói VIP: $e');
      rethrow;
    }
  }

  // Lấy lịch sử VIP của user
  Future<List<VipSubscription>> getUserVipHistory() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return [];

      final snapshot = await _dbRef
          .child('vipSubscriptions')
          .orderByChild('userId')
          .equalTo(user.uid)
          .get();

      if (!snapshot.exists || snapshot.value == null) return [];

      final data = snapshot.value as Map;
      final subscriptions = <VipSubscription>[];

      for (final entry in data.entries) {
        subscriptions.add(
          VipSubscription.fromMap(entry.key, entry.value as Map),
        );
      }

      // Sắp xếp theo thời gian tạo mới nhất
      subscriptions.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      return subscriptions;
    } catch (e) {
      print('❌ Lỗi lấy lịch sử VIP: $e');
      return [];
    }
  }

  // Auto-expire VIP subscriptions của tất cả users
  Future<void> checkAndExpireVipSubscriptions() async {
    try {
      final snapshot = await _dbRef
          .child('vipSubscriptions')
          .orderByChild('status')
          .equalTo('active')
          .get();

      if (!snapshot.exists || snapshot.value == null) return;

      final data = snapshot.value as Map;
      final now = DateTime.now();

      for (final entry in data.entries) {
        final sub = VipSubscription.fromMap(entry.key, entry.value as Map);

        // Nếu hết hạn, cập nhật status
        if (now.isAfter(sub.endDate)) {
          print('⏰ Expiring VIP: ${sub.packageName} for user ${sub.userId}');

          // 1. Cập nhật subscription status
          await _dbRef.child('vipSubscriptions').child(entry.key).update({
            'status': 'expired',
          });

          // 2. Downgrade user về FREE
          await _dbRef.child('users').child(sub.userId).update({
            'vipLevel': 0,
            'vipType': 'free',
            'vipEndDate': null,
          });

          // 3. Thông báo hết hạn
          final notificationRef = _dbRef
              .child('users')
              .child(sub.userId)
              .child('notifications')
              .push();

          await notificationRef.set({
            'title': '⏰ Gói VIP đã hết hạn',
            'content':
                'Gói "${sub.packageName}" của bạn đã hết hạn. Gia hạn ngay để tiếp tục nhận ưu đãi cho tất cả phòng!',
            'type': 'vip_expired',
            'timestamp': DateTime.now().millisecondsSinceEpoch,
            'isRead': false,
          });
        }
      }

      print('✅ VIP expiry check completed');
    } catch (e) {
      print('❌ Lỗi check expire VIP: $e');
    }
  }

  // Gửi nhắc nhở trước khi VIP hết hạn
  Future<void> checkAndSendExpiryReminders() async {
    try {
      final snapshot = await _dbRef
          .child('vipSubscriptions')
          .orderByChild('status')
          .equalTo('active')
          .get();

      if (!snapshot.exists || snapshot.value == null) return;

      final data = snapshot.value as Map;
      final now = DateTime.now();

      for (final entry in data.entries) {
        final sub = VipSubscription.fromMap(entry.key, entry.value as Map);
        final daysRemaining = sub.endDate.difference(now).inDays;

        // Nhắc khi còn 3 ngày
        if (daysRemaining == 3) {
          await _sendReminderNotification(
            sub,
            '⚠️ Gói VIP sắp hết hạn',
            'Gói "${sub.packageName}" còn 3 ngày. Gia hạn ngay để tiếp tục ưu đãi cho tất cả phòng!',
          );
        }

        // Nhắc khi còn 1 ngày
        if (daysRemaining == 1) {
          await _sendReminderNotification(
            sub,
            '🚨 VIP hết hạn vào ngày mai',
            'Gói "${sub.packageName}" sẽ hết hạn vào ngày mai! Gia hạn ngay!',
          );
        }
      }

      print('✅ VIP expiry reminders sent');
    } catch (e) {
      print('❌ Lỗi sending VIP reminders: $e');
    }
  }

  // Gửi notification nhắc nhở
  Future<void> _sendReminderNotification(
    VipSubscription sub,
    String title,
    String content,
  ) async {
    try {
      final notificationRef = _dbRef
          .child('users')
          .child(sub.userId)
          .child('notifications')
          .push();

      await notificationRef.set({
        'title': title,
        'content': content,
        'type': 'vip_reminder',
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'isRead': false,
      });
    } catch (e) {
      print('❌ Lỗi sending reminder: $e');
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }
}
