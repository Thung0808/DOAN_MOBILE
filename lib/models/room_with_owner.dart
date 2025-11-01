import 'room_model.dart';
import 'user_profile.dart';

/// Helper class để combine Room + Owner VIP info
/// Dùng để hiển thị phòng với badge VIP từ owner
class RoomWithOwner {
  final Room room;
  final UserProfile? owner;

  RoomWithOwner({required this.room, this.owner});

  // Helper: Lấy VIP level từ owner (nếu có) - CHECK EXPIRE!
  int get ownerVipLevel {
    // 🔥 Chỉ trả về vipLevel nếu VIP còn active
    if (owner?.isVipActive == true) {
      return owner!.vipLevel;
    }
    return 0; // VIP đã hết hạn hoặc không có VIP
  }

  // Helper: Lấy VIP type từ owner - CHECK EXPIRE!
  String get ownerVipType {
    // 🔥 Chỉ trả về vipType nếu VIP còn active
    if (owner?.isVipActive == true) {
      return owner!.vipType;
    }
    return 'free'; // VIP đã hết hạn hoặc không có VIP
  }

  // Helper: Check owner có VIP active không
  bool get isOwnerVip => owner?.isVipActive ?? false;

  // Helper: Lấy VIP icon từ owner - CHECK EXPIRE!
  String get ownerVipIcon {
    if (owner?.isVipActive == true) {
      return owner!.vipIcon;
    }
    return '';
  }

  // Helper: Lấy VIP name từ owner - CHECK EXPIRE!
  String get ownerVipName {
    if (owner?.isVipActive == true) {
      return owner!.vipName;
    }
    return 'Free';
  }

  // Helper: Lấy màu VIP từ owner - CHECK EXPIRE!
  int get ownerVipColor {
    if (owner?.isVipActive == true) {
      return owner!.vipColor;
    }
    return 0xFFFFFFFF;
  }

  // Sort priority: Premium (2) > VIP (1) > Free (0)
  int get sortPriority => ownerVipLevel;
}
