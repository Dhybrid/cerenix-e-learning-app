import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/chat_models.dart';

class ChatStorageService {
  static const String _chatBoxName = 'chat_sessions';
  static const String _currentSessionKey = 'current_session';
  
  static late Box<ChatSession> _chatBox;
  static bool _isInitialized = false;

  static Future<void> init() async {
    if (!_isInitialized) {
      _chatBox = await Hive.openBox<ChatSession>(_chatBoxName);
      _isInitialized = true;
    }
  }

  static Future<ChatSession> createNewChat(String firstMessage) async {
    await init();
    
    final sessionId = DateTime.now().millisecondsSinceEpoch.toString();
    final backendSessionId = 'session_$sessionId';
    
    final session = ChatSession(
      id: sessionId,
      title: firstMessage.length > 30 ? '${firstMessage.substring(0, 30)}...' : firstMessage,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      messages: [],
      backendSessionId: backendSessionId,
    );

    await _chatBox.put(sessionId, session);
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_currentSessionKey, sessionId);
    
    return session;
  }

  static Future<ChatSession?> getCurrentSession() async {
    await init();
    
    final prefs = await SharedPreferences.getInstance();
    final sessionId = prefs.getString(_currentSessionKey);
    
    if (sessionId != null) {
      return _chatBox.get(sessionId);
    }
    return null;
  }

  static Future<void> addMessageToCurrentSession(ChatMessage message) async {
    await init();
    
    final session = await getCurrentSession();
    if (session != null) {
      session.messages.add(message);
      session.updatedAt = DateTime.now();
      await _chatBox.put(session.id, session);
    }
  }

  static Future<List<ChatSession>> getAllChats() async {
    await init();
    
    final chats = _chatBox.values.toList();
    chats.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return chats;
  }

  static Future<void> loadChat(String sessionId) async {
    await init();
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_currentSessionKey, sessionId);
  }

  static Future<void> clearCurrentSession() async {
    await init();
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_currentSessionKey);
  }

  static Future<void> deleteChat(String sessionId) async {
    await init();
    
    final currentSession = await getCurrentSession();
    if (currentSession?.id == sessionId) {
      await clearCurrentSession();
    }
    
    await _chatBox.delete(sessionId);
  }

  static Future<void> clearAllChats() async {
    await init();
    await clearCurrentSession();
    await _chatBox.clear();
  }
}