import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class GeocodingService {
  // Sử dụng Nominatim API (OpenStreetMap Geocoding)
  static const String _baseUrl = 'https://nominatim.openstreetmap.org';

  /// Geocode địa chỉ thành tọa độ
  /// Trả về LatLng hoặc null nếu không tìm thấy
  static Future<LatLng?> geocodeAddress({
    String? province,
    String? district,
    String? ward,
    String? address,
  }) async {
    try {
      // Tạo query address từ các thành phần
      final addressParts = <String>[];
      if (address != null && address.isNotEmpty) addressParts.add(address);
      if (ward != null && ward.isNotEmpty) addressParts.add(ward);
      if (district != null && district.isNotEmpty) addressParts.add(district);
      if (province != null && province.isNotEmpty) addressParts.add(province);
      addressParts.add('Vietnam'); // Luôn thêm Vietnam

      if (addressParts.isEmpty) return null;

      final query = addressParts.join(', ');

      // Gọi Nominatim API
      final url = Uri.parse('$_baseUrl/search').replace(
        queryParameters: {
          'q': query,
          'format': 'json',
          'limit': '1',
          'addressdetails': '1',
        },
      );

      final response = await http.get(
        url,
        headers: {
          'User-Agent': 'DemoFlutterApp/1.0', // Required by Nominatim
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> results = json.decode(response.body);

        if (results.isNotEmpty) {
          final result = results[0];
          final lat = double.parse(result['lat'].toString());
          final lon = double.parse(result['lon'].toString());

          return LatLng(lat, lon);
        } else {
        }
      } else {
        print('❌ Lỗi geocoding: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Lỗi geocoding: $e');
    }

    return null;
  }

  /// Geocode chỉ với Tỉnh/Thành phố
  static Future<LatLng?> geocodeProvince(String province) async {
    return geocodeAddress(province: province);
  }

  /// Geocode với Tỉnh + Quận
  static Future<LatLng?> geocodeDistrict({
    required String province,
    required String district,
  }) async {
    return geocodeAddress(province: province, district: district);
  }

  /// Geocode đầy đủ
  static Future<LatLng?> geocodeFullAddress({
    required String province,
    required String district,
    required String ward,
    String? address,
  }) async {
    return geocodeAddress(
      province: province,
      district: district,
      ward: ward,
      address: address,
    );
  }

  /// Lấy tọa độ mặc định cho các thành phố lớn
  static LatLng? getDefaultLocationForProvince(String province) {
    final Map<String, LatLng> defaultLocations = {
      'Thành phố Hồ Chí Minh': const LatLng(10.762622, 106.660172),
      'Thành phố Hà Nội': const LatLng(21.028511, 105.804817),
      'Thành phố Đà Nẵng': const LatLng(16.047079, 108.206230),
      'Thành phố Hải Phòng': const LatLng(20.844910, 106.687797),
      'Thành phố Cần Thơ': const LatLng(10.045162, 105.746857),
    };

    return defaultLocations[province];
  }
}
