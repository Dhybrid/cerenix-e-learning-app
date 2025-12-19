// lib/features/past_questions/screens/question_gpt_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:markdown/markdown.dart' as md;
import '../../../features/cereva/screens/ai_gpt.dart';
import '../../../features/cereva/services/chat_service.dart';
import '../models/past_question_models.dart';

class QuestionGPTScreen extends StatefulWidget {
  final PastQuestion question;
  final String courseName;
  final String? topicName;
  final bool showAnswer;

  const QuestionGPTScreen({
    super.key,
    required this.question,
    required this.courseName,
    this.topicName,
    this.showAnswer = false,
  });

  @override
  State<QuestionGPTScreen> createState() => _QuestionGPTScreenState();
}

class _QuestionGPTScreenState extends State<QuestionGPTScreen> {
  final List<Map<String, dynamic>> _chatMessages = [];
  final ScrollController _scrollController = ScrollController();
  bool _isLoading = false;
  bool _hasReachedMax = false;
  String _initialPrompt = '';

  @override
  void initState() {
    super.initState();
    _initializeChat();
  }

  Future<void> _initializeChat() async {
    await ChatService.initHive();
    _initialPrompt = _buildInitialPrompt();
    
    // Auto-send the question to AI after a short delay
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _sendQuestionToAI();
    });
  }

  String _buildInitialPrompt() {
    String prompt = 'I need help understanding this past exam question:\n\n';
    
    // Add question
    if (widget.question.questionText != null && 
        widget.question.questionText!.isNotEmpty) {
      prompt += '**Question:** ${widget.question.questionText}\n\n';
    }
    
    // Add options if available
    if (widget.question.hasOptions) {
      final options = widget.question.getOptionsMap();
      if (options.isNotEmpty) {
        prompt += '**Options:**\n';
        options.forEach((key, value) {
          prompt += '${key.toUpperCase()}. $value\n';
        });
        prompt += '\n';
      }
    }
    
    // Add context
    prompt += '**Course:** ${widget.courseName}\n';
    if (widget.topicName != null) {
      prompt += '**Topic:** ${widget.topicName}\n';
    }
    
    // Add difficulty
    prompt += '**Difficulty:** ${widget.question.difficultyText}\n\n';
    
    // Add instruction
    prompt += 'Please provide a detailed explanation:\n\n';
    prompt += '1. **Explain the question** in simple terms\n';
    prompt += '2. **Analyze each option** - why it might be right or wrong\n';
    
    if (widget.showAnswer && widget.question.correctAnswer.isNotEmpty) {
      prompt += '3. **Correct Answer:** ${widget.question.correctAnswer.toUpperCase()}\n';
      prompt += '4. **Explain why this is correct** with reasoning\n';
    } else {
      prompt += '3. **Guide me to find the correct answer** without giving it away\n';
    }
    
    prompt += '5. **Provide step-by-step solution**\n';
    prompt += '6. **Similar examples** for practice\n';
    prompt += '7. **Key concepts** to remember\n\n';
    
    prompt += 'Please format your response clearly with headings, bullet points, and mathematical notation where applicable.';
    
    return prompt;
  }

  Future<void> _sendQuestionToAI() async {
    // Add user message (the question)
    _addUserMessage(_initialPrompt);
    
    // Generate AI response
    await _generateAIResponse(_initialPrompt);
  }

  void _addUserMessage(String message) {
    setState(() {
      _chatMessages.add({
        'text': message,
        'isUser': true,
        'timestamp': DateTime.now(),
      });
    });
    _scrollToBottom();
  }

  Future<void> _generateAIResponse(String userMessage) async {
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
            'timestamp': DateTime.now(),
          });
        } else {
          if (response['error'] == 'daily_limit_exceeded') {
            _chatMessages.add({
              'text': response['message'] ?? 'Daily message limit reached. Please try again tomorrow.',
              'isUser': false,
              'isError': true,
              'isLimitReached': true,
            });
          } else {
            if (response['error']?.toString().contains('maximum') == true) {
              _hasReachedMax = true;
            }
            _chatMessages.add({
              'text': 'Sorry, I encountered an error: ${response['error']}',
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

  void _copyQuestionToClipboard() {
    String questionText = '';
    
    if (widget.question.questionText != null && 
        widget.question.questionText!.isNotEmpty) {
      questionText = widget.question.questionText!;
    }
    
    if (widget.question.hasOptions) {
      final options = widget.question.getOptionsMap();
      if (options.isNotEmpty) {
        questionText += '\n\nOptions:';
        options.forEach((key, value) {
          questionText += '\n${key.toUpperCase()}. $value';
        });
      }
    }
    
    Clipboard.setData(ClipboardData(text: questionText));
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Question copied to clipboard'),
        backgroundColor: Color(0xFF10B981),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _regenerateResponse() {
    if (_chatMessages.length >= 2) {
      // Remove the last AI response
      setState(() {
        _chatMessages.removeLast();
      });
      // Regenerate
      _generateAIResponse(_initialPrompt);
    }
  }

  Widget _buildQuestionPreview() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6366F1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'Question',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 11,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: widget.question.difficultyColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: widget.question.difficultyColor.withOpacity(0.3)),
                    ),
                    child: Text(
                      widget.question.difficultyText,
                      style: TextStyle(
                        color: widget.question.difficultyColor,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.content_copy, size: 18, color: Color(0xFF6B7280)),
                onPressed: _copyQuestionToClipboard,
                tooltip: 'Copy question',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          // Question text
          if (widget.question.questionText != null && 
              widget.question.questionText!.isNotEmpty)
            Text(
              widget.question.questionText!,
              style: const TextStyle(
                fontSize: 14,
                height: 1.4,
                color: Color(0xFF1A1A2E),
              ),
            ),
          
          // Options
          if (widget.question.hasOptions)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 12),
                const Text(
                  'Options:',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: Color(0xFF1A1A2E),
                  ),
                ),
                const SizedBox(height: 8),
                ...widget.question.getOptionsMap().entries.map((option) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: Center(
                              child: Text(
                                option.key,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                  color: Color(0xFF1A1A2E),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              option.value,
                              style: const TextStyle(fontSize: 13, color: Color(0xFF1A1A2E)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ],
            ),
          
          // Course info
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              children: [
                const Icon(Icons.menu_book, size: 14, color: Color(0xFF6366F1)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    widget.courseName,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF6366F1),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                if (widget.topicName != null) ...[
                  Container(
                    height: 16,
                    width: 1,
                    color: Colors.grey.shade300,
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.label, size: 12, color: Color(0xFF8B5CF6)),
                  const SizedBox(width: 4),
                  Text(
                    widget.topicName!,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF8B5CF6),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> message, int index) {
    final isUser = message['isUser'];
    final isError = message['isError'] ?? false;
    
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
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
                isError ? Icons.error_rounded : Icons.auto_awesome_rounded, 
                color: Colors.white, 
                size: 16
              ),
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
                    color: isUser ? const Color(0xFF6366F1) : 
                           isError ? Colors.red.shade50 : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: !isUser && !isError ? [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.03),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ] : null,
                  ),
                  child: isUser 
                      ? SelectableText(
                          message['text'],
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            height: 1.4,
                          ),
                        )
                      : _buildAIResponse(message['text'], isError),
                ),
                const SizedBox(height: 4),
                if (!isUser && !isError)
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () => _copyToClipboard(message['text']),
                        child: Icon(Icons.content_copy_rounded, color: Colors.grey.shade500, size: 16),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: _regenerateResponse,
                        child: Icon(Icons.refresh_rounded, color: Colors.grey.shade500, size: 16),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Copy • Regenerate',
                        style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
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
        style: const TextStyle(
          color: Colors.red,
          fontSize: 15,
          height: 1.4,
        ),
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
            child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 16),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Row(
              children: [
                _buildTypingDots(),
                const SizedBox(width: 12),
                Text(
                  'Cerenix AI is analyzing your question...',
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'AI Explanation',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: Colors.white,
        elevation: 1,
        foregroundColor: const Color(0xFF1A1A2E),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          _buildQuestionPreview(),
          const SizedBox(height: 4),
          Expanded(
            child: _chatMessages.isEmpty && !_isLoading
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(
                          width: 60,
                          height: 60,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Color(0xFF6366F1),
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Getting AI Explanation...',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1A1A2E),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Analyzing your question and generating detailed explanation',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
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
        ],
      ),
    );
  }
}

// Reuse your existing MathMarkdownBody and related classes from ai_gpt.dart
// You can copy them or create a shared component
class MathMarkdownBody extends StatelessWidget {
  final String data;
  final Function(String) onCopyCode;

  const MathMarkdownBody({super.key, required this.data, required this.onCopyCode});

  String _preprocessMath(String text) {
    return text.replaceAllMapped(
      RegExp(r'\$\$([^\$]+)\$\$'),
      (match) => '\$${match.group(1)}\$'
    );
  }

  @override
  Widget build(BuildContext context) {
    final processedData = _preprocessMath(data);
    
    return MarkdownBody(
      data: processedData,
      styleSheet: MarkdownStyleSheet(
        p: const TextStyle(fontSize: 15, height: 1.6, color: Color(0xFF1A1A2E)),
        strong: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1A1A2E)),
        em: const TextStyle(fontStyle: FontStyle.italic, color: Color(0xFF1A1A2E)),
        h1: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF1A1A2E)),
        h2: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1A1A2E)),
        h3: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1A1A2E)),
        h4: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1A1A2E)),
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
        listBullet: const TextStyle(fontSize: 15, color: Color(0xFF1A1A2E)),
        tableBody: const TextStyle(fontSize: 15, color: Color(0xFF1A1A2E)),
        tableHead: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF1A1A2E)),
      ),
      builders: {
        'code': CodeElementBuilder(onCopy: onCopyCode),
        'math': MathElementBuilder(),
      },
      extensionSet: md.ExtensionSet(
        md.ExtensionSet.gitHubFlavored.blockSyntaxes,
        [
          md.EmojiSyntax(),
          ...md.ExtensionSet.gitHubFlavored.inlineSyntaxes,
          InlineMathSyntax(),
        ],
      ),
    );
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
      constraints: isMultiLine ? BoxConstraints(maxHeight: 300) : BoxConstraints(),
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
                      Icon(Icons.content_copy, size: 14, color: Colors.grey.shade700),
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
            textStyle: TextStyle(
              fontSize: 18,
              color: Colors.blue.shade900,
            ),
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
            textStyle: TextStyle(
              fontSize: 16,
              color: Colors.blue.shade900,
            ),
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