// lib/features/past_questions/screens/test_question_selection_screen.dart
import 'package:flutter/material.dart';

class TestQuestionsSelectionScreen extends StatefulWidget {
  const TestQuestionsSelectionScreen({super.key});

  @override
  State<TestQuestionsSelectionScreen> createState() => _TestQuestionsSelectionScreenState();
}

class _TestQuestionsSelectionScreenState extends State<TestQuestionsSelectionScreen> {
  String? _selectedSession;
  String? _selectedCourse;
  String? _selectedTopic;
  bool _randomMode = false;

  final List<String> _sessions = ['2022/2023', '2021/2022', '2020/2021', '2019/2020'];
  final List<String> _courses = ['PHY 101', 'MTH 112', 'CHM 101', 'BIO 101', 'CSC 101'];
  final List<String> _topics = ['Mechanics', 'Thermodynamics', 'Electromagnetism', 'Waves', 'Modern Physics'];

  void _loadQuestions() {
    Navigator.pushNamed(context, '/test-questions-screen');
  }

  Widget _buildSelectionCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20), // Reduced padding
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6366F1).withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.quiz_rounded, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Text(
                'Quiz Setup',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Random Mode Toggle - FIXED LAYOUT
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Icon(Icons.shuffle_rounded, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Random Questions',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500, fontSize: 14),
                  ),
                ),
                Switch(
                  value: _randomMode,
                  activeColor: const Color(0xFF6366F1),
                  activeTrackColor: Colors.white,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  onChanged: (value) {
                    setState(() {
                      _randomMode = value;
                      if (value) _selectedTopic = null;
                    });
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          
          // Selection Fields
          _buildSelectionField(
            label: 'Academic Session',
            value: _selectedSession,
            items: _sessions,
            onChanged: (value) => setState(() => _selectedSession = value),
            icon: Icons.calendar_month_rounded,
          ),
          const SizedBox(height: 12),
          
          _buildSelectionField(
            label: 'Course',
            value: _selectedCourse,
            items: _courses,
            onChanged: (value) => setState(() => _selectedCourse = value),
            icon: Icons.menu_book_rounded,
          ),
          const SizedBox(height: 12),
          
          if (!_randomMode)
            _buildSelectionField(
              label: 'Topic (Optional)',
              value: _selectedTopic,
              items: _topics,
              onChanged: (value) => setState(() => _selectedTopic = value),
              icon: Icons.category_rounded,
            ),
          
          if (!_randomMode) const SizedBox(height: 12),
          
          // Load Questions Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _loadQuestions,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF6366F1),
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Load Questions',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(width: 6),
                  Icon(Icons.arrow_forward_rounded, size: 18),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectionField({
    required String label,
    required String? value,
    required List<String> items,
    required Function(String?) onChanged,
    required IconData icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w500,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 5,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              underline: const SizedBox(),
              icon: const Icon(Icons.arrow_drop_down_rounded, color: Color(0xFF6366F1), size: 20),
              style: const TextStyle(color: Color(0xFF1A1A2E), fontSize: 13),
              items: items.map((String item) {
                return DropdownMenuItem<String>(
                  value: item,
                  child: Row(
                    children: [
                      Icon(icon, size: 16, color: const Color(0xFF6366F1)),
                      const SizedBox(width: 8),
                      Text(item, style: const TextStyle(fontSize: 13)),
                    ],
                  ),
                );
              }).toList(),
              onChanged: onChanged,
              hint: Text(
                'Select $label',
                style: const TextStyle(color: Colors.grey, fontSize: 13),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFeatureCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Color(0xFF1A1A2E),
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: const TextStyle(
                color: Color(0xFF6B7280),
                fontSize: 11,
                height: 1.2,
              ),
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
        title: const Text(
          'Test Questions',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: const Color(0xFF1A1A2E),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            const Text(
              'Practice Test Questions',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A1A2E),
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Select your parameters to start practicing',
              style: TextStyle(
                color: Color(0xFF6B7280),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 20),
            
            // Selection Card
            _buildSelectionCard(),
            const SizedBox(height: 20),
            
            // Features Grid
            const Text(
              'Features',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A1A2E),
              ),
            ),
            const SizedBox(height: 12),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              childAspectRatio: 1.1,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              children: [
                _buildFeatureCard(
                  icon: Icons.auto_awesome_rounded,
                  title: 'AI Explanation',
                  subtitle: 'Get AI explanations',
                  color: const Color(0xFF8B5CF6),
                ),
                _buildFeatureCard(
                  icon: Icons.bookmark_rounded,
                  title: 'Bookmark',
                  subtitle: 'Save questions',
                  color: const Color(0xFFF59E0B),
                ),
                _buildFeatureCard(
                  icon: Icons.flag_rounded,
                  title: 'Flag Questions',
                  subtitle: 'Mark for review',
                  color: const Color(0xFFEF4444),
                ),
                _buildFeatureCard(
                  icon: Icons.analytics_rounded,
                  title: 'Progress',
                  subtitle: 'Track learning',
                  color: const Color(0xFF10B981),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}