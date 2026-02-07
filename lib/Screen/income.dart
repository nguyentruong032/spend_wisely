import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:spend_wisely/Function/fire_services.dart';
import 'package:spend_wisely/Function/models.dart';
import 'package:intl/intl.dart'; // Thêm để format ngày tháng

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
  // Controllers cho 3 ô lọc
  final TextEditingController _dayController = TextEditingController();
  final TextEditingController _monthController = TextEditingController();
  final TextEditingController _yearController = TextEditingController();

  List<Transaction> _allTransactions = []; // Dữ liệu gốc
  List<Transaction> _filteredTransactions = []; // Dữ liệu hiển thị sau khi lọc
  void _calculateTotal() {
    setState(() {
      // Luôn tính tổng dựa trên danh sách đang hiển thị (filteredTransactions)
      _totalIncomeAmount = _filteredTransactions.fold(
        0.0,
        (sum, item) => sum + item.amount,
      );
    });
  }

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
    List<Transaction> incomes = await FirebaseService.getTransactions(
      _currentUser!.uid,
      'income',
    );
    setState(() {
      _allTransactions = incomes;
      _filteredTransactions = incomes;
      _calculateTotal();
    });
  }

  // Logic lọc dữ liệu theo 3 ô Textbox
  void _filterData() {
    String d = _dayController.text.trim();
    String m = _monthController.text.trim();
    String y = _yearController.text.trim();

    setState(() {
      _filteredTransactions = _allTransactions.where((tx) {
        DateTime date = DateTime.fromMillisecondsSinceEpoch(tx.date);

        bool matchDay = d.isEmpty || date.day == int.tryParse(d);
        bool matchMonth = m.isEmpty || date.month == int.tryParse(m);
        bool matchYear = y.isEmpty || date.year == int.tryParse(y);

        return matchDay && matchMonth && matchYear;
      }).toList();
      _calculateTotal();
    });
  }

  // Chức năng xóa giao dịch
  Future<void> _deleteTransaction(String transactionId) async {
    try {
      await FirebaseService.deleteTransaction(transactionId);
      setState(() {
        _allTransactions.removeWhere((tx) => tx.transactionId == transactionId);
        _filterData(); // Cập nhật lại danh sách đang hiển thị
        _calculateTotal();
      });
      Fluttertoast.showToast(msg: "Đã xóa giao dịch");
    } catch (e) {
      _showError("Không thể xóa: ${e.toString()}");
    }
  }

  void _showError(String msg) {
    Fluttertoast.showToast(
      msg: msg,
      backgroundColor: Colors.red,
      textColor: Colors.white,
      gravity: ToastGravity.TOP,
    );
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
                // === KHU VỰC BỘ LỌC ===
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 15,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildSearchField(_dayController, 'Ngày'),
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: _buildSearchField(_monthController, 'Tháng'),
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: _buildSearchField(_yearController, 'Năm'),
                      ),
                      IconButton(
                        icon: Icon(Icons.refresh, color: Colors.grey),
                        onPressed: () {
                          _dayController.clear();
                          _monthController.clear();
                          _yearController.clear();
                          _filterData();
                        },
                      ),
                    ],
                  ),
                ),

                // Danh sách các khoản thu
                // === DANH SÁCH GIAO DỊCH ===
                Expanded(
                  child: _filteredTransactions.isEmpty
                      ? Center(child: Text("Không tìm thấy giao dịch nào."))
                      : Container(
                          padding: EdgeInsets.symmetric(horizontal: 20),
                          child: ListView.builder(
                            itemCount: _filteredTransactions.length,
                            itemBuilder: (context, index) {
                              final transaction = _filteredTransactions[index];
                              final category =
                                  _categoriesMap[transaction.categoryId];

                              return Dismissible(
                                key: Key(transaction.transactionId),
                                direction: DismissDirection.endToStart,
                                confirmDismiss: (direction) async {
                                  // Dialog xác nhận chuẩn chuyên nghiệp
                                  return await showDialog(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      title: Text("Xác nhận"),
                                      content: Text(
                                        "Bạn có chắc muốn xóa giao dịch này?",
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(context, false),
                                          child: Text("Hủy"),
                                        ),
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(context, true),
                                          child: Text(
                                            "Xóa",
                                            style: TextStyle(color: Colors.red),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                                onDismissed: (direction) => _deleteTransaction(
                                  transaction.transactionId,
                                ),
                                background: Container(
                                  alignment: Alignment.centerRight,
                                  padding: EdgeInsets.only(right: 20),
                                  decoration: BoxDecoration(
                                    color: Colors.red,
                                    borderRadius: BorderRadius.circular(15),
                                  ),
                                  child: Icon(
                                    Icons.delete,
                                    color: Colors.white,
                                  ),
                                ),
                                child: _buildTransactionItem(
                                  transaction.note.isEmpty
                                      ? "Không có ghi chú"
                                      : transaction.note,
                                  "${transaction.amount.toStringAsFixed(0)} đ",
                                  category?.name ?? "Không xác định",
                                  category?.icon ?? Icons.category,
                                  category?.color ?? Colors.grey,
                                  transaction.date,
                                ),
                              );
                            },
                          ),
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildSearchField(TextEditingController controller, String label) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      textAlign: TextAlign.center,
      style: TextStyle(fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(fontSize: 12),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        contentPadding: EdgeInsets.zero,
      ),
      onChanged: (value) => _filterData(),
    );
  }

  Widget _buildTransactionItem(
    String title,
    String amount,
    String categoryName,
    IconData icon,
    Color iconColor,
    int timestamp,
  ) {
    String formattedDate = DateFormat(
      'dd/MM/yyyy',
    ).format(DateTime.fromMillisecondsSinceEpoch(timestamp));

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
            backgroundColor: iconColor.withOpacity(0.1),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                Text(
                  "$categoryName • $formattedDate",
                  style: TextStyle(color: Colors.grey, fontSize: 11),
                ),
              ],
            ),
          ),
          Text(
            amount,
            style: TextStyle(
              color: Colors.red,
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }
}
