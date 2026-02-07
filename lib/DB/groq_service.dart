import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:spend_wisely/Function/models.dart';

class GroqService {
  static String _apiKey = dotenv.get('GROQ_API_KEY', fallback: '');

  static const String _baseUrl = 'https://api.groq.com/openai/v1';

  /// Hàm cũ - giữ nguyên để tương thích ngược
  static Future<String> sendMessage(
    String userMessage,
    List<ChatMessage> chatHistory,
  ) async {
    if (_apiKey.trim().isEmpty) {
      throw Exception('Groq API key chưa được cấu hình.');
    }

    try {
      final List<Map<String, String>> messages = [];

      // System prompt mặc định (không có dữ liệu cá nhân)
      messages.add({
        'role': 'system',
        'content': '''Bạn là một trợ lý AI chuyên về quản lý tài chính cá nhân. 
Bạn giúp người dùng:
- Tư vấn về cách tiết kiệm tiền
- Phân tích chi tiêu và thu nhập
- Đưa ra gợi ý về ngân sách
- Trả lời các câu hỏi về tài chính cá nhân

Hãy trả lời một cách thân thiện, dễ hiểu và bằng tiếng Việt.''',
      });

      // Lấy 10 tin nhắn gần nhất (giữ nguyên logic cũ)
      final recentHistory = chatHistory.length > 10
          ? chatHistory.sublist(chatHistory.length - 10)
          : chatHistory;

      for (var msg in recentHistory) {
        messages.add({
          'role': msg.role == 'user' ? 'user' : 'assistant',
          'content': msg.content,
        });
      }

      messages.add({'role': 'user', 'content': userMessage});

      return await _callGroqApi(messages);
    } catch (e) {
      _handleGroqError(e);
      rethrow;
    }
  }

  /// Hàm mới - hỗ trợ system prompt động + toàn bộ lịch sử chat
  /// Dùng khi có toggle "Bao gồm dữ liệu cá nhân"
  static Future<String> sendMessages(List<Map<String, String>> messages) async {
    if (_apiKey.trim().isEmpty) {
      throw Exception('Groq API key chưa được cấu hình.');
    }

    try {
      return await _callGroqApi(messages);
    } catch (e) {
      _handleGroqError(e);
      rethrow;
    }
  }

  /// Hàm chung gọi API Groq
  static Future<String> _callGroqApi(List<Map<String, String>> messages) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/chat/completions'),
      headers: {
        'Authorization': 'Bearer $_apiKey',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'model':
            'llama-3.3-70b-versatile', // Có thể đổi thành mixtral, gemma2... tùy nhu cầu
        'messages': messages,
        'temperature': 0.7,
        'max_tokens': 2048, // Tăng lên để hỗ trợ context dài + trả lời chi tiết
        'top_p': 0.9,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final content = data['choices'][0]['message']['content'] as String;
      return content.trim();
    } else {
      final errorData = jsonDecode(response.body);
      final errorMsg = errorData['error']?['message'] ?? response.body;
      throw Exception(
        'Lỗi Groq API: $errorMsg (status: ${response.statusCode})',
      );
    }
  }

  /// Xử lý lỗi phổ biến và ném exception thân thiện
  static void _handleGroqError(dynamic e) {
    String message;
    if (e.toString().contains('429') ||
        e.toString().contains('rate-limit') ||
        e.toString().contains('quota')) {
      message =
          'Groq đang bị giới hạn tốc độ hoặc hết quota tạm thời. Vui lòng đợi 1–2 phút rồi thử lại.';
    } else if (e.toString().contains('401')) {
      message =
          'API key Groq không hợp lệ. Vui lòng kiểm tra lại trong file .env';
    } else {
      message = 'Lỗi kết nối với Groq: ${e.toString()}';
    }
    // Có thể log hoặc throw tùy nhu cầu
    print('Groq error: $message');
    throw Exception(message);
  }
}
