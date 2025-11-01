import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';
import '../models/room_model.dart';
import '../room_detail_page.dart';

class ApprovePostsPage extends StatefulWidget {
  const ApprovePostsPage({super.key});

  @override
  State<ApprovePostsPage> createState() => _ApprovePostsPageState();
}

class _ApprovePostsPageState extends State<ApprovePostsPage> {
  final dbRef = FirebaseDatabase.instance.ref();
  String _filterStatus = 'pending'; // pending, approved, rejected, all

  Future<void> _approvePost(String postId) async {
    await dbRef.child('rooms').child(postId).update({'status': 'approved'});
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Đã duyệt bài đăng'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _rejectPost(String postId) async {
    await dbRef.child('rooms').child(postId).update({'status': 'rejected'});
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ Đã từ chối bài đăng'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _deletePost(String postId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xác nhận xóa'),
        content: const Text('Bạn có chắc muốn xóa bài đăng này?'),
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
      await dbRef.child('rooms').child(postId).remove();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Đã xóa bài đăng')));
      }
    }
  }

  Widget _buildStatusChip(String status) {
    Color color;
    String text;
    IconData icon;

    switch (status) {
      case 'approved':
        color = Colors.green;
        text = 'Đã duyệt';
        icon = Icons.check_circle;
        break;
      case 'rejected':
        color = Colors.red;
        text = 'Từ chối';
        icon = Icons.cancel;
        break;
      default:
        color = Colors.orange;
        text = 'Chờ duyệt';
        icon = Icons.hourglass_empty;
    }

    return Chip(
      avatar: Icon(icon, size: 16, color: Colors.white),
      label: Text(text, style: const TextStyle(color: Colors.white)),
      backgroundColor: color,
      padding: EdgeInsets.zero,
    );
  }

  @override
  Widget build(BuildContext context) {
    final formatter = NumberFormat.currency(locale: 'vi_VN', symbol: '₫');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Duyệt bài đăng'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          PopupMenuButton<String>(
            initialValue: _filterStatus,
            icon: const Icon(Icons.filter_list),
            onSelected: (value) {
              setState(() {
                _filterStatus = value;
              });
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'pending',
                child: Text('🕐 Chờ duyệt'),
              ),
              const PopupMenuItem(value: 'approved', child: Text('✅ Đã duyệt')),
              const PopupMenuItem(value: 'rejected', child: Text('❌ Từ chối')),
              const PopupMenuItem(value: 'all', child: Text('📋 Tất cả')),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: StreamBuilder(
          stream: dbRef.child('rooms').onValue,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return const Center(child: Text('Lỗi tải dữ liệu'));
            }

            final data = (snapshot.data?.snapshot.value ?? {}) as Map?;
            if (data == null || data.isEmpty) {
              return const Center(child: Text('Chưa có bài đăng nào'));
            }

            // Filter by status
            var posts =
                data.entries
                    .map((entry) => Room.fromMap(entry.key, entry.value))
                    .where((room) {
                      if (_filterStatus == 'all') return true;
                      return room.status == _filterStatus;
                    })
                    .toList()
                  ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

            if (posts.isEmpty) {
              return Center(
                child: Text(
                  'Không có bài ${_filterStatus == "pending"
                      ? "chờ duyệt"
                      : _filterStatus == "approved"
                      ? "đã duyệt"
                      : "bị từ chối"}',
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: posts.length,
              itemBuilder: (context, index) {
                final post = posts[index];

                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Image & Info
                      InkWell(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => RoomDetailPage(room: post),
                            ),
                          );
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Thumbnail
                              Container(
                                width: 100,
                                height: 80,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  color: Colors.grey[300],
                                ),
                                child: post.images.isNotEmpty
                                    ? ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: Image.network(
                                          post.images.first,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) =>
                                              const Icon(
                                                Icons.image_not_supported,
                                              ),
                                        ),
                                      )
                                    : const Icon(Icons.home, size: 40),
                              ),
                              const SizedBox(width: 12),

                              // Info
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            post.title,
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                            ),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        _buildStatusChip(post.status),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.location_on,
                                          size: 14,
                                          color: Colors.grey,
                                        ),
                                        const SizedBox(width: 4),
                                        Expanded(
                                          child: Text(
                                            '${post.ward}, ${post.district}',
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: Colors.grey[600],
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      formatter.format(post.price),
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.red,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Chủ trọ: ${post.ownerName}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Action Buttons
                      const Divider(height: 1),
                      Padding(
                        padding: const EdgeInsets.all(8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            if (post.status == 'pending') ...[
                              OutlinedButton.icon(
                                onPressed: () => _rejectPost(post.id),
                                icon: const Icon(Icons.close, size: 18),
                                label: const Text('Từ chối'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.red,
                                ),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton.icon(
                                onPressed: () => _approvePost(post.id),
                                icon: const Icon(Icons.check, size: 18),
                                label: const Text('Duyệt'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ] else if (post.status == 'rejected') ...[
                              ElevatedButton.icon(
                                onPressed: () => _approvePost(post.id),
                                icon: const Icon(Icons.check, size: 18),
                                label: const Text('Duyệt lại'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ],
                            const SizedBox(width: 8),
                            OutlinedButton.icon(
                              onPressed: () => _deletePost(post.id),
                              icon: const Icon(Icons.delete, size: 18),
                              label: const Text('Xóa'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
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
