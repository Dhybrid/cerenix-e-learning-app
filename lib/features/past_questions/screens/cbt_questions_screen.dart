// lib/features/cbt/screens/cbt_questions_screen.dart
import 'dart:io';
import 'dart:math';
import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import '../../../core/network/api_service.dart';
import '../../../core/constants/endpoints.dart';
import '../../past_questions/models/past_question_models.dart';

class CBTQuestionsScreen extends StatefulWidget {
  final String courseId;
  final String courseName;
  final String? sessionId;
  final String sessionName;
  final String? topicId;
  final String? topicName;
  final bool randomMode;
  final bool enableTimer;
  final bool isOffline;

  const CBTQuestionsScreen({
    super.key,
    required this.courseId,
    required this.courseName,
    this.sessionId,
    required this.sessionName,
    this.topicId,
    this.topicName,
    required this.randomMode,
    required this.enableTimer,
    required this.isOffline,
  });

  @override
  State<CBTQuestionsScreen> createState() => _CBTQuestionsScreenState();
}

class _CBTQuestionsScreenState extends State<CBTQuestionsScreen> {
  final ApiService _apiService = ApiService();

  List<PastQuestion> _questions = [];
  List<String?> _userAnswers = [];
  List<bool> _isBookmarked = [];
  List<bool> _isFlagged = [];
  List<int> _flagCounts = [];
  bool _isLoading = true;
  bool _showResults = false;
  bool _showCorrections = false;
  int _currentQuestionIndex = 0;
  bool _showQuestionPicker = false;

  // ========== ACTIVATION STATE ==========
  bool _isUserActivated = false;
  bool _checkingActivation = false;
  String _activationStatusMessage = 'Checking activation status...';
  int _maxQuestionsForNonActivated =
      2; // Show only 2 questions for non-activated users
  // ========== END ACTIVATION STATE ==========

  // Timer variables
  Duration _timerDuration = const Duration(minutes: 30);
  late Timer _timer;
  Duration _timeUsed = Duration.zero;
  DateTime? _startTime;

  // Scroll controller to prevent auto-scroll to top
  final ScrollController _scrollController = ScrollController();

  // Image cache to prevent reloading - FIXED VERSION
  final Map<String, ImageProvider> _imageProviderCache = {};
  final Map<String, bool> _imageLoadingState = {};

  @override
  void initState() {
    super.initState();
    _loadInitialData();
    // _loadQuestions();
  }

  Future<void> _loadInitialData() async {
    await _checkActivationStatus(forceRefresh: true);
    await _loadQuestions();

    // Listen for activation changes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // You could set up a listener for activation changes here
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    _scrollController.dispose();
    _imageProviderCache.clear();
    _imageLoadingState.clear();
    super.dispose();
  }

  // Handle activation when returning from activation screen
  void _onActivationChanged() async {
    await _checkActivationStatus(forceRefresh: true);

    // Reload questions with new activation status
    if (mounted) {
      await _loadQuestions();
    }
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
            print('✅ CBT: Using cached activation status: $_isUserActivated');
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
          print('✅ CBT: User is activated: ${activationData.grade}');
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
          print('ℹ️ CBT: User is not activated');
        }
      } catch (e) {
        print('❌ CBT: Error fetching activation from API: $e');

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
      print('❌ CBT: Error in activation check: $e');
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

  // Future<void> _loadQuestions() async {
  //   if (!mounted) return;

  //   setState(() => _isLoading = true);

  //   try {
  //     print('📥 CBT: Loading questions...');

  //     // For CBT, we always use offline mode
  //     List<PastQuestion> offlineQuestions =
  //         await _loadQuestionsFromOfflineStorage();
  //     offlineQuestions = _filterOfflineQuestions(offlineQuestions);

  //     if (offlineQuestions.isEmpty) {
  //       throw Exception('No questions found in downloaded courses');
  //     }

  //     // Shuffle if random mode
  //     if (widget.randomMode) offlineQuestions.shuffle();

  //     // Limit to first 50 questions for CBT
  //     final maxQuestions = 50;
  //     if (offlineQuestions.length > maxQuestions) {
  //       offlineQuestions = offlineQuestions.sublist(0, maxQuestions);
  //     }

  //     // Load flag status if online
  //     if (await _isOnline()) {
  //       await _loadFlagStatus(offlineQuestions);
  //     }

  //     setState(() {
  //       _questions = offlineQuestions;
  //       _userAnswers = List.generate(offlineQuestions.length, (index) => null);
  //       _isBookmarked = List.generate(
  //         offlineQuestions.length,
  //         (index) => false,
  //       );
  //       _isFlagged = List.generate(offlineQuestions.length, (index) => false);
  //       _flagCounts = List.generate(offlineQuestions.length, (index) => 0);
  //       _isLoading = false;
  //     });

  //     // Start timer after questions are loaded
  //     WidgetsBinding.instance.addPostFrameCallback((_) {
  //       _startTime = DateTime.now();
  //       if (widget.enableTimer) {
  //         _startTimer();
  //       } else {
  //         _startStopwatch();
  //       }
  //     });
  //   } catch (e) {
  //     print('❌ CBT: Error loading questions: $e');

  //     if (!mounted) return;

  //     setState(() => _isLoading = false);

  //     ScaffoldMessenger.of(context).showSnackBar(
  //       SnackBar(
  //         content: Text(
  //           'Failed to load questions: ${e.toString().split(':').first}',
  //         ),
  //         backgroundColor: Colors.red,
  //         duration: const Duration(seconds: 3),
  //       ),
  //     );
  //   }
  // }

  Future<void> _loadQuestions() async {
    if (!mounted) return;

    setState(() => _isLoading = true);

    try {
      print('📥 CBT: Loading questions...');

      // For CBT, we always use offline mode
      List<PastQuestion> offlineQuestions =
          await _loadQuestionsFromOfflineStorage();
      offlineQuestions = _filterOfflineQuestions(offlineQuestions);

      if (offlineQuestions.isEmpty) {
        throw Exception('No questions found in downloaded courses');
      }

      // Shuffle if random mode
      if (widget.randomMode) offlineQuestions.shuffle();

      // Limit questions for non-activated users
      List<PastQuestion> displayQuestions = List.from(offlineQuestions);

      if (!_isUserActivated) {
        print(
          '🔒 CBT: User not activated - limiting to $_maxQuestionsForNonActivated questions',
        );

        // Limit to max questions OR total available (whichever is smaller)
        final limit = min(
          _maxQuestionsForNonActivated,
          displayQuestions.length,
        );
        displayQuestions = displayQuestions.sublist(0, limit);
      } else {
        // For activated users, limit to first 50 questions for CBT
        final maxQuestions = 50;
        if (displayQuestions.length > maxQuestions) {
          displayQuestions = displayQuestions.sublist(0, maxQuestions);
        }
      }

      // Load flag status if online
      if (await _isOnline()) {
        await _loadFlagStatus(displayQuestions);
      }

      setState(() {
        _questions = displayQuestions;
        _userAnswers = List.generate(displayQuestions.length, (index) => null);
        _isBookmarked = List.generate(
          displayQuestions.length,
          (index) => false,
        );
        _isFlagged = List.generate(displayQuestions.length, (index) => false);
        _flagCounts = List.generate(displayQuestions.length, (index) => 0);
        _isLoading = false;
      });

      // Start timer after questions are loaded
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _startTime = DateTime.now();
        if (widget.enableTimer) {
          _startTimer();
        } else {
          _startStopwatch();
        }
      });
    } catch (e) {
      print('❌ CBT: Error loading questions: $e');

      if (!mounted) return;

      setState(() => _isLoading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to load questions: ${e.toString().split(':').first}',
          ),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
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
                    'Only $_maxQuestionsForNonActivated questions are available. Tap to activate and unlock all past questions.',
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

  Future<List<PastQuestion>> _loadQuestionsFromOfflineStorage() async {
    try {
      final offlineBox = await Hive.openBox('offline_courses');

      // First check if course is downloaded
      final downloadedCourseIds = offlineBox.get(
        'downloaded_course_ids',
        defaultValue: <String>[],
      );

      if (!downloadedCourseIds.contains(widget.courseId)) {
        return [];
      }

      final courseData = offlineBox.get('course_${widget.courseId}');
      if (courseData == null) return [];

      // Combine past questions and test questions for CBT
      final List<dynamic> allQuestions = [];

      // Add past questions
      if (courseData['past_questions'] != null) {
        final pastQuestions = courseData['past_questions'] as List;
        allQuestions.addAll(pastQuestions);
      }

      // Add test questions
      if (courseData['test_questions'] != null) {
        final testQuestions = courseData['test_questions'] as List;
        allQuestions.addAll(testQuestions);
      }

      if (allQuestions.isEmpty) return [];

      final List<PastQuestion> questions = [];

      for (var questionData in allQuestions) {
        try {
          Map<String, dynamic> qMap = {};

          if (questionData is Map) {
            questionData.forEach((key, value) {
              if (key is String)
                qMap[key] = value;
              else if (key is int || key is double)
                qMap[key.toString()] = value;
            });
          }

          // Fix session info if missing
          if (qMap['session_info'] == null ||
              (qMap['session_info'] is Map && qMap['session_info'].isEmpty)) {
            if (qMap['session_id'] != null &&
                qMap['session_id'].toString().isNotEmpty) {
              qMap['session_info'] = {
                'id': qMap['session_id'].toString(),
                'name': 'Session ${qMap['session_id']}',
                'is_active': true,
              };
            }
          }

          // Check for local images
          if (courseData.containsKey('downloaded_images')) {
            final downloadedImages = courseData['downloaded_images'];
            if (downloadedImages is Map) {
              final imagesMap = <String, Map<String, dynamic>>{};
              downloadedImages.forEach((key, value) {
                if (key is String && value is Map) {
                  final imageInfo = <String, dynamic>{};
                  value.forEach((k, v) {
                    if (k is String)
                      imageInfo[k] = v;
                    else if (k is int || k is double)
                      imageInfo[k.toString()] = v;
                  });
                  imagesMap[key] = imageInfo;
                }
              });

              // Question image
              final questionImageKey = 'past_question_${qMap['id']}';
              if (imagesMap.containsKey(questionImageKey)) {
                final localPath =
                    imagesMap[questionImageKey]?['path'] as String?;
                if (localPath != null && localPath.isNotEmpty) {
                  qMap['question_image_url'] = localPath;
                }
              }

              // Solution image
              final solutionImageKey = 'past_question_solution_${qMap['id']}';
              if (imagesMap.containsKey(solutionImageKey)) {
                final localPath =
                    imagesMap[solutionImageKey]?['path'] as String?;
                if (localPath != null && localPath.isNotEmpty) {
                  qMap['solution_image_url'] = localPath;
                }
              }
            }
          }

          questions.add(PastQuestion.fromJson(qMap));
        } catch (e) {
          continue;
        }
      }

      return questions;
    } catch (e) {
      return [];
    }
  }

  List<PastQuestion> _filterOfflineQuestions(List<PastQuestion> questions) {
    if (questions.isEmpty) return [];

    List<PastQuestion> filtered = List.from(questions);

    // Filter by session if specified and not "All Sessions"
    if (widget.sessionId != null &&
        widget.sessionId!.isNotEmpty &&
        widget.sessionName != 'All Sessions') {
      filtered = filtered.where((question) {
        String? questionSessionId;

        if (question.sessionInfo.isNotEmpty) {
          if (question.sessionInfo['id'] != null) {
            questionSessionId = question.sessionInfo['id']?.toString();
          } else if (question.sessionInfo['session_id'] != null) {
            questionSessionId = question.sessionInfo['session_id']?.toString();
          }
        }

        if (questionSessionId == null || questionSessionId.isEmpty) {
          questionSessionId = question.sessionId;
        }

        if (questionSessionId == null || questionSessionId.isEmpty) {
          return widget.sessionId == null || widget.sessionId!.isEmpty;
        }

        return questionSessionId == widget.sessionId;
      }).toList();
    }

    // Filter by topic if specified
    if (widget.topicId != null && widget.topicId!.isNotEmpty) {
      filtered = filtered.where((question) {
        String? questionTopicId;

        if (question.topicInfo != null &&
            question.topicInfo is Map &&
            question.topicInfo!.isNotEmpty) {
          if (question.topicInfo!['id'] != null) {
            questionTopicId = question.topicInfo!['id']?.toString();
          }
        }

        if ((questionTopicId == null || questionTopicId.isEmpty) &&
            question.topicId != null) {
          questionTopicId = question.topicId;
        }

        if (questionTopicId == null || questionTopicId.isEmpty) {
          return widget.topicId!.isEmpty;
        }

        return questionTopicId == widget.topicId;
      }).toList();
    }

    return filtered;
  }

  Future<bool> _isOnline() async {
    try {
      final connectivityResult = await Connectivity().checkConnectivity();
      return connectivityResult != ConnectivityResult.none;
    } catch (e) {
      return false;
    }
  }

  Future<void> _loadFlagStatus(List<PastQuestion> questions) async {
    try {
      if (!await _isOnline()) return;

      for (int i = 0; i < questions.length; i++) {
        try {
          final flagStatus = await _apiService.getQuestionFlagStatus(
            questionId: questions[i].id,
          );

          if (mounted) {
            setState(() {
              if (i < _isFlagged.length) {
                _isFlagged[i] = flagStatus['is_flagged'] == true;
              }
              if (i < _flagCounts.length) {
                _flagCounts[i] = (flagStatus['total_flags'] as int?) ?? 0;
              }
            });
          }
        } catch (e) {
          // Silently fail for flag status
        }
      }
    } catch (e) {
      print('⚠️ CBT: Error loading flag status: $e');
    }
  }

  // ========== TIMER METHODS ==========

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
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
      if (!mounted) return;
      setState(() {
        _timeUsed = _timeUsed + const Duration(seconds: 1);
      });
    });
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    String hours = twoDigits(duration.inHours);

    if (duration.inHours > 0) {
      return "$hours:$twoDigitMinutes:$twoDigitSeconds";
    }
    return "$twoDigitMinutes:$twoDigitSeconds";
  }

  // ========== ANSWER HANDLING ==========

  void _selectAnswer(String option) {
    if (_showResults || _showCorrections) return;

    setState(() {
      _userAnswers[_currentQuestionIndex] = option;
    });
  }

  void _toggleBookmark() {
    setState(() {
      _isBookmarked[_currentQuestionIndex] =
          !_isBookmarked[_currentQuestionIndex];
    });
  }

  void _toggleFlagQuestion() async {
    try {
      final index = _currentQuestionIndex;

      if (_isFlagged[index]) {
        // Unflag
        if (await _isOnline()) {
          await _unflagQuestion(index);
        } else {
          setState(() => _isFlagged[index] = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Flag removed (offline mode)'),
              backgroundColor: Color(0xFF10B981),
              duration: Duration(seconds: 2),
            ),
          );
        }
      } else {
        // Flag
        if (await _isOnline()) {
          await _flagQuestion(
            index,
            'other',
            description: 'Flagged in CBT mode',
          );
        } else {
          setState(() => _isFlagged[index] = true);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Question flagged (offline mode)'),
              backgroundColor: Color(0xFF8B5CF6),
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      print('❌ CBT: Error toggling flag: $e');
    }
  }

  Future<void> _flagQuestion(
    int index,
    String reason, {
    String? description,
  }) async {
    try {
      final question = _questions[index];

      setState(() => _isFlagged[index] = true);

      final response = await _apiService.flagPastQuestion(
        questionId: question.id,
        reason: reason,
        description: description,
      );

      if (mounted) {
        setState(() {
          _flagCounts[index] =
              response['flag_count'] ?? (_flagCounts[index] + 1);
        });
      }
    } catch (e) {
      print('❌ CBT: Error flagging question: $e');
      if (mounted) {
        setState(() => _isFlagged[index] = false);
      }
    }
  }

  Future<void> _unflagQuestion(int index) async {
    try {
      final question = _questions[index];

      setState(() => _isFlagged[index] = false);

      await _apiService.unflagPastQuestion(questionId: question.id);

      if (mounted) {
        setState(() => _flagCounts[index] = max(0, (_flagCounts[index] - 1)));
      }
    } catch (e) {
      print('❌ CBT: Error unflagging question: $e');
      if (mounted) {
        setState(() => _isFlagged[index] = true);
      }
    }
  }

  // ========== NAVIGATION ==========

  void _goToQuestion(int index) {
    setState(() {
      _currentQuestionIndex = index;
      _showQuestionPicker = false;
    });

    // Reset scroll position to top when changing questions
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollController.jumpTo(0);
    });
  }

  void _nextQuestion() {
    if (_currentQuestionIndex < _questions.length - 1) {
      setState(() => _currentQuestionIndex++);

      // Reset scroll position to top
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollController.jumpTo(0);
      });
    }
  }

  void _previousQuestion() {
    if (_currentQuestionIndex > 0) {
      setState(() => _currentQuestionIndex--);

      // Reset scroll position to top
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollController.jumpTo(0);
      });
    }
  }

  // ========== EXAM SUBMISSION ==========

  void _showSubmitConfirmation() {
    final answeredCount = _userAnswers.where((answer) => answer != null).length;
    final totalQuestions = _questions.length;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Submit Exam?',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'You have answered $answeredCount out of $totalQuestions questions.',
              style: const TextStyle(color: Color(0xFF6B7280)),
            ),
            const SizedBox(height: 8),
            const Text(
              'Are you sure you want to submit your exam?',
              style: TextStyle(color: Color(0xFF6B7280)),
            ),
          ],
        ),
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
              backgroundColor: const Color(0xFF10B981),
            ),
            child: const Text('Submit'),
          ),
        ],
      ),
    );
  }

  void _submitExam() {
    _timer.cancel();
    setState(() => _showResults = true);
  }

  void _retakeExam() {
    _timer.cancel();
    setState(() {
      _showResults = false;
      _showCorrections = false;
      _currentQuestionIndex = 0;
      _timerDuration = const Duration(minutes: 30);
      _timeUsed = Duration.zero;
      _startTime = DateTime.now();

      // Reset all answers
      _userAnswers = List.generate(_questions.length, (index) => null);
      _isBookmarked = List.generate(_questions.length, (index) => false);
      _isFlagged = List.generate(_questions.length, (index) => false);

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

  // ========== SCORE CALCULATION ==========

  int get _score {
    int correct = 0;
    for (int i = 0; i < _questions.length; i++) {
      if (_userAnswers[i] == _questions[i].correctAnswer) {
        correct++;
      }
    }
    return correct;
  }

  int get _answeredCount {
    return _userAnswers.where((answer) => answer != null).length;
  }

  String get _grade {
    final percentage = _questions.isEmpty
        ? 0
        : (_score / _questions.length) * 100;
    if (percentage >= 70) return 'A';
    if (percentage >= 60) return 'B';
    if (percentage >= 50) return 'C';
    if (percentage >= 45) return 'D';
    return 'F';
  }

  String get _timeTaken {
    if (_startTime == null) return '00:00';
    final difference = DateTime.now().difference(_startTime!);
    return _formatDuration(difference);
  }

  // ========== FIXED IMAGE LOADING SYSTEM ==========

  Widget _buildQuestionImage(PastQuestion question) {
    final imageUrl = question.questionImageUrl;
    if (imageUrl == null || imageUrl.isEmpty) return const SizedBox();

    // Check cache first
    if (_imageProviderCache.containsKey(imageUrl)) {
      final provider = _imageProviderCache[imageUrl]!;
      return _buildCachedImage(provider, imageUrl);
    }

    // Create and cache the provider based on URL type
    ImageProvider provider;

    if (imageUrl.startsWith('hive://')) {
      return _buildHiveImage(imageUrl);
    } else if (imageUrl.startsWith('/') && !imageUrl.startsWith('http')) {
      provider = FileImage(File(imageUrl));
      _imageProviderCache[imageUrl] = provider;
      return _buildCachedImage(provider, imageUrl);
    } else {
      final cleanUrl = _cleanImageUrl(imageUrl);
      provider = CachedNetworkImageProvider(cleanUrl, cacheKey: imageUrl);
      _imageProviderCache[imageUrl] = provider;
      return _buildCachedImage(provider, imageUrl);
    }
  }

  Widget _buildCachedImage(ImageProvider provider, String imageUrl) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image(
        image: provider,
        fit: BoxFit.contain,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Container(
            height: 200,
            color: Colors.grey.shade100,
            child: Center(
              child: CircularProgressIndicator(
                value: loadingProgress.expectedTotalBytes != null
                    ? loadingProgress.cumulativeBytesLoaded /
                          loadingProgress.expectedTotalBytes!
                    : null,
              ),
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) {
          // Remove from cache on error
          _imageProviderCache.remove(imageUrl);
          return _buildErrorImage('Failed to load image');
        },
      ),
    );
  }

  Widget _buildHiveImage(String imageUrl) {
    final imageKey = imageUrl.replaceFirst('hive://', '');

    return FutureBuilder<Uint8List?>(
      future: _loadHiveImage(imageKey),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingPlaceholder();
        } else if (snapshot.hasError || snapshot.data == null) {
          return _buildErrorImage('Failed to load image');
        } else {
          final bytes = snapshot.data!;
          final provider = MemoryImage(bytes);
          _imageProviderCache[imageUrl] = provider;
          return _buildCachedImage(provider, imageUrl);
        }
      },
    );
  }

  String _cleanImageUrl(String url) {
    return url.replaceAll(RegExp(r'(?<!:)/{2,}'), '/');
  }

  Widget _buildErrorImage(String message) {
    return Container(
      height: 150,
      color: Colors.grey.shade100,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.broken_image, size: 40, color: Colors.grey),
          const SizedBox(height: 8),
          Text(
            message,
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingPlaceholder() {
    return Container(
      height: 200,
      color: Colors.grey.shade100,
      child: const Center(child: CircularProgressIndicator()),
    );
  }

  Future<Uint8List?> _loadHiveImage(String imageKey) async {
    try {
      final imageBox = await Hive.openBox('offline_images');
      final imageData = imageBox.get(imageKey);
      if (imageData == null || imageData['data'] == null) return null;
      return Uint8List.fromList(List<int>.from(imageData['data']));
    } catch (e) {
      return null;
    }
  }

  // ========== FIXED CONTENT FORMATTING WITH LaTeX SUPPORT ==========

  Widget _buildFormattedContent(String content, {bool isAnswer = false}) {
    if (content.isEmpty) return Container();

    // Convert CKEditor HTML to clean markdown with LaTeX support
    final cleanContent = _convertCkEditorToMarkdown(content);

    return Container(
      constraints: BoxConstraints(minHeight: 50),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: _parseContentForDisplay(cleanContent, isAnswer: isAnswer),
      ),
    );
  }

  String _convertCkEditorToMarkdown(String htmlContent) {
    if (htmlContent.isEmpty) return '';

    String result = htmlContent;

    // 1. Handle tables FIRST
    result = _convertHtmlTablesToMarkdown(result);

    // 2. Convert math equations - handle math-tex spans
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

    // 4. Convert inline LaTeX \( and \)
    result = result.replaceAllMapped(RegExp(r'\\\((.*?)\\\)', dotAll: true), (
      match,
    ) {
      final mathContent = match.group(1) ?? '';
      return '\$$mathContent\$';
    });

    // 5. Convert display LaTeX \[ and \]
    result = result.replaceAllMapped(RegExp(r'\\\[(.*?)\\\]', dotAll: true), (
      match,
    ) {
      final mathContent = match.group(1) ?? '';
      return '\$\$$mathContent\$\$';
    });

    // 6. Convert code blocks
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

    // 7. Convert inline code
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

    // 8. Convert images
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

        if (src == null || src.isEmpty) return '';

        // Handle relative URLs
        String imageUrl = src;

        if (!src.startsWith('http://') && !src.startsWith('https://')) {
          // It's a relative URL
          if (src.startsWith('/')) {
            final baseUrl = ApiEndpoints.baseUrl;
            imageUrl = '$baseUrl$src';
          } else if (src.startsWith('media/') || src.startsWith('/media/')) {
            final baseUrl = ApiEndpoints.baseUrl;
            if (src.startsWith('media/')) {
              imageUrl = '$baseUrl/$src';
            } else {
              imageUrl = '$baseUrl$src';
            }
          } else if (src.startsWith('uploads/')) {
            final baseUrl = ApiEndpoints.baseUrl;
            imageUrl = '$baseUrl/media/$src';
          } else {
            final baseUrl = ApiEndpoints.baseUrl;
            imageUrl = '$baseUrl/media/$src';
          }
        }

        // Clean up any double slashes
        imageUrl = imageUrl.replaceAll('//media/', '/media/');
        imageUrl = imageUrl.replaceAll(':/', '://');

        // Use title as alt text if alt is empty
        final displayAlt = alt?.isNotEmpty == true ? alt : title ?? '';

        return '![${displayAlt}]($imageUrl)';
      },
    );

    // 9. Convert headings
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

    // 10. Convert lists
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

    // 11. Convert paragraphs with proper spacing
    result = result.replaceAllMapped(
      RegExp(r'<p[^>]*>(.*?)</p>', caseSensitive: false, dotAll: true),
      (match) {
        final pContent = match.group(1) ?? '';
        final cleanText = _cleanHtmlText(pContent);
        return '$cleanText\n\n';
      },
    );

    // 12. Convert formatting
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

    // 13. Convert links
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

    // 14. Convert blockquotes
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

    // 15. Remove remaining HTML tags but keep their content
    result = result.replaceAll(RegExp(r'<[^>]*>'), '');

    // 16. Decode HTML entities
    result = _decodeHtmlEntities(result);

    // 17. Clean up whitespace
    result = result
        .replaceAll(RegExp(r'\n\s*\n\s*\n'), '\n\n')
        .replaceAll(RegExp(r'[ \t]+'), ' ')
        .trim();

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
      } else {
        final urlRegex = RegExp(r'https?://[^\s]+');
        final urlMatch = urlRegex.firstMatch(line);
        if (urlMatch != null) {
          imageUrl = urlMatch.group(0) ?? '';
        }
      }

      if (imageUrl.isNotEmpty) {
        // Check if it's a Hive-stored image (for web offline)
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

  // ========== QUESTION CARD BUILDER ==========

  Widget _buildQuestionCard() {
    if (_questions.isEmpty) return Container();

    final question = _questions[_currentQuestionIndex];
    final userAnswer = _userAnswers[_currentQuestionIndex];
    final correctAnswer = question.correctAnswer;
    final optionsMap = question.getOptionsMap();

    return Expanded(
      child: SingleChildScrollView(
        controller: _scrollController,
        physics: const ClampingScrollPhysics(),
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
                        'Q${_currentQuestionIndex + 1}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 11,
                        ),
                      ),
                    ),

                    // Flag count badge
                    if (_flagCounts[_currentQuestionIndex] > 0) ...[
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
                              '${_flagCounts[_currentQuestionIndex]}',
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
                      onPressed: _toggleBookmark,
                      icon: Icon(
                        _isBookmarked[_currentQuestionIndex]
                            ? Icons.bookmark_rounded
                            : Icons.bookmark_border_rounded,
                        color: _isBookmarked[_currentQuestionIndex]
                            ? const Color(0xFFF59E0B)
                            : Colors.grey.shade400,
                        size: 20,
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      iconSize: 20,
                    ),

                    // Flag button
                    GestureDetector(
                      onTap: _toggleFlagQuestion,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        margin: const EdgeInsets.only(left: 4),
                        decoration: BoxDecoration(
                          color: _isFlagged[_currentQuestionIndex]
                              ? const Color(0xFF8B5CF6).withOpacity(0.1)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: _isFlagged[_currentQuestionIndex]
                                ? const Color(0xFF8B5CF6)
                                : Colors.grey.shade300,
                            width: 1,
                          ),
                        ),
                        child: Icon(
                          _isFlagged[_currentQuestionIndex]
                              ? Icons.flag_rounded
                              : Icons.outlined_flag_rounded,
                          color: _isFlagged[_currentQuestionIndex]
                              ? const Color(0xFF8B5CF6)
                              : Colors.grey.shade600,
                          size: 16,
                        ),
                      ),
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
                    // Question Text with proper formatting INCLUDING LaTeX
                    if (question.questionText != null &&
                        question.questionText!.isNotEmpty)
                      _buildFormattedContent(
                        question.questionText!,
                        isAnswer: false,
                      ),

                    // Question Image - Use the improved caching method
                    if (question.questionImageUrl != null &&
                        question.questionImageUrl!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 12, bottom: 16),
                        child: _buildQuestionImage(question),
                      ),

                    // Options with proper formatting INCLUDING LaTeX
                    if (question.hasOptions && optionsMap.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: optionsMap.entries.map((option) {
                          final optionKey = option.key;
                          final isSelected = userAnswer == optionKey;
                          final isCorrect = optionKey == correctAnswer;

                          Color backgroundColor = Colors.grey.shade50;
                          Color borderColor = Colors.grey.shade200;
                          Color textColor = const Color(0xFF1A1A2E);

                          if (_showCorrections) {
                            if (isCorrect) {
                              backgroundColor = const Color(
                                0xFF10B981,
                              ).withOpacity(0.1);
                              borderColor = const Color(0xFF10B981);
                              textColor = const Color(0xFF10B981);
                            } else if (isSelected && !isCorrect) {
                              backgroundColor = const Color(
                                0xFFEF4444,
                              ).withOpacity(0.1);
                              borderColor = const Color(0xFFEF4444);
                              textColor = const Color(0xFFEF4444);
                            }
                          } else if (isSelected) {
                            backgroundColor = const Color(
                              0xFF6366F1,
                            ).withOpacity(0.1);
                            borderColor = const Color(0xFF6366F1);
                            textColor = const Color(0xFF6366F1);
                          }

                          Widget? trailingIcon;
                          if (_showCorrections) {
                            if (isCorrect) {
                              trailingIcon = Icon(
                                Icons.check_rounded,
                                color: const Color(0xFF10B981),
                                size: 16,
                              );
                            } else if (isSelected && !isCorrect) {
                              trailingIcon = Icon(
                                Icons.close_rounded,
                                color: const Color(0xFFEF4444),
                                size: 16,
                              );
                            }
                          }

                          return GestureDetector(
                            onTap: !_showCorrections
                                ? () => _selectAnswer(optionKey)
                                : null,
                            child: Container(
                              width:
                                  (MediaQuery.of(context).size.width - 56) / 2,
                              decoration: BoxDecoration(
                                color: backgroundColor,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: borderColor,
                                  width: 1.5,
                                ),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      width: 20,
                                      height: 20,
                                      decoration: BoxDecoration(
                                        color: _showCorrections && isCorrect
                                            ? const Color(0xFF10B981)
                                            : _showCorrections &&
                                                  isSelected &&
                                                  !isCorrect
                                            ? const Color(0xFFEF4444)
                                            : isSelected
                                            ? const Color(0xFF6366F1)
                                            : Colors.white,
                                        shape: BoxShape.circle,
                                        border: Border.all(color: borderColor),
                                      ),
                                      child: Center(
                                        child: Text(
                                          optionKey,
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color:
                                                isSelected ||
                                                    (_showCorrections &&
                                                        (isCorrect ||
                                                            (isSelected &&
                                                                !isCorrect)))
                                                ? Colors.white
                                                : textColor,
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
                                    if (trailingIcon != null) ...[
                                      const SizedBox(width: 8),
                                      trailingIcon,
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],

                    // Short answer indicator
                    if (!question.hasOptions)
                      Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(top: 12),
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

                    // Show correct answer in correction mode WITH LaTeX support
                    if (_showCorrections && question.hasOptions)
                      Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withOpacity(0.05),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: const Color(0xFF10B981).withOpacity(0.2),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.check_rounded,
                                color: const Color(0xFF10B981),
                                size: 16,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _buildFormattedContent(
                                  'Correct Answer: $correctAnswer',
                                  isAnswer: true,
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
        ),
      ),
    );
  }

  // ========== OTHER WIDGETS ==========

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
                  final isCurrent = index == _currentQuestionIndex;
                  final isAnswered = _userAnswers[index] != null;
                  final isFlagged = _isFlagged[index];
                  final isCorrect =
                      _showCorrections &&
                      _userAnswers[index] == _questions[index].correctAnswer;
                  final isWrong =
                      _showCorrections &&
                      _userAnswers[index] != null &&
                      _userAnswers[index] != _questions[index].correctAnswer;

                  Color backgroundColor = Colors.grey.shade100;
                  Color textColor = Colors.black;

                  if (_showCorrections) {
                    if (isCorrect) {
                      backgroundColor = const Color(
                        0xFF10B981,
                      ).withOpacity(0.3);
                      textColor = const Color(0xFF10B981);
                    } else if (isWrong) {
                      backgroundColor = const Color(
                        0xFFEF4444,
                      ).withOpacity(0.3);
                      textColor = const Color(0xFFEF4444);
                    } else if (isAnswered) {
                      backgroundColor = const Color(
                        0xFF6366F1,
                      ).withOpacity(0.3);
                      textColor = const Color(0xFF6366F1);
                    }
                  } else if (isCurrent) {
                    backgroundColor = const Color(0xFF6366F1);
                    textColor = Colors.white;
                  } else if (isAnswered) {
                    backgroundColor = const Color(0xFF10B981);
                    textColor = Colors.white;
                  }

                  return GestureDetector(
                    onTap: () => _goToQuestion(index),
                    child: Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: backgroundColor,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isFlagged
                              ? const Color(0xFF8B5CF6)
                              : Colors.transparent,
                          width: 2,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          '${index + 1}',
                          style: TextStyle(
                            color: textColor,
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
              ),
              child: const Text('Close'),
            ),
          ),
        ],
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
          const Icon(
            Icons.celebration_rounded,
            size: 64,
            color: Color(0xFFF59E0B),
          ),
          const SizedBox(height: 16),
          const Text(
            'CBT Exam Completed!',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            '${widget.courseName} • ${widget.sessionName}',
            style: const TextStyle(color: Colors.grey, fontSize: 14),
          ),
          const SizedBox(height: 4),
          Text(
            'Time Taken: $_timeTaken',
            style: const TextStyle(color: Colors.grey, fontSize: 14),
          ),
          Text(
            'Answered: $_answeredCount/${_questions.length}',
            style: const TextStyle(color: Colors.grey, fontSize: 14),
          ),
          const SizedBox(height: 24),

          // Grade display
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
                  style: TextStyle(fontSize: 16, color: Colors.grey),
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
                  style: const TextStyle(fontSize: 16, color: Colors.grey),
                ),
                Text(
                  '${_questions.isEmpty ? 0 : (_score / _questions.length * 100).toStringAsFixed(1)}%',
                  style: const TextStyle(fontSize: 16, color: Colors.grey),
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

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text(
            'Loading CBT Questions...',
            style: TextStyle(color: Color(0xFF6B7280)),
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
            const Icon(
              Icons.error_outline_rounded,
              size: 64,
              color: Color(0xFF6B7280),
            ),
            const SizedBox(height: 16),
            const Text(
              'Error Loading Questions',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'Unable to load questions from downloaded courses. '
                'Please make sure you have downloaded the course and try again.',
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
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
              '${widget.courseName} • ${widget.sessionName}',
              style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280)),
            ),
          ],
        ),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1A1A2E),
        elevation: 1,
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

          if (widget.isOffline)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              margin: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: const [
                  Icon(Icons.wifi_off_rounded, size: 12, color: Colors.orange),
                  SizedBox(width: 4),
                  Text(
                    'Offline',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.orange,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          IconButton(
            onPressed: _isLoading
                ? null
                : () => setState(
                    () => _showQuestionPicker = !_showQuestionPicker,
                  ),
            icon: const Icon(Icons.grid_view_rounded, size: 20),
          ),
        ],
      ),
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: _isLoading
                ? _buildLoadingState()
                : _questions.isEmpty
                ? _buildErrorState()
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
                          decoration: BoxDecoration(
                            color: Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(8),
                          ),
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

                      // Header with Timer and Submit Button
                      if (!_showResults && !_showCorrections)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
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
                              // Timer
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: widget.enableTimer
                                      ? const Color(0xFFF59E0B).withOpacity(0.1)
                                      : Colors.grey.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: widget.enableTimer
                                        ? const Color(0xFFF59E0B)
                                        : Colors.grey,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.timer_rounded,
                                      size: 16,
                                      color: widget.enableTimer
                                          ? const Color(0xFFF59E0B)
                                          : Colors.grey,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      widget.enableTimer
                                          ? _formatDuration(_timerDuration)
                                          : _formatDuration(_timeUsed),
                                      style: TextStyle(
                                        color: widget.enableTimer
                                            ? const Color(0xFFF59E0B)
                                            : Colors.grey,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Spacer(),
                              // Submit Button
                              ElevatedButton(
                                onPressed: _showSubmitConfirmation,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF10B981),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 10,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: const Text(
                                  'Submit',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (!_showResults && !_showCorrections)
                        const SizedBox(height: 16),

                      // Main Content
                      if (_showResults)
                        Expanded(
                          child: SingleChildScrollView(
                            physics: const ClampingScrollPhysics(),
                            child: _buildResultsScreen(),
                          ),
                        )
                      else
                        _buildQuestionCard(),

                      // Navigation Buttons
                      if (!_showResults) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
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
          // Question Picker Modal
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
