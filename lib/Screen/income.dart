import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:spend_wisely/Function/fire_services.dart';
import 'package:spend_wisely/Function/models.dart';

class IncomeScreen extends StatefulWidget {
  @override
  _IncomeScreenState createState() => _IncomeScreenState();
}

class _IncomeScreenState extends State<IncomeScreen> {
  User? _currentUser;
  List<Transaction> _incomeTransactions = [];
  Map<String, Category> _categoriesMap = {};
  double _totalIncomeAmount = 0.0;
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
      await _fetchIncomes();
    } catch (e) {
      Fluttertoast.showToast(
        msg: "Lỗi khi tải dữ liệu thu nhập: ${e.toString()}",
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

  Future<void> _fetchIncomes() async {
    if (_currentUser == null) return;
    try {
      List<Transaction> incomes = await FirebaseService.getTransactions(
        _currentUser!.uid,
        'income',
      );
      double total = incomes.fold(0.0, (sum, item) => sum + item.amount);
      setState(() {
        _incomeTransactions = incomes;
        _totalIncomeAmount = total;
      });
    } catch (e) {
      Fluttertoast.showToast(
        msg: "Lỗi tải giao dịch thu nhập: ${e.toString()}",
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
      backgroundColor: Color(0xFFE3F2FD),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          "THU NHẬP",
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
                  "Tổng thu nhập",
                  style: TextStyle(color: Colors.grey, fontSize: 16),
                ),
                Text(
                  "${_totalIncomeAmount.toStringAsFixed(0)} đ",
                  style: TextStyle(
                    color: Colors.blue,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                SizedBox(height: 30),

                // Danh sách các khoản thu
                Expanded(
                  child: _incomeTransactions.isEmpty
                      ? Center(child: Text("Không có giao dịch thu nhập nào."))
                      : Container(
                          padding: EdgeInsets.symmetric(horizontal: 20),
                          child: ListView.builder(
                            itemCount: _incomeTransactions.length,
                            itemBuilder: (context, index) {
                              final transaction = _incomeTransactions[index];
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
                                category?.color ?? Colors.blue, // Color
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
    String categoryName, // Tham số category name
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
              color: Colors.blue,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
}
