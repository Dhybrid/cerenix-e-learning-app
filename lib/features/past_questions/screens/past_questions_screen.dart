// lib/features/past_questions/screens/past_questions_screen.dart
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/network/api_service.dart';
import '../models/past_question_models.dart';

class PastQuestionsScreen extends StatefulWidget {
  final String courseId;
  final String courseName;
  final String? sessionId;
  final String sessionName;
  final String? topicId;
  final String? topicName;
  final bool randomMode;

  const PastQuestionsScreen({
    super.key,
    required this.courseId,
    required this.courseName,
    this.sessionId,
    required this.sessionName,
    this.topicId,
    this.topicName,
    required this.randomMode,
  });

  @override
  State<PastQuestionsScreen> createState() => _PastQuestionsScreenState();
}

class _PastQuestionsScreenState extends State<PastQuestionsScreen> {
  final ApiService _apiService = ApiService();
  
  List<PastQuestion> _questions = [];
  final List<bool> _showSolution = [];
  final List<bool> _isBookmarked = [];
  final List<bool> _isFlagged = [];
  bool _isLoading = true;
  bool _isOffline = false;
  bool _isEmptyTopic = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _loadQuestions();
  }

  Future<void> _loadQuestions() async {
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
      _isOffline = false;
      _isEmptyTopic = false;
      _errorMessage = '';
    });

    try {
      print('📥 Loading questions with params:');
      print('   - Course ID: ${widget.courseId}');
      print('   - Session ID: ${widget.sessionId}');
      print('   - Topic ID: ${widget.topicId}');
      print('   - Topic Name: ${widget.topicName}');
      
      final questions = await _apiService.getPastQuestions(
        courseId: widget.courseId,
        sessionId: widget.sessionId,
        topicId: widget.topicId,
      );

      if (!mounted) return;

      print('✅ Questions loaded: ${questions.length}');
      
      if (widget.topicId != null && widget.topicId!.isNotEmpty && questions.isEmpty) {
        print('⚠️ Empty topic detected: ${widget.topicName} (ID: ${widget.topicId})');
        setState(() {
          _isEmptyTopic = true;
          _questions = [];
          _errorMessage = 'This topic has no past questions. Try selecting another topic or enable Random Mode.';
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('This topic has no past questions. Try another topic or enable Random Mode.'),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 3),
              action: SnackBarAction(
                label: 'Go Back',
                textColor: Colors.white,
                onPressed: () {
                  Navigator.pop(context);
                },
              ),
            ),
          );
        }
        
        return;
      }

      setState(() {
        _questions = questions;
        _showSolution.clear();
        _isBookmarked.clear();
        _isFlagged.clear();
        
        _showSolution.addAll(List.generate(_questions.length, (index) => false));
        _isBookmarked.addAll(List.generate(_questions.length, (index) => false));
        _isFlagged.addAll(List.generate(_questions.length, (index) => false));
        _isEmptyTopic = false;
      });
    } catch (e) {
      print('❌ Error loading questions: $e');
      
      if (!mounted) return;
      
      final errorString = e.toString();
      
      if (errorString.contains('offline') || errorString.contains('internet')) {
        setState(() {
          _isOffline = true;
          _errorMessage = 'You are offline. Please check your internet connection.';
        });
      } else {
        setState(() {
          _errorMessage = 'Failed to load questions. Please try again.';
        });
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${errorString.split(':').last.trim()}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _toggleBookmark(int index) {
    setState(() {
      _isBookmarked[index] = !_isBookmarked[index];
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _isBookmarked[index] 
            ? 'Question bookmarked!' 
            : 'Bookmark removed',
        ),
        backgroundColor: const Color(0xFFF59E0B),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showFlagDialog(int index) {
    String? selectedReason;
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return Dialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.flag_rounded, size: 40, color: Color(0xFF8B5CF6)),
                  const SizedBox(height: 16),
                  const Text(
                    'Flag Question',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A1A2E),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Why are you flagging this question?',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Color(0xFF6B7280), fontSize: 14),
                  ),
                  const SizedBox(height: 20),
                  
                  Column(
                    children: [
                      _buildFlagOption('Incorrect question', selectedReason, (reason) {
                        setDialogState(() => selectedReason = reason);
                      }),
                      _buildFlagOption('Wrong answer', selectedReason, (reason) {
                        setDialogState(() => selectedReason = reason);
                      }),
                      _buildFlagOption('Poor formatting', selectedReason, (reason) {
                        setDialogState(() => selectedReason = reason);
                      }),
                      _buildFlagOption('Other issue', selectedReason, (reason) {
                        setDialogState(() => selectedReason = reason);
                      }),
                    ],
                  ),
                  
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF6B7280),
                            side: const BorderSide(color: Color(0xFFD1D5DB)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: selectedReason != null ? () {
                            setState(() {
                              _isFlagged[index] = true;
                            });
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Question flagged for review'),
                                backgroundColor: Color(0xFF8B5CF6),
                                duration: Duration(seconds: 2),
                              ),
                            );
                          } : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF8B5CF6),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          child: const Text('Flag Question'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildFlagOption(String reason, String? selectedReason, Function(String) onSelect) {
    final isSelected = selectedReason == reason;
    
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      child: OutlinedButton(
        onPressed: () => onSelect(reason),
        style: OutlinedButton.styleFrom(
          foregroundColor: isSelected ? const Color(0xFF8B5CF6) : const Color(0xFF6B7280),
          side: BorderSide(
            color: isSelected ? const Color(0xFF8B5CF6) : const Color(0xFFD1D5DB),
            width: isSelected ? 2 : 1,
          ),
          backgroundColor: isSelected ? const Color(0xFF8B5CF6).withOpacity(0.1) : Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        child: Text(
          reason,
          style: TextStyle(
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  void _showAnswer(int questionIndex) {
    final correctAnswer = _questions[questionIndex].correctAnswer;
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_rounded, color: Color(0xFF10B981), size: 32),
              ),
              const SizedBox(height: 16),
              const Text(
                'Correct Answer',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1A2E),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                correctAnswer,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF10B981),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Continue'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _toggleSolution(int index) {
    setState(() {
      _showSolution[index] = !_showSolution[index];
    });
  }

  // void _askAI(int questionIndex) {
  //   final question = _questions[questionIndex];
  //   Navigator.pushNamed(
  //     context, 
  //     '/questiongpt',
  //     arguments: {
  //       'question': question.questionText ?? 'Question Image',
  //       'course': widget.courseName,
  //     },
  //   );
  // }

  void _askAI(int questionIndex) {
  final question = _questions[questionIndex];
  
  Navigator.pushNamed(
    context, 
    '/question-gpt',  // New route
    arguments: {
      'question': question,
      'courseName': widget.courseName,
      'topicName': widget.topicName,
      'showAnswer': false,  // Set to true if you want AI to know the answer
    },
  );
}


  Widget _buildQuestionCard(int index) {
    final question = _questions[index];
    final optionsMap = question.getOptionsMap();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
              border: Border.all(color: Colors.grey.shade100),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366F1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Q${index + 1}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 11,
                    ),
                  ),
                ),
                const Spacer(),
                if (_isBookmarked[index]) 
                  const Icon(Icons.bookmark_rounded, color: Color(0xFFF59E0B), size: 16),
                if (_isFlagged[index]) 
                  const Padding(
                    padding: EdgeInsets.only(left: 4),
                    child: Icon(Icons.flag_rounded, color: Color(0xFF8B5CF6), size: 16),
                  ),
              ],
            ),
          ),
          
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (question.questionText != null && question.questionText!.isNotEmpty)
                  Text(
                    question.questionText!,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1A1A2E),
                      height: 1.4,
                    ),
                  ),
                
                if (question.questionImageUrl != null && question.questionImageUrl!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: CachedNetworkImage(
                        imageUrl: question.questionImageUrl!,
                        placeholder: (context, url) => Container(
                          height: 200,
                          color: Colors.grey.shade100,
                          child: const Center(
                            child: CircularProgressIndicator(),
                          ),
                        ),
                        errorWidget: (context, url, error) => Container(
                          height: 200,
                          color: Colors.grey.shade100,
                          child: const Center(
                            child: Icon(Icons.error, color: Colors.red),
                          ),
                        ),
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                
                const SizedBox(height: 12),
                
                if (question.hasOptions && optionsMap.isNotEmpty)
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: optionsMap.entries.map((option) {
                      return Container(
                        width: (MediaQuery.of(context).size.width - 56) / 2,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 20,
                                height: 20,
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
                                      fontSize: 10,
                                      color: Color(0xFF1A1A2E),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  option.value,
                                  style: const TextStyle(fontSize: 12),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                
                if (!question.hasOptions)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.short_text_rounded, size: 16, color: Color(0xFF6B7280)),
                        SizedBox(width: 8),
                        Text(
                          'Short answer question',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                      ],
                    ),
                  ),
                
                const SizedBox(height: 12),
                
                Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _showAnswer(index),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF6366F1),
                              side: const BorderSide(color: Color(0xFF6366F1)),
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            icon: const Icon(Icons.visibility_rounded, size: 14),
                            label: const Text(
                              'Show Answer',
                              style: TextStyle(fontSize: 12),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _toggleSolution(index),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF8B5CF6),
                              side: const BorderSide(color: Color(0xFF8B5CF6)),
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            icon: Icon(
                              _showSolution[index] ? Icons.visibility_off_rounded : Icons.lightbulb_rounded,
                              size: 14,
                            ),
                            label: Text(
                              _showSolution[index] ? 'Hide Solution' : 'Solution',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 8),
                    // SizedBox(
                    //   width: double.infinity,
                    //   child: OutlinedButton.icon(
                    //     onPressed: () => _askAI(index),
                    //     style: OutlinedButton.styleFrom(
                    //       foregroundColor: const Color(0xFF10B981),
                    //       side: const BorderSide(color: Color(0xFF10B981)),
                    //       padding: const EdgeInsets.symmetric(vertical: 8),
                    //       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    //     ),
                    //     icon: const Icon(Icons.auto_awesome_rounded, size: 14),
                    //     label: const Text(
                    //       'Ask AI for Help',
                    //       style: TextStyle(fontSize: 12),
                    //     ),
                    //   ),
                    // ),

                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => _askAI(index),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF10B981),
                          side: const BorderSide(color: Color(0xFF10B981)),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        icon: const Icon(Icons.auto_awesome_rounded, size: 14),
                        label: const Text(
                          'Ask AI for Explanation',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                    ),
                  ],
                ),
                
                if (_showSolution[index]) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF59E0B).withOpacity(0.05),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.2)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.lightbulb_rounded, color: Color(0xFFF59E0B), size: 16),
                            SizedBox(width: 6),
                            Text(
                              'Solution',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                                color: Color(0xFF1A1A2E),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        
                        if (question.solutionText != null && question.solutionText!.isNotEmpty)
                          Text(
                            question.solutionText!,
                            style: const TextStyle(
                              color: Color(0xFF6B7280),
                              fontSize: 12,
                              height: 1.4,
                            ),
                          ),
                        
                        if (question.solutionImageUrl != null && question.solutionImageUrl!.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: CachedNetworkImage(
                                imageUrl: question.solutionImageUrl!,
                                placeholder: (context, url) => Container(
                                  height: 150,
                                  color: Colors.grey.shade100,
                                  child: const Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                ),
                                errorWidget: (context, url, error) => Container(
                                  height: 150,
                                  color: Colors.grey.shade100,
                                  child: const Center(
                                    child: Icon(Icons.error, color: Colors.red),
                                  ),
                                ),
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),
                      ],
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

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          const Text(
            'Loading questions...',
            style: TextStyle(
              color: Color(0xFF6B7280),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _isOffline ? Icons.wifi_off_rounded : Icons.error_outline_rounded,
              size: 64,
              color: const Color(0xFF6B7280),
            ),
            const SizedBox(height: 16),
            Text(
              _isOffline ? 'You are offline' : 'Error loading questions',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A1A2E),
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                _errorMessage,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF6B7280),
                  fontSize: 14,
                ),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _loadQuestions,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6366F1),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _isEmptyTopic ? Icons.folder_off_rounded : Icons.quiz_outlined,
              size: 64,
              color: const Color(0xFF6B7280).withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              _isEmptyTopic ? 'No Questions in This Topic' : 'No Questions Found',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A1A2E),
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                _isEmptyTopic 
                  ? 'The topic "${widget.topicName ?? 'Selected Topic'}" doesn\'t have any past questions yet.\n\nTry selecting another topic or enable Random Mode to get questions from all topics.'
                  : 'No past questions found for the selected filters.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF6B7280),
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text('Go Back'),
                ),
                if (_isEmptyTopic) const SizedBox(width: 12),
                if (_isEmptyTopic)
                  ElevatedButton(
                    onPressed: _loadQuestions,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text('Try Random'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Past Questions',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            Text(
              '${widget.courseName} • ${widget.sessionName}${widget.topicName != null ? ' • ${widget.topicName}' : ''}',
              style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        backgroundColor: Colors.white,
        elevation: 1,
        foregroundColor: const Color(0xFF1A1A2E),
        actions: [
          if (_isOffline)
            IconButton(
              onPressed: null,
              icon: const Icon(Icons.wifi_off_rounded, color: Colors.orange),
            ),
          IconButton(
            onPressed: _isLoading ? null : _loadQuestions,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: _isLoading
          ? _buildLoadingState()
          : _questions.isEmpty
            ? _buildEmptyState()
            : ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: _questions.length,
                itemBuilder: (context, index) => _buildQuestionCard(index),
              ),
    );
  }
}