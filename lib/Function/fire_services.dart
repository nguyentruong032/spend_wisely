import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart' hide Transaction;
import 'package:spend_wisely/Function/models.dart';
import '../DB/firebase_options.dart';

class FirebaseService {
  // ==========================================
  // 1. KHỞI TẠO & TÀI KHOẢN (AUTH)
  // ==========================================
  static Future<void> initializeFirebase() async {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }

  static Future<void> updatePassword(
    String currentPassword,
    String newPassword,
  ) async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw FirebaseAuthException(
        code: 'no-current-user',
        message: 'No user is currently signed in.',
      );
    }
    try {
      AuthCredential credential = EmailAuthProvider.credential(
        email: user.email!,
        password: currentPassword,
      );
      await user.reauthenticateWithCredential(credential);
      await user.updatePassword(newPassword);
    } on FirebaseAuthException catch (e) {
      throw e;
    } catch (e) {
      throw Exception('Failed to update password: ${e.toString()}');
    }
  }

  static Future<void> deleteUserAccount(String currentPassword) async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw FirebaseAuthException(
        code: 'no-current-user',
        message: 'No user is currently signed in.',
      );
    }
    try {
      AuthCredential credential = EmailAuthProvider.credential(
        email: user.email!,
        password: currentPassword,
      );
      await user.reauthenticateWithCredential(credential);
      await FirebaseDatabase.instance.ref('users').child(user.uid).remove();
      await user.delete();
    } on FirebaseAuthException catch (e) {
      throw e;
    } catch (e) {
      throw Exception('Failed to delete account: ${e.toString()}');
    }
  }

  // ==========================================
  // 2. NGƯỜI DÙNG (USER DATA)
  // ==========================================
  static Future<UserData?> getUserData(String uid) async {
    DatabaseReference userRef = FirebaseDatabase.instance
        .ref('users')
        .child(uid);
    DataSnapshot snapshot = await userRef.get();
    if (snapshot.exists && snapshot.value != null) {
      return UserData.fromMap(snapshot.value as Map<dynamic, dynamic>);
    } else {
      return null;
    }
  }

  static Future<String> getUserName(String uid) async {
    try {
      DatabaseReference userRef = FirebaseDatabase.instance
          .ref('users')
          .child(uid);
      DataSnapshot snapshot = await userRef.get();
      if (snapshot.exists && snapshot.value != null) {
        final data = snapshot.value as Map<dynamic, dynamic>;
        return data['username'] ?? 'Người dùng';
      }
      return 'Người dùng';
    } catch (e) {
      return 'Người dùng';
    }
  }

  static Future<void> updateUserData(
    String uid,
    Map<String, dynamic> data,
  ) async {
    DatabaseReference userRef = FirebaseDatabase.instance
        .ref('users')
        .child(uid);
    await userRef.update(data);
  }

  // ==========================================
  // 3. GIAO DỊCH & DANH MỤC (FINANCE)
  // ==========================================
  static Future<void> addTransaction(Transaction transaction) async {
    DatabaseReference transactionsRef = FirebaseDatabase.instance.ref(
      'transactions',
    );
    String? newTransactionId = transactionsRef.push().key;
    if (newTransactionId != null) {
      await transactionsRef.child(newTransactionId).set(transaction.toMap());
    } else {
      throw Exception("Could not generate a unique transaction ID.");
    }
  }

  static Future<List<Transaction>> getTransactions(
    String userId,
    String type,
  ) async {
    DatabaseReference transactionsRef = FirebaseDatabase.instance.ref(
      'transactions',
    );
    Query query = transactionsRef.orderByChild('user_id').equalTo(userId);
    DataSnapshot snapshot = await query.get();
    List<Transaction> transactions = [];
    if (snapshot.exists && snapshot.value != null) {
      final dynamic value = snapshot.value;
      if (value is Map<dynamic, dynamic>) {
        value.forEach((key, data) {
          transactions.add(Transaction.fromMap(data, key));
        });
      }
    }
    if (type == 'all') return transactions;
    return transactions
        .where((transaction) => transaction.type == type)
        .toList();
  }

  static Future<void> deleteTransaction(String transactionId) async {
    DatabaseReference transactionRef = FirebaseDatabase.instance
        .ref('transactions')
        .child(transactionId);
    await transactionRef.remove();
  }

  static Future<void> updateTransactionViewed(
    String transactionId,
    bool isViewed,
  ) async {
    DatabaseReference txRef = FirebaseDatabase.instance
        .ref('transactions')
        .child(transactionId);
    await txRef.update({'is_viewed': isViewed});
  }

  static Future<List<Category>> getAllCategories() async {
    User? currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return [];
    DatabaseReference categoriesRef = FirebaseDatabase.instance.ref(
      'categories',
    );
    DataSnapshot snapshot = await categoriesRef.get();
    List<Category> categories = [];
    if (snapshot.exists && snapshot.value != null) {
      final dynamic value = snapshot.value;
      if (value is Map<dynamic, dynamic>) {
        value.forEach((key, data) {
          if (data is Map<dynamic, dynamic>) {
            bool isSystem = data['is_system_default'] == true;
            bool isUserCreated = data['created_by_user_id'] == currentUser.uid;
            if (isSystem || isUserCreated) {
              categories.add(Category.fromMap(data, key));
            }
          }
        });
      }
    }
    return categories;
  }

  static Future<void> addCategory(Category category) async {
    DatabaseReference categoriesRef = FirebaseDatabase.instance.ref(
      'categories',
    );
    String? newCategoryId = categoriesRef.push().key;
    if (newCategoryId != null) {
      await categoriesRef.child(newCategoryId).set(category.toMap());
    } else {
      throw Exception("Could not generate a unique category ID.");
    }
  }

  static Future<void> deleteCategory(String categoryId) async {
    try {
      DatabaseReference categoryRef = FirebaseDatabase.instance
          .ref('categories')
          .child(categoryId);
      DataSnapshot snapshot = await categoryRef.get();
      if (!snapshot.exists) throw Exception("Danh mục không tồn tại.");
      final data = snapshot.value as Map<dynamic, dynamic>?;
      if (data != null && data['is_system_default'] == true) {
        throw Exception("Không thể xóa danh mục hệ thống mặc định.");
      }
      await categoryRef.remove();
    } catch (e) {
      throw Exception("Lỗi xóa danh mục: $e");
    }
  }

  // ==========================================
  // 4. CHAT AI (CONVERSATIONS & MESSAGES)
  // ==========================================
  static Future<String> createConversation(String userId, String title) async {
    DatabaseReference conversationsRef = FirebaseDatabase.instance
        .ref('conversations')
        .child(userId);
    String? newConvId = conversationsRef.push().key;
    if (newConvId != null) {
      final conversation = Conversation(
        conversationId: newConvId,
        userId: userId,
        title: title,
        createdAt: DateTime.now().millisecondsSinceEpoch,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      );
      await conversationsRef.child(newConvId).set(conversation.toMap());
      return newConvId;
    } else {
      throw Exception("Could not generate conversation ID");
    }
  }

  static Future<List<Conversation>> getConversations(String userId) async {
    DatabaseReference conversationsRef = FirebaseDatabase.instance
        .ref('conversations')
        .child(userId);
    DataSnapshot snapshot = await conversationsRef.get();
    List<Conversation> conversations = [];
    if (snapshot.exists && snapshot.value != null) {
      final dynamic value = snapshot.value;
      if (value is Map<dynamic, dynamic>) {
        value.forEach((key, data) {
          if (data is Map<dynamic, dynamic>) {
            conversations.add(Conversation.fromMap(data, key));
          }
        });
      }
    }
    conversations.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return conversations;
  }

  static Future<void> saveMessageToConversation(
    String conversationId,
    ChatMessage message,
  ) async {
    DatabaseReference messagesRef = FirebaseDatabase.instance
        .ref('messages')
        .child(conversationId);
    String? newMessageId = messagesRef.push().key;
    if (newMessageId != null) {
      await messagesRef.child(newMessageId).set(message.toMap());
      await updateConversationMetadata(conversationId, message.content);
    } else {
      throw Exception("Could not generate message ID");
    }
  }

  static Future<List<ChatMessage>> getConversationMessages(
    String conversationId,
  ) async {
    DatabaseReference messagesRef = FirebaseDatabase.instance
        .ref('messages')
        .child(conversationId);
    DataSnapshot snapshot = await messagesRef.get();
    List<ChatMessage> messages = [];
    if (snapshot.exists && snapshot.value != null) {
      final dynamic value = snapshot.value;
      if (value is Map<dynamic, dynamic>) {
        value.forEach((key, data) {
          if (data is Map<dynamic, dynamic>) {
            messages.add(ChatMessage.fromMap(data, key));
          }
        });
      }
    }
    messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return messages;
  }

  static Future<void> deleteConversation(
    String userId,
    String conversationId,
  ) async {
    await FirebaseDatabase.instance
        .ref('conversations')
        .child(userId)
        .child(conversationId)
        .remove();
    await FirebaseDatabase.instance
        .ref('messages')
        .child(conversationId)
        .remove();
  }

  static Future<void> renameConversation(
    String userId,
    String conversationId,
    String newTitle,
  ) async {
    await FirebaseDatabase.instance
        .ref('conversations')
        .child(userId)
        .child(conversationId)
        .update({'title': newTitle});
  }

  static Future<void> updateConversationMetadata(
    String conversationId,
    String lastMessage,
  ) async {
    DatabaseReference allConversationsRef = FirebaseDatabase.instance.ref(
      'conversations',
    );
    DataSnapshot snapshot = await allConversationsRef.get();
    if (snapshot.exists && snapshot.value != null) {
      final dynamic value = snapshot.value;
      if (value is Map<dynamic, dynamic>) {
        value.forEach((userId, userConversations) async {
          if (userConversations is Map<dynamic, dynamic> &&
              userConversations.containsKey(conversationId)) {
            DatabaseReference convRef = FirebaseDatabase.instance
                .ref('conversations')
                .child(userId)
                .child(conversationId);
            DatabaseReference messagesRef = FirebaseDatabase.instance
                .ref('messages')
                .child(conversationId);
            DataSnapshot msgSnapshot = await messagesRef.get();
            int messageCount = (msgSnapshot.exists && msgSnapshot.value is Map)
                ? (msgSnapshot.value as Map).length
                : 0;
            final currentData = userConversations[conversationId];
            String title = currentData['title'] ?? 'Cuộc hội thoại mới';
            if (title == 'Cuộc hội thoại mới' && messageCount == 1) {
              title = lastMessage.length > 50
                  ? '${lastMessage.substring(0, 50)}...'
                  : lastMessage;
            }
            await convRef.update({
              'updated_at': DateTime.now().millisecondsSinceEpoch,
              'message_count': messageCount,
              'title': title,
            });
          }
        });
      }
    }
  }

  // ==========================================
  // 5. CÁC HÀM - DÀNH CHO SINGLE CHAT
  // ==========================================
  static Future<void> saveChatMessage(ChatMessage message) async {
    DatabaseReference chatRef = FirebaseDatabase.instance.ref('chats');
    String? newMessageId = chatRef.push().key;
    if (newMessageId != null) {
      await chatRef.child(newMessageId).set(message.toMap());
    } else {
      throw Exception("Could not generate a unique message ID.");
    }
  }

  static Future<List<ChatMessage>> getChatHistory(String userId) async {
    try {
      DatabaseReference chatRef = FirebaseDatabase.instance.ref('chats');
      Query query = chatRef.orderByChild('user_id').equalTo(userId);
      DataSnapshot snapshot = await query.get();
      List<ChatMessage> messages = [];
      if (snapshot.exists && snapshot.value != null) {
        final dynamic value = snapshot.value;
        if (value is Map<dynamic, dynamic>) {
          value.forEach((key, data) {
            if (data is Map<dynamic, dynamic> &&
                data['user_id'] != null &&
                data['role'] != null &&
                data['content'] != null) {
              messages.add(ChatMessage.fromMap(data, key.toString()));
            }
          });
        }
      }
      messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      return messages;
    } catch (e) {
      return [];
    }
  }

  static Future<void> deleteChatHistory(String userId) async {
    DatabaseReference chatRef = FirebaseDatabase.instance.ref('chats');
    Query query = chatRef.orderByChild('user_id').equalTo(userId);
    DataSnapshot snapshot = await query.get();
    if (snapshot.exists && snapshot.value != null) {
      final dynamic value = snapshot.value;
      if (value is Map<dynamic, dynamic>) {
        for (var key in value.keys) {
          await chatRef.child(key).remove();
        }
      }
    }
  }
}
