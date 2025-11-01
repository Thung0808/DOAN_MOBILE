class VipSubscription {
  final String id;
  final String userId; // User mua VIP (áp dụng cho TẤT CẢ phòng của user)
  final String packageId; // ID gói VIP
  final String packageName;
  final String packageType; // 'vip', 'premium' (không còn 'boost')
  final int packagePriority; // 0=Free, 1=VIP, 2=Premium
  final int price;
  final DateTime startDate;
  final DateTime endDate;
  final String status; // 'active', 'expired', 'cancelled'
  final String paymentId; // ID giao dịch thanh toán
  final String paymentMethod; // 'stripe', 'vnpay', 'momo', 'zalopay'
  final int createdAt;
  final Map<String, dynamic> features;

  VipSubscription({
    required this.id,
    required this.userId,
    required this.packageId,
    required this.packageName,
    required this.packageType,
    required this.packagePriority,
    required this.price,
    required this.startDate,
    required this.endDate,
    this.status = 'active',
    required this.paymentId,
    required this.paymentMethod,
    required this.createdAt,
    required this.features,
  });

  factory VipSubscription.fromMap(String id, Map<dynamic, dynamic> map) {
    return VipSubscription(
      id: id,
      userId: map['userId'] ?? '',
      packageId: map['packageId'] ?? '',
      packageName: map['packageName'] ?? '',
      packageType: map['packageType'] ?? '',
      packagePriority: map['packagePriority'] ?? 0,
      price: map['price'] ?? 0,
      startDate: DateTime.fromMillisecondsSinceEpoch(map['startDate'] ?? 0),
      endDate: DateTime.fromMillisecondsSinceEpoch(map['endDate'] ?? 0),
      status: map['status'] ?? 'active',
      paymentId: map['paymentId'] ?? '',
      paymentMethod: map['paymentMethod'] ?? '',
      createdAt: map['createdAt'] ?? 0,
      features: Map<String, dynamic>.from(map['features'] ?? {}),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'packageId': packageId,
      'packageName': packageName,
      'packageType': packageType,
      'packagePriority': packagePriority,
      'price': price,
      'startDate': startDate.millisecondsSinceEpoch,
      'endDate': endDate.millisecondsSinceEpoch,
      'status': status,
      'paymentId': paymentId,
      'paymentMethod': paymentMethod,
      'createdAt': createdAt,
      'features': features,
    };
  }

  // Kiểm tra còn hiệu lực
  bool get isActive {
    return status == 'active' && DateTime.now().isBefore(endDate);
  }

  // Số ngày còn lại
  int get daysRemaining {
    if (!isActive) return 0;
    return endDate.difference(DateTime.now()).inDays;
  }

  // Phần trăm thời gian đã sử dụng
  double get usagePercent {
    final totalDays = endDate.difference(startDate).inDays;
    final usedDays = DateTime.now().difference(startDate).inDays;
    if (totalDays <= 0) return 100;
    return (usedDays / totalDays * 100).clamp(0, 100);
  }
}
