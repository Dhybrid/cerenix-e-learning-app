// lib/features/cbt/screens/cbt_selection_screen.dart
import 'package:flutter/material.dart';

class CBTSelectionScreen extends StatefulWidget {
  const CBTSelectionScreen({super.key});

  @override
  State<CBTSelectionScreen> createState() => _CBTSelectionScreenState();
}

class _CBTSelectionScreenState extends State<CBTSelectionScreen> {
  String? _selectedSession;
  String? _selectedCourse;
  String? _selectedTopic;
  bool _randomMode = false;
  bool _enableTimer = false;

  final List<String> _sessions = [
    '2023/2024',
    '2022/2023', 
    '2021/2022',
    '2020/2021'
  ];

  final List<String> _courses = [
    'Physics',
    'Mathematics',
    'Chemistry',
    'Biology',
    'English'
  ];

  final List<String> _topics = [
    'Mechanics',
    'Thermodynamics',
    'Electromagnetism',
    'Optics',
    'Waves'
  ];

  void _startCBT() {
    if (!_randomMode && (_selectedSession == null || _selectedCourse == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select session and course'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_randomMode && _selectedCourse == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a course for random questions'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    Navigator.pushNamed(
      context,
      '/cbtquestions',
      arguments: {
        'session': _selectedSession ?? 'Random',
        'course': _selectedCourse!,
        'topic': _selectedTopic,
        'randomMode': _randomMode,
        'enableTimer': _enableTimer,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'CBT Practice',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1A1A2E),
        elevation: 1,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Random Mode Toggle
            Container(
              padding: const EdgeInsets.all(16),
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
                  const Icon(Icons.shuffle_rounded, color: Color(0xFF6366F1)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Random Questions',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          'Get random questions from all sessions',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: _randomMode,
                    onChanged: (value) {
                      setState(() {
                        _randomMode = value;
                        if (value) {
                          _selectedSession = null;
                        }
                      });
                    },
                    activeColor: const Color(0xFF6366F1),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Session Dropdown
            if (!_randomMode) ...[
              _buildDropdown(
                'Academic Session',
                _selectedSession,
                _sessions,
                (value) => setState(() => _selectedSession = value),
                Icons.calendar_today_rounded,
              ),
              const SizedBox(height: 12),
            ],

            // Course Dropdown
            _buildDropdown(
              'Course',
              _selectedCourse,
              _courses,
              (value) => setState(() => _selectedCourse = value),
              Icons.menu_book_rounded,
            ),

            const SizedBox(height: 12),

            // Topic Dropdown (Optional)
            _buildDropdown(
              'Topic (Optional)',
              _selectedTopic,
              _topics,
              (value) => setState(() => _selectedTopic = value),
              Icons.topic_rounded,
            ),

            const SizedBox(height: 16),

            // Timer Toggle
            Container(
              padding: const EdgeInsets.all(16),
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
                  const Icon(Icons.timer_rounded, color: Color(0xFFF59E0B)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Enable Timer',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          'Set time limit for the exam',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: _enableTimer,
                    onChanged: (value) => setState(() => _enableTimer = value),
                    activeColor: const Color(0xFFF59E0B),
                  ),
                ],
              ),
            ),

            const Spacer(),

            // Start Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _startCBT,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6366F1),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Start CBT Practice',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDropdown(
    String label,
    String? value,
    List<String> items,
    Function(String?) onChanged,
    IconData icon,
  ) {
    return Container(
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
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: DropdownButtonFormField<String>(
          value: value,
          onChanged: onChanged,
          decoration: InputDecoration(
            labelText: label,
            border: InputBorder.none,
            icon: Icon(icon, color: const Color(0xFF6366F1)),
          ),
          items: [
            DropdownMenuItem(
              value: null,
              child: Text('Select $label'),
            ),
            ...items.map((item) {
              return DropdownMenuItem(
                value: item,
                child: Text(item),
              );
            }),
          ],
        ),
      ),
    );
  }
}