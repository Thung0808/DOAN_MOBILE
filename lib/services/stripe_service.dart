import 'dart:convert';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

class StripeService {
  static final StripeService _instance = StripeService._internal();
  factory StripeService() => _instance;
  StripeService._internal();

  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();

  // Backend URL (sẽ chạy local)
  static const String _backendUrl = 'http://10.0.2.2:3000/api';

  // Initialize Stripe
  static Future<void> initialize() async {
    try {
      Stripe.publishableKey =
          'pk_test_51SLS953F9BqMqSZxROE90ZiMLXHBHuxP9od1omiRh5x0yXyQPw0HEMpS5tK3ZNn1r2BFzxWore0HgMCusivyMYWj00i5XX3KGL';
      await Stripe.instance.applySettings();
      print('✅ Stripe initialized successfully');
    } catch (e) {
      print('❌ Stripe initialization failed: $e');
      // Không throw error để app vẫn chạy được
    }
  }

  // Tạo Payment Intent và lấy client secret từ backend
  Future<Map<String, dynamic>?> createPaymentIntent({
    required double amount,
    required String currency,
    required String description,
    String? bookingId,
    String? roomId,
    String? packageId,
    String? packageType,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not authenticated');

      final response = await http.post(
        Uri.parse('$_backendUrl/create-payment-intent'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'amount': amount.toInt(), // VND không có cents, không nhân 100
          'currency': currency,
          'description': description,
          'userId': user.uid,
          'bookingId': bookingId,
          'roomId': roomId,
          'packageId': packageId,
          'packageType': packageType,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data;
      } else {
        print('Error creating payment intent: ${response.statusCode}');
        print('Response: ${response.body}');
        return null;
      }
    } catch (e) {
      print('Exception creating payment intent: $e');
      return null;
    }
  }

  // Tạo Payment Intent cho VIP Package
  Future<Map<String, dynamic>?> createVipPaymentIntent({
    required String packageId,
    required String packageName,
    required String packageType,
    required double amount,
    required String roomId,
    required String roomTitle,
  }) async {
    return createPaymentIntent(
      amount: amount,
      currency: 'vnd',
      description: 'Mua gói $packageName cho $roomTitle',
      roomId: roomId,
      packageId: packageId,
      packageType: packageType,
    );
  }

  // Lưu payment thành công vào Firebase (dùng với Payment Sheet)
  Future<void> saveSuccessfulPayment({
    required String paymentIntentId,
    required double amount,
    String? bookingId,
    String? roomId,
    String? roomTitle,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not authenticated');

      await _savePaymentRecord(
        paymentIntentId: paymentIntentId,
        userId: user.uid,
        amount: amount,
        status: 'success',
        bookingId: bookingId,
        roomId: roomId,
        roomTitle: roomTitle,
      );
    } catch (e) {
      print('Error saving payment: $e');
    }
  }

  // Lưu payment record vào Firebase
  Future<void> _savePaymentRecord({
    required String paymentIntentId,
    required String userId,
    required double amount,
    required String status,
    String? bookingId,
    String? roomId,
    String? roomTitle,
  }) async {
    try {
      final paymentRef = _dbRef.child('payments').child(paymentIntentId);

      await paymentRef.set({
        'id': paymentIntentId,
        'userId': userId,
        'amount': amount,
        'currency': 'vnd',
        'paymentMethod': 'stripe',
        'status': status,
        'createdAt': DateTime.now().millisecondsSinceEpoch,
        'bookingId': bookingId,
        'roomId': roomId,
        'roomTitle': roomTitle,
      });

      // Lưu vào user payments
      await _dbRef
          .child('users')
          .child(userId)
          .child('payments')
          .child(paymentIntentId)
          .set({
            'paymentIntentId': paymentIntentId,
            'amount': amount,
            'status': status,
            'createdAt': DateTime.now().millisecondsSinceEpoch,
          });
    } catch (e) {
      print('Error saving payment record: $e');
    }
  }

  // Lấy payment từ Firebase
  Future<Map<String, dynamic>?> getPayment(String paymentIntentId) async {
    try {
      final snapshot = await _dbRef
          .child('payments')
          .child(paymentIntentId)
          .get();

      if (snapshot.exists) {
        return Map<String, dynamic>.from(snapshot.value as Map);
      }
      return null;
    } catch (e) {
      print('Error getting payment: $e');
      return null;
    }
  }

  // Lấy danh sách payments của user
  Future<List<Map<String, dynamic>>> getUserPayments(String userId) async {
    try {
      final snapshot = await _dbRef
          .child('payments')
          .orderByChild('userId')
          .equalTo(userId)
          .get();

      if (snapshot.exists) {
        final paymentsMap = snapshot.value as Map<dynamic, dynamic>;
        return paymentsMap.entries
            .map((e) => Map<String, dynamic>.from(e.value as Map))
            .toList()
          ..sort(
            (a, b) => (b['createdAt'] as int).compareTo(a['createdAt'] as int),
          );
      }
      return [];
    } catch (e) {
      print('Error getting user payments: $e');
      return [];
    }
  }
}
