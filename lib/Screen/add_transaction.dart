// (Đã chỉnh sửa để fix crash khi xóa danh mục, reset selected, và giữ chức năng xóa
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:spend_wisely/Function/fire_services.dart';
import 'package:spend_wisely/Function/models.dart';
import 'form_category.dart'; // Đổi tên nếu file add_category.dart của bạn tên khác

class AddTransactionScreen extends StatefulWidget {
  const AddTransactionScreen({super.key});

  @override
  State<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends State<AddTransactionScreen> {
  String amount = "0";
  List<Category> _categories = [];
  List<Category> _filteredCategories = [];
  Category? _selectedCategory;
  final _noteController = TextEditingController();
  String _selectedDate = "Hôm nay";
  User? _currentUser;
  String _selectedTransactionType = 'expense';
  int _dropdownKey = 0; // Thêm biến này
  final GlobalKey _dropdownButtonKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _currentUser = FirebaseAuth.instance.currentUser;
    _fetchCategories().then((_) => _filterCategories());
  }

  Future<void> _fetchCategories() async {
    try {
      List<Category> fetchedCategories =
          await FirebaseService.getAllCategories();

      if (!mounted) return; // Thêm dòng này

      setState(() {
        _categories = fetchedCategories;
      });
    } catch (e) {
      if (!mounted) return; // Thêm dòng này

      Fluttertoast.showToast(
        msg: "Lỗi tải danh mục: $e",
        toastLength: Toast.LENGTH_LONG,
        gravity: ToastGravity.TOP,
        backgroundColor: Colors.red,
      );
    }
  }

  void _filterCategories() {
    _filteredCategories = _categories
        .where((category) => category.type == _selectedTransactionType)
        .toList();

    // Validate selectedCategory
    if (!_filteredCategories.contains(_selectedCategory)) {
      _selectedCategory = _filteredCategories.isNotEmpty
          ? _filteredCategories.first
          : null;
    }
  }

  void _safeUpdateSelectedCategory() {
    if (!mounted) return; // Thêm dòng này

    setState(() {
      if (_filteredCategories.isEmpty) {
        _selectedCategory = null;
        return;
      }

      final bool stillExists =
          _selectedCategory != null &&
          _filteredCategories.any(
            (cat) => cat.categoryId == _selectedCategory!.categoryId,
          );

      if (!stillExists) {
        _selectedCategory = _filteredCategories.first;
      }
    });
  }

  Future<void> _deleteCategory(Category category) async {
    if (category.isSystemDefault) {
      Fluttertoast.showToast(msg: "Không thể xóa danh mục hệ thống mặc định.");
      return;
    }

    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xác nhận xóa'),
        content: Text(
          'Bạn có chắc muốn xóa danh mục "${category.name}"?\n'
          'Các giao dịch cũ vẫn giữ nhãn này.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Xóa', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    try {
      await FirebaseService.deleteCategory(category.categoryId);

      if (!mounted) return;

      await _fetchCategories();

      if (!mounted) return;

      setState(() {
        _filterCategories();

        // Reset selectedCategory nếu nó bị xóa
        if (_selectedCategory?.categoryId == category.categoryId) {
          _selectedCategory = _filteredCategories.isNotEmpty
              ? _filteredCategories.first
              : null;
        }

        // Tăng key để force rebuild dropdown
        _dropdownKey++;
      });

      Fluttertoast.showToast(
        msg: "Đã xóa danh mục!",
        backgroundColor: Colors.green,
      );
    } catch (e) {
      if (!mounted) return;

      Fluttertoast.showToast(msg: "Lỗi xóa: $e", backgroundColor: Colors.red);
    }
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE3F2FD),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Thêm giao dịch",
          style: TextStyle(color: Colors.black, fontSize: 16),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Text(
              amount,
              style: const TextStyle(
                fontSize: 40,
                fontWeight: FontWeight.bold,
                color: Colors.blue,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _selectedTransactionType = 'expense';
                        _filterCategories(); // Đã có _safeUpdateSelectedCategory() bên trong
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _selectedTransactionType == 'expense'
                          ? Colors.redAccent
                          : Colors.grey,
                    ),
                    child: const Text(
                      'Chi tiêu',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _selectedTransactionType = 'income';
                        _filterCategories();
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _selectedTransactionType == 'income'
                          ? Colors.green
                          : Colors.grey,
                    ),
                    child: const Text(
                      'Thu nhập',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ),
          _buildCategoryInputRow("Chọn hạng mục"),
          _buildNoteInputRow(Icons.notes, "Viết ghi chú"),
          _buildDateInputRow(Icons.calendar_today, _selectedDate),
          _buildInputRow(Icons.wallet, "Tiền mặt"),
          const Spacer(),
          Container(
            color: Colors.white,
            child: Column(
              children: [
                _buildNumpadRow(["1", "2", "3", "delete"]),
                _buildNumpadRow(["4", "5", "6", "+"]),
                _buildNumpadRow(["7", "8", "9", "-"]),
                _buildNumpadRow([".", "0", "000", "done"]),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryInputRow(String hint) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<Category?>(
                key: _dropdownButtonKey, // Sử dụng GlobalKey
                isExpanded: true,
                value: _filteredCategories.contains(_selectedCategory)
                    ? _selectedCategory
                    : null,
                hint: Text(hint, style: const TextStyle(color: Colors.grey)),
                items: _filteredCategories.map<DropdownMenuItem<Category?>>((
                  category,
                ) {
                  return DropdownMenuItem<Category?>(
                    value: category,
                    child: Row(
                      children: [
                        Icon(category.icon, color: category.color),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            category.name,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (Category? newValue) {
                  if (mounted) {
                    setState(() => _selectedCategory = newValue);
                  }
                },
              ),
            ),
          ),
          // Nút xóa category đã chọn - Ở NGOÀI dropdown
          if (_selectedCategory != null && !_selectedCategory!.isSystemDefault)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              onPressed: () {
                _showDeleteCategoryDialog(_selectedCategory!);
              },
              tooltip: 'Xóa danh mục',
            ),
          // Nút thêm category mới
          IconButton(
            icon: const Icon(Icons.add_circle_outline, color: Colors.blue),
            onPressed: () async {
              await showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Tạo danh mục mới'),
                  content: AddCategoryScreen(
                    initialType: _selectedTransactionType,
                    onSaved: () async {
                      await _fetchCategories();

                      if (!mounted) return;

                      setState(() {
                        _filterCategories();

                        if (_filteredCategories.isNotEmpty) {
                          _selectedCategory = _filteredCategories.last;
                        }
                      });
                    },
                  ),
                ),
              );
            },
            tooltip: 'Thêm danh mục mới',
          ),
        ],
      ),
    );
  }

  // Hàm hiển thị dialog xóa
  Future<void> _showDeleteCategoryDialog(Category category) async {
    if (!mounted) return;

    final bool? confirm = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Xác nhận xóa'),
        content: Text(
          'Bạn có chắc muốn xóa danh mục "${category.name}"?\n'
          'Các giao dịch cũ vẫn giữ nhãn này.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      await _performDeleteCategory(category);
    }
  }

  // Hàm thực hiện xóa category
  Future<void> _performDeleteCategory(Category category) async {
    if (!mounted) return;

    try {
      // Hiển thị loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      await FirebaseService.deleteCategory(category.categoryId);

      if (!mounted) return;

      // Đóng loading dialog
      Navigator.of(context).pop();

      await _fetchCategories();

      if (!mounted) return;

      setState(() {
        _filterCategories();

        // Reset selectedCategory nếu nó bị xóa
        if (_selectedCategory?.categoryId == category.categoryId) {
          _selectedCategory = _filteredCategories.isNotEmpty
              ? _filteredCategories.first
              : null;
        }
      });

      Fluttertoast.showToast(
        msg: "Đã xóa danh mục!",
        backgroundColor: Colors.green,
      );
    } catch (e) {
      if (!mounted) return;

      // Đóng loading dialog nếu có lỗi
      Navigator.of(context).pop();

      Fluttertoast.showToast(msg: "Lỗi xóa: $e", backgroundColor: Colors.red);
    }
  }

  Widget _buildNoteInputRow(IconData icon, String hint) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.grey),
          const SizedBox(width: 15),
          Expanded(
            child: TextField(
              controller: _noteController,
              decoration: InputDecoration(
                hintText: hint,
                border: InputBorder.none,
                hintStyle: const TextStyle(color: Colors.grey),
              ),
              style: const TextStyle(color: Colors.black),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateInputRow(IconData icon, String dateText) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.grey),
          const SizedBox(width: 15),
          Expanded(
            child: GestureDetector(
              onTap: () async {
                DateTime? pickedDate = await showDatePicker(
                  context: context,
                  initialDate: DateTime.now(),
                  firstDate: DateTime(2000),
                  lastDate: DateTime(2101),
                );
                if (pickedDate != null) {
                  setState(() {
                    _selectedDate =
                        "${pickedDate.day}/${pickedDate.month}/${pickedDate.year}";
                  });
                }
              },
              child: Text(dateText, style: const TextStyle(color: Colors.grey)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputRow(IconData icon, String hint) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.grey),
          const SizedBox(width: 15),
          Text(hint, style: const TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildNumpadRow(List<String> keys) {
    return Row(
      children: keys.map((key) {
        return Expanded(
          child: InkWell(
            onTap: () => _handleKeyPress(key),
            child: Container(
              height: 60,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade100),
              ),
              child: Center(child: _getIconOrText(key)),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _getIconOrText(String key) {
    if (key == "delete") return const Icon(Icons.backspace_outlined);
    if (key == "done")
      return const Icon(Icons.check, color: Colors.green, size: 30);
    return Text(
      key,
      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w500),
    );
  }

  void _handleKeyPress(String key) {
    if (!mounted) return; // Thêm dòng này

    setState(() {
      if (key == "delete") {
        if (amount.length > 1) {
          amount = amount.substring(0, amount.length - 1);
        } else {
          amount = "0";
        }
      } else if (key == "done") {
        _saveTransaction();
      } else {
        if (amount == "0") {
          amount = key;
        } else {
          amount += key;
        }
      }
    });
  }

  Future<void> _saveTransaction() async {
    if (_currentUser == null) {
      Fluttertoast.showToast(
        msg: "Bạn chưa đăng nhập. Vui lòng đăng nhập để thêm giao dịch.",
        toastLength: Toast.LENGTH_LONG,
        gravity: ToastGravity.TOP,
        backgroundColor: Colors.red,
      );
      return;
    }
    if (_selectedCategory == null) {
      Fluttertoast.showToast(
        msg: "Vui lòng chọn một hạng mục.",
        toastLength: Toast.LENGTH_LONG,
        gravity: ToastGravity.TOP,
        backgroundColor: Colors.red,
      );
      return;
    }
    if (double.tryParse(amount) == null || double.parse(amount) <= 0) {
      Fluttertoast.showToast(
        msg: "Vui lòng nhập số tiền hợp lệ.",
        toastLength: Toast.LENGTH_LONG,
        gravity: ToastGravity.TOP,
        backgroundColor: Colors.red,
      );
      return;
    }

    try {
      DateTime selectedDateTime;
      if (_selectedDate == "Hôm nay") {
        selectedDateTime = DateTime.now();
      } else {
        List<String> dateParts = _selectedDate.split('/');
        if (dateParts.length == 3) {
          selectedDateTime = DateTime(
            int.parse(dateParts[2]),
            int.parse(dateParts[1]),
            int.parse(dateParts[0]),
          );
        } else {
          selectedDateTime = DateTime.now();
        }
      }

      final newTransaction = Transaction(
        transactionId: '',
        userId: _currentUser!.uid,
        categoryId: _selectedCategory!.categoryId,
        type: _selectedTransactionType,
        amount: double.parse(amount),
        note: _noteController.text.trim(),
        date: selectedDateTime.millisecondsSinceEpoch,
        createdAt: DateTime.now().millisecondsSinceEpoch,
      );

      await FirebaseService.addTransaction(newTransaction);

      Fluttertoast.showToast(
        msg: "Giao dịch đã được thêm thành công!",
        toastLength: Toast.LENGTH_LONG,
        gravity: ToastGravity.TOP,
        backgroundColor: Colors.green,
      );
      Navigator.pop(context);
    } catch (e) {
      Fluttertoast.showToast(
        msg: "Lỗi khi thêm giao dịch: $e",
        toastLength: Toast.LENGTH_LONG,
        gravity: ToastGravity.TOP,
        backgroundColor: Colors.red,
      );
    }
  }
}
