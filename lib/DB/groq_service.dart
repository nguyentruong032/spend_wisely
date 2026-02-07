import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:spend_wisely/Function/models.dart';

class GroqService {
  static String _apiKey = dotenv.get('GROQ_API_KEY', fallback: '');

  static const String _baseUrl = 'https://api.groq.com/openai/v1';

  static Future<String> sendMessage(
    String userMessage,
    List<ChatMessage> chatHistory,
  ) async {
    if (_apiKey.trim().isEmpty) {
      throw Exception('Groq API key chưa được cấu hình.');
    }

    try {
      // Chuyển đổi lịch sử chat thành format của Groq (OpenAI format)
      final List<Map<String, String>> messages = [];

      // Thêm system message
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

      // Thêm lịch sử chat (chỉ lấy 10 tin nhắn gần nhất để tránh vượt quá token limit)
      final recentHistory = chatHistory.length > 10
          ? chatHistory.sublist(chatHistory.length - 10)
          : chatHistory;

      for (var msg in recentHistory) {
        messages.add({
          'role': msg.role == 'user' ? 'user' : 'assistant',
          'content': msg.content,
        });
      }

      // Thêm tin nhắn hiện tại
      messages.add({'role': 'user', 'content': userMessage});

      // Gọi API Groq
      final response = await http.post(
        Uri.parse('$_baseUrl/chat/completions'),
        headers: {
          'Authorization': 'Bearer $_apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model':
              'llama-3.3-70b-versatile', // Hoặc 'mixtral-8x7b-32768', 'llama-3.1-8b-instant'
          'messages': messages,
          'temperature': 0.7,
          'max_tokens': 1000,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final content = data['choices'][0]['message']['content'] as String;
        return content;
      } else if (response.statusCode == 429) {
        throw Exception(
          'Groq đang bị giới hạn (rate-limit). Hãy đợi một chút rồi thử lại.',
        );
      } else if (response.statusCode == 401) {
        throw Exception(
          'Groq API key không hợp lệ. Vui lòng kiểm tra lại API key.',
        );
      } else {
        final errorData = jsonDecode(response.body);
        final errorMsg = errorData['error']?['message'] ?? response.body;
        throw Exception('Lỗi Groq API: $errorMsg');
      }
    } catch (e) {
      if (e.toString().contains('rate-limit') ||
          e.toString().contains('429') ||
          e.toString().contains('quota')) {
        throw Exception(
          'Groq đang bị giới hạn (quota/rate-limit). Hãy đợi một chút rồi thử lại.',
        );
      }
      throw Exception('Lỗi khi gửi tin nhắn đến Groq: ${e.toString()}');
    }
  }

  // Danh sách câu hỏi gợi ý
  static List<String> getSuggestedQuestions() {
    return [
      'Làm thế nào để tiết kiệm tiền hiệu quả?',
      'Tôi nên phân bổ ngân sách như thế nào?',
      'Cách theo dõi chi tiêu hàng ngày?',
      'Làm sao để tăng thu nhập?',
      'Tôi nên đầu tư bao nhiêu phần trăm thu nhập?',
    ];
  }
}
