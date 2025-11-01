class RoomBooking {
  final String id;
  final String roomId;
  final String roomTitle;
  final String roomAddress;
  final String tenantId; // Người đặt lịch
  final String tenantName;
  final String tenantPhone;
  final String tenantEmail;
  final String ownerId; // Chủ trọ
  final String ownerName;
  final String ownerPhone;
  final String ownerEmail;
  final DateTime bookingDateTime; // Ngày giờ muốn xem
  final String
  status; // 'pending', 'confirmed', 'rejected', 'completed', 'cancelled'
  final String bookingType; // 'viewing' (đặt lịch xem), 'deposit' (đặt cọc)
  final String? notes; // Ghi chú từ người đặt
  final String? ownerNotes; // Ghi chú từ chủ trọ
  final int createdAt; // Timestamp tạo lịch hẹn
  final int? confirmedAt; // Timestamp xác nhận
  final int? rejectedAt; // Timestamp từ chối
  final String? rejectionReason; // Lý do từ chối

  RoomBooking({
    required this.id,
    required this.roomId,
    required this.roomTitle,
    required this.roomAddress,
    required this.tenantId,
    required this.tenantName,
    required this.tenantPhone,
    required this.tenantEmail,
    required this.ownerId,
    required this.ownerName,
    required this.ownerPhone,
    required this.ownerEmail,
    required this.bookingDateTime,
    this.status = 'pending',
    this.bookingType = 'viewing', // Mặc định là đặt lịch xem
    this.notes,
    this.ownerNotes,
    required this.createdAt,
    this.confirmedAt,
    this.rejectedAt,
    this.rejectionReason,
  });

  factory RoomBooking.fromMap(String id, Map<dynamic, dynamic> map) {
    return RoomBooking(
      id: id,
      roomId: map['roomId'] ?? '',
      roomTitle: map['roomTitle'] ?? '',
      roomAddress: map['roomAddress'] ?? '',
      tenantId: map['tenantId'] ?? '',
      tenantName: map['tenantName'] ?? '',
      tenantPhone: map['tenantPhone'] ?? '',
      tenantEmail: map['tenantEmail'] ?? '',
      ownerId: map['ownerId'] ?? '',
      ownerName: map['ownerName'] ?? '',
      ownerPhone: map['ownerPhone'] ?? '',
      ownerEmail: map['ownerEmail'] ?? '',
      bookingDateTime: DateTime.fromMillisecondsSinceEpoch(
        map['bookingDateTime'] ?? 0,
      ),
      status: map['status'] ?? 'pending',
      bookingType: map['bookingType'] ?? 'viewing',
      notes: map['notes'],
      ownerNotes: map['ownerNotes'],
      createdAt: map['createdAt'] ?? 0,
      confirmedAt: map['confirmedAt'],
      rejectedAt: map['rejectedAt'],
      rejectionReason: map['rejectionReason'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'roomId': roomId,
      'roomTitle': roomTitle,
      'roomAddress': roomAddress,
      'tenantId': tenantId,
      'tenantName': tenantName,
      'tenantPhone': tenantPhone,
      'tenantEmail': tenantEmail,
      'ownerId': ownerId,
      'ownerName': ownerName,
      'ownerPhone': ownerPhone,
      'ownerEmail': ownerEmail,
      'bookingDateTime': bookingDateTime.millisecondsSinceEpoch,
      'status': status,
      'bookingType': bookingType,
      'notes': notes,
      'ownerNotes': ownerNotes,
      'createdAt': createdAt,
      'confirmedAt': confirmedAt,
      'rejectedAt': rejectedAt,
      'rejectionReason': rejectionReason,
    };
  }

  RoomBooking copyWith({
    String? id,
    String? roomId,
    String? roomTitle,
    String? roomAddress,
    String? tenantId,
    String? tenantName,
    String? tenantPhone,
    String? tenantEmail,
    String? ownerId,
    String? ownerName,
    String? ownerPhone,
    String? ownerEmail,
    DateTime? bookingDateTime,
    String? status,
    String? bookingType,
    String? notes,
    String? ownerNotes,
    int? createdAt,
    int? confirmedAt,
    int? rejectedAt,
    String? rejectionReason,
  }) {
    return RoomBooking(
      id: id ?? this.id,
      roomId: roomId ?? this.roomId,
      roomTitle: roomTitle ?? this.roomTitle,
      roomAddress: roomAddress ?? this.roomAddress,
      tenantId: tenantId ?? this.tenantId,
      tenantName: tenantName ?? this.tenantName,
      tenantPhone: tenantPhone ?? this.tenantPhone,
      tenantEmail: tenantEmail ?? this.tenantEmail,
      ownerId: ownerId ?? this.ownerId,
      ownerName: ownerName ?? this.ownerName,
      ownerPhone: ownerPhone ?? this.ownerPhone,
      ownerEmail: ownerEmail ?? this.ownerEmail,
      bookingDateTime: bookingDateTime ?? this.bookingDateTime,
      status: status ?? this.status,
      bookingType: bookingType ?? this.bookingType,
      notes: notes ?? this.notes,
      ownerNotes: ownerNotes ?? this.ownerNotes,
      createdAt: createdAt ?? this.createdAt,
      confirmedAt: confirmedAt ?? this.confirmedAt,
      rejectedAt: rejectedAt ?? this.rejectedAt,
      rejectionReason: rejectionReason ?? this.rejectionReason,
    );
  }

  // Helper methods
  bool get isPending => status == 'pending';
  bool get isConfirmed => status == 'confirmed';
  bool get isRejected => status == 'rejected';
  bool get isCompleted => status == 'completed';
  bool get isCancelled => status == 'cancelled';

  String get statusText {
    switch (status) {
      case 'pending':
        return 'Chờ xác nhận';
      case 'confirmed':
        return 'Đã xác nhận';
      case 'rejected':
        return 'Đã từ chối';
      case 'completed':
        return 'Hoàn thành';
      case 'cancelled':
        return 'Đã hủy';
      default:
        return 'Không xác định';
    }
  }
}
