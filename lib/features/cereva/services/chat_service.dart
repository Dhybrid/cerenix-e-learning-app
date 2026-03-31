// // lib/features/ai_chat/services/chat_service.dart
// import 'dart:convert';
// import 'package:http/http.dart' as http;
// import 'package:shared_preferences/shared_preferences.dart';
// import 'package:hive_flutter/hive_flutter.dart';
// import '../../../../core/constants/endpoints.dart';
// import '../models/chat_models.dart';

// class ChatService {
//   static String? _sessionId;
//   static late Box<ChatSession> _chatBox;
//   static bool _hiveInitialized = false;

//   static Future<void> initHive() async {
//     if (!_hiveInitialized) {
//       _chatBox = await Hive.openBox<ChatSession>('chat_sessions');
//       _hiveInitialized = true;
//     }
//   }

//   static Future<String> getSessionId() async {
//     if (_sessionId != null) return _sessionId!;

//     final prefs = await SharedPreferences.getInstance();
//     _sessionId = prefs.getString('ai_chat_session_id');

//     if (_sessionId == null) {
//       _sessionId = _generateSessionId();
//       await prefs.setString('ai_chat_session_id', _sessionId!);
//     }

//     return _sessionId!;
//   }

//   static String _generateSessionId() {
//     return 'session_${DateTime.now().millisecondsSinceEpoch}_${(100000 + DateTime.now().microsecondsSinceEpoch % 900000)}';
//   }

//   static Future<Map<String, dynamic>> sendMessage(String message) async {
//     try {
//       final sessionId = await getSessionId();

//       print('🌐 Sending to: ${ApiEndpoints.askCerava}');
//       print('💬 Message: $message');
//       print('🆔 Session ID: $sessionId');

//       // Create the request body
//       final requestBody = {
//         'message': message,
//         'session_id': sessionId,
//       };

//       print('📦 Request body: $requestBody');

//       final response = await http.post(
//         Uri.parse(ApiEndpoints.askCerava),
//         headers: {
//           'Content-Type': 'application/json',
//         },
//         body: json.encode(requestBody),
//       ).timeout(const Duration(seconds: 30));

//       print('📡 Response status: ${response.statusCode}');
//       print('📦 Response body: ${response.body}');

//       if (response.statusCode == 200) {
//         final data = json.decode(response.body);

//         // Save to Hive chat history
//         await _saveToChatHistory(message, data['reply'], sessionId, data['source'] ?? 'llm_model');

//         return {
//           'success': true,
//           'reply': data['reply'],
//           'session_id': data['session_id'],
//           'source': data['source'] ?? 'llm_model',
//         };
//       } else {
//         // Try to parse error response
//         try {
//           final errorData = json.decode(response.body);

//           // Check for session timeout errors
//           if (_isSessionError(errorData['error'])) {
//             print('🔄 Session expired, creating new session...');
//             await clearSession();
//             return await sendMessage(message); // Retry with new session
//           }

//           // Save error to chat history
//           await _saveToChatHistory(message, 'Error: ${errorData['error'] ?? 'Unknown error'}', sessionId, 'error', isError: true);

//           return {
//             'success': false,
//             'error': errorData['error'] ?? 'HTTP ${response.statusCode}',
//             'session_id': sessionId,
//           };
//         } catch (e) {
//           // Save error to chat history
//           await _saveToChatHistory(message, 'Error: HTTP ${response.statusCode}', sessionId, 'error', isError: true);

//           return {
//             'success': false,
//             'error': 'HTTP ${response.statusCode}: ${response.body}',
//             'session_id': sessionId,
//           };
//         }
//       }
//     } catch (e) {
//       print('💥 ChatService error: $e');

//       // Save network error to chat history
//       final currentSessionId = await getSessionId();
//       await _saveToChatHistory(message, 'Network error: Please check your connection', currentSessionId, 'error', isError: true);

//       return {
//         'success': false,
//         'error': 'Network error: $e',
//         'session_id': await getSessionId(),
//       };
//     }
//   }

//   static bool _isSessionError(String? error) {
//     if (error == null) return false;
//     final errorLower = error.toLowerCase();
//     return errorLower.contains('session') ||
//            errorLower.contains('timeout') ||
//            errorLower.contains('expired') ||
//            errorLower.contains('invalid') ||
//            errorLower.contains('bad request');
//   }

//   static Future<void> _saveToChatHistory(
//     String userMessage,
//     String aiResponse,
//     String sessionId,
//     String source, {
//     bool isError = false
//   }) async {
//     try {
//       await initHive();

//       // Get or create chat session
//       ChatSession? session = _chatBox.get(sessionId);
//       if (session == null) {
//         session = ChatSession(
//           id: sessionId,
//           title: userMessage.length > 30 ? '${userMessage.substring(0, 30)}...' : userMessage,
//           createdAt: DateTime.now(),
//           updatedAt: DateTime.now(),
//           messages: [],
//           backendSessionId: sessionId,
//         );
//       }

//       // Add user message
//       session.messages.add(ChatMessage(
//         text: userMessage,
//         isUser: true,
//         timestamp: DateTime.now(),
//       ));

//       // Add AI response
//       session.messages.add(ChatMessage(
//         text: aiResponse,
//         isUser: false,
//         timestamp: DateTime.now(),
//         source: isError ? null : source,
//         isError: isError,
//       ));

//       // Update session
//       session.updatedAt = DateTime.now();
//       await _chatBox.put(sessionId, session);

//       print('💾 Saved to chat history: ${session.messages.length} messages');

//     } catch (e) {
//       print('❌ Error saving to chat history: $e');
//     }
//   }

//   // Get chat history for sidebar
//   static Future<List<ChatSession>> getChatHistory() async {
//     try {
//       await initHive();
//       final sessions = _chatBox.values.toList();
//       sessions.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
//       return sessions;
//     } catch (e) {
//       print('❌ Error getting chat history: $e');
//       return [];
//     }
//   }

//   // Get messages for a specific session
//   static Future<List<ChatMessage>> getSessionMessages(String sessionId) async {
//     try {
//       await initHive();
//       final session = _chatBox.get(sessionId);
//       return session?.messages ?? [];
//     } catch (e) {
//       print('❌ Error getting session messages: $e');
//       return [];
//     }
//   }

//   // Load a specific chat session and get all its messages
//   static Future<List<ChatMessage>> loadChatSession(String sessionId) async {
//     try {
//       await initHive();

//       // Set this as current session
//       final prefs = await SharedPreferences.getInstance();
//       await prefs.setString('ai_chat_session_id', sessionId);
//       _sessionId = sessionId;

//       // Get messages for this session
//       final session = _chatBox.get(sessionId);
//       final messages = session?.messages ?? [];

//       print('📂 Loaded chat session: $sessionId with ${messages.length} messages');
//       return messages;
//     } catch (e) {
//       print('❌ Error loading chat session: $e');
//       return [];
//     }
//   }

//   // Start a new chat
//   static Future<void> startNewChat() async {
//     try {
//       final prefs = await SharedPreferences.getInstance();
//       await prefs.remove('ai_chat_session_id');
//       _sessionId = null;
//       print('🆕 Started new chat session');
//     } catch (e) {
//       print('❌ Error starting new chat: $e');
//     }
//   }

//   // Delete a chat session
//   static Future<void> deleteChatSession(String sessionId) async {
//     try {
//       await initHive();
//       await _chatBox.delete(sessionId);

//       // If deleting current session, clear it
//       final currentSessionId = await getSessionId();
//       if (currentSessionId == sessionId) {
//         await clearSession();
//       }

//       print('🗑️ Deleted chat session: $sessionId');
//     } catch (e) {
//       print('❌ Error deleting chat session: $e');
//     }
//   }

//   static Future<void> clearSession() async {
//     final prefs = await SharedPreferences.getInstance();
//     await prefs.remove('ai_chat_session_id');
//     _sessionId = null;
//   }

//   // Clear all chat history
//   static Future<void> clearAllChats() async {
//     try {
//       await initHive();
//       await _chatBox.clear();
//       await clearSession();
//       print('🧹 Cleared all chat history');
//     } catch (e) {
//       print('❌ Error clearing all chats: $e');
//     }
//   }

//   // Check if session is still valid
//   static Future<bool> validateSession() async {
//     try {
//       final sessionId = await getSessionId();
//       final response = await http.post(
//         Uri.parse(ApiEndpoints.askCerava),
//         headers: {'Content-Type': 'application/json'},
//         body: json.encode({
//           'message': 'ping',
//           'session_id': sessionId,
//         }),
//       ).timeout(const Duration(seconds: 10));

//       return response.statusCode == 200;
//     } catch (e) {
//       return false;
//     }
//   }
// }

// lib/features/ai_chat/services/chat_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../../../core/constants/endpoints.dart';
import '../models/chat_models.dart';
import '../utils/ai_response_utils.dart';

class ChatService {
  static String? _sessionId;
  static late Box<ChatSession> _chatBox;
  static bool _hiveInitialized = false;

  static Future<void> initHive() async {
    if (!_hiveInitialized) {
      _chatBox = await Hive.openBox<ChatSession>('chat_sessions');
      _hiveInitialized = true;
    }
  }

  // NEW: Get current user ID from Hive
  static Future<String?> getCurrentUserId() async {
    try {
      final box = await Hive.openBox('user_box');
      final userData = box.get('current_user');
      if (userData != null && userData is Map) {
        final userId = userData['id']?.toString();
        print('👤 Retrieved user ID from Hive: $userId');
        return userId;
      }
      print('❌ No user ID found in Hive');
      return null;
    } catch (e) {
      print('❌ Error getting user ID from Hive: $e');
      return null;
    }
  }

  static Future<String> getSessionId() async {
    if (_sessionId != null) return _sessionId!;

    final prefs = await SharedPreferences.getInstance();
    _sessionId = prefs.getString('ai_chat_session_id');

    if (_sessionId == null) {
      _sessionId = _generateSessionId();
      await prefs.setString('ai_chat_session_id', _sessionId!);
    }

    return _sessionId!;
  }

  static String _generateSessionId() {
    return 'session_${DateTime.now().millisecondsSinceEpoch}_${(100000 + DateTime.now().microsecondsSinceEpoch % 900000)}';
  }

  static Future<Map<String, dynamic>> sendMessage(
    String message, {
    String? userId,
  }) async {
    try {
      final sessionId = await getSessionId();

      // NEW: If userId is not provided, try to get it from Hive
      String? finalUserId = userId;
      if (finalUserId == null) {
        finalUserId = await getCurrentUserId();
      }

      print('🌐 Sending to: ${ApiEndpoints.askCerava}');
      print('💬 Message: $message');
      print('🆔 Session ID: $sessionId');
      print('👤 User ID: $finalUserId');

      // Create the request body - NOW USER_ID IS REQUIRED
      final requestBody = {
        'message': message,
        'session_id': sessionId,
        'user_id': finalUserId, // This is now required
      };

      if (finalUserId == null) {
        // Save error to chat history
        await _saveToChatHistory(
          message,
          'Please login to use Cerenix AI. You can access this feature after signing in.',
          sessionId,
          'auth_error',
          isError: true,
        );

        return {
          'success': false,
          'error': 'user_not_logged_in',
          'message':
              'Please login to use Cerenix AI. You can access this feature after signing in.',
          'session_id': sessionId,
        };
      }

      print('📦 Request body: $requestBody');

      final response = await http
          .post(
            Uri.parse(ApiEndpoints.askCerava),
            headers: {'Content-Type': 'application/json'},
            body: json.encode(requestBody),
          )
          .timeout(AiResponseUtils.requestTimeout);

      print('📡 Response status: ${response.statusCode}');
      print('📦 Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        // Save to Hive chat history
        await _saveToChatHistory(
          message,
          data['reply'],
          sessionId,
          data['source'] ?? 'llm_model',
        );

        return {
          'success': true,
          'reply': data['reply'],
          'session_id': data['session_id'],
          'source': data['source'] ?? 'llm_model',
          'remaining_messages': data['remaining_messages'],
          'limit_info': data['limit_info'],
        };
      } else if (response.statusCode == 429) {
        // Rate limit exceeded - handle gracefully
        final errorData = json.decode(response.body);
        print('🚫 Daily limit exceeded: ${errorData['message']}');

        // Save limit message to chat history
        await _saveToChatHistory(
          message,
          errorData['message'] ??
              'Daily message limit reached. Please try again tomorrow.',
          sessionId,
          'limit_error',
          isError: true,
        );

        return {
          'success': false,
          'error': 'daily_limit_exceeded',
          'message':
              errorData['message'] ??
              'Daily message limit reached. Please try again tomorrow.',
          'limit_reached': true,
          'session_id': sessionId,
        };
      } else if (response.statusCode == 400) {
        // Bad request - likely missing user_id
        final errorData = json.decode(response.body);
        print('❌ Bad request: ${errorData['error']}');

        // Save error to chat history
        await _saveToChatHistory(
          message,
          'Authentication error. Please login again.',
          sessionId,
          'auth_error',
          isError: true,
        );

        return {
          'success': false,
          'error': 'authentication_required',
          'message': 'Please login again to continue using Cerenix AI.',
          'session_id': sessionId,
        };
      } else {
        // Try to parse error response
        try {
          final errorData = json.decode(response.body);

          // Check for session timeout errors
          if (_isSessionError(errorData['error'])) {
            print('🔄 Session expired, creating new session...');
            await clearSession();
            return await sendMessage(
              message,
              userId: finalUserId,
            ); // Retry with new session
          }

          // Save error to chat history
          await _saveToChatHistory(
            message,
            'Error: ${errorData['error'] ?? 'Unknown error'}',
            sessionId,
            'error',
            isError: true,
          );

          return {
            'success': false,
            'error': errorData['error'] ?? 'HTTP ${response.statusCode}',
            'session_id': sessionId,
          };
        } catch (e) {
          // Save error to chat history
          await _saveToChatHistory(
            message,
            'Error: HTTP ${response.statusCode}',
            sessionId,
            'error',
            isError: true,
          );

          return {
            'success': false,
            'error': 'HTTP ${response.statusCode}: ${response.body}',
            'session_id': sessionId,
          };
        }
      }
    } catch (e) {
      print('💥 ChatService error: $e');

      // Save network error to chat history
      final currentSessionId = await getSessionId();
      await _saveToChatHistory(
        message,
        'Network error: Please check your connection',
        currentSessionId,
        'error',
        isError: true,
      );

      return {
        'success': false,
        'error': 'Network error: $e',
        'session_id': await getSessionId(),
      };
    }
  }

  // NEW: Get message status and limits for a user
  static Future<Map<String, dynamic>> getMessageStatus({String? userId}) async {
    try {
      // If userId is not provided, try to get it from Hive
      String? finalUserId = userId;
      if (finalUserId == null) {
        finalUserId = await getCurrentUserId();
      }

      if (finalUserId == null) {
        return {'success': false, 'error': 'User not logged in'};
      }

      print('📊 Getting message status for user: $finalUserId');

      final response = await http
          .get(
            // Uri.parse('${ApiEndpoints.askCerava}status/?user_id=$finalUserId'),
            Uri.parse(
              '${ApiEndpoints.baseUrl}/api/ask/status/?user_id=$finalUserId',
            ),
            headers: {'Content-Type': 'application/json'},
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print(
          '✅ Message status retrieved: ${data['remaining_today']} remaining',
        );

        return {'success': true, 'data': data};
      } else {
        print('❌ Failed to get message status: ${response.statusCode}');
        return {
          'success': false,
          'error': 'Failed to get message status: HTTP ${response.statusCode}',
        };
      }
    } catch (e) {
      print('❌ Error getting message status: $e');
      return {'success': false, 'error': 'Network error: $e'};
    }
  }

  // NEW: Check if user is logged in
  static Future<bool> isUserLoggedIn() async {
    final userId = await getCurrentUserId();
    return userId != null;
  }

  // NEW: Get current user data
  static Future<Map<String, dynamic>?> getCurrentUserData() async {
    try {
      final box = await Hive.openBox('user_box');
      final userData = box.get('current_user');
      if (userData != null && userData is Map) {
        return Map<String, dynamic>.from(userData);
      }
      return null;
    } catch (e) {
      print('❌ Error getting user data: $e');
      return null;
    }
  }

  static bool _isSessionError(String? error) {
    if (error == null) return false;
    final errorLower = error.toLowerCase();
    return errorLower.contains('session') ||
        errorLower.contains('timeout') ||
        errorLower.contains('expired') ||
        errorLower.contains('invalid') ||
        errorLower.contains('bad request');
  }

  static Future<void> _saveToChatHistory(
    String userMessage,
    String aiResponse,
    String sessionId,
    String source, {
    bool isError = false,
  }) async {
    try {
      await initHive();

      // Get or create chat session
      ChatSession? session = _chatBox.get(sessionId);
      if (session == null) {
        session = ChatSession(
          id: sessionId,
          title: userMessage.length > 30
              ? '${userMessage.substring(0, 30)}...'
              : userMessage,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          messages: [],
          backendSessionId: sessionId,
        );
      }

      // Add user message
      session.messages.add(
        ChatMessage(text: userMessage, isUser: true, timestamp: DateTime.now()),
      );

      // Add AI response
      session.messages.add(
        ChatMessage(
          text: aiResponse,
          isUser: false,
          timestamp: DateTime.now(),
          source: isError ? null : source,
          isError: isError,
        ),
      );

      // Update session
      session.updatedAt = DateTime.now();
      await _chatBox.put(sessionId, session);

      print('💾 Saved to chat history: ${session.messages.length} messages');
    } catch (e) {
      print('❌ Error saving to chat history: $e');
    }
  }

  // Get chat history for sidebar
  static Future<List<ChatSession>> getChatHistory() async {
    try {
      await initHive();
      final sessions = _chatBox.values.toList();
      sessions.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      return sessions;
    } catch (e) {
      print('❌ Error getting chat history: $e');
      return [];
    }
  }

  // Get messages for a specific session
  static Future<List<ChatMessage>> getSessionMessages(String sessionId) async {
    try {
      await initHive();
      final session = _chatBox.get(sessionId);
      return session?.messages ?? [];
    } catch (e) {
      print('❌ Error getting session messages: $e');
      return [];
    }
  }

  // Load a specific chat session and get all its messages
  static Future<List<ChatMessage>> loadChatSession(String sessionId) async {
    try {
      await initHive();

      // Set this as current session
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('ai_chat_session_id', sessionId);
      _sessionId = sessionId;

      // Get messages for this session
      final session = _chatBox.get(sessionId);
      final messages = session?.messages ?? [];

      print(
        '📂 Loaded chat session: $sessionId with ${messages.length} messages',
      );
      return messages;
    } catch (e) {
      print('❌ Error loading chat session: $e');
      return [];
    }
  }

  // Start a new chat
  static Future<void> startNewChat() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('ai_chat_session_id');
      _sessionId = null;
      print('🆕 Started new chat session');
    } catch (e) {
      print('❌ Error starting new chat: $e');
    }
  }

  // Delete a chat session
  static Future<void> deleteChatSession(String sessionId) async {
    try {
      await initHive();
      await _chatBox.delete(sessionId);

      // If deleting current session, clear it
      final currentSessionId = await getSessionId();
      if (currentSessionId == sessionId) {
        await clearSession();
      }

      print('🗑️ Deleted chat session: $sessionId');
    } catch (e) {
      print('❌ Error deleting chat session: $e');
    }
  }

  static Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('ai_chat_session_id');
    _sessionId = null;
  }

  // Clear all chat history
  static Future<void> clearAllChats() async {
    try {
      await initHive();
      await _chatBox.clear();
      await clearSession();
      print('🧹 Cleared all chat history');
    } catch (e) {
      print('❌ Error clearing all chats: $e');
    }
  }

  // Check if session is still valid
  static Future<bool> validateSession() async {
    try {
      final sessionId = await getSessionId();
      final userId = await getCurrentUserId();

      if (userId == null) {
        return false;
      }

      final response = await http
          .post(
            Uri.parse(ApiEndpoints.askCerava),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({
              'message': 'ping',
              'session_id': sessionId,
              'user_id': userId,
            }),
          )
          .timeout(const Duration(seconds: 10));

      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // NEW: Backward compatibility - sendMessage without userId (will try to get from Hive)
  static Future<Map<String, dynamic>> sendMessageWithoutUser(
    String message,
  ) async {
    return await sendMessage(message);
  }
}
