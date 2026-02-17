// lib/features/ai_chat/screens/ai_chat_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:markdown/markdown.dart' as md;
import '../services/chat_service.dart';
import '../models/chat_models.dart';

class AIChatScreen extends StatefulWidget {
  final String? initialQuestion;
  const AIChatScreen({super.key, this.initialQuestion});

  @override
  State<AIChatScreen> createState() => _AIChatScreenState();
}

class _AIChatScreenState extends State<AIChatScreen> {
  final List<Map<String, dynamic>> _chatMessages = [];
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isLoading = false;
  bool _showSidebar = false;
  int _editingMessageIndex = -1;
  bool _hasReachedMax = false;
  String _currentSessionId = '';

  final List<Map<String, dynamic>> _courses = [
    {
      'title': 'Mathematics',
      'icon': Icons.functions,
      'color': Color(0xFF6366F1),
    },
    {'title': 'Physics', 'icon': Icons.bolt, 'color': Color(0xFF8B5CF6)},
    {'title': 'Chemistry', 'icon': Icons.science, 'color': Color(0xFF10B981)},
    {'title': 'Biology', 'icon': Icons.psychology, 'color': Color(0xFFF59E0B)},
    {
      'title': 'Computer Science',
      'icon': Icons.code,
      'color': Color(0xFFEF4444),
    },
    {'title': 'English', 'icon': Icons.menu_book, 'color': Color(0xFF06B6D4)},
    {'title': 'History', 'icon': Icons.public, 'color': Color(0xFF84CC16)},
    {'title': 'Geography', 'icon': Icons.map, 'color': Color(0xFFF97316)},
  ];

  List<ChatSession> _chatHistory = [];

  @override
  void initState() {
    super.initState();
    _initializeChat();
  }

  Future<void> _initializeChat() async {
    await ChatService.initHive();
    _loadChatHistory();
    _getCurrentSessionId();

    if (widget.initialQuestion != null) {
      _addUserMessage(widget.initialQuestion!);
      _generateAIResponse(widget.initialQuestion!);
    } else {
      await _loadCurrentSessionMessages();
    }
  }

  Future<void> _getCurrentSessionId() async {
    _currentSessionId = await ChatService.getSessionId();
  }

  Future<void> _loadCurrentSessionMessages() async {
    try {
      final messages = await ChatService.getSessionMessages(_currentSessionId);
      if (messages.isNotEmpty) {
        setState(() {
          _chatMessages.clear();
          for (final message in messages) {
            _chatMessages.add({
              'text': message.text,
              'isUser': message.isUser,
              'source': message.source,
              'isError': message.isError,
            });
          }
        });
        _scrollToBottom();
      }
    } catch (e) {
      print('Error loading current session messages: $e');
    }
  }

  Future<void> _loadChatHistory() async {
    try {
      final history = await ChatService.getChatHistory();
      setState(() {
        _chatHistory = history;
      });
    } catch (e) {
      print('Error loading chat history: $e');
    }
  }

  void _addUserMessage(String message) {
    setState(() {
      _chatMessages.add({'text': message, 'isUser': true});
    });
    _scrollToBottom();
  }

  void _generateAIResponse(String userMessage) async {
    setState(() {
      _isLoading = true;
      _hasReachedMax = false;
    });

    try {
      final response = await ChatService.sendMessage(userMessage);

      setState(() {
        _isLoading = false;

        if (response['success']) {
          _chatMessages.add({
            'text': response['reply'],
            'isUser': false,
            'source': response['source'] ?? 'llm_model',
          });
        } else {
          if (response['error'] == 'daily_limit_exceeded') {
            _chatMessages.add({
              'text':
                  response['message'] ??
                  'Daily message limit reached. Please try again tomorrow.',
              'isUser': false,
              'isError': true,
              'isLimitReached': true,
            });
          } else {
            if (response['error']?.toString().contains('maximum') == true) {
              _hasReachedMax = true;
            }
            _chatMessages.add({
              'text':
                  'Sorry, I encountered an error, check your network and try again',
              'isUser': false,
              'isError': true,
            });
          }
        }
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        if (e.toString().contains('maximum')) {
          _hasReachedMax = true;
        }
        _chatMessages.add({
          'text': 'Network error: Please check your connection and try again.',
          'isUser': false,
          'isError': true,
        });
      });
    }

    _scrollToBottom();
    _loadChatHistory();
    _getCurrentSessionId();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Copied to clipboard'),
        backgroundColor: Color(0xFF10B981),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _editMessage(int index) {
    setState(() {
      _editingMessageIndex = index;
      _messageController.text = _chatMessages[index]['text'];
    });
  }

  void _sendEditedMessage() {
    if (_messageController.text.trim().isNotEmpty &&
        _editingMessageIndex != -1) {
      setState(() {
        _chatMessages[_editingMessageIndex]['text'] = _messageController.text;
        _editingMessageIndex = -1;
      });
      _messageController.clear();
      _generateAIResponse(_messageController.text);
    }
  }

  Future<void> _startNewChat() async {
    await ChatService.startNewChat();
    setState(() {
      _chatMessages.clear();
      _showSidebar = false;
      _hasReachedMax = false;
    });
    _loadChatHistory();
    _getCurrentSessionId();
  }

  Future<void> _loadChatSession(String sessionId) async {
    try {
      final messages = await ChatService.loadChatSession(sessionId);
      setState(() {
        _chatMessages.clear();
        for (final message in messages) {
          _chatMessages.add({
            'text': message.text,
            'isUser': message.isUser,
            'source': message.source,
            'isError': message.isError,
          });
        }
        _showSidebar = false;
        _hasReachedMax = false;
      });
      _scrollToBottom();
      _getCurrentSessionId();
    } catch (e) {
      print('Error loading chat session: $e');
      setState(() {
        _chatMessages.clear();
        _chatMessages.add({
          'text': 'Error loading previous conversation. Starting new chat...',
          'isUser': false,
          'isError': true,
        });
      });
    }
  }

  Widget _buildWelcomeSection() {
    return Column(
      children: [
        const SizedBox(height: 40),
        Container(
          width: 80,
          height: 80,
          child: Icon(
            Icons.auto_awesome_rounded,
            color: Color(0xFF6366F1),
            size: 60,
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          'Hi, I\'m Cerenix AI',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1A1A2E),
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'How can I help you today?',
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
        const SizedBox(height: 40),
      ],
    );
  }

  Widget _buildCourseChips() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          _buildWelcomeSection(),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            alignment: WrapAlignment.center,
            children: _courses
                .map((course) => _buildCourseChip(course))
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildCourseChip(Map<String, dynamic> course) {
    return FilterChip(
      label: Text(
        course['title'],
        style: TextStyle(color: course['color'], fontWeight: FontWeight.w500),
      ),
      avatar: Icon(course['icon'], color: course['color'], size: 18),
      backgroundColor: course['color'].withOpacity(0.1),
      selectedColor: course['color'].withOpacity(0.2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      onSelected: (selected) {
        _addUserMessage("Help with ${course['title']}");
        _generateAIResponse("${course['title']} concepts");
      },
    );
  }

  Widget _buildSidebar() {
    return GestureDetector(
      onTap: () => setState(() => _showSidebar = false),
      child: Container(
        color: Colors.black54,
        child: Align(
          alignment: Alignment.centerRight,
          child: GestureDetector(
            onTap: () {},
            child: Container(
              width: MediaQuery.of(context).size.width * 0.75,
              height: double.infinity,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20),
                  bottomLeft: Radius.circular(20),
                ),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        const Text(
                          'Chat History',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => setState(() => _showSidebar = false),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Expanded(
                    child: _chatHistory.isEmpty
                        ? _buildEmptyHistory()
                        : ListView(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            children: [..._buildHistorySections()],
                          ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(20),
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.add_rounded, size: 20),
                      label: const Text('New Chat'),
                      onPressed: _startNewChat,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6366F1),
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyHistory() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history_rounded, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            'No chat history',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade500,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Start a new conversation to see it here',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade400),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  List<Widget> _buildHistorySections() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final lastWeek = today.subtract(const Duration(days: 7));

    List<ChatSession> todayChats = [];
    List<ChatSession> yesterdayChats = [];
    List<ChatSession> last7DaysChats = [];
    List<ChatSession> olderChats = [];

    for (final chat in _chatHistory) {
      final chatDate = DateTime(
        chat.updatedAt.year,
        chat.updatedAt.month,
        chat.updatedAt.day,
      );

      if (chatDate == today) {
        todayChats.add(chat);
      } else if (chatDate == yesterday) {
        yesterdayChats.add(chat);
      } else if (chatDate.isAfter(lastWeek)) {
        last7DaysChats.add(chat);
      } else {
        olderChats.add(chat);
      }
    }

    final sections = <Widget>[];

    if (todayChats.isNotEmpty) {
      sections.add(_buildHistorySection('Today', todayChats));
    }
    if (yesterdayChats.isNotEmpty) {
      sections.add(_buildHistorySection('Yesterday', yesterdayChats));
    }
    if (last7DaysChats.isNotEmpty) {
      sections.add(_buildHistorySection('Previous 7 days', last7DaysChats));
    }
    if (olderChats.isNotEmpty) {
      sections.add(_buildHistorySection('Older', olderChats));
    }

    return sections;
  }

  Widget _buildHistorySection(String title, List<ChatSession> chats) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.grey,
            ),
          ),
        ),
        ...chats
            .map(
              (chat) => Container(
                margin: const EdgeInsets.only(bottom: 4),
                child: ListTile(
                  leading: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: chat.id == _currentSessionId
                          ? Colors.green
                          : Colors.transparent,
                      shape: BoxShape.circle,
                    ),
                  ),
                  title: Text(
                    chat.title,
                    style: TextStyle(
                      fontWeight: chat.id == _currentSessionId
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                  subtitle: Text(
                    '${chat.messages.length} messages • ${_formatDate(chat.updatedAt)}',
                    style: TextStyle(
                      color: chat.id == _currentSessionId
                          ? Colors.green
                          : Colors.grey.shade500,
                      fontSize: 12,
                    ),
                  ),
                  onTap: () => _loadChatSession(chat.id),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  tileColor: chat.id == _currentSessionId
                      ? Colors.green.withOpacity(0.1)
                      : null,
                ),
              ),
            )
            .toList(),
        const SizedBox(height: 16),
      ],
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) return 'Today';
    if (difference.inDays == 1) return 'Yesterday';
    if (difference.inDays < 7) return '${difference.inDays} days ago';
    if (difference.inDays < 30) return '${difference.inDays ~/ 7} weeks ago';
    return '${difference.inDays ~/ 30} months ago';
  }

  Widget _buildMessageBubble(Map<String, dynamic> message, int index) {
    final isUser = message['isUser'];
    final isError = message['isError'] ?? false;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: isUser
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        children: [
          if (!isUser)
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: isError ? Colors.red : const Color(0xFF6366F1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isError ? Icons.error_rounded : Icons.smart_toy_rounded,
                color: Colors.white,
                size: 16,
              ),
            ),
          if (!isUser) const SizedBox(width: 8),
          Flexible(
            child: Column(
              crossAxisAlignment: isUser
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                Container(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.75,
                  ),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isUser
                        ? const Color(0xFF6366F1)
                        : isError
                        ? Colors.red.shade50
                        : Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: isUser
                      ? SelectableText(
                          message['text'],
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            height: 1.4,
                          ),
                        )
                      : _buildAIResponse(message['text'], isError),
                ),
                const SizedBox(height: 4),
                if (isUser)
                  GestureDetector(
                    onTap: () => _editMessage(index),
                    child: Icon(
                      Icons.edit_rounded,
                      color: Colors.grey.shade500,
                      size: 16,
                    ),
                  ),
                if (!isUser && !isError)
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () => _copyToClipboard(message['text']),
                        child: Icon(
                          Icons.content_copy_rounded,
                          color: Colors.grey.shade500,
                          size: 16,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Copy',
                        style: TextStyle(
                          color: Colors.grey.shade500,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          if (isUser) const SizedBox(width: 8),
        ],
      ),
    );
  }

  Widget _buildAIResponse(String text, bool isError) {
    if (isError) {
      return SelectableText(
        text,
        style: const TextStyle(color: Colors.red, fontSize: 15, height: 1.4),
      );
    }

    return MathMarkdownBody(data: text, onCopyCode: _copyToClipboard);
  }

  Widget _buildLoadingIndicator() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: const BoxDecoration(
              color: Color(0xFF6366F1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.smart_toy_rounded,
              color: Colors.white,
              size: 16,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                _buildTypingDots(),
                const SizedBox(width: 12),
                Text(
                  'Cerenix AI is thinking...',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypingDots() {
    return SizedBox(
      width: 40,
      height: 20,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildAnimatedDot(0),
          _buildAnimatedDot(1),
          _buildAnimatedDot(2),
        ],
      ),
    );
  }

  Widget _buildAnimatedDot(int index) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 2),
      width: 6,
      height: 6,
      decoration: BoxDecoration(
        color: Colors.grey.shade600,
        shape: BoxShape.circle,
      ),
    );
  }

  Widget _buildMaxMessagesWarning() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        border: Border(top: BorderSide(color: Colors.orange.shade200)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(
                Icons.warning_amber_rounded,
                color: Colors.orange.shade700,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'This chat has reached the maximum message limit',
                  style: TextStyle(
                    color: Colors.orange.shade800,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Start New Chat'),
              onPressed: _startNewChat,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6366F1),
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatInput() {
    if (_hasReachedMax) {
      return _buildMaxMessagesWarning();
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              constraints: BoxConstraints(maxHeight: 120),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(25),
              ),
              child: TextField(
                controller: _messageController,
                maxLines: null,
                keyboardType: TextInputType.multiline,
                decoration: InputDecoration(
                  hintText: _editingMessageIndex != -1
                      ? 'Edit your message...'
                      : 'Message Cerenix AI...',
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  hintStyle: TextStyle(color: Colors.grey.shade500),
                ),
                onSubmitted: (value) => _sendMessage(),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFF6366F1),
              borderRadius: BorderRadius.circular(24),
            ),
            child: IconButton(
              icon: Icon(
                _editingMessageIndex != -1
                    ? Icons.check_rounded
                    : Icons.north_east_rounded,
                color: Colors.white,
                size: 20,
              ),
              onPressed: _sendMessage,
            ),
          ),
        ],
      ),
    );
  }

  void _sendMessage() {
    final message = _messageController.text.trim();
    if (message.isNotEmpty && !_hasReachedMax) {
      if (_editingMessageIndex != -1) {
        _sendEditedMessage();
      } else {
        _addUserMessage(message);
        _generateAIResponse(message);
        _messageController.clear();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Cerenix AI',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1A1A2E),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.dehaze_rounded),
            onPressed: () => setState(() => _showSidebar = !_showSidebar),
          ),
        ],
      ),
      body: GestureDetector(
        onHorizontalDragUpdate: (details) {
          if (details.delta.dx > 10) {
            setState(() => _showSidebar = true);
          } else if (details.delta.dx < -10) {
            setState(() => _showSidebar = false);
          }
        },
        child: Stack(
          children: [
            Column(
              children: [
                Expanded(
                  child: _chatMessages.isEmpty
                      ? SingleChildScrollView(child: _buildCourseChips())
                      : ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.only(bottom: 8),
                          itemCount:
                              _chatMessages.length + (_isLoading ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (index == _chatMessages.length && _isLoading) {
                              return _buildLoadingIndicator();
                            }
                            return _buildMessageBubble(
                              _chatMessages[index],
                              index,
                            );
                          },
                        ),
                ),
                _buildChatInput(),
              ],
            ),
            if (_showSidebar) _buildSidebar(),
          ],
        ),
      ),
    );
  }
}

class MathMarkdownBody extends StatelessWidget {
  final String data;
  final Function(String) onCopyCode;

  const MathMarkdownBody({
    super.key,
    required this.data,
    required this.onCopyCode,
  });

  String _preprocessMath(String text) {
    return text.replaceAllMapped(
      RegExp(r'\$\$([^\$]+)\$\$'),
      (match) => '\$${match.group(1)}\$',
    );
  }

  @override
  Widget build(BuildContext context) {
    final processedData = _preprocessMath(data);

    return MarkdownBody(
      data: processedData,
      styleSheet: MarkdownStyleSheet(
        p: const TextStyle(fontSize: 15, height: 1.6, color: Colors.black87),
        strong: const TextStyle(
          fontWeight: FontWeight.bold,
          color: Colors.black87,
        ),
        em: const TextStyle(fontStyle: FontStyle.italic, color: Colors.black87),
        h1: const TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: Colors.black87,
        ),
        h2: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Colors.black87,
        ),
        h3: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Colors.black87,
        ),
        h4: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Colors.black87,
        ),
        blockquote: TextStyle(
          color: Colors.grey.shade700,
          fontStyle: FontStyle.italic,
          backgroundColor: Colors.grey.shade100,
        ),
        code: TextStyle(
          backgroundColor: Colors.grey.shade200,
          color: Colors.black87,
          fontFamily: 'Monospace',
          fontSize: 14,
        ),
        codeblockPadding: const EdgeInsets.all(16),
        codeblockDecoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
        ),
        listBullet: const TextStyle(fontSize: 15, color: Colors.black87),
        tableBody: const TextStyle(fontSize: 15, color: Colors.black87),
        tableHead: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.bold,
          color: Colors.black87,
        ),
      ),
      builders: {
        'code': CodeElementBuilder(onCopy: onCopyCode),
        'math': MathElementBuilder(),
      },
      onTapLink: (text, href, title) {
        if (href != null) {
          _launchUrl(href);
        }
      },
      extensionSet:
          md.ExtensionSet(md.ExtensionSet.gitHubFlavored.blockSyntaxes, [
            md.EmojiSyntax(),
            ...md.ExtensionSet.gitHubFlavored.inlineSyntaxes,
            InlineMathSyntax(),
          ]),
    );
  }

  Future<void> _launchUrl(String url) async {
    final Uri uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }
}

class CodeElementBuilder extends MarkdownElementBuilder {
  final Function(String) onCopy;

  CodeElementBuilder({required this.onCopy});

  @override
  Widget? visitElementAfter(md.Element element, TextStyle? preferredStyle) {
    final codeContent = element.textContent;
    final lines = codeContent.split('\n').length;
    final isMultiLine = lines > 5;

    return Container(
      width: double.infinity,
      constraints: isMultiLine
          ? BoxConstraints(maxHeight: 300)
          : BoxConstraints(),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        mainAxisSize: isMultiLine ? MainAxisSize.min : MainAxisSize.max,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(8),
                topRight: Radius.circular(8),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Code',
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                GestureDetector(
                  onTap: () => onCopy(codeContent),
                  child: Row(
                    children: [
                      Icon(
                        Icons.content_copy,
                        size: 14,
                        color: Colors.grey.shade700,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Copy',
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (isMultiLine)
            Expanded(
              child: Scrollbar(
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: SelectableText(
                      codeContent,
                      style: preferredStyle?.copyWith(
                        fontFamily: 'Monospace',
                        fontSize: 14,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                ),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.all(16),
              child: SelectableText(
                codeContent,
                style: preferredStyle?.copyWith(
                  fontFamily: 'Monospace',
                  fontSize: 14,
                  color: Colors.black87,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class MathElementBuilder extends MarkdownElementBuilder {
  @override
  Widget? visitElementAfter(md.Element element, TextStyle? preferredStyle) {
    String mathContent = element.textContent;

    mathContent = mathContent.trim();
    bool needsWrapping = mathContent.length > 40;

    try {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.blue.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.blue.shade200),
        ),
        child: needsWrapping
            ? _buildWrappedMath(mathContent)
            : _buildSingleLineMath(mathContent),
      );
    } catch (e) {
      return _buildMathFallback(mathContent, needsWrapping);
    }
  }

  Widget _buildSingleLineMath(String mathContent) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 300),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Math.tex(
            mathContent,
            textStyle: TextStyle(fontSize: 18, color: Colors.blue.shade900),
            onErrorFallback: (FlutterMathException e) {
              return _buildMathFallback(mathContent, false);
            },
          ),
        ),
      ),
    );
  }

  Widget _buildWrappedMath(String mathContent) {
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: 120),
      child: Scrollbar(
        thumbVisibility: true,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Math.tex(
            mathContent,
            textStyle: TextStyle(fontSize: 16, color: Colors.blue.shade900),
            onErrorFallback: (FlutterMathException e) {
              return _buildMathFallback(mathContent, true);
            },
          ),
        ),
      ),
    );
  }

  Widget _buildMathFallback(String mathContent, bool isWrapped) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: isWrapped
          ? ConstrainedBox(
              constraints: BoxConstraints(maxHeight: 80),
              child: Scrollbar(
                thumbVisibility: true,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SelectableText(
                    mathContent,
                    style: TextStyle(
                      fontFamily: 'Monospace',
                      color: Colors.red.shade800,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            )
          : ConstrainedBox(
              constraints: BoxConstraints(maxWidth: 300),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: SelectableText(
                  mathContent,
                  style: TextStyle(
                    fontFamily: 'Monospace',
                    color: Colors.red.shade800,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
    );
  }
}

class InlineMathSyntax extends md.InlineSyntax {
  InlineMathSyntax() : super(r'\$([^\$]+)\$');

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    parser.addNode(md.Element('math', [md.Text(match.group(1)!)]));
    return true;
  }
}
