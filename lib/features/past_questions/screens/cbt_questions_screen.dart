// lib/features/cbt/screens/cbt_questions_screen.dart
import 'package:flutter/material.dart';
import 'dart:async';

class CBTQuestionsScreen extends StatefulWidget {
  final String session;
  final String course;
  final String? topic;
  final bool randomMode;
  final bool enableTimer;

  const CBTQuestionsScreen({
    super.key,
    required this.session,
    required this.course,
    this.topic,
    required this.randomMode,
    required this.enableTimer,
  });

  @override
  State<CBTQuestionsScreen> createState() => _CBTQuestionsScreenState();
}

class _CBTQuestionsScreenState extends State<CBTQuestionsScreen> {
  final List<Map<String, dynamic>> _questions = [
    {
      'id': 1,
      'question': 'Which of the following is a vector quantity?',
      'options': {
        'A': 'Mass',
        'B': 'Temperature',
        'C': 'Velocity',
        'D': 'Speed',
        'E': 'Distance'
      },
      'correctAnswer': 'C',
      'solution': 'Velocity is a vector quantity because it has both magnitude and direction.',
      'isBookmarked': false,
      'isFlagged': false,
      'userAnswer': null,
    },
    {
      'id': 2,
      'question': 'What is the SI unit of force?',
      'options': {
        'A': 'Joule',
        'B': 'Watt',
        'C': 'Newton',
        'D': 'Pascal',
        'E': 'Volt'
      },
      'correctAnswer': 'C',
      'solution': 'The SI unit of force is Newton (N).',
      'isBookmarked': false,
      'isFlagged': false,
      'userAnswer': null,
    },
    {
      'id': 3,
      'question': 'Which law states that every action has an equal and opposite reaction?',
      'options': {
        'A': 'Newton\'s First Law',
        'B': 'Newton\'s Second Law',
        'C': 'Newton\'s Third Law',
        'D': 'Law of Gravitation',
        'E': 'Law of Conservation'
      },
      'correctAnswer': 'C',
      'solution': 'Newton\'s Third Law states that every action has an equal and opposite reaction.',
      'isBookmarked': false,
      'isFlagged': false,
      'userAnswer': null,
    },
  ];

  int _currentQuestionIndex = 0;
  bool _showQuestionPicker = false;
  bool _showResults = false;
  bool _showCorrections = false;
  Duration _timerDuration = const Duration(minutes: 30);
  late Timer _timer;
  Duration _timeUsed = Duration.zero;
  DateTime? _startTime;

  @override
  void initState() {
    super.initState();
    _startTime = DateTime.now();
    if (widget.enableTimer) {
      _startTimer();
    } else {
      _startStopwatch();
    }
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_timerDuration.inSeconds > 0) {
          _timerDuration = _timerDuration - const Duration(seconds: 1);
        } else {
          _timer.cancel();
          _submitExam();
        }
      });
    });
  }

  void _startStopwatch() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _timeUsed = _timeUsed + const Duration(seconds: 1);
      });
    });
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "$twoDigitMinutes:$twoDigitSeconds";
  }

  void _selectAnswer(String option) {
    setState(() {
      _questions[_currentQuestionIndex]['userAnswer'] = option;
    });
  }

  void _toggleBookmark() {
    setState(() {
      _questions[_currentQuestionIndex]['isBookmarked'] = 
          !_questions[_currentQuestionIndex]['isBookmarked'];
    });
  }

  void _showFlagDialog() {
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
                  
                  // Flag reasons
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
                              _questions[_currentQuestionIndex]['isFlagged'] = true;
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

  void _goToQuestion(int index) {
    setState(() {
      _currentQuestionIndex = index;
      _showQuestionPicker = false;
    });
  }

  void _nextQuestion() {
    if (_currentQuestionIndex < _questions.length - 1) {
      setState(() {
        _currentQuestionIndex++;
      });
    }
  }

  void _previousQuestion() {
    if (_currentQuestionIndex > 0) {
      setState(() {
        _currentQuestionIndex--;
      });
    }
  }

  void _showSubmitConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Submit Exam?'),
        content: const Text('Are you sure you want to submit your exam? You cannot change your answers after submission.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _submitExam();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6366F1),
            ),
            child: const Text('Yes, Submit'),
          ),
        ],
      ),
    );
  }

  void _submitExam() {
    _timer.cancel();
    setState(() {
      _showResults = true;
    });
  }

  void _retakeExam() {
    setState(() {
      _showResults = false;
      _showCorrections = false;
      _currentQuestionIndex = 0;
      _timerDuration = const Duration(minutes: 30);
      _timeUsed = Duration.zero;
      _startTime = DateTime.now();
      
      // Reset all questions
      for (var question in _questions) {
        question['userAnswer'] = null;
        question['isBookmarked'] = false;
        question['isFlagged'] = false;
      }
      
      if (widget.enableTimer) {
        _startTimer();
      } else {
        _startStopwatch();
      }
    });
  }

  void _showExamCorrections() {
    setState(() {
      _showResults = false;
      _showCorrections = true;
      _currentQuestionIndex = 0;
    });
  }

  int get _score {
    return _questions.where((q) => q['userAnswer'] == q['correctAnswer']).length;
  }

  int get _answeredCount {
    return _questions.where((q) => q['userAnswer'] != null).length;
  }

  String get _grade {
    final percentage = (_score / _questions.length) * 100;
    if (percentage >= 70) return 'A';
    if (percentage >= 60) return 'B';
    if (percentage >= 50) return 'C';
    if (percentage >= 45) return 'D';
    return 'F';
  }

  String get _timeTaken {
    if (_startTime == null) return '00:00';
    final endTime = DateTime.now();
    final difference = endTime.difference(_startTime!);
    return _formatDuration(difference);
  }

  Widget _buildQuestionPicker() {
    return Container(
      height: MediaQuery.of(context).size.height * 0.6,
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 10,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Questions',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: SingleChildScrollView(
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: List.generate(_questions.length, (index) {
                  final question = _questions[index];
                  final isCurrent = index == _currentQuestionIndex;
                  final isAnswered = question['userAnswer'] != null;
                  final isFlagged = question['isFlagged'];
                  
                  return GestureDetector(
                    onTap: () => _goToQuestion(index),
                    child: Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: isCurrent ? const Color(0xFF6366F1) : 
                               isAnswered ? const Color(0xFF10B981) : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isFlagged ? const Color(0xFF8B5CF6) : Colors.transparent,
                          width: 2,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          '${index + 1}',
                          style: TextStyle(
                            color: isCurrent || isAnswered ? Colors.white : Colors.black,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => setState(() => _showQuestionPicker = false),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6366F1),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: const Text('Close'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionCard() {
    final question = _questions[_currentQuestionIndex];
    final userAnswer = question['userAnswer'];
    final correctAnswer = question['correctAnswer'];
    final showResults = _showCorrections;

    return Expanded(
      child: SingleChildScrollView(
        child: Container(
          margin: const EdgeInsets.only(bottom: 16),
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
              // Question Header
              Container(
                padding: const EdgeInsets.all(16),
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
                    Text(
                      'Question ${_currentQuestionIndex + 1} of ${_questions.length}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1A1A2E),
                      ),
                    ),
                    const Spacer(),
                    // Bookmark and Flag in one line
                    Row(
                      children: [
                        IconButton(
                          onPressed: _toggleBookmark,
                          icon: Icon(
                            question['isBookmarked'] ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                            color: question['isBookmarked'] ? const Color(0xFFF59E0B) : Colors.grey.shade600,
                            size: 20,
                          ),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                        IconButton(
                          onPressed: _showFlagDialog,
                          icon: Icon(
                            question['isFlagged'] ? Icons.flag_rounded : Icons.outlined_flag_rounded,
                            color: question['isFlagged'] ? const Color(0xFF8B5CF6) : Colors.grey.shade600,
                            size: 20,
                          ),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              // Question Content
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Question Text
                    Text(
                      question['question'] as String,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1A1A2E),
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Options - Compact Design
                    Column(
                      children: (question['options'] as Map<String, String>).entries.map((option) {
                        final isSelected = userAnswer == option.key;
                        final isCorrect = option.key == correctAnswer;
                        
                        Color backgroundColor = Colors.grey.shade50;
                        Color borderColor = Colors.grey.shade200;
                        Color textColor = const Color(0xFF1A1A2E);
                        
                        if (showResults) {
                          if (isCorrect) {
                            backgroundColor = const Color(0xFF10B981).withOpacity(0.1);
                            borderColor = const Color(0xFF10B981);
                            textColor = const Color(0xFF10B981);
                          } else if (isSelected && !isCorrect) {
                            backgroundColor = const Color(0xFFEF4444).withOpacity(0.1);
                            borderColor = const Color(0xFFEF4444);
                            textColor = const Color(0xFFEF4444);
                          }
                        } else if (isSelected) {
                          backgroundColor = const Color(0xFF6366F1).withOpacity(0.1);
                          borderColor = const Color(0xFF6366F1);
                          textColor = const Color(0xFF6366F1);
                        }
                        
                        Widget? trailingIcon;
                        if (showResults) {
                          if (isCorrect) {
                            trailingIcon = const Icon(Icons.check_rounded, color: Color(0xFF10B981), size: 16);
                          } else if (isSelected && !isCorrect) {
                            trailingIcon = const Icon(Icons.close_rounded, color: Color(0xFFEF4444), size: 16);
                          }
                        }
                        
                        return GestureDetector(
                          onTap: !showResults ? () => _selectAnswer(option.key) : null,
                          child: Container(
                            width: double.infinity,
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: backgroundColor,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: borderColor, width: 1.5),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 24,
                                  height: 24,
                                  decoration: BoxDecoration(
                                    color: showResults && isCorrect ? const Color(0xFF10B981) :
                                          showResults && isSelected && !isCorrect ? const Color(0xFFEF4444) :
                                          isSelected ? const Color(0xFF6366F1) : Colors.white,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: showResults && isCorrect ? const Color(0xFF10B981) :
                                            showResults && isSelected && !isCorrect ? const Color(0xFFEF4444) :
                                            isSelected ? const Color(0xFF6366F1) : Colors.grey.shade300,
                                    ),
                                  ),
                                  child: Center(
                                    child: Text(
                                      option.key,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: isSelected || (showResults && (isCorrect || (isSelected && !isCorrect))) 
                                            ? Colors.white 
                                            : const Color(0xFF1A1A2E),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    option.value,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: textColor,
                                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                    ),
                                  ),
                                ),
                                if (trailingIcon != null) ...[
                                  const SizedBox(width: 8),
                                  trailingIcon,
                                ],
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResultsScreen() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Retake Button at Top Right
          Align(
            alignment: Alignment.topRight,
            child: TextButton.icon(
              onPressed: _retakeExam,
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Retake'),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF6366F1),
              ),
            ),
          ),

          const Icon(Icons.celebration_rounded, size: 64, color: Color(0xFFF59E0B)),
          const SizedBox(height: 16),
          const Text(
            'Exam Completed!',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A1A2E),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${widget.course} • ${widget.session}',
            style: const TextStyle(color: Colors.grey, fontSize: 14),
          ),
          const SizedBox(height: 8),
          Text(
            'Time Taken: $_timeTaken',
            style: const TextStyle(color: Colors.grey, fontSize: 14),
          ),
          Text(
            'Answered: $_answeredCount/${_questions.length}',
            style: const TextStyle(color: Colors.grey, fontSize: 14),
          ),
          const SizedBox(height: 24),
          
          // Grade in center - very bold
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 30),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              children: [
                const Text(
                  'Your Grade',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _grade,
                  style: const TextStyle(
                    fontSize: 64,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF6366F1),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Score: $_score/${_questions.length}',
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.grey,
                  ),
                ),
                Text(
                  '${(_score / _questions.length * 100).toStringAsFixed(1)}%',
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Action Buttons
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _showExamCorrections,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Show Correction',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
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
              'CBT Practice',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            Text(
              '${widget.course} • ${widget.session}',
              style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280)),
            ),
          ],
        ),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1A1A2E),
        elevation: 1,
        actions: [
          // Question Picker Toggle - Icon stays at top
          IconButton(
            onPressed: () => setState(() => _showQuestionPicker = !_showQuestionPicker),
            icon: const Icon(Icons.grid_view_rounded, size: 20),
          ),
        ],
      ),
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Header with Timer and Submit Button - Only show in normal mode
                if (!_showResults && !_showCorrections)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                    child: Row(
                      children: [
                        // Timer on Left
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: widget.enableTimer 
                                ? const Color(0xFFF59E0B).withOpacity(0.1)
                                : Colors.grey.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: widget.enableTimer ? const Color(0xFFF59E0B) : Colors.grey,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.timer_rounded,
                                size: 16,
                                color: widget.enableTimer ? const Color(0xFFF59E0B) : Colors.grey,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                widget.enableTimer 
                                    ? _formatDuration(_timerDuration)
                                    : _formatDuration(_timeUsed),
                                style: TextStyle(
                                  color: widget.enableTimer ? const Color(0xFFF59E0B) : Colors.grey,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        
                        const Spacer(),
                        
                        // Submit Button on Right
                        ElevatedButton(
                          onPressed: _showSubmitConfirmation,
                          style: ElevatedButton.styleFrom(
                            foregroundColor: Colors.white,
                            backgroundColor: const Color(0xFF10B981),
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text(
                            'Submit',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),
                
                if (!_showResults && !_showCorrections) const SizedBox(height: 16),
                
                // Main Content
                if (_showResults)
                  Expanded(
                    child: SingleChildScrollView(
                      child: _buildResultsScreen(),
                    ),
                  )
                else
                  _buildQuestionCard(),
                
                // Navigation Buttons (show in normal mode AND correction mode)
                if (!_showResults && _showCorrections) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _previousQuestion,
                            child: const Text('Previous'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _nextQuestion,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF6366F1),
                            ),
                            child: const Text('Next'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                
                // Navigation Buttons for normal mode
                if (!_showResults && !_showCorrections) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _previousQuestion,
                            child: const Text('Previous'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _nextQuestion,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF6366F1),
                            ),
                            child: const Text('Next'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Question Picker Modal - Shows from bottom as overlay
          if (_showQuestionPicker)
            Positioned.fill(
              child: Container(
                color: Colors.black54,
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: _buildQuestionPicker(),
                ),
              ),
            ),
        ],
      ),
    );
  }
}