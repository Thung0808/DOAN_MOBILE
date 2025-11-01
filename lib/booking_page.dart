import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';
import 'models/room_model.dart';
import 'stripe_payment_page.dart';

class BookingPage extends StatefulWidget {
  final Room room;

  const BookingPage({super.key, required this.room});

  @override
  State<BookingPage> createState() => _BookingPageState();
}

class _BookingPageState extends State<BookingPage> {
  final user = FirebaseAuth.instance.currentUser!;
  final dbRef = FirebaseDatabase.instance.ref();

  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  final TextEditingController _notesController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  // 🔔 Thông báo cho những người đã đặt lịch xem trước đó
  Future<void> _notifyOtherViewers(
    String currentBookingId,
    String depositorName,
  ) async {
    try {
      // Lấy tất cả booking của phòng này
      final bookingsSnapshot = await dbRef
          .child('bookings')
          .orderByChild('roomId')
          .equalTo(widget.room.id)
          .get();

      if (!bookingsSnapshot.exists) return;

      final bookingsMap = bookingsSnapshot.value as Map;

      for (var entry in bookingsMap.entries) {
        final bookingData = entry.value as Map;
        final bookingId = entry.key;

        // Bỏ qua booking hiện tại và chỉ thông báo cho booking type 'viewing'
        if (bookingId == currentBookingId) continue;
        if (bookingData['bookingType'] != 'viewing') continue;
        if (bookingData['status'] == 'cancelled' ||
            bookingData['status'] == 'rejected')
          continue;

        final tenantId = bookingData['tenantId'];
        if (tenantId == null || tenantId == user.uid) continue;

        // Gửi thông báo
        final notificationRef = dbRef
            .child('users')
            .child(tenantId)
            .child('notifications')
            .push();

        await notificationRef.set({
          'title': '⚠️ Phòng đã được đặt cọc',
          'content':
              'Rất tiếc! Phòng "${widget.room.title}" mà bạn đã đặt lịch xem đã được $depositorName đặt cọc trước. Vui lòng tìm phòng khác phù hợp.',
          'type': 'room_deposited',
          'roomId': widget.room.id,
          'roomTitle': widget.room.title,
          'depositorName': depositorName,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
          'adminId': 'system',
          'adminName': 'Hệ thống',
        });
      }
    } catch (e) {
      print('❌ Lỗi gửi thông báo cho viewers: $e');
    }
  }

  // 🔔 Thông báo cho chủ trọ về việc đặt cọc thành công
  Future<void> _notifyOwnerAboutDeposit(String tenantName) async {
    try {
      final notificationRef = dbRef
          .child('users')
          .child(widget.room.ownerId)
          .child('notifications')
          .push();

      await notificationRef.set({
        'title': '💰 Có người đặt cọc phòng',
        'content':
            '$tenantName đã đặt cọc 30% cho phòng "${widget.room.title}". Phòng hiện đã được khóa. Vui lòng liên hệ người thuê để hoàn tất thủ tục.',
        'type': 'deposit_received',
        'roomId': widget.room.id,
        'roomTitle': widget.room.title,
        'tenantId': user.uid,
        'tenantName': tenantName,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'adminId': 'system',
        'adminName': 'Hệ thống',
      });
    } catch (e) {
      print('❌ Lỗi gửi thông báo cho chủ trọ: $e');
    }
  }

  // 🔔 Thông báo cho chủ trọ về lịch xem đầu tiên
  Future<void> _notifyOwnerAboutFirstViewing(String tenantName) async {
    try {
      final notificationRef = dbRef
          .child('users')
          .child(widget.room.ownerId)
          .child('notifications')
          .push();

      await notificationRef.set({
        'title': '📅 Có người đặt lịch xem phòng',
        'content':
            '$tenantName là người đầu tiên đặt lịch xem phòng "${widget.room.title}". Phòng hiện đã có người quan tâm!',
        'type': 'first_viewing_scheduled',
        'roomId': widget.room.id,
        'roomTitle': widget.room.title,
        'tenantId': user.uid,
        'tenantName': tenantName,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'adminId': 'system',
        'adminName': 'Hệ thống',
      });
    } catch (e) {
      print('❌ Lỗi gửi thông báo cho chủ trọ: $e');
    }
  }

  Future<void> _selectDateTime() async {
    // Chọn ngày trước
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );

    if (pickedDate == null) return;

    // Chọn giờ sau
    final TimeOfDay? pickedTime = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 9, minute: 0),
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: child!,
        );
      },
    );

    if (pickedTime == null) return;

    // Kiểm tra thời gian không được trong quá khứ
    final bookingDateTime = DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    );

    if (bookingDateTime.isBefore(DateTime.now())) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Thời gian đặt lịch không được trong quá khứ'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    // Xác nhận lựa chọn
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xác nhận lịch hẹn'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Bạn đã chọn:'),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.calendar_today, color: Colors.blue, size: 20),
                const SizedBox(width: 8),
                Text(
                  DateFormat('dd/MM/yyyy').format(pickedDate),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.access_time, color: Colors.blue, size: 20),
                const SizedBox(width: 8),
                Text(
                  pickedTime.format(context),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Bạn sẽ xem phòng "${widget.room.title}" vào thời gian này.',
                style: TextStyle(fontSize: 14, color: Colors.blue[700]),
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
            child: const Text('Xác nhận'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() {
        _selectedDate = pickedDate;
        _selectedTime = pickedTime;
      });
    }
  }

  Future<void> _submitBooking({bool requirePayment = false}) async {
    if (_selectedDate == null || _selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng chọn ngày và giờ xem phòng'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // 🔥 Nếu yêu cầu thanh toán (đặt cọc), kiểm tra trạng thái phòng
    if (requirePayment) {
      final roomSnapshot = await dbRef
          .child('rooms')
          .child(widget.room.id)
          .get();
      if (roomSnapshot.exists) {
        final roomData = roomSnapshot.value as Map;
        final availabilityStatus = roomData['availabilityStatus'] ?? 'DangMo';

        if (availabilityStatus == 'DaDatCoc') {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Row(
                  children: [
                    Icon(Icons.error, color: Colors.white),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Phòng đã được đặt cọc! Vui lòng chọn phòng khác.',
                      ),
                    ),
                  ],
                ),
                backgroundColor: Colors.red,
                duration: Duration(seconds: 4),
              ),
            );
          }
          return;
        }
      }
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Tạo booking datetime
      final bookingDateTime = DateTime(
        _selectedDate!.year,
        _selectedDate!.month,
        _selectedDate!.day,
        _selectedTime!.hour,
        _selectedTime!.minute,
      );

      // Kiểm tra thời gian đặt lịch (không được trong quá khứ)
      if (bookingDateTime.isBefore(DateTime.now())) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Thời gian đặt lịch không được trong quá khứ'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() {
          _isLoading = false;
        });
        return;
      }

      // Lấy thông tin người dùng
      final userSnapshot = await dbRef.child('users').child(user.uid).get();
      if (!userSnapshot.exists) {
        throw Exception('Không tìm thấy thông tin người dùng');
      }

      final userData = userSnapshot.value as Map;
      final userName = userData['name'] ?? user.displayName ?? 'Người dùng';
      final userPhone = userData['phone'] ?? '';
      final userEmail = user.email ?? '';

      // Tạo booking ID
      final bookingRef = dbRef.child('bookings').push();
      final bookingId = bookingRef.key!;

      // Lưu booking vào Firebase - chỉ lưu thông tin cơ bản
      await bookingRef.set({
        'roomId': widget.room.id,
        'roomTitle': widget.room.title,
        'roomAddress':
            '${widget.room.address}, ${widget.room.ward}, ${widget.room.district}',
        'tenantId': user.uid,
        'tenantName': userName,
        'tenantPhone': userPhone,
        'tenantEmail': userEmail,
        'ownerId': widget.room.ownerId,
        'ownerName': widget.room.ownerName,
        'ownerPhone': widget.room.ownerPhone,
        'ownerEmail': '',
        'bookingDateTime': bookingDateTime.millisecondsSinceEpoch,
        'status': 'pending',
        'bookingType': requirePayment
            ? 'deposit'
            : 'viewing', // 🔥 Phân biệt loại booking
        'notes': _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
        'createdAt': DateTime.now().millisecondsSinceEpoch,
        // 💰 Thông tin thanh toán
        'fullPrice': widget.room.price,
        'depositAmount': (widget.room.price * 0.3).roundToDouble(),
        'remainingAmount': (widget.room.price * 0.7).roundToDouble(),
        'paymentStatus': 'unpaid', // 'unpaid', 'partial', 'paid'
      });

      // Lưu booking vào profile người dùng
      final userBookingsRef = dbRef
          .child('users')
          .child(user.uid)
          .child('bookings')
          .child(bookingId);
      await userBookingsRef.set({
        'roomId': widget.room.id,
        'roomTitle': widget.room.title,
        'bookingDateTime': bookingDateTime.millisecondsSinceEpoch,
        'status': 'pending',
        'createdAt': DateTime.now().millisecondsSinceEpoch,
      });

      // Lưu booking vào profile chủ trọ
      final ownerBookingsRef = dbRef
          .child('users')
          .child(widget.room.ownerId)
          .child('ownerBookings')
          .child(bookingId);
      await ownerBookingsRef.set({
        'roomId': widget.room.id,
        'roomTitle': widget.room.title,
        'tenantId': user.uid,
        'tenantName': userName,
        'tenantPhone': userPhone,
        'bookingDateTime': bookingDateTime.millisecondsSinceEpoch,
        'status': 'pending',
        'createdAt': DateTime.now().millisecondsSinceEpoch,
      });

      // Tạo thông báo riêng cho chủ trọ
      final ownerNotificationRef = dbRef
          .child('users')
          .child(widget.room.ownerId)
          .child('notifications')
          .push();
      await ownerNotificationRef.set({
        'title': '🔔 Có người đặt lịch xem phòng',
        'content':
            '$userName muốn xem phòng "${widget.room.title}" vào ${DateFormat('dd/MM/yyyy HH:mm').format(bookingDateTime)}. Vui lòng xác nhận hoặc từ chối.',
        'type': 'booking_request',
        'bookingId': bookingId,
        'roomId': widget.room.id,
        'tenantId': user.uid,
        'tenantName': userName,
        'ownerId': widget.room.ownerId,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'adminId': 'system',
        'adminName': 'Hệ thống',
      });

      // Tạo thông báo riêng cho người đặt lịch
      final tenantNotificationRef = dbRef
          .child('users')
          .child(user.uid)
          .child('notifications')
          .push();
      await tenantNotificationRef.set({
        'title': '✅ Đặt lịch xem phòng thành công',
        'content':
            'Bạn đã đặt lịch xem phòng "${widget.room.title}" vào ${DateFormat('dd/MM/yyyy HH:mm').format(bookingDateTime)}. Chủ trọ sẽ xác nhận trong thời gian sớm nhất.',
        'type': 'booking_success',
        'bookingId': bookingId,
        'roomId': widget.room.id,
        'tenantId': user.uid,
        'tenantName': userName,
        'ownerId': widget.room.ownerId,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'adminId': 'system',
        'adminName': 'Hệ thống',
      });

      if (mounted) {
        if (requirePayment) {
          // Nếu yêu cầu thanh toán, chuyển sang trang Stripe
          // 🔥 Tính tiền đặt cọc 30% giá phòng
          final depositAmount = (widget.room.price * 0.3).roundToDouble();

          final paymentSuccess = await Navigator.push<bool>(
            context,
            MaterialPageRoute(
              builder: (context) => StripePaymentPage(
                amount: depositAmount,
                bookingId: bookingId,
                roomId: widget.room.id,
                roomTitle: widget.room.title,
                isDeposit: true, // Đánh dấu đây là tiền đặt cọc
                fullPrice: widget.room.price,
              ),
            ),
          );

          if (paymentSuccess == true) {
            // 🔒 ATOMIC: Dùng transaction để đảm bảo chỉ 1 người đặt cọc được
            final transactionResult = await dbRef
                .child('rooms')
                .child(widget.room.id)
                .child('availabilityStatus')
                .runTransaction((currentValue) {
                  final currentStatus = currentValue as String? ?? 'DangMo';

                  // Chỉ cho phép đặt cọc nếu phòng còn trống (DangMo hoặc DaDatLich)
                  if (currentStatus == 'DangMo' ||
                      currentStatus == 'DaDatLich') {
                    return Transaction.success('DaDatCoc');
                  } else {
                    // Phòng đã được đặt cọc bởi người khác
                    return Transaction.abort();
                  }
                });

            if (!transactionResult.committed) {
              // Transaction failed - phòng đã được người khác đặt cọc
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      '❌ Phòng đã được người khác đặt cọc trước bạn!',
                    ),
                    backgroundColor: Colors.red,
                    duration: Duration(seconds: 4),
                  ),
                );
                Navigator.pop(context, false);
              }
              return;
            }

            // Transaction thành công - cập nhật các thông tin khác
            await dbRef.child('rooms').child(widget.room.id).update({
              'depositedBy': user.uid,
              'depositedAt': DateTime.now().millisecondsSinceEpoch,
            });

            // Cập nhật trạng thái booking thành partial (đã đặt cọc 30%)
            await bookingRef.update({
              'paymentStatus': 'partial',
              'paidDepositAt': DateTime.now().millisecondsSinceEpoch,
            });

            // 🔔 Thông báo cho những người đã đặt lịch xem trước đó
            await _notifyOtherViewers(bookingId, userName);

            // 🔔 Thông báo cho chủ trọ về việc đặt cọc
            await _notifyOwnerAboutDeposit(userName);

            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.check_circle, color: Colors.white),
                          SizedBox(width: 12),
                          Expanded(child: Text('Đặt cọc 30% thành công!')),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '💰 Đã trả: ${NumberFormat.currency(locale: 'vi_VN', symbol: '₫').format(depositAmount)}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.white70,
                        ),
                      ),
                      Text(
                        '📝 Còn lại: ${NumberFormat.currency(locale: 'vi_VN', symbol: '₫').format((widget.room.price * 0.7).roundToDouble())} (trả khi nhận phòng)',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                  backgroundColor: Colors.green,
                  duration: const Duration(seconds: 5),
                ),
              );
              Navigator.pop(context, true);
            }
          }
        } else {
          // 🔒 ATOMIC: Dùng transaction để cập nhật trạng thái phòng
          // Chỉ cập nhật nếu phòng đang mở (DangMo)
          final transactionResult = await dbRef
              .child('rooms')
              .child(widget.room.id)
              .child('availabilityStatus')
              .runTransaction((currentValue) {
                final currentStatus = currentValue as String? ?? 'DangMo';

                // Chỉ set 'DaDatLich' nếu phòng đang 'DangMo'
                if (currentStatus == 'DangMo') {
                  return Transaction.success('DaDatLich');
                } else {
                  // Phòng đã có người đặt lịch/đặt cọc - không làm gì
                  return Transaction.success(currentStatus);
                }
              });

          // Nếu transaction thành công và status mới là 'DaDatLich'
          if (transactionResult.committed &&
              transactionResult.snapshot.value == 'DaDatLich') {
            // Cập nhật thông tin người đặt lịch đầu tiên
            await dbRef.child('rooms').child(widget.room.id).update({
              'firstViewingAt': DateTime.now().millisecondsSinceEpoch,
              'firstViewerId': user.uid,
            });

            // 🔔 Thông báo cho chủ trọ về lịch xem đầu tiên
            await _notifyOwnerAboutFirstViewing(userName);
          }

          if (mounted) {
            final roomSnapshot = await dbRef
                .child('rooms')
                .child(widget.room.id)
                .get();
            final roomData = roomSnapshot.value as Map?;
            final currentStatus = roomData?['availabilityStatus'] ?? 'DangMo';

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.check_circle, color: Colors.white),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Đặt lịch thành công!',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 4),
                    Text(
                      '✉️ Chủ trọ đã nhận được thông báo',
                      style: TextStyle(fontSize: 12, color: Colors.white70),
                    ),
                    if (currentStatus == 'DaDatLich')
                      Text(
                        '⚠️ Lưu ý: Phòng đã có người quan tâm. Đặt cọc sớm để giữ phòng!',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.orangeAccent,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                  ],
                ),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 5),
              ),
            );

            Navigator.pop(
              context,
              true,
            ); // Trả về true để refresh trang chi tiết
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(child: Text('Lỗi đặt lịch: ${e.toString()}')),
              ],
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
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
        title: const Text('Đặt lịch xem phòng'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Thông tin phòng
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 4,
                            height: 24,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF4A90E2), Color(0xFF50C9FF)],
                              ),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            'Thông tin phòng',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        widget.room.title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(
                            Icons.location_on,
                            size: 16,
                            color: Colors.grey,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              '${widget.room.address}, ${widget.room.ward}, ${widget.room.district}',
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.grey,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(
                            Icons.attach_money,
                            size: 16,
                            color: Colors.green,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            NumberFormat.currency(
                              locale: 'vi_VN',
                              symbol: '₫',
                            ).format(widget.room.price),
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                          const SizedBox(width: 16),
                          const Icon(
                            Icons.square_foot,
                            size: 16,
                            color: Colors.blue,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${widget.room.area} m²',
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.blue,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Chọn ngày giờ
              const Text(
                'Chọn ngày giờ xem phòng',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              InkWell(
                onTap: _selectDateTime,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[300]!),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.event, color: Colors.blue),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _selectedDate == null || _selectedTime == null
                              ? 'Chọn ngày giờ xem phòng'
                              : '${DateFormat('dd/MM/yyyy').format(_selectedDate!)} lúc ${_selectedTime!.format(context)}',
                          style: TextStyle(
                            fontSize: 16,
                            color:
                                _selectedDate == null || _selectedTime == null
                                ? Colors.grey
                                : Colors.black,
                          ),
                        ),
                      ),
                      const Icon(Icons.arrow_drop_down, color: Colors.grey),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Ghi chú
              const Text(
                'Ghi chú (tùy chọn)',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _notesController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText:
                      'Nhập ghi chú cho chủ trọ (ví dụ: thời gian phù hợp, số người xem...)',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.all(12),
                ),
              ),

              const SizedBox(height: 32),

              // Nút đặt lịch (không thanh toán)
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _isLoading
                      ? null
                      : () => _submitBooking(requirePayment: false),
                  icon: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : const Icon(Icons.event),
                  label: Text(
                    _isLoading ? 'Đang xử lý...' : 'Đặt lịch xem phòng',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // Nút thanh toán ngay với Stripe
              SizedBox(
                width: double.infinity,
                height: 50,
                child: OutlinedButton.icon(
                  onPressed: _isLoading
                      ? null
                      : () => _submitBooking(requirePayment: true),
                  icon: const Icon(Icons.payment),
                  label: Text(
                    'Đặt cọc 30% ngay (${NumberFormat.currency(locale: 'vi_VN', symbol: '₫').format((widget.room.price * 0.3).round())})',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF635BFF), // Stripe color
                    side: const BorderSide(color: Color(0xFF635BFF), width: 2),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Thông tin bổ sung
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue[200]!),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info, color: Colors.blue, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Chủ trọ sẽ nhận được thông báo và xác nhận lịch hẹn của bạn.',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.blue[700],
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '💰 Đặt cọc 30% = ${NumberFormat.currency(locale: 'vi_VN', symbol: '₫').format((widget.room.price * 0.3).round())}',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.blue[900],
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '📝 Còn lại 70% = ${NumberFormat.currency(locale: 'vi_VN', symbol: '₫').format((widget.room.price * 0.7).round())} (trả khi nhận phòng)',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.blue[700],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
