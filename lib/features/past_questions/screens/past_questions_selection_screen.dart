// lib/features/past_questions/screens/past_questions_selection_screen.dart
import 'package:flutter/material.dart';
import '../../../core/network/api_service.dart';
import '../../../features/courses/models/course_models.dart';
import '../models/past_question_models.dart';

class PastQuestionsSelectionScreen extends StatefulWidget {
  const PastQuestionsSelectionScreen({super.key});

  @override
  State<PastQuestionsSelectionScreen> createState() => _PastQuestionsSelectionScreenState();
}

class _PastQuestionsSelectionScreenState extends State<PastQuestionsSelectionScreen> {
  final ApiService _apiService = ApiService();
  
  String? _selectedSessionId;
  String? _selectedCourseId;
  String? _selectedTopicId;
  bool _randomMode = false;
  bool _isLoading = false;
  bool _isOffline = false;

  List<PastQuestionSession> _sessions = [];
  List<Course> _courses = [];
  List<Map<String, dynamic>> _topics = []; // Store topics with outline info
  
  // Loading states for dropdowns
  bool _loadingTopics = false;
  String? _topicError;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    if (_isLoading) return;
    
    setState(() {
      _isLoading = true;
      _isOffline = false;
    });

    try {
      // Load all academic sessions first
      final allSessions = await _apiService.getPastQuestionSessions();
      
      // Load courses for the current user
      final userCourses = await _apiService.getCoursesForUser();
      
      setState(() {
        _sessions = allSessions;
        _courses = userCourses;
        
        // Pre-select the first session if available
        if (_sessions.isNotEmpty) {
          _selectedSessionId = _sessions.first.id;
        }
        
        // Pre-select the first course if available
        if (_courses.isNotEmpty) {
          _selectedCourseId = _courses.first.id;
          // Load topics for the first course
          _loadTopicsForCourse(_courses.first.id);
        }
      });
      
    } catch (e) {
      print('❌ Error loading initial data: $e');
      
      if (e.toString().contains('offline') || e.toString().contains('internet')) {
        setState(() {
          _isOffline = true;
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('You are offline. Please check your internet connection.'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 3),
            ),
          );
        }
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadTopicsForCourse(String courseId) async {
    if (courseId.isEmpty) return;
    
    setState(() {
      _loadingTopics = true;
      _topics.clear();
      _selectedTopicId = null;
      _topicError = null;
    });

    try {
      print('📋 Loading topics for course ID: $courseId');
      
      // Use the new method - it already returns maps in the right format
      _topics = await _apiService.getTopicsForPastQuestions(
        courseId: int.parse(courseId)
      );
      
      print('📚 Total topics loaded: ${_topics.length}');
      
      setState(() {
        if (_topics.isEmpty) {
          _topicError = 'No topics available for this course';
        }
      });
    } catch (e) {
      print('❌ Error loading topics: $e');
      setState(() {
        _topicError = 'Failed to load topics: ${e.toString().split(':').first}';
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load topics: ${e.toString().split(':').last.trim()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _loadingTopics = false;
        });
      }
    }
  }

  Future<void> _loadQuestions() async {
    if (_selectedCourseId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a course'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      // Find selected course
      final selectedCourse = _courses.firstWhere(
        (course) => course.id == _selectedCourseId,
      );

      // Find selected session name
      String sessionName = 'All Sessions';
      if (_selectedSessionId != null && _selectedSessionId!.isNotEmpty) {
        final session = _sessions.firstWhere(
          (session) => session.id == _selectedSessionId,
          orElse: () => PastQuestionSession(id: '', name: 'All Sessions', isActive: false),
        );
        sessionName = session.name;
      }

      // Find selected topic - FIXED: Handle null properly
      String? topicName;
      String? topicIdToSend;
      
      if (_selectedTopicId != null && _selectedTopicId!.isNotEmpty) {
        // Check if we have topics loaded
        if (_topics.isNotEmpty) {
          final topic = _topics.firstWhere(
            (topic) => topic['id']?.toString() == _selectedTopicId,
            orElse: () => {'title': 'Unknown', 'id': null},
          );
          topicName = topic['title'] ?? 'Unknown';
          topicIdToSend = topic['id']?.toString();
        } else {
          // No topics loaded, but we have a topic ID (this shouldn't happen)
          topicIdToSend = _selectedTopicId;
          topicName = 'Selected Topic';
        }
        
        print('📌 Selected topic: $topicName (ID: $topicIdToSend)');
      } else {
        print('📌 No specific topic selected - will show all questions for course');
        topicName = null;
        topicIdToSend = null;
      }

      // Navigate to past questions screen
      Navigator.pushNamed(
        context,
        '/past-questions-screen',
        arguments: {
          'courseId': _selectedCourseId!,
          'courseName': '${selectedCourse.code} - ${selectedCourse.title}',
          'sessionId': _selectedSessionId,
          'sessionName': sessionName,
          'topicId': topicIdToSend,
          'topicName': topicName,
          'randomMode': _randomMode,
        },
      );

    } catch (e) {
      print('❌ Error navigating to questions: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildSelectionCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
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
          
          // Offline warning
          if (_isOffline)
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.orange),
              ),
              child: Row(
                children: [
                  const Icon(Icons.wifi_off_rounded, color: Colors.orange, size: 18),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'You are offline. Please reconnect to load data.',
                      style: TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          
          // Random Mode Toggle
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
                  onChanged: _isLoading ? null : (value) {
                    setState(() {
                      _randomMode = value;
                      if (value) {
                        _selectedTopicId = null;
                      }
                    });
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          
          // Session Dropdown
          _buildSessionDropdown(),
          const SizedBox(height: 12),
          
          // Course Dropdown
          _buildCourseDropdown(),
          const SizedBox(height: 12),
          
          // Topic Dropdown (only show if not random mode)
          if (!_randomMode) ...[
            _buildTopicDropdown(),
            const SizedBox(height: 12),
          ],
          
          // Load Questions Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: (_isLoading || _loadingTopics || _selectedCourseId == null) ? null : _loadQuestions,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF6366F1),
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: (_isLoading || _loadingTopics)
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Row(
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

  Widget _buildSessionDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Academic Session',
          style: TextStyle(
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
              value: _selectedSessionId,
              isExpanded: true,
              underline: const SizedBox(),
              icon: const Icon(Icons.arrow_drop_down_rounded, color: Color(0xFF6366F1), size: 20),
              style: const TextStyle(color: Color(0xFF1A1A2E), fontSize: 13),
              items: [
                // Add "All Sessions" option
                const DropdownMenuItem<String>(
                  value: null,
                  child: Row(
                    children: [
                      Icon(Icons.all_inclusive_rounded, size: 16, color: Color(0xFF6366F1)),
                      SizedBox(width: 8),
                      Text('All Sessions', style: TextStyle(fontSize: 13)),
                    ],
                  ),
                ),
                // Add actual sessions
                ..._sessions.map((session) {
                  return DropdownMenuItem<String>(
                    value: session.id,
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_month_rounded, size: 16, color: Color(0xFF6366F1)),
                        const SizedBox(width: 8),
                        Text(session.name, style: const TextStyle(fontSize: 13)),
                      ],
                    ),
                  );
                }).toList(),
              ],
              onChanged: _isLoading ? null : (value) {
                setState(() {
                  _selectedSessionId = value;
                });
              },
              hint: const Text(
                'Select Session',
                style: TextStyle(color: Colors.grey, fontSize: 13),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCourseDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Course',
          style: TextStyle(
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
              value: _selectedCourseId,
              isExpanded: true,
              underline: const SizedBox(),
              icon: _loadingTopics
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.arrow_drop_down_rounded, color: Color(0xFF6366F1), size: 20),
              style: const TextStyle(color: Color(0xFF1A1A2E), fontSize: 13),
              items: _courses.map((course) {
                return DropdownMenuItem<String>(
                  value: course.id,
                  child: Row(
                    children: [
                      const Icon(Icons.menu_book_rounded, size: 16, color: Color(0xFF6366F1)),
                      const SizedBox(width: 8),
                      Text('${course.code} - ${course.title}', 
                           style: const TextStyle(fontSize: 13),
                           maxLines: 1,
                           overflow: TextOverflow.ellipsis),
                    ],
                  ),
                );
              }).toList(),
              onChanged: _isLoading ? null : (value) {
                setState(() {
                  _selectedCourseId = value;
                  // Reset topics when course changes
                  _topics.clear();
                  _selectedTopicId = null;
                  _topicError = null;
                });
                // Load topics for the selected course
                if (value != null) {
                  _loadTopicsForCourse(value);
                }
              },
              hint: const Text(
                'Select Course',
                style: TextStyle(color: Colors.grey, fontSize: 13),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTopicDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Topic',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w500,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 8),
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
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: DropdownButton<String>(
              value: _selectedTopicId,
              isExpanded: true,
              underline: const SizedBox(),
              icon: _loadingTopics
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.arrow_drop_down_rounded, color: Color(0xFF6366F1), size: 20),
              style: const TextStyle(color: Color(0xFF1A1A2E), fontSize: 13),
              items: [
                // "All Topics" option - IMPORTANT: This sends NULL topic
                const DropdownMenuItem<String>(
                  value: null,
                  child: Row(
                    children: [
                      Icon(Icons.all_inclusive_rounded, size: 16, color: Color(0xFF6366F1)),
                      SizedBox(width: 8),
                      Text('All Topics (General Questions)', style: TextStyle(fontSize: 13)),
                    ],
                  ),
                ),
                // Add actual topics
                ..._topics.map((topic) {
                  return DropdownMenuItem<String>(
                    value: topic['id']?.toString() ?? '',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          topic['title'] ?? 'Unknown',
                          style: const TextStyle(fontSize: 13),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (topic['outlineTitle'] != null)
                          Text(
                            'Outline: ${topic['outlineTitle']}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.grey,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  );
                }).toList(),
              ],
              onChanged: (_isLoading || _loadingTopics) ? null : (value) {
                setState(() {
                  _selectedTopicId = value;
                  print('Selected topic ID: $value');
                });
              },
              hint: _loadingTopics
                  ? const Row(
                      children: [
                        SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                        SizedBox(width: 8),
                        Text('Loading topics...', style: TextStyle(fontSize: 13)),
                      ],
                    )
                  : (_topicError != null && _topics.isEmpty)
                    ? Text(
                        _topicError!,
                        style: const TextStyle(color: Colors.orange, fontSize: 12),
                      )
                    : const Text(
                        'Select Topic (Optional)',
                        style: TextStyle(color: Colors.grey, fontSize: 13),
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
          'Past Questions',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: const Color(0xFF1A1A2E),
      ),
      body: _isLoading && _sessions.isEmpty && _courses.isEmpty
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  const Text(
                    'Practice Past Questions',
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