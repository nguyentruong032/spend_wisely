import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:spend_wisely/Function/fire_services.dart';
import 'package:spend_wisely/DB/groq_service.dart';
import 'package:spend_wisely/Function/models.dart';
import 'package:fluttertoast/fluttertoast.dart';

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

    _loadConversations();
  }

  Future<void> _loadUserName() async {
    // Gọi hàm lấy tên dựa trên UID của người dùng hiện tại
    String name = await FirebaseService.getUserName(_currentUser!.uid);
    setState(() {
      _userName = name;
    });
  }

  // Tải danh sách tất cả cuộc hội thoại của user
  Future<void> _loadConversations() async {
    if (_currentUser == null) return;
    try {
      List<Conversation> conversations = await FirebaseService.getConversations(
        _currentUser!.uid,
      );
      setState(() {
        _conversations = conversations;
      });
    } catch (e) {
      print('Lỗi load danh sách conversations: $e');
    }
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

    // Tạo object tin nhắn người dùng
    final userMessage = ChatMessage(
      messageId: '',
      conversationId: _currentConversationId!, // THÊM DÒNG NÀY
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

    // 1. Lưu tin nhắn người dùng vào Firebase
    try {
      await FirebaseService.saveMessageToConversation(
        _currentConversationId!,
        userMessage,
      );
    } catch (e) {
      print('Lỗi khi lưu tin nhắn: $e');
    }

    // 2. Gửi đến Groq AI và nhận phản hồi
    try {
      String response = await GroqService.sendMessage(text.trim(), _messages);

      final assistantMessage = ChatMessage(
        messageId: '',
        conversationId: _currentConversationId!, // THÊM DÒNG NÀY
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

      // 3. Lưu phản hồi của AI vào Firebase
      await FirebaseService.saveMessageToConversation(
        _currentConversationId!,
        assistantMessage,
      );

      // Cập nhật lại danh sách cuộc hội thoại (để cập nhật title/thời gian mới nhất)
      _loadConversations();
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
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

            // 4. Danh sách các cuộc hội thoại cũ
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
                            Navigator.pop(context);
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
                              : null,
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
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: Colors.black54),
            onPressed: _loadConversations, // Làm mới danh sách
          ),
        ],
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
              _loadConversations();
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
          Icon(Icons.chat_bubble_outline, size: 80, color: Colors.grey),
          SizedBox(height: 20),
          Text(
            "Bắt đầu cuộc hội thoại mới",
            style: TextStyle(fontSize: 18, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestedQuestions() {
    final suggestions = GroqService.getSuggestedQuestions();
    return Container(
      height: 100,
      padding: EdgeInsets.symmetric(horizontal: 16),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: suggestions.length,
        itemBuilder: (context, index) {
          return Padding(
            padding: const EdgeInsets.only(right: 8.0, bottom: 20),
            child: ActionChip(
              label: Text(suggestions[index], style: TextStyle(fontSize: 12)),
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
      padding: EdgeInsets.all(16),
      color: Colors.white,
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              decoration: InputDecoration(
                hintText: "Hỏi AI về tài chính...",
                filled: true,
                fillColor: Color(0xFFF5F5F5),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
              ),
              onSubmitted: _sendMessage,
            ),
          ),
          IconButton(
            icon: Icon(Icons.send, color: Color(0xFF1976D2)),
            onPressed: () => _sendMessage(_messageController.text),
          ),
        ],
      ),
    );
  }
}
