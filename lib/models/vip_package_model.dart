class VipPackage {
  final String id;
  final String name;
  final String description;
  final int price; // Giá (VND)
  final int durationDays; // Số ngày hiệu lực
  final String type; // 'boost', 'badge', 'premium'
  final Map<String, dynamic> features; // Các tính năng đi kèm
  final int priority; // Mức độ ưu tiên (số càng cao càng ưu tiên)
  final String icon; // Icon emoji

  VipPackage({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.durationDays,
    required this.type,
    required this.features,
    required this.priority,
    required this.icon,
  });

  factory VipPackage.fromMap(String id, Map<dynamic, dynamic> map) {
    return VipPackage(
      id: id,
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      price: map['price'] ?? 0,
      durationDays: map['durationDays'] ?? 0,
      type: map['type'] ?? '',
      features: Map<String, dynamic>.from(map['features'] ?? {}),
      priority: map['priority'] ?? 0,
      icon: map['icon'] ?? '⭐',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'description': description,
      'price': price,
      'durationDays': durationDays,
      'type': type,
      'features': features,
      'priority': priority,
      'icon': icon,
    };
  }

  // Các gói VIP mặc định (CHO USER - áp dụng tất cả phòng)
  static List<VipPackage> getDefaultPackages() {
    return [
      // 👑 Gói VIP - Cho tất cả phòng của user
      VipPackage(
        id: 'vip_7days',
        name: 'VIP 7 Ngày',
        description: 'Tất cả phòng của bạn có huy hiệu VIP trong 7 ngày',
        price: 99000,
        durationDays: 7,
        type: 'vip',
        priority: 1,
        icon: '👑',
        features: {
          'vipBadge': true,
          'highlight': true,
          'showViews': true,
          'priorityDisplay': true,
        },
      ),
      VipPackage(
        id: 'vip_30days',
        name: 'VIP 30 Ngày',
        description: 'Tất cả phòng của bạn có huy hiệu VIP trong 30 ngày',
        price: 299000,
        durationDays: 30,
        type: 'vip',
        priority: 1,
        icon: '👑',
        features: {
          'vipBadge': true,
          'highlight': true,
          'showViews': true,
          'priorityDisplay': true,
          'prioritySupport': true,
        },
      ),

      // 💎 Gói Premium - Cho tất cả phòng của user
      VipPackage(
        id: 'premium_7days',
        name: 'Premium 7 Ngày',
        description: 'Tất cả phòng của bạn có ưu tiên cao nhất trong 7 ngày',
        price: 199000,
        durationDays: 7,
        type: 'premium',
        priority: 2,
        icon: '💎',
        features: {
          'topPosition': true,
          'vipBadge': true,
          'highlight': true,
          'showViews': true,
          'priorityDisplay': true,
          'prioritySupport': true,
          'analytics': true,
        },
      ),
      VipPackage(
        id: 'premium_30days',
        name: 'Premium 30 Ngày',
        description:
            'Tất cả phòng của bạn có ưu tiên cao nhất + Analytics trong 30 ngày',
        price: 499000,
        durationDays: 30,
        type: 'premium',
        priority: 2,
        icon: '💎',
        features: {
          'topPosition': true,
          'vipBadge': true,
          'highlight': true,
          'showViews': true,
          'priorityDisplay': true,
          'prioritySupport': true,
          'autoBoost': true,
          'analytics': true,
        },
      ),
    ];
  }

  // Tính giá trị tiết kiệm
  int getSavingsPercent() {
    if (durationDays == 1) return 0;
    if (durationDays == 3) return 20; // Tiết kiệm 20%
    if (durationDays == 7) return 30; // Tiết kiệm 30%
    if (durationDays == 30 && type == 'premium') return 40; // Tiết kiệm 40%
    return 0;
  }
}
