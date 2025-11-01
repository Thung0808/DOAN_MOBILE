import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../models/report_model.dart';
import '../room_detail_page.dart';
import '../models/room_model.dart';

class ManageReportsPage extends StatefulWidget {
  const ManageReportsPage({super.key});

  @override
  State<ManageReportsPage> createState() => _ManageReportsPageState();
}

class _ManageReportsPageState extends State<ManageReportsPage>
    with SingleTickerProviderStateMixin {
  final dbRef = FirebaseDatabase.instance.ref();
  final user = FirebaseAuth.instance.currentUser!;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _resolveReport(Report report, String action) async {
    final adminNoteController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          action == 'resolved' ? 'Giải quyết báo cáo' : 'Bỏ qua báo cáo',
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              action == 'resolved'
                  ? 'Xác nhận báo cáo này là hợp lệ và đã xử lý?'
                  : 'Xác nhận bỏ qua báo cáo này?',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: adminNoteController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Ghi chú của admin (không bắt buộc)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: action == 'resolved'
                  ? Colors.green
                  : Colors.grey,
            ),
            child: const Text('Xác nhận'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await dbRef.child('reports').child(report.id).update({
        'status': action,
        'adminNote': adminNoteController.text.trim().isEmpty
            ? null
            : adminNoteController.text.trim(),
        'resolvedBy': user.email,
        'resolvedAt': DateTime.now().millisecondsSinceEpoch,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              action == 'resolved'
                  ? 'Đã giải quyết báo cáo'
                  : 'Đã bỏ qua báo cáo',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  Future<void> _viewRoomDetail(String roomId) async {
    final roomSnapshot = await dbRef.child('rooms').child(roomId).get();
    if (roomSnapshot.exists) {
      final room = Room.fromMap(roomId, roomSnapshot.value as Map);
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => RoomDetailPage(room: room)),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Bài đăng không tồn tại hoặc đã bị xóa'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildReportCard(Report report) {
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');
    final reportDate = DateTime.fromMillisecondsSinceEpoch(report.timestamp);

    Color statusColor;
    IconData statusIcon;
    String statusText;

    switch (report.status) {
      case 'resolved':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        statusText = 'Đã giải quyết';
        break;
      case 'dismissed':
        statusColor = Colors.grey;
        statusIcon = Icons.cancel;
        statusText = 'Đã bỏ qua';
        break;
      default:
        statusColor = Colors.orange;
        statusIcon = Icons.hourglass_empty;
        statusText = 'Chờ xử lý';
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      child: ExpansionTile(
        leading: Icon(Icons.flag, color: statusColor, size: 28),
        title: Text(
          report.roomTitle,
          style: const TextStyle(fontWeight: FontWeight.bold),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(statusIcon, size: 16, color: statusColor),
                const SizedBox(width: 4),
                Text(
                  statusText,
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Lý do: ${report.reason}',
              style: const TextStyle(fontSize: 13),
            ),
            Text(
              dateFormat.format(reportDate),
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildInfoRow('Người báo cáo', report.reporterName),
                _buildInfoRow('Email', report.reporterEmail),
                _buildInfoRow('Lý do', report.reason),
                if (report.description.isNotEmpty)
                  _buildInfoRow('Chi tiết', report.description),
                if (report.adminNote != null && report.adminNote!.isNotEmpty)
                  _buildInfoRow('Ghi chú admin', report.adminNote!),
                if (report.resolvedBy != null) ...[
                  _buildInfoRow('Xử lý bởi', report.resolvedBy!),
                  if (report.resolvedAt != null)
                    _buildInfoRow(
                      'Thời gian xử lý',
                      dateFormat.format(
                        DateTime.fromMillisecondsSinceEpoch(report.resolvedAt!),
                      ),
                    ),
                ],
                const SizedBox(height: 16),
                // Action buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _viewRoomDetail(report.roomId),
                        icon: const Icon(Icons.visibility),
                        label: const Text('Xem bài đăng'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.blue,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    if (report.status == 'pending') ...[
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _resolveReport(report, 'dismissed'),
                          icon: const Icon(Icons.cancel, size: 18),
                          label: const Text('Bỏ qua'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.grey,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _resolveReport(report, 'resolved'),
                          icon: const Icon(Icons.check, size: 18),
                          label: const Text('Giải quyết'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Text(value, style: TextStyle(color: Colors.grey[700])),
          ),
        ],
      ),
    );
  }

  Widget _buildFilteredReportsList(
    List<Report> allReports,
    String filterStatus,
  ) {
    var reports = List<Report>.from(allReports);

    if (filterStatus != 'all') {
      reports = reports.where((r) => r.status == filterStatus).toList();
    }

    if (reports.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox, size: 80, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              filterStatus == 'all'
                  ? 'Chưa có báo cáo nào'
                  : 'Không có báo cáo nào',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: reports.length,
      itemBuilder: (context, index) {
        return _buildReportCard(reports[index]);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quản lý báo cáo'),
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'Chờ xử lý'),
            Tab(text: 'Đã giải quyết'),
            Tab(text: 'Tất cả'),
          ],
        ),
      ),
      body: StreamBuilder(
        stream: dbRef.child('reports').onValue,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return const Center(child: Text('Lỗi tải dữ liệu'));
          }

          final data = (snapshot.data?.snapshot.value ?? {}) as Map?;
          if (data == null || data.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.flag_outlined, size: 80, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'Chưa có báo cáo nào',
                    style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                  ),
                ],
              ),
            );
          }

          // Parse all reports once with error handling
          final allReports = <Report>[];
          for (var entry in data.entries) {
            try {
              final report = Report.fromMap(entry.key, entry.value as Map);
              allReports.add(report);
            } catch (e) {
              // Skip this report and continue
            }
          }
          allReports.sort((a, b) => b.timestamp.compareTo(a.timestamp));

          return TabBarView(
            controller: _tabController,
            key: const PageStorageKey<String>('reports_tab_view'),
            children: [
              _buildFilteredReportsList(allReports, 'pending'),
              _buildFilteredReportsList(allReports, 'resolved'),
              _buildFilteredReportsList(allReports, 'all'),
            ],
          );
        },
      ),
    );
  }
}
