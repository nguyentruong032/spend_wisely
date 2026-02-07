import 'package:flutter/material.dart';

class UserData {
  final String uid;
  final String email;
  final String username;
  final String? avatarUrl;
  final int createdAt;
  final Map<String, dynamic>? preferences;

  UserData({
    required this.uid,
    required this.email,
    required this.username,
    this.avatarUrl,
    required this.createdAt,
    this.preferences,
  });

  factory UserData.fromMap(Map<dynamic, dynamic> map) {
    int parseTimestamp(dynamic timestamp) {
      if (timestamp is int) {
        return timestamp;
      } else if (timestamp is String) {
        return DateTime.parse(timestamp).millisecondsSinceEpoch;
      }
      return 0; // Default or error value
    }

    return UserData(
      uid: (map['uid'] as String?) ?? (map['user_id'] as String),
      email: map['email'] as String,
      username: map['username'] as String,
      avatarUrl: map['avatar_url'] as String?,
      createdAt: parseTimestamp(map['createdAt'] ?? map['created_at']),
      preferences: map['preferences'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'username': username,
      'avatar_url': avatarUrl,
      'createdAt': createdAt,
      'preferences': preferences,
    };
  }
}

class Category {
  final String categoryId;
  final String name;
  final String type; // 'expense' or 'income'
  final String iconCode;
  final String colorHex;
  final bool isSystemDefault;
  final String? createdByUserId;

  Category({
    required this.categoryId,
    required this.name,
    required this.type,
    required this.iconCode,
    required this.colorHex,
    required this.isSystemDefault,
    this.createdByUserId,
  });

  factory Category.fromMap(Map<dynamic, dynamic> map, String categoryId) {
    return Category(
      categoryId: categoryId,
      name: map['name'] as String,
      type: map['type'] as String,
      iconCode: map['icon_code'] as String,
      colorHex: map['color_hex'] as String,
      isSystemDefault: map['is_system_default'] as bool,
      createdByUserId: map['created_by_user_id'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'type': type,
      'icon_code': iconCode,
      'color_hex': colorHex,
      'is_system_default': isSystemDefault,
      'created_by_user_id': createdByUserId,
    };
  }

  IconData get icon {
    switch (iconCode) {
      case 'restaurant':
        return Icons.restaurant;
      case 'electric_bolt':
        return Icons.electric_bolt;
      case 'attach_money':
        return Icons.attach_money;
      case 'home':
        return Icons.home;
      case 'notes':
        return Icons.notes;
      case 'calendar_today':
        return Icons.calendar_today;
      case 'wallet':
        return Icons.wallet;
      case 'payments':
        return Icons.payments;
      case 'card_giftcard':
        return Icons.card_giftcard;
      case 'storefront':
        return Icons.storefront;
      case 'directions_car':
        return Icons.directions_car;
      case 'toys':
        return Icons.toys;
      default:
        return Icons.category;
    }
  }

  Color get color {
    return Color(int.parse(colorHex.substring(1, 7), radix: 16) + 0xFF000000);
  }
}

class Transaction {
  final String transactionId;
  final String userId;
  final String categoryId;
  final String type; // 'expense' or 'income'
  final double amount;
  final String note;
  final int date; // Timestamp in milliseconds
  final int createdAt; // Timestamp in milliseconds
  final bool isViewed;

  Transaction({
    required this.transactionId,
    required this.userId,
    required this.categoryId,
    required this.type,
    required this.amount,
    required this.note,
    required this.date,
    required this.createdAt,
    this.isViewed = false,
  });

  factory Transaction.fromMap(Map<dynamic, dynamic> map, String transactionId) {
    int parseDate(dynamic dateValue) {
      if (dateValue is int) {
        return dateValue;
      } else if (dateValue is String) {
        try {
          return DateTime.parse(dateValue).millisecondsSinceEpoch;
        } catch (e) {
          return int.tryParse(dateValue) ??
              DateTime.now().millisecondsSinceEpoch;
        }
      } else if (dateValue is num) {
        return dateValue.toInt();
      }
      return DateTime.now().millisecondsSinceEpoch;
    }

    int parseCreatedAt(dynamic createdAtValue) {
      if (createdAtValue is int) {
        return createdAtValue;
      } else if (createdAtValue is String) {
        try {
          return DateTime.parse(createdAtValue).millisecondsSinceEpoch;
        } catch (e) {
          return int.tryParse(createdAtValue) ??
              DateTime.now().millisecondsSinceEpoch;
        }
      } else if (createdAtValue is num) {
        return createdAtValue.toInt();
      }
      return DateTime.now().millisecondsSinceEpoch;
    }

    return Transaction(
      transactionId: transactionId,
      userId: map['user_id'] as String,
      categoryId: map['category_id'] as String,
      type: map['type'] as String,
      amount: (map['amount'] as num).toDouble(),
      note: map['note'] as String? ?? '',
      date: parseDate(map['date']),
      createdAt: parseCreatedAt(map['created_at'] ?? map['createdAt']),
      isViewed: map['is_viewed'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'user_id': userId,
      'category_id': categoryId,
      'type': type,
      'amount': amount,
      'note': note,
      'date': date,
      'created_at': createdAt,
      'is_viewed': isViewed,
    };
  }
}

// === NEW MODELS ===

class Conversation {
  final String conversationId;
  final String userId;
  final String title;
  final int createdAt;
  final int updatedAt;
  final int messageCount;

  Conversation({
    required this.conversationId,
    required this.userId,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    this.messageCount = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'conversation_id': conversationId,
      'user_id': userId,
      'title': title,
      'created_at': createdAt,
      'updated_at': updatedAt,
      'message_count': messageCount,
    };
  }

  factory Conversation.fromMap(Map<dynamic, dynamic> map, String id) {
    // Helper function to handle timestamps safely
    int parseTimestamp(dynamic timestamp) {
      if (timestamp is int) {
        return timestamp;
      } else if (timestamp is String) {
        try {
          return DateTime.parse(timestamp).millisecondsSinceEpoch;
        } catch (e) {
          return int.tryParse(timestamp) ?? 0;
        }
      }
      return 0;
    }

    return Conversation(
      conversationId: id,
      userId: map['user_id'] ?? '',
      title: map['title'] ?? 'Cuộc hội thoại mới',
      createdAt: parseTimestamp(map['created_at']),
      updatedAt: parseTimestamp(map['updated_at']),
      messageCount: map['message_count'] ?? 0,
    );
  }
}

class ChatMessage {
  final String messageId;
  final String conversationId;
  final String userId; // THÊM LẠI DÒNG NÀY
  final String role; // 'user' or 'assistant'
  final String content;
  final int timestamp;

  ChatMessage({
    required this.messageId,
    required this.conversationId,
    required this.userId, // THÊM
    required this.role,
    required this.content,
    required this.timestamp,
  });

  factory ChatMessage.fromMap(Map<dynamic, dynamic> map, String messageId) {
    int parseTimestamp(dynamic timestamp) {
      if (timestamp is int) {
        return timestamp;
      } else if (timestamp is String) {
        try {
          return DateTime.parse(timestamp).millisecondsSinceEpoch;
        } catch (e) {
          return int.tryParse(timestamp) ??
              DateTime.now().millisecondsSinceEpoch;
        }
      } else if (timestamp is num) {
        return timestamp.toInt();
      }
      return DateTime.now().millisecondsSinceEpoch;
    }

    return ChatMessage(
      messageId: messageId,
      conversationId: (map['conversation_id'] as String?) ?? '',
      userId: map['user_id'] ?? '', // THÊM
      role: (map['role'] as String?) ?? 'user',
      content: (map['content'] as String?) ?? '',
      timestamp: parseTimestamp(map['timestamp'] ?? map['created_at']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'message_id': messageId,
      'conversation_id': conversationId,
      'role': role,
      'content': content,
      'timestamp': timestamp,
    };
  }
}
