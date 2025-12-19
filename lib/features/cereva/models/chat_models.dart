import 'package:hive/hive.dart';

part 'chat_models.g.dart';

@HiveType(typeId: 0)
class ChatSession {
  @HiveField(0)
  String id;
  
  @HiveField(1)
  String title;
  
  @HiveField(2)
  DateTime createdAt;
  
  @HiveField(3)
  DateTime updatedAt;
  
  @HiveField(4)
  List<ChatMessage> messages;
  
  @HiveField(5)
  String? backendSessionId;

  ChatSession({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    required this.messages,
    this.backendSessionId,
  });
}

@HiveType(typeId: 1)
class ChatMessage {
  @HiveField(0)
  final String text;
  
  @HiveField(1)
  final bool isUser;
  
  @HiveField(2)
  final DateTime timestamp;
  
  @HiveField(3)
  final String? source;
  
  @HiveField(4)
  final bool isError;

  ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.source,
    this.isError = false,
  });
}