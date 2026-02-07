import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart'; // Import Firebase Realtime Database
import 'package:fluttertoast/fluttertoast.dart'; // Import Fluttertoast
import 'login.dart';

class RegisterScreen extends StatefulWidget {
  @override
  _RegisterScreenState createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _emailController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFE3F2FD), // Nền xanh nhạt đồng bộ
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 30.0),
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Tiêu đề Register
                Text(
                  'Đăng ký',
                  style: TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1976D2),
                  ),
                ),
                SizedBox(height: 50),

                // Trường Email
                _buildInputField(
                  controller: _emailController,
                  hintText: 'Email',
                  icon: Icons.email,
                ),
                SizedBox(height: 20),

                // Trường Username
                _buildInputField(
                  controller: _usernameController,
                  hintText: 'Tên người dùng',
                  icon: Icons.person,
                ),
                SizedBox(height: 20),

                // Trường Password
                _buildInputField(
                  controller: _passwordController,
                  hintText: 'Mật khẩu',
                  icon: Icons.lock,
                  isPassword: true,
                ),
                SizedBox(height: 20),

                // Trường Confirm Password
                _buildInputField(
                  controller: _confirmPasswordController,
                  hintText: 'Xác nhận mật khẩu',
                  icon: Icons.lock_outline,
                  isPassword: true,
                ),
                SizedBox(height: 40),

                // Nút SEND (Đăng ký)
                SizedBox(
                  width: 150, // Độ rộng nút theo tỉ lệ thiết kế
                  child: ElevatedButton(
                    onPressed: () async {
                      if (_passwordController.text !=
                          _confirmPasswordController.text) {
                        Fluttertoast.showToast(
                          msg: "Mật khẩu không khớp!",
                          toastLength: Toast.LENGTH_LONG,
                          gravity: ToastGravity.TOP,
                          backgroundColor: Colors.red,
                          textColor: Colors.white,
                        );
                        return;
                      }
                      try {
                        await FirebaseAuth.instance
                            .createUserWithEmailAndPassword(
                              email: _emailController.text,
                              password: _passwordController.text,
                            );
                        // Store additional user data in Realtime Database
                        User? user = FirebaseAuth.instance.currentUser;
                        if (user != null) {
                          DatabaseReference usersRef = FirebaseDatabase.instance
                              .ref('users');
                          await usersRef.child(user.uid).set({
                            'uid': user.uid,
                            'email': _emailController.text,
                            'username': _usernameController.text,
                            'createdAt':
                                ServerValue.timestamp, // Use server timestamp
                          });
                        }
                        Fluttertoast.showToast(
                          msg: "Đăng ký thành công! Vui lòng đăng nhập.",
                          toastLength: Toast.LENGTH_LONG,
                          gravity: ToastGravity.TOP,
                          backgroundColor: Colors.green,
                          textColor: Colors.white,
                        );
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (context) => LoginScreen(),
                          ),
                        );
                      } on FirebaseAuthException catch (e) {
                        String message;
                        if (e.code == 'weak-password') {
                          message = 'Mật khẩu quá yếu.';
                        } else if (e.code == 'email-already-in-use') {
                          message = 'Tài khoản đã tồn tại với email này.';
                        } else {
                          message =
                              e.message ?? 'Đã xảy ra lỗi không xác định.';
                        }
                        Fluttertoast.showToast(
                          msg: message,
                          toastLength: Toast.LENGTH_LONG,
                          gravity: ToastGravity.TOP,
                          backgroundColor: Colors.red,
                          textColor: Colors.white,
                        );
                      } catch (e) {
                        Fluttertoast.showToast(
                          msg: 'Đã xảy ra lỗi không mong muốn.',
                          toastLength: Toast.LENGTH_LONG,
                          gravity: ToastGravity.TOP,
                          backgroundColor: Colors.red,
                          textColor: Colors.white,
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF1E88E5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      padding: EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: Text(
                      'GỬI',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                ),

                // Nút quay lại Login (Bổ sung thêm để tiện sử dụng)
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text("Đã có tài khoản? Đăng nhập"),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Widget dùng chung cho các ô nhập liệu (Đồng nhất với Login)
  Widget _buildInputField({
    required TextEditingController controller,
    required String hintText,
    required IconData icon,
    bool isPassword = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(
          20,
        ), // Bo góc nhẹ hơn hoặc theo thiết kế
        border: Border.all(color: Colors.blue.shade100),
        boxShadow: [
          BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      child: TextField(
        controller: controller,
        obscureText: isPassword,
        style: TextStyle(fontSize: 14),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
          prefixIcon: Icon(icon, color: Colors.blue, size: 28),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(vertical: 18),
        ),
      ),
    );
  }
}
