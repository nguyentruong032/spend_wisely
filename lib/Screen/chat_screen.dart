import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:spend_wisely/Function/fire_services.dart';
import 'package:spend_wisely/DB/groq_service.dart';
import 'package:spend_wisely/Function/models.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:spend_wisely/Function/finacial_data_service.dart';

class ChatScreen extends StatefulWidget {
  final String? conversationId; // Thêm parameter để nhận ID cuộc hội thoại

  const ChatScreen({Key? key, this.conversationId})
    : super(key: key); // ← Remove 'required' here if present
  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<ChatMessage> _messages = [];
  List<Conversation> _conversations = []; // Danh sách các cuộc hội thoại

  User? _currentUser;
  String? _currentConversationId; // ID cuộc hội thoại hiện tại

  bool _isLoading = false;
  bool _isInitialLoading = true;
  String _userName = "Đang tải...";
  bool _includePersonalData = false; // mặc định tắt

  @override
  void initState() {
    super.initState();
    _currentUser = FirebaseAuth.instance.currentUser;
    if (_currentUser != null) {
      _loadUserName();
    }

    // Logic khởi tạo cuộc hội thoại
    if (widget.conversationId != null) {
      _currentConversationId = widget.conversationId;
      _loadConversationMessages();
    } else {
      _createNewConversation();
    }
  }

  Future<void> _loadUserName() async {
    // Gọi hàm lấy tên dựa trên UID của người dùng hiện tại
    String name = await FirebaseService.getUserName(_currentUser!.uid);
    setState(() {
      _userName = name;
    });
  }

  // Tạo một cuộc hội thoại mới khi vào màn hình mà không có ID
  Future<void> _createNewConversation() async {
    if (_currentUser == null) return;
    setState(() => _isInitialLoading = true);

    try {
      String newConvId = await FirebaseService.createConversation(
        _currentUser!.uid,
        'Cuộc hội thoại mới',
      );
      setState(() {
        _currentConversationId = newConvId;
        _messages = [];
        _isInitialLoading = false;
      });
    } catch (e) {
      print('Lỗi tạo conversation mới: $e');
      setState(() => _isInitialLoading = false);
    }
  }

  // Tải tin nhắn của cuộc hội thoại hiện tại
  Future<void> _loadConversationMessages() async {
    if (_currentConversationId == null) return;

    setState(() {
      _isInitialLoading = true;
    });

    try {
      List<ChatMessage> history = await FirebaseService.getConversationMessages(
        _currentConversationId!,
      );
      setState(() {
        _messages = history;
        _isInitialLoading = false;
      });
      if (_messages.isNotEmpty) {
        _scrollToBottom();
      }
    } catch (e) {
      print('Lỗi khi tải tin nhắn: $e');
      setState(() {
        _messages = [];
        _isInitialLoading = false;
      });
      Fluttertoast.showToast(msg: "Không thể tải tin nhắn");
    }
  }

  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty ||
        _currentUser == null ||
        _currentConversationId == null)
      return;

    setState(() {
      _isLoading = true;
    });

    // Tạo tin nhắn người dùng
    final userMessage = ChatMessage(
      messageId: '',
      conversationId: _currentConversationId!,
      userId: _currentUser!.uid,
      role: 'user',
      content: text.trim(),
      timestamp: DateTime.now().millisecondsSinceEpoch,
    );

    setState(() {
      _messages.add(userMessage);
    });
    _messageController.clear();
    _scrollToBottom();

    // Lưu tin nhắn người dùng
    try {
      await FirebaseService.saveMessageToConversation(
        _currentConversationId!,
        userMessage,
      );
    } catch (e) {
      print('Lỗi lưu tin nhắn người dùng: $e');
    }

    // ────────────────────────────────────────────────────────────────
    // Phần mới: Chuẩn bị context tài chính nếu toggle bật
    String financialContext = "";
    if (_includePersonalData) {
      try {
        final summary = await FinancialDataService.getUserFinancialSummary(
          _currentUser!.uid,
          yearsBack: 1,
        );
        final rawSummaryText = summary['summaryText'];
        financialContext =
            rawSummaryText?.toString() ??
            "\n(Lưu ý: Không có dữ liệu tài chính hợp lệ hoặc summaryText rỗng)";
      } catch (e, stack) {
        financialContext = "\n(Lỗi khi lấy dữ liệu tài chính: $e)";
      }
    }

    // Tạo system prompt động
    final systemPrompt =
        """
Bạn là trợ lý tài chính cá nhân thông minh, trung thực, trả lời bằng tiếng Việt, chi tiết và thực tế.
${_includePersonalData ? """
Dữ liệu tài chính thực tế 1 năm qua của người dùng (UID: ${_currentUser!.uid}):
$financialContext

→ Luôn dựa vào dữ liệu trên để đưa ra lời khuyên cụ thể, tính toán kế hoạch, cảnh báo rủi ro.
→ Nếu dữ liệu không đủ hoặc không liên quan, hãy nói rõ và bổ sung lời khuyên chung.
""" : """
Không sử dụng bất kỳ dữ liệu cá nhân nào của người dùng.
Trả lời chung chung, mang tính tham khảo, không giả định thông tin tài chính cụ thể.
"""}
""";

    // ────────────────────────────────────────────────────────────────

    try {
      // Chuẩn bị danh sách messages cho Groq
      final messagesForGroq = <Map<String, String>>[
        {'role': 'system', 'content': systemPrompt},
      ];

      // Thêm lịch sử chat (để Groq hiểu ngữ cảnh cuộc trò chuyện)
      for (final msg in _messages) {
        if (msg.role == 'user' || msg.role == 'assistant') {
          messagesForGroq.add({'role': msg.role, 'content': msg.content});
        }
      }

      // Gọi Groq với toàn bộ context
      final response = await GroqService.sendMessages(
        messagesForGroq,
      ); // ← cần hàm mới

      final assistantMessage = ChatMessage(
        messageId: '',
        conversationId: _currentConversationId!,
        userId: _currentUser!.uid,
        role: 'assistant',
        content: response,
        timestamp: DateTime.now().millisecondsSinceEpoch,
      );

      setState(() {
        _messages.add(assistantMessage);
        _isLoading = false;
      });
      _scrollToBottom();

      await FirebaseService.saveMessageToConversation(
        _currentConversationId!,
        assistantMessage,
      );
    } catch (e) {
      setState(() => _isLoading = false);
      Fluttertoast.showToast(
        msg: "Lỗi kết nối AI: ${e.toString()}",
        toastLength: Toast.LENGTH_LONG,
        backgroundColor: Colors.red,
      );
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFE3F2FD),
      // 1. THÊM DRAWER Ở ĐÂY
      drawer: Drawer(
        child: Column(
          children: [
            // 1. Header hiển thị thông tin người dùng
            UserAccountsDrawerHeader(
              decoration: BoxDecoration(
                color: Color(0xFF1976D2),
                image: DecorationImage(
                  image: NetworkImage(
                    "https://www.transparenttextures.com/patterns/cubes.png",
                  ),
                  opacity: 0.1,
                ),
              ),
              accountName: Text(
                _userName,
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              accountEmail: Text(_currentUser?.email ?? ""),
              currentAccountPicture: CircleAvatar(
                backgroundColor: Colors.white,
                child: Icon(Icons.person, color: Color(0xFF1976D2), size: 40),
              ),
            ),

            // 2. Nút QUAY VỀ TRANG CHỦ (Giải quyết vấn đề của bạn)
            ListTile(
              leading: Icon(Icons.home_rounded, color: Colors.blue[700]),
              title: Text(
                "Quay về Trang chủ",
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              onTap: () {
                Navigator.pop(context); // Đóng Drawer trước
                Navigator.pop(context); // Thoát màn hình Chat để về Home
              },
            ),

            // 3. Nút Tạo cuộc hội thoại mới
            ListTile(
              leading: Icon(
                Icons.add_comment_rounded,
                color: Colors.green[700],
              ),
              title: Text("Tạo cuộc trò chuyện mới"),
              onTap: () {
                Navigator.pop(context);
                _createNewConversation();
              },
            ),

            Divider(thickness: 1, height: 1),

            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Row(
                children: [
                  Icon(Icons.history, size: 16, color: Colors.grey),
                  SizedBox(width: 8),
                  Text(
                    "LỊCH SỬ GẦN ĐÂY",
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

            // 4. Danh sách các cuộc hội thoại cũ (SỬA Ở ĐÂY: Thêm icon delete)
            Expanded(
              child: _conversations.isEmpty
                  ? Center(
                      child: Text(
                        "Chưa có hội thoại nào",
                        style: TextStyle(color: Colors.grey),
                      ),
                    )
                  : ListView.builder(
                      padding: EdgeInsets.zero,
                      itemCount: _conversations.length,
                      itemBuilder: (context, index) {
                        final conv = _conversations[index];
                        final isSelected =
                            conv.conversationId == _currentConversationId;

                        return ListTile(
                          selected: isSelected,
                          selectedTileColor: Colors.blue.withOpacity(0.1),
                          leading: Icon(
                            Icons.chat_bubble_outline_rounded,
                            color: isSelected
                                ? Color(0xFF1976D2)
                                : Colors.grey[600],
                            size: 20,
                          ),
                          title: Text(
                            conv.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                          onTap: () {
                            Navigator.pop(
                              context,
                            ); // Đóng Drawer trước khi load
                            if (!isSelected) {
                              setState(() {
                                _currentConversationId = conv.conversationId;
                                _loadConversationMessages();
                              });
                            }
                          },
                          trailing: isSelected
                              ? Icon(
                                  Icons.arrow_right,
                                  color: Color(0xFF1976D2),
                                )
                              : IconButton(
                                  // THÊM: Icon delete nếu không selected
                                  icon: Icon(
                                    Icons.delete_outline,
                                    color: Colors.red[600],
                                    size: 20,
                                  ),
                                  onPressed: () {
                                    Navigator.pop(context); // Đóng Drawer
                                    _confirmDeleteConversation(
                                      conv,
                                    ); // Gọi confirm xóa single
                                  },
                                ),
                        );
                      },
                    ),
            ),

            // 5. Nút cài đặt hoặc hướng dẫn (Tùy chọn thêm)
            Divider(),
            ListTile(
              leading: Icon(Icons.help_outline, size: 20),
              title: Text(
                "Hướng dẫn sử dụng AI",
                style: TextStyle(fontSize: 13),
              ),
              onTap: () {
                // Thêm logic hướng dẫn nếu cần
              },
            ),
            SizedBox(height: 10),
          ],
        ),
      ),

      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        // Flutter sẽ tự động hiển thị nút Menu (3 gạch) tại đây vì đã khai báo drawer
        title: Text(
          "AI Tư vấn Tài chính",
          style: TextStyle(
            color: Colors.black87,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: _isInitialLoading
                ? Center(child: CircularProgressIndicator())
                : _messages.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    controller: _scrollController,
                    padding: EdgeInsets.all(16),
                    itemCount: _messages.length + (_isLoading ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == _messages.length)
                        return _buildTypingIndicator();
                      return _buildMessageBubble(_messages[index]);
                    },
                  ),
          ),
          _buildMessageInput(),
        ],
      ),
    );
  }

  // Hàm hỗ trợ xác nhận xóa
  void _confirmDeleteConversation(Conversation conv) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Xóa cuộc hội thoại?"),
        content: Text("Bạn có chắc muốn xóa '${conv.title}' không?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("Hủy"),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await FirebaseService.deleteConversation(
                _currentUser!.uid,
                conv.conversationId,
              );
              if (_currentConversationId == conv.conversationId) {
                _createNewConversation();
              }
            },
            child: Text("Xóa", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  // Các Widget hỗ trợ (giữ nguyên từ bản cũ nhưng có chỉnh sửa nhẹ về màu sắc/logic)
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.chat_bubble_outline_rounded,
            size: 90,
            color: Colors.blue.shade300,
          ),
          const SizedBox(height: 24),
          Text(
            "Chào bạn! Bạn muốn hỏi gì hôm nay?",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Dưới đây là một số gợi ý phổ biến:",
            style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 20),
          _buildSuggestedQuestions(), // ← Thêm dòng này
        ],
      ),
    );
  }

  Widget _buildSuggestedQuestions() {
    final suggestions = [
      "Lời khuyên đầu tư an toàn 2026",
      "Ngân sách du lịch 10 triệu nên chia thế nào?",
    ];
    return Container(
      height: 125,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: suggestions.length,
        itemBuilder: (context, index) {
          return Padding(
            padding: const EdgeInsets.only(right: 10, bottom: 12),
            child: ActionChip(
              elevation: 2,
              backgroundColor: Colors.white,
              side: BorderSide(color: Colors.blue.shade100),
              label: Text(
                suggestions[index],
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              onPressed: () => _sendMessage(suggestions[index]),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage message) {
    final isUser = message.role == 'user';
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.only(bottom: 12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isUser ? Color(0xFF1976D2) : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
            bottomLeft: isUser ? Radius.circular(20) : Radius.circular(0),
            bottomRight: isUser ? Radius.circular(0) : Radius.circular(20),
          ),
        ),
        child: Text(
          message.content,
          style: TextStyle(color: isUser ? Colors.white : Colors.black87),
        ),
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Text(
        "AI đang soạn tin nhắn...",
        style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey),
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.all(12),
      color: Colors.white,
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              decoration: InputDecoration(
                hintText: "Hỏi AI về tài chính...",
                filled: true,
                fillColor: const Color(0xFFF5F5F5),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
              onSubmitted: (value) => _sendMessage(value),
            ),
          ),
          const SizedBox(width: 8),
          // Toggle button "Dữ liệu cá nhân"
          Tooltip(
            message: _includePersonalData
                ? "Đang gửi dữ liệu thu chi 1 năm cho AI"
                : "Bật để AI sử dụng dữ liệu tài chính cá nhân của bạn",
            child: IconButton(
              icon: Icon(
                Icons.account_balance_wallet_rounded,
                color: _includePersonalData
                    ? Colors.blue[700]
                    : Colors.grey[600],
                size: 28,
              ),
              onPressed: () {
                setState(() {
                  _includePersonalData = !_includePersonalData;
                });
                Fluttertoast.showToast(
                  msg: _includePersonalData
                      ? "Đã bật dữ liệu cá nhân"
                      : "Đã tắt dữ liệu cá nhân",
                  gravity: ToastGravity.BOTTOM,
                );
              },
            ),
          ),
          IconButton(
            icon: const Icon(Icons.send, color: Color(0xFF1976D2)),
            onPressed: () => _sendMessage(_messageController.text),
          ),
        ],
      ),
    );
  }
}
