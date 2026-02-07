// Tạo file mới: manage_categories.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:spend_wisely/Function/fire_services.dart';
import 'package:spend_wisely/Function/models.dart';
import 'package:spend_wisely/Screen/form_category.dart'; // Nếu cần thêm mới từ đây

class ManageCategoriesScreen extends StatefulWidget {
  @override
  _ManageCategoriesScreenState createState() => _ManageCategoriesScreenState();
}

class _ManageCategoriesScreenState extends State<ManageCategoriesScreen> {
  List<Category> _categories = [];
  User? _currentUser;

  @override
  void initState() {
    super.initState();
    _currentUser = FirebaseAuth.instance.currentUser;
    _fetchCategories();
  }

  Future<void> _fetchCategories() async {
    try {
      List<Category> fetchedCategories =
          await FirebaseService.getAllCategories();
      // Lọc chỉ danh mục của user hiện tại hoặc hệ thống (nhưng xóa chỉ user-created)
      setState(() {
        _categories = fetchedCategories.where((cat) {
          return cat.isSystemDefault ||
              cat.createdByUserId == _currentUser?.uid;
        }).toList();
      });
    } catch (e) {
      Fluttertoast.showToast(msg: "Lỗi tải danh mục: $e");
    }
  }

  Future<void> _deleteCategory(Category category) async {
    if (category.isSystemDefault) {
      Fluttertoast.showToast(msg: "Không thể xóa danh mục hệ thống.");
      return;
    }
    if (category.createdByUserId != _currentUser?.uid) {
      Fluttertoast.showToast(msg: "Bạn không có quyền xóa danh mục này.");
      return;
    }

    try {
      // Kiểm tra nếu category đang được sử dụng trong transactions (tùy chọn, để tránh xóa nếu đang dùng)
      List<Transaction> transactions = await FirebaseService.getTransactions(
        _currentUser!.uid,
        'all',
      );
      bool isUsed = transactions.any(
        (tx) => tx.categoryId == category.categoryId,
      );
      if (isUsed) {
        Fluttertoast.showToast(
          msg: "Danh mục đang được sử dụng trong giao dịch, không thể xóa.",
        );
        return;
      }

      await FirebaseService.deleteCategory(category.categoryId);
      Fluttertoast.showToast(
        msg: "Danh mục đã được xóa thành công!",
        backgroundColor: Colors.green,
      );
      _fetchCategories(); // Refresh list
    } catch (e) {
      Fluttertoast.showToast(msg: "Lỗi khi xóa danh mục: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Quản lý danh mục"),
        actions: [
          IconButton(
            icon: Icon(Icons.add),
            onPressed: () async {
              // Mở dialog thêm mới, ví dụ cho expense, bạn có thể thêm lựa chọn type
              await showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: Text('Tạo danh mục mới'),
                  content: AddCategoryScreen(
                    initialType: 'expense', // Hoặc cho chọn type
                    onSaved: _fetchCategories,
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: ListView.builder(
        itemCount: _categories.length,
        itemBuilder: (context, index) {
          final category = _categories[index];
          return ListTile(
            leading: Icon(
              Icons.category, // Hoặc parse icon từ category.icon
              color: Color(
                int.parse(category.colorHex.replaceFirst('#', '0xff')),
              ),
            ),
            title: Text(category.name),
            subtitle: Text(
              category.type == 'expense' ? 'Chi tiêu' : 'Thu nhập',
            ),
            trailing: category.isSystemDefault
                ? null
                : IconButton(
                    icon: Icon(Icons.delete, color: Colors.red),
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: Text('Xác nhận xóa'),
                          content: Text(
                            'Bạn có chắc muốn xóa danh mục "${category.name}"?',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: Text('Hủy'),
                            ),
                            ElevatedButton(
                              onPressed: () {
                                Navigator.pop(context);
                                _deleteCategory(category);
                              },
                              child: Text('Xóa'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          );
        },
      ),
    );
  }
}
