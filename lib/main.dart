import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'login_page.dart';
import 'home_page.dart';
import 'admin/admin_panel.dart';
import 'services/auth_service.dart';
import 'services/stripe_service.dart';
import 'services/deposit_auto_release_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await StripeService.initialize(); // Initialize Stripe

  // ❌ COMMENTED OUT: Không nên gọi trước khi user login (permission denied)
  // VipServiceUser()
  //     .checkAndExpireVipSubscriptions()
  //     .then((_) {
  //       print('✅ User VIP expiry check completed');
  //     })
  //     .catchError((e) {
  //       print('❌ User VIP expiry check failed: $e');
  //     });

  // VipServiceUser()
  //     .checkAndSendExpiryReminders()
  //     .then((_) {
  //       print('✅ User VIP reminders sent');
  //     })
  //     .catchError((e) {
  //       print('❌ User VIP reminders failed: $e');
  //     });

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Tìm Trọ',
      theme: ThemeData(primarySwatch: Colors.blue, useMaterial3: true),
      home: const AuthWrapper(),
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool _isLoading = true;
  Widget _initialPage = const LoginPage();

  @override
  void initState() {
    super.initState();
    _checkAuthState();
  }

  Future<void> _checkAuthState() async {
    try {
      // Kiểm tra Firebase Auth trước
      final user = FirebaseAuth.instance.currentUser;

      if (user != null) {
        // User đã đăng nhập, kiểm tra role
        final authResult = await AuthService.checkAutoLogin();

        if (authResult != null) {
          final role = authResult['role'] as String;
          if (role == 'admin') {
            _initialPage = const AdminPanel();
          } else {
            _initialPage = const HomePage();
          }
        } else {
          _initialPage = const HomePage();
        }

        // Tự động kiểm tra và release các đặt cọc đã quá hạn (24h)
        DepositAutoReleaseService.scheduleAutoRelease()
            .then((_) => print('✅ Deposit auto-release check completed'))
            .catchError(
              (e) => print('❌ Deposit auto-release check failed: $e'),
            );
      } else {
        // User chưa đăng nhập, chuyển đến trang login
        _initialPage = const LoginPage();
      }
    } catch (e) {
      // Nếu có lỗi, chuyển đến trang login
      _initialPage = const LoginPage();
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return _initialPage;
  }
}
