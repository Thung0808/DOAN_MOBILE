import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'models/room_model.dart';
import 'services/cloudinary_service.dart';
import 'data/vietnam_locations.dart';

class EditRoomPage extends StatefulWidget {
  final Room room;

  const EditRoomPage({super.key, required this.room});

  @override
  State<EditRoomPage> createState() => _EditRoomPageState();
}

class _EditRoomPageState extends State<EditRoomPage> {
  final _formKey = GlobalKey<FormState>();
  final dbRef = FirebaseDatabase.instance.ref();
  final ImagePicker _picker = ImagePicker();

  late final TextEditingController titleController;
  late final TextEditingController descriptionController;
  late final TextEditingController priceController;
  late final TextEditingController areaController;
  late final TextEditingController addressController;

  String? _selectedProvince;
  String? _selectedDistrict;
  String? _selectedWard;
  List<String> _availableDistricts = [];
  List<String> _availableWards = [];
  final List<String> _selectedAmenities = [];
  final List<File> _newImages = [];
  final List<String> _uploadedNewImageUrls = [];
  List<String> _existingImageUrls = [];
  bool _isLoading = false;
  bool _isLoadingLocations = true;

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
    _initializeData();
    _loadLocationData();
  }

  void _initializeData() {
    // Initialize controllers with existing data
    titleController = TextEditingController(text: widget.room.title);
    descriptionController = TextEditingController(
      text: widget.room.description,
    );
    priceController = TextEditingController(
      text: widget.room.price.toInt().toString(),
    );
    areaController = TextEditingController(
      text: widget.room.area.toInt().toString(),
    );
    addressController = TextEditingController(text: widget.room.address);

    // Set location data
    _selectedProvince = widget.room.province.isNotEmpty
        ? widget.room.province
        : null;
    _selectedDistrict = widget.room.district;
    _selectedWard = widget.room.ward;

    // Set amenities
    _selectedAmenities.addAll(widget.room.amenities);

    // Set existing images
    _existingImageUrls = List<String>.from(widget.room.images);
  }

  Future<void> _loadLocationData() async {
    await VietnamLocations.loadData();
    if (mounted) {
      // Load districts and wards if province is selected
      if (_selectedProvince != null) {
        setState(() {
          _availableDistricts = VietnamLocations.getDistrictNames(
            _selectedProvince!,
          );
          if (_selectedDistrict != null) {
            _availableWards = VietnamLocations.getWardNames(
              _selectedProvince!,
              _selectedDistrict!,
            );
          }
          _isLoadingLocations = false;
        });
      } else {
        setState(() {
          _isLoadingLocations = false;
        });
      }
    }
  }

  @override
  void dispose() {
    titleController.dispose();
    descriptionController.dispose();
    priceController.dispose();
    areaController.dispose();
    addressController.dispose();
    super.dispose();
  }

  Future<void> _requestPhotoPermission() async {
    if (Platform.isAndroid) {
      // Android 13+ uses Photo Picker (no permission needed)
      // Android < 13 needs storage permission
      final androidInfo = await Permission.storage.status;
      if (androidInfo.isDenied) {
        await Permission.storage.request();
      }
    } else if (Platform.isIOS) {
      await Permission.photos.request();
    }
  }

  Future<void> _pickImages() async {
    await _requestPhotoPermission();

    try {
      final List<XFile> images = await _picker.pickMultiImage();
      if (images.isNotEmpty) {
        setState(() {
          _newImages.addAll(images.map((xFile) => File(xFile.path)));
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Lỗi chọn ảnh: $e')));
      }
    }
  }

  Future<void> _pickImagesFromFiles() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: true,
      );

      if (result != null && result.files.isNotEmpty) {
        setState(() {
          for (var file in result.files) {
            if (file.path != null) {
              _newImages.add(File(file.path!));
            }
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Lỗi chọn ảnh: $e')));
      }
    }
  }

  Future<void> _takePhoto() async {
    await _requestPhotoPermission();
    await Permission.camera.request();

    try {
      final XFile? photo = await _picker.pickImage(source: ImageSource.camera);
      if (photo != null) {
        setState(() {
          _newImages.add(File(photo.path));
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Lỗi chụp ảnh: $e')));
      }
    }
  }

  void _removeExistingImage(int index) {
    setState(() {
      _existingImageUrls.removeAt(index);
    });
  }

  void _removeNewImage(int index) {
    setState(() {
      _newImages.removeAt(index);
    });
  }

  Future<void> _uploadNewImages() async {
    if (_newImages.isEmpty) return;

    for (var imageFile in _newImages) {
      try {
        final imageUrl = await CloudinaryService.uploadImage(imageFile);
        _uploadedNewImageUrls.add(imageUrl);
      } catch (e) {
      }
    }
  }

  Future<void> _updateRoom() async {
    if (!_formKey.currentState!.validate()) return;

    final totalImages = _existingImageUrls.length + _newImages.length;
    if (totalImages == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng chọn ít nhất 1 ảnh')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Upload new images
      await _uploadNewImages();

      // Combine existing and new image URLs
      final allImageUrls = [..._existingImageUrls, ..._uploadedNewImageUrls];

      // Update room data
      await dbRef.child('rooms').child(widget.room.id).update({
        'title': titleController.text.trim(),
        'description': descriptionController.text.trim(),
        'price': double.parse(priceController.text.trim()),
        'area': double.parse(areaController.text.trim()),
        'address': addressController.text.trim(),
        'province': _selectedProvince ?? '',
        'district': _selectedDistrict ?? '',
        'ward': _selectedWard ?? '',
        'images': allImageUrls,
        'amenities': _selectedAmenities,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Đã cập nhật bài đăng thành công!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Lỗi: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sửa bài đăng'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: _isLoadingLocations
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Title
                  TextFormField(
                    controller: titleController,
                    decoration: const InputDecoration(
                      labelText: 'Tiêu đề',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) => value == null || value.isEmpty
                        ? 'Vui lòng nhập tiêu đề'
                        : null,
                  ),
                  const SizedBox(height: 16),

                  // Description
                  TextFormField(
                    controller: descriptionController,
                    decoration: const InputDecoration(
                      labelText: 'Mô tả',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 4,
                    validator: (value) => value == null || value.isEmpty
                        ? 'Vui lòng nhập mô tả'
                        : null,
                  ),
                  const SizedBox(height: 16),

                  // Price & Area
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: priceController,
                          decoration: const InputDecoration(
                            labelText: 'Giá (₫)',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.number,
                          validator: (value) => value == null || value.isEmpty
                              ? 'Nhập giá'
                              : null,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextFormField(
                          controller: areaController,
                          decoration: const InputDecoration(
                            labelText: 'Diện tích (m²)',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.number,
                          validator: (value) => value == null || value.isEmpty
                              ? 'Nhập diện tích'
                              : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Province
                  DropdownButtonFormField<String>(
        initialValue: _selectedProvince,
                    decoration: const InputDecoration(
                      labelText: 'Tỉnh/Thành phố',
                      border: OutlineInputBorder(),
                    ),
                    items: VietnamLocations.getProvinceNames()
                        .map(
                          (province) => DropdownMenuItem(
                            value: province,
                            child: Text(province),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedProvince = value;
                        _selectedDistrict = null;
                        _selectedWard = null;
                        _availableDistricts = value != null
                            ? VietnamLocations.getDistrictNames(value)
                            : [];
                        _availableWards = [];
                      });
                    },
                    validator: (value) =>
                        value == null ? 'Chọn tỉnh/thành phố' : null,
                  ),
                  const SizedBox(height: 16),

                  // District
                  DropdownButtonFormField<String>(
        initialValue: _selectedDistrict,
                    decoration: const InputDecoration(
                      labelText: 'Quận/Huyện',
                      border: OutlineInputBorder(),
                    ),
                    items: _availableDistricts
                        .map(
                          (district) => DropdownMenuItem(
                            value: district,
                            child: Text(district),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedDistrict = value;
                        _selectedWard = null;
                        _availableWards =
                            value != null && _selectedProvince != null
                            ? VietnamLocations.getWardNames(
                                _selectedProvince!,
                                value,
                              )
                            : [];
                      });
                    },
                    validator: (value) =>
                        value == null ? 'Chọn quận/huyện' : null,
                  ),
                  const SizedBox(height: 16),

                  // Ward
                  DropdownButtonFormField<String>(
        initialValue: _selectedWard,
                    decoration: const InputDecoration(
                      labelText: 'Phường/Xã',
                      border: OutlineInputBorder(),
                    ),
                    items: _availableWards
                        .map(
                          (ward) =>
                              DropdownMenuItem(value: ward, child: Text(ward)),
                        )
                        .toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedWard = value;
                      });
                    },
                    validator: (value) =>
                        value == null ? 'Chọn phường/xã' : null,
                  ),
                  const SizedBox(height: 16),

                  // Address
                  TextFormField(
                    controller: addressController,
                    decoration: const InputDecoration(
                      labelText: 'Địa chỉ cụ thể',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) =>
                        value == null || value.isEmpty ? 'Nhập địa chỉ' : null,
                  ),
                  const SizedBox(height: 16),

                  // Amenities
                  const Text(
                    'Tiện nghi:',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: amenitiesList.map((amenity) {
                      final isSelected = _selectedAmenities.contains(amenity);
                      return FilterChip(
                        label: Text(amenity),
                        selected: isSelected,
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

                  // Images
                  const Text(
                    'Hình ảnh:',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),

                  // Existing Images
                  if (_existingImageUrls.isNotEmpty) ...[
                    const Text('Ảnh hiện tại:', style: TextStyle(fontSize: 14)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _existingImageUrls.asMap().entries.map((entry) {
                        final index = entry.key;
                        final url = entry.value;
                        return Stack(
                          children: [
                            Container(
                              width: 100,
                              height: 100,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                image: DecorationImage(
                                  image: NetworkImage(url),
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                            Positioned(
                              top: 4,
                              right: 4,
                              child: GestureDetector(
                                onTap: () => _removeExistingImage(index),
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(
                                    color: Colors.red,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.close,
                                    size: 16,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // New Images
                  if (_newImages.isNotEmpty) ...[
                    const Text('Ảnh mới:', style: TextStyle(fontSize: 14)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _newImages.asMap().entries.map((entry) {
                        final index = entry.key;
                        final image = entry.value;
                        return Stack(
                          children: [
                            Container(
                              width: 100,
                              height: 100,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                image: DecorationImage(
                                  image: FileImage(image),
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                            Positioned(
                              top: 4,
                              right: 4,
                              child: GestureDetector(
                                onTap: () => _removeNewImage(index),
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(
                                    color: Colors.red,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.close,
                                    size: 16,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Add Image Buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _pickImages,
                          icon: const Icon(Icons.photo_library),
                          label: const Text('Thư viện'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _pickImagesFromFiles,
                          icon: const Icon(Icons.folder),
                          label: const Text('File Manager'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _takePhoto,
                          icon: const Icon(Icons.camera_alt),
                          label: const Text('Chụp ảnh'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),

                  // Submit Button
                  ElevatedButton(
                    onPressed: _isLoading ? null : _updateRoom,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text(
                            'Cập nhật bài đăng',
                            style: TextStyle(fontSize: 16),
                          ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
    );
  }
}
