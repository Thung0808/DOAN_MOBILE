import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:latlong2/latlong.dart';
import 'package:permission_handler/permission_handler.dart';
import 'data/vietnam_locations.dart';
import 'pick_location_page.dart';
import 'services/geocoding_service.dart';
import 'services/cloudinary_service.dart';

class AddRoomPage extends StatefulWidget {
  final VoidCallback? onRoomAdded;

  const AddRoomPage({super.key, this.onRoomAdded});

  @override
  State<AddRoomPage> createState() => _AddRoomPageState();
}

class _AddRoomPageState extends State<AddRoomPage> {
  final _formKey = GlobalKey<FormState>();
  final user = FirebaseAuth.instance.currentUser!;
  final dbRef = FirebaseDatabase.instance.ref();
  final ImagePicker _picker = ImagePicker();

  final titleController = TextEditingController();
  final descriptionController = TextEditingController();
  final priceController = TextEditingController();
  final areaController = TextEditingController();
  final addressController = TextEditingController();
  final ownerNameController = TextEditingController();
  final ownerPhoneController = TextEditingController();

  String? _selectedProvince;
  String? _selectedDistrict;
  String? _selectedWard;
  List<String> _availableDistricts = [];
  List<String> _availableWards = [];
  final List<String> _selectedAmenities = [];
  final List<File> _selectedImages = [];
  final List<String> _uploadedImageUrls = [];
  bool _isLoading = false;
  bool _isLoadingLocations = true;
  LatLng? _selectedLocation;

  final amenitiesList = [
    'Wi-Fi',
    'Điều hoà',
    'Tủ lạnh',
    'Máy giặt',
    'Nóng lạnh',
    'Thang máy',
    'Chỗ để xe',
    'Bảo vệ',
    'Giường',
    'Tủ quần áo',
    'Bàn học',
    'Bếp',
  ];

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
    _loadLocationData();
  }

  Future<void> _loadLocationData() async {
    await VietnamLocations.loadData();
    if (mounted) {
      setState(() {
        _isLoadingLocations = false;
      });
    }
  }

  @override
  void dispose() {
    // Dispose controllers để tránh memory leak
    titleController.dispose();
    descriptionController.dispose();
    priceController.dispose();
    areaController.dispose();
    addressController.dispose();
    ownerNameController.dispose();
    ownerPhoneController.dispose();
    super.dispose();
  }

  Future<void> _loadUserInfo() async {
    try {
      final snapshot = await dbRef.child('users').child(user.uid).get();
      if (snapshot.exists && mounted) {
        final data = snapshot.value as Map;
        setState(() {
          ownerNameController.text = data['name'] ?? '';
          ownerPhoneController.text = data['phone'] ?? '';
        });
      }
    } catch (e) {
      // Không crash app, chỉ log lỗi
    }
  }

  /// Tự động geocode địa chỉ khi chọn từ dropdown
  Future<void> _geocodeCurrentAddress() async {
    if (_selectedProvince == null) return;

    try {
      LatLng? location;

      // Ưu tiên geocode đầy đủ nếu có đủ thông tin
      if (_selectedWard != null && _selectedDistrict != null) {
        location = await GeocodingService.geocodeFullAddress(
          province: _selectedProvince!,
          district: _selectedDistrict!,
          ward: _selectedWard!,
          address: addressController.text.trim().isNotEmpty
              ? addressController.text.trim()
              : null,
        );
      } else if (_selectedDistrict != null) {
        location = await GeocodingService.geocodeDistrict(
          province: _selectedProvince!,
          district: _selectedDistrict!,
        );
      } else {
        // Chỉ có tỉnh - dùng location mặc định trước
        location = GeocodingService.getDefaultLocationForProvince(
          _selectedProvince!,
        );
        // Nếu không có default, thử geocode
        location ??= await GeocodingService.geocodeProvince(_selectedProvince!);
      }

      if (location != null && mounted) {
        setState(() {
          _selectedLocation = location;
        });
        print(
          '✅ Đã cập nhật vị trí: ${location.latitude}, ${location.longitude}',
        );
      }
    } catch (e) {
      print('❌ Lỗi geocode: $e');
    }
  }

  // Chọn ảnh từ gallery - ĐƠN GIẢN
  // Request quyền truy cập photos
  Future<bool> _requestPhotoPermission() async {
    if (Platform.isIOS) {
      // iOS: Luôn cần permission
      final status = await Permission.photos.request();
      if (status.isGranted || status.isLimited) {
        return true;
      }
      if (status.isPermanentlyDenied && mounted) {
        final shouldOpenSettings = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Cần quyền truy cập ảnh'),
            content: const Text(
              'App cần quyền truy cập ảnh để bạn có thể chọn ảnh phòng trọ. '
              'Vui lòng cấp quyền trong cài đặt.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Hủy'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Mở cài đặt'),
              ),
            ],
          ),
        );
        if (shouldOpenSettings == true) {
          await openAppSettings();
        }
      }
      return status.isGranted || status.isLimited;
    }

    // ANDROID: Đơn giản hóa
    // Android 13+ (API 33+): Photo Picker tự động xử lý, KHÔNG CẦN permission
    // Android < 13: Vẫn cần storage permission

    try {
      // Thử request storage permission (cho Android < 13)
      var storageStatus = await Permission.storage.status;

      if (!storageStatus.isGranted && !storageStatus.isPermanentlyDenied) {
        storageStatus = await Permission.storage.request();
      }

      // Nếu bị denied vĩnh viễn, hỏi mở Settings
      if (storageStatus.isPermanentlyDenied && mounted) {
        final shouldOpenSettings = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Cần quyền truy cập ảnh'),
            content: const Text(
              'App cần quyền truy cập ảnh để bạn có thể chọn ảnh phòng trọ. '
              'Vui lòng cấp quyền trong cài đặt.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Hủy'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Mở cài đặt'),
              ),
            ],
          ),
        );
        if (shouldOpenSettings == true) {
          await openAppSettings();
        }
        return false;
      }

      // Android 13+: Dù không có permission, vẫn cho phép (Photo Picker tự xử lý)
      return true;
    } catch (e) {
      print('❌ Lỗi request permission: $e');
      // Android 13+: Nếu lỗi permission, vẫn cho thử (Photo Picker không cần)
      return true;
    }
  }

  // Request quyền camera
  Future<bool> _requestCameraPermission() async {
    final status = await Permission.camera.request();
    if (status.isGranted) {
      return true;
    }
    if (status.isPermanentlyDenied && mounted) {
      final shouldOpenSettings = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Cần quyền camera'),
          content: const Text(
            'App cần quyền camera để bạn có thể chụp ảnh phòng trọ. '
            'Vui lòng cấp quyền trong cài đặt.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Hủy'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Mở cài đặt'),
            ),
          ],
        ),
      );
      if (shouldOpenSettings == true) {
        await openAppSettings();
      }
    }
    return status.isGranted;
  }

  Future<void> _pickImages() async {
    // Check permission trước
    final hasPermission = await _requestPhotoPermission();
    if (!hasPermission) {
      print('❌ Không có quyền truy cập ảnh');
      if (mounted) {
        _showMessage('⚠️ Cần quyền truy cập ảnh để chọn ảnh');
      }
      return;
    }

    try {
      // Android 13+: Dùng pickMultiImage với Photo Picker
      // iOS: Dùng pickMultiImage bình thường
      final List<XFile> pickedFiles = await _picker.pickMultiImage(
        imageQuality: 80,
        maxWidth: 1920,
        maxHeight: 1920,
        // Không giới hạn số lượng ảnh
      );

      if (!mounted) return;

      if (pickedFiles.isNotEmpty) {
        final newImages = pickedFiles.map((xFile) => File(xFile.path)).toList();

        // Kiểm tra tổng số ảnh không vượt quá 10
        if (_selectedImages.length + newImages.length > 10) {
          _showMessage(
            'Chỉ được chọn tối đa 10 ảnh. Hiện tại đã có ${_selectedImages.length} ảnh',
          );
          return;
        }

        setState(() {
          _selectedImages.addAll(newImages);
        });

        _showMessage('✅ Đã chọn ${newImages.length} ảnh');
      } else {
        if (mounted) {
          _showMessage('Không có ảnh nào được chọn. Vui lòng thử lại.');
        }
      }
    } catch (e) {
      print('❌ Lỗi chọn ảnh: $e');
      if (mounted) {
        // Hiển thị lỗi chi tiết hơn
        String errorMsg = 'Lỗi chọn ảnh';
        if (e.toString().contains('photo access')) {
          errorMsg =
              'Không có quyền truy cập ảnh. Vui lòng cấp quyền trong Settings.';
        } else if (e.toString().contains('cancelled')) {
          errorMsg = 'Đã hủy chọn ảnh';
        } else {
          errorMsg = 'Lỗi: ${e.toString()}';
        }
        _showMessage(errorMsg);
      }
    }
  }

  // Chọn ảnh từ File Manager (Google Photos, Drive, Cloud...)
  Future<void> _pickImagesFromFiles() async {
    try {
      // Dùng file_picker - hỗ trợ Google Photos, Drive, Cloud storage
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: true,
        allowCompression: true,
      );

      if (!mounted) return;

      if (result != null && result.files.isNotEmpty) {
        final newImages = <File>[];
        for (var file in result.files) {
          if (file.path != null) {
            newImages.add(File(file.path!));
          } else {}
        }

        if (newImages.isNotEmpty) {
          // Kiểm tra tổng số ảnh không vượt quá 10
          if (_selectedImages.length + newImages.length > 10) {
            _showMessage(
              'Chỉ được chọn tối đa 10 ảnh. Hiện tại đã có ${_selectedImages.length} ảnh',
            );
            return;
          }

          setState(() {
            _selectedImages.addAll(newImages);
          });

          _showMessage('✅ Đã chọn ${newImages.length} ảnh từ File Manager');
        } else {
          _showMessage('⚠️ Không thể đọc file ảnh');
        }
      } else {}
    } catch (e) {
      print('❌ Lỗi chọn ảnh từ File Manager: $e');
      if (mounted) {
        _showMessage('Lỗi: ${e.toString()}');
      }
    }
  }

  // Chụp ảnh từ camera
  Future<void> _pickImageFromCamera() async {
    // Check camera permission trước
    final hasPermission = await _requestCameraPermission();
    if (!hasPermission) {
      if (mounted) {
        _showMessage('⚠️ Cần quyền camera để chụp ảnh');
      }
      return;
    }

    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 80,
        maxWidth: 1920,
        maxHeight: 1920,
      );

      if (photo != null && mounted) {
        setState(() {
          _selectedImages.add(File(photo.path));
        });
        _showMessage('✅ Đã chụp ảnh');
      }
    } catch (e) {
      if (mounted) {
        _showMessage('Lỗi: ${e.toString()}');
      }
    }
  }

  Future<void> _uploadImages() async {
    for (int i = 0; i < _selectedImages.length; i++) {
      final imageFile = _selectedImages[i];

      try {
        // Kiểm tra file tồn tại
        if (!await imageFile.exists()) {
          print('❌ File không tồn tại: ${imageFile.path}');
          throw Exception('File ảnh ${i + 1} không tồn tại');
        }

        // Kiểm tra kích thước file (tối đa 5MB)
        final fileSize = await imageFile.length();
        if (fileSize > 5 * 1024 * 1024) {
          print('❌ File quá lớn: ${fileSize / (1024 * 1024)}MB');
          throw Exception('Ảnh ${i + 1} quá lớn (tối đa 5MB)');
        }

        print(
          '📸 Uploading ảnh ${i + 1}/${_selectedImages.length} lên Cloudinary...',
        );

        // Upload lên Cloudinary
        final String imageUrl = await CloudinaryService.uploadImage(imageFile);

        // Thêm vào list
        _uploadedImageUrls.add(imageUrl);
      } catch (e) {
        print('❌ Lỗi upload ảnh ${i + 1}: $e');

        // Hiển thị lỗi cho user
        if (mounted) {
          _showMessage('❌ Lỗi upload ảnh ${i + 1}: ${e.toString()}');
        }

        // QUAN TRỌNG: Throw lỗi để dừng việc đăng bài
        rethrow;
      }
    }

    print(
      '🎉 Đã upload thành công ${_uploadedImageUrls.length} ảnh lên Cloudinary',
    );
  }

  Future<void> _submitRoom() async {
    // Validate form
    if (!_formKey.currentState!.validate()) return;

    if (_selectedProvince == null) {
      _showMessage('Vui lòng chọn Tỉnh/Thành phố');
      return;
    }

    if (_selectedDistrict == null) {
      _showMessage('Vui lòng chọn Quận/Huyện');
      return;
    }

    if (_selectedWard == null) {
      _showMessage('Vui lòng chọn Phường/Xã');
      return;
    }

    if (_selectedImages.isEmpty) {
      _showMessage('Vui lòng chọn ít nhất 1 ảnh');
      return;
    }

    if (_selectedImages.length > 10) {
      _showMessage('Chỉ được chọn tối đa 10 ảnh');
      return;
    }

    if (_selectedAmenities.isEmpty) {
      _showMessage('Vui lòng chọn ít nhất 1 tiện ích');
      return;
    }

    // Bắt đầu loading
    setState(() => _isLoading = true);

    try {
      // Bước 1: Upload ảnh lên Firebase Storage
      _showMessage('⏳ Đang upload ${_selectedImages.length} ảnh...');
      await _uploadImages();

      // Kiểm tra xem có ảnh nào upload thành công không
      if (_uploadedImageUrls.isEmpty) {
        throw Exception('Không có ảnh nào được upload thành công');
      }

      // Bước 2: Tạo room data
      _showMessage('⏳ Đang lưu thông tin bài đăng...');

      final roomData = {
        'title': titleController.text.trim(),
        'description': descriptionController.text.trim(),
        'price': double.parse(priceController.text.trim()),
        'area': double.parse(areaController.text.trim()),
        'address': addressController.text.trim(),
        'province': _selectedProvince,
        'district': _selectedDistrict,
        'ward': _selectedWard,
        'ownerId': user.uid,
        'ownerName': ownerNameController.text.trim(),
        'ownerPhone': ownerPhoneController.text.trim(),
        'images': _uploadedImageUrls,
        'amenities': _selectedAmenities,
        'latitude': _selectedLocation?.latitude,
        'longitude': _selectedLocation?.longitude,
        'status': 'pending', // Chờ admin duyệt
        'availabilityStatus': 'DangMo', // 🔥 Trạng thái khả dụng mặc định
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'viewCount': 1, // Khởi tạo lượt xem = 1
        'averageRating': 0.0, // Khởi tạo rating = 0
        'reviewCount': 0, // Khởi tạo số đánh giá = 0
      };

      // Bước 3: Lưu vào Database
      await dbRef.child('rooms').push().set(roomData);

      // Hiển thị thông báo thành công và quay lại
      if (!mounted) return;

      // Hiển thị thông báo
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '✅ Đăng bài thành công với ${_uploadedImageUrls.length} ảnh! Chờ admin duyệt',
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );

      // Đợi 300ms để user thấy thông báo
      await Future.delayed(const Duration(milliseconds: 300));

      // Quay lại màn hình trước - CHỈ POP 1 LẦN!
      if (mounted) {
        Navigator.of(context).pop(true); // Trả về true = thành công
      }
    } catch (e) {
      print('❌ LỖI ĐĂNG BÀI: $e');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Lỗi: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'OK',
              textColor: Colors.white,
              onPressed: () {},
            ),
          ),
        );
      }
    } finally {
      // Reset loading state
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showMessage(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Đăng tin cho thuê'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Upload ảnh
              _buildImageSection(),
              const SizedBox(height: 20),

              // Tiêu đề
              TextFormField(
                controller: titleController,
                maxLength: 100,
                decoration: const InputDecoration(
                  labelText: 'Tiêu đề *',
                  hintText: 'VD: Phòng trọ giá rẻ gần trường ĐH',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.title),
                  counterText: '',
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Vui lòng nhập tiêu đề';
                  }
                  if (val.trim().length < 10) {
                    return 'Tiêu đề phải có ít nhất 10 ký tự';
                  }
                  if (val.trim().length > 100) {
                    return 'Tiêu đề không được quá 100 ký tự';
                  }
                  // Kiểm tra ký tự đặc biệt không hợp lệ
                  if (RegExp(r'[<>{}[\]\\|`~!@#$%^&*()+=]').hasMatch(val)) {
                    return 'Tiêu đề không được chứa ký tự đặc biệt';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Mô tả
              TextFormField(
                controller: descriptionController,
                maxLines: 4,
                maxLength: 500,
                decoration: const InputDecoration(
                  labelText: 'Mô tả *',
                  hintText: 'Mô tả chi tiết về phòng trọ',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.description),
                  counterText: '',
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Vui lòng nhập mô tả';
                  }
                  if (val.trim().length < 20) {
                    return 'Mô tả phải có ít nhất 20 ký tự';
                  }
                  if (val.trim().length > 500) {
                    return 'Mô tả không được quá 500 ký tự';
                  }
                  // Kiểm tra spam (lặp lại từ quá nhiều)
                  final words = val.trim().toLowerCase().split(' ');
                  final wordCount = <String, int>{};
                  for (final word in words) {
                    if (word.length > 2) {
                      wordCount[word] = (wordCount[word] ?? 0) + 1;
                    }
                  }
                  for (final count in wordCount.values) {
                    if (count > 5) {
                      return 'Mô tả chứa từ lặp lại quá nhiều lần';
                    }
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Giá & Diện tích
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: priceController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Giá (VNĐ) *',
                        hintText: '3000000',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.attach_money),
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return 'Vui lòng nhập giá';
                        }
                        final price = double.tryParse(val.trim());
                        if (price == null) {
                          return 'Giá phải là số hợp lệ';
                        }
                        if (price < 500000) {
                          return 'Giá tối thiểu là 500,000 VNĐ';
                        }
                        if (price > 50000000) {
                          return 'Giá tối đa là 50,000,000 VNĐ';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: areaController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Diện tích (m²) *',
                        hintText: '25',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.square_foot),
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return 'Vui lòng nhập diện tích';
                        }
                        final area = double.tryParse(val.trim());
                        if (area == null) {
                          return 'Diện tích phải là số hợp lệ';
                        }
                        if (area < 10) {
                          return 'Diện tích tối thiểu là 10 m²';
                        }
                        if (area > 200) {
                          return 'Diện tích tối đa là 200 m²';
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Tỉnh/Thành phố Dropdown
              if (_isLoadingLocations)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: CircularProgressIndicator(),
                  ),
                )
              else
                DropdownButtonFormField<String>(
                  value: _selectedProvince,
                  decoration: const InputDecoration(
                    labelText: 'Tỉnh/Thành phố *',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.public),
                  ),
                  items: VietnamLocations.getProvinceNames()
                      .map(
                        (prov) =>
                            DropdownMenuItem(value: prov, child: Text(prov)),
                      )
                      .toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedProvince = value;
                      _selectedDistrict = null; // Reset district
                      _selectedWard = null; // Reset ward
                      _availableDistricts = VietnamLocations.getDistrictNames(
                        value ?? '',
                      );
                      _availableWards = [];
                    });
                    // Tự động geocode khi chọn tỉnh
                    _geocodeCurrentAddress();
                  },
                  validator: (val) =>
                      val == null ? 'Vui lòng chọn tỉnh/thành phố' : null,
                ),
              const SizedBox(height: 16),

              // Quận/Huyện Dropdown
              DropdownButtonFormField<String>(
                value: _selectedDistrict,
                decoration: const InputDecoration(
                  labelText: 'Quận/Huyện *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.location_city),
                ),
                items: _availableDistricts
                    .map(
                      (district) => DropdownMenuItem(
                        value: district,
                        child: Text(district),
                      ),
                    )
                    .toList(),
                onChanged: _selectedProvince == null
                    ? null
                    : (value) {
                        setState(() {
                          _selectedDistrict = value;
                          _selectedWard = null; // Reset ward
                          _availableWards = VietnamLocations.getWardNames(
                            _selectedProvince!,
                            value ?? '',
                          );
                        });
                        // Tự động geocode khi chọn quận
                        _geocodeCurrentAddress();
                      },
                validator: (val) =>
                    val == null ? 'Vui lòng chọn quận/huyện' : null,
              ),
              const SizedBox(height: 16),

              // Phường/Xã Dropdown
              DropdownButtonFormField<String>(
                value: _selectedWard,
                decoration: const InputDecoration(
                  labelText: 'Phường/Xã *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.location_on),
                ),
                items: _availableWards
                    .map(
                      (ward) =>
                          DropdownMenuItem(value: ward, child: Text(ward)),
                    )
                    .toList(),
                onChanged: _selectedDistrict == null
                    ? null
                    : (value) {
                        setState(() {
                          _selectedWard = value;
                        });
                        // Tự động geocode khi chọn phường
                        _geocodeCurrentAddress();
                      },
                validator: (val) =>
                    val == null ? 'Vui lòng chọn phường/xã' : null,
              ),
              const SizedBox(height: 16),

              // Địa chỉ cụ thể
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: addressController,
                      decoration: const InputDecoration(
                        labelText: 'Địa chỉ cụ thể *',
                        hintText: '123 Đường ABC',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.home),
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return 'Vui lòng nhập địa chỉ cụ thể';
                        }
                        if (val.trim().length < 5) {
                          return 'Địa chỉ phải có ít nhất 5 ký tự';
                        }
                        if (val.trim().length > 100) {
                          return 'Địa chỉ không được quá 100 ký tự';
                        }
                        // Kiểm tra ký tự đặc biệt không hợp lệ
                        if (RegExp(
                          r'[<>{}[\]\\|`~!@#$%^&*()+=]',
                        ).hasMatch(val)) {
                          return 'Địa chỉ không được chứa ký tự đặc biệt';
                        }
                        return null;
                      },
                      onChanged: (_) {
                        // Sẽ geocode khi nhấn nút bên cạnh
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.green.shade400, Colors.green.shade600],
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: IconButton(
                      onPressed:
                          (_selectedProvince != null &&
                              _selectedDistrict != null &&
                              _selectedWard != null &&
                              addressController.text.trim().isNotEmpty)
                          ? () {
                              // Geocode với địa chỉ đầy đủ
                              _geocodeCurrentAddress();
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    '🗺️ Đang tìm vị trí chính xác...',
                                  ),
                                  duration: Duration(seconds: 1),
                                ),
                              );
                            }
                          : null,
                      icon: const Icon(Icons.my_location, color: Colors.white),
                      tooltip: 'Tìm vị trí chính xác từ địa chỉ',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Google Maps
              _buildMapSection(),
              const SizedBox(height: 16),

              // Tiện ích
              const Text(
                'Tiện ích:',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: amenitiesList.map((amenity) {
                  return FilterChip(
                    label: Text(amenity),
                    selected: _selectedAmenities.contains(amenity),
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          _selectedAmenities.add(amenity);
                        } else {
                          _selectedAmenities.remove(amenity);
                        }
                      });
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),

              // Thông tin chủ nhà
              const Divider(),
              const Text(
                'Thông tin liên hệ:',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),

              // Tên chủ nhà (tự động điền)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue[200]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.person, color: Colors.blue[600], size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Tên: ${ownerNameController.text.isNotEmpty ? ownerNameController.text : "Đang tải..."}',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.blue[700],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Số điện thoại (cho phép nhập thủ công)
              TextFormField(
                controller: ownerPhoneController,
                keyboardType: TextInputType.phone,
                maxLength: 15,
                decoration: const InputDecoration(
                  labelText: 'Số điện thoại *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.phone),
                  counterText: '',
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Vui lòng nhập số điện thoại';
                  }
                  // Loại bỏ tất cả ký tự không phải số
                  final cleanPhone = val.replaceAll(RegExp(r'[^\d]'), '');

                  if (cleanPhone.length < 10) {
                    return 'Số điện thoại phải có ít nhất 10 số';
                  }
                  if (cleanPhone.length > 11) {
                    return 'Số điện thoại không được quá 11 số';
                  }
                  // Kiểm tra format số điện thoại Việt Nam
                  if (!RegExp(
                    r'^(0[3|5|7|8|9])[0-9]{8}$',
                  ).hasMatch(cleanPhone)) {
                    return 'Số điện thoại không đúng định dạng Việt Nam';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),

              // Nút đăng bài
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submitRoom,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        )
                      : const Text(
                          'Đăng bài',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  // Build từng ảnh item - AN TOÀN TUYỆT ĐỐI
  Widget _buildImageItem(int index) {
    if (index >= _selectedImages.length) {
      return const SizedBox.shrink();
    }

    final imageFile = _selectedImages[index];

    return Container(
      width: 120,
      height: 120,
      margin: const EdgeInsets.only(right: 12),
      child: Stack(
        children: [
          // Ảnh chính
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[300]!, width: 2),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: FutureBuilder<bool>(
                future: imageFile.exists(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    );
                  }

                  if (snapshot.data == true) {
                    return Image.file(
                      imageFile,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return _buildErrorPlaceholder();
                      },
                    );
                  }

                  return _buildErrorPlaceholder();
                },
              ),
            ),
          ),

          // Nút xóa
          Positioned(
            top: 4,
            right: 4,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  if (mounted) {
                    setState(() {
                      _selectedImages.removeAt(index);
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Đã xóa ảnh'),
                        duration: Duration(seconds: 1),
                      ),
                    );
                  }
                },
                borderRadius: BorderRadius.circular(15),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close, color: Colors.white, size: 16),
                ),
              ),
            ),
          ),

          // Số thứ tự
          Positioned(
            bottom: 4,
            left: 4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${index + 1}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Placeholder khi lỗi ảnh
  Widget _buildErrorPlaceholder() {
    return Container(
      color: Colors.grey[300],
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Icon(Icons.broken_image, size: 32, color: Colors.grey),
          SizedBox(height: 4),
          Text('Lỗi ảnh', style: TextStyle(fontSize: 10, color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildImageSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Hình ảnh phòng trọ *',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            Text(
              '${_selectedImages.length} ảnh',
              style: TextStyle(color: Colors.grey[600], fontSize: 14),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Nút thêm ảnh - 3 phương thức
        Column(
          children: [
            // Row 1: Thư viện & File Manager
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _pickImages,
                    icon: const Icon(Icons.photo_library),
                    label: const Text('Thư viện'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _pickImagesFromFiles,
                    icon: const Icon(Icons.folder),
                    label: const Text('File Manager'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Row 2: Camera
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _pickImageFromCamera,
                icon: const Icon(Icons.camera_alt),
                label: const Text('Chụp ảnh'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        // Hiển thị ảnh đã chọn - AN TOÀN TUYỆT ĐỐI
        if (_selectedImages.isNotEmpty)
          Container(
            height: 120,
            margin: const EdgeInsets.symmetric(vertical: 8),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _selectedImages.length,
              itemBuilder: (context, index) {
                return _buildImageItem(index);
              },
            ),
          ),

        // Hướng dẫn
        if (_selectedImages.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue[200]!),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue[700]),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Vui lòng thêm ít nhất 1 ảnh phòng trọ',
                    style: TextStyle(color: Colors.blue[700]),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildMapSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.map, color: Colors.blue.shade700),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Vị trí trên bản đồ (tùy chọn)',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_selectedLocation != null)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.check_circle,
                        color: Colors.green.shade600,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Đã xác định vị trí',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Hiển thị địa chỉ đầy đủ nếu có
                  if (_selectedProvince != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.home,
                            size: 14,
                            color: Colors.blue.shade700,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              [
                                if (addressController.text.trim().isNotEmpty)
                                  addressController.text.trim(),
                                if (_selectedWard != null) _selectedWard,
                                if (_selectedDistrict != null)
                                  _selectedDistrict,
                                if (_selectedProvince != null)
                                  _selectedProvince,
                              ].join(', '),
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.blue.shade900,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(
                        Icons.location_on,
                        size: 14,
                        color: Colors.grey.shade600,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          'Lat: ${_selectedLocation!.latitude.toStringAsFixed(6)}, Lng: ${_selectedLocation!.longitude.toStringAsFixed(6)}',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            )
          else
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: Colors.orange.shade700,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Chọn địa chỉ ở trên để tự động xác định vị trí',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.orange.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () async {
                final result = await Navigator.push<LatLng>(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        PickLocationPage(initialLocation: _selectedLocation),
                  ),
                );
                if (result != null && mounted) {
                  setState(() {
                    _selectedLocation = result;
                  });
                }
              },
              icon: Icon(
                _selectedLocation == null
                    ? Icons.add_location
                    : Icons.edit_location,
              ),
              label: Text(
                _selectedLocation == null
                    ? 'Chọn vị trí trên bản đồ'
                    : 'Xem/Chỉnh sửa vị trí trên bản đồ',
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
