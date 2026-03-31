// lib/features/cbt/screens/cbt_questions_screen.dart
import 'dart:io';
import 'dart:math';
import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import '../../../core/network/api_service.dart';
import '../../../core/services/activation_status_service.dart';
import '../../../core/constants/endpoints.dart';
import '../../../core/utils/latex_render_utils.dart';
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
  final Map<String, String> _offlineDownloadedImageMap = {};
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
      7; // Show only 2 questions for non-activated users
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
    ActivationStatusService.listenable.addListener(_handleActivationStatusChanged);
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
    ActivationStatusService.listenable.removeListener(
      _handleActivationStatusChanged,
    );
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

  void _handleActivationStatusChanged() {
    if (!mounted) return;
    _applyActivationSnapshot(ActivationStatusService.current);
  }

  void _applyActivationSnapshot(ActivationStatusSnapshot snapshot) {
    if (!mounted) return;

    setState(() {
      _isUserActivated = snapshot.isActivated;
      _activationStatusMessage = snapshot.isActivated
          ? (snapshot.grade?.toUpperCase() ?? 'Activated')
          : 'Not Activated';
      _checkingActivation = false;
    });
  }

  Future<void> _checkActivationStatus({bool forceRefresh = false}) async {
    setState(() {
      _checkingActivation = true;
    });

    try {
      await ActivationStatusService.initialize();
      final status = await ActivationStatusService.resolveStatus(
        forceRefresh: false,
      );

      _applyActivationSnapshot(status);

      if (forceRefresh || status.isStale || !status.hasCachedValue) {
        ActivationStatusService.refreshInBackground(forceRefresh: true);
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

      _offlineDownloadedImageMap.clear();
      if (courseData.containsKey('downloaded_images')) {
        final downloadedImages = courseData['downloaded_images'];
        if (downloadedImages is Map) {
          downloadedImages.forEach((key, value) {
            if (value is Map) {
              final originalUrl = value['original_url']?.toString();
              final localPath = value['path']?.toString();

              if (originalUrl != null &&
                  originalUrl.isNotEmpty &&
                  localPath != null &&
                  localPath.isNotEmpty) {
                _offlineDownloadedImageMap[originalUrl] = localPath;
                final normalizedOriginal = _normalizeImageUrl(originalUrl);
                _offlineDownloadedImageMap[normalizedOriginal] = localPath;
              }
            }
          });
          print(
            '🖼️ Loaded ${_offlineDownloadedImageMap.length} offline image mappings',
          );
        }
      }

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

              // CBT combines past and test questions, so check both key patterns.
              final questionImageKeys = [
                'past_question_${qMap['id']}',
                'test_question_${qMap['id']}',
              ];
              for (final questionImageKey in questionImageKeys) {
                final localPath =
                    imagesMap[questionImageKey]?['path'] as String?;
                if (localPath != null && localPath.isNotEmpty) {
                  qMap['question_image_url'] = localPath;
                  break;
                }
              }

              final solutionImageKeys = [
                'past_question_solution_${qMap['id']}',
                'test_question_solution_${qMap['id']}',
              ];
              for (final solutionImageKey in solutionImageKeys) {
                final localPath =
                    imagesMap[solutionImageKey]?['path'] as String?;
                if (localPath != null && localPath.isNotEmpty) {
                  qMap['solution_image_url'] = localPath;
                  break;
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
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final surface = isDark ? const Color(0xFF101A2B) : Colors.white;
        final titleColor = isDark
            ? const Color(0xFFF8FAFC)
            : const Color(0xFF1A1A2E);
        final bodyColor = isDark
            ? const Color(0xFFCBD5E1)
            : const Color(0xFF6B7280);
        return AlertDialog(
          backgroundColor: surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            'Submit Exam?',
            style: TextStyle(fontWeight: FontWeight.bold, color: titleColor),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'You have answered $answeredCount out of $totalQuestions questions.',
                style: TextStyle(color: bodyColor),
              ),
              const SizedBox(height: 8),
              Text(
                'Are you sure you want to submit your exam?',
                style: TextStyle(color: bodyColor),
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
        );
      },
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

    if (_shouldRenderAsHtml(content)) {
      return _buildHtmlFormattedContent(content, isAnswer: isAnswer);
    }

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

  bool _shouldRenderAsHtml(String content) {
    final trimmed = content.trim();
    return (trimmed.contains('<') && trimmed.contains('>')) ||
        _looksLikeTabularPlainText(trimmed) ||
        RegExp(r'!\[.*?\]\(.*?\)').hasMatch(trimmed);
  }

  bool _looksLikeTabularPlainText(String content) {
    final lines = content
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();

    if (lines.length < 2) return false;

    final tabRows = lines.where((line) => line.contains('\t')).toList();
    if (tabRows.length < 2) return false;

    final firstColumnCount = tabRows.first.split(RegExp(r'\t+')).length;
    if (firstColumnCount < 2) return false;

    return tabRows
        .take(4)
        .every((row) => row.split(RegExp(r'\t+')).length == firstColumnCount);
  }

  Widget _buildHtmlFormattedContent(String content, {bool isAnswer = false}) {
    final processedContent = _prepareHtmlContentForRendering(content);
    final textColor = isAnswer
        ? const Color(0xFF10B981)
        : const Color(0xFF333333);

    return Html(
      data: processedContent,
      shrinkWrap: true,
      extensions: [
        TagExtension(
          tagsToExtend: {'pre'},
          builder: (context) {
            final rawHtml = context.innerHtml;
            final language = _extractCodeLanguageFromHtml(rawHtml);
            final codeContent = _extractCodeTextFromHtml(rawHtml);
            if (codeContent.trim().isEmpty) {
              return const SizedBox.shrink();
            }
            return _buildCodeBlock(codeContent, language);
          },
        ),
        TagExtension(
          tagsToExtend: {'code'},
          builder: (context) {
            final rawHtml = context.innerHtml;
            if (rawHtml.contains('\n')) {
              final language = _extractCodeLanguageFromHtml(rawHtml);
              final codeContent = _extractCodeTextFromHtml(rawHtml);
              if (codeContent.trim().isEmpty) {
                return const SizedBox.shrink();
              }
              return _buildCodeBlock(codeContent, language);
            }

            final inlineCode = _decodeHtmlEntities(
              rawHtml.replaceAll(RegExp(r'<[^>]*>'), '').trim(),
            );
            if (inlineCode.isEmpty) {
              return const SizedBox.shrink();
            }
            return _buildInlineCode('`$inlineCode`');
          },
        ),
        TagExtension(
          tagsToExtend: {'img'},
          builder: (context) {
            final src = context.attributes['src'] ?? '';
            final alt = context.attributes['alt'] ?? '';
            return _buildImageFromSource(src, altText: alt);
          },
        ),
        TagExtension(
          tagsToExtend: {'flutter-table'},
          builder: (context) {
            final encodedData = context.attributes['data'];
            if (encodedData == null || encodedData.isEmpty) {
              return const SizedBox.shrink();
            }

            try {
              final tableData =
                  jsonDecode(Uri.decodeComponent(encodedData))
                      as Map<String, dynamic>;
              final hasHeader = tableData['hasHeader'] == true;
              final rows = (tableData['rows'] as List<dynamic>)
                  .map(
                    (row) => (row as List<dynamic>)
                        .map((cell) => cell.toString())
                        .toList(),
                  )
                  .toList();
              return _buildHtmlTable(rows, hasHeader: hasHeader);
            } catch (e) {
              return Container(
                padding: const EdgeInsets.all(12),
                color: Colors.red.shade50,
                child: Text('Table render error: $e'),
              );
            }
          },
        ),
        TagExtension(
          tagsToExtend: {'tex-inline'},
          builder: (context) {
            final expression = _decodeHtmlEntities(context.innerHtml.trim());
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: _buildMathWidget(expression, isInline: true),
            );
          },
        ),
        TagExtension(
          tagsToExtend: {'tex-block'},
          builder: (context) {
            final expression = _decodeHtmlEntities(context.innerHtml.trim());
            return _buildMathBlock(expression);
          },
        ),
      ],
      style: {
        'html': Style(margin: Margins.zero, padding: HtmlPaddings.zero),
        'body': Style(
          margin: Margins.zero,
          padding: HtmlPaddings.zero,
          color: textColor,
          fontSize: FontSize(isAnswer ? 16 : 14),
          lineHeight: LineHeight(1.6),
        ),
        'p': Style(
          margin: Margins.only(bottom: 14),
          color: textColor,
          fontSize: FontSize(isAnswer ? 16 : 14),
          lineHeight: LineHeight(1.6),
        ),
        'div': Style(
          margin: Margins.only(bottom: 8),
          color: textColor,
          fontSize: FontSize(isAnswer ? 16 : 14),
          lineHeight: LineHeight(1.6),
        ),
        'span': Style(
          color: textColor,
          fontSize: FontSize(isAnswer ? 16 : 14),
          lineHeight: LineHeight(1.6),
        ),
        'strong': Style(fontWeight: FontWeight.w700, color: textColor),
        'b': Style(fontWeight: FontWeight.w700, color: textColor),
        'em': Style(fontStyle: FontStyle.italic, color: textColor),
        'i': Style(fontStyle: FontStyle.italic, color: textColor),
        'u': Style(textDecoration: TextDecoration.underline, color: textColor),
        'h1': Style(
          fontSize: FontSize(22),
          fontWeight: FontWeight.bold,
          margin: Margins.only(top: 16, bottom: 12),
          color: textColor,
        ),
        'h2': Style(
          fontSize: FontSize(20),
          fontWeight: FontWeight.bold,
          margin: Margins.only(top: 14, bottom: 10),
          color: textColor,
        ),
        'h3': Style(
          fontSize: FontSize(18),
          fontWeight: FontWeight.w700,
          margin: Margins.only(top: 12, bottom: 8),
          color: textColor,
        ),
        'ul': Style(
          margin: Margins.only(bottom: 12, left: 18),
          padding: HtmlPaddings.zero,
        ),
        'ol': Style(
          margin: Margins.only(bottom: 12, left: 18),
          padding: HtmlPaddings.zero,
        ),
        'li': Style(
          color: textColor,
          fontSize: FontSize(isAnswer ? 16 : 14),
          lineHeight: LineHeight(1.6),
          margin: Margins.only(bottom: 6),
        ),
        'img': Style(margin: Margins.only(top: 10, bottom: 10)),
        'blockquote': Style(
          padding: HtmlPaddings.only(left: 12, top: 8, bottom: 8),
          margin: Margins.only(top: 8, bottom: 8),
          border: Border(
            left: BorderSide(color: Colors.blue.shade200, width: 4),
          ),
          backgroundColor: Colors.blue.shade50,
        ),
      },
    );
  }

  String _prepareHtmlContentForRendering(String content) {
    String processed = LatexRenderUtils.sanitizeStoredMathTags(content).trim();

    if (!_looksLikeHtml(processed) && _looksLikeTabularPlainText(processed)) {
      processed = _convertPlainTextTableToHtml(processed);
    } else if (!_looksLikeHtml(processed)) {
      processed = processed
          .split('\n\n')
          .map(
            (block) =>
                '<p>${_escapeHtmlText(block).replaceAll('\n', '<br>')}</p>',
          )
          .join();
    }

    processed = _convertMarkdownImagesToHtml(processed);
    processed = _normalizeCkEditorImageUrls(processed);
    processed = _replaceCkEditorMathWithCustomTags(processed);
    processed = LatexRenderUtils.replaceBracketMathWithCustomTags(
      processed,
      _escapeHtmlText,
    );
    processed = _replaceDollarMathWithCustomTags(processed);
    processed = _replaceHtmlTablesWithCustomTags(processed);

    return '''
<style>
  img { max-width: 100%; height: auto; display: block; margin: 0 auto; }
</style>
$processed
''';
  }

  bool _looksLikeHtml(String content) {
    return RegExp(r'<[a-zA-Z][^>]*>').hasMatch(content);
  }

  String _extractCodeLanguageFromHtml(String rawHtml) {
    final classMatch = RegExp(
      r'class="([^"]+)"',
      caseSensitive: false,
    ).firstMatch(rawHtml);
    if (classMatch == null) return '';

    final classes = classMatch.group(1)?.split(RegExp(r'\s+')) ?? const [];
    for (final cls in classes) {
      if (cls.startsWith('language-')) {
        return cls.replaceFirst('language-', '').trim();
      }
    }

    return '';
  }

  String _extractCodeTextFromHtml(String rawHtml) {
    final stripped = rawHtml
        .replaceAll(RegExp(r'</?(pre|code)[^>]*>', caseSensitive: false), '')
        .replaceAll('<br>', '\n')
        .replaceAll('<br/>', '\n')
        .replaceAll('<br />', '\n')
        .replaceAll(RegExp(r'</p\s*>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'<[^>]*>'), '');

    return _decodeHtmlEntities(stripped).trimRight();
  }

  String _convertPlainTextTableToHtml(String content) {
    final lines = content
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();

    if (lines.isEmpty) return content;

    final rows = lines
        .map(
          (line) =>
              line.split(RegExp(r'\t+')).map((cell) => cell.trim()).toList(),
        )
        .toList();

    final buffer = StringBuffer('<table><tbody>');
    for (final row in rows) {
      buffer.write('<tr>');
      for (final cell in row) {
        buffer.write('<td>${_escapeHtmlText(cell)}</td>');
      }
      buffer.write('</tr>');
    }
    buffer.write('</tbody></table>');
    return buffer.toString();
  }

  String _normalizeCkEditorImageUrls(String htmlContent) {
    return htmlContent.replaceAllMapped(
      RegExp(r'<img([^>]*?)src="([^"]*)"([^>]*)>', caseSensitive: false),
      (match) {
        final before = match.group(1) ?? '';
        final src = match.group(2) ?? '';
        final after = match.group(3) ?? '';
        final normalizedUrl = _normalizeImageUrl(src);
        return '<img$before src="$normalizedUrl"$after>';
      },
    );
  }

  String _convertMarkdownImagesToHtml(String content) {
    return content.replaceAllMapped(RegExp(r'!\[(.*?)\]\((.*?)\)'), (match) {
      final alt = _escapeHtmlText(match.group(1) ?? '');
      final src = _normalizeImageUrl(match.group(2) ?? '');
      return '<img src="$src" alt="$alt" />';
    });
  }

  String _normalizeImageUrl(String src) {
    if (src.isEmpty) return src;
    if (_offlineDownloadedImageMap.containsKey(src)) {
      return _offlineDownloadedImageMap[src]!;
    }
    if (src.startsWith('http://') || src.startsWith('https://')) {
      return _offlineDownloadedImageMap[src] ?? src;
    }

    final baseUrl = ApiEndpoints.baseUrl;
    String imageUrl;

    if (src.startsWith('/')) {
      imageUrl = '$baseUrl$src';
    } else if (src.startsWith('media/') || src.startsWith('/media/')) {
      imageUrl = src.startsWith('media/') ? '$baseUrl/$src' : '$baseUrl$src';
    } else if (src.startsWith('uploads/')) {
      imageUrl = '$baseUrl/media/$src';
    } else {
      imageUrl = '$baseUrl/media/$src';
    }

    imageUrl = imageUrl.replaceAll('//media/', '/media/');
    imageUrl = imageUrl.replaceAll(':/', '://');
    return _offlineDownloadedImageMap[imageUrl] ?? imageUrl;
  }

  String _replaceCkEditorMathWithCustomTags(String htmlContent) {
    String result = htmlContent;

    result = result.replaceAllMapped(
      RegExp(
        r'<span[^>]*class="[^"]*math-tex[^"]*"[^>]*>(.*?)</span>',
        caseSensitive: false,
        dotAll: true,
      ),
      (match) => '<tex-inline>${match.group(1) ?? ''}</tex-inline>',
    );

    result = result.replaceAllMapped(
      RegExp(
        r'<script[^>]*type="math/tex; mode=display"[^>]*>(.*?)</script>',
        caseSensitive: false,
        dotAll: true,
      ),
      (match) =>
          '<tex-block>${_escapeHtmlText(match.group(1) ?? '')}</tex-block>',
    );

    result = result.replaceAllMapped(
      RegExp(
        r'<script[^>]*type="math/tex"[^>]*>(.*?)</script>',
        caseSensitive: false,
        dotAll: true,
      ),
      (match) =>
          '<tex-inline>${_escapeHtmlText(match.group(1) ?? '')}</tex-inline>',
    );

    return result;
  }

  String _replaceDollarMathWithCustomTags(String content) {
    String result = LatexRenderUtils.normalizeDelimitedMath(content);

    result = result.replaceAllMapped(
      RegExp(r'\$\$(.+?)\$\$', dotAll: true),
      (match) =>
          '<tex-block>${_escapeHtmlText(match.group(1) ?? '')}</tex-block>',
    );

    result = result.replaceAllMapped(
      RegExp(r'(?<!\$)\$([^\$]+?)\$(?!\$)', dotAll: true),
      (match) =>
          '<tex-inline>${_escapeHtmlText(match.group(1) ?? '')}</tex-inline>',
    );

    return result;
  }

  String _replaceHtmlTablesWithCustomTags(String htmlContent) {
    return htmlContent.replaceAllMapped(
      RegExp(r'<table[^>]*>(.*?)</table>', caseSensitive: false, dotAll: true),
      (tableMatch) {
        final tableInnerHtml = tableMatch.group(1) ?? '';
        final rows = <List<String>>[];
        bool hasHeader = false;

        final rowMatches = RegExp(
          r'<tr[^>]*>(.*?)</tr>',
          caseSensitive: false,
          dotAll: true,
        ).allMatches(tableInnerHtml);

        for (final rowMatch in rowMatches) {
          final rowHtml = rowMatch.group(1) ?? '';
          final cells = <String>[];

          final cellMatches = RegExp(
            r'<(th|td)[^>]*>(.*?)</\1>',
            caseSensitive: false,
            dotAll: true,
          ).allMatches(rowHtml);

          for (final cellMatch in cellMatches) {
            final tag = (cellMatch.group(1) ?? '').toLowerCase();
            if (tag == 'th') hasHeader = true;
            cells.add((cellMatch.group(2) ?? '').trim());
          }

          if (cells.isNotEmpty) {
            rows.add(cells);
          }
        }

        if (rows.isEmpty) return '';

        final encoded = Uri.encodeComponent(
          jsonEncode({'hasHeader': hasHeader, 'rows': rows}),
        );
        return '<flutter-table data="$encoded"></flutter-table>';
      },
    );
  }

  String _escapeHtmlText(String text) {
    return text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#39;');
  }

  String _convertCkEditorToMarkdown(String htmlContent) {
    if (htmlContent.isEmpty) return '';

    String result = LatexRenderUtils.restoreCustomTexTagsToLatex(htmlContent);

    // Debug: Print raw HTML
    print(
      '📝 Raw HTML: ${htmlContent.substring(0, min(200, htmlContent.length))}...',
    );

    // 1. CRITICAL: First check if it's plain text (no HTML tags)
    if (!result.contains('<') && !result.contains('>')) {
      // It's already plain text, just decode entities
      return _decodeHtmlEntities(result);
    }

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

      // Handle plain text tables where cells are separated with tabs
      if (_isTabSeparatedTableStart(lines, i)) {
        final tableLines = _extractTabSeparatedTableLines(lines, i);
        if (tableLines.isNotEmpty) {
          widgets.add(_buildPlainTextTable(tableLines));
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

      // Handle mixed text/image lines without dropping surrounding text
      if (_containsImageMarkup(line)) {
        if (_isStandaloneImageLine(line)) {
          widgets.add(_buildImage(line.trim()));
        } else {
          widgets.addAll(_buildMixedContentLine(line, isAnswer: isAnswer));
        }
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

  bool _isTabSeparatedTableStart(List<String> lines, int index) {
    if (index >= lines.length) return false;
    final current = lines[index].trim();
    if (!current.contains('\t')) return false;
    if (index + 1 >= lines.length) return false;

    final next = lines[index + 1].trim();
    if (!next.contains('\t')) return false;

    final currentColumns = current.split(RegExp(r'\t+')).length;
    final nextColumns = next.split(RegExp(r'\t+')).length;
    return currentColumns >= 2 && currentColumns == nextColumns;
  }

  List<String> _extractTabSeparatedTableLines(
    List<String> lines,
    int startIndex,
  ) {
    final tableLines = <String>[];
    int? expectedColumns;

    for (int i = startIndex; i < lines.length; i++) {
      final line = lines[i].trim();
      if (!line.contains('\t')) break;

      final columns = line.split(RegExp(r'\t+')).length;
      expectedColumns ??= columns;

      if (columns != expectedColumns || columns < 2) break;
      tableLines.add(line);
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

  bool _containsImageMarkup(String line) {
    final markdownImageRegex = RegExp(r'!\[.*?\]\(.*?\)');
    final htmlImageRegex = RegExp(
      r'<img[^>]*src="[^"]+"[^>]*>',
      caseSensitive: false,
    );

    return markdownImageRegex.hasMatch(line) || htmlImageRegex.hasMatch(line);
  }

  bool _isStandaloneImageLine(String line) {
    final trimmed = line.trim();
    final markdownImageRegex = RegExp(r'^!\[.*?\]\(.*?\)$');
    final htmlImageRegex = RegExp(
      r'^<img[^>]*src="[^"]+"[^>]*>$',
      caseSensitive: false,
    );
    final urlRegex = RegExp(
      r'^https?://[^\s]+\.(jpg|jpeg|png|gif|bmp|webp|svg)(\?.*)?$',
      caseSensitive: false,
    );

    return markdownImageRegex.hasMatch(trimmed) ||
        htmlImageRegex.hasMatch(trimmed) ||
        urlRegex.hasMatch(trimmed);
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

  List<Widget> _buildMixedContentLine(String line, {bool isAnswer = false}) {
    final widgets = <Widget>[];
    final markdownImageRegex = RegExp(r'!\[.*?\]\(.*?\)');
    final matches = markdownImageRegex.allMatches(line).toList();

    if (matches.isEmpty) {
      widgets.add(_buildText(line, isAnswer: isAnswer));
      return widgets;
    }

    int lastIndex = 0;

    for (final match in matches) {
      final beforeImage = line.substring(lastIndex, match.start).trim();
      if (beforeImage.isNotEmpty) {
        if (_containsInlineMath(beforeImage)) {
          widgets.add(_buildInlineMathText(beforeImage, isAnswer: isAnswer));
        } else {
          widgets.add(_buildText(beforeImage, isAnswer: isAnswer));
        }
      }

      widgets.add(_buildImage(match.group(0)!));
      lastIndex = match.end;
    }

    final afterLastImage = line.substring(lastIndex).trim();
    if (afterLastImage.isNotEmpty) {
      if (_containsInlineMath(afterLastImage)) {
        widgets.add(_buildInlineMathText(afterLastImage, isAnswer: isAnswer));
      } else {
        widgets.add(_buildText(afterLastImage, isAnswer: isAnswer));
      }
    }

    return widgets;
  }

  bool _isTableLine(String line) {
    return line.contains('|') &&
        line.split('|').where((p) => p.trim().isNotEmpty).length >= 2;
  }

  bool _isMarkdownSeparatorLine(String line) {
    final trimmed = line.trim();
    if (!trimmed.startsWith('|')) return false;

    final parts = trimmed.split('|');
    for (int i = 1; i < parts.length - 1; i++) {
      final part = parts[i].trim();
      if (part.isNotEmpty && !RegExp(r'^:?-+:?$').hasMatch(part)) {
        return false;
      }
    }

    return true;
  }

  // ========== WIDGET BUILDERS ==========

  Widget _buildText(String text, {bool isAnswer = false}) {
    return _buildRichTextBlock(
      text,
      isAnswer: isAnswer,
      padding: const EdgeInsets.symmetric(vertical: 4),
    );
  }

  Widget _buildRichTextBlock(
    String text, {
    bool isAnswer = false,
    bool isHeader = false,
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
    EdgeInsetsGeometry padding = EdgeInsets.zero,
  }) {
    final resolvedStyle = TextStyle(
      fontSize: fontSize ?? (isAnswer ? 16 : 14),
      fontWeight: fontWeight ?? FontWeight.normal,
      color:
          color ??
          (isAnswer ? const Color(0xFF10B981) : const Color(0xFF666666)),
      height: 1.6,
    );

    return Padding(
      padding: padding,
      child: RichText(
        text: TextSpan(
          style: resolvedStyle,
          children: _buildInlineSpans(
            text,
            baseStyle: resolvedStyle,
            isAnswer: isAnswer,
            isHeader: isHeader,
          ),
        ),
      ),
    );
  }

  List<InlineSpan> _buildInlineSpans(
    String text, {
    required TextStyle baseStyle,
    bool isAnswer = false,
    bool isHeader = false,
  }) {
    final spans = <InlineSpan>[];
    int index = 0;

    while (index < text.length) {
      if (text.startsWith(r'\(', index)) {
        final end = text.indexOf(r'\)', index + 2);
        if (end != -1) {
          final mathContent = text.substring(index + 2, end);
          spans.add(
            WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: _buildMathWidget(mathContent, isInline: true),
              ),
            ),
          );
          index = end + 2;
          continue;
        }
      }

      if (text[index] == r'$') {
        final end = _findClosingDollar(text, index + 1);
        if (end != -1) {
          final mathContent = text.substring(index + 1, end);
          spans.add(
            WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: _buildMathWidget(mathContent, isInline: true),
              ),
            ),
          );
          index = end + 1;
          continue;
        }
      }

      if (text.startsWith('**', index) || text.startsWith('__', index)) {
        final marker = text.substring(index, index + 2);
        final end = text.indexOf(marker, index + 2);
        if (end != -1) {
          final content = text.substring(index + 2, end);
          spans.add(
            TextSpan(
              text: content,
              style: baseStyle.copyWith(fontWeight: FontWeight.bold),
            ),
          );
          index = end + 2;
          continue;
        }
      }

      if (text.startsWith('~~', index)) {
        final end = text.indexOf('~~', index + 2);
        if (end != -1) {
          final content = text.substring(index + 2, end);
          spans.add(
            TextSpan(
              text: content,
              style: baseStyle.copyWith(decoration: TextDecoration.lineThrough),
            ),
          );
          index = end + 2;
          continue;
        }
      }

      if (text[index] == '`') {
        final end = text.indexOf('`', index + 1);
        if (end != -1) {
          final content = text.substring(index + 1, end);
          spans.add(
            TextSpan(
              text: content,
              style: baseStyle.copyWith(
                backgroundColor: Colors.grey.shade200,
                color: Colors.red.shade700,
                fontFamily: 'RobotoMono',
                fontSize: (baseStyle.fontSize ?? 14) - 1,
                fontWeight: FontWeight.w500,
              ),
            ),
          );
          index = end + 1;
          continue;
        }
      }

      if (text[index] == '[') {
        final labelEnd = text.indexOf(']', index + 1);
        if (labelEnd != -1 &&
            labelEnd + 1 < text.length &&
            text[labelEnd + 1] == '(') {
          final urlEnd = text.indexOf(')', labelEnd + 2);
          if (urlEnd != -1) {
            final label = text.substring(index + 1, labelEnd);
            spans.add(
              TextSpan(
                text: label,
                style: baseStyle.copyWith(
                  color: Colors.blue.shade700,
                  decoration: TextDecoration.underline,
                ),
              ),
            );
            index = urlEnd + 1;
            continue;
          }
        }
      }

      if (text[index] == '*' || text[index] == '_') {
        final marker = text[index];
        final end = text.indexOf(marker, index + 1);
        if (end != -1) {
          final content = text.substring(index + 1, end);
          spans.add(
            TextSpan(
              text: content,
              style: baseStyle.copyWith(fontStyle: FontStyle.italic),
            ),
          );
          index = end + 1;
          continue;
        }
      }

      final nextToken = _findNextInlineTokenIndex(text, index + 1);
      spans.add(
        TextSpan(text: text.substring(index, nextToken), style: baseStyle),
      );
      index = nextToken;
    }

    return spans;
  }

  int _findNextInlineTokenIndex(String text, int start) {
    final tokenStarts = <int>[];
    final tokens = [r'\(', r'$', '**', '__', '~~', '`', '[', '*', '_'];

    for (final token in tokens) {
      final tokenIndex = text.indexOf(token, start);
      if (tokenIndex != -1) {
        tokenStarts.add(tokenIndex);
      }
    }

    if (tokenStarts.isEmpty) return text.length;
    tokenStarts.sort();
    return tokenStarts.first;
  }

  int _findClosingDollar(String text, int start) {
    for (int i = start; i < text.length; i++) {
      if (text[i] == r'$' && text[i - 1] != r'\') {
        return i;
      }
    }
    return -1;
  }

  Widget _buildInlineContent(
    String text, {
    bool isAnswer = false,
    bool isHeader = false,
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
  }) {
    final resolvedStyle = TextStyle(
      fontSize: fontSize ?? (isAnswer ? 16 : 14),
      fontWeight: fontWeight ?? FontWeight.normal,
      color:
          color ??
          (isAnswer ? const Color(0xFF10B981) : const Color(0xFF666666)),
      height: 1.5,
    );

    return RichText(
      text: TextSpan(
        style: resolvedStyle,
        children: _buildInlineSpans(
          text,
          baseStyle: resolvedStyle,
          isAnswer: isAnswer,
          isHeader: isHeader,
        ),
      ),
    );
  }

  Widget _buildParagraph(String text, {bool isAnswer = false}) {
    return _buildRichTextBlock(
      text,
      isAnswer: isAnswer,
      padding: const EdgeInsets.symmetric(vertical: 8),
    );
  }

  Widget _buildInlineMathText(String text, {bool isAnswer = false}) {
    return _buildRichTextBlock(
      text,
      isAnswer: isAnswer,
      padding: const EdgeInsets.symmetric(vertical: 4),
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
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: _buildMathWidget(mathContent.trim(), isInline: false),
        ),
      ),
    );
  }

  Widget _buildMathWidget(String mathContent, {bool isInline = true}) {
    final cleanMath = LatexRenderUtils.normalizeMathExpression(mathContent);

    return Container(
      padding: EdgeInsets.all(isInline ? 4 : 0),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Math.tex(
          cleanMath,
          textStyle: TextStyle(
            fontSize: isInline ? 14 : 16,
            color: Colors.blue.shade900,
          ),
          onErrorFallback: (FlutterMathException e) {
            print('Math rendering error: $e for expression: $cleanMath');
            final simplifiedMath = LatexRenderUtils.fallbackMathText(
              mathContent,
            );

            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Container(
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
              ),
            );
          },
        ),
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
      margin: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade700),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
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
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade800,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '${code.split('\n').length} lines',
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 11,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
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
                            Icon(
                              Icons.content_copy,
                              size: 14,
                              color: Colors.white,
                            ),
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
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Container(
                constraints: BoxConstraints(
                  minWidth: MediaQuery.of(context).size.width - 32,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: code.split('\n').asMap().entries.map((entry) {
                    final lineNumber = entry.key + 1;
                    final lineContent = entry.value;

                    return Container(
                      constraints: BoxConstraints(
                        minWidth: MediaQuery.of(context).size.width - 32,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
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
                          ConstrainedBox(
                            constraints: BoxConstraints(
                              minWidth: MediaQuery.of(context).size.width - 120,
                            ),
                            child: SelectableText(
                              lineContent,
                              style: const TextStyle(
                                fontFamily: 'RobotoMono',
                                fontSize: 14,
                                color: Color(0xFFD4D4D4),
                                height: 1.4,
                              ),
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
    return _buildRichTextBlock(
      text,
      padding: const EdgeInsets.symmetric(vertical: 4),
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
        return _buildImageFromSource(imageUrl, altText: altText);
      }
    } catch (e) {
      print('❌ Error in _buildImage: $e');
      print('   Line: $line');
    }

    return const SizedBox.shrink();
  }

  Widget _buildImageFromSource(String src, {String altText = ''}) {
    if (src.isEmpty) return const SizedBox.shrink();

    final imageUrl = _normalizeImageUrl(src);

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
          }

          return _buildImageContainer(
            image: Image.memory(snapshot.data!, fit: BoxFit.contain),
            altText: altText,
          );
        },
      );
    }

    if (imageUrl.startsWith('/') && !imageUrl.startsWith('http')) {
      print('🖼️ Loading local file image: $imageUrl');
      return _buildImageContainer(
        image: Image.file(
          File(imageUrl),
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            print('❌ Error loading local image: $error');
            return _buildErrorImage('Local image load failed');
          },
        ),
        altText: altText,
      );
    }

    final cleanUrl = imageUrl.replaceAll(RegExp(r'(?<!:)/{2,}'), '/');
    print('🖼️ Loading network image: $cleanUrl');

    return _buildImageContainer(
      image: CachedNetworkImage(
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
      altText: altText,
    );
  }

  Widget _buildImageContainer({required Widget image, String altText = ''}) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        children: [
          ClipRRect(borderRadius: BorderRadius.circular(8), child: image),
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
      child: _buildInlineContent(
        text,
        isHeader: true,
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
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

      final hasHeader = lines.length > 1 && _isMarkdownSeparatorLine(lines[1]);
      final rows = <List<String>>[];

      for (int i = 0; i < lines.length; i++) {
        if (hasHeader && i == 1) continue;
        if (lines[i].trim().isEmpty) continue;
        rows.add(_parseTableRow(lines[i]));
      }

      return _buildTable(rows, hasHeader: hasHeader);
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

  Widget _buildPlainTextTable(List<String> tableLines) {
    final rows = tableLines
        .map(
          (line) =>
              line.split(RegExp(r'\t+')).map((cell) => cell.trim()).toList(),
        )
        .toList();

    return _buildTable(rows, hasHeader: false);
  }

  Widget _buildHtmlTable(List<List<String>> rows, {bool hasHeader = false}) {
    if (rows.isEmpty) return const SizedBox.shrink();

    final normalizedRows = rows.map((row) => List<String>.from(row)).toList();
    final columnCount = normalizedRows
        .map((row) => row.length)
        .fold<int>(0, (maxColumns, rowLength) => max(maxColumns, rowLength));

    for (final row in normalizedRows) {
      while (row.length < columnCount) {
        row.add('');
      }
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
        color: Colors.white,
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: BoxConstraints(minWidth: columnCount * 200),
          child: Table(
            defaultVerticalAlignment: TableCellVerticalAlignment.middle,
            border: TableBorder.symmetric(
              inside: BorderSide(color: Colors.grey.shade300),
            ),
            columnWidths: {
              for (int i = 0; i < columnCount; i++)
                i: const IntrinsicColumnWidth(),
            },
            children: normalizedRows.asMap().entries.map((entry) {
              final rowIndex = entry.key;
              final row = entry.value;
              final isHeaderRow = hasHeader && rowIndex == 0;

              return TableRow(
                decoration: BoxDecoration(
                  color: isHeaderRow ? Colors.blue.shade50 : Colors.white,
                ),
                children: row.map((cellHtml) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    child: _buildHtmlTableCell(cellHtml, isHeader: isHeaderRow),
                  );
                }).toList(),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildHtmlTableCell(String cellHtml, {bool isHeader = false}) {
    final processedCellHtml = _replaceDollarMathWithCustomTags(
      _replaceCkEditorMathWithCustomTags(
        _normalizeCkEditorImageUrls(_convertMarkdownImagesToHtml(cellHtml)),
      ),
    );

    return Html(
      data: processedCellHtml,
      shrinkWrap: true,
      extensions: [
        TagExtension(
          tagsToExtend: {'tex-inline'},
          builder: (context) => _buildMathWidget(
            _decodeHtmlEntities(context.innerHtml.trim()),
            isInline: true,
          ),
        ),
        TagExtension(
          tagsToExtend: {'tex-block'},
          builder: (context) =>
              _buildMathBlock(_decodeHtmlEntities(context.innerHtml.trim())),
        ),
      ],
      style: {
        'html': Style(margin: Margins.zero, padding: HtmlPaddings.zero),
        'body': Style(
          margin: Margins.zero,
          padding: HtmlPaddings.zero,
          color: Colors.black87,
          fontSize: FontSize(isHeader ? 14 : 13),
          fontWeight: isHeader ? FontWeight.bold : FontWeight.normal,
          lineHeight: LineHeight(1.5),
        ),
        'p': Style(margin: Margins.zero, padding: HtmlPaddings.zero),
        'div': Style(margin: Margins.zero, padding: HtmlPaddings.zero),
        'strong': Style(fontWeight: FontWeight.bold),
        'b': Style(fontWeight: FontWeight.bold),
        'em': Style(fontStyle: FontStyle.italic),
        'i': Style(fontStyle: FontStyle.italic),
        'img': Style(margin: Margins.only(top: 6, bottom: 6)),
      },
    );
  }

  Widget _buildTable(List<List<String>> rows, {bool hasHeader = false}) {
    if (rows.isEmpty) return const SizedBox.shrink();

    final normalizedRows = rows.map((row) => List<String>.from(row)).toList();
    final columnCount = normalizedRows
        .map((row) => row.length)
        .fold<int>(0, (maxColumns, rowLength) => max(maxColumns, rowLength));

    for (final row in normalizedRows) {
      while (row.length < columnCount) {
        row.add('');
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
        child: ConstrainedBox(
          constraints: BoxConstraints(minWidth: columnCount * 180),
          child: Table(
            defaultVerticalAlignment: TableCellVerticalAlignment.middle,
            border: TableBorder.symmetric(
              inside: BorderSide(color: Colors.grey.shade300),
            ),
            columnWidths: {
              for (int i = 0; i < columnCount; i++)
                i: const IntrinsicColumnWidth(),
            },
            children: normalizedRows.asMap().entries.map((entry) {
              final rowIndex = entry.key;
              final row = entry.value;
              final isHeaderRow = hasHeader && rowIndex == 0;

              return TableRow(
                decoration: BoxDecoration(
                  color: isHeaderRow ? Colors.blue.shade50 : Colors.white,
                ),
                children: row.map((cell) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    child: _buildTableCellContent(cell, isHeader: isHeaderRow),
                  );
                }).toList(),
              );
            }).toList(),
          ),
        ),
      ),
    );
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
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 240),
      child: _buildInlineContent(
        cellContent,
        isHeader: isHeader,
        fontSize: isHeader ? 14 : 13,
        fontWeight: isHeader ? FontWeight.bold : FontWeight.normal,
        color: Colors.black87,
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

  // String _decodeHtmlEntities(String text) {
  //   return text
  //       .replaceAll('&nbsp;', ' ')
  //       .replaceAll('&amp;', '&')
  //       .replaceAll('&lt;', '<')
  //       .replaceAll('&gt;', '>')
  //       .replaceAll('&quot;', '"')
  //       .replaceAll('&#39;', "'")
  //       .replaceAll('&ldquo;', '"')
  //       .replaceAll('&rdquo;', '"')
  //       .replaceAll('&lsquo;', "'")
  //       .replaceAll('&rsquo;', "'")
  //       .replaceAll('&hellip;', '...')
  //       .replaceAll('&mdash;', '—')
  //       .replaceAll('&ndash;', '–')
  //       .replaceAll('&copy;', '©')
  //       .replaceAll('&reg;', '®')
  //       .replaceAll('&trade;', '™')
  //       .replaceAll('&times;', '×')
  //       .replaceAll('&divide;', '÷')
  //       .replaceAll('&plusmn;', '±');
  // }

  String _decodeHtmlEntities(String text) {
    return text
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&apos;', "'")
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
        .replaceAll('&plusmn;', '±')
        .replaceAll('&frac12;', '½')
        .replaceAll('&frac14;', '¼')
        .replaceAll('&frac34;', '¾')
        .replaceAll('&deg;', '°')
        .replaceAll('&micro;', 'µ')
        .replaceAll('&para;', '¶')
        .replaceAll('&middot;', '·');
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
    final theme = Theme.of(context);
    final subtitleColor =
        theme.textTheme.bodySmall?.color ?? const Color(0xFF6B7280);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
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
              style: TextStyle(fontSize: 11, color: subtitleColor),
            ),
          ],
        ),
        backgroundColor: theme.colorScheme.surface,
        foregroundColor: theme.colorScheme.onSurface,
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
