import 'dart:io';
import 'package:cloudinary_public/cloudinary_public.dart';

class CloudinaryService {
  // Cloudinary configuration
  static const String _cloudName = 'phungtronghung';
  static const String _uploadPreset = 'flutter_unsigned_preset';

  // Singleton instance
  static final CloudinaryPublic _cloudinary = CloudinaryPublic(
    _cloudName,
    _uploadPreset,
    cache: false,
  );

  /// Upload một ảnh lên Cloudinary
  /// Trả về URL của ảnh đã upload
  static Future<String> uploadImage(File imageFile) async {
    try {

      final response = await _cloudinary.uploadFile(
        CloudinaryFile.fromFile(
          imageFile.path,
          resourceType: CloudinaryResourceType.Image,
          folder: 'room_images', // Tạo folder riêng cho ảnh phòng
        ),
      );

      final imageUrl = response.secureUrl;

      return imageUrl;
    } catch (e) {
      print('❌ Error uploading to Cloudinary: $e');
      rethrow;
    }
  }

  /// Upload nhiều ảnh cùng lúc
  /// Trả về List URL của các ảnh đã upload
  static Future<List<String>> uploadImages(List<File> imageFiles) async {
    final List<String> uploadedUrls = [];

    for (int i = 0; i < imageFiles.length; i++) {
      try {
        final url = await uploadImage(imageFiles[i]);
        uploadedUrls.add(url);
      } catch (e) {
        print('❌ Failed to upload image ${i + 1}: $e');
        // Tiếp tục upload các ảnh còn lại
        continue;
      }
    }

    return uploadedUrls;
  }

  /// Xóa ảnh từ Cloudinary (cần publicId)
  /// Note: Unsigned preset không hỗ trợ xóa, cần signed request
  static Future<void> deleteImage(String publicId) async {
    try {
      // Unsigned preset không thể xóa ảnh
      // Cần implement signed request hoặc xóa qua Cloudinary dashboard
    } catch (e) {
      print('❌ Error deleting from Cloudinary: $e');
    }
  }

  /// Lấy URL với transformations (resize, crop, etc.)
  static String getTransformedUrl(
    String originalUrl, {
    int? width,
    int? height,
    String? crop,
    int? quality,
  }) {
    // Parse original URL to get public ID
    final uri = Uri.parse(originalUrl);
    final pathSegments = uri.pathSegments;

    // Build transformation string
    final transformations = <String>[];
    if (width != null) transformations.add('w_$width');
    if (height != null) transformations.add('h_$height');
    if (crop != null) transformations.add('c_$crop');
    if (quality != null) transformations.add('q_$quality');

    if (transformations.isEmpty) return originalUrl;

    // Insert transformations into URL
    final transformString = transformations.join(',');
    final newPath = pathSegments
        .map((segment) {
          if (segment == 'upload') {
            return 'upload/$transformString';
          }
          return segment;
        })
        .join('/');

    return '${uri.scheme}://${uri.host}/$newPath';
  }

  /// Lấy thumbnail URL (nhỏ, chất lượng tối ưu)
  static String getThumbnailUrl(String originalUrl) {
    return getTransformedUrl(
      originalUrl,
      width: 300,
      height: 300,
      crop: 'fill',
      quality: 80,
    );
  }

  /// Lấy optimized URL (tối ưu cho hiển thị)
  static String getOptimizedUrl(String originalUrl) {
    return getTransformedUrl(
      originalUrl,
      width: 800,
      quality: 85,
      crop: 'limit',
    );
  }
}
