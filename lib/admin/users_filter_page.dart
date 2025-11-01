import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';

class UsersFilterPage extends StatefulWidget {
  final String filterType; // 'all', 'admin', 'regular', 'today'
  final String title;

  const UsersFilterPage({
    super.key,
    required this.filterType,
    required this.title,
  });

  @override
  State<UsersFilterPage> createState() => _UsersFilterPageState();
}

class _UsersFilterPageState extends State<UsersFilterPage> {
  final dbRef = FirebaseDatabase.instance.ref();

  Future<void> _toggleUserRole(String userId, bool isAdmin) async {
    await dbRef.child('users').child(userId).update({
      'role': isAdmin ? 'user' : 'admin',
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isAdmin ? 'Đã gỡ quyền admin' : 'Đã cấp quyền admin'),
        ),
      );
    }
  }

  Future<void> _editUser(String userId, Map userData) async {
    final nameController = TextEditingController(text: userData['name'] ?? '');
    final phoneController = TextEditingController(
      text: userData['phone'] ?? '',
    );

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Chỉnh sửa người dùng'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Họ và tên',
                  prefixIcon: Icon(Icons.person),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: phoneController,
                decoration: const InputDecoration(
                  labelText: 'Số điện thoại',
                  prefixIcon: Icon(Icons.phone),
                ),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.email, size: 16, color: Colors.grey[600]),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            userData['email'] ?? "",
                            style: TextStyle(
                              color: Colors.grey[700],
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.fingerprint,
                          size: 16,
                          color: Colors.grey[600],
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'ID: $userId',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 10,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () async {
              await dbRef.child('users').child(userId).update({
                'name': nameController.text.trim(),
                'phone': phoneController.text.trim(),
              });
              if (mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('✅ Đã cập nhật thông tin')),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
            child: const Text('Lưu'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteUser(String userId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xác nhận xóa'),
        content: const Text(
          'Bạn có chắc muốn xóa người dùng này? (Chỉ xóa dữ liệu profile, không xóa tài khoản Firebase Auth)',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await dbRef.child('users').child(userId).remove();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Đã xóa người dùng')));
      }
    }
  }

  List<MapEntry> _filterUsers(Map users) {
    final now = DateTime.now();
    final todayStart = DateTime(
      now.year,
      now.month,
      now.day,
    ).millisecondsSinceEpoch;

    return users.entries.where((entry) {
      final user = entry.value as Map;
      final role = user['role'] ?? 'user';
      final createdAt = user['createdAt'] ?? 0;

      switch (widget.filterType) {
        case 'all':
          return true;
        case 'admin':
          return role == 'admin';
        case 'regular':
          return role == 'user';
        case 'today':
          return createdAt >= todayStart;
        default:
          return true;
      }
    }).toList()..sort((a, b) {
      final aTime = a.value['createdAt'] ?? 0;
      final bTime = b.value['createdAt'] ?? 0;
      return bTime.compareTo(aTime);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: Colors.cyan,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: StreamBuilder(
          stream: dbRef.child('users').onValue,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline, size: 60, color: Colors.red[300]),
                    const SizedBox(height: 16),
                    Text(
                      'Lỗi tải dữ liệu: ${snapshot.error}',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              );
            }

            final data = (snapshot.data?.snapshot.value ?? {}) as Map?;
            if (data == null || data.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.people_outline,
                      size: 80,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Chưa có người dùng nào',
                      style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                    ),
                  ],
                ),
              );
            }

            final filteredUsers = _filterUsers(data);

            if (filteredUsers.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.search_off, size: 80, color: Colors.grey[400]),
                    const SizedBox(height: 16),
                    Text(
                      'Không có người dùng nào phù hợp',
                      style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                    ),
                  ],
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: filteredUsers.length,
              itemBuilder: (context, index) {
                final userId = filteredUsers[index].key;
                final userData = filteredUsers[index].value as Map;
                final name = userData['name'] ?? 'Người dùng';
                final email = userData['email'] ?? '';
                final phone = userData['phone'] ?? '';
                final role = userData['role'] ?? 'user';
                final isAdmin = role == 'admin';

                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: isAdmin ? Colors.orange : Colors.blue,
                      child: Icon(
                        isAdmin ? Icons.admin_panel_settings : Icons.person,
                        color: Colors.white,
                      ),
                    ),
                    title: Row(
                      children: [
                        Expanded(
                          child: Text(
                            name,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        if (isAdmin)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.orange,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              'ADMIN',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (email.isNotEmpty)
                          Text(email, style: const TextStyle(fontSize: 13)),
                        if (phone.isNotEmpty)
                          Text(
                            phone,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                      ],
                    ),
                    trailing: PopupMenuButton<String>(
                      onSelected: (value) {
                        if (value == 'edit') {
                          _editUser(userId, userData);
                        } else if (value == 'toggle_role') {
                          _toggleUserRole(userId, isAdmin);
                        } else if (value == 'delete') {
                          _deleteUser(userId);
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'edit',
                          child: Row(
                            children: [
                              Icon(Icons.edit, size: 20, color: Colors.blue),
                              SizedBox(width: 8),
                              Text('Chỉnh sửa'),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'toggle_role',
                          child: Row(
                            children: [
                              Icon(
                                isAdmin
                                    ? Icons.person
                                    : Icons.admin_panel_settings,
                                size: 20,
                                color: Colors.orange,
                              ),
                              const SizedBox(width: 8),
                              Text(isAdmin ? 'Gỡ admin' : 'Cấp admin'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete, size: 20, color: Colors.red),
                              SizedBox(width: 8),
                              Text('Xóa', style: TextStyle(color: Colors.red)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
