// lib/features/cbt/screens/cbt_selection_screen.dart
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../../../core/network/api_service.dart';
import '../../../features/courses/models/course_models.dart';
import '../models/past_question_models.dart';

class CBTSelectionScreen extends StatefulWidget {
  const CBTSelectionScreen({super.key});

  @override
  State<CBTSelectionScreen> createState() => _CBTSelectionScreenState();
}

class _CBTSelectionScreenState extends State<CBTSelectionScreen> {
  final ApiService _apiService = ApiService();
  final Connectivity _connectivity = Connectivity();

  String? _selectedSessionId;
  String? _selectedCourseId;
  String? _selectedTopicId;
  bool _randomMode = false;
  bool _enableTimer = false;
  bool _isLoading = false;
  bool _isOffline = false;
  bool _hasOfflineCourses = false;

  List<PastQuestionSession> _sessions = [];
  List<Course> _courses = [];
  List<Map<String, dynamic>> _topics = [];

  // Loading states
  bool _loadingTopics = false;
  String? _topicError;

  // Hive boxes
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
    _checkConnectivityAndLoadData();
  }

  Future<void> _checkConnectivityAndLoadData() async {
    final connectivityResult = await _connectivity.checkConnectivity();
    final isOnline = connectivityResult != ConnectivityResult.none;

    setState(() {
      _isOffline = !isOnline;
    });

    // CBT is offline-only, so we always load offline data
    await _loadOfflineData();
  }

  Future<void> _loadOfflineData() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      _isOffline = true;
      _hasOfflineCourses = false;
    });

    try {
      print('📴 CBT: Loading offline data...');

      // Load offline courses
      await _loadOfflineCourses();

      // Load offline sessions
      await _loadOfflineSessions();

      // Pre-select the first course if available
      if (_courses.isNotEmpty) {
        _selectedCourseId = _courses.first.id;
        print('📌 CBT: Pre-selected course: $_selectedCourseId');

        // Load topics for the first course
        await _loadTopicsFromOfflineCourse(_selectedCourseId!);
      } else {
        print('⚠️ CBT: No offline courses found');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'No downloaded courses found. Please download courses when online to use CBT.',
              ),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 3),
            ),
          );
        }
      }

      setState(() {
        _hasOfflineCourses = _courses.isNotEmpty;
      });
    } catch (e) {
      print('❌ CBT: Error loading offline data: $e');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Error loading offline data. Please check your storage.',
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadOfflineCourses() async {
    try {
      final offlineBox = await Hive.openBox(offlineCoursesBox);
      final downloadedCourseIds = offlineBox.get(
        'downloaded_course_ids',
        defaultValue: <String>[],
      );

      print('📂 CBT: Found ${downloadedCourseIds.length} downloaded courses');

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

            final course = Course(
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
            );

            offlineCourses.add(course);
          }
        } catch (e) {
          print('⚠️ CBT: Error loading offline course $courseId: $e');
        }
      }

      // Sort courses: downloaded first, then by code
      offlineCourses.sort((a, b) {
        if (a.isDownloaded && !b.isDownloaded) return -1;
        if (!a.isDownloaded && b.isDownloaded) return 1;
        return a.code.compareTo(b.code);
      });

      setState(() {
        _courses = offlineCourses;

        // Pre-select the first course if available
        if (_courses.isNotEmpty && _selectedCourseId == null) {
          _selectedCourseId = _courses.first.id;
        }
      });

      print('✅ CBT: Loaded ${offlineCourses.length} offline courses');
    } catch (e) {
      print('❌ CBT: Error loading offline courses: $e');
      setState(() {
        _courses = [];
      });
    }
  }

  Future<void> _loadOfflineSessions() async {
    try {
      print('📅 CBT: Loading offline sessions...');

      final offlineBox = await Hive.openBox(offlineCoursesBox);
      final downloadedCourseIds = offlineBox.get(
        'downloaded_course_ids',
        defaultValue: <String>[],
      );

      // First, try to load from cache
      final cachedSessions = offlineBox.get('offline_sessions_cache');
      if (cachedSessions != null && cachedSessions is List) {
        print('📂 CBT: Loading sessions from cache');
        final sessions = cachedSessions.map((sessionJson) {
          return PastQuestionSession.fromJson(
            Map<String, dynamic>.from(sessionJson),
          );
        }).toList();

        setState(() {
          _sessions = sessions;
          if (_sessions.isNotEmpty && _selectedSessionId == null) {
            _selectedSessionId = _sessions.first.id;
          }
        });
        return;
      }

      // Extract sessions from all downloaded courses
      final sessionSet = <String, PastQuestionSession>{};

      for (var courseId in downloadedCourseIds) {
        try {
          final courseData = offlineBox.get('course_$courseId');
          if (courseData == null) continue;

          // Check past questions
          if (courseData['past_questions'] != null) {
            final pastQuestions = courseData['past_questions'] as List;
            for (var pq in pastQuestions) {
              if (pq is Map) {
                final sessionData = pq['session_info'] ?? pq['session'];
                if (sessionData is Map) {
                  final sessionId = sessionData['id']?.toString();
                  final sessionName = sessionData['name']?.toString();

                  if (sessionId != null &&
                      sessionName != null &&
                      !sessionSet.containsKey(sessionId)) {
                    sessionSet[sessionId] = PastQuestionSession(
                      id: sessionId,
                      name: sessionName,
                      isActive: true,
                    );
                  }
                }
              }
            }
          }

          // Check test questions
          if (courseData['test_questions'] != null) {
            final testQuestions = courseData['test_questions'] as List;
            for (var tq in testQuestions) {
              if (tq is Map && tq['session'] != null) {
                final sessionData = tq['session'];
                if (sessionData is Map) {
                  final sessionId = sessionData['id']?.toString();
                  final sessionName = sessionData['name']?.toString();

                  if (sessionId != null &&
                      sessionName != null &&
                      !sessionSet.containsKey(sessionId)) {
                    sessionSet[sessionId] = PastQuestionSession(
                      id: sessionId,
                      name: sessionName,
                      isActive: true,
                    );
                  }
                }
              }
            }
          }
        } catch (e) {
          print('⚠️ CBT: Error extracting sessions from course $courseId: $e');
        }
      }

      // Create session list
      final sessionList = sessionSet.values.toList();

      // Sort sessions by name
      sessionList.sort((a, b) => a.name.compareTo(b.name));

      // Add "All Sessions" option at the beginning
      sessionList.insert(
        0,
        PastQuestionSession(id: '', name: 'All Sessions', isActive: true),
      );

      print('✅ CBT: Extracted ${sessionList.length} sessions');

      // Cache the sessions
      final sessionCache = sessionList
          .map((session) => session.toJson())
          .toList();
      await offlineBox.put('offline_sessions_cache', sessionCache);

      setState(() {
        _sessions = sessionList;
        if (_sessions.isNotEmpty && _selectedSessionId == null) {
          _selectedSessionId = _sessions.first.id; // "All Sessions"
        }
      });
    } catch (e) {
      print('❌ CBT: Error loading offline sessions: $e');

      // Fallback
      setState(() {
        _sessions = [
          PastQuestionSession(id: '', name: 'All Sessions', isActive: true),
        ];
        _selectedSessionId = '';
      });
    }
  }

  // Future<void> _loadTopicsFromOfflineCourse(String courseId) async {
  //   try {
  //     print('📋 CBT: Loading offline topics for course: $courseId');

  //     final offlineBox = await Hive.openBox(offlineCoursesBox);
  //     final courseData = offlineBox.get('course_$courseId');

  //     if (courseData == null) {
  //       throw Exception('No offline data found for this course');
  //     }

  //     final topicsList = <Map<String, dynamic>>[];

  //     // Extract topics from course topics
  //     if (courseData['topics'] != null) {
  //       final courseTopics = courseData['topics'] as List;
  //       for (var topic in courseTopics) {
  //         if (topic is Map) {
  //           final topicId = topic['id']?.toString();
  //           final topicTitle = topic['title']?.toString();
  //           final outline = topic['outline_info'] ?? topic['outline'];

  //           if (topicId != null && topicTitle != null) {
  //             if (!topicsList.any((t) => t['id'] == topicId)) {
  //               topicsList.add({
  //                 'id': topicId,
  //                 'title': topicTitle,
  //                 'outlineTitle': outline is Map
  //                     ? outline['title']?.toString()
  //                     : 'No Outline',
  //               });
  //             }
  //           }
  //         }
  //       }
  //     }

  //     // Extract topics from past questions
  //     if (courseData['past_questions'] != null) {
  //       final pastQuestions = courseData['past_questions'] as List;
  //       for (var pq in pastQuestions) {
  //         if (pq is Map && pq['topic'] != null) {
  //           final topic = pq['topic'];
  //           if (topic is Map) {
  //             final topicId = topic['id']?.toString();
  //             final topicTitle = topic['title']?.toString();
  //             final outline = topic['outline_info'] ?? topic['outline'];

  //             if (topicId != null && topicTitle != null) {
  //               if (!topicsList.any((t) => t['id'] == topicId)) {
  //                 topicsList.add({
  //                   'id': topicId,
  //                   'title': topicTitle,
  //                   'outlineTitle': outline is Map
  //                       ? outline['title']?.toString()
  //                       : 'No Outline',
  //                 });
  //               }
  //             }
  //           }
  //         }
  //       }
  //     }

  //     // Extract topics from test questions
  //     if (courseData['test_questions'] != null) {
  //       final testQuestions = courseData['test_questions'] as List;
  //       for (var tq in testQuestions) {
  //         if (tq is Map && tq['topic'] != null) {
  //           final topic = tq['topic'];
  //           if (topic is Map) {
  //             final topicId = topic['id']?.toString();
  //             final topicTitle = topic['title']?.toString();
  //             final outline = topic['outline_info'] ?? topic['outline'];

  //             if (topicId != null && topicTitle != null) {
  //               if (!topicsList.any((t) => t['id'] == topicId)) {
  //                 topicsList.add({
  //                   'id': topicId,
  //                   'title': topicTitle,
  //                   'outlineTitle': outline is Map
  //                       ? outline['title']?.toString()
  //                       : 'No Outline',
  //                 });
  //               }
  //             }
  //           }
  //         }
  //       }
  //     }

  //     // Sort topics by title
  //     topicsList.sort((a, b) => (a['title'] ?? '').compareTo(b['title'] ?? ''));

  //     print('📚 CBT: Extracted ${topicsList.length} unique topics');

  //     setState(() {
  //       _topics = topicsList;

  //       if (topicsList.isEmpty) {
  //         _topicError = 'No topics found in offline data';
  //       } else {
  //         _topicError = null;
  //       }
  //     });
  //   } catch (e) {
  //     print('❌ CBT: Error loading offline topics: $e');
  //     setState(() {
  //       _topicError = 'Error loading topics from offline data';
  //       _topics = [];
  //     });
  //   }
  // }

  Future<void> _loadTopicsFromOfflineCourse(String courseId) async {
    try {
      print('📋 CBT: Loading offline topics for course: $courseId');

      setState(() {
        _loadingTopics = true;
        _topics.clear();
        _selectedTopicId = null;
        _topicError = null;
      });

      final offlineBox = await Hive.openBox(offlineCoursesBox);
      final courseData = offlineBox.get('course_$courseId');

      if (courseData == null) {
        setState(() => _topicError = 'No offline data found for this course');
        return;
      }

      final outlinesList = <Map<String, dynamic>>[];
      final seenIds = <String>{};

      // Extract outline info from topic_info in past_questions
      final pastQuestions = courseData['past_questions'];
      if (pastQuestions != null) {
        for (var pq in pastQuestions as List) {
          if (pq is! Map) continue;
          final topicInfo = pq['topic_info'];
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

      // Also extract from topic_info in test_questions
      final testQuestions = courseData['test_questions'];
      if (testQuestions != null) {
        for (var tq in testQuestions as List) {
          if (tq is! Map) continue;
          final topicInfo = tq['topic_info'];
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

      // Sort by title
      outlinesList.sort(
        (a, b) => (a['title'] ?? '').compareTo(b['title'] ?? ''),
      );

      print('📚 CBT: Extracted ${outlinesList.length} unique outlines');

      setState(() {
        _topics = outlinesList;
        _topicError = outlinesList.isEmpty
            ? 'No outlines found in downloaded data'
            : null;
      });
    } catch (e) {
      print('❌ CBT: Error loading offline topics: $e');
      setState(() {
        _topicError = 'Error loading topics from offline data';
        _topics = [];
      });
    } finally {
      if (mounted) setState(() => _loadingTopics = false);
    }
  }

  Future<void> _startCBT() async {
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

      // Handle session
      String sessionName = 'All Sessions';
      String? sessionIdToSend = null;

      if (_selectedSessionId != null && _selectedSessionId!.isNotEmpty) {
        if (_selectedSessionId != '') {
          final session = _sessions.firstWhere(
            (session) => session.id == _selectedSessionId,
            orElse: () => PastQuestionSession(
              id: '',
              name: 'All Sessions',
              isActive: false,
            ),
          );
          sessionName = session.name;
          sessionIdToSend = _selectedSessionId;
        }
      }

      // Handle topic
      String? topicName;
      String? topicIdToSend;

      if (_selectedTopicId != null && _selectedTopicId!.isNotEmpty) {
        if (_topics.isNotEmpty) {
          final topic = _topics.firstWhere(
            (topic) => topic['id']?.toString() == _selectedTopicId,
            orElse: () => {'title': 'Unknown', 'id': null},
          );
          topicName = topic['title'] ?? 'Unknown';
          topicIdToSend = topic['id']?.toString();
        } else {
          topicIdToSend = _selectedTopicId;
          topicName = 'Selected Topic';
        }
      }

      // Navigate to CBT questions screen
      Navigator.pushNamed(
        context,
        '/cbtquestions',
        arguments: {
          'courseId': _selectedCourseId!,
          'courseName': '${selectedCourse.code} - ${selectedCourse.title}',
          'sessionId': sessionIdToSend,
          'sessionName': sessionName,
          'topicId': topicIdToSend,
          'topicName': topicName,
          'randomMode': _randomMode,
          'enableTimer': _enableTimer,
          'isOffline': true,
        },
      );
    } catch (e) {
      print('❌ CBT: Error navigating to questions: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildSessionDropdown() {
    final isDisabled = _isLoading || _sessions.isEmpty;

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
              value: _selectedSessionId ?? '',
              isExpanded: true,
              underline: const SizedBox(),
              icon: Icon(
                Icons.arrow_drop_down_rounded,
                color: isDisabled ? Colors.grey : const Color(0xFF6366F1),
                size: 24,
              ),
              style: TextStyle(
                fontSize: 14,
                color: isDisabled ? Colors.grey : _titleColor,
              ),
              items: _sessions.map((session) {
                final isAllSessions = session.id.isEmpty;
                return DropdownMenuItem<String>(
                  value: session.id,
                  child: Row(
                    children: [
                      Icon(
                        isAllSessions
                            ? Icons.all_inclusive_rounded
                            : Icons.calendar_month_rounded,
                        size: 18,
                        color: isDisabled
                            ? Colors.grey
                            : const Color(0xFF6366F1),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          session.name,
                          style: TextStyle(color: _titleColor),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
              onChanged: isDisabled
                  ? null
                  : (value) {
                      setState(() {
                        _selectedSessionId = value;
                      });
                    },
              hint: Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Text(
                  isDisabled ? 'No sessions available' : 'Select Session',
                  style: TextStyle(
                    color: isDisabled ? Colors.grey : _bodyColor,
                  ),
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
              style: TextStyle(
                fontSize: 14,
                color: isDisabled ? Colors.grey : _titleColor,
              ),
              items: _courses.map((course) {
                final isSelected = _selectedCourseId == course.id;
                final isDownloaded = course.isDownloaded;

                return DropdownMenuItem<String>(
                  value: course.id,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        // Course icon with color
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
                        // Course info
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
                                      color: isDisabled
                                          ? Colors.grey
                                          : _titleColor,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  if (isDownloaded)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.green.shade100,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.download_rounded,
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
                                  color: isDisabled ? Colors.grey : _bodyColor,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        // Selection indicator
                        if (isSelected)
                          Icon(
                            Icons.check_circle_rounded,
                            size: 20,
                            color: isDisabled
                                ? Colors.grey
                                : const Color(0xFF6366F1),
                          ),
                      ],
                    ),
                  ),
                );
              }).toList(),
              onChanged: isDisabled
                  ? null
                  : (value) {
                      setState(() {
                        _selectedCourseId = value;
                        // Reset topics when course changes
                        _topics.clear();
                        _selectedTopicId = null;
                        _topicError = null;
                      });
                      // Load topics for the selected course
                      if (value != null) {
                        _loadTopicsFromOfflineCourse(value);
                      }
                    },
              hint: Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Text(
                  isDisabled ? 'No courses available' : 'Select a course',
                  style: TextStyle(
                    color: isDisabled ? Colors.grey : _bodyColor,
                  ),
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
    final hasTopics = _topics.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(left: 4, bottom: 6),
          child: Text(
            'Topic (Optional)',
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
              style: TextStyle(
                fontSize: 14,
                color: isDisabled ? Colors.grey : _titleColor,
              ),
              items: [
                // "All Topics" option
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
                          'All Topics (General Questions)',
                          style: TextStyle(fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                ),
                // Actual topics
                ..._topics.map((topic) {
                  return DropdownMenuItem<String>(
                    value: topic['id']?.toString() ?? '',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          topic['title'] ?? 'Unknown',
                          style: TextStyle(fontSize: 14, color: _titleColor),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (topic['outlineTitle'] != null &&
                            topic['outlineTitle'] != 'No Outline')
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              'Outline: ${topic['outlineTitle']}',
                              style: TextStyle(fontSize: 11, color: _bodyColor),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                    ),
                  );
                }).toList(),
              ],
              onChanged: isDisabled || !hasTopics
                  ? null
                  : (value) {
                      setState(() {
                        _selectedTopicId = value;
                      });
                    },
              hint: _loadingTopics
                  ? const Padding(
                      padding: EdgeInsets.only(left: 4),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          SizedBox(width: 8),
                          Text('Loading topics...'),
                        ],
                      ),
                    )
                  : (_topicError != null && !hasTopics)
                  ? Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: Text(
                        _topicError!,
                        style: const TextStyle(color: Colors.orange),
                      ),
                    )
                  : Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: Text(
                        hasTopics
                            ? 'Select a topic (optional)'
                            : 'No topics available',
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
            color: Colors.black.withValues(alpha: _isDark ? 0.18 : 0.05),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _pageBackground,
      appBar: AppBar(
        title: const Text(
          'CBT Practice',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: _surfaceColor,
        foregroundColor: _titleColor,
        elevation: 1,
      ),
      body: _isLoading && _courses.isEmpty
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF6366F1)),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Text(
                    'Computer-Based Test',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: _titleColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Practice with downloaded courses in exam-like conditions',
                    style: TextStyle(fontSize: 14, color: _bodyColor),
                  ),
                  const SizedBox(height: 24),

                  // Offline notice
                  if (_isOffline)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(
                          alpha: _isDark ? 0.16 : 0.08,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.orange.withValues(
                            alpha: _isDark ? 0.35 : 0.3,
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.wifi_off_rounded,
                            color: Colors.orange.shade700,
                            size: 22,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Offline Mode',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: Colors.orange.shade700,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _hasOfflineCourses
                                      ? 'Using ${_courses.length} downloaded course${_courses.length == 1 ? '' : 's'}'
                                      : 'No downloaded courses found. Download courses when online to use CBT.',
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
                        // Section Header
                        Row(
                          children: [
                            Icon(
                              Icons.settings_rounded,
                              color: Color(0xFF6366F1),
                              size: 20,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Test Configuration',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: _titleColor,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),

                        // Random Mode Toggle
                        // _buildOptionCard(
                        //   icon: Icons.shuffle_rounded,
                        //   title: 'Random Questions',
                        //   subtitle: 'Get random questions from all sessions',
                        //   value: _randomMode,
                        //   onChanged: (value) {
                        //     setState(() {
                        //       _randomMode = value;
                        //       if (value) {
                        //         _selectedSessionId = null;
                        //         _selectedTopicId = null;
                        //       }
                        //     });
                        //   },
                        //   activeColor: const Color(0xFF6366F1),
                        // ),
                        _buildOptionCard(
                          icon: Icons.shuffle_rounded,
                          title: 'Random Questions',
                          subtitle: 'Get random questions from all sessions',
                          value: _randomMode,
                          onChanged: (value) {
                            setState(() {
                              _randomMode = value;
                              if (value) {
                                // When turning ON random mode, clear selections
                                _selectedSessionId = null;
                                _selectedTopicId = null;
                              } else {
                                // When turning OFF random mode, set session to a default value
                                if (_sessions.isNotEmpty) {
                                  _selectedSessionId = _sessions
                                      .first
                                      .id; // or any default you prefer
                                }
                              }
                            });
                          },
                          activeColor: const Color(0xFF6366F1),
                        ),
                        const SizedBox(height: 12),

                        // Session Dropdown (only show if not random mode)
                        if (!_randomMode) ...[
                          _buildSessionDropdown(),
                          const SizedBox(height: 16),
                        ],

                        // Course Dropdown
                        _buildCourseDropdown(),
                        const SizedBox(height: 16),

                        // Topic Dropdown (only show if not random mode)
                        if (!_randomMode) ...[
                          _buildTopicDropdown(),
                          const SizedBox(height: 16),
                        ],

                        // Timer Toggle
                        _buildOptionCard(
                          icon: Icons.timer_rounded,
                          title: 'Enable Timer',
                          subtitle: 'Set time limit for the exam (optional)',
                          value: _enableTimer,
                          onChanged: (value) =>
                              setState(() => _enableTimer = value),
                          activeColor: const Color(0xFFF59E0B),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Start Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed:
                          (_isLoading ||
                              !_hasOfflineCourses ||
                              _selectedCourseId == null)
                          ? null
                          : _startCBT,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6366F1),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                        shadowColor: Colors.transparent,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.play_arrow_rounded, size: 20),
                          const SizedBox(width: 8),
                          const Text(
                            'Start CBT Practice',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Info Section
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue.shade100),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.info_rounded,
                          size: 20,
                          color: Colors.blue.shade700,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'About CBT Practice',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.blue.shade800,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Computer-Based Test mode simulates real exam conditions with timed practice using your downloaded courses. '
                                'You can track your progress, review answers, and improve your exam-taking skills.',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.blue.shade800,
                                  height: 1.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Spacing at the bottom
                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }
}
