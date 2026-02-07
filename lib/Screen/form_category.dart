// Nội dung file add_category.dart hoặc form_category.dart của bạn
// (mình giả sử giống phiên bản trước – bạn thay thế nếu khác)

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:spend_wisely/Function/fire_services.dart';
import 'package:spend_wisely/Function/models.dart';

class AddCategoryScreen extends StatefulWidget {
  final String initialType;
  final VoidCallback onSaved;

  const AddCategoryScreen({
    super.key,
    required this.initialType,
    required this.onSaved,
  });

  @override
  State<AddCategoryScreen> createState() => _AddCategoryScreenState();
}

class _AddCategoryScreenState extends State<AddCategoryScreen> {
  final _nameController = TextEditingController();
  final String _selectedIconCode = 'category';
  late String _selectedType;
  Color _selectedColor = Colors.grey[300]!;
  User? _currentUser;

  @override
  void initState() {
    super.initState();
    _currentUser = FirebaseAuth.instance.currentUser;
    _selectedType = widget.initialType;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _showColorPicker() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Chọn màu danh mục'),
          content: SingleChildScrollView(
            child: ColorPicker(
              pickerColor: _selectedColor,
              onColorChanged: (color) => setState(() => _selectedColor = color),
              showLabel: true,
              pickerAreaHeightPercent: 0.8,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Hủy'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Xong'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _saveCategory() async {
    if (_currentUser == null) {
      Fluttertoast.showToast(msg: "Bạn cần đăng nhập để tạo danh mục.");
      return;
    }
    if (_nameController.text.trim().isEmpty) {
      Fluttertoast.showToast(msg: "Vui lòng nhập tên danh mục.");
      return;
    }

    try {
      final newCategory = Category(
        categoryId: '',
        name: _nameController.text.trim(),
        iconCode: _selectedIconCode,
        colorHex:
            '#${_selectedColor.value.toRadixString(16).padLeft(8, '0').substring(2)}',
        type: _selectedType,
        isSystemDefault: false,
        createdByUserId: _currentUser!.uid,
      );

      await FirebaseService.addCategory(newCategory);

      Fluttertoast.showToast(
        msg: "Danh mục \"${newCategory.name}\" đã được tạo!",
        backgroundColor: Colors.green,
      );

      widget.onSaved();
      Navigator.pop(context);
    } catch (e) {
      Fluttertoast.showToast(msg: "Lỗi khi tạo danh mục: $e");
    }
  }

  Color _getBackgroundColor() {
    return _selectedType == 'expense' ? Colors.red[50]! : Colors.green[50]!;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _getBackgroundColor(),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _selectedType == 'expense' ? 'Chi tiêu' : 'Thu nhập',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: _selectedType == 'expense'
                      ? Colors.red[800]
                      : Colors.green[800],
                ),
              ),
              const SizedBox(height: 24),
              Text('Tên danh mục', style: _labelStyle()),
              const SizedBox(height: 8),
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  filled: true,
                  fillColor: Colors.white,
                ),
              ),
              const SizedBox(height: 20),
              Text('Màu sắc danh mục', style: _labelStyle()),
              const SizedBox(height: 8),
              Row(
                children: [
                  CircleAvatar(radius: 24, backgroundColor: _selectedColor),
                  const SizedBox(width: 16),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.palette, size: 20),
                    label: const Text('Chọn màu'),
                    onPressed: _showColorPicker,
                  ),
                ],
              ),
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Hủy'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.save),
                    label: const Text('Lưu danh mục'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _selectedType == 'expense'
                          ? Colors.red[700]
                          : Colors.green[700],
                      foregroundColor: Colors.white,
                    ),
                    onPressed: _saveCategory,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  TextStyle _labelStyle() {
    return const TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w600,
      color: Colors.black87,
    );
  }
}
