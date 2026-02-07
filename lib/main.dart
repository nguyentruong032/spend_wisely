import 'package:flutter/material.dart';
import 'Screen/login.dart';
import 'Screen/register.dart';
import 'Function/fire_services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await dotenv.load(fileName: ".env");
    await FirebaseService.initializeFirebase();
    runApp(const MainApp());
  } catch (e) {
    print("Lỗi khởi tạo: $e");
  }
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      initialRoute: '/login',
      routes: {
        '/login': (context) => LoginScreen(),
        '/register': (context) => RegisterScreen(),
      },
    );
  }
}
