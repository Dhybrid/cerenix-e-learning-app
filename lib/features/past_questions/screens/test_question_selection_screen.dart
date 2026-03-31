// lib/features/test_questions/screens/test_questions_selection_screen.dart

import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../../core/network/api_service.dart';
import '../../../features/courses/models/course_models.dart';
import '../models/test_question_models.dart';

class TestQuestionsSelectionScreen extends StatefulWidget {
  const TestQuestionsSelectionScreen({super.key});

  @override
  State<TestQuestionsSelectionScreen> createState() =>
      _TestQuestionsSelectionScreenState();
}

class _TestQuestionsSelectionScreenState
    extends State<TestQuestionsSelectionScreen> {
  final ApiService _apiService = ApiService();

  String? _selectedSessionId;
  String? _selectedSessionName;
  String? _selectedCourseId;
  String? _selectedTopicId;
  String? _selectedTopicName;
  bool _randomMode = false;
  bool _isLoading = false;
  bool _hasOfflineCourses = false;

  List<TestQuestionSession> _sessions = [];
  List<Course> _courses = [];
  List<Map<String, dynamic>> _offlineTopics = [];

  bool _loadingTopics = false;
  String? _topicError;

  static const String offlineCoursesBox = 'offline_courses';

  bool get _isDark => Theme.of(context).brightness == Brightness.dark;
  Color get _pageBackground =>
      _isDark ? const Color(0xFF09111F) : const Color(0xFFF8FAFC);
  Color get _surfaceColor => _isDark ? const Color(0xFF101A2B) : Colors.white;
  Color get _secondarySurfaceColor =>
      _isDark ? const Color(0xFF162235) : const Color(0xFFF8FAFC);
  Color get _borderColor =>
      _isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE2E8F0);
  Color get _titleColor =>
      _isDark ? const Color(0xFFF8FAFC) : const Color(0xFF1A1A2E);
  Color get _bodyColor =>
      _isDark ? const Color(0xFFCBD5E1) : const Color(0xFF6B7280);

  @override
  void initState() {
    super.initState();
    _loadOfflineData();
  }

  Future<void> _loadOfflineData() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      _hasOfflineCourses = false;
    });

    try {
      await _loadOfflineCourses();
      await _loadOfflineSessions();

      setState(() {
        _hasOfflineCourses = _courses.isNotEmpty;
      });

      if (_courses.isNotEmpty) {
        _selectedCourseId = _courses.first.id;
        await _loadTopicsFromOfflineCourse(_selectedCourseId!);
      }
    } catch (e) {
      print('❌ Error loading offline data: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadOfflineCourses() async {
    try {
      final offlineBox = await Hive.openBox(offlineCoursesBox);
      final downloadedCourseIds = offlineBox.get(
        'downloaded_course_ids',
        defaultValue: <String>[],
      );

      final offlineCourses = <Course>[];
      for (var courseId in downloadedCourseIds) {
        try {
          final courseData = offlineBox.get('course_$courseId');
          if (courseData != null && courseData['course'] != null) {
            final courseJson = Map<String, dynamic>.from(courseData['course']);

            Color color;
            if (courseJson['color'] is int) {
              color = Color(courseJson['color'] as int);
            } else if (courseJson['color_value'] is int) {
              color = Color(courseJson['color_value'] as int);
            } else {
              color = Course.generateColorFromCode(
                courseJson['code']?.toString() ?? '',
              );
            }

            offlineCourses.add(
              Course(
                id: courseJson['id']?.toString() ?? courseId,
                code: courseJson['code']?.toString() ?? 'Unknown',
                title: courseJson['title']?.toString() ?? 'No Title',
                description: courseJson['description']?.toString(),
                imageUrl: courseJson['image_url']?.toString(),
                abbreviation: courseJson['abbreviation']?.toString(),
                creditUnits: courseJson['credit_units'] is int
                    ? courseJson['credit_units'] as int
                    : 0,
                universityId: courseJson['university_id']?.toString() ?? '',
                universityName: courseJson['university_name']?.toString() ?? '',
                levelId: courseJson['level_id']?.toString() ?? '',
                levelName: courseJson['level_name']?.toString() ?? '',
                semesterId: courseJson['semester_id']?.toString() ?? '',
                semesterName: courseJson['semester_name']?.toString() ?? '',
                departmentsInfo: courseJson['departments_info'] ?? [],
                progress: courseJson['progress'] is int
                    ? courseJson['progress'] as int
                    : 0,
                isDownloaded: true,
                downloadDate: DateTime.now(),
                localImagePath: courseJson['local_image_path']?.toString(),
                color: color,
              ),
            );
          }
        } catch (e) {
          print('⚠️ Error loading offline course $courseId: $e');
        }
      }

      setState(() {
        _courses = offlineCourses;
        if (_courses.isNotEmpty && _selectedCourseId == null) {
          _selectedCourseId = _courses.first.id;
        }
      });

      print('✅ Loaded ${offlineCourses.length} offline courses');
    } catch (e) {
      print('❌ Error loading offline courses: $e');
      setState(() => _courses = []);
    }
  }

  Future<void> _loadOfflineSessions() async {
    try {
      final offlineBox = await Hive.openBox(offlineCoursesBox);
      final downloadedCourseIds = offlineBox.get(
        'downloaded_course_ids',
        defaultValue: <String>[],
      );

      final sessionSet = <String, TestQuestionSession>{};

      for (var courseId in downloadedCourseIds) {
        final courseData = offlineBox.get('course_$courseId');
        if (courseData == null) continue;

        // Read from test_questions
        final testQuestions = courseData['test_questions'];
        if (testQuestions == null) continue;

        for (var tq in testQuestions as List) {
          if (tq is! Map) continue;
          final sessionData = tq['session_info'] ?? tq['session'];
          if (sessionData is Map) {
            final id = sessionData['id']?.toString();
            final name = sessionData['name']?.toString();
            if (id != null && name != null && !sessionSet.containsKey(id)) {
              sessionSet[id] = TestQuestionSession(
                id: id,
                name: name,
                isActive: true,
              );
            }
          }
        }
      }

      final sessionList = sessionSet.values.toList();
      sessionList.sort((a, b) => b.name.compareTo(a.name));

      setState(() {
        _sessions = sessionList;
        _selectedSessionId = null;
        _selectedSessionName = null;
      });

      print('✅ Loaded ${sessionList.length} sessions from offline data');
    } catch (e) {
      print('❌ Error loading offline sessions: $e');
      setState(() => _sessions = []);
    }
  }

  Future<void> _loadTopicsFromOfflineCourse(String courseId) async {
    setState(() {
      _loadingTopics = true;
      _offlineTopics.clear();
      _selectedTopicId = null;
      _selectedTopicName = null;
      _topicError = null;
    });

    try {
      final offlineBox = await Hive.openBox(offlineCoursesBox);
      final courseData = offlineBox.get('course_$courseId');

      if (courseData == null) {
        setState(() => _topicError = 'No offline data for this course');
        return;
      }

      final outlinesList = <Map<String, dynamic>>[];
      final seenIds = <String>{};

      // Extract outline info from topic_info in test_questions
      final testQuestions = courseData['test_questions'];
      if (testQuestions != null) {
        for (var q in testQuestions as List) {
          if (q is! Map) continue;
          final topicInfo = q['topic_info'];
          if (topicInfo is Map) {
            final id = topicInfo['id']?.toString();
            final title = topicInfo['title']?.toString();
            if (id != null && title != null && !seenIds.contains(id)) {
              seenIds.add(id);
              outlinesList.add({'id': id, 'title': title});
            }
          }
        }
      }

      // Fallback: extract from topics[].outline_info
      if (outlinesList.isEmpty && courseData['topics'] != null) {
        for (var topic in courseData['topics'] as List) {
          if (topic is! Map) continue;
          final outlineInfo = topic['outline_info'] ?? topic['outline'];
          if (outlineInfo is Map) {
            final id = outlineInfo['id']?.toString();
            final title = outlineInfo['title']?.toString();
            if (id != null && title != null && !seenIds.contains(id)) {
              seenIds.add(id);
              outlinesList.add({'id': id, 'title': title});
            }
          }
        }
      }

      setState(() {
        _offlineTopics = outlinesList;
        _topicError = outlinesList.isEmpty
            ? 'No outlines found in downloaded data'
            : null;
      });

      print('✅ Loaded ${outlinesList.length} outlines from offline data');
    } catch (e) {
      print('❌ Error loading outlines: $e');
      setState(() => _topicError = 'Error loading outlines');
    } finally {
      if (mounted) setState(() => _loadingTopics = false);
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
      final selectedCourse = _courses.firstWhere(
        (c) => c.id == _selectedCourseId,
      );

      Navigator.pushNamed(
        context,
        '/test-questions-screen',
        arguments: {
          'courseId': _selectedCourseId!,
          'courseName': '${selectedCourse.code} - ${selectedCourse.title}',
          'sessionId': _selectedSessionId,
          'sessionName': _selectedSessionName ?? 'All Sessions',
          'topicId': _selectedTopicId,
          'topicName': _selectedTopicName,
          'randomMode': _randomMode,
        },
      );
    } catch (e) {
      print('❌ Error navigating: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _pageBackground,
      appBar: AppBar(
        title: const Text(
          'Test Questions',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: _surfaceColor,
        elevation: 1,
        foregroundColor: _titleColor,
      ),
      body: _isLoading && _courses.isEmpty && _sessions.isEmpty
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF6366F1)),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Practice Test Questions',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: _titleColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Select filters and start practicing offline',
                    style: TextStyle(fontSize: 14, color: _bodyColor),
                  ),
                  const SizedBox(height: 24),

                  // Offline notice
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: _hasOfflineCourses
                          ? Colors.green.withValues(
                              alpha: _isDark ? 0.16 : 0.08,
                            )
                          : Colors.orange.withValues(
                              alpha: _isDark ? 0.16 : 0.08,
                            ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _hasOfflineCourses
                            ? Colors.green.withValues(
                                alpha: _isDark ? 0.35 : 0.3,
                              )
                            : Colors.orange.withValues(
                                alpha: _isDark ? 0.35 : 0.3,
                              ),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _hasOfflineCourses
                              ? Icons.download_done_rounded
                              : Icons.wifi_off_rounded,
                          color: _hasOfflineCourses
                              ? Colors.green.shade700
                              : Colors.orange.shade700,
                          size: 22,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _hasOfflineCourses
                                    ? 'Offline Mode'
                                    : 'No Downloaded Courses',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: _hasOfflineCourses
                                      ? Colors.green.shade700
                                      : Colors.orange.shade700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _hasOfflineCourses
                                    ? 'Using ${_courses.length} downloaded course${_courses.length == 1 ? '' : 's'}'
                                    : 'Please download courses when online to access test questions.',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: _bodyColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Configuration Section
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: _surfaceColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: _borderColor),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(
                            alpha: _isDark ? 0.22 : 0.05,
                          ),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.settings_rounded,
                              color: Color(0xFF6366F1),
                              size: 20,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Quiz Setup',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: _titleColor,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),

                        _buildOptionCard(
                          icon: Icons.shuffle_rounded,
                          title: 'Random Questions',
                          subtitle: 'Shuffle questions from all sessions',
                          value: _randomMode,
                          onChanged: (value) {
                            setState(() {
                              _randomMode = value;
                              if (value) {
                                _selectedTopicId = null;
                                _selectedTopicName = null;
                              }
                            });
                          },
                          activeColor: const Color(0xFF6366F1),
                        ),
                        const SizedBox(height: 16),

                        _buildSessionDropdown(),
                        const SizedBox(height: 16),

                        _buildCourseDropdown(),
                        const SizedBox(height: 16),

                        if (!_randomMode) ...[
                          _buildTopicDropdown(),
                          const SizedBox(height: 16),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed:
                          (_isLoading ||
                              _loadingTopics ||
                              _selectedCourseId == null ||
                              !_hasOfflineCourses)
                          ? null
                          : _loadQuestions,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6366F1),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: _isLoading || _loadingTopics
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.play_arrow_rounded, size: 20),
                                SizedBox(width: 8),
                                Text(
                                  'Load Questions',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),

                  const SizedBox(height: 24),
                  _buildFeaturesGrid(),
                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }

  Widget _buildOptionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required Function(bool) onChanged,
    required Color activeColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: value ? activeColor.withValues(alpha: 0.35) : _borderColor,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: _isDark ? 0.18 : 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: value
                  ? activeColor.withValues(alpha: 0.14)
                  : _secondarySurfaceColor,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              color: value ? activeColor : Colors.grey.shade600,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: _titleColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: _bodyColor,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: (_isLoading || !_hasOfflineCourses) ? null : onChanged,
            activeColor: activeColor,
            inactiveTrackColor: Colors.grey.shade400,
          ),
        ],
      ),
    );
  }

  Widget _buildSessionDropdown() {
    final isDisabled = _isLoading;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(left: 4, bottom: 6),
          child: Text(
            'Academic Session',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: _titleColor,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: _surfaceColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _borderColor),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: _isDark ? 0.18 : 0.05),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: DropdownButton<String>(
              value: _selectedSessionId,
              isExpanded: true,
              underline: const SizedBox(),
              icon: Icon(
                Icons.arrow_drop_down_rounded,
                color: isDisabled ? Colors.grey : const Color(0xFF6366F1),
                size: 24,
              ),
              items: [
                DropdownMenuItem<String>(
                  value: null,
                  child: Row(
                    children: [
                      Icon(
                        Icons.all_inclusive_rounded,
                        size: 18,
                        color: isDisabled
                            ? Colors.grey
                            : const Color(0xFF6366F1),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'All Sessions',
                        style: TextStyle(fontSize: 14),
                      ),
                    ],
                  ),
                ),
                ..._sessions.map(
                  (session) => DropdownMenuItem<String>(
                    value: session.id,
                    child: Row(
                      children: [
                        Icon(
                          Icons.calendar_month_rounded,
                          size: 18,
                          color: isDisabled
                              ? Colors.grey
                              : const Color(0xFF6366F1),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            session.name,
                            style: TextStyle(fontSize: 14, color: _titleColor),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              onChanged: isDisabled
                  ? null
                  : (value) {
                      final session = value == null
                          ? null
                          : _sessions.firstWhere(
                              (s) => s.id == value,
                              orElse: () => TestQuestionSession(
                                id: value,
                                name: value,
                                isActive: true,
                              ),
                            );
                      setState(() {
                        _selectedSessionId = value;
                        _selectedSessionName = session?.name;
                      });
                    },
              hint: Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Text(
                  _sessions.isEmpty
                      ? 'No sessions available'
                      : 'Select Session',
                  style: TextStyle(color: _bodyColor),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCourseDropdown() {
    final isDisabled = _isLoading || _courses.isEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(left: 4, bottom: 6),
          child: Text(
            'Course',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: _titleColor,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: _surfaceColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _borderColor),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: _isDark ? 0.18 : 0.05),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
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
                  : Icon(
                      Icons.arrow_drop_down_rounded,
                      color: isDisabled ? Colors.grey : const Color(0xFF6366F1),
                      size: 24,
                    ),
              items: _courses
                  .map(
                    (course) => DropdownMenuItem<String>(
                      value: course.id,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: course.color.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                Icons.menu_book_rounded,
                                size: 18,
                                color: course.color,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        course.code,
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: _titleColor,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.green.shade100,
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.download_done_rounded,
                                              size: 10,
                                              color: Colors.green.shade800,
                                            ),
                                            const SizedBox(width: 2),
                                            Text(
                                              'Downloaded',
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.green.shade800,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    course.title,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: _bodyColor,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                  .toList(),
              onChanged: isDisabled
                  ? null
                  : (value) {
                      setState(() {
                        _selectedCourseId = value;
                        _offlineTopics.clear();
                        _selectedTopicId = null;
                        _selectedTopicName = null;
                        _topicError = null;
                      });
                      if (value != null) {
                        _loadTopicsFromOfflineCourse(value);
                      }
                    },
              hint: Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Text(
                  _courses.isEmpty ? 'No downloaded courses' : 'Select Course',
                  style: TextStyle(color: _bodyColor),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTopicDropdown() {
    final isDisabled = _isLoading || _loadingTopics;
    final hasTopics = _offlineTopics.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(left: 4, bottom: 6),
          child: Text(
            'Course Outline (Optional)',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: _titleColor,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: _surfaceColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _borderColor),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: _isDark ? 0.18 : 0.05),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
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
                  : Icon(
                      Icons.arrow_drop_down_rounded,
                      color: isDisabled ? Colors.grey : const Color(0xFF6366F1),
                      size: 24,
                    ),
              items: [
                DropdownMenuItem<String>(
                  value: null,
                  child: Row(
                    children: [
                      Icon(
                        Icons.all_inclusive_rounded,
                        size: 18,
                        color: isDisabled
                            ? Colors.grey
                            : const Color(0xFF6366F1),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'All Outlines (All Questions)',
                          style: TextStyle(fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                ),
                ..._offlineTopics.map(
                  (outline) => DropdownMenuItem<String>(
                    value: outline['id']?.toString() ?? '',
                    child: Text(
                      outline['title'] ?? 'Unknown',
                      style: TextStyle(fontSize: 14, color: _titleColor),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
              onChanged: isDisabled
                  ? null
                  : (value) {
                      final outlineName = value == null
                          ? null
                          : _offlineTopics.firstWhere(
                                  (o) => o['id']?.toString() == value,
                                  orElse: () => {'title': 'Unknown'},
                                )['title']
                                as String?;
                      setState(() {
                        _selectedTopicId = value;
                        _selectedTopicName = outlineName;
                      });
                    },
              hint: Padding(
                padding: const EdgeInsets.only(left: 4),
                child: _loadingTopics
                    ? const Text('Loading outlines...')
                    : Text(
                        hasTopics
                            ? 'Select Outline (Optional)'
                            : (_topicError ?? 'No outlines available'),
                        style: TextStyle(
                          color: hasTopics ? _bodyColor : Colors.orange,
                        ),
                      ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFeaturesGrid() {
    return GridView.count(
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
        color: _surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: _isDark ? 0.18 : 0.05),
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
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: _titleColor,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(color: _bodyColor, fontSize: 11, height: 1.2),
            ),
          ],
        ),
      ),
    );
  }
}
