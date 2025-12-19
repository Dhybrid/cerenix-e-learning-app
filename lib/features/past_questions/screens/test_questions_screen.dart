// lib/features/past_questions/screens/test_questions_screen.dart
import 'package:flutter/material.dart';

class TestQuestionsScreen extends StatefulWidget {
  final String session;
  final String course;
  final String? topic;
  final bool randomMode;

  const TestQuestionsScreen({
    super.key,
    required this.session,
    required this.course,
    this.topic,
    required this.randomMode,
  });

  @override
  State<TestQuestionsScreen> createState() => _TestQuestionsScreenState();
}

class _TestQuestionsScreenState extends State<TestQuestionsScreen> {
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
      'solution': 'Velocity is a vector quantity because it has both magnitude and direction. Mass, temperature, speed, and distance are scalar quantities as they only have magnitude.',
      'isBookmarked': false,
      'isFlagged': false,
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
      'solution': 'The SI unit of force is Newton (N), named after Sir Isaac Newton. 1 Newton is defined as the force required to accelerate a 1 kg mass at 1 m/s².',
      'isBookmarked': false,
      'isFlagged': false,
    },
  ];

  final List<bool> _showSolution = [];

  @override
  void initState() {
    super.initState();
    _showSolution.addAll(List.generate(_questions.length, (index) => false));
  }

  void _toggleBookmark(int index) {
    setState(() {
      _questions[index]['isBookmarked'] = !_questions[index]['isBookmarked'];
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _questions[index]['isBookmarked'] 
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
                              _questions[index]['isFlagged'] = true;
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
    final correctAnswer = _questions[questionIndex]['correctAnswer'];
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
                'Option $correctAnswer',
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

  void _askAI(int questionIndex) {
    Navigator.pushNamed(
      context, 
      '/questiongpt',
      arguments: {
        'question': _questions[questionIndex]['question'],
        'course': widget.course,
      },
    );
  }

  Widget _buildQuestionCard(int index) {
    final question = _questions[index];

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
          // Question Header - Clean and compact
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
                // Status indicators - smaller
                if (question['isBookmarked']) 
                  const Icon(Icons.bookmark_rounded, color: Color(0xFFF59E0B), size: 16),
                if (question['isFlagged']) 
                  const Padding(
                    padding: EdgeInsets.only(left: 4),
                    child: Icon(Icons.flag_rounded, color: Color(0xFF8B5CF6), size: 16),
                  ),
              ],
            ),
          ),
          
          // Question Content
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Question Text - Full visibility, no abbreviation
                Text(
                  question['question'] as String,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1A1A2E),
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 12),
                
                // Options - More compact layout
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: (question['options'] as Map<String, String>).entries.map((option) {
                    return Container(
                      width: (MediaQuery.of(context).size.width - 56) / 2, // Half width for 2 columns
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
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
                
                const SizedBox(height: 12),
                
                // Action Buttons - Reorganized layout
                Column(
                  children: [
                    // First row: Bookmark and Flag
                    Row(
                      children: [
                        // Bookmark button
                        IconButton(
                          onPressed: () => _toggleBookmark(index),
                          icon: Icon(
                            question['isBookmarked'] ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                            color: question['isBookmarked'] ? const Color(0xFFF59E0B) : Colors.grey.shade600,
                            size: 20,
                          ),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                        const SizedBox(width: 8),
                        // Flag button
                        IconButton(
                          onPressed: () => _showFlagDialog(index),
                          icon: Icon(
                            question['isFlagged'] ? Icons.flag_rounded : Icons.outlined_flag_rounded,
                            color: question['isFlagged'] ? const Color(0xFF8B5CF6) : Colors.grey.shade600,
                            size: 20,
                          ),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                        const Spacer(),
                      ],
                    ),
                    
                    // Second row: Show Answer and Show Solution
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
                    
                    // Third row: Ask AI (full width)
                    const SizedBox(height: 8),
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
                          'Ask AI for Help',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                    ),
                  ],
                ),
                
                // Solution Section
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
                        Text(
                          question['solution'] as String,
                          style: const TextStyle(
                            color: Color(0xFF6B7280),
                            fontSize: 12,
                            height: 1.4,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Test Questions',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            Text(
              '${widget.course} • ${widget.session}',
              style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
            ),
          ],
        ),
        backgroundColor: Colors.white,
        elevation: 1,
        foregroundColor: const Color(0xFF1A1A2E),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _questions.length,
        itemBuilder: (context, index) => _buildQuestionCard(index),
      ),
    );
  }
}