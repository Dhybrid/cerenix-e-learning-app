// lib/features/courses/screens/related_past_questions_screen.dart
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/network/api_service.dart';
import '../../past_questions/models/past_question_models.dart';

class RelatedPastQuestionsScreen extends StatefulWidget {
  final String courseId;
  final String courseCode;
  final String topicTitle;
  final String? topicId;

  const RelatedPastQuestionsScreen({
    Key? key,
    required this.courseId,
    required this.courseCode,
    required this.topicTitle,
    this.topicId,
  }) : super(key: key);

  @override
  State<RelatedPastQuestionsScreen> createState() => _RelatedPastQuestionsScreenState();
}

class _RelatedPastQuestionsScreenState extends State<RelatedPastQuestionsScreen> {
  final ApiService _apiService = ApiService();
  
  List<PastQuestion> _questions = [];
  final List<bool> _showSolution = [];
  final List<bool> _isBookmarked = [];
  final List<bool> _isFlagged = [];
  bool _isLoading = true;
  bool _isOffline = false;
  String _errorMessage = '';
  int _selectedQuestionIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadQuestions();
  }

  Future<void> _loadQuestions() async {
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      print('📥 Loading related past questions...');
      print('   - Course ID: ${widget.courseId}');
      print('   - Topic ID: ${widget.topicId}');
      print('   - Topic Title: ${widget.topicTitle}');
      
      final questions = await _apiService.getPastQuestions(
        courseId: widget.courseId,
        topicId: widget.topicId,
      );

      if (!mounted) return;

      print('✅ Loaded ${questions.length} related questions');
      
      setState(() {
        _questions = questions;
        _showSolution.clear();
        _isBookmarked.clear();
        _isFlagged.clear();
        
        _showSolution.addAll(List.generate(_questions.length, (index) => false));
        _isBookmarked.addAll(List.generate(_questions.length, (index) => false));
        _isFlagged.addAll(List.generate(_questions.length, (index) => false));
      });
    } catch (e) {
      print('❌ Error loading related questions: $e');
      
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
        backgroundColor: Colors.orange,
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
          return AlertDialog(
            title: Text('Flag Question ${index + 1}'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Why are you flagging this question?'),
                const SizedBox(height: 16),
                
                // Flag options
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
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
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: selectedReason != null ? () {
                  setState(() {
                    _isFlagged[index] = true;
                  });
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Question flagged for review'),
                      backgroundColor: Colors.purple,
                      duration: Duration(seconds: 2),
                    ),
                  );
                } : null,
                child: const Text('Flag'),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildFlagOption(String reason, String? selectedReason, Function(String) onSelect) {
    final isSelected = selectedReason == reason;
    
    return ChoiceChip(
      label: Text(reason),
      selected: isSelected,
      onSelected: (_) => onSelect(reason),
      backgroundColor: isSelected ? Colors.purple.withOpacity(0.1) : null,
      selectedColor: Colors.purple.withOpacity(0.3),
      labelStyle: TextStyle(
        color: isSelected ? Colors.purple : Colors.black,
      ),
    );
  }

  void _toggleSolution(int index) {
    setState(() {
      _showSolution[index] = !_showSolution[index];
    });
  }

  void _askAI(int index) {
    final question = _questions[index];
    
    // Navigate to AI explanation screen
    Navigator.pushNamed(
      context,
      '/question-gpt',
      arguments: {
        'question': question,
        'courseName': widget.courseCode,
        'topicName': widget.topicTitle,
      },
    );
  }

  Widget _buildQuestionCard(int index) {
    final question = _questions[index];
    final isCurrent = index == _selectedQuestionIndex;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: isCurrent
            ? [
                BoxShadow(
                  color: Colors.blue.withOpacity(0.3),
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
              ]
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
        border: isCurrent
            ? Border.all(color: Colors.blue, width: 2)
            : Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Question header
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.blue,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Q${index + 1}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Question ${index + 1}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
                if (_isBookmarked[index])
                  const Icon(Icons.bookmark, color: Colors.orange, size: 18),
                if (_isFlagged[index])
                  const Padding(
                    padding: EdgeInsets.only(left: 4),
                    child: Icon(Icons.flag, color: Colors.purple, size: 18),
                  ),
              ],
            ),
          ),
          
          // Question content
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Question text
                if (question.questionText != null && question.questionText!.isNotEmpty)
                  Text(
                    question.questionText!,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: Colors.black87,
                      height: 1.4,
                    ),
                  ),
                
                // Question image
                if (question.questionImageUrl != null && question.questionImageUrl!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: CachedNetworkImage(
                        imageUrl: question.questionImageUrl!,
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
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                
                // Options (if MCQ)
                if (question.hasOptions)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: question.getOptionsMap().entries.map((option) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            children: [
                              Container(
                                width: 24,
                                height: 24,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.grey.shade400),
                                ),
                                child: Center(
                                  child: Text(
                                    option.key,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  option.value,
                                  style: const TextStyle(fontSize: 14),
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                
                // Actions
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _toggleSolution(index),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: Colors.grey.shade300),
                        ),
                        icon: Icon(
                          _showSolution[index] 
                              ? Icons.visibility_off 
                              : Icons.lightbulb_outline,
                          size: 16,
                        ),
                        label: Text(
                          _showSolution[index] ? 'Hide Solution' : 'Show Solution',
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _askAI(index),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.green),
                        ),
                        icon: const Icon(Icons.auto_awesome, size: 16, color: Colors.green),
                        label: const Text(
                          'Ask AI',
                          style: TextStyle(fontSize: 13, color: Colors.green),
                        ),
                      ),
                    ),
                  ],
                ),
                
                // Solution (if shown)
                if (_showSolution[index])
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.amber.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.amber.withOpacity(0.2)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.lightbulb, color: Colors.amber, size: 16),
                              SizedBox(width: 6),
                              Text(
                                'Solution',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          
                          if (question.solutionText != null && question.solutionText!.isNotEmpty)
                            Text(
                              question.solutionText!,
                              style: const TextStyle(
                                fontSize: 13,
                                color: Colors.black87,
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
                                    height: 120,
                                    color: Colors.grey.shade100,
                                  ),
                                  errorWidget: (context, url, error) => Container(
                                    height: 120,
                                    color: Colors.grey.shade100,
                                    child: const Icon(Icons.error),
                                  ),
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
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
          CircularProgressIndicator(),
          const SizedBox(height: 20),
          Text(
            'Loading related questions...',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade600,
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
              _isOffline ? Icons.wifi_off : Icons.error_outline,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 20),
            Text(
              _isOffline ? 'You are offline' : 'Error loading questions',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              _errorMessage,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _loadQuestions,
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
            Icon(Icons.quiz_outlined, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 20),
            Text(
              'No related questions found',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'There are no past questions related to this topic yet.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 20),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Go Back'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Related Past Questions',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 2),
            Text(
              '${widget.courseCode} - ${widget.topicTitle}',
              style: TextStyle(
                fontSize: 12,
                color: Colors.white.withOpacity(0.9),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _loadQuestions,
          ),
        ],
      ),
      body: _isLoading
          ? _buildLoadingState()
          : _questions.isEmpty
              ? _buildEmptyState()
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      // Question count
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.quiz, color: Colors.blue, size: 18),
                            const SizedBox(width: 8),
                            Text(
                              '${_questions.length} Related Questions',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                            const Spacer(),
                            if (_questions.length > 1)
                              Row(
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.arrow_back_ios, size: 16),
                                    onPressed: _selectedQuestionIndex > 0
                                        ? () {
                                            setState(() {
                                              _selectedQuestionIndex--;
                                            });
                                            // Scroll to question
                                          }
                                        : null,
                                  ),
                                  Text(
                                    '${_selectedQuestionIndex + 1}/${_questions.length}',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.arrow_forward_ios, size: 16),
                                    onPressed: _selectedQuestionIndex < _questions.length - 1
                                        ? () {
                                            setState(() {
                                              _selectedQuestionIndex++;
                                            });
                                          }
                                        : null,
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Show selected question or all questions
                      _buildQuestionCard(_selectedQuestionIndex),
                      
                      // Or show all questions in a list
                      // ..._questions.map((question) => _buildQuestionCard(_questions.indexOf(question))).toList(),
                    ],
                  ),
                ),
    );
  }
}