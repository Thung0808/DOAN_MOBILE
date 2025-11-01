# 🏠 Tìm Trọ - Flutter Rental App

Ứng dụng di động tìm kiếm và quản lý phòng trọ được xây dựng bằng Flutter với Firebase backend.

## 📱 Tính năng chính

### 👤 Người dùng
- ✅ **Xác thực người dùng**: Đăng nhập, đăng ký, quên mật khẩu với Firebase Auth và Google Sign-In
- 🔍 **Tìm kiếm phòng trọ**: Tìm kiếm theo địa điểm, giá cả, tiện ích
- 📍 **Bản đồ**: Xem vị trí phòng trọ trên Google Maps
- 💰 **Thanh toán**: Tích hợp Stripe để thanh toán đặt cọc và gói VIP
- ⭐ **Đánh giá**: Hệ thống đánh giá và xếp hạng phòng trọ
- 💬 **Chat**: Chat real-time với chủ phòng trọ
- ❤️ **Yêu thích**: Lưu các phòng trọ yêu thích
- 📅 **Đặt phòng**: Đặt phòng và quản lý booking
- 🔔 **Thông báo**: Nhận thông báo về booking, tin nhắn mới
- 👑 **VIP**: Đăng ký gói VIP để ưu tiên hiển thị phòng trọ

### 🏢 Chủ phòng trọ
- ➕ **Đăng phòng**: Đăng tin phòng trọ với hình ảnh, mô tả chi tiết
- 📊 **Dashboard**: Thống kê và quản lý phòng trọ
- 💳 **Quản lý đặt cọc**: Theo dõi và tự động hoàn trả đặt cọc sau 24h
- 💬 **Chat**: Trả lời tin nhắn từ người thuê
- 📝 **Quản lý booking**: Xem và xử lý yêu cầu đặt phòng

### 👨‍💼 Admin
- 👥 **Quản lý người dùng**: Xem danh sách, filter, quản lý người dùng
- 📝 **Duyệt bài đăng**: Phê duyệt hoặc từ chối bài đăng phòng trọ
- 📊 **Thống kê**: Xem báo cáo và thống kê hệ thống
- 🔔 **Gửi thông báo**: Gửi thông báo toàn hệ thống
- ⚖️ **Quản lý báo cáo**: Xử lý các báo cáo từ người dùng
- 💳 **Quản lý giao dịch**: Theo dõi các giao dịch Stripe
- ⭐ **Cập nhật đánh giá**: Quản lý hệ thống đánh giá

## 🛠️ Công nghệ sử dụng

### Frontend
- **Flutter** - Framework chính
- **Dart** - Ngôn ngữ lập trình

### Backend & Services
- **Firebase Authentication** - Xác thực người dùng
- **Firebase Realtime Database** - Database realtime
- **Firebase Storage** - Lưu trữ hình ảnh
- **Firebase Cloud Messaging** - Push notifications
- **Stripe** - Thanh toán online
- **Google Maps** - Hiển thị bản đồ và vị trí
- **Cloudinary** - CDN cho hình ảnh

### Packages chính
```yaml
firebase_core: ^3.15.2
firebase_auth: ^5.3.0
firebase_database: ^11.3.10
firebase_storage: ^12.3.4
firebase_messaging: ^15.1.3
flutter_stripe: ^11.1.0
google_maps_flutter: ^2.5.0
geolocator: ^10.1.0
google_sign_in: ^6.1.1
```

## 📋 Yêu cầu hệ thống

- Flutter SDK: ^3.9.2
- Dart SDK: Tương thích với Flutter 3.9.2
- Android Studio / VS Code
- Firebase project đã được cấu hình
- Stripe account (cho thanh toán)
- Google Maps API key

## 🚀 Cài đặt

1. **Clone repository**
```bash
git clone https://github.com/Thung0808/DOAN_MOBILE.git
cd DOAN_MOBILE
```

2. **Cài đặt dependencies**
```bash
flutter pub get
```

3. **Cấu hình Firebase**
   - Tải file `google-services.json` từ Firebase Console
   - Đặt vào `android/app/google-services.json`
   - Đặt `GoogleService-Info.plist` vào `ios/Runner/` (nếu build iOS)

4. **Cấu hình Stripe**
   - Thêm Stripe publishable key vào code
   - Cấu hình backend server (trong `stripe_backend/`)

5. **Cấu hình Google Maps**
   - Thêm Google Maps API key vào `android/app/src/main/AndroidManifest.xml`

6. **Chạy ứng dụng**
```bash
flutter run
```

## 📁 Cấu trúc dự án

```
lib/
├── admin/              # Trang quản trị
├── models/             # Data models
├── pages/              # Các trang màn hình
├── services/           # Business logic và services
├── widgets/            # Reusable widgets
├── data/               # Dữ liệu static
├── main.dart           # Entry point
└── ...

android/                # Android native code
ios/                    # iOS native code
assets/                 # Hình ảnh, fonts, JSON data
functions/              # Firebase Cloud Functions
stripe_backend/         # Stripe backend server
```

## 🔐 Bảo mật

⚠️ **Lưu ý quan trọng**: 
- Không commit file `google-services.json` hoặc các API keys
- Cấu hình Firebase Security Rules đúng cách
- Sử dụng environment variables cho các thông tin nhạy cảm

## 📱 Tính năng nổi bật

- ✅ **Trust Score System**: Hệ thống điểm tin cậy dựa trên đánh giá và giao dịch
- ✅ **VIP Subscription**: Gói VIP để tăng độ ưu tiên hiển thị
- ✅ **Auto Deposit Release**: Tự động hoàn trả đặt cọc sau 24h
- ✅ **Real-time Chat**: Chat real-time với Firebase Realtime Database
- ✅ **Push Notifications**: Thông báo đẩy với Firebase Cloud Messaging
- ✅ **Location-based Search**: Tìm kiếm theo vị trí địa lý
- ✅ **Rating System**: Hệ thống đánh giá và phản hồi chi tiết

## 🤝 Đóng góp

Mọi đóng góp đều được chào đón! Vui lòng:
1. Fork repository
2. Tạo feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to branch (`git push origin feature/AmazingFeature`)
5. Mở Pull Request

## 📄 License

Dự án này được phát triển cho mục đích học tập và nghiên cứu.

## 👨‍💻 Tác giả

Thung0808

## 📞 Liên hệ

Nếu có câu hỏi hoặc đề xuất, vui lòng mở một issue trên GitHub.

---

⭐ Nếu project này hữu ích, hãy cho một star!

