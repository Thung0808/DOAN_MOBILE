class UserProfile {
  final String uid;
  final String name;
  final String email;
  final String phone;
  final String? avatarUrl;
  final List<String> favorites;

  // ⭐ VIP fields (theo USER, không theo phòng)
  final int vipLevel; // 0=Free, 1=VIP, 2=Premium
  final String vipType; // 'free', 'vip', 'premium'
  final int? vipEndDate; // Timestamp hết hạn VIP
  final bool isVip; // Shortcut: vipLevel > 0

  UserProfile({
    required this.uid,
    required this.name,
    required this.email,
    this.phone = '',
    this.avatarUrl,
    this.favorites = const [],
    this.vipLevel = 0,
    this.vipType = 'free',
    this.vipEndDate,
  }) : isVip = vipLevel > 0;

  factory UserProfile.fromMap(String uid, Map<dynamic, dynamic> map) {
    return UserProfile(
      uid: uid,
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      phone: map['phone'] ?? '',
      avatarUrl: map['avatarUrl'],
      favorites: List<String>.from(map['favorites'] ?? []),
      vipLevel: map['vipLevel'] ?? 0,
      vipType: map['vipType'] ?? 'free',
      vipEndDate: map['vipEndDate'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'email': email,
      'phone': phone,
      'avatarUrl': avatarUrl,
      'favorites': favorites,
      'vipLevel': vipLevel,
      'vipType': vipType,
      'vipEndDate': vipEndDate,
    };
  }

  // Helper: Kiểm tra VIP còn hiệu lực
  bool get isVipActive {
    if (!isVip || vipEndDate == null) return false;
    return DateTime.now().millisecondsSinceEpoch < vipEndDate!;
  }

  // Helper: Số ngày VIP còn lại
  int get vipDaysRemaining {
    if (!isVipActive || vipEndDate == null) return 0;
    final remaining = DateTime.fromMillisecondsSinceEpoch(
      vipEndDate!,
    ).difference(DateTime.now()).inDays;
    return remaining > 0 ? remaining : 0;
  }

  // Helper: VIP sắp hết hạn (còn <= 3 ngày)
  bool get isVipExpiringSoon {
    return isVipActive && vipDaysRemaining <= 3;
  }

  // Helper: Lấy màu VIP
  int get vipColor {
    switch (vipType) {
      case 'premium':
        return 0xFF00FFFF; // Aqua
      case 'vip':
        return 0xFFFFD700; // Gold
      default:
        return 0xFFFFFFFF; // White
    }
  }

  // Helper: Lấy icon VIP
  String get vipIcon {
    switch (vipType) {
      case 'premium':
        return '💎';
      case 'vip':
        return '👑';
      default:
        return '';
    }
  }

  // Helper: Lấy tên gói VIP
  String get vipName {
    switch (vipType) {
      case 'premium':
        return 'Premium';
      case 'vip':
        return 'VIP';
      default:
        return 'Free';
    }
  }
}
