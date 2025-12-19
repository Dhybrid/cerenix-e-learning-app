// lib/features/ai_chat/screens/simple_ai_chat_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class SimpleAIChatScreen extends StatefulWidget {
  final String? initialQuestion;
  const SimpleAIChatScreen({super.key, this.initialQuestion});

  @override
  State<SimpleAIChatScreen> createState() => _SimpleAIChatScreenState();
}

class _SimpleAIChatScreenState extends State<SimpleAIChatScreen> {
  final List<Map<String, dynamic>> _chatMessages = [];
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isLoading = false;
  int _editingMessageIndex = -1;

  @override
  void initState() {
    super.initState();
    if (widget.initialQuestion != null) {
      _addUserMessage(widget.initialQuestion!);
      _generateAIResponse(widget.initialQuestion!);
    }
  }

  void _addUserMessage(String message) {
    setState(() {
      _chatMessages.add({'text': message, 'isUser': true});
    });
    _scrollToBottom();
  }

  void _generateAIResponse(String userMessage) {
    setState(() => _isLoading = true);
    Future.delayed(const Duration(seconds: 1), () {
      setState(() {
        _isLoading = false;
        _chatMessages.add({
          'text': 'I understand you\'re asking about **$userMessage**. Let me provide you with a comprehensive explanation...',
          'isUser': false
        });
      });
      _scrollToBottom();
    });
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
      const SnackBar(content: Text('Copied to clipboard'), backgroundColor: Color(0xFF10B981)),
    );
  }

  void _editMessage(int index) {
    setState(() {
      _editingMessageIndex = index;
      _messageController.text = _chatMessages[index]['text'];
    });
  }

  void _sendEditedMessage() {
    if (_messageController.text.trim().isNotEmpty && _editingMessageIndex != -1) {
      setState(() {
        _chatMessages[_editingMessageIndex]['text'] = _messageController.text;
        _editingMessageIndex = -1;
      });
      _messageController.clear();
      _generateAIResponse(_messageController.text);
    }
  }

  Widget _buildMessageBubble(Map<String, dynamic> message, int index) {
    final isUser = message['isUser'];
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isUser)
            Container(
              width: 32,
              height: 32,
              decoration: const BoxDecoration(
                color: Color(0xFF6366F1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.smart_toy_rounded, color: Colors.white, size: 16),
            ),
          if (!isUser) const SizedBox(width: 8),
          Flexible(
            child: Column(
              crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Container(
                  constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isUser ? const Color(0xFF6366F1) : Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: SelectableText(
                    message['text'],
                    style: TextStyle(
                      color: isUser ? Colors.white : Colors.black87,
                      fontSize: 15,
                      height: 1.4,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                if (isUser)
                  GestureDetector(
                    onTap: () => _editMessage(index),
                    child: Icon(Icons.edit_rounded, color: Colors.grey.shade500, size: 16),
                  ),
                if (!isUser)
                  GestureDetector(
                    onTap: () => _copyToClipboard(message['text']),
                    child: Icon(Icons.content_copy_rounded, color: Colors.grey.shade500, size: 16),
                  ),
              ],
            ),
          ),
          if (isUser) const SizedBox(width: 8),
        ],
      ),
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
            child: const Icon(Icons.smart_toy_rounded, color: Colors.white, size: 16),
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
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.grey.shade600),
                  ),
                ),
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

  Widget _buildChatInput() {
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
                  hintText: _editingMessageIndex != -1 ? 'Edit your message...' : 'Message Cerenix AI...',
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
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
              icon: Icon(_editingMessageIndex != -1 ? Icons.check_rounded : Icons.send_rounded, color: Colors.white, size: 20),
              onPressed: _sendMessage,
            ),
          ),
        ],
      ),
    );
  }

  void _sendMessage() {
    if (_messageController.text.trim().isNotEmpty) {
      if (_editingMessageIndex != -1) {
        _sendEditedMessage();
      } else {
        _addUserMessage(_messageController.text);
        _generateAIResponse(_messageController.text);
        _messageController.clear();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Cerenix AI', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1A1A2E),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.only(bottom: 8),
              itemCount: _chatMessages.length + (_isLoading ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == _chatMessages.length && _isLoading) {
                  return _buildLoadingIndicator();
                }
                return _buildMessageBubble(_chatMessages[index], index);
              },
            ),
          ),
          _buildChatInput(),
        ],
      ),
    );
  }
}