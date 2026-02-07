Spend Wisely 💰
Spend Wisely là một ứng dụng quản lý chi tiêu cá nhân được xây dựng bằng Flutter và Firebase. Ứng dụng giúp người dùng theo dõi các khoản thu chi một cách khoa học, trực quan và bảo mật.

🚀 Tính năng chính
Xác thực người dùng: Đăng ký và đăng nhập bảo mật qua Firebase Authentication.

Quản lý chi tiêu: Ghi lại các giao dịch thu nhập và chi phí hàng ngày.

Bảo mật thông tin: Sử dụng biến môi trường (.env) để bảo vệ các API Key nhạy cảm của Firebase.

Đa nền tảng: Hỗ trợ tốt trên Android, iOS và tiềm năng mở rộng sang Web/Windows.

🛠 Công nghệ sử dụng
Language: Dart

Framework: Flutter

Backend: Firebase (Auth, Firestore)

Security: flutter_dotenv để quản lý Secrets.

📦 Hướng dẫn cài đặt
Để chạy dự án này trên môi trường local, bạn cần thực hiện các bước sau:

1. Clone dự án
Bash
git clone https://github.com/nguyentruong032/spend_wisely.git
cd spend_wisely
2. Thiết lập biến môi trường (.env)
Dự án này sử dụng kiến trúc bảo mật không lưu API Key trực tiếp trong mã nguồn. Bạn cần tạo một tệp .env tại thư mục gốc và điền các thông số từ Firebase Console của bạn:

Plaintext
# Android
APIKEY_ANDROID=...
APP_ID=...

# iOS & macOS
APIKEY_IOS_MACOS=...

# Web & Windows
APIKEY_WINDOW_WEB=...

# Chung
MESS_SENDER_ID=...
PROJECT_ID=...
DATABASEURL=...
STORAGE_BUCKET=...
IOS_BUNDLE=...
(Bạn có thể tham khảo tệp .env.example trong repo để biết danh sách các biến cần thiết).

3. Cài đặt các gói phụ thuộc
Bash
flutter pub get
4. Chạy ứng dụng
Bash
flutter run
🏗 Cấu trúc thư mục
Dự án được tổ chức theo cấu trúc rõ ràng, dễ bảo trì:

lib/Screen/: Chứa giao diện người dùng (Login, Register, Dashboard...).

lib/Function/: Chứa các logic xử lý dịch vụ (Firebase services, helper functions...).

lib/firebase_options.dart: Cấu hình nền tảng Firebase (đã được tối ưu để đọc từ .env).

assets/: Chứa hình ảnh và tệp .env.

🛡 Bảo mật (Security)
Trong môi trường làm việc chuyên nghiệp, chúng tôi cam kết bảo mật thông tin:

File .env chứa các thông tin nhạy cảm đã được thêm vào .gitignore.

Tiến trình khởi tạo được thực hiện tuần tự trong main.dart để đảm bảo các biến cấu hình được nạp đầy đủ trước khi ứng dụng chạy.

👨‍💻 Tác giả
Nguyễn Trường - nguyentruong032
