class Room {
  final String id;
  final String title;
  final String description;
  final double price;
  final double area;
  final String address;
  final String province; // Tỉnh/Thành phố
  final String district;
  final String ward;
  final String ownerId;
  final String ownerName;
  final String ownerPhone;
  final List<String> images;
  final List<String> amenities;
  final String status; // 'pending', 'approved', 'rejected'
  final String
  availabilityStatus; // 'DangMo', 'DaDatLich', 'DaDatCoc', 'DaThue'
  final int timestamp;
  final double? latitude;
  final double? longitude;
  final int viewCount; // Số lượt xem
  final double averageRating; // Điểm đánh giá trung bình
  final int reviewCount; // Số lượng đánh giá
  final bool isVip; // Phòng có VIP không (DEPRECATED - dùng owner vipLevel)
  final String? vipType; // Loại VIP (DEPRECATED - dùng owner vipType)

  Room({
    required this.id,
    required this.title,
    required this.description,
    required this.price,
    required this.area,
    required this.address,
    this.province = '', // Tùy chọn, tương thích với dữ liệu cũ
    required this.district,
    required this.ward,
    required this.ownerId,
    required this.ownerName,
    required this.ownerPhone,
    required this.images,
    required this.amenities,
    this.status = 'pending',
    this.availabilityStatus = 'DangMo', // Mặc định là đang mở
    required this.timestamp,
    this.latitude,
    this.longitude,
    this.viewCount = 1,
    this.averageRating = 0.0,
    this.reviewCount = 0,
    this.isVip = false,
    this.vipType,
  });

  factory Room.fromMap(String id, Map<dynamic, dynamic> map) {
    final room = Room(
      id: id,
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      price: (map['price'] ?? 0).toDouble(),
      area: (map['area'] ?? 0).toDouble(),
      address: map['address'] ?? '',
      province: map['province'] ?? '', // Tương thích với dữ liệu cũ
      district: map['district'] ?? '',
      ward: map['ward'] ?? '',
      ownerId: map['ownerId'] ?? '',
      ownerName: map['ownerName'] ?? '',
      ownerPhone: map['ownerPhone'] ?? '',
      images: List<String>.from(map['images'] ?? []),
      amenities: List<String>.from(map['amenities'] ?? []),
      status: map['status'] ?? 'pending',
      availabilityStatus: map['availabilityStatus'] ?? 'DangMo',
      timestamp: map['timestamp'] ?? 0,
      latitude: map['latitude']?.toDouble(),
      longitude: map['longitude']?.toDouble(),
      viewCount: map['viewCount'] ?? 1,
      averageRating: (map['averageRating'] ?? 0.0).toDouble(),
      reviewCount: map['reviewCount'] ?? map['totalReviews'] ?? 0,
      isVip: map['isVip'] ?? false,
      vipType: map['vipType'],
    );

    return room;
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'price': price,
      'area': area,
      'address': address,
      'province': province,
      'district': district,
      'ward': ward,
      'ownerId': ownerId,
      'ownerName': ownerName,
      'ownerPhone': ownerPhone,
      'images': images,
      'amenities': amenities,
      'status': status,
      'availabilityStatus': availabilityStatus,
      'timestamp': timestamp,
      'latitude': latitude,
      'longitude': longitude,
      'viewCount': viewCount,
      'averageRating': averageRating,
      'reviewCount': reviewCount,
    };
  }
}
