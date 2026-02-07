import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fluttertoast/fluttertoast.dart';
import '../Function/fire_services.dart';
import 'login.dart';

class DeleteAccountScreen extends StatefulWidget {
  @override
  _DeleteAccountScreenState createState() => _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends State<DeleteAccountScreen> {
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFE3F2FD),
      appBar: AppBar(
        title: Text("XÓA TÀI KHOẢN"),
        backgroundColor: Colors.transparent,
      ),
      body: Padding(
        padding: const EdgeInsets.all(25.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "XÓA TÀI KHOẢN SẼ",
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey),
            ),
            SizedBox(height: 20),
            _buildWarningItem("Không thể khôi phục dữ liệu"),
            SizedBox(height: 10),
            _buildWarningItem("Xóa toàn bộ thông tin tài khoản"),
            Spacer(),
            Center(
              child: ElevatedButton(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (BuildContext context) {
                      return AlertDialog(
                        title: Text("Xác nhận xóa tài khoản"),
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              "Bạn có chắc chắn muốn xóa tài khoản này không? Hành động này không thể hoàn tác.",
                            ),
                            SizedBox(height: 20),
                            TextField(
                              controller: _passwordController,
                              obscureText: true,
                              decoration: InputDecoration(
                                hintText: "Nhập mật khẩu hiện tại",
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ],
                        ),
                        actions: [
                          TextButton(
                            onPressed: () {
                              Navigator.of(context).pop(); // Đóng dialog
                            },
                            child: Text("Hủy"),
                          ),
                          ElevatedButton(
                            onPressed: () async {
                              // Navigator.of(context).pop(); // Đóng dialog ngay lập tức
                              if (_passwordController.text.isEmpty) {
                                Fluttertoast.showToast(
                                  msg:
                                      "Vui lòng nhập mật khẩu hiện tại để xác nhận.",
                                  toastLength: Toast.LENGTH_LONG,
                                  gravity: ToastGravity.TOP,
                                  backgroundColor: Colors.red,
                                  textColor: Colors.white,
                                );
                                return;
                              }

                              try {
                                await FirebaseService.deleteUserAccount(
                                  _passwordController.text,
                                );
                                Fluttertoast.showToast(
                                  msg: "Tài khoản đã được xóa thành công.",
                                  toastLength: Toast.LENGTH_LONG,
                                  gravity: ToastGravity.TOP,
                                  backgroundColor: Colors.green,
                                  textColor: Colors.white,
                                );
                                Navigator.of(context).pushAndRemoveUntil(
                                  MaterialPageRoute(
                                    builder: (context) => LoginScreen(),
                                  ),
                                  (Route<dynamic> route) => false,
                                );
                              } on FirebaseAuthException catch (e) {
                                String message;
                                if (e.code == 'wrong-password') {
                                  message =
                                      'Mật khẩu hiện tại không chính xác.';
                                } else if (e.code == 'requires-recent-login') {
                                  message =
                                      'Thao tác này yêu cầu đăng nhập lại gần đây. Vui lòng đăng nhập lại.';
                                } else {
                                  message =
                                      e.message ??
                                      'Đã xảy ra lỗi Firebase không xác định.';
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
                                  msg:
                                      'Đã xảy ra lỗi không mong muốn: ${e.toString()}',
                                  toastLength: Toast.LENGTH_LONG,
                                  gravity: ToastGravity.TOP,
                                  backgroundColor: Colors.red,
                                  textColor: Colors.white,
                                );
                              }
                            },
                            child: Text("Xóa"),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                            ),
                          ),
                        ],
                      );
                    },
                  );
                },
                child: Text(
                  "XÓA TÀI KHOẢN",
                  style: TextStyle(color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  shape: StadiumBorder(),
                  padding: EdgeInsets.symmetric(horizontal: 50, vertical: 15),
                ),
              ),
            ),
            SizedBox(height: 50),
          ],
        ),
      ),
    );
  }

  Widget _buildWarningItem(String text) {
    return Row(
      children: [
        Icon(Icons.close, color: Colors.red),
        SizedBox(width: 10),
        Text(text, style: TextStyle(fontSize: 14)),
      ],
    );
  }
}
