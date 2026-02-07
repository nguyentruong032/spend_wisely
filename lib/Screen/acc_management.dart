import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../Function/fire_services.dart'; // Đảm bảo đúng đường dẫn tới file FirebaseService của bạn
import 'change_pass.dart';
import 'delete_acc.dart';
import 'login.dart';

class AccountManagementScreen extends StatefulWidget {
  @override
  _AccountManagementScreenState createState() =>
      _AccountManagementScreenState();
}

class _AccountManagementScreenState extends State<AccountManagementScreen> {
  String? _email;
  String _username = "Đang tải...";
  final User? _currentUser = FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  // Lấy dữ liệu từ Auth và Realtime Database
  Future<void> _loadUserData() async {
    if (_currentUser != null) {
      setState(() {
        _email = _currentUser!.email;
      });

      // Gọi hàm getUserName đã có trong FirebaseService của bạn
      String name = await FirebaseService.getUserName(_currentUser!.uid);

      if (mounted) {
        setState(() {
          _username = name;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFE3F2FD),
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.black54),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "QUẢN LÝ TÀI KHOẢN",
          style: TextStyle(
            color: Colors.black54,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Center(
        child: Column(
          children: [
            SizedBox(height: 20),
            // Avatar Profile
            Container(
              height: 100,
              width: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(colors: [Colors.cyan, Colors.blue]),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 10,
                    offset: Offset(0, 5),
                  ),
                ],
              ),
              child: Icon(Icons.person, size: 60, color: Colors.white),
            ),
            SizedBox(height: 15),

            // HIỂN THỊ EMAIL (Lấy từ Firebase Auth)
            Text(
              _email ?? "Không có email",
              style: TextStyle(
                color: Colors.black87,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),

            // HIỂN THỊ USERNAME (Lấy từ Realtime Database)
            Text(
              _username,
              style: TextStyle(color: Colors.black54, fontSize: 14),
            ),

            SizedBox(height: 40),

            // Các nút lựa chọn
            _buildOptionButton(
              context,
              Icons.lock_outline,
              "Thay đổi mật khẩu",
              () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ChangePasswordScreen(),
                  ),
                );
              },
            ),
            SizedBox(height: 15),
            _buildOptionButton(
              context,
              Icons.delete_forever_outlined,
              "Xóa tài khoản",
              () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => DeleteAccountScreen(),
                  ),
                );
              },
            ),

            Spacer(),

            // Nút Đăng xuất
            ElevatedButton.icon(
              onPressed: () async {
                await FirebaseAuth.instance.signOut();
                if (mounted) {
                  Navigator.of(
                    context,
                  ).pushNamedAndRemoveUntil('/login', (route) => false);
                }
              },
              icon: Icon(Icons.logout),
              label: Text("ĐĂNG XUẤT"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF1E88E5),
                foregroundColor: Colors.white,
                shape: StadiumBorder(),
                padding: EdgeInsets.symmetric(horizontal: 40, vertical: 12),
                elevation: 3,
              ),
            ),
            SizedBox(height: 50),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionButton(
    BuildContext context,
    IconData icon,
    String title,
    VoidCallback onTap,
  ) {
    return Container(
      width: MediaQuery.of(context).size.width * 0.85,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 5,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        onTap: onTap,
        leading: Icon(icon, color: Colors.blue.shade700),
        title: Text(
          title,
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
        ),
        trailing: Icon(Icons.chevron_right, color: Colors.grey),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      ),
    );
  }
}
