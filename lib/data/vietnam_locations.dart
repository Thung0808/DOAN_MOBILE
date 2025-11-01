import 'dart:convert';
import 'package:flutter/services.dart';

// Models
class Ward {
  final int code;
  final String name;

  Ward({required this.code, required this.name});

  factory Ward.fromJson(Map<String, dynamic> json) {
    return Ward(code: json['code'] as int, name: json['name'] as String);
  }
}

class District {
  final int code;
  final String name;
  final List<Ward> wards;

  District({required this.code, required this.name, required this.wards});

  factory District.fromJson(Map<String, dynamic> json) {
    return District(
      code: json['code'] as int,
      name: json['name'] as String,
      wards: (json['wards'] as List)
          .map((w) => Ward.fromJson(w as Map<String, dynamic>))
          .toList(),
    );
  }
}

class Province {
  final int code;
  final String name;
  final List<District> districts;

  Province({required this.code, required this.name, required this.districts});

  factory Province.fromJson(Map<String, dynamic> json) {
    return Province(
      code: json['code'] as int,
      name: json['name'] as String,
      districts: (json['districts'] as List)
          .map((d) => District.fromJson(d as Map<String, dynamic>))
          .toList(),
    );
  }
}

// Main class
class VietnamLocations {
  static List<Province>? _provinces;
  static bool _isLoaded = false;

  // Load dữ liệu từ JSON
  static Future<void> loadData() async {
    if (_isLoaded) return;

    try {
      final String jsonString = await rootBundle.loadString(
        'assets/vietnam_locations.json',
      );
      final List<dynamic> jsonData = json.decode(jsonString) as List;

      _provinces = jsonData
          .map((p) => Province.fromJson(p as Map<String, dynamic>))
          .toList();

      _isLoaded = true;
    } catch (e) {
      print('❌ Lỗi load dữ liệu địa chỉ: $e');
      _provinces = [];
    }
  }

  // Lấy tất cả tỉnh/thành phố
  static List<Province> getAllProvinces() {
    return _provinces ?? [];
  }

  // Lấy danh sách tên tỉnh/thành phố
  static List<String> getProvinceNames() {
    return _provinces?.map((p) => p.name).toList() ?? [];
  }

  // Lấy tỉnh/thành phố theo tên
  static Province? getProvinceByName(String name) {
    return _provinces?.firstWhere(
      (p) => p.name == name,
      orElse: () => Province(code: 0, name: '', districts: []),
    );
  }

  // Lấy danh sách quận/huyện theo tỉnh
  static List<String> getDistrictNames(String provinceName) {
    final province = getProvinceByName(provinceName);
    return province?.districts.map((d) => d.name).toList() ?? [];
  }

  // Lấy quận/huyện theo tên
  static District? getDistrictByName(String provinceName, String districtName) {
    final province = getProvinceByName(provinceName);
    return province?.districts.firstWhere(
      (d) => d.name == districtName,
      orElse: () => District(code: 0, name: '', wards: []),
    );
  }

  // Lấy danh sách phường/xã theo quận
  static List<String> getWardNames(String provinceName, String districtName) {
    final district = getDistrictByName(provinceName, districtName);
    return district?.wards.map((w) => w.name).toList() ?? [];
  }

  // Compatibility với code cũ - Chỉ lấy TP.HCM
  static List<String> get hcmDistricts {
    final hcm = getProvinceByName('Thành phố Hồ Chí Minh');
    return hcm?.districts.map((d) => d.name).toList() ?? [];
  }

  // Compatibility với code cũ - Chỉ lấy Hà Nội
  static List<String> get hanoiDistricts {
    final hn = getProvinceByName('Thành phố Hà Nội');
    return hn?.districts.map((d) => d.name).toList() ?? [];
  }

  // Compatibility với code cũ - Lấy phường theo quận (bất kỳ tỉnh nào)
  static List<String> getWards(String districtName) {
    // Tìm trong tất cả các tỉnh
    for (var province in _provinces ?? []) {
      for (var district in province.districts) {
        if (district.name == districtName) {
          return district.wards.map((w) => w.name).toList();
        }
      }
    }
    return ['Phường 01', 'Phường 02', 'Phường 03']; // Fallback
  }

  // Compatibility với code cũ - Lấy tất cả quận/huyện
  static List<String> getAllDistricts() {
    final allDistricts = <String>[];
    for (var province in _provinces ?? []) {
      for (var district in province.districts) {
        allDistricts.add(district.name);
      }
    }
    return allDistricts..sort();
  }
}
