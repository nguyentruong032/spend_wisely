// Chức năng 2: Trang notification.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:spend_wisely/Function/fire_services.dart';
import 'package:spend_wisely/Function/models.dart';

class NotificationScreen extends StatefulWidget {
  @override
  _NotificationScreenState createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  User? _currentUser;
  List<Transaction> _newTransactions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _currentUser = FirebaseAuth.instance.currentUser;
    if (_currentUser != null) {
      _fetchNewTransactions();
    } else {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchNewTransactions() async {
    setState(() {
      _isLoading = true;
    });
    try {
      List<Transaction> allTransactions = await FirebaseService.getTransactions(
        _currentUser!.uid,
        'all',
      );
      // Lọc các giao dịch chưa xem, sắp xếp theo date desc, lấy 10 gần nhất
      allTransactions.sort((a, b) => b.date.compareTo(a.date));
      _newTransactions = allTransactions
          .where((tx) => !tx.isViewed)
          .take(10)
          .toList();
    } catch (e) {
      Fluttertoast.showToast(msg: "Lỗi tải thông báo: $e");
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _markAsViewed() async {
    try {
      for (var tx in _newTransactions) {
        await FirebaseService.updateTransactionViewed(tx.transactionId, true);
      }
      setState(() {
        _newTransactions.clear();
      });
      Fluttertoast.showToast(msg: "Đã đánh dấu tất cả là đã xem.");
    } catch (e) {
      Fluttertoast.showToast(msg: "Lỗi khi cập nhật trạng thái: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Thông báo giao dịch mới'),
        actions: [
          IconButton(icon: Icon(Icons.done_all), onPressed: _markAsViewed),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _newTransactions.isEmpty
          ? Center(child: Text('Không có thông báo mới.'))
          : ListView.builder(
              itemCount: _newTransactions.length,
              itemBuilder: (context, index) {
                final tx = _newTransactions[index];
                return ListTile(
                  title: Text(tx.note ?? 'Giao dịch không có ghi chú'),
                  subtitle: Text(
                    '${tx.amount} đ - ${tx.type == 'expense' ? 'Chi tiêu' : 'Thu nhập'}',
                  ),
                  trailing: Text(
                    DateTime.fromMillisecondsSinceEpoch(tx.date).toString(),
                  ),
                );
              },
            ),
    );
  }
}
