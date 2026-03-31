// lib/features/ai_chat/screens/ai_chat_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:markdown/markdown.dart' as md;
import '../../../core/utils/latex_render_utils.dart';
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
  Timer? _responseStreamTimer;
  bool _isLoading = false;
  bool _showSidebar = false;
  int _editingMessageIndex = -1;
  bool _hasReachedMax = false;
  bool _isNearChatBottom = true;
  bool _showJumpToLatest = false;
  String _currentSessionId = '';

  bool get _isDark => Theme.of(context).brightness == Brightness.dark;
  Color get _pageBackground =>
      _isDark ? const Color(0xFF09111F) : const Color(0xFFF8FAFC);
  Color get _surfaceColor => _isDark ? const Color(0xFF101A2B) : Colors.white;
  Color get _secondarySurfaceColor =>
      _isDark ? const Color(0xFF162235) : const Color(0xFFF8FAFC);
  Color get _titleColor =>
      _isDark ? const Color(0xFFF8FAFC) : const Color(0xFF1A1A2E);
  Color get _bodyColor =>
      _isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569);
  Color get _mutedColor =>
      _isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
  Color get _borderColor =>
      _isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE2E8F0);

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
    _scrollController.addListener(_handleScrollChange);
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

  @override
  void dispose() {
    _responseStreamTimer?.cancel();
    _messageController.dispose();
    _scrollController.removeListener(_handleScrollChange);
    _scrollController.dispose();
    super.dispose();
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
          _startStreamingAssistantResponse(
            response['reply']?.toString() ?? '',
            source: response['source']?.toString() ?? 'llm_model',
          );
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

  void _startStreamingAssistantResponse(String text, {String? source}) {
    final safeText = text.trim();
    final messageIndex = _chatMessages.length;

    setState(() {
      _chatMessages.add({
        'text': '',
        'isUser': false,
        'source': source ?? 'llm_model',
        'isStreaming': true,
      });
    });

    if (safeText.isEmpty) {
      setState(() {
        _chatMessages[messageIndex]['isStreaming'] = false;
      });
      return;
    }

    _responseStreamTimer?.cancel();
    int currentLength = 0;
    final chunkSize = safeText.length > 1200
        ? 14
        : safeText.length > 600
        ? 10
        : 6;

    _responseStreamTimer = Timer.periodic(const Duration(milliseconds: 18), (
      timer,
    ) {
      if (!mounted || messageIndex >= _chatMessages.length) {
        timer.cancel();
        return;
      }

      currentLength = (currentLength + chunkSize).clamp(0, safeText.length);

      setState(() {
        _chatMessages[messageIndex]['text'] = safeText.substring(
          0,
          currentLength,
        );
        _chatMessages[messageIndex]['isStreaming'] =
            currentLength < safeText.length;
      });

      _scrollToBottom();

      if (currentLength >= safeText.length) {
        timer.cancel();
        _scrollToBottom(force: true, animated: true);
      }
    });
  }

  bool get _hasActiveStreamingMessage =>
      _isLoading ||
      _chatMessages.any((message) => message['isStreaming'] == true);

  bool _isAtBottom({double threshold = 88}) {
    if (!_scrollController.hasClients) return true;
    final position = _scrollController.position;
    return (position.maxScrollExtent - position.pixels) <= threshold;
  }

  void _handleScrollChange() {
    if (!_scrollController.hasClients) return;

    final isNearBottom = _isAtBottom();
    final showJump = _hasActiveStreamingMessage && !isNearBottom;

    if (isNearBottom != _isNearChatBottom || showJump != _showJumpToLatest) {
      setState(() {
        _isNearChatBottom = isNearBottom;
        _showJumpToLatest = showJump;
      });
    }
  }

  void _scrollToBottom({bool force = false, bool animated = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        if (!force && !_isNearChatBottom) return;

        final target = _scrollController.position.maxScrollExtent;
        if ((target - _scrollController.position.pixels).abs() < 1) return;

        if (animated && !_hasActiveStreamingMessage) {
          _scrollController.animateTo(
            target,
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
          );
        } else {
          _scrollController.jumpTo(target);
        }
      }
    });
  }

  void _jumpToLatest() {
    setState(() {
      _isNearChatBottom = true;
      _showJumpToLatest = false;
    });
    _scrollToBottom(force: true, animated: true);
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
    final editedText = _messageController.text.trim();
    if (editedText.isNotEmpty && _editingMessageIndex != -1) {
      setState(() {
        _chatMessages[_editingMessageIndex]['text'] = editedText;
        _editingMessageIndex = -1;
      });
      _messageController.clear();
      _generateAIResponse(editedText);
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
        Text(
          'Hi, I\'m Cerenix AI',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: _titleColor,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'How can I help you today?',
          style: TextStyle(fontSize: 16, color: _bodyColor),
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
      backgroundColor: _isDark
          ? course['color'].withOpacity(0.18)
          : course['color'].withOpacity(0.1),
      selectedColor: course['color'].withOpacity(_isDark ? 0.28 : 0.2),
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
        color: Colors.black.withValues(alpha: 0.58),
        child: Align(
          alignment: Alignment.centerRight,
          child: GestureDetector(
            onTap: () {},
            child: Container(
              width: MediaQuery.of(context).size.width * 0.75,
              height: double.infinity,
              decoration: BoxDecoration(
                color: _surfaceColor,
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
                        Text(
                          'Chat History',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: _titleColor,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: Icon(Icons.close_rounded, color: _bodyColor),
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
              color: _bodyColor,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Start a new conversation to see it here',
            style: TextStyle(fontSize: 14, color: _mutedColor),
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
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: _mutedColor,
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
                      color: _titleColor,
                    ),
                  ),
                  subtitle: Text(
                    '${chat.messages.length} messages • ${_formatDate(chat.updatedAt)}',
                    style: TextStyle(
                      color: chat.id == _currentSessionId
                          ? Colors.green
                          : _mutedColor,
                      fontSize: 12,
                    ),
                  ),
                  onTap: () => _loadChatSession(chat.id),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  tileColor: chat.id == _currentSessionId
                      ? Colors.green.withOpacity(_isDark ? 0.18 : 0.1)
                      : _secondarySurfaceColor,
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
    final isStreaming = message['isStreaming'] ?? false;

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
                        ? (_isDark
                              ? Colors.red.withOpacity(0.14)
                              : Colors.red.shade50)
                        : _surfaceColor,
                    border: isUser ? null : Border.all(color: _borderColor),
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
                      : isStreaming
                      ? SelectableText(
                          '${message['text']}▋',
                          style: TextStyle(
                            color: _titleColor,
                            fontSize: 15,
                            height: 1.55,
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
                      color: _mutedColor,
                      size: 16,
                    ),
                  ),
                if (!isUser && !isError && !isStreaming)
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () => _copyToClipboard(message['text']),
                        child: Icon(
                          Icons.content_copy_rounded,
                          color: _mutedColor,
                          size: 16,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Copy',
                        style: TextStyle(color: _mutedColor, fontSize: 12),
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

    return MathMarkdownBody(
      data: text,
      onCopyCode: _copyToClipboard,
      isDark: _isDark,
    );
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
              color: _surfaceColor,
              border: Border.all(color: _borderColor),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                _buildTypingDots(),
                const SizedBox(width: 12),
                Text(
                  'Cerenix AI is thinking...',
                  style: TextStyle(color: _bodyColor, fontSize: 14),
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
      decoration: BoxDecoration(color: _bodyColor, shape: BoxShape.circle),
    );
  }

  Widget _buildMaxMessagesWarning() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _isDark
            ? Colors.orange.withOpacity(0.12)
            : Colors.orange.shade50,
        border: Border(
          top: BorderSide(
            color: _isDark
                ? Colors.orange.withOpacity(0.24)
                : Colors.orange.shade200,
          ),
        ),
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
        color: _surfaceColor,
        border: Border(top: BorderSide(color: _borderColor)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              constraints: BoxConstraints(maxHeight: 120),
              decoration: BoxDecoration(
                color: _secondarySurfaceColor,
                borderRadius: BorderRadius.circular(25),
              ),
              child: TextField(
                controller: _messageController,
                maxLines: null,
                keyboardType: TextInputType.multiline,
                style: TextStyle(color: _titleColor),
                decoration: InputDecoration(
                  hintText: _editingMessageIndex != -1
                      ? 'Edit your message...'
                      : 'Message Cerenix AI...',
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  hintStyle: TextStyle(color: _mutedColor),
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
      backgroundColor: _pageBackground,
      appBar: AppBar(
        title: Text(
          'Cerenix AI',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: _titleColor,
          ),
        ),
        backgroundColor: _surfaceColor,
        surfaceTintColor: Colors.transparent,
        foregroundColor: _titleColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_rounded,
            size: 20,
            color: _titleColor,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.dehaze_rounded, color: _titleColor),
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
            if (_showJumpToLatest)
              Positioned(
                right: 16,
                bottom: 88,
                child: SafeArea(
                  top: false,
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _jumpToLatest,
                      borderRadius: BorderRadius.circular(999),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: _surfaceColor.withValues(alpha: 0.96),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: _borderColor),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.14),
                              blurRadius: 18,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.arrow_downward_rounded,
                              size: 16,
                              color: _titleColor,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Latest',
                              style: TextStyle(
                                color: _titleColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
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
  final bool isDark;

  const MathMarkdownBody({
    super.key,
    required this.data,
    required this.onCopyCode,
    required this.isDark,
  });

  String _preprocessMath(String text) {
    final normalized = LatexRenderUtils.sanitizeStoredMathTags(text);
    return normalized.replaceAllMapped(
      RegExp(r'\$\$([\s\S]+?)\$\$', dotAll: true),
      (match) => '\$${match.group(1)}\$',
    );
  }

  @override
  Widget build(BuildContext context) {
    final processedData = _preprocessMath(data);
    final textColor = isDark
        ? const Color(0xFFF8FAFC)
        : const Color(0xFF111827);
    final bodyColor = isDark
        ? const Color(0xFFCBD5E1)
        : const Color(0xFF475569);
    final surface = isDark ? const Color(0xFF162235) : Colors.grey.shade100;
    final altSurface = isDark ? const Color(0xFF1E293B) : Colors.grey.shade200;
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.grey.shade300;
    final mathSurface = isDark
        ? Colors.blue.withOpacity(0.12)
        : Colors.blue.shade50;
    final mathBorder = isDark
        ? Colors.blue.withOpacity(0.22)
        : Colors.blue.shade200;
    final mathText = isDark ? const Color(0xFFBFDBFE) : Colors.blue.shade900;

    return MarkdownBody(
      data: processedData,
      styleSheet: MarkdownStyleSheet(
        p: TextStyle(fontSize: 15, height: 1.6, color: textColor),
        strong: TextStyle(fontWeight: FontWeight.bold, color: textColor),
        em: TextStyle(fontStyle: FontStyle.italic, color: textColor),
        h1: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: textColor,
        ),
        h2: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: textColor,
        ),
        h3: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: textColor,
        ),
        h4: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: textColor,
        ),
        blockquote: TextStyle(
          color: bodyColor,
          fontStyle: FontStyle.italic,
          backgroundColor: surface,
        ),
        code: TextStyle(
          backgroundColor: altSurface,
          color: textColor,
          fontFamily: 'Monospace',
          fontSize: 14,
        ),
        codeblockPadding: const EdgeInsets.all(16),
        codeblockDecoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: borderColor),
        ),
        listBullet: TextStyle(fontSize: 15, color: textColor),
        tableBody: TextStyle(fontSize: 15, color: textColor),
        tableHead: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.bold,
          color: textColor,
        ),
      ),
      builders: {
        'code': CodeElementBuilder(onCopy: onCopyCode, isDark: isDark),
        'math': MathElementBuilder(
          isDark: isDark,
          mathSurface: mathSurface,
          mathBorder: mathBorder,
          mathText: mathText,
        ),
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
  final bool isDark;

  CodeElementBuilder({required this.onCopy, required this.isDark});

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
        color: isDark ? const Color(0xFF162235) : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.grey.shade300,
        ),
      ),
      child: Column(
        mainAxisSize: isMultiLine ? MainAxisSize.min : MainAxisSize.max,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.grey.shade200,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(8),
                topRight: Radius.circular(8),
              ),
            ),
            child: Wrap(
              spacing: 12,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  'Code',
                  style: TextStyle(
                    color: isDark
                        ? const Color(0xFFCBD5E1)
                        : Colors.grey.shade700,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                GestureDetector(
                  onTap: () => onCopy(codeContent),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.content_copy,
                        size: 14,
                        color: isDark
                            ? const Color(0xFFCBD5E1)
                            : Colors.grey.shade700,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Copy',
                        style: TextStyle(
                          color: isDark
                              ? const Color(0xFFCBD5E1)
                              : Colors.grey.shade700,
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
                        color: isDark
                            ? const Color(0xFFF8FAFC)
                            : Colors.black87,
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
                  color: isDark ? const Color(0xFFF8FAFC) : Colors.black87,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class MathElementBuilder extends MarkdownElementBuilder {
  final bool isDark;
  final Color mathSurface;
  final Color mathBorder;
  final Color mathText;

  MathElementBuilder({
    required this.isDark,
    required this.mathSurface,
    required this.mathBorder,
    required this.mathText,
  });

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
          color: mathSurface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: mathBorder),
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
            textStyle: TextStyle(fontSize: 18, color: mathText),
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
            textStyle: TextStyle(fontSize: 16, color: mathText),
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
        color: isDark ? Colors.red.withOpacity(0.14) : Colors.red.shade50,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: isDark ? Colors.red.withOpacity(0.22) : Colors.red.shade200,
        ),
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
