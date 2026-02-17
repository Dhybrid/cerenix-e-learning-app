// lib/features/test_questions/screens/test_questions_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter/services.dart';
import 'dart:math';
import 'dart:async';
import '../../../core/network/api_service.dart';
import '../../../core/constants/endpoints.dart';
import '../models/test_question_models.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class TestQuestionsScreen extends StatefulWidget {
  final String courseId;
  final String courseName;
  final String? sessionId;
  final String sessionName;
  final String? topicId;
  final String? topicName;
  final bool randomMode;

  const TestQuestionsScreen({
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
  State<TestQuestionsScreen> createState() => _TestQuestionsScreenState();
}

class _TestQuestionsScreenState extends State<TestQuestionsScreen> {
  final ApiService _apiService = ApiService();

  List<TestQuestion> _questions = [];
  final List<bool> _showSolution = [];
  final List<bool> _isBookmarked = [];
  final List<bool> _isFlagged = [];
  final List<int> _flagCounts = []; // Track total flags per question
  bool _isLoading = true;
  bool _isOffline = false;
  bool _isEmptyTopic = false;
  String _errorMessage = '';

  // ========== ACTIVATION STATE ==========
  bool _isUserActivated = false;
  bool _checkingActivation = false;
  String _activationStatusMessage = 'Checking activation status...';
  int _maxQuestionsForNonActivated =
      2; // Show only 2 questions for non-activated users
  // ========== END ACTIVATION STATE ==========

  @override
  void initState() {
    super.initState();
    // _loadQuestions();
    _loadInitialData();

    // Debug offline storage
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _debugOfflineStorage();
    });
  }

  Future<void> _loadInitialData() async {
    await _checkActivationStatus(forceRefresh: true);
    await _loadQuestions();
  }

  // ========== ACTIVATION STATUS CHECK ==========

  Future<void> _checkActivationStatus({bool forceRefresh = false}) async {
    setState(() {
      _checkingActivation = true;
    });

    try {
      final activationBox = await Hive.openBox('activation_cache');

      if (!forceRefresh) {
        // Try cached data first
        final cachedActivation = activationBox.get('user_activated');
        final cachedTimestamp = activationBox.get('activation_timestamp');

        if (cachedActivation != null && cachedTimestamp != null) {
          final timestamp = DateTime.parse(cachedTimestamp);
          final now = DateTime.now();
          final difference = now.difference(timestamp);

          // Use cached data if it's less than 5 minutes old
          if (difference.inMinutes < 5) {
            setState(() {
              _isUserActivated = cachedActivation;
              _checkingActivation = false;
              _activationStatusMessage = _isUserActivated
                  ? 'Account activated'
                  : 'Account not activated';
            });
            print('✅ Using cached activation status: $_isUserActivated');
            return;
          }
        }
      }

      // Always fetch fresh data when forceRefresh is true or cache expired
      try {
        final activationData = await _apiService.getActivationStatus();

        if (activationData != null && activationData.isValid) {
          setState(() {
            _isUserActivated = true;
            _activationStatusMessage =
                '${activationData.grade?.toUpperCase() ?? 'Activated'}';
          });

          // Cache the result with timestamp
          await activationBox.put('user_activated', true);
          await activationBox.put(
            'activation_timestamp',
            DateTime.now().toIso8601String(),
          );
          await activationBox.put('activation_grade', activationData.grade);
          print('✅ User is activated: ${activationData.grade}');
        } else {
          setState(() {
            _isUserActivated = false;
            _activationStatusMessage = 'Not Activated';
          });

          // Cache the result
          await activationBox.put('user_activated', false);
          await activationBox.put(
            'activation_timestamp',
            DateTime.now().toIso8601String(),
          );
          print('ℹ️ User is not activated');
        }
      } catch (e) {
        print('❌ Error fetching activation from API: $e');

        // Fallback to cached data if available
        final cachedActivation = activationBox.get('user_activated');
        if (cachedActivation != null) {
          setState(() {
            _isUserActivated = cachedActivation;
            _activationStatusMessage = _isUserActivated
                ? 'Account activated (offline)'
                : 'Account not activated (offline)';
          });
        } else {
          setState(() {
            _isUserActivated = false;
            _activationStatusMessage = 'Not Activated (offline)';
          });
        }
      }
    } catch (e) {
      print('❌ Error in activation check: $e');
      setState(() {
        _isUserActivated = false;
        _activationStatusMessage = 'Error checking activation';
      });
    } finally {
      if (mounted) {
        setState(() {
          _checkingActivation = false;
        });
      }
    }
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
      print('📥 Loading questions...');
      print('   Course: ${widget.courseId} - ${widget.courseName}');
      print('   Session: ${widget.sessionId} - ${widget.sessionName}');
      print('   Topic: ${widget.topicId} - ${widget.topicName}');
      print('   Random Mode: ${widget.randomMode}');

      // Step 1: Simple connectivity check
      bool isOnline = false;
      try {
        final connectivityResult = await Connectivity().checkConnectivity();
        isOnline = connectivityResult != ConnectivityResult.none;

        if (isOnline) {
          print('📶 Device shows connectivity');
          // Try a HEAD request to your own server (more reliable)
          try {
            final response = await http
                .head(
                  Uri.parse('${ApiEndpoints.baseUrl}/api/health/'),
                  headers: {'Accept': 'application/json'},
                )
                .timeout(const Duration(seconds: 10));

            isOnline = response.statusCode < 500; // Server is reachable
            print('🌐 Server reachable: $isOnline (${response.statusCode})');
          } catch (e) {
            print('⚠️ Server check failed: $e');
            // If server check fails, try a simpler test
            try {
              // Try DNS lookup instead
              await InternetAddress.lookup(
                'google.com',
              ).timeout(const Duration(seconds: 3));
              isOnline = true;
              print('🌐 DNS test passed');
            } catch (e) {
              print('⚠️ DNS test also failed: $e');
              isOnline = false;
            }
          }
        }
      } catch (e) {
        print('⚠️ Connectivity check error: $e');
        isOnline = false;
      }

      // Step 2: If we think we're online, try API first
      if (isOnline) {
        print('🌐 Online - attempting to fetch from API...');

        // Add a timeout for the API call
        final apiQuestions = await _fetchQuestionsFromAPI()
            .timeout(
              const Duration(seconds: 15),
              onTimeout: () {
                print('⏰ API timeout - falling back to offline');
                return []; // Return empty to trigger offline fallback
              },
            )
            .catchError((error) {
              print('❌ API error: $error');
              return []; // Return empty to trigger offline fallback
            });

        if (!mounted) return;

        if (apiQuestions.isNotEmpty) {
          print('✅ API returned ${apiQuestions.length} questions');

          // Load flag status
          await _loadFlagStatus(apiQuestions);

          // Show the questions
          _showQuestions(apiQuestions, isOffline: false);

          // Cache for offline use
          await _cacheQuestionsForOffline(apiQuestions);

          return; // Success! Return here
        } else {
          print('⚠️ API returned empty or failed');
          // API failed or returned empty, check offline
        }
      } else {
        print('📴 No connectivity detected');
        setState(() {
          _isOffline = true;
        });
      }

      // Step 3: Check for offline questions (if we're offline OR API failed)
      print('📂 Checking for offline questions...');
      List<TestQuestion> offlineQuestions =
          await _loadQuestionsFromOfflineStorage();
      offlineQuestions = _filterOfflineQuestions(offlineQuestions);

      if (offlineQuestions.isNotEmpty) {
        print('✅ Found ${offlineQuestions.length} offline questions');
        _showQuestions(offlineQuestions, isOffline: true);
        return;
      }

      // Step 4: No questions found anywhere
      print('📭 No questions found from any source');

      if (isOnline) {
        // We're online but got no questions
        if (widget.topicId != null && widget.topicId!.isNotEmpty) {
          _showNoQuestions(
            isOffline: false,
            isEmptyTopic: true,
            message: 'No questions found for "${widget.topicName}".',
          );
        } else {
          _showNoQuestions(
            isOffline: false,
            message: 'No questions found for the selected filters.',
          );
        }
      } else {
        // We're offline with no downloaded questions
        _showNoQuestions(
          isOffline: true,
          message:
              'No internet connection and no downloaded questions found for this course.\n\n'
              'Please download courses when online or check your internet connection.',
        );
      }
    } catch (e) {
      print('❌ Error in _loadQuestions: $e');

      if (!mounted) return;

      _showNoQuestions(
        isOffline: true,
        message: 'Failed to load questions. ${e.toString().split(':').first}',
      );
    }
  }

  // Helper method to show questions
  void _showQuestions(List<TestQuestion> questions, {required bool isOffline}) {
    if (!mounted) return;

    // Limit questions for non-activated users
    List<TestQuestion> displayQuestions = List.from(questions);

    if (!_isUserActivated &&
        displayQuestions.length > _maxQuestionsForNonActivated) {
      print(
        '🔒 User not activated - limiting to $_maxQuestionsForNonActivated questions',
      );
      displayQuestions = displayQuestions.sublist(
        0,
        _maxQuestionsForNonActivated,
      );
    }

    setState(() {
      _questions = displayQuestions;
      _isOffline = isOffline;
      _isLoading = false;
      _isEmptyTopic = false;
    });

    // Initialize UI arrays
    _initializeUIArrays();

    print(
      '✅ Showing ${displayQuestions.length} questions (${isOffline ? 'offline' : 'online'}) - Activated: $_isUserActivated',
    );
  }

  // ========== ACTIVATION BANNER ==========

  Widget _buildActivationBanner() {
    return GestureDetector(
      onTap: () async {
        final result = await Navigator.pushNamed(context, '/activation');
        if (mounted) {
          await _checkActivationStatus(forceRefresh: true);
          await _loadQuestions();
        }
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.orange.shade50,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.orange.shade200, width: 1.5),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.orange.shade100,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.lock_outline_rounded,
                color: Colors.orange.shade600,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Account Not Activated',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange.shade800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Only $_maxQuestionsForNonActivated questions are available. Tap to activate and unlock all test questions.',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.orange.shade700,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              color: Colors.orange.shade600,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }

  // Helper method to show no questions state
  void _showNoQuestions({
    required bool isOffline,
    bool isEmptyTopic = false,
    required String message,
  }) {
    if (!mounted) return;

    setState(() {
      _questions = [];
      _isOffline = isOffline;
      _isLoading = false;
      _isEmptyTopic = isEmptyTopic;
      _errorMessage = message;
    });

    print('📭 No questions: $message');
  }

  void _initializeUIArrays() {
    _showSolution.clear();
    _isBookmarked.clear();
    _isFlagged.clear();
    _flagCounts.clear();

    // Initialize arrays with the correct length
    _showSolution.addAll(List.generate(_questions.length, (index) => false));
    _isBookmarked.addAll(List.generate(_questions.length, (index) => false));
    _isFlagged.addAll(List.generate(_questions.length, (index) => false));
    _flagCounts.addAll(List.generate(_questions.length, (index) => 0));

    print('📊 UI Arrays initialized for ${_questions.length} questions');
  }

  // Helper method to fetch questions from API

  Future<List<TestQuestion>> _fetchQuestionsFromAPI() async {
    if (widget.randomMode) {
      // Random mode - get all questions for the course and shuffle them
      final questions = await _apiService.getTestQuestions(
        courseId: widget.courseId,
      );
      questions.shuffle();
      print('🎲 Random Mode: Shuffled ${questions.length} questions');
      return questions;
    } else if (widget.topicId != null && widget.topicId!.isNotEmpty) {
      // Filter by topic
      return await _apiService.getTestQuestions(
        courseId: widget.courseId,
        sessionId: widget.sessionId,
        topicId: widget.topicId,
      );
    } else if (widget.sessionId != null && widget.sessionId!.isNotEmpty) {
      // Filter by session only
      return await _apiService.getTestQuestions(
        courseId: widget.courseId,
        sessionId: widget.sessionId,
      );
    } else {
      // Filter by course only
      return await _apiService.getTestQuestions(courseId: widget.courseId);
    }
  }

  Future<List<TestQuestion>> _loadQuestionsFromOfflineStorage() async {
    try {
      print('📂 Loading offline test questions for course: ${widget.courseId}');

      final offlineBox = await Hive.openBox('offline_courses');

      // First check if course is downloaded
      final downloadedCourseIds = offlineBox.get(
        'downloaded_course_ids',
        defaultValue: <String>[],
      );

      if (!downloadedCourseIds.contains(widget.courseId)) {
        print('⚠️ Course ${widget.courseId} not downloaded for offline use');
        return [];
      }

      final courseData = offlineBox.get('course_${widget.courseId}');

      if (courseData == null) {
        print('⚠️ No offline data found for course: ${widget.courseId}');
        return [];
      }

      final testQuestionsData = courseData['test_questions'] as List?;
      if (testQuestionsData == null || testQuestionsData.isEmpty) {
        print('⚠️ No test questions found in offline data');
        return [];
      }

      print(
        '✅ Found ${testQuestionsData.length} test questions in offline storage',
      );

      final List<TestQuestion> testQuestions = [];

      for (var pqData in testQuestionsData) {
        try {
          // FIX: Properly handle LinkedMap from Hive
          Map<String, dynamic> pqMap;
          if (pqData is Map) {
            // Convert LinkedMap or any Map type to Map<String, dynamic>
            pqMap = {};
            pqData.forEach((key, value) {
              if (key is String) {
                pqMap[key] = value;
              } else if (key is int || key is double) {
                pqMap[key.toString()] = value;
              }
            });
          } else if (pqData is Map<String, dynamic>) {
            pqMap = pqData;
          } else {
            print('⚠️ Unexpected data type: ${pqData.runtimeType}');
            continue;
          }

          print('🔍 Processing question ID: ${pqMap['id']}');

          // FIX: Ensure session info is properly structured
          if (pqMap['session_info'] == null ||
              (pqMap['session_info'] is Map &&
                  (pqMap['session_info'] as Map).isEmpty)) {
            // If session_info is empty but we have session_id, reconstruct it
            if (pqMap['session_id'] != null &&
                pqMap['session_id'].toString().isNotEmpty) {
              pqMap['session_info'] = {
                'id': pqMap['session_id'].toString(),
                'name': 'Session ${pqMap['session_id']}',
                'is_active': true,
              };
              print('   ✅ Reconstructed session_info from session_id');
            }
          }

          // FIX: Check for local image paths - ensure proper type handling
          if (courseData.containsKey('downloaded_images')) {
            final downloadedImages = courseData['downloaded_images'];
            if (downloadedImages is Map) {
              // Convert downloaded_images to proper Map<String, dynamic>
              final imagesMap = <String, Map<String, dynamic>>{};
              downloadedImages.forEach((key, value) {
                if (key is String && value is Map) {
                  final imageInfo = <String, dynamic>{};
                  value.forEach((k, v) {
                    if (k is String) {
                      imageInfo[k] = v;
                    } else if (k is int || k is double) {
                      imageInfo[k.toString()] = v;
                    }
                  });
                  imagesMap[key] = imageInfo;
                }
              });

              // Replace question image URL with local path if available
              final questionImageKey = 'test_question_${pqMap['id']}';
              if (imagesMap.containsKey(questionImageKey)) {
                final imageInfo = imagesMap[questionImageKey];
                final localPath = imageInfo?['path'] as String?;

                if (localPath != null && localPath.isNotEmpty) {
                  // Store both original and local path
                  pqMap['original_question_image_url'] =
                      pqMap['question_image_url'];
                  pqMap['question_image_url'] = localPath;
                  pqMap['local_question_image_path'] = localPath;
                  print('   ✅ Found local question image: $localPath');
                }
              }

              // Replace solution image URL with local path if available
              final solutionImageKey = 'test_question_solution_${pqMap['id']}';
              if (imagesMap.containsKey(solutionImageKey)) {
                final imageInfo = imagesMap[solutionImageKey];
                final localPath = imageInfo?['path'] as String?;

                if (localPath != null && localPath.isNotEmpty) {
                  // Store both original and local path
                  pqMap['original_solution_image_url'] =
                      pqMap['solution_image_url'];
                  pqMap['solution_image_url'] = localPath;
                  pqMap['local_solution_image_path'] = localPath;
                  print('   ✅ Found local solution image: $localPath');
                }
              }
            }
          }

          // Parse the question
          final testQuestion = TestQuestion.fromJson(pqMap);

          // Debug the parsed question
          print('   ✅ Parsed question:');
          print('      - ID: ${testQuestion.id}');
          print('      - Course ID: ${testQuestion.courseId}');
          print('      - Session ID: ${testQuestion.sessionId}');
          print('      - Session Info: ${testQuestion.sessionInfo}');
          print(
            '      - Has question image: ${testQuestion.questionImageUrl != null}',
          );
          print(
            '      - Has solution image: ${testQuestion.solutionImageUrl != null}',
          );

          testQuestions.add(testQuestion);
        } catch (e) {
          print('⚠️ Error parsing offline test question: $e');
          print('   Error type: ${e.runtimeType}');
          print('   Raw data type: ${pqData.runtimeType}');
          continue;
        }
      }

      print(
        '✅ Successfully loaded ${testQuestions.length} offline test questions',
      );
      return testQuestions;
    } catch (e) {
      print('❌ Error loading offline questions: $e');
      return [];
    }
  }

  List<TestQuestion> _filterOfflineQuestions(List<TestQuestion> questions) {
    if (questions.isEmpty) return [];

    print('🔍 Filtering ${questions.length} offline questions');
    print('   - Session filter: ${widget.sessionId}');
    print('   - Session Name: ${widget.sessionName}');
    print('   - Topic filter: ${widget.topicId}');
    print('   - Random mode: ${widget.randomMode}');

    List<TestQuestion> filtered = List.from(questions);

    // Debug all questions first
    print('📊 All offline questions before filtering:');
    for (var q in filtered) {
      print('   - ID: ${q.id}');
      print('     Session ID from question: ${q.sessionId}');
      print('     Session Info: ${q.sessionInfo}');
      print('     Topic ID: ${q.topicId}');
      print('     Topic Info: ${q.topicInfo}');
    }

    // Handle "All Sessions" case
    if (widget.sessionName == 'All Sessions') {
      print('   "All Sessions" selected - no session filtering');
    }
    // Filter by session if specified and not "All Sessions"
    else if (widget.sessionId != null &&
        widget.sessionId!.isNotEmpty &&
        widget.sessionName != 'All Sessions') {
      print('   Applying session filter: ${widget.sessionId}');

      filtered = filtered.where((question) {
        String? questionSessionId;

        // Get session ID from various possible sources
        if (question.sessionInfo.isNotEmpty) {
          // Try to get from session_info map
          final sessionInfo = question.sessionInfo;
          if (sessionInfo['id'] != null) {
            questionSessionId = sessionInfo['id']?.toString();
          } else if (sessionInfo['session_id'] != null) {
            questionSessionId = sessionInfo['session_id']?.toString();
          }
        }

        // Fallback to direct sessionId field
        if (questionSessionId == null || questionSessionId.isEmpty) {
          questionSessionId = question.sessionId;
        }

        // If still no session ID, check session_info field (nested)
        if ((questionSessionId == null || questionSessionId.isEmpty) &&
            question.sessionInfo.containsKey('session_info')) {
          final nested = question.sessionInfo['session_info'];
          if (nested is Map && nested['id'] != null) {
            questionSessionId = nested['id']?.toString();
          }
        }

        // Handle case where question has no session info
        if (questionSessionId == null || questionSessionId.isEmpty) {
          print('   ⚠️ Question ${question.id} has no session ID');
          // In offline mode, include if no specific filter OR if session filter is empty
          if (widget.sessionId == null || widget.sessionId!.isEmpty) {
            return true;
          }
          return false;
        }

        // Compare session IDs (as strings since widget.sessionId is String?)
        final matches = questionSessionId == widget.sessionId;
        print(
          '   Question ${question.id} -> session: $questionSessionId, filter: ${widget.sessionId}, match: $matches',
        );
        return matches;
      }).toList();
    }

    print('   - After session filter: ${filtered.length} questions');

    // Filter by topic if specified
    if (widget.topicId != null && widget.topicId!.isNotEmpty) {
      print('   Applying topic filter: ${widget.topicId}');

      filtered = filtered.where((question) {
        String? questionTopicId;

        // Check topicInfo map first
        if (question.topicInfo != null &&
            question.topicInfo is Map &&
            question.topicInfo!.isNotEmpty) {
          final topicInfo = question.topicInfo!;
          if (topicInfo['id'] != null) {
            questionTopicId = topicInfo['id']?.toString();
          }
        }

        // Check topicId field
        if ((questionTopicId == null || questionTopicId.isEmpty) &&
            question.topicId != null) {
          questionTopicId = question.topicId;
        }

        // If question has no topic ID
        if (questionTopicId == null || questionTopicId.isEmpty) {
          if (widget.topicId!.isEmpty) {
            return true; // Include if no specific topic filter
          }
          return false; // Exclude if specific topic filter but no topic ID
        }

        final matches = questionTopicId == widget.topicId;
        print(
          '   Question ${question.id} -> topic: $questionTopicId, filter: ${widget.topicId}, match: $matches',
        );
        return matches;
      }).toList();

      print('   - After topic filter: ${filtered.length} questions');
    }

    // Apply random mode if enabled
    if (widget.randomMode && filtered.isNotEmpty) {
      filtered.shuffle();
      print('   - Random mode applied: shuffled ${filtered.length} questions');
    }

    return filtered;
  }

  Future<void> _debugOfflineStorage() async {
    print('🔍 === DEBUG OFFLINE STORAGE ===');
    try {
      final offlineBox = await Hive.openBox('offline_courses');
      final downloadedCourseIds = offlineBox.get(
        'downloaded_course_ids',
        defaultValue: <String>[],
      );

      print('📦 Downloaded courses: $downloadedCourseIds');

      for (var courseId in downloadedCourseIds) {
        print('\n📖 Course ID: $courseId');
        final courseData = offlineBox.get('course_$courseId');

        if (courseData != null) {
          final testQuestions = courseData['test_questions'] as List?;
          print('   Test questions count: ${testQuestions?.length ?? 0}');

          if (testQuestions != null && testQuestions.isNotEmpty) {
            final firstPq = Map<String, dynamic>.from(testQuestions.first);
            print('   First question structure:');
            print('     - ID: ${firstPq['id']}');
            print('     - Course: ${firstPq['course']}');
            print('     - Session: ${firstPq['session']}');
            print('     - Session type: ${firstPq['session']?.runtimeType}');
            print('     - Topic: ${firstPq['topic']}');
          }
        }
      }
    } catch (e) {
      print('❌ Debug error: $e');
    }
    print('🔍 === END DEBUG ===');
  }

  Future<void> _debugOfflineQuestions(List<TestQuestion> questions) async {
    print('🔍 === DEBUG OFFLINE QUESTIONS STRUCTURE ===');
    print('📊 Total questions: ${questions.length}');

    for (int i = 0; i < min(3, questions.length); i++) {
      final q = questions[i];
      print('\n📋 Question ${i + 1} (ID: ${q.id}):');
      print('   Course ID: ${q.courseId}');
      print('   Session ID: ${q.sessionId}');
      print('   Session Info: ${q.sessionInfo}');
      print('   Topic ID: ${q.topicId}');
      print('   Topic Info: ${q.topicInfo}');
      print('   Question text length: ${q.questionText?.length ?? 0}');
      print('   Has options: ${q.hasOptions}');
    }

    // Also check sessions across all questions
    final sessionSet = <String, String>{};
    for (var q in questions) {
      if (q.sessionInfo.isNotEmpty && q.sessionInfo['id'] != null) {
        final sessionId = q.sessionInfo['id']?.toString() ?? '';
        final sessionName = q.sessionInfo['name']?.toString() ?? 'Unknown';
        sessionSet[sessionId] = sessionName;
      }
    }

    print('\n📅 Unique sessions in questions:');
    if (sessionSet.isEmpty) {
      print('   ⚠️ NO SESSION DATA FOUND IN QUESTIONS');
    } else {
      sessionSet.forEach((id, name) {
        print('   - $id: $name');
      });
    }

    print('🔍 === END DEBUG ===');
  }

  // Helper method to cache questions for offline use
  Future<void> _cacheQuestionsForOffline(List<TestQuestion> questions) async {
    try {
      final box = await Hive.openBox('Test_questions_cache');
      final cacheKey = 'course_${widget.courseId}';
      final questionData = questions.map((q) => q.toJson()).toList();

      await box.put(cacheKey, questionData);
      await box.put('${cacheKey}_timestamp', DateTime.now().toIso8601String());

      print('✅ Cached ${questions.length} questions for offline use');
    } catch (e) {
      print('⚠️ Error caching questions: $e');
    }
  }

  @override
  void didUpdateWidget(TestQuestionsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Check if any filter parameters have changed
    final hasChanges =
        oldWidget.courseId != widget.courseId ||
        oldWidget.sessionId != widget.sessionId ||
        oldWidget.topicId != widget.topicId ||
        oldWidget.randomMode != widget.randomMode;

    if (hasChanges) {
      print('🔄 Filter parameters changed, reloading questions...');
      print('   - Course: ${oldWidget.courseId} -> ${widget.courseId}');
      print('   - Session: ${oldWidget.sessionId} -> ${widget.sessionId}');
      print('   - Topic: ${oldWidget.topicId} -> ${widget.topicId}');
      print(
        '   - Random Mode: ${oldWidget.randomMode} -> ${widget.randomMode}',
      );

      // Reload questions with new filters
      _loadQuestions();
    }
  }

  String _getErrorMessage(dynamic error) {
    final errorStr = error.toString();

    if (errorStr.contains('offline') ||
        errorStr.contains('internet') ||
        errorStr.contains('network') ||
        errorStr.contains('SocketException')) {
      return 'No internet connection. Showing offline questions if available.';
    } else if (errorStr.contains('401')) {
      return 'Please login to continue';
    } else if (errorStr.contains('404')) {
      return _isOffline
          ? 'No offline questions found for this course'
          : 'No questions found for the selected filters';
    } else if (errorStr.contains('500')) {
      return 'Server error. Please try again later';
    } else {
      return 'Failed to load questions. ${_isOffline ? 'You are offline.' : ''}';
    }
  }

  Future<void> _loadFlagStatus(List<TestQuestion> questions) async {
    try {
      print('🚩 Loading flag status for ${questions.length} questions');

      for (int i = 0; i < questions.length; i++) {
        final question = questions[i];
        print('🚩 Getting flag status for question: ${question.id}');

        try {
          final flagStatus = await _apiService.getTestQuestionFlagStatus(
            questionId: question.id,
          );

          print('📥 Flag status for ${question.id}: $flagStatus');

          if (mounted) {
            setState(() {
              if (i < _isFlagged.length) {
                // If user is not authenticated, they can't have flagged anything
                _isFlagged[i] = flagStatus['is_flagged'] == true;
              }
              if (i < _flagCounts.length) {
                _flagCounts[i] = (flagStatus['total_flags'] as int?) ?? 0;
              }
            });
          }

          // Debug output
          print(
            '   Question ${question.id}: flagged=${_isFlagged[i]}, flags=${_flagCounts[i]}, auth=${flagStatus['is_authenticated']}',
          );
        } catch (e) {
          print('⚠️ Error loading flag status for question ${question.id}: $e');

          // Set default values on error
          if (mounted) {
            setState(() {
              if (i < _isFlagged.length) {
                _isFlagged[i] = false;
              }
              if (i < _flagCounts.length) {
                _flagCounts[i] = 0;
              }
            });
          }
        }
      }

      print('✅ Flag status loaded for all questions');
    } catch (e) {
      print('❌ Error in _loadFlagStatus: $e');
    }
  }

  Future<void> _toggleFlagQuestion(int index) async {
    try {
      final question = _questions[index];

      if (_isFlagged[index]) {
        // Unflag the question
        await _unflagQuestion(index);
      } else {
        // Flag the question with a default reason
        await _flagQuestion(
          index,
          'other', // Default reason
          description: 'Flagged by user',
        );
      }
    } catch (e) {
      print('❌ Error toggling flag: $e');
    }
  }

  // Simplify the flag method
  Future<void> _flagQuestion(
    int index,
    String reason, {
    String? description,
  }) async {
    try {
      final question = _questions[index];

      // Update UI immediately for better UX
      setState(() {
        _isFlagged[index] = true;
      });

      final response = await _apiService.flagTestQuestion(
        questionId: question.id,
        reason: reason,
        description: description,
      );

      // Update flag count
      if (mounted) {
        setState(() {
          _flagCounts[index] =
              response['flag_count'] ?? (_flagCounts[index] + 1);
        });
      }

      // Show simple snackbar instead of undo
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Question flagged'),
          backgroundColor: const Color(0xFF8B5CF6),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      print('❌ Error flagging question: $e');

      // Revert on error
      if (mounted) {
        setState(() {
          _isFlagged[index] = false;
        });
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to flag question'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  // Simplify the unflag method
  Future<void> _unflagQuestion(int index) async {
    try {
      final question = _questions[index];

      setState(() {
        _isFlagged[index] = false;
      });

      final response = await _apiService.unflagTestQuestion(
        questionId: question.id,
      );

      // Update flag count
      if (mounted) {
        setState(() {
          _flagCounts[index] = max(0, (_flagCounts[index] - 1));
        });
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Flag removed'),
          backgroundColor: const Color(0xFF10B981),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      print('❌ Error unflagging question: $e');

      // Revert on error
      if (mounted) {
        setState(() {
          _isFlagged[index] = true;
        });
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to remove flag'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }
  // In ApiService class (api_service.dart), update the flagTestQuestion method:

  void _toggleBookmark(int index) {
    setState(() {
      _isBookmarked[index] = !_isBookmarked[index];
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _isBookmarked[index] ? 'Question bookmarked!' : 'Bookmark removed',
        ),
        backgroundColor: const Color(0xFFF59E0B),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showFlagDialog(int index) {
    String? selectedReason;
    final descriptionController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return Dialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.flag_rounded,
                    size: 40,
                    color: _isFlagged[index]
                        ? Colors.orange
                        : const Color(0xFF8B5CF6),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _isFlagged[index] ? 'Update Flag' : 'Flag Question',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A1A2E),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _isFlagged[index]
                        ? 'You have already flagged this question. You can update your reason.'
                        : 'Why are you flagging this question?',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFF6B7280),
                      fontSize: 14,
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Flag Count Badge
                  if (_flagCounts[index] > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.orange.shade200),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.flag, size: 14, color: Colors.orange),
                          const SizedBox(width: 6),
                          Text(
                            '${_flagCounts[index]} other user${_flagCounts[index] > 1 ? 's' : ''} also flagged this',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.orange.shade800,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),

                  const SizedBox(height: 20),

                  // Reason Options
                  Column(
                    children: [
                      _buildFlagOption('Incorrect question', selectedReason, (
                        reason,
                      ) {
                        setDialogState(() => selectedReason = reason);
                      }),
                      _buildFlagOption('Wrong answer', selectedReason, (
                        reason,
                      ) {
                        setDialogState(() => selectedReason = reason);
                      }),
                      _buildFlagOption('Poor formatting', selectedReason, (
                        reason,
                      ) {
                        setDialogState(() => selectedReason = reason);
                      }),
                      _buildFlagOption('Other issue', selectedReason, (reason) {
                        setDialogState(() => selectedReason = reason);
                      }),
                    ],
                  ),

                  const SizedBox(height: 16),
                  TextField(
                    controller: descriptionController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: 'Additional details (optional)',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  Row(
                    children: [
                      if (_isFlagged[index])
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              Navigator.pop(context);
                              _unflagQuestion(index);
                            },
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.red,
                              side: const BorderSide(color: Colors.red),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: const Text('Remove Flag'),
                          ),
                        ),
                      if (_isFlagged[index]) const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF6B7280),
                            side: const BorderSide(color: Color(0xFFD1D5DB)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: selectedReason != null
                              ? () async {
                                  Navigator.pop(context);
                                  await _flagQuestion(
                                    index,
                                    selectedReason!,
                                    description:
                                        descriptionController.text.isNotEmpty
                                        ? descriptionController.text
                                        : null,
                                  );
                                }
                              : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _isFlagged[index]
                                ? Colors.orange
                                : const Color(0xFF8B5CF6),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: Text(
                            _isFlagged[index] ? 'Update' : 'Flag Question',
                          ),
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

  Widget _buildFlagOption(
    String reason,
    String? selectedReason,
    Function(String) onSelect,
  ) {
    final isSelected = selectedReason == reason;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      child: OutlinedButton(
        onPressed: () => onSelect(reason),
        style: OutlinedButton.styleFrom(
          foregroundColor: isSelected
              ? const Color(0xFF8B5CF6)
              : const Color(0xFF6B7280),
          side: BorderSide(
            color: isSelected
                ? const Color(0xFF8B5CF6)
                : const Color(0xFFD1D5DB),
            width: isSelected ? 2 : 1,
          ),
          backgroundColor: isSelected
              ? const Color(0xFF8B5CF6).withOpacity(0.1)
              : Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
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
                child: const Icon(
                  Icons.check_rounded,
                  color: Color(0xFF10B981),
                  size: 32,
                ),
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
              _buildFormattedContent(correctAnswer, isAnswer: true),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
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
    final question = _questions[questionIndex];

    Navigator.pushNamed(
      context,
      '/question-gpt',
      arguments: {
        'question': question,
        'courseName': widget.courseName,
        'topicName': widget.topicName,
        'showAnswer': false,
      },
    );
  }

  // ========== CONTENT FORMATTING METHODS (SAME AS LECTURE SCREEN) ==========

  Widget _buildFormattedContent(String content, {bool isAnswer = false}) {
    if (content.isEmpty) return Container();

    // Convert CKEditor HTML to clean markdown
    final cleanContent = _convertCkEditorToMarkdown(content);

    return Container(
      constraints: BoxConstraints(
        minHeight: 50, // Minimum height to avoid unconstrained errors
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: _parseContentForDisplay(cleanContent, isAnswer: isAnswer),
        ),
      ),
    );
  }

  String _convertCkEditorToMarkdown(String htmlContent) {
    if (htmlContent.isEmpty) return '';

    String result = htmlContent;

    // Debug: Print raw HTML
    print(
      '📝 Raw HTML: ${htmlContent.substring(0, min(200, htmlContent.length))}...',
    );

    // 1. Handle tables FIRST (important to do this before removing other tags)
    result = _convertHtmlTablesToMarkdown(result);

    // 2. Convert math equations
    result = result.replaceAllMapped(
      RegExp(
        r'<span[^>]*class="math-tex"[^>]*>(.*?)</span>',
        caseSensitive: false,
        dotAll: true,
      ),
      (match) {
        final mathContent = match.group(1) ?? '';
        // Clean math content
        final cleanMath = mathContent
            .replaceAll('&lt;', '<')
            .replaceAll('&gt;', '>')
            .replaceAll('&amp;', '&');
        return '\$$cleanMath\$';
      },
    );

    // 3. Handle MathJax/LaTeX blocks
    result = result.replaceAllMapped(
      RegExp(
        r'<script[^>]*type="math/tex"[^>]*>(.*?)</script>',
        caseSensitive: false,
        dotAll: true,
      ),
      (match) {
        final mathContent = match.group(1) ?? '';
        return '\$\$$mathContent\$\$';
      },
    );

    result = result.replaceAllMapped(
      RegExp(
        r'<script[^>]*type="math/tex; mode=display"[^>]*>(.*?)</script>',
        caseSensitive: false,
        dotAll: true,
      ),
      (match) {
        final mathContent = match.group(1) ?? '';
        return '\$\$$mathContent\$\$';
      },
    );

    // 4. Convert code blocks
    result = result.replaceAllMapped(
      RegExp(r'<pre[^>]*>(.*?)</pre>', caseSensitive: false, dotAll: true),
      (match) {
        final preContent = match.group(1) ?? '';
        String codeContent = preContent;

        // Extract language from class
        String language = '';
        final classMatch = RegExp(
          r'class="([^"]*)"',
        ).firstMatch(match.group(0) ?? '');
        if (classMatch != null) {
          final classes = classMatch.group(1)!.split(' ');
          for (final cls in classes) {
            if (cls.startsWith('language-')) {
              language = cls.replaceFirst('language-', '');
              break;
            }
          }
        }

        // Clean code content
        codeContent = codeContent
            .replaceAll('<code>', '')
            .replaceAll('</code>', '')
            .replaceAll('&lt;', '<')
            .replaceAll('&gt;', '>')
            .replaceAll('&amp;', '&')
            .trim();

        return '```$language\n$codeContent\n```';
      },
    );

    // 5. Convert inline code
    result = result.replaceAllMapped(
      RegExp(r'<code[^>]*>(.*?)</code>', caseSensitive: false),
      (match) {
        final codeContent = match.group(1) ?? '';
        final cleanCode = codeContent
            .replaceAll('&lt;', '<')
            .replaceAll('&gt;', '>')
            .replaceAll('&amp;', '&');
        return '`$cleanCode`';
      },
    );

    // 6. Convert images with proper handling
    result = result.replaceAllMapped(
      RegExp(r'<img[^>]*>', caseSensitive: false),
      (match) {
        final imgTag = match.group(0)!;
        String? src, alt;

        // Extract src
        final srcMatch = RegExp(r'src="([^"]*)"').firstMatch(imgTag);
        if (srcMatch != null) src = srcMatch.group(1);

        // Extract alt
        final altMatch = RegExp(r'alt="([^"]*)"').firstMatch(imgTag);
        if (altMatch != null) alt = altMatch.group(1);

        // Extract title
        final titleMatch = RegExp(r'title="([^"]*)"').firstMatch(imgTag);
        final title = titleMatch?.group(1);

        // if (src == null) return '';

        // If no src, return empty
        if (src == null || src.isEmpty) return '';

        // Handle relative URLs
        String imageUrl = src;

        // Check if it's already a full URL
        if (!src.startsWith('http://') && !src.startsWith('https://')) {
          // It's a relative URL
          if (src.startsWith('/')) {
            // Path starts with /, append to base URL
            final baseUrl = ApiEndpoints.baseUrl;
            imageUrl = '$baseUrl$src';
          } else if (src.startsWith('media/') || src.startsWith('/media/')) {
            // Django media path
            final baseUrl = ApiEndpoints.baseUrl;
            if (src.startsWith('media/')) {
              imageUrl = '$baseUrl/$src';
            } else {
              imageUrl = '$baseUrl$src';
            }
          } else if (src.startsWith('uploads/')) {
            // CKEditor uploads path
            final baseUrl = ApiEndpoints.baseUrl;
            imageUrl = '$baseUrl/media/$src';
          } else {
            // Assume it's a relative path from media
            final baseUrl = ApiEndpoints.baseUrl;
            imageUrl = '$baseUrl/media/$src';
          }
        }

        // Clean up any double slashes
        imageUrl = imageUrl.replaceAll('//media/', '/media/');
        imageUrl = imageUrl.replaceAll(':/', '://');

        // Use title as alt text if alt is empty
        final displayAlt = alt?.isNotEmpty == true ? alt : title ?? '';

        print('🖼️ Image URL: $imageUrl');
        print('🖼️ Alt text: $displayAlt');

        return '![${displayAlt}]($imageUrl)';

        // Handle relative URLs
        // if (!src.startsWith('http') && !src.startsWith('/')) {
        //   src = '/media/$src';
        // }

        // return '![${alt ?? title ?? ''}]($src)';
      },
    );

    // 7. Convert headings
    for (int i = 6; i >= 1; i--) {
      result = result.replaceAllMapped(
        RegExp(r'<h$i[^>]*>(.*?)</h$i>', caseSensitive: false, dotAll: true),
        (match) {
          final headingText = match.group(1) ?? '';
          final cleanText = _cleanHtmlText(headingText);
          final hashes = '#' * i;
          return '$hashes $cleanText';
        },
      );
    }

    // 8. Convert lists
    result = result.replaceAllMapped(
      RegExp(r'<ul[^>]*>(.*?)</ul>', caseSensitive: false, dotAll: true),
      (match) {
        String ulContent = match.group(1) ?? '';
        ulContent = ulContent.replaceAllMapped(
          RegExp(r'<li[^>]*>(.*?)</li>', caseSensitive: false, dotAll: true),
          (liMatch) {
            String liContent = liMatch.group(1) ?? '';
            liContent = _cleanHtmlText(liContent);
            return '- $liContent';
          },
        );
        return ulContent;
      },
    );

    result = result.replaceAllMapped(
      RegExp(r'<ol[^>]*>(.*?)</ol>', caseSensitive: false, dotAll: true),
      (match) {
        String olContent = match.group(1) ?? '';
        int counter = 1;
        olContent = olContent.replaceAllMapped(
          RegExp(r'<li[^>]*>(.*?)</li>', caseSensitive: false, dotAll: true),
          (liMatch) {
            String liContent = liMatch.group(1) ?? '';
            liContent = _cleanHtmlText(liContent);
            final result = '$counter. $liContent';
            counter++;
            return result;
          },
        );
        return olContent;
      },
    );

    // 9. Convert paragraphs with proper spacing
    result = result.replaceAllMapped(
      RegExp(r'<p[^>]*>(.*?)</p>', caseSensitive: false, dotAll: true),
      (match) {
        final pContent = match.group(1) ?? '';
        final cleanText = _cleanHtmlText(pContent);
        return '$cleanText\n\n';
      },
    );

    // 10. Convert formatting
    result = result.replaceAllMapped(
      RegExp(
        r'<strong[^>]*>(.*?)</strong>',
        caseSensitive: false,
        dotAll: true,
      ),
      (match) {
        final content = match.group(1) ?? '';
        return '**${_cleanHtmlText(content)}**';
      },
    );

    result = result.replaceAllMapped(
      RegExp(r'<b[^>]*>(.*?)</b>', caseSensitive: false, dotAll: true),
      (match) {
        final content = match.group(1) ?? '';
        return '**${_cleanHtmlText(content)}**';
      },
    );

    result = result.replaceAllMapped(
      RegExp(r'<em[^>]*>(.*?)</em>', caseSensitive: false, dotAll: true),
      (match) {
        final content = match.group(1) ?? '';
        return '*${_cleanHtmlText(content)}*';
      },
    );

    result = result.replaceAllMapped(
      RegExp(r'<i[^>]*>(.*?)</i>', caseSensitive: false, dotAll: true),
      (match) {
        final content = match.group(1) ?? '';
        return '*${_cleanHtmlText(content)}*';
      },
    );

    // 11. Convert links
    result = result.replaceAllMapped(
      RegExp(
        r'<a[^>]*href="([^"]*)"[^>]*>(.*?)</a>',
        caseSensitive: false,
        dotAll: true,
      ),
      (match) {
        final href = match.group(1) ?? '';
        final text = match.group(2) ?? '';
        final cleanText = _cleanHtmlText(text);
        return '[$cleanText]($href)';
      },
    );

    // 12. Convert blockquotes
    result = result.replaceAllMapped(
      RegExp(
        r'<blockquote[^>]*>(.*?)</blockquote>',
        caseSensitive: false,
        dotAll: true,
      ),
      (match) {
        String quoteContent = match.group(1) ?? '';
        quoteContent = _cleanHtmlText(quoteContent);
        final lines = quoteContent.split('\n');
        return lines.map((line) => '> $line').join('\n');
      },
    );

    // 13. Remove remaining HTML tags but keep their content
    result = result.replaceAll(RegExp(r'<[^>]*>'), '');

    // 14. Decode HTML entities
    result = _decodeHtmlEntities(result);

    // 15. Clean up whitespace
    result = result
        .replaceAll(RegExp(r'\n\s*\n\s*\n'), '\n\n')
        .replaceAll(RegExp(r'[ \t]+'), ' ')
        .trim();

    print(
      '📝 Converted Markdown: ${result.substring(0, min(200, result.length))}...',
    );
    return result;
  }

  List<Widget> _parseContentForDisplay(
    String content, {
    bool isAnswer = false,
  }) {
    final List<Widget> widgets = [];
    final lines = content.split('\n');
    bool inCodeBlock = false;
    bool inMathBlock = false;
    List<String> currentCodeBlock = [];
    String? currentLanguage;
    List<String> currentMathBlock = [];

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      final trimmedLine = line.trim();

      // Skip if inside code or math block
      if (inCodeBlock || inMathBlock) {
        if (inCodeBlock) {
          if (trimmedLine.startsWith('```')) {
            inCodeBlock = false;
            final codeContent = currentCodeBlock.join('\n');
            widgets.add(_buildCodeBlock(codeContent, currentLanguage ?? ''));
          } else {
            currentCodeBlock.add(line);
          }
        }
        if (inMathBlock) {
          if (trimmedLine.startsWith(r'$$')) {
            inMathBlock = false;
            if (currentMathBlock.isNotEmpty) {
              widgets.add(_buildMathBlock(currentMathBlock.join('\n')));
            }
          } else {
            currentMathBlock.add(line);
          }
        }
        continue;
      }

      // Handle tables
      if (_isTableStart(lines, i)) {
        final tableLines = _extractTableLines(lines, i);
        if (tableLines.isNotEmpty) {
          widgets.add(_buildMarkdownTable(tableLines.join('\n')));
          i += tableLines.length - 1;
        }
        continue;
      }

      // Handle math blocks with $$
      if (trimmedLine.startsWith(r'$$')) {
        if (!inMathBlock) {
          inMathBlock = true;
          currentMathBlock = [];
        } else {
          inMathBlock = false;
          if (currentMathBlock.isNotEmpty) {
            widgets.add(_buildMathBlock(currentMathBlock.join('\n')));
          }
        }
        continue;
      }

      if (inMathBlock) {
        currentMathBlock.add(line);
        continue;
      }

      // Handle LaTeX math blocks with \[ \]
      if (trimmedLine.contains(r'\[') && trimmedLine.contains(r'\]')) {
        final startIndex = trimmedLine.indexOf(r'\[');
        final endIndex = trimmedLine.indexOf(r'\]');
        if (startIndex != -1 && endIndex != -1 && endIndex > startIndex) {
          final mathContent = trimmedLine.substring(startIndex + 2, endIndex);
          widgets.add(_buildMathBlock(mathContent));

          final beforeMath = trimmedLine.substring(0, startIndex);
          if (beforeMath.isNotEmpty) {
            widgets.add(_buildText(beforeMath, isAnswer: isAnswer));
          }

          final afterMath = trimmedLine.substring(endIndex + 2);
          if (afterMath.isNotEmpty) {
            widgets.add(_buildText(afterMath, isAnswer: isAnswer));
          }
          continue;
        }
      }

      // Handle inline math with $ or \( \)
      if (_containsInlineMath(line)) {
        widgets.add(_buildInlineMathText(line, isAnswer: isAnswer));
        continue;
      }

      // Handle code blocks
      if (trimmedLine.startsWith('```')) {
        if (!inCodeBlock) {
          inCodeBlock = true;
          currentCodeBlock = [];
          currentLanguage = trimmedLine.replaceAll('```', '').trim();
        } else {
          inCodeBlock = false;
          final codeContent = currentCodeBlock.join('\n');
          widgets.add(_buildCodeBlock(codeContent, currentLanguage ?? ''));
        }
        continue;
      }

      if (inCodeBlock) {
        currentCodeBlock.add(line);
        continue;
      }

      // Handle inline code
      if (_containsInlineCode(line)) {
        widgets.add(_buildInlineCode(line));
        continue;
      }

      // Handle images
      if (_isImageLine(line)) {
        widgets.add(_buildImage(line));
        continue;
      }

      // Handle headings
      if (trimmedLine.startsWith('#')) {
        widgets.add(_buildHeading(line));
        continue;
      }

      // Handle lists
      if (_isListItem(line)) {
        final listItems = _extractListItems(lines, i);
        widgets.add(_buildList(listItems));
        i += listItems.length - 1;
        continue;
      }

      // Regular paragraphs
      if (trimmedLine.isNotEmpty) {
        if (i == 0 || lines[i - 1].trim().isEmpty) {
          final paragraph = _extractParagraph(lines, i);
          if (_containsInlineMath(paragraph)) {
            widgets.add(_buildInlineMathText(paragraph, isAnswer: isAnswer));
          } else {
            widgets.add(_buildParagraph(paragraph, isAnswer: isAnswer));
          }
          i += paragraph.split('\n').length - 1;
        }
      } else {
        if (i > 0 && lines[i - 1].trim().isNotEmpty) {
          widgets.add(const SizedBox(height: 8));
        }
      }
    }

    // Handle any remaining blocks
    if (inCodeBlock && currentCodeBlock.isNotEmpty) {
      final codeContent = currentCodeBlock.join('\n');
      widgets.add(_buildCodeBlock(codeContent, currentLanguage ?? ''));
    }

    if (inMathBlock && currentMathBlock.isNotEmpty) {
      widgets.add(_buildMathBlock(currentMathBlock.join('\n')));
    }

    return widgets;
  }

  // ========== CONTENT PARSING HELPER METHODS ==========

  bool _isTableStart(List<String> lines, int index) {
    if (index >= lines.length) return false;
    final line = lines[index].trim();
    if (!line.startsWith('|')) return false;
    if (index + 1 >= lines.length) return false;

    final nextLine = lines[index + 1].trim();
    if (!nextLine.startsWith('|')) return false;

    final pipeCount = '|'.allMatches(nextLine).length;
    if (pipeCount < 2) return false;

    final parts = nextLine.split('|');
    for (int i = 1; i < parts.length - 1; i++) {
      final part = parts[i].trim();
      if (part.isNotEmpty && !RegExp(r'^:?-+:?$').hasMatch(part)) {
        return false;
      }
    }

    return true;
  }

  List<String> _extractTableLines(List<String> lines, int startIndex) {
    final tableLines = <String>[];

    for (int i = startIndex; i < lines.length; i++) {
      final line = lines[i].trim();
      if (!line.startsWith('|')) break;

      if (i > startIndex && line.contains('---')) {
        final parts = line.split('|');
        bool isValidSeparator = true;
        for (int j = 1; j < parts.length - 1; j++) {
          final part = parts[j].trim();
          if (part.isNotEmpty && !RegExp(r'^:?-+:?$').hasMatch(part)) {
            isValidSeparator = false;
            break;
          }
        }
        if (!isValidSeparator) break;
      }

      tableLines.add(line);
      if (tableLines.length > 50) break;
    }

    return tableLines;
  }

  bool _containsInlineMath(String text) {
    final hasDollarMath =
        RegExp(r'[^\\]\$[^\$].*?[^\\]\$').hasMatch(text) ||
        RegExp(r'^\$[^\$].*?[^\\]\$').hasMatch(text);
    final hasLatexInline = text.contains(r'\(') && text.contains(r'\)');
    return hasDollarMath || hasLatexInline;
  }

  bool _containsInlineCode(String line) {
    final regex = RegExp(r'`[^`\n]+`');
    return regex.hasMatch(line);
  }

  bool _isImageLine(String line) {
    final markdownImageRegex = RegExp(r'!\[.*?\]\(.*?\)');
    final htmlImageRegex = RegExp(
      r'<img[^>]*src="[^"]+"[^>]*>',
      caseSensitive: false,
    );
    final urlRegex = RegExp(
      r'\.(jpg|jpeg|png|gif|bmp|webp|svg)(\?.*)?$',
      caseSensitive: false,
    );

    return markdownImageRegex.hasMatch(line) ||
        htmlImageRegex.hasMatch(line) ||
        (line.trim().startsWith('http') && urlRegex.hasMatch(line));
  }

  bool _isListItem(String line) {
    final trimmed = line.trim();
    return trimmed.startsWith('- ') ||
        trimmed.startsWith('* ') ||
        trimmed.startsWith('+ ') ||
        RegExp(r'^\d+\.\s').hasMatch(trimmed) ||
        RegExp(r'^[-*+]\s').hasMatch(trimmed);
  }

  List<String> _extractListItems(List<String> lines, int startIndex) {
    final items = <String>[];

    for (int i = startIndex; i < lines.length; i++) {
      if (_isListItem(lines[i])) {
        items.add(lines[i]);
      } else {
        break;
      }
    }

    return items;
  }

  String _extractParagraph(List<String> lines, int startIndex) {
    final paragraphLines = <String>[];
    for (int i = startIndex; i < lines.length; i++) {
      final line = lines[i];
      final trimmed = line.trim();
      if (trimmed.isEmpty) break;

      if (_isListItem(line) ||
          _isTableLine(line) ||
          _containsInlineMath(line) ||
          trimmed.startsWith('#') ||
          trimmed.startsWith(r'$$') ||
          (trimmed.contains(r'\[') && trimmed.contains(r'\]'))) {
        break;
      }
      paragraphLines.add(line);
    }
    return paragraphLines.join('\n');
  }

  bool _isTableLine(String line) {
    return line.contains('|') &&
        line.split('|').where((p) => p.trim().isNotEmpty).length >= 2;
  }

  // ========== WIDGET BUILDERS ==========

  Widget _buildText(String text, {bool isAnswer = false}) {
    if (_containsInlineMath(text)) {
      return _buildInlineMathText(text, isAnswer: isAnswer);
    }

    // Handle bold (**text**) and italic (*text*)
    final regex = RegExp(r'(\*\*.*?\*\*|\*.*?\*|~~.*?~~)');
    final parts = text.split(regex);
    final spans = <InlineSpan>[];

    for (final part in parts) {
      if (part.startsWith('**') && part.endsWith('**')) {
        final content = part.substring(2, part.length - 2);
        spans.add(
          TextSpan(
            text: content,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isAnswer
                  ? const Color(0xFF10B981)
                  : const Color(0xFF333333),
            ),
          ),
        );
      } else if (part.startsWith('*') &&
          part.endsWith('*') &&
          !part.startsWith('**')) {
        final content = part.substring(1, part.length - 1);
        spans.add(
          TextSpan(
            text: content,
            style: TextStyle(
              fontStyle: FontStyle.italic,
              color: isAnswer
                  ? const Color(0xFF10B981)
                  : const Color(0xFF333333),
            ),
          ),
        );
      } else if (part.startsWith('~~') && part.endsWith('~~')) {
        final content = part.substring(2, part.length - 2);
        spans.add(
          TextSpan(
            text: content,
            style: const TextStyle(
              decoration: TextDecoration.lineThrough,
              color: Color(0xFF666666),
            ),
          ),
        );
      } else {
        spans.add(
          TextSpan(
            text: part,
            style: TextStyle(
              fontSize: isAnswer ? 16 : 14,
              color: isAnswer
                  ? const Color(0xFF10B981)
                  : const Color(0xFF666666),
              height: 1.6,
            ),
          ),
        );
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: SelectableText.rich(TextSpan(children: spans)),
    );
  }

  Widget _buildParagraph(String text, {bool isAnswer = false}) {
    if (_containsInlineMath(text)) {
      return _buildInlineMathText(text, isAnswer: isAnswer);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: SelectableText(
        text,
        style: TextStyle(
          fontSize: isAnswer ? 16 : 14,
          color: isAnswer ? const Color(0xFF10B981) : const Color(0xFF666666),
          height: 1.6,
        ),
      ),
    );
  }

  Widget _buildInlineMathText(String text, {bool isAnswer = false}) {
    final regex = RegExp(r'(\\\(.*?\\\)|\$.*?(?<!\\)\$)|([^$\\]+)');
    final matches = regex.allMatches(text);
    final spans = <InlineSpan>[];

    for (final match in matches) {
      final matchedText = match.group(0)!;

      if (matchedText.startsWith(r'\(') && matchedText.endsWith(r'\)')) {
        final mathContent = matchedText.substring(2, matchedText.length - 2);
        spans.add(
          WidgetSpan(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: _buildMathWidget(mathContent, isInline: true),
            ),
          ),
        );
      } else if (matchedText.startsWith('\$') &&
          matchedText.endsWith('\$') &&
          matchedText.length > 2) {
        final mathContent = matchedText.substring(1, matchedText.length - 1);
        spans.add(
          WidgetSpan(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: _buildMathWidget(mathContent, isInline: true),
            ),
          ),
        );
      } else {
        spans.add(
          TextSpan(
            text: matchedText,
            style: TextStyle(
              fontSize: isAnswer ? 16 : 14,
              color: isAnswer
                  ? const Color(0xFF10B981)
                  : const Color(0xFF666666),
              height: 1.6,
            ),
          ),
        );
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: SelectableText.rich(TextSpan(children: spans)),
    );
  }

  Widget _buildMathBlock(String mathContent) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade200, width: 1),
      ),
      child: Center(
        child: _buildMathWidget(mathContent.trim(), isInline: false),
      ),
    );
  }

  Widget _buildMathWidget(String mathContent, {bool isInline = true}) {
    String cleanMath = mathContent;
    cleanMath = cleanMath.replaceAll(r'\over', r'\frac');
    cleanMath = cleanMath.replaceAll(r'\pm', r'\pm');

    return Container(
      padding: EdgeInsets.all(isInline ? 4 : 0),
      child: Math.tex(
        cleanMath,
        textStyle: TextStyle(
          fontSize: isInline ? 14 : 16,
          color: Colors.blue.shade900,
        ),
        onErrorFallback: (FlutterMathException e) {
          print('Math rendering error: $e for expression: $cleanMath');
          String simplifiedMath = mathContent
              .replaceAll(r'\over', '/')
              .replaceAll(r'\pm', '±')
              .replaceAll(r'\sqrt', '√');

          return Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: Colors.orange.shade200),
            ),
            child: SelectableText(
              simplifiedMath,
              style: TextStyle(
                fontFamily: 'RobotoMono',
                color: Colors.orange.shade800,
                fontSize: isInline ? 12 : 14,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCodeBlock(String code, String language) {
    final langMap = {
      'python': 'Python',
      'javascript': 'JavaScript',
      'java': 'Java',
      'cpp': 'C++',
      'c': 'C',
      'html': 'HTML',
      'css': 'CSS',
      'dart': 'Dart',
      'sql': 'SQL',
      'bash': 'Bash',
      'json': 'JSON',
      'yaml': 'YAML',
    };

    final displayLang = langMap[language] ?? language.toUpperCase();

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade700),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey.shade900,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(8),
                topRight: Radius.circular(8),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.code_rounded,
                      size: 18,
                      color: Colors.blue.shade300,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      displayLang,
                      style: TextStyle(
                        color: Colors.blue.shade300,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
                GestureDetector(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: code));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Code copied to clipboard'),
                        backgroundColor: Colors.green,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade800,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.content_copy, size: 14, color: Colors.white),
                        SizedBox(width: 6),
                        Text(
                          'Copy',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Container(
                padding: const EdgeInsets.only(right: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: code.split('\n').asMap().entries.map((entry) {
                    final lineNumber = entry.key + 1;
                    final lineContent = entry.value;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 40,
                            child: Text(
                              lineNumber.toString().padLeft(3, ' '),
                              style: const TextStyle(
                                fontFamily: 'RobotoMono',
                                fontSize: 13,
                                color: Colors.grey,
                              ),
                              textAlign: TextAlign.right,
                            ),
                          ),
                          const SizedBox(width: 16),
                          SelectableText(
                            lineContent,
                            style: const TextStyle(
                              fontFamily: 'RobotoMono',
                              fontSize: 13,
                              color: Color(0xFFD4D4D4),
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInlineCode(String text) {
    final regex = RegExp(r'`([^`]+)`');
    final matches = regex.allMatches(text);

    if (matches.isEmpty) {
      return _buildText(text);
    }

    final spans = <TextSpan>[];
    int lastIndex = 0;

    for (final match in matches) {
      if (match.start > lastIndex) {
        spans.add(
          TextSpan(
            text: text.substring(lastIndex, match.start),
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF666666),
              height: 1.6,
            ),
          ),
        );
      }

      spans.add(
        TextSpan(
          text: match.group(1),
          style: TextStyle(
            backgroundColor: Colors.grey.shade200,
            color: Colors.red.shade700,
            fontFamily: 'RobotoMono',
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      );

      lastIndex = match.end;
    }

    if (lastIndex < text.length) {
      spans.add(
        TextSpan(
          text: text.substring(lastIndex),
          style: const TextStyle(
            fontSize: 14,
            color: Color(0xFF666666),
            height: 1.6,
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: SelectableText.rich(TextSpan(children: spans)),
    );
  }

  Widget _buildImage(String line) {
    try {
      String imageUrl = '';
      String altText = '';

      final markdownRegex = RegExp(r'!\[(.*?)\]\((.*?)\)');
      final markdownMatch = markdownRegex.firstMatch(line);

      if (markdownMatch != null) {
        altText = markdownMatch.group(1) ?? '';
        imageUrl = markdownMatch.group(2) ?? '';
        print('🖼️ Parsed markdown image: URL=$imageUrl, Alt=$altText');
      } else {
        final urlRegex = RegExp(r'https?://[^\s]+');
        final urlMatch = urlRegex.firstMatch(line);
        if (urlMatch != null) {
          imageUrl = urlMatch.group(0) ?? '';
          print('🖼️ Parsed direct URL image: $imageUrl');
        }
      }

      if (imageUrl.isNotEmpty) {
        // Check if it's a Hive-stored image (for web offline)
        if (imageUrl.startsWith('hive://')) {
          final imageKey = imageUrl.replaceFirst('hive://', '');
          print('🖼️ Loading Hive image with key: $imageKey');

          return FutureBuilder<Uint8List?>(
            future: _loadHiveImage(imageKey),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Container(
                  height: 200,
                  color: Colors.grey.shade100,
                  child: const Center(child: CircularProgressIndicator()),
                );
              } else if (snapshot.hasError || snapshot.data == null) {
                print('❌ Failed to load Hive image: ${snapshot.error}');
                return _buildErrorImage('Hive image load failed');
              } else {
                return Container(
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  child: Column(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.memory(
                          snapshot.data!,
                          fit: BoxFit.contain,
                        ),
                      ),
                      if (altText.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            altText,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF666666),
                              fontStyle: FontStyle.italic,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                    ],
                  ),
                );
              }
            },
          );
        }
        // Check if it's a local file path (for mobile/desktop offline)
        else if (imageUrl.startsWith('/') && !imageUrl.startsWith('http')) {
          print('🖼️ Loading local file image: $imageUrl');

          return Container(
            margin: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.file(
                    File(imageUrl),
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      print('❌ Error loading local image: $error');
                      return _buildErrorImage('Local image load failed');
                    },
                  ),
                ),
                if (altText.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      altText,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF666666),
                        fontStyle: FontStyle.italic,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
              ],
            ),
          );
        }
        // It's a network URL
        else {
          // Clean up the URL first
          String cleanUrl = imageUrl.replaceAll(RegExp(r'(?<!:)/{2,}'), '/');

          print('🖼️ Loading network image: $cleanUrl');

          return Container(
            margin: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: CachedNetworkImage(
                    imageUrl: cleanUrl,
                    placeholder: (context, url) => Container(
                      height: 200,
                      color: Colors.grey.shade100,
                      child: const Center(child: CircularProgressIndicator()),
                    ),
                    errorWidget: (context, url, error) {
                      print('❌ Error loading network image: $error, URL: $url');
                      return _buildErrorImage('Network image load failed');
                    },
                    fit: BoxFit.contain,
                  ),
                ),
                if (altText.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      altText,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF666666),
                        fontStyle: FontStyle.italic,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
              ],
            ),
          );
        }
      }
    } catch (e) {
      print('❌ Error in _buildImage: $e');
      print('   Line: $line');
    }

    return const SizedBox.shrink();
  }

  Widget _buildErrorImage(String message) {
    return Container(
      height: 200,
      color: Colors.grey.shade100,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.broken_image, size: 40, color: Colors.grey),
          const SizedBox(height: 8),
          Text(
            message,
            style: const TextStyle(fontSize: 12, color: Colors.grey),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildHeading(String line) {
    final trimmed = line.trim();
    int level = 0;

    for (int i = 0; i < trimmed.length && i < 6; i++) {
      if (trimmed[i] == '#') {
        level++;
      } else {
        break;
      }
    }

    final text = trimmed.substring(level).trim();

    double fontSize;
    FontWeight fontWeight;
    Color color;
    EdgeInsets padding;

    switch (level) {
      case 1:
        fontSize = 20;
        fontWeight = FontWeight.bold;
        color = const Color(0xFF333333);
        padding = const EdgeInsets.only(top: 16, bottom: 8);
        break;
      case 2:
        fontSize = 18;
        fontWeight = FontWeight.bold;
        color = const Color(0xFF333333);
        padding = const EdgeInsets.only(top: 14, bottom: 6);
        break;
      case 3:
        fontSize = 16;
        fontWeight = FontWeight.w600;
        color = const Color(0xFF444444);
        padding = const EdgeInsets.only(top: 12, bottom: 4);
        break;
      default:
        fontSize = 14;
        fontWeight = FontWeight.w600;
        color = const Color(0xFF666666);
        padding = const EdgeInsets.only(top: 8, bottom: 2);
    }

    return Padding(
      padding: padding,
      child: SelectableText(
        text,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: fontWeight,
          color: color,
        ),
      ),
    );
  }

  Widget _buildList(List<String> items) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: items.map((item) {
          final trimmed = item.trim();
          bool isNumbered = RegExp(r'^\d+\.\s').hasMatch(trimmed);
          final text = isNumbered
              ? trimmed.replaceFirst(RegExp(r'^\d+\.\s'), '')
              : trimmed.substring(2);

          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 5, right: 12),
                  child: isNumbered
                      ? Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            color: Colors.blue.shade100,
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              trimmed.split('.')[0],
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue,
                              ),
                            ),
                          ),
                        )
                      : Container(
                          width: 6,
                          height: 6,
                          margin: const EdgeInsets.only(top: 8),
                          decoration: const BoxDecoration(
                            color: Color(0xFF666666),
                            shape: BoxShape.circle,
                          ),
                        ),
                ),
                Expanded(child: _buildText(text)),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildMarkdownTable(String tableMarkdown) {
    try {
      final lines = tableMarkdown.trim().split('\n');
      if (lines.length < 2) return Container();

      // Parse header
      final headerRow = lines[0];
      final headers = _parseTableRow(headerRow);

      // Parse data rows
      final dataRows = <List<Widget>>[];
      for (int i = 2; i < lines.length; i++) {
        if (lines[i].trim().isNotEmpty) {
          final cells = _parseTableRow(lines[i]);
          final cellWidgets = cells.map((cell) {
            return Container(
              constraints: const BoxConstraints(maxWidth: 150),
              child: _buildTableCellContent(cell),
            );
          }).toList();
          dataRows.add(cellWidgets);
        }
      }

      return Container(
        margin: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(8),
        ),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Container(
            constraints: BoxConstraints(minWidth: headers.length * 150),
            child: DataTable(
              columnSpacing: 24,
              horizontalMargin: 16,
              headingRowColor: MaterialStateProperty.all(Colors.blue.shade50),
              dataRowColor: MaterialStateProperty.all(Colors.white),
              columns: headers.map((header) {
                return DataColumn(
                  label: Container(
                    constraints: const BoxConstraints(maxWidth: 150),
                    child: _buildTableCellContent(header, isHeader: true),
                  ),
                );
              }).toList(),
              rows: dataRows.map((rowCells) {
                return DataRow(
                  cells: rowCells.map((cellWidget) {
                    return DataCell(
                      Container(
                        constraints: const BoxConstraints(maxWidth: 150),
                        child: cellWidget,
                      ),
                    );
                  }).toList(),
                );
              }).toList(),
            ),
          ),
        ),
      );
    } catch (e) {
      print('Error rendering table: $e');
      return Container(
        padding: const EdgeInsets.all(16),
        color: Colors.red.shade50,
        child: Text('Error rendering table: $e'),
      );
    }
  }

  List<String> _parseTableRow(String row) {
    final cleanRow = row.trim().replaceAll(RegExp(r'^\||\|$'), '');
    return cleanRow.split('|').map((cell) => cell.trim()).toList();
  }

  String _convertHtmlTablesToMarkdown(String html) {
    String result = html;

    final tableRegex = RegExp(
      r'<table[^>]*>(.*?)</table>',
      caseSensitive: false,
      dotAll: true,
    );

    result = result.replaceAllMapped(tableRegex, (tableMatch) {
      String tableHtml = tableMatch.group(1) ?? '';
      List<List<String>> rows = [];

      final rowRegex = RegExp(
        r'<tr[^>]*>(.*?)</tr>',
        caseSensitive: false,
        dotAll: true,
      );
      final rowMatches = rowRegex.allMatches(tableHtml);

      for (final rowMatch in rowMatches) {
        String rowHtml = rowMatch.group(1) ?? '';
        List<String> cells = [];

        final cellRegex = RegExp(
          r'<(th|td)[^>]*>(.*?)</\1>',
          caseSensitive: false,
          dotAll: true,
        );
        final cellMatches = cellRegex.allMatches(rowHtml);

        for (final cellMatch in cellMatches) {
          String cellContent = cellMatch.group(2) ?? '';
          cellContent = _preserveMathInCell(cellContent);
          cellContent = _cleanHtmlText(cellContent);
          cells.add(cellContent);
        }

        if (cells.isNotEmpty) {
          rows.add(cells);
        }
      }

      if (rows.isEmpty) return '';

      final markdownTable = _rowsToMarkdownTable(rows);
      return '\n\n$markdownTable\n\n';
    });

    return result;
  }

  String _preserveMathInCell(String cellContent) {
    String result = cellContent;

    result = result.replaceAllMapped(RegExp(r'\\\((.*?)\\\)', dotAll: true), (
      match,
    ) {
      final mathContent = match.group(1) ?? '';
      return '\$$mathContent\$';
    });

    result = result.replaceAllMapped(RegExp(r'\\\[(.*?)\\\]', dotAll: true), (
      match,
    ) {
      final mathContent = match.group(1) ?? '';
      return '\$\$$mathContent\$\$';
    });

    result = result
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>');

    return result;
  }

  String _rowsToMarkdownTable(List<List<String>> rows) {
    if (rows.isEmpty) return '';

    final List<String> markdownRows = [];
    final int columnCount = rows[0].length;

    markdownRows.add('| ${rows[0].join(' | ')} |');

    final separator =
        '|' + List<String>.generate(columnCount, (_) => '---').join('|') + '|';
    markdownRows.add(separator);

    for (int i = 1; i < rows.length; i++) {
      final row = rows[i];
      final paddedRow = List<String>.from(row);
      while (paddedRow.length < columnCount) {
        paddedRow.add('');
      }
      while (paddedRow.length > columnCount) {
        paddedRow.removeLast();
      }
      markdownRows.add('| ${paddedRow.join(' | ')} |');
    }

    return markdownRows.join('\n');
  }

  Widget _buildTableCellContent(String cellContent, {bool isHeader = false}) {
    if (_containsMath(cellContent)) {
      return Container(
        constraints: const BoxConstraints(maxWidth: 150),
        child: _buildTableCellWithMath(cellContent, isHeader: isHeader),
      );
    }

    return Container(
      constraints: const BoxConstraints(maxWidth: 200),
      child: Text(
        cellContent,
        style: TextStyle(
          fontWeight: isHeader ? FontWeight.bold : FontWeight.normal,
          fontSize: isHeader ? 14 : 13,
        ),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _buildTableCellWithMath(String cellContent, {bool isHeader = false}) {
    final regex = RegExp(r'(\$.*?(?<!\\)\$)|([^$]+)');
    final matches = regex.allMatches(cellContent);
    final textSpans = <InlineSpan>[];

    for (final match in matches) {
      final matchedText = match.group(0)!;

      if (matchedText.startsWith('\$') && matchedText.endsWith('\$')) {
        final mathContent = matchedText.substring(1, matchedText.length - 1);
        textSpans.add(
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: _buildTableCellMathWidget(mathContent),
            ),
          ),
        );
      } else {
        textSpans.add(
          TextSpan(
            text: matchedText,
            style: TextStyle(
              fontWeight: isHeader ? FontWeight.bold : FontWeight.normal,
              fontSize: isHeader ? 14 : 13,
            ),
          ),
        );
      }
    }

    return RichText(
      text: TextSpan(
        children: textSpans,
        style: TextStyle(fontSize: isHeader ? 14 : 13, color: Colors.black87),
      ),
    );
  }

  Widget _buildTableCellMathWidget(String mathContent) {
    return Container(
      padding: const EdgeInsets.all(2),
      child: Math.tex(
        mathContent,
        textStyle: const TextStyle(fontSize: 12),
        onErrorFallback: (FlutterMathException e) {
          return Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(2),
              border: Border.all(color: Colors.orange.shade200),
            ),
            child: Text(
              mathContent,
              style: TextStyle(
                fontFamily: 'RobotoMono',
                fontSize: 10,
                color: Colors.orange.shade800,
              ),
            ),
          );
        },
      ),
    );
  }

  bool _containsMath(String line) {
    return line.contains(r'$') ||
        line.contains(r'\(') ||
        line.contains(r'\[') ||
        line.contains(r'$$');
  }

  String _cleanHtmlText(String text) {
    return text.replaceAll(RegExp(r'<[^>]*>'), '').replaceAll('\n', ' ').trim();
  }

  String _decodeHtmlEntities(String text) {
    return text
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&ldquo;', '"')
        .replaceAll('&rdquo;', '"')
        .replaceAll('&lsquo;', "'")
        .replaceAll('&rsquo;', "'")
        .replaceAll('&hellip;', '...')
        .replaceAll('&mdash;', '—')
        .replaceAll('&ndash;', '–')
        .replaceAll('&copy;', '©')
        .replaceAll('&reg;', '®')
        .replaceAll('&trade;', '™')
        .replaceAll('&times;', '×')
        .replaceAll('&divide;', '÷')
        .replaceAll('&plusmn;', '±');
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
                // Question number
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
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

                // Flag count badge (if any)
                if (_flagCounts[index] > 0) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.flag,
                          size: 10,
                          color: Colors.orange.shade700,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          '${_flagCounts[index]}',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.orange.shade700,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const Spacer(),

                // Bookmark button
                IconButton(
                  icon: Icon(
                    _isBookmarked[index]
                        ? Icons.bookmark_rounded
                        : Icons.bookmark_border_rounded,
                    color: _isBookmarked[index]
                        ? const Color(0xFFF59E0B)
                        : Colors.grey.shade400,
                    size: 20,
                  ),
                  onPressed: () => _toggleBookmark(index),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  iconSize: 20,
                ),
                const SizedBox(width: 8),

                // Flag button with toggle functionality
                GestureDetector(
                  onTap: () => _toggleFlagQuestion(index),
                  onLongPress: () => _showFlagOptions(index),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: _isFlagged[index]
                          ? const Color(0xFF8B5CF6).withOpacity(0.1)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _isFlagged[index]
                            ? const Color(0xFF8B5CF6)
                            : Colors.grey.shade300,
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _isFlagged[index]
                              ? Icons.flag_rounded
                              : Icons.outlined_flag_rounded,
                          color: _isFlagged[index]
                              ? const Color(0xFF8B5CF6)
                              : Colors.grey.shade600,
                          size: 16,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle image-only questions specially
                if (question.isImageOnlyQuestion)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Label for image-only questions
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.blue.shade200),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.image,
                              size: 14,
                              color: Colors.blue.shade700,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Image Question',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.blue.shade700,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Question Image (for image-only questions, show first)
                      if (question.questionImageUrl != null &&
                          question.questionImageUrl!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _buildQuestionImage(question),
                        ),
                    ],
                  )
                else
                  // Regular questions with text first
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Question Text with full formatting
                      if (question.questionText != null &&
                          question.questionText!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _buildFormattedContent(
                            question.questionText!,
                            isAnswer: false,
                          ),
                        ),

                      // Question Image
                      if (question.questionImageUrl != null &&
                          question.questionImageUrl!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _buildQuestionImage(question),
                        ),
                    ],
                  ),

                // Options with full formatting
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
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 20,
                                height: 20,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.grey.shade300,
                                  ),
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
                              const SizedBox(width: 10),
                              Expanded(
                                child: _buildFormattedContent(
                                  option.value,
                                  isAnswer: false,
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
                        Icon(
                          Icons.short_text_rounded,
                          size: 16,
                          color: Color(0xFF6B7280),
                        ),
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

                // Action Buttons
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
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            icon: const Icon(
                              Icons.visibility_rounded,
                              size: 14,
                            ),
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
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            icon: Icon(
                              _showSolution[index]
                                  ? Icons.visibility_off_rounded
                                  : Icons.lightbulb_rounded,
                              size: 14,
                            ),
                            label: Text(
                              _showSolution[index]
                                  ? 'Hide Solution'
                                  : 'Solution',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => _askAI(index),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF10B981),
                          side: const BorderSide(color: Color(0xFF10B981)),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
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

                // Solution Section with full formatting
                if (_showSolution[index]) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF59E0B).withOpacity(0.05),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: const Color(0xFFF59E0B).withOpacity(0.2),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(
                              Icons.lightbulb_rounded,
                              color: Color(0xFFF59E0B),
                              size: 16,
                            ),
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

                        // Solution Text with full formatting
                        if (question.solutionText != null &&
                            question.solutionText!.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: _buildFormattedContent(
                              question.solutionText!,
                              isAnswer: false,
                            ),
                          ),

                        // Solution Image
                        if (question.solutionImageUrl != null &&
                            question.solutionImageUrl!.isNotEmpty)
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

  Widget _buildQuestionImage(TestQuestion question) {
    final imageUrl = question.questionImageUrl!;

    // Check if it's a local path (offline)
    final isLocalPath =
        imageUrl.startsWith('/') ||
        imageUrl.startsWith('hive://') ||
        (imageUrl.contains(
              RegExp(r'\.(jpg|jpeg|png|gif|bmp|webp)$', caseSensitive: false),
            ) &&
            !imageUrl.startsWith('http'));

    if (isLocalPath) {
      if (imageUrl.startsWith('hive://')) {
        final imageKey = imageUrl.replaceFirst('hive://', '');
        return FutureBuilder<Uint8List?>(
          future: _loadHiveImage(imageKey),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Container(
                height: 200,
                color: Colors.grey.shade100,
                child: const Center(child: CircularProgressIndicator()),
              );
            } else if (snapshot.hasError || snapshot.data == null) {
              return _buildErrorImage('Failed to load offline image');
            } else {
              return ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.memory(snapshot.data!, fit: BoxFit.contain),
              );
            }
          },
        );
      } else {
        // Local file
        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.file(
            File(imageUrl),
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) {
              return _buildErrorImage('Failed to load local image');
            },
          ),
        );
      }
    } else {
      // Network URL - clean it first
      String cleanUrl = imageUrl.replaceAll(RegExp(r'(?<!:)/{2,}'), '/');

      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: CachedNetworkImage(
          imageUrl: cleanUrl,
          placeholder: (context, url) => Container(
            height: 200,
            color: Colors.grey.shade100,
            child: const Center(child: CircularProgressIndicator()),
          ),
          errorWidget: (context, url, error) {
            return _buildErrorImage('Failed to load image');
          },
          fit: BoxFit.contain,
        ),
      );
    }
  }

  // Add this method for long press to show reason options
  void _showFlagOptions(int index) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Flag Reason',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 16),

              // Flag count badge
              if (_flagCounts[index] > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.flag, size: 14, color: Colors.orange),
                      const SizedBox(width: 6),
                      Text(
                        '${_flagCounts[index]} flag${_flagCounts[index] > 1 ? 's' : ''}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.orange.shade800,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),

              // Reason options
              ...[
                'Incorrect question',
                'Wrong answer',
                'Poor formatting',
                'Other issue',
              ].map((reason) {
                return ListTile(
                  leading: Icon(Icons.flag, color: const Color(0xFF8B5CF6)),
                  title: Text(reason),
                  onTap: () {
                    Navigator.pop(context);
                    _flagQuestion(
                      index,
                      reason.toLowerCase().replaceAll(' ', '_'),
                      description: 'Flagged: $reason',
                    );
                  },
                );
              }).toList(),

              // Cancel option
              ListTile(
                leading: const Icon(Icons.close, color: Colors.grey),
                title: const Text(
                  'Cancel',
                  style: TextStyle(color: Colors.grey),
                ),
                onTap: () => Navigator.pop(context),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<Uint8List?> _loadHiveImage(String imageKey) async {
    try {
      print('🔍 Loading Hive image with key: $imageKey');
      final imageBox = await Hive.openBox('offline_images');
      final imageData = imageBox.get(imageKey);

      if (imageData == null) {
        print('❌ No image found in Hive for key: $imageKey');
        return null;
      }

      if (imageData['data'] == null) {
        print('❌ Image data is null for key: $imageKey');
        return null;
      }

      try {
        final bytes = Uint8List.fromList(List<int>.from(imageData['data']));
        print('✅ Successfully loaded Hive image (${bytes.length} bytes)');
        return bytes;
      } catch (e) {
        print('❌ Error converting Hive image data: $e');
        return null;
      }
    } catch (e) {
      print('❌ Error loading Hive image: $e');
      return null;
    }
  }
  // ========== OTHER BUILDER METHODS ==========

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          const Text(
            'Loading questions...',
            style: TextStyle(color: Color(0xFF6B7280), fontSize: 14),
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
                style: const TextStyle(color: Color(0xFF6B7280), fontSize: 14),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _loadQuestions,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6366F1),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
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
              _isEmptyTopic
                  ? Icons.folder_off_rounded
                  : _isOffline
                  ? Icons.wifi_off_rounded
                  : Icons.quiz_outlined,
              size: 64,
              color: const Color(0xFF6B7280).withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              _isOffline
                  ? 'No Offline Questions'
                  : _isEmptyTopic
                  ? 'No Questions in This Topic'
                  : 'No Questions Found',
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
                _isOffline
                    ? 'You are offline and no downloaded questions found for this course. Please download questions when online.'
                    : _isEmptyTopic
                    ? 'The topic "${widget.topicName ?? 'Selected Topic'}" doesn\'t have any test questions yet.\n\nTry selecting another topic or enable Random Mode to get questions from all topics.'
                    : 'No test questions found for the selected filters.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF6B7280),
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
            ),

            // Add activation message for non-activated users with questions
            if (!_isUserActivated && _questions.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(top: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.lock_outline_rounded,
                      size: 16,
                      color: Colors.orange.shade700,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Only $_maxQuestionsForNonActivated questions shown. Activate account to see all questions.',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.orange.shade800,
                        ),
                      ),
                    ),
                  ],
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text('Go Back'),
                ),
                if (_isEmptyTopic && !_isOffline) const SizedBox(width: 12),
                if (_isEmptyTopic && !_isOffline)
                  ElevatedButton(
                    onPressed: _loadQuestions,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
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
              'Test Questions',
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
          // Activation status indicator
          if (_checkingActivation)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: _isUserActivated ? Colors.green : Colors.orange,
                ),
              ),
            ),
          if (!_checkingActivation && !_isUserActivated)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.orange.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.lock_outline_rounded,
                      size: 14,
                      color: Colors.orange.shade700,
                    ),
                    const SizedBox(width: 4),
                    const Text(
                      'Limited',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.orange,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (_isOffline)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              margin: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: const [
                  Icon(Icons.wifi_off_rounded, size: 14, color: Colors.orange),
                  SizedBox(width: 4),
                  Text(
                    'Offline',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.orange,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
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
          : Column(
              children: [
                // Show activation banner if user is not activated
                if (!_isUserActivated && !_checkingActivation)
                  _buildActivationBanner(),

                // Show limited access message if user is not activated
                if (!_isUserActivated &&
                    _questions.length <= _maxQuestionsForNonActivated)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    color: Colors.orange.shade50,
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline_rounded,
                          size: 16,
                          color: Colors.orange.shade700,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Showing $_maxQuestionsForNonActivated of ${widget.randomMode ? 'many' : 'all'} questions. Activate account to see more.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.orange.shade800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _questions.length,
                    itemBuilder: (context, index) => _buildQuestionCard(index),
                  ),
                ),
              ],
            ),
    );
  }
}
