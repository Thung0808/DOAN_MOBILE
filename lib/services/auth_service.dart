import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

class AuthService {
  static const String _isLoggedInKey = 'is_logged_in';
  static const String _userEmailKey = 'user_email';
  static const String _userRoleKey = 'user_role';

  // Lưu trạng thái đăng nhập
  static Future<void> saveLoginState(String email, String role) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_isLoggedInKey, true);
    await prefs.setString(_userEmailKey, email);
    await prefs.setString(_userRoleKey, role);
  }

  // Kiểm tra trạng thái đăng nhập
  static Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_isLoggedInKey) ?? false;
  }

  // Lấy email đã lưu
  static Future<String?> getSavedEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_userEmailKey);
  }

  // Lấy role đã lưu
  static Future<String?> getSavedRole() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_userRoleKey);
  }

  // Xóa trạng thái đăng nhập (đăng xuất)
  static Future<void> clearLoginState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_isLoggedInKey);
    await prefs.remove(_userEmailKey);
    await prefs.remove(_userRoleKey);
  }

  // Kiểm tra và tự động đăng nhập
  static Future<Map<String, dynamic>?> checkAutoLogin() async {
    try {
      // Kiểm tra Firebase Auth state trước
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        await clearLoginState();
        return null;
      }

      // Lấy thông tin user từ database
      final dbRef = FirebaseDatabase.instance.ref();
      final snapshot = await dbRef.child('users').child(user.uid).get();

      if (snapshot.exists) {
        final data = snapshot.value as Map;
        final role = data['role'] ?? 'user';
        final email = data['email'] ?? user.email ?? '';

        // Lưu lại trạng thái đăng nhập nếu chưa có
        await saveLoginState(email, role);

        return {'user': user, 'role': role, 'email': email};
      }

      return null;
    } catch (e) {
      // Nếu có lỗi, xóa trạng thái đăng nhập
      await clearLoginState();
      return null;
    }
  }
}
