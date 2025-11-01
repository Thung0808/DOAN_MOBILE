import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';

class ManageTransactionsPage extends StatefulWidget {
  const ManageTransactionsPage({super.key});

  @override
  State<ManageTransactionsPage> createState() => _ManageTransactionsPageState();
}

class _ManageTransactionsPageState extends State<ManageTransactionsPage> {
  final dbRef = FirebaseDatabase.instance.ref();

  List<Map<String, dynamic>> _allTransactions = [];
  List<Map<String, dynamic>> _filteredTransactions = [];
  bool _isLoading = true;

  // Thống kê
  double _totalRevenue = 0;
  int _successCount = 0;
  int _failedCount = 0;

  // Bộ lọc
  String _filterStatus = 'all'; // all, success, failed
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadTransactions();
  }

  Future<void> _loadTransactions() async {
    setState(() => _isLoading = true);

    try {
      final snapshot = await dbRef.child('payments').get();

      if (snapshot.exists && snapshot.value != null) {
        final paymentsMap = snapshot.value as Map<dynamic, dynamic>;

        _allTransactions = [];
        _totalRevenue = 0;
        _successCount = 0;
        _failedCount = 0;

        for (var entry in paymentsMap.entries) {
          final payment = Map<String, dynamic>.from(entry.value as Map);
          payment['id'] = entry.key;
          _allTransactions.add(payment);

          // Tính thống kê
          final status = payment['status']?.toString() ?? '';
          final amount = (payment['amount'] ?? 0).toDouble();

          if (status == 'success') {
            _successCount++;
            _totalRevenue += amount;
          } else {
            _failedCount++;
          }
        }

        // Sắp xếp theo thời gian (mới nhất trước)
        _allTransactions.sort((a, b) {
          final aTime = a['createdAt'] ?? 0;
          final bTime = b['createdAt'] ?? 0;
          return bTime.compareTo(aTime);
        });

        _applyFilters();
      }
    } catch (e) {
      print('Error loading transactions: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _applyFilters() {
    _filteredTransactions = _allTransactions.where((transaction) {
      // Lọc theo status
      if (_filterStatus != 'all') {
        final status = transaction['status']?.toString() ?? '';
        if (status != _filterStatus) return false;
      }

      // Lọc theo search query
      if (_searchQuery.isNotEmpty) {
        final id = transaction['id']?.toString().toLowerCase() ?? '';
        final userId = transaction['userId']?.toString().toLowerCase() ?? '';
        final roomTitle =
            transaction['roomTitle']?.toString().toLowerCase() ?? '';
        final bookingId =
            transaction['bookingId']?.toString().toLowerCase() ?? '';

        if (!id.contains(_searchQuery.toLowerCase()) &&
            !userId.contains(_searchQuery.toLowerCase()) &&
            !roomTitle.contains(_searchQuery.toLowerCase()) &&
            !bookingId.contains(_searchQuery.toLowerCase())) {
          return false;
        }
      }

      return true;
    }).toList();

    setState(() {});
  }

  void _showTransactionDetail(Map<String, dynamic> transaction) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.receipt_long, color: Colors.blue),
            SizedBox(width: 8),
            Text('Chi tiết giao dịch'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailRow('Payment ID', transaction['id'] ?? 'N/A'),
              _buildDetailRow('User ID', transaction['userId'] ?? 'N/A'),
              _buildDetailRow(
                'Số tiền',
                NumberFormat.currency(
                  locale: 'vi_VN',
                  symbol: '₫',
                ).format((transaction['amount'] ?? 0).toDouble()),
              ),
              _buildDetailRow('Trạng thái', transaction['status'] ?? 'N/A'),
              _buildDetailRow(
                'Phương thức',
                transaction['paymentMethod'] ?? 'N/A',
              ),
              _buildDetailRow(
                'Tiền tệ',
                (transaction['currency'] ?? 'N/A').toUpperCase(),
              ),
              if (transaction['roomTitle'] != null)
                _buildDetailRow('Phòng', transaction['roomTitle']),
              if (transaction['roomId'] != null)
                _buildDetailRow('Room ID', transaction['roomId']),
              if (transaction['bookingId'] != null)
                _buildDetailRow('Booking ID', transaction['bookingId']),
              _buildDetailRow(
                'Thời gian',
                transaction['createdAt'] != null
                    ? DateFormat('dd/MM/yyyy HH:mm:ss').format(
                        DateTime.fromMillisecondsSinceEpoch(
                          transaction['createdAt'],
                        ),
                      )
                    : 'N/A',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Đóng'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
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
            child: SelectableText(
              value,
              style: const TextStyle(color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quản lý giao dịch'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadTransactions,
            tooltip: 'Làm mới',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Thống kê tổng quan
                Container(
                  padding: const EdgeInsets.all(16),
                  color: Colors.green[50],
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          '💰 Tổng doanh thu',
                          NumberFormat.currency(
                            locale: 'vi_VN',
                            symbol: '₫',
                          ).format(_totalRevenue),
                          Colors.green,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildStatCard(
                          '✅ Thành công',
                          '$_successCount giao dịch',
                          Colors.blue,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildStatCard(
                          '❌ Thất bại',
                          '$_failedCount giao dịch',
                          Colors.red,
                        ),
                      ),
                    ],
                  ),
                ),

                const Divider(height: 1),

                // Bộ lọc và tìm kiếm
                Container(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      // Search bar
                      TextField(
                        decoration: InputDecoration(
                          hintText:
                              'Tìm kiếm (ID, User ID, Phòng, Booking ID)...',
                          prefixIcon: const Icon(Icons.search),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                        onChanged: (value) {
                          _searchQuery = value;
                          _applyFilters();
                        },
                      ),

                      const SizedBox(height: 12),

                      // Status filter
                      Row(
                        children: [
                          const Text(
                            'Trạng thái:',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Wrap(
                              spacing: 8,
                              children: [
                                FilterChip(
                                  label: const Text('Tất cả'),
                                  selected: _filterStatus == 'all',
                                  onSelected: (_) {
                                    setState(() => _filterStatus = 'all');
                                    _applyFilters();
                                  },
                                ),
                                FilterChip(
                                  label: const Text('Thành công'),
                                  selected: _filterStatus == 'success',
                                  onSelected: (_) {
                                    setState(() => _filterStatus = 'success');
                                    _applyFilters();
                                  },
                                ),
                                FilterChip(
                                  label: const Text('Thất bại'),
                                  selected: _filterStatus == 'failed',
                                  onSelected: (_) {
                                    setState(() => _filterStatus = 'failed');
                                    _applyFilters();
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const Divider(height: 1),

                // Kết quả
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Tìm thấy ${_filteredTransactions.length} giao dịch',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),

                // Danh sách giao dịch
                Expanded(
                  child: _filteredTransactions.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.receipt_long_outlined,
                                size: 64,
                                color: Colors.grey[400],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Không có giao dịch nào',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _filteredTransactions.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final transaction = _filteredTransactions[index];
                            return _buildTransactionCard(transaction);
                          },
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildStatCard(String title, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionCard(Map<String, dynamic> transaction) {
    final status = transaction['status']?.toString() ?? '';
    final amount = (transaction['amount'] ?? 0).toDouble();
    final createdAt = transaction['createdAt'] != null
        ? DateTime.fromMillisecondsSinceEpoch(transaction['createdAt'])
        : null;

    final isSuccess = status == 'success';
    final statusColor = isSuccess ? Colors.green : Colors.red;
    final statusIcon = isSuccess ? Icons.check_circle : Icons.cancel;
    final statusText = isSuccess ? 'Thành công' : 'Thất bại';

    return Card(
      elevation: 2,
      child: InkWell(
        onTap: () => _showTransactionDetail(transaction),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: Status + Amount
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(statusIcon, color: statusColor, size: 20),
                      const SizedBox(width: 6),
                      Text(
                        statusText,
                        style: TextStyle(
                          color: statusColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    NumberFormat.currency(
                      locale: 'vi_VN',
                      symbol: '₫',
                    ).format(amount),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isSuccess ? Colors.green : Colors.grey,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              // Room Title (if available)
              if (transaction['roomTitle'] != null) ...[
                Row(
                  children: [
                    const Icon(Icons.home, size: 14, color: Colors.grey),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        transaction['roomTitle'],
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
              ],

              // Payment ID
              Row(
                children: [
                  const Icon(Icons.tag, size: 14, color: Colors.grey),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'ID: ${transaction['id'] ?? 'N/A'}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.grey,
                        fontFamily: 'monospace',
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 4),

              // Date + User
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.access_time,
                        size: 14,
                        color: Colors.grey,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        createdAt != null
                            ? DateFormat('dd/MM/yyyy HH:mm').format(createdAt)
                            : 'N/A',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      const Icon(Icons.person, size: 14, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text(
                        (transaction['userId'] ?? 'N/A').toString().substring(
                          0,
                          8,
                        ),
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.grey,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
