import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:spend_wisely/Function/fire_services.dart';
import 'package:spend_wisely/Function/models.dart';

class ExpenseScreen extends StatefulWidget {
  @override
  _ExpenseScreenState createState() => _ExpenseScreenState();
}

class _ExpenseScreenState extends State<ExpenseScreen> {
  User? _currentUser;
  List<Transaction> _expenseTransactions = [];
  Map<String, Category> _categoriesMap = {};
  double _totalExpenseAmount = 0.0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _currentUser = FirebaseAuth.instance.currentUser;
    if (_currentUser != null) {
      _fetchData();
    } else {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchData() async {
    setState(() {
      _isLoading = true;
    });
    try {
      await _fetchCategories();
      await _fetchExpenses();
    } catch (e) {
      Fluttertoast.showToast(
        msg: "Lỗi khi tải dữ liệu chi tiêu: ${e.toString()}",
        toastLength: Toast.LENGTH_LONG,
        gravity: ToastGravity.TOP,
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchCategories() async {
    try {
      List<Category> fetchedCategories =
          await FirebaseService.getAllCategories();
      setState(() {
        _categoriesMap = {
          for (var category in fetchedCategories) category.categoryId: category,
        };
      });
    } catch (e) {
      Fluttertoast.showToast(
        msg: "Lỗi tải hạng mục: ${e.toString()}",
        toastLength: Toast.LENGTH_LONG,
        gravity: ToastGravity.TOP,
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
    }
  }

  Future<void> _fetchExpenses() async {
    if (_currentUser == null) return;
    try {
      List<Transaction> expenses = await FirebaseService.getTransactions(
        _currentUser!.uid,
        'expense',
      );
      double total = expenses.fold(0.0, (sum, item) => sum + item.amount);
      setState(() {
        _expenseTransactions = expenses;
        _totalExpenseAmount = total;
      });
    } catch (e) {
      Fluttertoast.showToast(
        msg: "Lỗi tải giao dịch chi tiêu: ${e.toString()}",
        toastLength: Toast.LENGTH_LONG,
        gravity: ToastGravity.TOP,
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFFDE3E3), // Nền hồng nhạt/đỏ nhạt cho Chi tiêu
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          "CHI TIÊU",
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : Column(
              children: [
                SizedBox(height: 20),
                Text(
                  "Tổng chi tiêu",
                  style: TextStyle(color: Colors.grey, fontSize: 16),
                ),
                Text(
                  "${_totalExpenseAmount.toStringAsFixed(0)} đ",
                  style: TextStyle(
                    color: Colors.redAccent,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                SizedBox(height: 30),

                Expanded(
                  child: _expenseTransactions.isEmpty
                      ? Center(child: Text("Không có giao dịch chi tiêu nào."))
                      : Container(
                          padding: EdgeInsets.symmetric(horizontal: 20),
                          child: ListView.builder(
                            itemCount: _expenseTransactions.length,
                            itemBuilder: (context, index) {
                              final transaction = _expenseTransactions[index];
                              final category =
                                  _categoriesMap[transaction.categoryId];
                              return _buildTransactionItem(
                                transaction.note.isEmpty
                                    ? "Không có ghi chú"
                                    : transaction.note, // Title
                                "${transaction.amount.toStringAsFixed(0)} đ", // Amount
                                category?.name ??
                                    "Không xác định", // Category name
                                category?.icon ?? Icons.category, // IconData
                                category?.color ?? Colors.grey, // Color
                              );
                            },
                          ),
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildTransactionItem(
    String title,
    String amount,
    String categoryName, // Thêm tham số category name
    IconData icon,
    Color iconColor,
  ) {
    return Container(
      margin: EdgeInsets.only(bottom: 15),
      padding: EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: iconColor.withOpacity(0.2),
            child: Icon(icon, color: iconColor),
          ),
          SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(fontWeight: FontWeight.w500, fontSize: 16),
                ),
                SizedBox(height: 4),
                // Hiển thị nhãn category
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: iconColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    categoryName,
                    style: TextStyle(
                      color: iconColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 10),
          Text(
            amount,
            style: TextStyle(
              color: Colors.red,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
}
