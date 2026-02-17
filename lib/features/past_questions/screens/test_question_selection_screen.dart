// lib/features/test_questions/screens/test_questions_selection_screen.dart
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
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
  final Connectivity _connectivity = Connectivity();

  String? _selectedSessionId;
  String? _selectedCourseId;
  String? _selectedTopicId;
  bool _randomMode = false;
  bool _isLoading = false;
  bool _isOffline = false;
  bool _hasOfflineCourses = false;

  List<TestQuestionSession> _sessions = [];
  List<Course> _courses = [];
  List<Map<String, dynamic>> _topics = [];
  List<Map<String, dynamic>> _offlineTopics = [];

  // Loading states for dropdowns
  bool _loadingTopics = false;
  String? _topicError;

  // Hive boxes
  static const String offlineCoursesBox = 'offline_courses';

  @override
  void initState() {
    super.initState();
    _checkConnectivityAndLoadData();

    // Add debug logging after 2 seconds
    Future.delayed(Duration(seconds: 2), () {
      _debugOfflineData();
    });
  }

  Future<void> _checkConnectivityAndLoadData() async {
    final connectivityResult = await _connectivity.checkConnectivity();
    final isOnline = connectivityResult != ConnectivityResult.none;

    setState(() {
      _isOffline = !isOnline;
    });

    if (isOnline) {
      await _loadInitialData();
    } else {
      await _loadOfflineData();
    }
  }

  // Replace the existing _loadInitialData method with this updated version
  Future<void> _loadInitialData() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      _isOffline = false;
      _hasOfflineCourses = false;
    });

    try {
      // Check connectivity
      final connectivityResult = await Connectivity().checkConnectivity();
      final isOnline = connectivityResult != ConnectivityResult.none;

      if (isOnline) {
        // Online mode - try to load from API
        print('🌐 Online mode - loading from API');

        try {
          // Load all academic sessions first
          final allSessions = await _apiService.getTestQuestionSessions();
          print('✅ Loaded ${allSessions.length} sessions from API');

          // Load courses for the current user
          final userCourses = await _apiService.getCoursesForUser();
          print('✅ Loaded ${userCourses.length} courses from API');

          setState(() {
            _sessions = allSessions;
            _courses = userCourses;
            _isOffline = false;
          });

          // Pre-select the first session if available
          if (_sessions.isNotEmpty) {
            _selectedSessionId = _sessions.first.id;
          }

          // Pre-select the first course if available
          if (_courses.isNotEmpty) {
            _selectedCourseId = _courses.first.id;
            // Load topics for the first course
            await _loadTopicsForCourse(_courses.first.id);
          }

          // Check for offline courses as well
          await _checkOfflineCourses();
        } catch (apiError) {
          print('⚠️ API error, switching to offline mode: $apiError');
          // Fall back to offline mode
          await _loadOfflineData();
        }
      } else {
        // Offline mode - load from storage
        print('📴 Offline mode - loading from storage');
        await _loadOfflineData();
      }
    } catch (e) {
      print('❌ Error in _loadInitialData: $e');

      // Try offline as last resort
      try {
        await _loadOfflineData();
      } catch (offlineError) {
        print('❌ Offline load also failed: $offlineError');

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                _isOffline && !_hasOfflineCourses
                    ? 'No downloaded courses found. Please download courses when online.'
                    : 'Failed to load data: ${e.toString().split(':').first}',
              ),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 3),
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

  // Update the _loadOfflineData method
  Future<void> _loadOfflineData() async {
    setState(() {
      _isLoading = true;
      _isOffline = true;
      _hasOfflineCourses = false;
    });

    try {
      print('📴 Loading offline data...');

      // Load offline courses
      await _loadOfflineCourses();

      // Load offline sessions from downloaded courses
      await _loadOfflineSessions();

      // DEBUG: Check what's in offline content
      await _debugOfflineContent();

      // Set hasOfflineCourses flag
      setState(() {
        _hasOfflineCourses = _courses.isNotEmpty;
      });

      // Pre-select the first course if available
      if (_courses.isNotEmpty) {
        _selectedCourseId = _courses.first.id;
        print('📌 Pre-selected course: $_selectedCourseId');

        // Load topics for the first course
        await _loadTopicsFromOfflineCourse(_selectedCourseId!);
      } else {
        print('⚠️ No offline courses found');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'No downloaded courses found. Please download courses when online.',
              ),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      print('❌ Error loading offline data: $e');

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

      print('📂 Found ${downloadedCourseIds.length} downloaded courses');

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
          print('⚠️ Error loading offline course $courseId: $e');
        }
      }

      setState(() {
        _courses = offlineCourses;

        // Pre-select the first course if available
        if (_courses.isNotEmpty && _selectedCourseId == null) {
          _selectedCourseId = _courses.first.id;
        }
      });

      print('✅ Loaded ${offlineCourses.length} offline courses');
    } catch (e) {
      print('❌ Error loading offline courses: $e');
      setState(() {
        _courses = [];
      });
    }
  }

  Future<void> _loadOfflineSessions() async {
    try {
      print('📅 Loading offline sessions from downloaded courses...');

      final offlineBox = await Hive.openBox(offlineCoursesBox);
      final downloadedCourseIds = offlineBox.get(
        'downloaded_course_ids',
        defaultValue: <String>[],
      );

      print('📦 Found ${downloadedCourseIds.length} downloaded courses');

      // First, try to load from a dedicated sessions cache
      final cachedSessions = offlineBox.get('offline_sessions_cache');
      if (cachedSessions != null && cachedSessions is List) {
        print('📂 Loading sessions from cache');
        final sessions = cachedSessions.map((sessionJson) {
          return TestQuestionSession.fromJson(
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

      // If no cache, extract sessions from test questions
      final sessionSet = <String, TestQuestionSession>{};

      for (var courseId in downloadedCourseIds) {
        try {
          final courseData = offlineBox.get('course_$courseId');
          if (courseData == null) continue;

          // Check for test questions
          if (courseData['test_questions'] != null) {
            final testQuestions = courseData['test_questions'] as List;
            print(
              '📝 Found ${testQuestions.length} test questions in course $courseId',
            );

            for (var pq in testQuestions) {
              if (pq is Map && pq['session'] != null) {
                final sessionData = pq['session'];
                if (sessionData is Map) {
                  final sessionId = sessionData['id']?.toString();
                  final sessionName = sessionData['name']?.toString();

                  if (sessionId != null &&
                      sessionName != null &&
                      !sessionSet.containsKey(sessionId)) {
                    sessionSet[sessionId] = TestQuestionSession(
                      id: sessionId,
                      name: sessionName,
                      isActive: true,
                    );

                    print('📅 Found session: $sessionName ($sessionId)');
                  }
                }
              }
            }
          }

          // Also check for test questions
          if (courseData['test_questions'] != null) {
            final testQuestions = courseData['test_questions'] as List;
            print(
              '📝 Found ${testQuestions.length} test questions in course $courseId',
            );

            for (var tq in testQuestions) {
              if (tq is Map && tq['session'] != null) {
                final sessionData = tq['session'];
                if (sessionData is Map) {
                  final sessionId = sessionData['id']?.toString();
                  final sessionName = sessionData['name']?.toString();

                  if (sessionId != null &&
                      sessionName != null &&
                      !sessionSet.containsKey(sessionId)) {
                    sessionSet[sessionId] = TestQuestionSession(
                      id: sessionId,
                      name: sessionName,
                      isActive: true,
                    );

                    print(
                      '📅 Found session in test questions: $sessionName ($sessionId)',
                    );
                  }
                }
              }
            }
          }
        } catch (e) {
          print('⚠️ Error extracting sessions from course $courseId: $e');
        }
      }

      // Create session list
      final sessionList = sessionSet.values.toList();

      // Add "All Sessions" option
      sessionList.insert(
        0,
        TestQuestionSession(id: '', name: 'All Sessions', isActive: true),
      );

      print(
        '✅ Extracted ${sessionList.length} sessions from downloaded courses',
      );

      // Cache the sessions for future use
      final sessionCache = sessionList
          .map((session) => session.toJson())
          .toList();
      await offlineBox.put('offline_sessions_cache', sessionCache);

      setState(() {
        _sessions = sessionList;
        if (_sessions.isNotEmpty && _selectedSessionId == null) {
          _selectedSessionId = _sessions.first.id;
        }
      });
    } catch (e) {
      print('❌ Error loading offline sessions: $e');

      // Fallback: create default "All Sessions" option
      setState(() {
        _sessions = [
          TestQuestionSession(id: '', name: 'All Sessions', isActive: true),
        ];
        _selectedSessionId = '';
      });
    }
  }

  Future<void> _checkOfflineCourses() async {
    try {
      final offlineBox = await Hive.openBox(offlineCoursesBox);
      final downloadedCourseIds = offlineBox.get(
        'downloaded_course_ids',
        defaultValue: <String>[],
      );

      setState(() {
        _hasOfflineCourses = downloadedCourseIds.isNotEmpty;
      });
    } catch (e) {
      print('⚠️ Error checking offline courses: $e');
    }
  }

  Future<void> _loadTopicsForCourse(String courseId) async {
    if (courseId.isEmpty) return;

    setState(() {
      _loadingTopics = true;
      _topics.clear();
      _offlineTopics.clear();
      _selectedTopicId = null;
      _topicError = null;
    });

    try {
      if (_isOffline) {
        await _loadTopicsFromOfflineCourse(courseId);
      } else {
        print('📋 Loading topics for course ID: $courseId');

        // Load from API
        _topics = await _apiService.getTopicsForTestQuestions(
          courseId: int.parse(courseId),
        );

        print('📚 Total topics loaded: ${_topics.length}');

        setState(() {
          if (_topics.isEmpty) {
            _topicError = 'No topics available for this course';
          }
        });
      }
    } catch (e) {
      print('❌ Error loading topics: $e');

      // Try loading from offline storage as fallback
      if (!_isOffline) {
        try {
          await _loadTopicsFromOfflineCourse(courseId);
        } catch (offlineError) {
          print('❌ Error loading offline topics: $offlineError');
          setState(() {
            _topicError =
                'Failed to load topics: ${e.toString().split(':').first}';
          });
        }
      } else {
        setState(() {
          _topicError =
              'Failed to load topics: ${e.toString().split(':').first}';
        });
      }

      if (mounted && !_isOffline) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to load topics: ${e.toString().split(':').last.trim()}',
            ),
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

  Future<void> _loadTopicsFromOfflineCourse(String courseId) async {
    try {
      print('📋 Loading offline topics and sessions for course: $courseId');

      final offlineBox = await Hive.openBox(offlineCoursesBox);
      final courseData = offlineBox.get('course_$courseId');

      if (courseData == null) {
        throw Exception('No offline data found for this course');
      }

      final topicsList = <Map<String, dynamic>>[];
      final sessionsSet = <String, TestQuestionSession>{};

      // 1. First, extract topics from course topics
      if (courseData['topics'] != null) {
        final courseTopics = courseData['topics'] as List;
        print('📚 Found ${courseTopics.length} course topics');

        for (var topic in courseTopics) {
          if (topic is Map) {
            final topicId = topic['id']?.toString();
            final topicTitle = topic['title']?.toString();
            final outline = topic['outline_info'] ?? topic['outline'];

            if (topicId != null && topicTitle != null) {
              if (!topicsList.any((t) => t['id'] == topicId)) {
                topicsList.add({
                  'id': topicId,
                  'title': topicTitle,
                  'outlineTitle': outline is Map
                      ? outline['title']?.toString()
                      : 'No Outline',
                });
                print('   - Added course topic: $topicTitle (ID: $topicId)');
              }
            }
          }
        }
      }

      // 2. Extract sessions from ALL downloaded courses (not just this one)
      final downloadedCourseIds = offlineBox.get(
        'downloaded_course_ids',
        defaultValue: <String>[],
      );

      print('🔍 Looking for sessions across all downloaded courses...');

      // Check for a dedicated sessions cache first
      final cachedSessions = offlineBox.get('offline_sessions_cache');
      if (cachedSessions != null && cachedSessions is List) {
        print('📂 Loading sessions from cache');
        for (var sessionJson in cachedSessions) {
          try {
            final session = TestQuestionSession.fromJson(
              Map<String, dynamic>.from(sessionJson),
            );
            sessionsSet[session.id] = session;
          } catch (e) {
            print('⚠️ Error parsing cached session: $e');
          }
        }
      } else {
        // Extract sessions from all downloaded courses
        for (var downloadedCourseId in downloadedCourseIds) {
          try {
            final downloadedCourseData = offlineBox.get(
              'course_$downloadedCourseId',
            );
            if (downloadedCourseData == null) continue;

            // Check test questions
            if (downloadedCourseData['test_questions'] != null) {
              final testQuestions =
                  downloadedCourseData['test_questions'] as List;
              for (var pq in testQuestions) {
                if (pq is Map) {
                  // Try multiple session field names
                  final sessionData =
                      pq['session'] ??
                      pq['session_info'] ??
                      pq['academic_session'];

                  if (sessionData != null) {
                    String? sessionId;
                    String? sessionName;

                    if (sessionData is Map) {
                      sessionId =
                          sessionData['id']?.toString() ??
                          sessionData['session_id']?.toString();
                      sessionName =
                          sessionData['name']?.toString() ??
                          sessionData['session_name']?.toString() ??
                          sessionData['academic_session']?.toString();
                    } else if (sessionData is String) {
                      sessionName = sessionData;
                      sessionId = sessionData.hashCode.toString();
                    }

                    if (sessionName != null && sessionName.isNotEmpty) {
                      if (sessionId == null || sessionId.isEmpty) {
                        sessionId = sessionName.hashCode.toString();
                      }

                      if (!sessionsSet.containsKey(sessionId)) {
                        sessionsSet[sessionId] = TestQuestionSession(
                          id: sessionId,
                          name: sessionName,
                          isActive: true,
                        );
                        print('📅 Found session: $sessionName ($sessionId)');
                      }
                    }
                  }
                }
              }
            }

            // Check test questions
            if (downloadedCourseData['test_questions'] != null) {
              final testQuestions =
                  downloadedCourseData['test_questions'] as List;
              for (var tq in testQuestions) {
                if (tq is Map) {
                  final sessionData =
                      tq['session'] ??
                      tq['session_info'] ??
                      tq['academic_session'];

                  if (sessionData != null) {
                    String? sessionId;
                    String? sessionName;

                    if (sessionData is Map) {
                      sessionId =
                          sessionData['id']?.toString() ??
                          sessionData['session_id']?.toString();
                      sessionName =
                          sessionData['name']?.toString() ??
                          sessionData['session_name']?.toString() ??
                          sessionData['academic_session']?.toString();
                    } else if (sessionData is String) {
                      sessionName = sessionData;
                      sessionId = sessionData.hashCode.toString();
                    }

                    if (sessionName != null && sessionName.isNotEmpty) {
                      if (sessionId == null || sessionId.isEmpty) {
                        sessionId = sessionName.hashCode.toString();
                      }

                      if (!sessionsSet.containsKey(sessionId)) {
                        sessionsSet[sessionId] = TestQuestionSession(
                          id: sessionId,
                          name: sessionName,
                          isActive: true,
                        );
                        print(
                          '📅 Found session in test questions: $sessionName ($sessionId)',
                        );
                      }
                    }
                  }
                }
              }
            }
          } catch (e) {
            print('⚠️ Error processing course $downloadedCourseId: $e');
          }
        }

        // Cache the sessions for future use
        if (sessionsSet.isNotEmpty) {
          final sessionCache = sessionsSet.values
              .map((session) => session.toJson())
              .toList();
          await offlineBox.put('offline_sessions_cache', sessionCache);
          print('💾 Cached ${sessionCache.length} sessions');
        }
      }

      // 3. Extract topics from test questions in this specific course
      if (courseData['test_questions'] != null) {
        final testQuestions = courseData['test_questions'] as List;
        print('📝 Found ${testQuestions.length} test questions in this course');

        for (var pq in testQuestions) {
          if (pq is Map) {
            // Extract topic information
            if (pq['topic'] != null) {
              final topic = pq['topic'];
              if (topic is Map) {
                final topicId = topic['id']?.toString();
                final topicTitle = topic['title']?.toString();
                final outline = topic['outline_info'] ?? topic['outline'];

                if (topicId != null && topicTitle != null) {
                  if (!topicsList.any((t) => t['id'] == topicId)) {
                    topicsList.add({
                      'id': topicId,
                      'title': topicTitle,
                      'outlineTitle': outline is Map
                          ? outline['title']?.toString()
                          : 'No Outline',
                    });
                    print('   - Added topic from test question: $topicTitle');
                  }
                }
              }
            }
          }
        }
      }

      // 4. Extract topics from test questions in this specific course
      if (courseData['test_questions'] != null) {
        final testQuestions = courseData['test_questions'] as List;
        print('📝 Found ${testQuestions.length} test questions in this course');

        for (var tq in testQuestions) {
          if (tq is Map) {
            // Extract topic information
            if (tq['topic'] != null) {
              final topic = tq['topic'];
              if (topic is Map) {
                final topicId = topic['id']?.toString();
                final topicTitle = topic['title']?.toString();
                final outline = topic['outline_info'] ?? topic['outline'];

                if (topicId != null && topicTitle != null) {
                  if (!topicsList.any((t) => t['id'] == topicId)) {
                    topicsList.add({
                      'id': topicId,
                      'title': topicTitle,
                      'outlineTitle': outline is Map
                          ? outline['title']?.toString()
                          : 'No Outline',
                    });
                    print('   - Added topic from test question: $topicTitle');
                  }
                }
              }
            }
          }
        }
      }

      print('📚 Extracted ${topicsList.length} unique topics');
      print('📅 Extracted ${sessionsSet.length} sessions');

      // Create final session list
      final sessionList = sessionsSet.values.toList();

      // Add "All Sessions" option at the beginning
      sessionList.insert(
        0,
        TestQuestionSession(id: '', name: 'All Sessions', isActive: true),
      );

      setState(() {
        _sessions = sessionList;
        _offlineTopics = topicsList;

        // Set default selections
        if (_selectedSessionId == null || _selectedSessionId!.isEmpty) {
          _selectedSessionId = ''; // "All Sessions"
        }

        if (topicsList.isEmpty) {
          _topicError = 'No topics found in offline data';
          print('⚠️ No topics extracted from offline data');
        } else {
          _topicError = null;
          print('✅ Loaded ${topicsList.length} offline topics');
        }
      });

      print(
        '✅ Updated with ${_sessions.length} sessions (including "All Sessions")',
      );
    } catch (e) {
      print('❌ Error loading offline topics: $e');
      setState(() {
        _topicError = 'Error loading topics from offline data: ${e.toString()}';
        _offlineTopics = [];
        // Fallback sessions
        _sessions = [
          TestQuestionSession(id: '', name: 'All Sessions', isActive: true),
        ];
        _selectedSessionId = '';
      });
    }
  }

  Future<void> _debugCourseStructure(String courseId) async {
    try {
      print('🔍 === DEBUG COURSE STRUCTURE ===');
      final offlineBox = await Hive.openBox(offlineCoursesBox);
      final courseData = offlineBox.get('course_$courseId');

      if (courseData == null) {
        print('❌ No course data found');
        return;
      }

      print('📦 Course data keys: ${courseData.keys.toList()}');

      // Check test questions structure
      if (courseData['test_questions'] != null) {
        final testQuestions = courseData['test_questions'] as List;
        print('📝 Test questions count: ${testQuestions.length}');

        if (testQuestions.isNotEmpty) {
          final firstPq = testQuestions[0];
          print('🔍 First test question keys: ${firstPq.keys.toList()}');
          print('🔍 First test question session: ${firstPq['session']}');
          print(
            '🔍 First test question session type: ${firstPq['session']?.runtimeType}',
          );

          if (firstPq['session'] != null && firstPq['session'] is Map) {
            final sessionMap = firstPq['session'] as Map;
            print('🔍 Session map keys: ${sessionMap.keys.toList()}');
            for (var key in sessionMap.keys) {
              print(
                '   - $key: ${sessionMap[key]} (type: ${sessionMap[key]?.runtimeType})',
              );
            }
          }
        }
      }

      // Check test questions structure
      if (courseData['test_questions'] != null) {
        final testQuestions = courseData['test_questions'] as List;
        print('📝 Test questions count: ${testQuestions.length}');

        if (testQuestions.isNotEmpty) {
          final firstTq = testQuestions[0];
          print('🔍 First test question keys: ${firstTq.keys.toList()}');
          print('🔍 First test question session: ${firstTq['session']}');
        }
      }

      print('🔍 === END DEBUG ===');
    } catch (e) {
      print('❌ Debug error: $e');
    }
  }

  Future<void> _debugOfflineContent() async {
    print('🔍 === DEBUG OFFLINE CONTENT ===');
    try {
      final offlineBox = await Hive.openBox(offlineCoursesBox);
      final downloadedCourseIds = offlineBox.get(
        'downloaded_course_ids',
        defaultValue: <String>[],
      );

      print('📦 Found ${downloadedCourseIds.length} downloaded courses');

      for (var courseId in downloadedCourseIds) {
        final courseData = offlineBox.get('course_$courseId');
        if (courseData != null) {
          print('\n📖 Course: $courseId');

          // Check course info
          if (courseData['course'] != null) {
            final course = Map<String, dynamic>.from(courseData['course']);
            print('   📚 Code: ${course['code']}');
            print('   📚 Title: ${course['title']}');
          }

          // Check test questions
          if (courseData['test_questions'] != null) {
            final testQuestions = courseData['test_questions'] as List;
            print('   📝 Test Questions: ${testQuestions.length}');

            // Check sessions in test questions
            final sessionsInTestQuestions = <String>{};
            for (var pq in testQuestions) {
              if (pq is Map && pq['session'] != null) {
                final session = pq['session'];
                if (session is Map) {
                  final sessionId = session['id']?.toString();
                  final sessionName = session['name']?.toString();
                  if (sessionName != null) {
                    sessionsInTestQuestions.add('$sessionName ($sessionId)');
                  }
                }
              }
            }
            print('   📅 Sessions in test questions: $sessionsInTestQuestions');
          }

          // Check test questions
          if (courseData['test_questions'] != null) {
            final testQuestions = courseData['test_questions'] as List;
            print('   📝 Test Questions: ${testQuestions.length}');

            // Check sessions in test questions
            final sessionsInTestQuestions = <String>{};
            for (var tq in testQuestions) {
              if (tq is Map && tq['session'] != null) {
                final session = tq['session'];
                if (session is Map) {
                  final sessionId = session['id']?.toString();
                  final sessionName = session['name']?.toString();
                  if (sessionName != null) {
                    sessionsInTestQuestions.add('$sessionName ($sessionId)');
                  }
                }
              }
            }
            print('   📅 Sessions in test questions: $sessionsInTestQuestions');
          }
        }
      }
    } catch (e) {
      print('❌ Debug error: $e');
    }
    print('🔍 === END DEBUG ===');
  }

  // Add this debug method to your class
  Future<void> _debugOfflineData() async {
    print('🔍 === DEBUG OFFLINE DATA ===');
    try {
      final offlineBox = await Hive.openBox(offlineCoursesBox);
      final downloadedCourseIds = offlineBox.get(
        'downloaded_course_ids',
        defaultValue: <String>[],
      );

      print('📦 Downloaded course IDs: $downloadedCourseIds');
      print('📦 Number of downloaded courses: ${downloadedCourseIds.length}');

      for (var courseId in downloadedCourseIds) {
        final courseData = offlineBox.get('course_$courseId');
        if (courseData != null) {
          print('\n📖 Course: $courseId');

          if (courseData['course'] != null) {
            final course = Map<String, dynamic>.from(courseData['course']);
            print('   Code: ${course['code']}');
            print('   Title: ${course['title']}');
          }

          if (courseData['test_questions'] != null) {
            final testQuestions = courseData['test_questions'] as List;
            print('   Test Questions: ${testQuestions.length}');

            // Check sessions in test questions
            final sessions = <String>{};
            for (var pq in testQuestions) {
              if (pq is Map && pq['session'] != null) {
                final session = pq['session'];
                if (session is Map) {
                  final sessionName = session['name']?.toString();
                  if (sessionName != null) {
                    sessions.add(sessionName);
                  }
                }
              }
            }
            print('   Sessions in test questions: $sessions');
          }

          if (courseData['topics'] != null) {
            final topics = courseData['topics'] as List;
            print('   Topics: ${topics.length}');
          }
        }
      }
    } catch (e) {
      print('❌ Debug error: $e');
    }
    print('🔍 === END DEBUG ===');
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

      // Handle session name - FIXED for "All Sessions"
      String sessionName = 'All Sessions';
      String? sessionIdToSend = null;

      if (_selectedSessionId != null && _selectedSessionId!.isNotEmpty) {
        // Check if it's not the "All Sessions" option (empty string)
        if (_selectedSessionId != '') {
          final session = _sessions.firstWhere(
            (session) => session.id == _selectedSessionId,
            orElse: () => TestQuestionSession(
              id: '',
              name: 'All Sessions',
              isActive: false,
            ),
          );
          sessionName = session.name;
          sessionIdToSend = _selectedSessionId;
        }
      }

      // Find selected topic
      String? topicName;
      String? topicIdToSend;

      if (_selectedTopicId != null && _selectedTopicId!.isNotEmpty) {
        // Check if we have topics loaded
        final topicList = _isOffline ? _offlineTopics : _topics;
        if (topicList.isNotEmpty) {
          final topic = topicList.firstWhere(
            (topic) => topic['id']?.toString() == _selectedTopicId,
            orElse: () => {'title': 'Unknown', 'id': null},
          );
          topicName = topic['title'] ?? 'Unknown';
          topicIdToSend = topic['id']?.toString();
        } else {
          topicIdToSend = _selectedTopicId;
          topicName = 'Selected Topic';
        }

        print('📌 Selected topic: $topicName (ID: $topicIdToSend)');
      } else {
        print(
          '📌 No specific topic selected - will show all questions for course',
        );
        topicName = null;
        topicIdToSend = null;
      }

      print('📌 Session to send: $sessionIdToSend ($sessionName)');

      // Navigate to test questions screen
      Navigator.pushNamed(
        context,
        '/test-questions-screen',
        arguments: {
          'courseId': _selectedCourseId!,
          'courseName': '${selectedCourse.code} - ${selectedCourse.title}',
          'sessionId': sessionIdToSend, // Send null for "All Sessions"
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

          // Offline status indicator
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
                  const Icon(
                    Icons.wifi_off_rounded,
                    color: Colors.orange,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'You are offline',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _hasOfflineCourses
                              ? 'Showing downloaded courses'
                              : 'No downloaded courses found',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                          ),
                        ),
                      ],
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
                const Icon(
                  Icons.shuffle_rounded,
                  color: Colors.white,
                  size: 18,
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Random Questions',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                    ),
                  ),
                ),
                Switch(
                  value: _randomMode,
                  activeColor: const Color(0xFF6366F1),
                  activeTrackColor: Colors.white,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  onChanged: (_isLoading || (_isOffline && !_hasOfflineCourses))
                      ? null
                      : (value) {
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
              onPressed:
                  (_isLoading ||
                      _loadingTopics ||
                      _selectedCourseId == null ||
                      (_isOffline && !_hasOfflineCourses))
                  ? null
                  : _loadQuestions,
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
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _isOffline
                              ? 'Load Offline Questions'
                              : 'Load Questions',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Icon(Icons.arrow_forward_rounded, size: 18),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSessionDropdown() {
    final isDisabled = _isLoading || (_isOffline && _sessions.isEmpty);
    final currentTopics = _isOffline ? _offlineTopics : _topics;

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
              value: _selectedSessionId ?? '', // Handle null value
              isExpanded: true,
              underline: const SizedBox(),
              icon: const Icon(
                Icons.arrow_drop_down_rounded,
                color: Color(0xFF6366F1),
                size: 20,
              ),
              style: TextStyle(
                color: isDisabled ? Colors.grey : const Color(0xFF1A1A2E),
                fontSize: 13,
              ),
              items: [
                // Add "All Sessions" option - using empty string as value
                DropdownMenuItem<String>(
                  value: '',
                  child: Row(
                    children: [
                      Icon(
                        Icons.all_inclusive_rounded,
                        size: 16,
                        color: isDisabled
                            ? Colors.grey
                            : const Color(0xFF6366F1),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'All Sessions',
                        style: TextStyle(
                          fontSize: 13,
                          color: isDisabled ? Colors.grey : null,
                        ),
                      ),
                    ],
                  ),
                ),
                // Add actual sessions
                ..._sessions.where((session) => session.id.isNotEmpty).map((
                  session,
                ) {
                  return DropdownMenuItem<String>(
                    value: session.id,
                    child: Row(
                      children: [
                        Icon(
                          Icons.calendar_month_rounded,
                          size: 16,
                          color: isDisabled
                              ? Colors.grey
                              : const Color(0xFF6366F1),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          session.name,
                          style: TextStyle(
                            fontSize: 13,
                            color: isDisabled ? Colors.grey : null,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ],
              onChanged: isDisabled
                  ? null
                  : (value) {
                      print('Selected session: $value');
                      setState(() {
                        _selectedSessionId = value;
                      });
                    },
              hint: Text(
                isDisabled
                    ? (_isOffline ? 'No offline sessions' : 'Select Session')
                    : 'Select Session',
                style: TextStyle(
                  color: isDisabled ? Colors.grey : const Color(0xFF666666),
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCourseDropdown() {
    final isDisabled = _isLoading || (_isOffline && _courses.isEmpty);

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
                  : Icon(
                      Icons.arrow_drop_down_rounded,
                      color: isDisabled ? Colors.grey : const Color(0xFF6366F1),
                      size: 20,
                    ),
              style: TextStyle(
                color: isDisabled ? Colors.grey : const Color(0xFF1A1A2E),
                fontSize: 13,
              ),
              items: _courses.map((course) {
                final isDownloaded = course.isDownloaded;
                return DropdownMenuItem<String>(
                  value: course.id,
                  child: Row(
                    children: [
                      Icon(
                        Icons.menu_book_rounded,
                        size: 16,
                        color: isDisabled
                            ? Colors.grey
                            : const Color(0xFF6366F1),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${course.code} - ${course.title}',
                          style: TextStyle(
                            fontSize: 13,
                            color: isDisabled ? Colors.grey : null,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isDownloaded && _isOffline)
                        Container(
                          margin: const EdgeInsets.only(left: 8),
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: Colors.green,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Icon(
                            Icons.download_done_rounded,
                            size: 12,
                            color: Colors.white,
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
                        _selectedCourseId = value;
                        // Reset topics when course changes
                        _topics.clear();
                        _offlineTopics.clear();
                        _selectedTopicId = null;
                        _topicError = null;
                      });
                      // Load topics for the selected course
                      if (value != null) {
                        _loadTopicsForCourse(value);
                      }
                    },
              hint: Text(
                isDisabled
                    ? (_isOffline ? 'No offline courses' : 'Select Course')
                    : 'Select Course',
                style: TextStyle(
                  color: isDisabled ? Colors.grey : const Color(0xFF666666),
                  fontSize: 13,
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
    final currentTopics = _isOffline ? _offlineTopics : _topics;
    final hasTopics = currentTopics.isNotEmpty;

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
                  : Icon(
                      Icons.arrow_drop_down_rounded,
                      color: isDisabled ? Colors.grey : const Color(0xFF6366F1),
                      size: 20,
                    ),
              style: TextStyle(
                color: isDisabled ? Colors.grey : const Color(0xFF1A1A2E),
                fontSize: 13,
              ),
              items: [
                // "All Topics" option
                DropdownMenuItem<String>(
                  value: null,
                  child: Row(
                    children: [
                      Icon(
                        Icons.all_inclusive_rounded,
                        size: 16,
                        color: isDisabled
                            ? Colors.grey
                            : const Color(0xFF6366F1),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'All Topics (General Questions)',
                        style: TextStyle(
                          fontSize: 13,
                          color: isDisabled ? Colors.grey : null,
                        ),
                      ),
                    ],
                  ),
                ),
                // Add actual topics
                ...currentTopics.map((topic) {
                  return DropdownMenuItem<String>(
                    value: topic['id']?.toString() ?? '',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          topic['title'] ?? 'Unknown',
                          style: TextStyle(
                            fontSize: 13,
                            color: isDisabled ? Colors.grey : null,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (topic['outlineTitle'] != null)
                          Text(
                            'Outline: ${topic['outlineTitle']}',
                            style: TextStyle(
                              fontSize: 11,
                              color: isDisabled ? Colors.grey : Colors.grey,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
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
                        print('Selected topic ID: $value');
                      });
                    },
              hint: _loadingTopics
                  ? const Row(
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Loading topics...',
                          style: TextStyle(fontSize: 13),
                        ),
                      ],
                    )
                  : (_topicError != null && !hasTopics)
                  ? Text(
                      _topicError!,
                      style: const TextStyle(
                        color: Colors.orange,
                        fontSize: 12,
                      ),
                    )
                  : Text(
                      hasTopics
                          ? 'Select Topic (Optional)'
                          : 'No topics available',
                      style: TextStyle(
                        color: hasTopics
                            ? const Color(0xFF666666)
                            : Colors.orange,
                        fontSize: 13,
                      ),
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
      body: _isLoading && _sessions.isEmpty && _courses.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
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
                  Text(
                    _isOffline
                        ? 'Offline Mode: Select from downloaded courses'
                        : 'Select your parameters to start practicing',
                    style: const TextStyle(
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
