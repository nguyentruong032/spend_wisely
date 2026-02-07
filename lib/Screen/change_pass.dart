import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fluttertoast/fluttertoast.dart';
import '../Function/fire_services.dart';

class ChangePasswordScreen extends StatefulWidget {
  @override
  _ChangePasswordScreenState createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _emailController = TextEditingController();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  bool _isLoading = false; // Trạng thái chờ xử lý

  @override
  void initState() {
    super.initState();
    _emailController.text = FirebaseAuth.instance.currentUser?.email ?? "";
  }

  @override
  void dispose() {
    _emailController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    super.dispose();
  }

  // Hàm xử lý chính
  Future<void> _handleUpdatePassword() async {
    String currentPassword = _currentPasswordController.text.trim();
    String newPassword = _newPasswordController.text.trim();

    // Validate dữ liệu đầu vào
    if (currentPassword.isEmpty || newPassword.isEmpty) {
      _showToast("Vui lòng nhập đầy đủ thông tin.", Colors.red);
      return;
    }

    if (newPassword.length < 6) {
      _showToast("Mật khẩu mới phải từ 6 ký tự trở lên.", Colors.red);
      return;
    }

    setState(() => _isLoading = true);

    try {
      // 1. Thực hiện đổi mật khẩu
      await FirebaseService.updatePassword(currentPassword, newPassword);

      // 2. Hiển thị thông báo ngay lập tức
      _showToast("Đổi mật khẩu thành công!", Colors.green);

      // 3. Đợi một chút ngắn để Toast kịp hiển thị và hệ thống ổn định
      await Future.delayed(Duration(milliseconds: 500));

      // 4. Kiểm tra xem màn hình còn tồn tại không trước khi chuyển trang
      if (!mounted) return;

      // 5. Đăng xuất và xóa sạch Stack màn hình
      // Lưu ý: Gọi signOut() ngay trong lệnh điều hướng để tránh xung đột dữ liệu
      await FirebaseAuth.instance.signOut();
      if (mounted) {
        Navigator.of(
          context,
        ).pushNamedAndRemoveUntil('/login', (route) => false);
      }
    } catch (e) {
      // Kiểm tra nếu lỗi chỉ là do việc đăng xuất làm gián đoạn thì bỏ qua
      if (e.toString().contains("permission-denied") ||
          e.toString().contains("network-error")) {
        return;
      }
      print("DEBUG ERROR: $e");
      _showToast("Lỗi: ${e.toString()}", Colors.red);
    }
  }

  // Hàm hiển thị thông báo nhanh
  void _showToast(String msg, Color color) {
    Fluttertoast.showToast(
      msg: msg,
      toastLength: Toast.LENGTH_LONG,
      gravity: ToastGravity.TOP,
      backgroundColor: color,
      textColor: Colors.white,
    );
  }

  // Phân tích lỗi Firebase
  String _getFirebaseErrorMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'wrong-password':
        return 'Mật khẩu hiện tại không chính xác.';
      case 'too-many-requests':
        return 'Quá nhiều yêu cầu. Vui lòng thử lại sau.';
      case 'requires-recent-login':
        return 'Thao tác yêu cầu đăng nhập lại trước khi thực hiện.';
      case 'weak-password':
        return 'Mật khẩu mới quá yếu.';
      default:
        return e.message ?? 'Lỗi xác thực không xác định.';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFE3F2FD),
      appBar: AppBar(
        title: Text("Đổi Mật Khẩu", style: TextStyle(color: Colors.black87)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        // Dùng cái này để không bị lỗi tràn màn hình khi hiện bàn phím
        padding: const EdgeInsets.all(30.0),
        child: Column(
          children: [
            CircleAvatar(
              radius: 45,
              backgroundColor: Colors.blue.shade100,
              child: Icon(
                Icons.lock_reset,
                size: 50,
                color: Colors.blue.shade700,
              ),
            ),
            SizedBox(height: 30),

            _buildInputField(
              controller: _emailController,
              hintText: "Email",
              icon: Icons.email,
              readOnly: true,
            ),
            SizedBox(height: 20),

            _buildInputField(
              controller: _currentPasswordController,
              hintText: "Mật khẩu hiện tại",
              icon: Icons.lock_outline,
              isPassword: true,
            ),
            SizedBox(height: 20),

            _buildInputField(
              controller: _newPasswordController,
              hintText: "Mật khẩu mới",
              icon: Icons.vpn_key_outlined,
              isPassword: true,
            ),
            SizedBox(height: 40),

            ElevatedButton(
              onPressed: _isLoading ? null : _handleUpdatePassword,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                minimumSize: Size(double.infinity, 55),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
                elevation: 2,
              ),
              child: _isLoading
                  ? CircularProgressIndicator(color: Colors.white)
                  : Text(
                      "CẬP NHẬT MẬT KHẨU",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String hintText,
    required IconData icon,
    bool isPassword = false,
    bool readOnly = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: readOnly ? Colors.grey.shade100 : Colors.white,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        obscureText: isPassword,
        readOnly: readOnly,
        style: TextStyle(color: readOnly ? Colors.grey : Colors.black87),
        decoration: InputDecoration(
          hintText: hintText,
          prefixIcon: Icon(icon, color: Colors.blue),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(vertical: 18, horizontal: 20),
        ),
      ),
    );
  }
}
