import 'dart:io';
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../../core/network/api_service.dart';
import '../../../core/constants/endpoints.dart';
import '../../../features/courses/models/course_models.dart';
import '../../../features/past_questions/models/past_question_models.dart';
import '../screens/past_questions_screen.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter/services.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:flutter/gestures.dart';
import 'package:flutter_markdown_latex/flutter_markdown_latex.dart';
import 'package:flutter_markdown_plus_latex/flutter_markdown_plus_latex.dart';
import 'dart:math'; // ADD THIS IMPORT
import 'package:flutter_html/flutter_html.dart';

class LectureScreen extends StatefulWidget {
  final dynamic course;
  final dynamic outline;
  final List<dynamic> outlines;
  final Function(bool)? onProgressUpdated;

  const LectureScreen({
    Key? key,
    required this.course,
    required this.outline,
    required this.outlines,
    this.onProgressUpdated,
  }) : super(key: key);

  @override
  State<LectureScreen> createState() => _LectureScreenState();
}

class _LectureScreenState extends State<LectureScreen> {
  late String selectedTopicId;
  late int selectedOutlineId;
  final ScrollController _scrollController = ScrollController();

  final ApiService _apiService = ApiService();
  final Connectivity _connectivity = Connectivity();

  bool _showWebViewError = false;

  List<Topic> _topics = [];
  Topic? _currentTopic;
  bool _isVoiceIconExpanded = true;
  Timer? _collapseTimer;
  bool _isLoading = true;
  bool _isLoadingContent = false;
  String _errorMessage = '';
  int _currentTopicIndex = 0;

  // WebView Controller
  WebViewController? _webViewController;
  bool _isVideoLoading = false;

  // Offline mode
  bool _isOfflineMode = false;
  bool _isCourseDownloaded = false;

  @override
  void initState() {
    super.initState();
    selectedOutlineId = _getOutlineId(widget.outline);
    selectedTopicId = '';

    _startCollapseTimer();
    _checkConnectivityAndLoad();
  }

  @override
  void dispose() {
    _collapseTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _checkConnectivityAndLoad() async {
    try {
      // Check if course is downloaded
      _isCourseDownloaded = await _isCourseDownloadedForOffline();

      // Check connectivity
      final connectivityResult = await _connectivity.checkConnectivity();
      _isOfflineMode = connectivityResult == ConnectivityResult.none;

      print(
        '📱 Connectivity: $_isOfflineMode, Course Downloaded: $_isCourseDownloaded',
      );

      if (_isOfflineMode && !_isCourseDownloaded) {
        setState(() {
          _isLoading = false;
          _errorMessage =
              'You are offline and this course is not downloaded. Please connect to the internet or download the course first.';
        });
        return;
      }

      await _loadTopics();
    } catch (e) {
      print('❌ Error checking connectivity: $e');
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to load content. Please try again.';
      });
    }
  }

  Future<bool> _isCourseDownloadedForOffline() async {
    try {
      final courseId = _getCourseId(widget.course);
      if (courseId.isEmpty) return false;

      final offlineBox = await Hive.openBox('offline_courses');
      final downloadedCourseIds = offlineBox.get(
        'downloaded_course_ids',
        defaultValue: <String>[],
      );

      return downloadedCourseIds.contains(courseId);
    } catch (e) {
      print('❌ Error checking if course is downloaded: $e');
      return false;
    }
  }

  void _startCollapseTimer() {
    _collapseTimer?.cancel();
    _collapseTimer = Timer(const Duration(seconds: 5), () {
      setState(() {
        _isVoiceIconExpanded = false;
      });
    });
  }

  Future<void> _loadTopics() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      print('📚 Loading topics for outline ID: $selectedOutlineId');

      List<Topic> topics = [];

      if (_isOfflineMode || _isCourseDownloaded) {
        // Try to load from offline storage
        print('📂 Loading topics from offline storage...');
        topics = await _getOfflineTopics(
          widget.course.id,
          selectedOutlineId.toString(),
        );

        if (topics.isNotEmpty) {
          print('✅ Loaded ${topics.length} topics from offline storage');
        } else if (!_isOfflineMode) {
          // Offline storage empty but we're online - try API
          print('📂 No offline topics, trying API...');
          topics = await _apiService.getTopics(outlineId: selectedOutlineId);
        } else {
          // Offline and no offline data available
          throw Exception(
            'No topics available offline. Please re-download the course.',
          );
        }
      } else {
        // Online mode - load from API
        print('🌐 Loading topics from API...');
        topics = await _apiService.getTopics(outlineId: selectedOutlineId);
      }

      if (topics.isNotEmpty) {
        setState(() {
          _topics = topics;
          _currentTopicIndex = 0;
          _currentTopic = topics.first;
          selectedTopicId = topics.first.id;
        });

        print('✅ Loaded ${topics.length} topics');

        // Initialize video for first topic if it has video
        if (_currentTopic?.videoUrl != null &&
            _currentTopic!.videoUrl!.isNotEmpty) {
          _initializeVideoPlayer(_currentTopic!.videoUrl!);
        }
      } else {
        setState(() {
          _topics = [];
          _errorMessage = 'No topics available for this outline';
        });
      }
    } catch (e) {
      print('❌ Error loading topics: $e');
      setState(() {
        _errorMessage = _isOfflineMode
            ? 'Failed to load offline content. Please try re-opening the course.'
            : 'Failed to load topics. Please try again.';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Get offline topics - FIXED VERSION
  Future<List<Topic>> _getOfflineTopics(
    String courseId,
    String outlineId,
  ) async {
    try {
      print(
        '🔍 Getting offline topics for course: $courseId, outline: $outlineId',
      );

      final offlineBox = await Hive.openBox('offline_courses');
      final courseData = offlineBox.get('course_$courseId');

      if (courseData == null) {
        print('❌ No course data found');
        return [];
      }

      final data = Map<String, dynamic>.from(courseData);
      print('📁 Found course data');

      if (data['topics'] != null && data['topics'] is List) {
        final topicsJson = data['topics'] as List;
        print('📚 Found ${topicsJson.length} total topics in offline storage');

        final allTopics = <Topic>[];

        // Parse all topics
        for (int i = 0; i < topicsJson.length; i++) {
          try {
            final topicData = topicsJson[i];

            if (topicData is Map<String, dynamic>) {
              final topic = Topic.fromJson(topicData);
              allTopics.add(topic);
            } else if (topicData is Map) {
              final json = Map<String, dynamic>.from(topicData);
              final topic = Topic.fromJson(json);
              allTopics.add(topic);
            }
          } catch (e) {
            print('⚠️ Error parsing topic $i: $e');
          }
        }

        print('✅ Parsed ${allTopics.length} topics');

        // Filter topics by outlineId
        final outlineTopics = allTopics.where((topic) {
          final matches = topic.outlineId == outlineId.toString();
          if (matches) {
            print('   📘 Topic matches outline: ${topic.title}');
          }
          return matches;
        }).toList();

        print(
          '📊 Filtered to ${outlineTopics.length} topics for outline $outlineId',
        );
        return outlineTopics;
      } else {
        print('❌ No topics found in offline storage');
        return [];
      }
    } catch (e) {
      print('❌ Error getting offline topics: $e');
      return [];
    }
  }
  // ########################

  // Get image URL - handles both online and offline
  String? _getImageUrl(String? imagePath) {
    if (imagePath == null || imagePath.isEmpty) return null;

    // Check if we have a local image path in offline storage
    if (_isOfflineMode || _isCourseDownloaded) {
      try {
        final courseId = _getCourseId(widget.course);
        final offlineBox = Hive.box('offline_courses');
        final courseData = offlineBox.get('course_$courseId');

        if (courseData != null && courseData['downloaded_images'] != null) {
          final downloadedImages = Map<String, String>.from(
            courseData['downloaded_images'],
          );

          // Try to find the image by topic ID
          if (_currentTopic != null &&
              downloadedImages.containsKey(_currentTopic!.id)) {
            final localPath = downloadedImages[_currentTopic!.id];
            if (localPath != null && File(localPath).existsSync()) {
              return localPath;
            }
          }

          // Try to find course image
          if (downloadedImages.containsKey('course_image')) {
            final localPath = downloadedImages['course_image'];
            if (localPath != null && File(localPath).existsSync()) {
              return localPath;
            }
          }

          // Try to find image by path
          for (final entry in downloadedImages.entries) {
            if (entry.key.contains('topic') &&
                entry.value.contains(imagePath.split('/').last)) {
              if (File(entry.value).existsSync()) {
                return entry.value;
              }
            }
          }
        }
      } catch (e) {
        print('⚠️ Error getting local image: $e');
      }
    }

    // Fall back to network image
    if (imagePath.startsWith('http')) {
      return imagePath;
    }

    String path = imagePath.replaceFirst('file://', '');
    final baseUrl = ApiEndpoints.baseUrl;
    return '$baseUrl$path';
  }

  void _initializeVideoPlayer(String videoUrl) {
    print('🎬 Initializing video player with URL: $videoUrl');

    setState(() {
      _isVideoLoading = true;
      _showWebViewError = false;
    });

    try {
      final videoId = _extractYouTubeVideoId(videoUrl);
      if (videoId == null) {
        setState(() {
          _isVideoLoading = false;
        });
        return;
      }

      // Create WebView controller with error detection
      _webViewController = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setNavigationDelegate(
          NavigationDelegate(
            onPageStarted: (url) {
              print('🌐 Page started loading: $url');
            },
            onPageFinished: (url) {
              print('✅ Page finished loading: $url');
              // Check for YouTube error pages
              if (url.contains('youtube.com/embed') &&
                  (url.contains('error') || url.contains('restricted'))) {
                print('⚠️ YouTube embed restriction detected');
                if (mounted) {
                  setState(() {
                    _showWebViewError = true;
                    _isVideoLoading = false;
                  });
                }
              } else if (mounted) {
                setState(() {
                  _isVideoLoading = false;
                });
              }
            },
            onWebResourceError: (error) {
              print(
                '❌ Web resource error: ${error.errorCode} - ${error.description}',
              );
              // YouTube embed error codes
              if (error.errorCode == 153 || error.errorCode == 150) {
                print('⚠️ YouTube embed restriction error');
                if (mounted) {
                  setState(() {
                    _showWebViewError = true;
                    _isVideoLoading = false;
                  });
                }
              }
            },
          ),
        )
        ..loadRequest(Uri.parse('https://www.youtube.com/embed/$videoId'));

      // Set timeout
      Future.delayed(const Duration(seconds: 8), () {
        if (mounted && _isVideoLoading) {
          print('⚠️ Loading timeout');
          setState(() {
            _isVideoLoading = false;
            _showWebViewError = true;
          });
        }
      });
    } catch (e) {
      print('❌ Error initializing video player: $e');
      if (mounted) {
        setState(() {
          _isVideoLoading = false;
          _showWebViewError = true;
        });
      }
    }
  }

  String? _getYouTubeEmbedUrl(String url) {
    try {
      final videoId = _extractYouTubeVideoId(url);
      if (videoId == null) return null;

      // Create embed URL
      return 'https://www.youtube.com/embed/$videoId?autoplay=0&modestbranding=1&rel=0&showinfo=0&controls=1';
    } catch (e) {
      print('Error creating embed URL: $e');
      return null;
    }
  }

  String? _extractYouTubeVideoId(String url) {
    try {
      String cleanUrl = url.trim();

      // Handle youtu.be links
      if (cleanUrl.contains('youtu.be/')) {
        var parts = cleanUrl.split('youtu.be/');
        if (parts.length > 1) {
          String videoId = parts[1].split('?')[0].split('&')[0];
          if (videoId.length == 11) return videoId;
        }
      }

      // Handle youtube.com/watch?v=VIDEO_ID
      if (cleanUrl.contains('youtube.com/watch')) {
        var uri = Uri.parse(cleanUrl);
        String? videoId = uri.queryParameters['v'];
        if (videoId != null && videoId.length == 11) return videoId;
      }

      // Handle youtube.com/embed/VIDEO_ID
      if (cleanUrl.contains('youtube.com/embed/')) {
        var parts = cleanUrl.split('embed/');
        if (parts.length > 1) {
          String videoId = parts[1].split('?')[0].split('&')[0];
          if (videoId.length == 11) return videoId;
        }
      }

      // Fallback regex
      final RegExp regex = RegExp(
        r'(?:youtube\.com\/(?:[^\/]+\/.+\/|(?:v|e(?:mbed)?)\/|.*[?&]v=)|youtu\.be\/)([^"&?\/\s]{11})',
        caseSensitive: false,
      );

      final match = regex.firstMatch(cleanUrl);
      return match?.group(1);
    } catch (e) {
      print('Error extracting YouTube video ID: $e');
      return null;
    }
  }

  void _selectTopic(int index) {
    if (index < 0 || index >= _topics.length) return;

    setState(() {
      _currentTopicIndex = index;
      _currentTopic = _topics[index];
      selectedTopicId = _topics[index].id;
      _scrollController.jumpTo(0);
      _isVideoLoading = false;
    });

    // Initialize video if exists
    if (_currentTopic?.videoUrl != null &&
        _currentTopic!.videoUrl!.isNotEmpty) {
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted && _currentTopic?.videoUrl != null) {
          _initializeVideoPlayer(_currentTopic!.videoUrl!);
        }
      });
    } else {
      _webViewController = null;
    }
  }

  void _navigateToNextTopic() {
    if (_currentTopicIndex < _topics.length - 1) {
      _selectTopic(_currentTopicIndex + 1);
    } else if (_currentTopicIndex == _topics.length - 1) {
      _showCompletionDialog();
    }
  }

  void _navigateToPreviousTopic() {
    if (_currentTopicIndex > 0) {
      _selectTopic(_currentTopicIndex - 1);
    }
  }

  void _initializeYouTubePlayer(String videoUrl) {
    print('🎬 Preparing video: $videoUrl');
    // No need to initialize anything - we'll show thumbnail immediately
    setState(() {
      _isVideoLoading = false;
    });
  }

  Future<void> _showCompletionQuestion() async {
    if (_currentTopic == null ||
        _currentTopic!.completionQuestionText == null) {
      _navigateToNextTopic();
      return;
    }

    // Check if we can submit answers (need internet connection)
    if (_isOfflineMode) {
      _showOfflineCompletionDialog();
      return;
    }

    await showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.7),
      builder: (context) => WillPopScope(
        onWillPop: () async {
          return false;
        },
        child: CompletionQuestionDialog(
          topic: _currentTopic!,
          onAnswerSubmitted: (bool isCorrect) async {
            if (isCorrect) {
              try {
                print(
                  '✅ Correct answer! Topic will be marked as completed by Django...',
                );

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Correct! Topic marked as completed.'),
                    backgroundColor: Colors.green,
                    duration: const Duration(seconds: 2),
                  ),
                );

                await _refreshTopics();
                await _updateCourseProgressInCache();

                if (widget.onProgressUpdated != null) {
                  widget.onProgressUpdated!(true);
                }

                if (mounted) {
                  Navigator.pop(context);
                  await Future.delayed(const Duration(milliseconds: 300));
                  _navigateToNextTopic();
                }
              } catch (e) {
                print('❌ Error: $e');
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error: ${e.toString()}'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Incorrect answer. Try again!'),
                  backgroundColor: Colors.red,
                  duration: const Duration(seconds: 2),
                ),
              );

              if (mounted) {
                Navigator.pop(context);
              }
            }
          },
          onSkip: () {
            Navigator.pop(context);
            _navigateToNextTopic();
          },
        ),
      ),
    );
  }

  Future<void> _refreshTopics() async {
    try {
      setState(() {
        _isLoading = true;
      });

      List<Topic> topics = [];

      if (_isOfflineMode || _isCourseDownloaded) {
        topics = await _getOfflineTopics(
          widget.course.id,
          selectedOutlineId.toString(),
        );
      } else {
        topics = await _apiService.getTopics(outlineId: selectedOutlineId);
      }

      if (topics.isNotEmpty) {
        setState(() {
          _topics = topics;
          if (_currentTopic != null) {
            final currentIndex = topics.indexWhere(
              (t) => t.id == _currentTopic!.id,
            );
            if (currentIndex != -1) {
              _currentTopic = topics[currentIndex];
              _currentTopicIndex = currentIndex;
              selectedTopicId = _currentTopic!.id;
            }
          }
        });
        print(
          '✅ Topics refreshed. Completed: ${topics.where((t) => t.isCompleted).length}/${topics.length}',
        );
      }
    } catch (e) {
      print('⚠️ Error refreshing topics: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _updateCourseProgressInCache() async {
    try {
      final courseId = _getCourseId(widget.course);
      if (courseId.isEmpty) return;

      int completedCount = _topics.where((topic) => topic.isCompleted).length;
      int totalTopics = _topics.length;
      int progress = totalTopics > 0
          ? ((completedCount / totalTopics) * 100).round()
          : 0;

      final box = await Hive.openBox('course_progress_cache');
      await box.put('progress_$courseId', progress);

      print('💾 Updated course $courseId progress in cache: $progress%');
    } catch (e) {
      print('⚠️ Error updating course progress cache: $e');
    }
  }

  // Future<void> _showRelatedPastQuestions() async {
  //   if (_currentTopic == null) return;

  //   setState(() {
  //     _isLoadingContent = true;
  //   });

  //   try {
  //     await Navigator.push(
  //       context,
  //       MaterialPageRoute(
  //         builder: (context) => RelatedPastQuestionsScreen(
  //           courseId: _getCourseId(widget.course),
  //           courseCode: _getCourseCode(widget.course),
  //           topicTitle: _currentTopic!.title,
  //           topicId: _currentTopic!.id,
  //         ),
  //       ),
  //     );
  //   } catch (e) {
  //     print('❌ Error showing related past questions: $e');
  //     ScaffoldMessenger.of(context).showSnackBar(
  //       SnackBar(
  //         content: Text('Failed to load past questions: ${e.toString()}'),
  //         backgroundColor: Colors.red,
  //       ),
  //     );
  //   } finally {
  //     if (mounted) {
  //       setState(() {
  //         _isLoadingContent = false;
  //       });
  //     }
  //   }
  // }

  // Future<void> _showRelatedPastQuestions() async {
  //   if (_currentTopic == null) return;

  //   setState(() {
  //     _isLoadingContent = true;
  //   });

  //   try {
  //     await Navigator.push(
  //       context,
  //       MaterialPageRoute(
  //         builder: (context) => RelatedPastQuestionsScreen(
  //           courseId: _getCourseId(widget.course),
  //           courseName:
  //               widget.course['name'] ??
  //               widget.course['course_name'] ??
  //               widget.course['title'] ??
  //               'Course',
  //           topicTitle: _currentTopic!.title,
  //           topicId: _currentTopic!.id,
  //           sessionId: widget.course['session_id']?.toString(),
  //           sessionName: widget.course['session_name'] ?? 'Related Questions',
  //         ),
  //       ),
  //     );
  //   } catch (e) {
  //     print('❌ Error showing related past questions: $e');
  //     ScaffoldMessenger.of(context).showSnackBar(
  //       SnackBar(
  //         content: Text('Failed to load past questions: ${e.toString()}'),
  //         backgroundColor: Colors.red,
  //       ),
  //     );
  //   } finally {
  //     if (mounted) {
  //       setState(() {
  //         _isLoadingContent = false;
  //       });
  //     }
  //   }
  // }

  Future<void> _showRelatedPastQuestions() async {
    if (_currentTopic == null) return;

    setState(() {
      _isLoadingContent = true;
    });

    try {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => RelatedPastQuestionsScreen(
            courseId: _getCourseId(widget.course),
            courseName: 'Course', // Temporary hardcoded value
            topicTitle: _currentTopic!.title,
            topicId: _currentTopic!.id,
            sessionId: null, // Temporarily set to null
            sessionName: 'Related Questions',
          ),
        ),
      );
    } catch (e) {
      print('❌ Error showing related past questions: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load past questions: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingContent = false;
        });
      }
    }
  }

  Future<void> _playVideoInBrowser() async {
    if (_currentTopic?.videoUrl == null || _currentTopic!.videoUrl!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('No video available for this topic'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final Uri url = Uri.parse(_currentTopic!.videoUrl!);
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Could not open video'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showCompletionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('🎉 Congratulations!', textAlign: TextAlign.center),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle, size: 60, color: Colors.green),
            const SizedBox(height: 20),
            const Text(
              'You have completed all topics in this outline!',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16),
            ),
            if (_isOfflineMode)
              Container(
                margin: const EdgeInsets.only(top: 10),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Note: Quiz answers will sync when you reconnect to the internet',
                  style: TextStyle(fontSize: 12, color: Colors.blue),
                  textAlign: TextAlign.center,
                ),
              ),
          ],
        ),
        actions: [
          Center(
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pop(context);
              },
              child: const Text('Return to Outline'),
            ),
          ),
        ],
      ),
    );
  }

  void _expandVoiceIcon() {
    setState(() {
      _isVoiceIconExpanded = true;
    });
    _startCollapseTimer();
  }

  // Show dialog for offline completion
  void _showOfflineCompletionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(
              Icons.wifi_off_rounded,
              color: Colors.orange.shade600,
              size: 28,
            ),
            const SizedBox(width: 12),
            const Text(
              'Offline Mode',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Quiz requires internet connection.',
              style: TextStyle(
                fontSize: 15,
                height: 1.4,
                color: Color(0xFF666666),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    color: Colors.blue.shade600,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'To take quizzes:',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.blue.shade800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Connect to the internet and return to this topic',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.blue.shade700,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Color(0xFF666666)),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _navigateToNextTopic();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF667eea),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text(
              'Skip for Now',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  // Helper methods
  int _getOutlineId(dynamic outline) {
    try {
      if (outline is Map) {
        return int.tryParse(outline['id']?.toString() ?? '') ?? 0;
      } else if (outline is CourseOutline) {
        return int.tryParse(outline.id) ?? 0;
      }
      return 0;
    } catch (e) {
      print('Error getting outline ID: $e');
      return 0;
    }
  }

  String _getOutlineTitle(dynamic outline) {
    if (outline is Map) {
      return outline['title'] ?? 'Untitled';
    } else if (outline is CourseOutline) {
      return outline.title;
    }
    return 'Untitled';
  }

  String _getCourseId(dynamic course) {
    try {
      if (course is Map) {
        return course['id']?.toString() ?? '';
      } else if (course is Course) {
        return course.id;
      }
      return '';
    } catch (e) {
      print('Error getting course ID: $e');
      return '';
    }
  }

  String _getCourseCode(dynamic course) {
    if (course is Map) {
      return course['code'] ?? 'Course';
    } else if (course is Course) {
      return course.code;
    }
    return 'Course';
  }

  Color _getCourseColor(dynamic course) {
    try {
      if (course is Map) {
        final color = course['color'];
        if (color is int) {
          return Color(color);
        } else if (color is String && color.startsWith('#')) {
          return Color(int.parse(color.replaceFirst('#', '0xFF')));
        } else if (color is String && color.startsWith('0x')) {
          return Color(int.parse(color));
        }
        return const Color(0xFF667eea);
      } else if (course is Course) {
        return course.color;
      }
      return const Color(0xFF667eea);
    } catch (e) {
      print('Error getting course color: $e');
      return const Color(0xFF667eea);
    }
  }

  // ========== UI BUILDING METHODS (KEEPING YOUR EXISTING CODE) ==========

  @override
  Widget build(BuildContext context) {
    final courseColor = _getCourseColor(widget.course);

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          Column(
            children: [
              _buildHeader(courseColor),

              // Offline indicator banner
              if (_isOfflineMode && _isCourseDownloaded)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  color: Colors.green.withOpacity(0.1),
                  child: Row(
                    children: [
                      Icon(
                        Icons.download_done_rounded,
                        size: 16,
                        color: Colors.green.shade700,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Offline Mode - Downloaded Content',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.green.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const Spacer(),
                      if (_isOfflineMode)
                        Icon(
                          Icons.wifi_off_rounded,
                          size: 16,
                          color: Colors.green.shade700,
                        ),
                    ],
                  ),
                ),

              Expanded(
                child: _isLoading
                    ? _buildLoadingState()
                    : _errorMessage.isNotEmpty
                    ? _buildErrorState()
                    : _currentTopic == null
                    ? _buildEmptyState()
                    : SingleChildScrollView(
                        controller: _scrollController,
                        child: Column(
                          children: [
                            _buildProgressSection(courseColor),
                            _buildTopicSelector(courseColor),
                            _buildContent(courseColor),
                            const SizedBox(height: 20),
                            _buildPastQuestionsButton(courseColor),
                            const SizedBox(height: 100),
                          ],
                        ),
                      ),
              ),
            ],
          ),

          // Floating AI Voice Icon (only show if not offline)
          if (!_isOfflineMode)
            Positioned(
              bottom: 80,
              right: 20,
              child: GestureDetector(
                onTap: _expandVoiceIcon,
                child: _buildFloatingVoiceIcon(courseColor),
              ),
            ),

          // Bottom Navigation
          if (!_isLoading && _errorMessage.isEmpty && _currentTopic != null)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: _buildBottomNavigation(courseColor),
            ),
        ],
      ),
    );
  }

  Widget _buildHeader(Color courseColor) {
    final courseCode = _getCourseCode(widget.course);
    final outlineTitle = _getOutlineTitle(widget.outline);

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [courseColor, _darkenColor(courseColor, 0.3)],
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  size: 20,
                  color: Colors.white,
                ),
                onPressed: () => Navigator.pop(context),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      outlineTitle,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      courseCode,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withOpacity(0.9),
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

  Widget _buildProgressSection(Color courseColor) {
    int completedCount = _topics.where((topic) => topic.isCompleted).length;
    int totalTopics = _topics.length;
    double progress = totalTopics > 0
        ? (completedCount / totalTopics) * 100
        : 0;

    final screenWidth = MediaQuery.of(context).size.width;
    final availableWidth = screenWidth - 40;
    final progressWidth = availableWidth * (progress / 100);

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Outline Progress',
                      style: TextStyle(
                        fontSize: 14,
                        color: const Color(0xFF666666),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Stack(
                      children: [
                        Container(
                          height: 6,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0F0F0),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 800),
                          curve: Curves.easeOut,
                          height: 6,
                          width: progressWidth,
                          decoration: BoxDecoration(
                            color: courseColor,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 15),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 500),
                    child: Text(
                      '${progress.round()}%',
                      key: ValueKey<double>(progress),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: courseColor,
                      ),
                    ),
                  ),
                  Text(
                    '$completedCount/$totalTopics',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF999999),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (_currentTopic != null && _currentTopic!.isCompleted)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.withOpacity(0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle, size: 16, color: Colors.green),
                  const SizedBox(width: 6),
                  const Text(
                    'Topic Completed',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.green,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTopicSelector(Color courseColor) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Select Topic',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF333333),
                  ),
                ),
              ),
              Text(
                '${_currentTopicIndex + 1}/${_topics.length}',
                style: const TextStyle(fontSize: 14, color: Color(0xFF999999)),
              ),
            ],
          ),
          const SizedBox(height: 10),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE0E0E0)),
            ),
            child: DropdownButton<Topic>(
              value: _currentTopic,
              isExpanded: true,
              underline: const SizedBox(),
              icon: Icon(Icons.arrow_drop_down, color: courseColor),
              onChanged: (Topic? newValue) {
                if (newValue != null) {
                  final index = _topics.indexWhere(
                    (topic) => topic.id == newValue.id,
                  );
                  if (index != -1) {
                    _selectTopic(index);
                  }
                }
              },
              selectedItemBuilder: (context) {
                return _topics.map<Widget>((Topic topic) {
                  return Container(
                    constraints: BoxConstraints(
                      minHeight: 48,
                      maxWidth: MediaQuery.of(context).size.width - 100,
                    ),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Row(
                        children: [
                          if (topic.isCompleted)
                            const Icon(
                              Icons.check_circle,
                              size: 16,
                              color: Colors.green,
                            ),
                          if (topic.isCompleted) const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              '${topic.order}. ${topic.title}',
                              style: const TextStyle(
                                fontSize: 14,
                                color: Color(0xFF333333),
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList();
              },
              itemHeight: 50,
              dropdownColor: Colors.white,
              borderRadius: BorderRadius.circular(8),
              elevation: 4,
              menuMaxHeight: 400,
              items: _topics.map<DropdownMenuItem<Topic>>((Topic topic) {
                final isCompleted = topic.isCompleted;
                final isSelected = topic.id == _currentTopic?.id;

                return DropdownMenuItem<Topic>(
                  value: topic,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        if (isCompleted)
                          const Icon(
                            Icons.check_circle,
                            size: 16,
                            color: Colors.green,
                          ),
                        if (isCompleted) const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${topic.order}. ${topic.title}',
                            style: TextStyle(
                              fontSize: 14,
                              color: isSelected
                                  ? courseColor
                                  : const Color(0xFF333333),
                              fontWeight: isSelected
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(Color courseColor) {
    final topic = _currentTopic!;
    final imageUrl = _getImageUrl(topic.image);

    return Container(
      margin: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Media Section (Video/Image)
          if (topic.videoUrl != null && topic.videoUrl!.isNotEmpty)
            _buildVideoSection(topic, courseColor)
          else if (imageUrl != null && imageUrl.isNotEmpty)
            _buildImageSection(imageUrl, topic.title, courseColor)
          else
            _buildPlaceholderSection(courseColor),

          // Content Card
          _buildContentCard(topic, courseColor),
        ],
      ),
    );
  }

  Widget _buildVideoSection(Topic topic, Color courseColor) {
    return Container(
      width: double.infinity,
      height: 220,
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: _buildVideoPlayer(),
      ),
    );
  }

  Widget _buildVideoPlayer() {
    final videoId = _currentTopic?.videoUrl != null
        ? _extractYouTubeVideoId(_currentTopic!.videoUrl!)
        : null;

    return _buildVideoThumbnail(videoId);
  }

  Widget _buildVideoThumbnail(String? videoId) {
    return GestureDetector(
      onTap: () async {
        // Show loading indicator while preparing to open
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const CircularProgressIndicator(color: Colors.white),
                const SizedBox(width: 15),
                const Text('Opening YouTube...'),
              ],
            ),
            duration: const Duration(seconds: 2),
          ),
        );

        // Try to open in YouTube app first
        final youtubeAppUri = Uri.parse('vnd.youtube:$videoId');

        if (await canLaunchUrl(youtubeAppUri)) {
          await launchUrl(youtubeAppUri, mode: LaunchMode.externalApplication);
        } else {
          // Fallback to browser
          await _playVideoInBrowser();
        }
      },
      child: Container(
        color: Colors.black,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // YouTube thumbnail with loading fallback
            if (videoId != null)
              Image.network(
                'https://img.youtube.com/vi/$videoId/maxresdefault.jpg',
                width: double.infinity,
                height: double.infinity,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Container(
                    color: Colors.grey[900],
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
                  return Container(
                    color: Colors.grey[900],
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.videocam_off,
                            size: 60,
                            color: Colors.grey[700],
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            'Video Preview',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              )
            else
              Container(
                color: Colors.grey[900],
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.videocam_off,
                        size: 60,
                        color: Colors.grey[700],
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Video Not Available',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ),

            // Dark overlay
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black.withOpacity(0.7)],
                  stops: const [0.5, 1],
                ),
              ),
            ),

            // Play button overlay
            Center(
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.95),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.5),
                      blurRadius: 15,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.play_arrow_rounded,
                  size: 60,
                  color: Colors.white,
                ),
              ),
            ),

            // YouTube badge
            Positioned(
              top: 15,
              right: 15,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 5,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const Icon(Icons.play_arrow, size: 16, color: Colors.white),
                    const SizedBox(width: 6),
                    const Text(
                      'YouTube',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Video title and info (at the bottom)
            Positioned(
              bottom: 20,
              left: 20,
              right: 20,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _currentTopic?.title ?? 'Video',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      shadows: [Shadow(color: Colors.black, blurRadius: 8)],
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(
                        Icons.touch_app,
                        size: 16,
                        color: Colors.white70,
                      ),
                      const SizedBox(width: 5),
                      const Text(
                        'Tap to watch in YouTube app',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                          shadows: [Shadow(color: Colors.black, blurRadius: 5)],
                        ),
                      ),
                    ],
                  ),
                  if (_currentTopic?.durationMinutes != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.timer,
                            size: 16,
                            color: Colors.white70,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            '${_currentTopic!.durationMinutes} min',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageSection(String imageUrl, String title, Color courseColor) {
    return Container(
      width: double.infinity,
      height: 200,
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        image: DecorationImage(
          image: imageUrl.startsWith('http')
              ? NetworkImage(imageUrl) as ImageProvider
              : FileImage(File(imageUrl)),
          fit: BoxFit.cover,
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [Colors.black.withOpacity(0.7), Colors.transparent],
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              bottom: 10,
              left: 10,
              right: 10,
              child: Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholderSection(Color courseColor) {
    return Container(
      width: double.infinity,
      height: 150,
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: courseColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: courseColor.withOpacity(0.3)),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.image_not_supported,
              size: 40,
              color: courseColor.withOpacity(0.5),
            ),
            const SizedBox(height: 10),
            Text(
              'No media available',
              style: TextStyle(
                color: courseColor.withOpacity(0.7),
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Widget _buildContentCard(Topic topic, Color courseColor) {
  //   return Material(
  //     elevation: 4,
  //     borderRadius: BorderRadius.circular(20),
  //     child: Container(
  //       width: double.infinity,
  //       decoration: BoxDecoration(
  //         color: Colors.white,
  //         borderRadius: BorderRadius.circular(20),
  //       ),
  //       child: Padding(
  //         padding: const EdgeInsets.all(25),
  //         child: Column(
  //           crossAxisAlignment: CrossAxisAlignment.start,
  //           children: [
  //             Text(
  //               topic.title,
  //               style: const TextStyle(
  //                 fontSize: 20,
  //                 fontWeight: FontWeight.bold,
  //                 color: Color(0xFF333333),
  //                 height: 1.3,
  //               ),
  //             ),
  //             if (topic.description != null &&
  //                 topic.description!.isNotEmpty) ...[
  //               const SizedBox(height: 10),
  //               Text(
  //                 topic.description!,
  //                 style: const TextStyle(
  //                   fontSize: 16,
  //                   color: Color(0xFF666666),
  //                   fontStyle: FontStyle.italic,
  //                 ),
  //               ),
  //             ],
  //             const SizedBox(height: 15),

  //             // Stats
  //             Container(
  //               padding: const EdgeInsets.all(16),
  //               decoration: BoxDecoration(
  //                 color: const Color(0xFFF8F9FA),
  //                 borderRadius: BorderRadius.circular(12),
  //               ),
  //               child: Row(
  //                 mainAxisAlignment: MainAxisAlignment.spaceAround,
  //                 children: [
  //                   if (topic.durationMinutes != null)
  //                     _buildStatItem(
  //                       Icons.schedule_rounded,
  //                       '${topic.durationMinutes} min',
  //                       'Duration',
  //                     ),
  //                   _buildStatItem(
  //                     Icons.book_rounded,
  //                     'Topic ${topic.order}',
  //                     'Position',
  //                   ),
  //                   if (topic.completionQuestionText != null &&
  //                       topic.completionQuestionText!.isNotEmpty)
  //                     _buildStatItem(Icons.quiz_rounded, 'Quiz', 'Assessment'),
  //                 ],
  //               ),
  //             ),
  //             const SizedBox(height: 25),

  //             // Content
  //             if (topic.content != null && topic.content!.isNotEmpty)
  //               _buildFormattedContent(topic.content!)
  //             else
  //               Text(
  //                 'No detailed content available for this topic.',
  //                 style: const TextStyle(
  //                   fontSize: 16,
  //                   color: Color(0xFF999999),
  //                   fontStyle: FontStyle.italic,
  //                 ),
  //               ),
  //           ],
  //         ),
  //       ),
  //     ),
  //   );
  // }

  Widget _buildContentCard(Topic topic, Color courseColor) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(25),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              topic.title,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Color(0xFF333333),
                height: 1.3,
              ),
            ),
            if (topic.description != null && topic.description!.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8F9FA),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE0E0E0)),
                ),
                child: Text(
                  topic.description!,
                  style: const TextStyle(
                    fontSize: 16,
                    color: Color(0xFF666666),
                    fontStyle: FontStyle.italic,
                    height: 1.5,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 20),

            // Stats - make it more compact
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF8F9FA),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  if (topic.durationMinutes != null)
                    _buildStatItem(
                      Icons.schedule_rounded,
                      '${topic.durationMinutes} min',
                      'Duration',
                    ),
                  _buildStatItem(
                    Icons.book_rounded,
                    'Topic ${topic.order}',
                    'Position',
                  ),
                  if (topic.completionQuestionText != null &&
                      topic.completionQuestionText!.isNotEmpty)
                    _buildStatItem(Icons.quiz_rounded, 'Quiz', 'Assessment'),
                ],
              ),
            ),
            const SizedBox(height: 25),

            // Content - with more space
            if (topic.content != null && topic.content!.isNotEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: _buildFormattedContent(topic.content!),
              )
            else
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8F9FA),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE0E0E0)),
                ),
                child: const Center(
                  child: Text(
                    'No detailed content available for this topic.',
                    style: TextStyle(
                      fontSize: 16,
                      color: Color(0xFF999999),
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // Widget _buildFormattedContent(String content) {
  //   // Convert CKEditor HTML to clean markdown
  //   final cleanContent = _convertCkEditorToMarkdown(content);

  //   return Container(
  //     constraints: BoxConstraints(
  //       minHeight: 50, // Minimum height to avoid unconstrained errors
  //     ),
  //     child: SingleChildScrollView(
  //       child: Column(
  //         crossAxisAlignment: CrossAxisAlignment.start,
  //         children: _parseContentForLecture(cleanContent),
  //       ),
  //     ),
  //   );
  // }

  Widget _buildFormattedContent(String content) {
    // Convert CKEditor HTML to clean markdown
    final cleanContent = _convertCkEditorToMarkdown(content);

    return Container(
      width: double.infinity,
      constraints: BoxConstraints(minHeight: 50),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: _parseContentForLecture(cleanContent),
      ),
    );
  }

  // String _convertCkEditorToMarkdown(String htmlContent) {
  //   if (htmlContent.isEmpty) return '';

  //   String result = htmlContent;

  //   // Debug: Print raw HTML
  //   print(
  //     '📝 Raw HTML: ${htmlContent.substring(0, min(200, htmlContent.length))}...',
  //   );

  //   // 1. Handle tables FIRST (important to do this before removing other tags)
  //   result = _convertHtmlTablesToMarkdown(result);

  //   // 2. Convert math equations
  //   result = result.replaceAllMapped(
  //     RegExp(
  //       r'<span[^>]*class="math-tex"[^>]*>(.*?)</span>',
  //       caseSensitive: false,
  //       dotAll: true,
  //     ),
  //     (match) {
  //       final mathContent = match.group(1) ?? '';
  //       // Clean math content
  //       final cleanMath = mathContent
  //           .replaceAll('&lt;', '<')
  //           .replaceAll('&gt;', '>')
  //           .replaceAll('&amp;', '&');
  //       return '\$$cleanMath\$';
  //     },
  //   );

  //   // 3. Handle MathJax/LaTeX blocks
  //   result = result.replaceAllMapped(
  //     RegExp(
  //       r'<script[^>]*type="math/tex"[^>]*>(.*?)</script>',
  //       caseSensitive: false,
  //       dotAll: true,
  //     ),
  //     (match) {
  //       final mathContent = match.group(1) ?? '';
  //       return '\$\$$mathContent\$\$';
  //     },
  //   );

  //   result = result.replaceAllMapped(
  //     RegExp(
  //       r'<script[^>]*type="math/tex; mode=display"[^>]*>(.*?)</script>',
  //       caseSensitive: false,
  //       dotAll: true,
  //     ),
  //     (match) {
  //       final mathContent = match.group(1) ?? '';
  //       return '\$\$$mathContent\$\$';
  //     },
  //   );

  //   // 4. Convert code blocks
  //   result = result.replaceAllMapped(
  //     RegExp(r'<pre[^>]*>(.*?)</pre>', caseSensitive: false, dotAll: true),
  //     (match) {
  //       final preContent = match.group(1) ?? '';
  //       String codeContent = preContent;

  //       // Extract language from class
  //       String language = '';
  //       final classMatch = RegExp(
  //         r'class="([^"]*)"',
  //       ).firstMatch(match.group(0) ?? '');
  //       if (classMatch != null) {
  //         final classes = classMatch.group(1)!.split(' ');
  //         for (final cls in classes) {
  //           if (cls.startsWith('language-')) {
  //             language = cls.replaceFirst('language-', '');
  //             break;
  //           }
  //         }
  //       }

  //       // Clean code content
  //       codeContent = codeContent
  //           .replaceAll('<code>', '')
  //           .replaceAll('</code>', '')
  //           .replaceAll('&lt;', '<')
  //           .replaceAll('&gt;', '>')
  //           .replaceAll('&amp;', '&')
  //           .trim();

  //       return '```$language\n$codeContent\n```';
  //     },
  //   );

  //   // 5. Convert inline code
  //   result = result.replaceAllMapped(
  //     RegExp(r'<code[^>]*>(.*?)</code>', caseSensitive: false),
  //     (match) {
  //       final codeContent = match.group(1) ?? '';
  //       final cleanCode = codeContent
  //           .replaceAll('&lt;', '<')
  //           .replaceAll('&gt;', '>')
  //           .replaceAll('&amp;', '&');
  //       return '`$cleanCode`';
  //     },
  //   );

  //   // 6. Convert images with proper handling
  //   result = result.replaceAllMapped(
  //     RegExp(r'<img[^>]*>', caseSensitive: false),
  //     (match) {
  //       final imgTag = match.group(0)!;
  //       String? src, alt;

  //       // Extract src
  //       final srcMatch = RegExp(r'src="([^"]*)"').firstMatch(imgTag);
  //       if (srcMatch != null) src = srcMatch.group(1);

  //       // Extract alt
  //       final altMatch = RegExp(r'alt="([^"]*)"').firstMatch(imgTag);
  //       if (altMatch != null) alt = altMatch.group(1);

  //       // Extract title
  //       final titleMatch = RegExp(r'title="([^"]*)"').firstMatch(imgTag);
  //       final title = titleMatch?.group(1);

  //       // if (src == null) return '';

  //       // If no src, return empty
  //       if (src == null || src.isEmpty) return '';

  //       // Handle relative URLs
  //       String imageUrl = src;

  //       // Check if it's already a full URL
  //       if (!src.startsWith('http://') && !src.startsWith('https://')) {
  //         // It's a relative URL
  //         if (src.startsWith('/')) {
  //           // Path starts with /, append to base URL
  //           final baseUrl = ApiEndpoints.baseUrl;
  //           imageUrl = '$baseUrl$src';
  //         } else if (src.startsWith('media/') || src.startsWith('/media/')) {
  //           // Django media path
  //           final baseUrl = ApiEndpoints.baseUrl;
  //           if (src.startsWith('media/')) {
  //             imageUrl = '$baseUrl/$src';
  //           } else {
  //             imageUrl = '$baseUrl$src';
  //           }
  //         } else if (src.startsWith('uploads/')) {
  //           // CKEditor uploads path
  //           final baseUrl = ApiEndpoints.baseUrl;
  //           imageUrl = '$baseUrl/media/$src';
  //         } else {
  //           // Assume it's a relative path from media
  //           final baseUrl = ApiEndpoints.baseUrl;
  //           imageUrl = '$baseUrl/media/$src';
  //         }
  //       }

  //       // Clean up any double slashes
  //       imageUrl = imageUrl.replaceAll('//media/', '/media/');
  //       imageUrl = imageUrl.replaceAll(':/', '://');

  //       // Use title as alt text if alt is empty
  //       final displayAlt = alt?.isNotEmpty == true ? alt : title ?? '';

  //       print('🖼️ Image URL: $imageUrl');
  //       print('🖼️ Alt text: $displayAlt');

  //       return '![${displayAlt}]($imageUrl)';

  //       // Handle relative URLs
  //       // if (!src.startsWith('http') && !src.startsWith('/')) {
  //       //   src = '/media/$src';
  //       // }

  //       // return '![${alt ?? title ?? ''}]($src)';
  //     },
  //   );

  //   // 7. Convert headings
  //   for (int i = 6; i >= 1; i--) {
  //     result = result.replaceAllMapped(
  //       RegExp(r'<h$i[^>]*>(.*?)</h$i>', caseSensitive: false, dotAll: true),
  //       (match) {
  //         final headingText = match.group(1) ?? '';
  //         final cleanText = _cleanHtmlText(headingText);
  //         final hashes = '#' * i;
  //         return '$hashes $cleanText';
  //       },
  //     );
  //   }

  //   // 8. Convert lists
  //   result = result.replaceAllMapped(
  //     RegExp(r'<ul[^>]*>(.*?)</ul>', caseSensitive: false, dotAll: true),
  //     (match) {
  //       String ulContent = match.group(1) ?? '';
  //       ulContent = ulContent.replaceAllMapped(
  //         RegExp(r'<li[^>]*>(.*?)</li>', caseSensitive: false, dotAll: true),
  //         (liMatch) {
  //           String liContent = liMatch.group(1) ?? '';
  //           liContent = _cleanHtmlText(liContent);
  //           return '- $liContent';
  //         },
  //       );
  //       return ulContent;
  //     },
  //   );

  //   result = result.replaceAllMapped(
  //     RegExp(r'<ol[^>]*>(.*?)</ol>', caseSensitive: false, dotAll: true),
  //     (match) {
  //       String olContent = match.group(1) ?? '';
  //       int counter = 1;
  //       olContent = olContent.replaceAllMapped(
  //         RegExp(r'<li[^>]*>(.*?)</li>', caseSensitive: false, dotAll: true),
  //         (liMatch) {
  //           String liContent = liMatch.group(1) ?? '';
  //           liContent = _cleanHtmlText(liContent);
  //           final result = '$counter. $liContent';
  //           counter++;
  //           return result;
  //         },
  //       );
  //       return olContent;
  //     },
  //   );

  //   // 9. Convert paragraphs with proper spacing
  //   result = result.replaceAllMapped(
  //     RegExp(r'<p[^>]*>(.*?)</p>', caseSensitive: false, dotAll: true),
  //     (match) {
  //       final pContent = match.group(1) ?? '';
  //       final cleanText = _cleanHtmlText(pContent);
  //       return '$cleanText\n\n';
  //     },
  //   );

  //   // Handle bold with b tags
  //   result = result.replaceAllMapped(
  //     RegExp(r'<b>(.*?)</b>', caseSensitive: false, dotAll: true),
  //     (match) => '**${match.group(1)}**',
  //   );

  //   // Handle italic
  //   result = result.replaceAllMapped(
  //     RegExp(r'<em>(.*?)</em>', caseSensitive: false, dotAll: true),
  //     (match) => '*${match.group(1)}*',
  //   );

  //   result = result.replaceAllMapped(
  //     RegExp(r'<i>(.*?)</i>', caseSensitive: false, dotAll: true),
  //     (match) => '*${match.group(1)}*',
  //   );

  //   // 10. Convert formatting
  //   result = result.replaceAllMapped(
  //     RegExp(
  //       r'<strong[^>]*>\s*<em[^>]*>(.*?)</em>\s*</strong>',
  //       caseSensitive: false,
  //       dotAll: true,
  //     ),
  //     (match) {
  //       final content = match.group(1) ?? '';
  //       return '***${_cleanHtmlText(content)}***';
  //     },
  //   );

  //   result = result.replaceAllMapped(
  //     RegExp(
  //       r'<em[^>]*>\s*<strong[^>]*>(.*?)</strong>\s*</em>',
  //       caseSensitive: false,
  //       dotAll: true,
  //     ),
  //     (match) {
  //       final content = match.group(1) ?? '';
  //       return '***${_cleanHtmlText(content)}***';
  //     },
  //   );

  //   // Handle bold with strong tags - IMPORTANT: Do this BEFORE removing all HTML tags
  //   // result = result.replaceAllMapped(
  //   //   RegExp(
  //   //     r'<strong[^>]*>(.*?)</strong>',
  //   //     caseSensitive: false,
  //   //     dotAll: true,
  //   //   ),
  //   //   (match) {
  //   //     final content = match.group(1) ?? '';
  //   //     // Also handle any nested formatting inside
  //   //     final cleanedContent = _cleanHtmlText(content);
  //   //     return '**$cleanedContent**';
  //   //   },
  //   // );

  //   result = result.replaceAllMapped(
  //     RegExp(
  //       r'<strong[^>]*>(.*?)</strong>',
  //       caseSensitive: false,
  //       dotAll: true,
  //     ),
  //     (match) {
  //       final content = match.group(1) ?? '';
  //       return '**${_cleanHtmlText(content)}**';
  //     },
  //   );

  //   result = result.replaceAllMapped(
  //     RegExp(r'<b[^>]*>(.*?)</b>', caseSensitive: false, dotAll: true),
  //     (match) {
  //       final content = match.group(1) ?? '';
  //       return '**${_cleanHtmlText(content)}**';
  //     },
  //   );

  //   // Handle italic
  //   result = result.replaceAllMapped(
  //     RegExp(r'<em[^>]*>(.*?)</em>', caseSensitive: false, dotAll: true),
  //     (match) {
  //       final content = match.group(1) ?? '';
  //       return '*${_cleanHtmlText(content)}*';
  //     },
  //   );

  //   result = result.replaceAllMapped(
  //     RegExp(r'<i[^>]*>(.*?)</i>', caseSensitive: false, dotAll: true),
  //     (match) {
  //       final content = match.group(1) ?? '';
  //       return '*${_cleanHtmlText(content)}*';
  //     },
  //   );

  //   // 11. Convert links
  //   result = result.replaceAllMapped(
  //     RegExp(
  //       r'<a[^>]*href="([^"]*)"[^>]*>(.*?)</a>',
  //       caseSensitive: false,
  //       dotAll: true,
  //     ),
  //     (match) {
  //       final href = match.group(1) ?? '';
  //       final text = match.group(2) ?? '';
  //       final cleanText = _cleanHtmlText(text);
  //       return '[$cleanText]($href)';
  //     },
  //   );

  //   // 12. Convert blockquotes
  //   result = result.replaceAllMapped(
  //     RegExp(
  //       r'<blockquote[^>]*>(.*?)</blockquote>',
  //       caseSensitive: false,
  //       dotAll: true,
  //     ),
  //     (match) {
  //       String quoteContent = match.group(1) ?? '';
  //       quoteContent = _cleanHtmlText(quoteContent);
  //       final lines = quoteContent.split('\n');
  //       return lines.map((line) => '> $line').join('\n');
  //     },
  //   );

  //   // 13. Remove remaining HTML tags but keep their content
  //   result = result.replaceAll(RegExp(r'<[^>]*>'), '');

  //   // 14. Decode HTML entities
  //   result = _decodeHtmlEntities(result);

  //   // 15. Clean up whitespace
  //   result = result
  //       .replaceAll(RegExp(r'\n\s*\n\s*\n'), '\n\n')
  //       .replaceAll(RegExp(r'[ \t]+'), ' ')
  //       .trim();

  //   print(
  //     '📝 Converted Markdown: ${result.substring(0, min(200, result.length))}...',
  //   );
  //   return result;
  // }

  // $$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$

  String _convertCkEditorToMarkdown(String htmlContent) {
    if (htmlContent.isEmpty) return '';

    String result = htmlContent;

    // ─── STEP 1: PROTECT MATH FIRST (before anything strips tags) ───────────────
    final mathPlaceholders = <String, String>{};
    int mathIndex = 0;

    // PRE-STEP: Normalize backslashes — CKEditor sometimes escapes them as \\
    // e.g. \\frac becomes \frac
    result = result.replaceAll(r'\\frac', r'\frac');
    result = result.replaceAll(r'\\sqrt', r'\sqrt');
    result = result.replaceAll(r'\\times', r'\times');
    result = result.replaceAll(r'\\div', r'\div');
    result = result.replaceAll(r'\\cdot', r'\cdot');
    result = result.replaceAll(r'\\sum', r'\sum');
    result = result.replaceAll(r'\\int', r'\int');
    result = result.replaceAll(r'\\infty', r'\infty');
    result = result.replaceAll(r'\\alpha', r'\alpha');
    result = result.replaceAll(r'\\beta', r'\beta');
    result = result.replaceAll(r'\\gamma', r'\gamma');
    result = result.replaceAll(r'\\delta', r'\delta');
    result = result.replaceAll(r'\\theta', r'\theta');
    result = result.replaceAll(r'\\pi', r'\pi');
    result = result.replaceAll(r'\\sigma', r'\sigma');
    result = result.replaceAll(r'\\omega', r'\omega');
    result = result.replaceAll(r'\\lambda', r'\lambda');
    result = result.replaceAll(r'\\mu', r'\mu');
    result = result.replaceAll(r'\\pm', r'\pm');
    result = result.replaceAll(r'\\leq', r'\leq');
    result = result.replaceAll(r'\\geq', r'\geq');
    result = result.replaceAll(r'\\neq', r'\neq');
    result = result.replaceAll(r'\\approx', r'\approx');
    result = result.replaceAll(r'\\left', r'\left');
    result = result.replaceAll(r'\\right', r'\right');
    result = result.replaceAll(r'\\text', r'\text');
    result = result.replaceAll(r'\\vec', r'\vec');
    result = result.replaceAll(r'\\hat', r'\hat');
    result = result.replaceAll(r'\\bar', r'\bar');
    result = result.replaceAll(r'\\dot', r'\dot');
    result = result.replaceAll(r'\\lim', r'\lim');
    result = result.replaceAll(r'\\log', r'\log');
    result = result.replaceAll(r'\\ln', r'\ln');
    result = result.replaceAll(r'\\sin', r'\sin');
    result = result.replaceAll(r'\\cos', r'\cos');
    result = result.replaceAll(r'\\tan', r'\tan');

    // Auto-complete unclosed inline math: $\frac{...  → $\frac{...}$
    result = result.replaceAllMapped(
      RegExp(r'\$([^$\n]{1,300})$', multiLine: true),
      (match) {
        final inner = match.group(1) ?? '';
        // Only auto-close if it looks like a math expression
        if (inner.contains(r'\') ||
            inner.contains('^') ||
            inner.contains('_')) {
          // Count braces to auto-close if needed
          int openBraces = '{'.allMatches(inner).length;
          int closeBraces = '}'.allMatches(inner).length;
          final missingBraces = '}'.repeat(
            openBraces - closeBraces > 0 ? openBraces - closeBraces : 0,
          );
          return '\$${inner}${missingBraces}\$';
        }
        return match.group(0)!;
      },
    );

    // CKEditor math spans: <span class="math-tex">\(...\)</span> or \[...\]
    result = result.replaceAllMapped(
      RegExp(
        r'<span[^>]*class="math-tex"[^>]*>([\s\S]*?)</span>',
        caseSensitive: false,
        dotAll: true,
      ),
      (match) {
        final key = '___MATH${mathIndex}___';
        String inner = match.group(1) ?? '';
        // Decode entities inside math before protecting
        inner = inner
            .replaceAll('&lt;', '<')
            .replaceAll('&gt;', '>')
            .replaceAll('&amp;', '&')
            .replaceAll('&#160;', ' ')
            .replaceAll('&nbsp;', ' ')
            .trim();
        // Block math \[...\]
        if (inner.startsWith(r'\[') || inner.contains(r'\[')) {
          final extracted = inner
              .replaceFirst(RegExp(r'^\s*\\\['), '')
              .replaceFirst(RegExp(r'\\\]\s*$'), '')
              .trim();
          mathPlaceholders[key] = '\$\$$extracted\$\$';
        } else {
          // Inline math \(...\)
          final extracted = inner
              .replaceFirst(RegExp(r'^\s*\\\('), '')
              .replaceFirst(RegExp(r'\\\)\s*$'), '')
              .trim();
          mathPlaceholders[key] = '\$$extracted\$';
        }
        mathIndex++;
        return key;
      },
    );

    // MathJax script tags (display mode)
    result = result.replaceAllMapped(
      RegExp(
        r'<script[^>]*type="math/tex;\s*mode=display"[^>]*>([\s\S]*?)</script>',
        caseSensitive: false,
        dotAll: true,
      ),
      (match) {
        final key = '___MATH${mathIndex}___';
        mathPlaceholders[key] = '\$\$${match.group(1)?.trim()}\$\$';
        mathIndex++;
        return key;
      },
    );

    // MathJax script tags (inline)
    result = result.replaceAllMapped(
      RegExp(
        r'<script[^>]*type="math/tex"[^>]*>([\s\S]*?)</script>',
        caseSensitive: false,
        dotAll: true,
      ),
      (match) {
        final key = '___MATH${mathIndex}___';
        mathPlaceholders[key] = '\$${match.group(1)?.trim()}\$';
        mathIndex++;
        return key;
      },
    );

    // Protect already-existing $$...$$ and $...$ in content
    result = result.replaceAllMapped(
      RegExp(r'\$\$[\s\S]*?\$\$|\$[^\$\n]{1,200}\$'),
      (match) {
        final key = '___MATH${mathIndex}___';
        mathPlaceholders[key] = match.group(0)!;
        mathIndex++;
        return key;
      },
    );

    // ─── STEP 2: TABLES (before any tag stripping) ───────────────────────────────
    result = _convertHtmlTablesToMarkdown(result);

    // ─── STEP 3: CODE BLOCKS ─────────────────────────────────────────────────────
    result = result.replaceAllMapped(
      RegExp(r'<pre[^>]*>([\s\S]*?)</pre>', caseSensitive: false, dotAll: true),
      (match) {
        final fullTag = match.group(0) ?? '';
        String codeContent = match.group(1) ?? '';

        // Extract language from class attribute
        String language = '';
        final classMatch = RegExp(r'class="([^"]*)"').firstMatch(fullTag);
        if (classMatch != null) {
          for (final cls in classMatch.group(1)!.split(' ')) {
            if (cls.startsWith('language-')) {
              language = cls.replaceFirst('language-', '');
              break;
            }
          }
        }

        // Strip inner <code> tags only
        codeContent = codeContent
            .replaceAll(RegExp(r'<code[^>]*>'), '')
            .replaceAll('</code>', '')
            .replaceAll('&lt;', '<')
            .replaceAll('&gt;', '>')
            .replaceAll('&amp;', '&')
            .replaceAll('&nbsp;', ' ')
            .trim();

        return '\n```$language\n$codeContent\n```\n';
      },
    );

    // ─── STEP 4: INLINE CODE ─────────────────────────────────────────────────────
    result = result.replaceAllMapped(
      RegExp(r'<code[^>]*>(.*?)</code>', caseSensitive: false, dotAll: true),
      (match) {
        final code = match.group(1) ?? '';
        final clean = code
            .replaceAll('&lt;', '<')
            .replaceAll('&gt;', '>')
            .replaceAll('&amp;', '&');
        return '`$clean`';
      },
    );

    // ─── STEP 5: IMAGES ──────────────────────────────────────────────────────────
    result = result.replaceAllMapped(
      RegExp(r'<img[^>]*>', caseSensitive: false),
      (match) {
        final imgTag = match.group(0)!;
        final src = RegExp(r'src="([^"]*)"').firstMatch(imgTag)?.group(1) ?? '';
        final alt = RegExp(r'alt="([^"]*)"').firstMatch(imgTag)?.group(1) ?? '';
        final title =
            RegExp(r'title="([^"]*)"').firstMatch(imgTag)?.group(1) ?? '';

        if (src.isEmpty) return '';

        String imageUrl = src;
        if (!src.startsWith('http://') && !src.startsWith('https://')) {
          final baseUrl = ApiEndpoints.baseUrl;
          if (src.startsWith('/')) {
            imageUrl = '$baseUrl$src';
          } else if (src.startsWith('media/') || src.startsWith('/media/')) {
            imageUrl = src.startsWith('media/')
                ? '$baseUrl/$src'
                : '$baseUrl$src';
          } else if (src.startsWith('uploads/')) {
            imageUrl = '$baseUrl/media/$src';
          } else {
            imageUrl = '$baseUrl/media/$src';
          }
          imageUrl = imageUrl
              .replaceAll('//media/', '/media/')
              .replaceAll(':/', '://');
        }

        final displayAlt = alt.isNotEmpty ? alt : title;
        return '\n![$displayAlt]($imageUrl)\n';
      },
    );

    // ─── STEP 6: HEADINGS ────────────────────────────────────────────────────────
    for (int i = 6; i >= 1; i--) {
      result = result.replaceAllMapped(
        RegExp('<h$i[^>]*>(.*?)</h$i>', caseSensitive: false, dotAll: true),
        (match) {
          final text = _stripTagsKeepText(match.group(1) ?? '');
          return '\n${'#' * i} $text\n';
        },
      );
    }

    // // ─── STEP 7: BOLD + ITALIC COMBINED (must come before bold/italic alone) ─────
    // result = result.replaceAllMapped(
    //   RegExp(
    //     r'<strong[^>]*>\s*<em[^>]*>([\s\S]*?)</em>\s*</strong>'
    //     r'|<em[^>]*>\s*<strong[^>]*>([\s\S]*?)</strong>\s*</em>',
    //     caseSensitive: false,
    //     dotAll: true,
    //   ),
    //   (match) {
    //     final content = _stripTagsKeepText(
    //       match.group(1) ?? match.group(2) ?? '',
    //     );
    //     return '***$content***';
    //   },
    // );

    // ─── STEP 7: BOLD + ITALIC COMBINED ──────────────────────────────────────────
    result = result.replaceAllMapped(
      RegExp(
        r'<strong[^>]*>\s*<em[^>]*>([\s\S]*?)</em>\s*</strong>'
        r'|<em[^>]*>\s*<strong[^>]*>([\s\S]*?)</strong>\s*</em>',
        caseSensitive: false,
        dotAll: true,
      ),
      (match) {
        // Only strip actual HTML tags — leave math placeholders and text intact
        final content = (match.group(1) ?? match.group(2) ?? '')
            .replaceAll(RegExp(r'<[^>]*>'), '')
            .trim();
        return '***$content***';
      },
    );

    // // ─── STEP 8: BOLD ─────────────────────────────────────────────────────────────
    // result = result.replaceAllMapped(
    //   RegExp(
    //     r'<strong[^>]*>([\s\S]*?)</strong>|<b[^>]*>([\s\S]*?)</b>',
    //     caseSensitive: false,
    //     dotAll: true,
    //   ),
    //   (match) {
    //     final content = _stripTagsKeepText(
    //       match.group(1) ?? match.group(2) ?? '',
    //     );
    //     return '**$content**';
    //   },
    // );

    // ─── STEP 8: BOLD ─────────────────────────────────────────────────────────────
    result = result.replaceAllMapped(
      RegExp(
        r'<strong[^>]*>([\s\S]*?)</strong>|<b[^>]*>([\s\S]*?)</b>',
        caseSensitive: false,
        dotAll: true,
      ),
      (match) {
        // Only strip actual HTML tags — leave math placeholders and text intact
        final content = (match.group(1) ?? match.group(2) ?? '')
            .replaceAll(RegExp(r'<[^>]*>'), '')
            .trim();
        return '**$content**';
      },
    );

    // // ─── STEP 9: ITALIC ───────────────────────────────────────────────────────────
    // result = result.replaceAllMapped(
    //   RegExp(
    //     r'<em[^>]*>([\s\S]*?)</em>|<i[^>]*>([\s\S]*?)</i>',
    //     caseSensitive: false,
    //     dotAll: true,
    //   ),
    //   (match) {
    //     final content = _stripTagsKeepText(
    //       match.group(1) ?? match.group(2) ?? '',
    //     );
    //     return '*$content*';
    //   },
    // );

    // ─── STEP 9: ITALIC ───────────────────────────────────────────────────────────
    result = result.replaceAllMapped(
      RegExp(
        r'<em[^>]*>([\s\S]*?)</em>|<i[^>]*>([\s\S]*?)</i>',
        caseSensitive: false,
        dotAll: true,
      ),
      (match) {
        // Only strip actual HTML tags — leave math placeholders and text intact
        final content = (match.group(1) ?? match.group(2) ?? '')
            .replaceAll(RegExp(r'<[^>]*>'), '')
            .trim();
        return '*$content*';
      },
    );
    // ─── STEP 10: UNDERLINE (no markdown equivalent — just keep text) ─────────────
    result = result.replaceAllMapped(
      RegExp(r'<u[^>]*>([\s\S]*?)</u>', caseSensitive: false, dotAll: true),
      (match) => _stripTagsKeepText(match.group(1) ?? ''),
    );

    // ─── STEP 11: STRIKETHROUGH ───────────────────────────────────────────────────
    result = result.replaceAllMapped(
      RegExp(
        r'<s[^>]*>([\s\S]*?)</s>|<del[^>]*>([\s\S]*?)</del>',
        caseSensitive: false,
        dotAll: true,
      ),
      (match) {
        final content = _stripTagsKeepText(
          match.group(1) ?? match.group(2) ?? '',
        );
        return '~~$content~~';
      },
    );

    // ─── STEP 12: LINKS ───────────────────────────────────────────────────────────
    result = result.replaceAllMapped(
      RegExp(
        r'<a[^>]*href="([^"]*)"[^>]*>([\s\S]*?)</a>',
        caseSensitive: false,
        dotAll: true,
      ),
      (match) {
        final href = match.group(1) ?? '';
        final text = _stripTagsKeepText(match.group(2) ?? '');
        return '[$text]($href)';
      },
    );

    // ─── STEP 13: BLOCKQUOTES ─────────────────────────────────────────────────────
    result = result.replaceAllMapped(
      RegExp(
        r'<blockquote[^>]*>([\s\S]*?)</blockquote>',
        caseSensitive: false,
        dotAll: true,
      ),
      (match) {
        final content = _stripTagsKeepText(match.group(1) ?? '');
        return content.split('\n').map((line) => '> $line').join('\n');
      },
    );

    // ─── STEP 14: UNORDERED LISTS ─────────────────────────────────────────────────
    result = result.replaceAllMapped(
      RegExp(r'<ul[^>]*>([\s\S]*?)</ul>', caseSensitive: false, dotAll: true),
      (match) {
        String ul = match.group(1) ?? '';
        ul = ul.replaceAllMapped(
          RegExp(
            r'<li[^>]*>([\s\S]*?)</li>',
            caseSensitive: false,
            dotAll: true,
          ),
          (li) {
            final text = _stripTagsKeepText(li.group(1) ?? '').trim();
            return '- $text\n';
          },
        );
        return '\n$ul\n';
      },
    );

    // ─── STEP 15: ORDERED LISTS ───────────────────────────────────────────────────
    result = result.replaceAllMapped(
      RegExp(r'<ol[^>]*>([\s\S]*?)</ol>', caseSensitive: false, dotAll: true),
      (match) {
        String ol = match.group(1) ?? '';
        int counter = 1;
        ol = ol.replaceAllMapped(
          RegExp(
            r'<li[^>]*>([\s\S]*?)</li>',
            caseSensitive: false,
            dotAll: true,
          ),
          (li) {
            final text = _stripTagsKeepText(li.group(1) ?? '').trim();
            final item = '$counter. $text\n';
            counter++;
            return item;
          },
        );
        return '\n$ol\n';
      },
    );

    // ─── STEP 16: PARAGRAPHS ──────────────────────────────────────────────────────
    // Preserve CKEditor spacing — empty <p> = intentional blank line
    result = result.replaceAllMapped(
      RegExp(r'<p[^>]*>([\s\S]*?)</p>', caseSensitive: false, dotAll: true),
      (match) {
        final inner = match.group(1) ?? '';
        final trimmed = inner.trim();
        // Empty paragraph or just &nbsp; = blank line (CKEditor spacing intent)
        if (trimmed.isEmpty ||
            trimmed == '&nbsp;' ||
            trimmed == '&#160;' ||
            trimmed == '\u00a0') {
          return '\n';
        }
        return '${inner.trim()}\n\n';
      },
    );

    // ─── STEP 17: LINE BREAKS ─────────────────────────────────────────────────────
    result = result.replaceAll(
      RegExp(r'<br\s*/?>', caseSensitive: false),
      '\n',
    );

    // ─── STEP 18: HORIZONTAL RULES ────────────────────────────────────────────────
    result = result.replaceAll(
      RegExp(r'<hr[^>]*>', caseSensitive: false),
      '\n---\n',
    );

    // ─── STEP 19: STRIP ALL REMAINING HTML TAGS ───────────────────────────────────
    // (divs, spans, figures, captions, etc. — keep their text content)
    result = result.replaceAll(RegExp(r'<[^>]*>'), '');

    // ─── STEP 20: DECODE HTML ENTITIES ───────────────────────────────────────────
    result = _decodeHtmlEntities(result);

    // ─── STEP 21: RESTORE PROTECTED MATH ─────────────────────────────────────────
    mathPlaceholders.forEach((key, value) {
      result = result.replaceAll(key, value);
    });

    // ─── STEP 22: CLEAN UP WHITESPACE ────────────────────────────────────────────
    result = result
        .replaceAll(RegExp(r'[ \t]+'), ' ') // collapse spaces/tabs
        .replaceAll(RegExp(r'\n{4,}'), '\n\n\n') // max 3 consecutive newlines
        .replaceAll(RegExp(r' \n'), '\n') // trailing spaces before newline
        .replaceAll(RegExp(r'\n '), '\n') // leading spaces after newline
        .trim();

    return result;
  }

  // Helper: strips HTML tags only, keeps inner text intact
  // Used during conversion steps before the final entity decode
  String _stripTagsKeepText(String html) {
    return html.replaceAll(RegExp(r'<[^>]*>'), '').trim();
  }

  Widget _buildMarkdownTable(String tableMarkdown) {
    try {
      final lines = tableMarkdown.trim().split('\n');
      if (lines.length < 2) return Container();

      // Parse header
      final headerRow = _parseTableRow(lines[0]);

      // Check if there's a separator line (typically the second line with ---)
      final hasSeparator = lines.length > 1 && lines[1].contains('---');
      final dataStartIndex = hasSeparator ? 2 : 1;

      // Parse data rows
      final dataRows = <List<String>>[];
      for (int i = dataStartIndex; i < lines.length; i++) {
        if (lines[i].trim().isNotEmpty) {
          final cells = _parseTableRow(lines[i]);
          dataRows.add(cells);
        }
      }

      // Calculate column widths based on content
      final columnCount = headerRow.length;
      final columnWidths = List<double>.filled(columnCount, 0);

      // Measure header widths
      for (int col = 0; col < columnCount; col++) {
        final textPainter = TextPainter(
          text: TextSpan(
            text: headerRow[col],
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          textDirection: TextDirection.ltr,
        )..layout();

        columnWidths[col] = textPainter.width + 32; // Add padding
      }

      // Measure data row widths
      for (final row in dataRows) {
        for (int col = 0; col < row.length && col < columnCount; col++) {
          final textPainter = TextPainter(
            text: TextSpan(
              text: row[col],
              style: const TextStyle(fontSize: 13),
            ),
            textDirection: TextDirection.ltr,
          )..layout();

          columnWidths[col] = max(columnWidths[col], textPainter.width + 32);
        }
      }

      // Cap maximum width to prevent extremely wide columns
      for (int col = 0; col < columnCount; col++) {
        columnWidths[col] = min(columnWidths[col], 300.0);
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
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header row
                Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 12,
                    horizontal: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    border: Border(
                      bottom: BorderSide(color: Colors.grey.shade300),
                    ),
                  ),
                  child: Row(
                    children: List.generate(columnCount, (col) {
                      return Container(
                        width: columnWidths[col],
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Text(
                          headerRow[col],
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: Color(0xFF333333),
                          ),
                          softWrap: true,
                        ),
                      );
                    }),
                  ),
                ),

                // Data rows
                ...dataRows.map((row) {
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 10,
                      horizontal: 8,
                    ),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: Colors.grey.shade200),
                      ),
                    ),
                    child: Row(
                      children: List.generate(columnCount, (col) {
                        final cellContent = col < row.length ? row[col] : '';

                        return Container(
                          width: columnWidths[col],
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: _buildTableCellContent(cellContent),
                        );
                      }),
                    ),
                  );
                }).toList(),
              ],
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

  double _getColumnWidth(int index, int totalColumns) {
    // Adjust column widths based on position
    if (totalColumns <= 2) return 300;
    if (totalColumns <= 3) return 200;
    if (totalColumns <= 4) return 150;
    return 120;
  }

  // Widget _buildTableCellContent(String cellContent, {bool isHeader = false}) {
  //   // Check if cell contains math
  //   if (_containsMath(cellContent)) {
  //     return Container(
  //       constraints: BoxConstraints(maxWidth: 150),
  //       child: _buildTableCellWithMath(cellContent, isHeader: isHeader),
  //     );
  //   }

  //   // Regular text cell
  //   return Container(
  //     constraints: BoxConstraints(maxWidth: 200), // Add constraint
  //     child: Text(
  //       cellContent,
  //       style: TextStyle(
  //         fontWeight: isHeader ? FontWeight.bold : FontWeight.normal,
  //         fontSize: isHeader ? 14 : 13,
  //       ),
  //       overflow: TextOverflow.ellipsis,
  //     ),
  //   );
  // }

  Widget _buildTableCellContent(String cellContent, {bool isHeader = false}) {
    // Check if cell contains math
    if (_containsMath(cellContent)) {
      return _buildTableCellWithMath(cellContent, isHeader: isHeader);
    }

    // Regular text cell with word wrapping
    return Text(
      cellContent,
      style: TextStyle(
        fontWeight: isHeader ? FontWeight.bold : FontWeight.normal,
        fontSize: isHeader ? 14 : 13,
        color: Colors.black87,
      ),
      softWrap: true,
      overflow: TextOverflow.visible, // Allow text to wrap
    );
  }

  Widget _buildTableCellWithMath(String cellContent, {bool isHeader = false}) {
    // Parse mixed content with text and math
    final regex = RegExp(r'(\$.*?(?<!\\)\$)|([^$]+)');
    final matches = regex.allMatches(cellContent);

    final textSpans = <InlineSpan>[];

    for (final match in matches) {
      final matchedText = match.group(0)!;

      if (matchedText.startsWith('\$') && matchedText.endsWith('\$')) {
        // Math content
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
        // Text content
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
              // REMOVE const from Text widget
              mathContent,
              style: TextStyle(
                // REMOVE const from TextStyle
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

  List<String> _parseTableRow(String row) {
    // Remove leading/trailing pipes and split
    final cleanRow = row.trim().replaceAll(RegExp(r'^\||\|$'), '');
    return cleanRow.split('|').map((cell) => cell.trim()).toList();
  }

  String _convertHtmlTablesToMarkdown(String html) {
    String result = html;

    // Find all table elements
    final tableRegex = RegExp(
      r'<table[^>]*>(.*?)</table>',
      caseSensitive: false,
      dotAll: true,
    );

    result = result.replaceAllMapped(tableRegex, (tableMatch) {
      String tableHtml = tableMatch.group(1) ?? '';
      List<List<String>> rows = [];

      // Extract rows
      final rowRegex = RegExp(
        r'<tr[^>]*>(.*?)</tr>',
        caseSensitive: false,
        dotAll: true,
      );
      final rowMatches = rowRegex.allMatches(tableHtml);

      for (final rowMatch in rowMatches) {
        String rowHtml =
            rowMatch.group(1) ?? ''; // FIXED: .group(1) not .match(1)
        List<String> cells = [];

        // Extract cells (handle both th and td)
        final cellRegex = RegExp(
          r'<(th|td)[^>]*>(.*?)</\1>',
          caseSensitive: false,
          dotAll: true,
        );
        final cellMatches = cellRegex.allMatches(rowHtml);

        for (final cellMatch in cellMatches) {
          String cellContent = cellMatch.group(2) ?? '';

          // Preserve math content in cells
          cellContent = _preserveMathInCell(cellContent);

          // Clean other HTML tags
          cellContent = _cleanHtmlText(cellContent);
          cells.add(cellContent);
        }

        if (cells.isNotEmpty) {
          rows.add(cells);
        }
      }

      if (rows.isEmpty) return '';

      // Convert to markdown table
      final markdownTable = _rowsToMarkdownTable(rows);
      return '\n\n$markdownTable\n\n';
    });

    return result;
  }
  // Add these methods to your _LectureScreenState class:

  bool _isTableStart(List<String> lines, int index) {
    if (index >= lines.length) return false;
    final line = lines[index].trim();

    // Table starts with a pipe
    if (!line.startsWith('|')) return false;

    // Need at least one more line (separator)
    if (index + 1 >= lines.length) return false;

    // Next line should be a separator
    final nextLine = lines[index + 1].trim();

    // Check if it's a valid separator line (contains --- and |)
    if (!nextLine.startsWith('|')) return false;

    // Count pipes in separator line
    final pipeCount = '|'.allMatches(nextLine).length;
    if (pipeCount < 2) return false;

    // Check if it contains dashes between pipes
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

      // Stop if we hit a non-table line
      if (!line.startsWith('|')) {
        break;
      }

      // For separator lines, we need to validate
      if (i > startIndex && line.contains('---')) {
        // Check if it's a valid separator
        final parts = line.split('|');
        bool isValidSeparator = true;
        for (int j = 1; j < parts.length - 1; j++) {
          final part = parts[j].trim();
          if (part.isNotEmpty && !RegExp(r'^:?-+:?$').hasMatch(part)) {
            isValidSeparator = false;
            break;
          }
        }
        if (!isValidSeparator) {
          break;
        }
      }

      tableLines.add(line);

      // Stop if we have too many rows (performance)
      if (tableLines.length > 50) {
        break;
      }
    }

    return tableLines;
  }

  String _preserveMathInCell(String cellContent) {
    String result = cellContent;

    // Handle escaped LaTeX commands
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

    // Handle HTML encoded LaTeX
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

    // Add header
    markdownRows.add('| ${rows[0].join(' | ')} |');

    // Add separator
    final separator =
        '|' + List<String>.generate(columnCount, (_) => '---').join('|') + '|';
    markdownRows.add(separator);

    // Add data rows
    for (int i = 1; i < rows.length; i++) {
      final row = rows[i];
      // Ensure row has same number of columns as header
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

  // String _cleanHtmlText(String text) {
  //   return text
  //       .replaceAll(RegExp(r'<[^>]*>'), '') // Remove any remaining tags
  //       .replaceAll('\n', ' ')
  //       .trim();
  // }

  String _cleanHtmlText(String text) {
    // Don't remove ** or * - they're markdown syntax
    String result = text;

    // Remove HTML tags but preserve their content
    result = result.replaceAll(RegExp(r'<[^>]*>'), '');

    // Decode HTML entities
    result = _decodeHtmlEntities(result);

    // Clean up whitespace but don't trim completely if it's part of formatting
    result = result.replaceAll(RegExp(r'\s+'), ' ').trim();

    return result;
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

  Widget _buildImageErrorPlaceholder(String? altText) {
    return Container(
      height: 200,
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.broken_image_rounded, size: 48, color: Colors.grey),
          const SizedBox(height: 8),
          Text(
            altText?.isNotEmpty == true
                ? 'Image: $altText'
                : 'Image not available',
            style: const TextStyle(color: Colors.grey, fontSize: 14),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildLectureCodeBlockEnhanced(String code, String language) {
    // Map common language names
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
          // Header with language and copy button
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
                    // Line count
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
                    // Copy button
                    GestureDetector(
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: code));
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text('Code copied to clipboard'),
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

          // SIMPLIFIED CODE CONTENT - No Row, just text with line numbers
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

  // Rename the second one to avoid duplicate (add "Enhanced" suffix)
  Widget _buildNetworkImageEnhanced(String imageUrl, String? altText) {
    // Check if it's a local file
    bool isLocalFile =
        imageUrl.startsWith('/') ||
        imageUrl.startsWith('file://') ||
        imageUrl.contains(
          RegExp(r'\.(jpg|jpeg|png|gif|bmp|webp|svg)$', caseSensitive: false),
        );

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: isLocalFile
                ? Image.file(
                    File(imageUrl.replaceFirst('file://', '')),
                    fit: BoxFit.contain,
                    width: double.infinity,
                    errorBuilder: (context, error, stackTrace) {
                      return _buildImageErrorPlaceholder(altText);
                    },
                  )
                : Image.network(
                    imageUrl,
                    fit: BoxFit.contain,
                    width: double.infinity,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Container(
                        height: 200,
                        color: Colors.grey.shade200,
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
                      return _buildImageErrorPlaceholder(altText);
                    },
                  ),
          ),
          if (altText?.isNotEmpty == true)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                altText!,
                style: const TextStyle(
                  fontSize: 14,
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

  Widget _parseLectureContent(String content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: _parseContentForLecture(content),
    );
  }

  List<Widget> _parseContentForLecture(String content) {
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
            widgets.add(
              _buildLectureCodeBlockEnhanced(
                codeContent,
                currentLanguage ?? '',
              ),
            );
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
      // Handle tables - This is likely where the Row issue is
      if (_isTableStart(lines, i)) {
        final tableLines = _extractTableLines(lines, i);
        if (tableLines.isNotEmpty) {
          widgets.add(
            ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width,
              ),
              child: _buildMarkdownTable(tableLines.join('\n')),
            ),
          );
          i += tableLines.length - 1;
        }
        continue;
      }

      // // Handle code blocks
      // if (trimmedLine.startsWith('```')) {
      //   inCodeBlock = true;
      //   currentCodeBlock = [];
      //   currentLanguage = trimmedLine.replaceAll('```', '').trim();
      //   continue;
      // }

      // Handle math blocks with $$
      if (trimmedLine.startsWith(r'$$')) {
        if (!inMathBlock) {
          // Start of math block
          inMathBlock = true;
          currentMathBlock = [];
        } else {
          // End of math block
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

          // Handle any text before the math block
          final beforeMath = trimmedLine.substring(0, startIndex);
          if (beforeMath.isNotEmpty) {
            widgets.add(_buildLectureText(beforeMath));
          }

          // Handle any text after the math block
          final afterMath = trimmedLine.substring(endIndex + 2);
          if (afterMath.isNotEmpty) {
            widgets.add(_buildLectureText(afterMath));
          }
          continue;
        }
      }

      // Handle inline math with $ or \( \)
      if (_containsInlineMath(line)) {
        widgets.add(_buildInlineMathText(line));
        continue;
      }

      // Handle code blocks
      if (trimmedLine.startsWith('```')) {
        if (!inCodeBlock) {
          // Start of code block
          inCodeBlock = true;
          currentCodeBlock = [];
          currentLanguage = trimmedLine.replaceAll('```', '').trim();
        } else {
          // End of code block
          inCodeBlock = false;
          final codeContent = currentCodeBlock.join('\n');
          widgets.add(
            _buildLectureCodeBlock(codeContent, currentLanguage ?? ''),
          );
        }
        continue;
      }
      // And at the end:
      // if (inCodeBlock && currentCodeBlock.isNotEmpty) {
      //   final codeContent = currentCodeBlock.join('\n');
      //   widgets.add(
      //     _buildLectureCodeBlockEnhanced(codeContent, currentLanguage ?? ''),
      //   );
      // }

      if (inCodeBlock) {
        currentCodeBlock.add(line);
        continue;
      }

      // Handle inline code
      if (_containsInlineCode(line)) {
        widgets.add(_buildLectureInlineCode(line));
        continue;
      }

      // Handle images
      if (_isImageLine(line)) {
        widgets.add(_buildLectureImage(line));
        continue;
      }

      // Handle headings
      if (trimmedLine.startsWith('#')) {
        widgets.add(_buildLectureHeading(line));
        continue;
      }

      // Handle tables
      if (_isTableLine(line)) {
        final tableData = _extractTableFromLines(lines, i);
        if (tableData.isNotEmpty) {
          widgets.add(_buildLectureTable(tableData));
          i += tableData.length - 1;
        }
        continue;
      }

      // Handle lists
      if (_isListItem(line)) {
        final listItems = _extractListItems(lines, i);
        widgets.add(_buildLectureList(listItems));
        i += listItems.length - 1;
        continue;
      }

      // Regular paragraphs
      if (trimmedLine.isNotEmpty) {
        // Check if this is the start of a paragraph
        if (i == 0 || lines[i - 1].trim().isEmpty) {
          final paragraph = _extractParagraph(lines, i);
          // Check if paragraph contains inline math
          if (_containsInlineMath(paragraph)) {
            widgets.add(_buildInlineMathText(paragraph));
          } else {
            widgets.add(_buildLectureParagraph(paragraph));
          }
          i += paragraph.split('\n').length - 1;
        }
      } else {
        // Add spacing for empty lines
        if (i > 0 && lines[i - 1].trim().isNotEmpty) {
          widgets.add(const SizedBox(height: 8));
        }
      }
    }

    // Handle any remaining blocks
    if (inCodeBlock && currentCodeBlock.isNotEmpty) {
      final codeContent = currentCodeBlock.join('\n');
      widgets.add(_buildLectureCodeBlock(codeContent, currentLanguage ?? ''));
    }

    if (inMathBlock && currentMathBlock.isNotEmpty) {
      widgets.add(_buildMathBlock(currentMathBlock.join('\n')));
    }

    return widgets;
  }

  bool _containsInlineMath(String text) {
    // Check for inline math with $...$ or \(...\)
    final hasDollarMath =
        RegExp(r'[^\\]\$[^\$].*?[^\\]\$').hasMatch(text) ||
        RegExp(r'^\$[^\$].*?[^\\]\$').hasMatch(text);
    final hasLatexInline = text.contains(r'\(') && text.contains(r'\)');

    return hasDollarMath || hasLatexInline;
  }

  Widget _buildMathBlock(String mathContent) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 20),
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

  // Widget _buildInlineMathText(String text) {
  //   // Parse mixed text with inline math
  //   final regex = RegExp(r'(\\\(.*?\\\)|\$.*?(?<!\\)\$)|([^$\\]+)');
  //   final matches = regex.allMatches(text);

  //   final spans = <InlineSpan>[];

  //   for (final match in matches) {
  //     final matchedText = match.group(0)!;

  //     if (matchedText.startsWith(r'\(') && matchedText.endsWith(r'\)')) {
  //       // LaTeX inline math
  //       final mathContent = matchedText.substring(2, matchedText.length - 2);
  //       spans.add(
  //         WidgetSpan(
  //           child: Padding(
  //             padding: const EdgeInsets.symmetric(horizontal: 2),
  //             child: _buildMathWidget(mathContent, isInline: true),
  //           ),
  //         ),
  //       );
  //     } else if (matchedText.startsWith('\$') &&
  //         matchedText.endsWith('\$') &&
  //         matchedText.length > 2) {
  //       // Dollar sign inline math (ensure it's not just a single dollar sign)
  //       final mathContent = matchedText.substring(1, matchedText.length - 1);
  //       spans.add(
  //         WidgetSpan(
  //           child: Padding(
  //             padding: const EdgeInsets.symmetric(horizontal: 2),
  //             child: _buildMathWidget(mathContent, isInline: true),
  //           ),
  //         ),
  //       );
  //     } else {
  //       // Regular text
  //       spans.add(
  //         TextSpan(
  //           text: matchedText,
  //           style: const TextStyle(
  //             fontSize: 16,
  //             color: Color(0xFF666666),
  //             height: 1.6,
  //           ),
  //         ),
  //       );
  //     }
  //   }

  //   return Padding(
  //     padding: const EdgeInsets.symmetric(vertical: 4),
  //     child: SelectableText.rich(TextSpan(children: spans)),
  //   );
  // }

  Widget _buildInlineMathText(String text) {
    // Split the line into alternating: plain-text and math segments
    // Handles: \(...\)  $$...$$  $...$
    final mathRegex = RegExp(
      r'\\\([\s\S]*?\\\)' // \( ... \)
      r'|\$\$[\s\S]*?\$\$' // $$ ... $$
      r'|\$[^\$\n]+\$', // $ ... $
    );

    final spans = <InlineSpan>[];
    int lastIndex = 0;

    for (final match in mathRegex.allMatches(text)) {
      // ── Plain text segment before this math ──────────────────────────────────
      if (match.start > lastIndex) {
        final segment = text.substring(lastIndex, match.start);
        // Parse bold/italic/strikethrough INSIDE this plain segment
        spans.addAll(_parseFormattingToSpans(segment));
      }

      // ── Math segment ─────────────────────────────────────────────────────────
      final mathMatch = match.group(0)!;
      String mathContent = '';
      bool isBlock = false;

      if (mathMatch.startsWith(r'\(') && mathMatch.endsWith(r'\)')) {
        mathContent = mathMatch.substring(2, mathMatch.length - 2);
      } else if (mathMatch.startsWith(r'$$') && mathMatch.endsWith(r'$$')) {
        mathContent = mathMatch.substring(2, mathMatch.length - 2);
        isBlock = true;
      } else if (mathMatch.startsWith(r'$') && mathMatch.endsWith(r'$')) {
        mathContent = mathMatch.substring(1, mathMatch.length - 1);
      }

      if (mathContent.isNotEmpty) {
        spans.add(
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: _buildMathWidget(mathContent, isInline: !isBlock),
            ),
          ),
        );
      }

      lastIndex = match.end;
    }

    // ── Remaining plain text after last math ─────────────────────────────────
    if (lastIndex < text.length) {
      spans.addAll(_parseFormattingToSpans(text.substring(lastIndex)));
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: SelectableText.rich(
        TextSpan(
          children: spans,
          style: const TextStyle(
            fontSize: 16,
            color: Color(0xFF666666),
            height: 1.6,
          ),
        ),
      ),
    );
  }

  // ── Converts a plain-text segment with **bold** *italic* ~~strike~~
  //    into a list of correctly styled TextSpans ─────────────────────────────────
  List<InlineSpan> _parseFormattingToSpans(String text) {
    if (text.isEmpty) return [];

    final spans = <InlineSpan>[];
    final RegExp formatRegex = RegExp(
      r'\*\*\*(.+?)\*\*\*' // ***bold italic***
      r'|\*\*(.+?)\*\*' // **bold**
      r'|\*(.+?)\*' // *italic*
      r'|~~(.+?)~~', // ~~strikethrough~~
      dotAll: true,
    );

    int lastIndex = 0;

    for (final match in formatRegex.allMatches(text)) {
      // Plain text before this format match
      if (match.start > lastIndex) {
        spans.add(
          TextSpan(
            text: text.substring(lastIndex, match.start),
            style: const TextStyle(
              fontSize: 16,
              color: Color(0xFF666666),
              height: 1.6,
            ),
          ),
        );
      }

      if (match.group(1) != null) {
        // ***bold italic***
        spans.add(
          TextSpan(
            text: match.group(1),
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              fontStyle: FontStyle.italic,
              color: Color(0xFF1A1A1A),
              height: 1.6,
            ),
          ),
        );
      } else if (match.group(2) != null) {
        // **bold**
        spans.add(
          TextSpan(
            text: match.group(2),
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A1A1A),
              height: 1.6,
            ),
          ),
        );
      } else if (match.group(3) != null) {
        // *italic*
        spans.add(
          TextSpan(
            text: match.group(3),
            style: const TextStyle(
              fontSize: 16,
              fontStyle: FontStyle.italic,
              color: Color(0xFF333333),
              height: 1.6,
            ),
          ),
        );
      } else if (match.group(4) != null) {
        // ~~strikethrough~~
        spans.add(
          TextSpan(
            text: match.group(4),
            style: const TextStyle(
              fontSize: 16,
              decoration: TextDecoration.lineThrough,
              color: Color(0xFF666666),
              height: 1.6,
            ),
          ),
        );
      }

      lastIndex = match.end;
    }

    // Any remaining plain text
    if (lastIndex < text.length) {
      spans.add(
        TextSpan(
          text: text.substring(lastIndex),
          style: const TextStyle(
            fontSize: 16,
            color: Color(0xFF666666),
            height: 1.6,
          ),
        ),
      );
    }

    return spans;
  }

  Widget _buildMathWidget(String mathContent, {bool isInline = true}) {
    // Clean up problematic LaTeX commands
    String cleanMath = mathContent;

    // Replace \over with frac
    cleanMath = cleanMath.replaceAll(r'\over', r'\frac');

    // Handle other unsupported commands
    cleanMath = cleanMath.replaceAll(r'\pm', r'\pm');

    return Container(
      padding: EdgeInsets.all(isInline ? 4 : 0),
      child: Math.tex(
        cleanMath,
        textStyle: TextStyle(
          fontSize: isInline ? 16 : 18,
          color: Colors.blue.shade900,
        ),
        onErrorFallback: (FlutterMathException e) {
          print('Math rendering error: $e for expression: $cleanMath');
          // Try a simpler version
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
                fontSize: isInline ? 14 : 16,
              ),
            ),
          );
        },
      ),
    );
  }

  // Update your existing methods to handle math better:

  bool _containsInlineCode(String line) {
    final regex = RegExp(r'`[^`\n]+`');
    return regex.hasMatch(line);
  }

  // Widget _buildLectureParagraph(String text) {
  //   // Check if paragraph contains inline math
  //   if (_containsInlineMath(text)) {
  //     return _buildInlineMathText(text);
  //   }

  //   return Padding(
  //     padding: const EdgeInsets.symmetric(vertical: 8),
  //     child: SelectableText(
  //       text,
  //       style: const TextStyle(
  //         fontSize: 16,
  //         color: Color(0xFF666666),
  //         height: 1.6,
  //       ),
  //     ),
  //   );
  // }

  Widget _buildLectureParagraph(String text) {
    // Check if paragraph contains inline math
    if (_containsInlineMath(text)) {
      return _buildInlineMathText(text);
    }

    // IMPORTANT: Check if paragraph contains markdown formatting
    if (text.contains('**') || text.contains('*') || text.contains('~~')) {
      return _buildLectureText(text); // Use the markdown-aware parser
    }

    // Plain text without formatting
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: SelectableText(
        text,
        style: const TextStyle(
          fontSize: 16,
          color: Color(0xFF666666),
          height: 1.6,
        ),
      ),
    );
  }

  // Widget _buildLectureText(String text) {
  //   // Check if text contains inline math
  //   if (_containsInlineMath(text)) {
  //     return _buildInlineMathText(text);
  //   }

  //   // Handle markdown formatting: **bold**, *italic*, ~~strikethrough~~
  //   final List<InlineSpan> spans = [];
  //   final RegExp markdownRegex = RegExp(
  //     r'(\*\*\*.*?\*\*\*|\*\*.*?\*\*|\*.*?\*|~~.*?~~)',
  //     dotAll: true,
  //   );

  //   int lastIndex = 0;
  //   final matches = markdownRegex.allMatches(text);

  //   for (final match in matches) {
  //     // Add text before the match
  //     if (match.start > lastIndex) {
  //       spans.add(
  //         TextSpan(
  //           text: text.substring(lastIndex, match.start),
  //           style: const TextStyle(
  //             fontSize: 16,
  //             color: Color(0xFF666666),
  //             height: 1.6,
  //           ),
  //         ),
  //       );
  //     }

  //     // Handle the matched formatting
  //     final matchedText = match.group(0)!;

  //     if (matchedText.startsWith('***') && matchedText.endsWith('***')) {
  //       // Bold + Italic
  //       final content = matchedText.substring(3, matchedText.length - 3);
  //       spans.add(
  //         TextSpan(
  //           text: content,
  //           style: const TextStyle(
  //             fontWeight: FontWeight.bold,
  //             fontStyle: FontStyle.italic,
  //             color: Color(0xFF333333),
  //             fontSize: 16,
  //             height: 1.6,
  //           ),
  //         ),
  //       );
  //     } else if (matchedText.startsWith('**') && matchedText.endsWith('**')) {
  //       // Bold
  //       final content = matchedText.substring(2, matchedText.length - 2);
  //       spans.add(
  //         TextSpan(
  //           text: content,
  //           style: const TextStyle(
  //             fontWeight: FontWeight.bold,
  //             color: Color(0xFF333333),
  //             fontSize: 16,
  //             height: 1.6,
  //           ),
  //         ),
  //       );
  //     } else if (matchedText.startsWith('*') && matchedText.endsWith('*')) {
  //       // Italic
  //       final content = matchedText.substring(1, matchedText.length - 1);
  //       spans.add(
  //         TextSpan(
  //           text: content,
  //           style: const TextStyle(
  //             fontStyle: FontStyle.italic,
  //             color: Color(0xFF333333),
  //             fontSize: 16,
  //             height: 1.6,
  //           ),
  //         ),
  //       );
  //     } else if (matchedText.startsWith('~~') && matchedText.endsWith('~~')) {
  //       // Strikethrough
  //       final content = matchedText.substring(2, matchedText.length - 2);
  //       spans.add(
  //         TextSpan(
  //           text: content,
  //           style: const TextStyle(
  //             decoration: TextDecoration.lineThrough,
  //             color: Color(0xFF666666),
  //             fontSize: 16,
  //             height: 1.6,
  //           ),
  //         ),
  //       );
  //     }

  //     lastIndex = match.end;
  //   }

  //   // Add remaining text
  //   if (lastIndex < text.length) {
  //     spans.add(
  //       TextSpan(
  //         text: text.substring(lastIndex),
  //         style: const TextStyle(
  //           fontSize: 16,
  //           color: Color(0xFF666666),
  //           height: 1.6,
  //         ),
  //       ),
  //     );
  //   }

  //   // return SelectableText.rich(TextSpan(children: spans));
  //   return Padding(
  //     padding: const EdgeInsets.symmetric(vertical: 4),
  //     child: SelectableText.rich(TextSpan(children: spans)),
  //   );
  // }

  Widget _buildLectureText(String text) {
    if (text.isEmpty) return const SizedBox.shrink();

    // If line has math, let _buildInlineMathText handle everything
    // including bold/italic between math segments
    if (_containsInlineMath(text)) {
      return _buildInlineMathText(text);
    }

    // Pure text with formatting only
    final spans = _parseFormattingToSpans(text);

    if (spans.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: SelectableText.rich(
        TextSpan(
          children: spans,
          style: const TextStyle(
            fontSize: 16,
            color: Color(0xFF666666),
            height: 1.6,
          ),
        ),
      ),
    );
  }

  String _extractParagraph(List<String> lines, int startIndex) {
    final paragraphLines = <String>[];
    for (int i = startIndex; i < lines.length; i++) {
      final line = lines[i];
      final trimmed = line.trim();
      if (trimmed.isEmpty) {
        break;
      }
      // Skip if it's a special element
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

  bool _containsMath(String line) {
    return line.contains(r'$') ||
        line.contains(r'\(') ||
        line.contains(r'\[') ||
        line.contains(r'$$');
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

  bool _isTableLine(String line) {
    return line.contains('|') &&
        line.split('|').where((p) => p.trim().isNotEmpty).length >= 2;
  }

  List<String> _extractTableFromLines(List<String> lines, int startIndex) {
    final tableLines = <String>[];

    for (int i = startIndex; i < lines.length; i++) {
      if (_isTableLine(lines[i])) {
        tableLines.add(lines[i]);
      } else {
        break;
      }
    }

    return tableLines;
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

  Widget _buildLectureCodeBlock(String code, String language) {
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
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
                    const Icon(Icons.code, size: 16, color: Colors.grey),
                    const SizedBox(width: 8),
                    Text(
                      language.isNotEmpty ? language.toUpperCase() : 'CODE',
                      style: const TextStyle(
                        color: Colors.grey,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
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
                        Icon(Icons.content_copy, size: 12, color: Colors.white),
                        SizedBox(width: 6),
                        Text(
                          'Copy',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
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

          // Code content - FIXED VERSION
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
                          // Line number
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
                          // Code line - Use ConstrainedBox instead of Flexible/Expanded
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

  // $$$$$$$$$$$$$$$$$$$$$$$

  Widget _buildLectureInlineCode(String text) {
    final regex = RegExp(r'`([^`]+)`');
    final matches = regex.allMatches(text);

    if (matches.isEmpty) {
      return _buildLectureText(text);
    }

    final spans = <TextSpan>[];
    int lastIndex = 0;

    for (final match in matches) {
      // Add text before code
      if (match.start > lastIndex) {
        spans.add(
          TextSpan(
            text: text.substring(lastIndex, match.start),
            style: const TextStyle(
              fontSize: 16,
              color: Color(0xFF666666),
              height: 1.6,
            ),
          ),
        );
      }

      // Add code
      spans.add(
        TextSpan(
          text: match.group(1),
          style: TextStyle(
            backgroundColor: Colors.grey.shade200,
            color: Colors.red.shade700,
            fontFamily: 'RobotoMono',
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      );

      lastIndex = match.end;
    }

    // Add remaining text
    if (lastIndex < text.length) {
      spans.add(
        TextSpan(
          text: text.substring(lastIndex),
          style: const TextStyle(
            fontSize: 16,
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

  Widget _buildLectureMathWidget(String text) {
    try {
      // Extract math content
      String mathContent = '';
      bool isBlock = false;

      if (text.contains(r'\[') && text.contains(r'\]')) {
        // Block math
        mathContent = text.substring(
          text.indexOf(r'\[') + 2,
          text.lastIndexOf(r'\]'),
        );
        isBlock = true;
      } else if (text.contains(r'\(') && text.contains(r'\)')) {
        // Inline math
        mathContent = text.substring(
          text.indexOf(r'\(') + 2,
          text.lastIndexOf(r'\)'),
        );
        isBlock = false;
      } else if (text.contains(r'$$')) {
        // Block math with $$
        final parts = text.split(r'$$');
        if (parts.length > 1) {
          mathContent = parts[1];
          isBlock = true;
        }
      } else if (text.contains(r'$')) {
        // Inline math with $
        final parts = text.split(r'$');
        if (parts.length > 1) {
          mathContent = parts[1];
          isBlock = false;
        }
      }

      if (mathContent.isNotEmpty) {
        return Container(
          margin: EdgeInsets.symmetric(vertical: isBlock ? 12 : 4),
          padding: EdgeInsets.all(isBlock ? 16 : 8),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(isBlock ? 8 : 4),
            border: Border.all(
              color: Colors.blue.shade200,
              width: isBlock ? 1.5 : 1,
            ),
          ),
          child: Center(
            child: Math.tex(
              mathContent.trim(),
              textStyle: TextStyle(
                fontSize: isBlock ? 18 : 16,
                color: Colors.blue.shade900,
              ),
              onErrorFallback: (FlutterMathException e) {
                return Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: SelectableText(
                    mathContent.trim(),
                    style: TextStyle(
                      fontFamily: 'RobotoMono',
                      color: Colors.orange.shade800,
                      fontSize: isBlock ? 14 : 12,
                    ),
                  ),
                );
              },
            ),
          ),
        );
      }
    } catch (e) {
      print('Error rendering math: $e');
    }

    return _buildLectureText(text);
  }

  Widget _buildLectureImage(String line) {
    try {
      String imageUrl = '';
      String altText = '';

      // Parse markdown image
      final markdownRegex = RegExp(r'!\[(.*?)\]\((.*?)\)');
      final markdownMatch = markdownRegex.firstMatch(line);

      if (markdownMatch != null) {
        altText = markdownMatch.group(1) ?? '';
        imageUrl = markdownMatch.group(2) ?? '';
      } else {
        // Try direct URL
        final urlRegex = RegExp(r'https?://[^\s]+');
        final urlMatch = urlRegex.firstMatch(line);
        if (urlMatch != null) {
          imageUrl = urlMatch.group(0) ?? '';
        }
      }

      if (imageUrl.isNotEmpty) {
        return Container(
          margin: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Container(
                      height: 200,
                      color: Colors.grey.shade200,
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
                    return Container(
                      height: 200,
                      color: Colors.grey.shade200,
                      child: const Center(
                        child: Icon(
                          Icons.broken_image,
                          size: 40,
                          color: Colors.grey,
                        ),
                      ),
                    );
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
    } catch (e) {
      print('Error loading image: $e');
    }

    return const SizedBox.shrink();
  }

  Widget _buildLectureHeading(String line) {
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
        fontSize = 24;
        fontWeight = FontWeight.bold;
        color = const Color(0xFF333333);
        padding = const EdgeInsets.only(top: 16, bottom: 8);
        break;
      case 2:
        fontSize = 20;
        fontWeight = FontWeight.bold;
        color = const Color(0xFF333333);
        padding = const EdgeInsets.only(top: 14, bottom: 6);
        break;
      case 3:
        fontSize = 18;
        fontWeight = FontWeight.w600;
        color = const Color(0xFF444444);
        padding = const EdgeInsets.only(top: 12, bottom: 4);
        break;
      case 4:
        fontSize = 16;
        fontWeight = FontWeight.w600;
        color = const Color(0xFF555555);
        padding = const EdgeInsets.only(top: 10, bottom: 3);
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

  Widget _buildLectureTable(List<String> tableLines) {
    try {
      if (tableLines.isEmpty) return Container();

      final rows = tableLines.map((line) {
        return line.split('|').map((cell) => cell.trim()).toList();
      }).toList();

      // Remove empty columns
      for (final row in rows) {
        row.removeWhere((cell) => cell.isEmpty);
      }

      // Remove separator row if present
      bool hasSeparator =
          rows.length > 1 &&
          rows[1].every((cell) => RegExp(r'^:?-+:?$').hasMatch(cell));

      final dataRows = hasSeparator ? rows.sublist(2) : rows.sublist(1);

      if (rows.isEmpty || dataRows.isEmpty) return Container();

      return Container(
        margin: const EdgeInsets.symmetric(vertical: 12),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columnSpacing: 16,
            horizontalMargin: 12,
            headingRowColor: MaterialStateProperty.all(Colors.blue.shade50),
            dataRowColor: MaterialStateProperty.all(Colors.white),
            columns: rows[0].map((header) {
              return DataColumn(
                label: SizedBox(
                  width: 120,
                  child: Text(
                    header,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              );
            }).toList(),
            rows: dataRows.map((row) {
              return DataRow(
                cells: List.generate(rows[0].length, (index) {
                  final cell = index < row.length ? row[index] : '';
                  return DataCell(
                    SizedBox(
                      width: 120,
                      child: Text(cell, overflow: TextOverflow.ellipsis),
                    ),
                  );
                }),
              );
            }).toList(),
          ),
        ),
      );
    } catch (e) {
      print('Error rendering table: $e');
      return Container();
    }
  }

  Widget _buildLectureList(List<String> items) {
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
                Expanded(child: _buildLectureText(text)),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildStatItem(IconData icon, String value, String label) {
    return Column(
      children: [
        Icon(icon, size: 24, color: const Color(0xFF667eea)),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Color(0xFF333333),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Color(0xFF999999)),
        ),
      ],
    );
  }

  Widget _buildPastQuestionsButton(Color courseColor) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton.icon(
        onPressed: _isLoadingContent ? null : _showRelatedPastQuestions,
        style: ElevatedButton.styleFrom(
          backgroundColor: courseColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 2,
        ),
        icon: _isLoadingContent
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.history_edu_rounded, size: 20),
        label: _isLoadingContent
            ? const Text('Loading...')
            : const Text(
                'Show Related Past Questions',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
      ),
    );
  }

  Widget _buildBottomNavigation(Color courseColor) {
    final hasPrevious = _currentTopicIndex > 0;
    final hasNext = _currentTopicIndex < _topics.length - 1;
    final isLastTopic = _currentTopicIndex == _topics.length - 1;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          if (hasPrevious)
            Expanded(
              child: SizedBox(
                height: 50,
                child: OutlinedButton.icon(
                  onPressed: _navigateToPreviousTopic,
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFE0E0E0)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.arrow_back_ios_rounded, size: 16),
                  label: const Text(
                    'Previous',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF333333),
                    ),
                  ),
                ),
              ),
            ),
          if (hasPrevious) const SizedBox(width: 12),

          Expanded(
            child: SizedBox(
              height: 50,
              child: ElevatedButton.icon(
                onPressed: () {
                  if (_currentTopic != null &&
                      _currentTopic!.completionQuestionText != null &&
                      _currentTopic!.completionQuestionText!.isNotEmpty &&
                      !_currentTopic!.isCompleted) {
                    _showCompletionQuestion();
                  } else {
                    _navigateToNextTopic();
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: courseColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 4,
                ),
                icon: Icon(
                  isLastTopic
                      ? Icons.check_rounded
                      : Icons.arrow_forward_ios_rounded,
                  size: 16,
                ),
                label: Text(
                  isLastTopic ? 'Complete Outline' : 'Next',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingVoiceIcon(Color courseColor) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: courseColor,
        borderRadius: BorderRadius.circular(_isVoiceIconExpanded ? 25 : 30),
        boxShadow: [
          BoxShadow(
            color: courseColor.withOpacity(0.4),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.mic_rounded, color: Colors.white, size: 24),
          if (_isVoiceIconExpanded) ...[
            const SizedBox(width: 8),
            const Text(
              'Talk to Cereva on this',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 20),
          Text(
            'Loading topics...',
            style: TextStyle(fontSize: 16, color: Color(0xFF666666)),
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
              _isOfflineMode ? Icons.wifi_off_rounded : Icons.error_outline,
              size: 60,
              color: _isOfflineMode ? Colors.orange : Colors.red,
            ),
            const SizedBox(height: 20),
            Text(
              _errorMessage,
              style: const TextStyle(fontSize: 16, color: Color(0xFF666666)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            if (!_isOfflineMode)
              ElevatedButton(
                onPressed: _loadTopics,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF667eea),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text(
                  'Retry',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            if (_isOfflineMode && !_isCourseDownloaded)
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text(
                  'Go Back to Courses',
                  style: TextStyle(color: Colors.white),
                ),
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
            Icon(Icons.menu_book, size: 60, color: Colors.grey[400]),
            const SizedBox(height: 20),
            const Text(
              'No topics available',
              style: TextStyle(
                fontSize: 18,
                color: Color(0xFF666666),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Topics will be added soon by your instructor',
              style: TextStyle(color: Color(0xFF999999), fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF667eea),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text(
                'Back to Outline',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _darkenColor(Color color, double factor) {
    final hsl = HSLColor.fromColor(color);
    final hslDark = hsl.withLightness((hsl.lightness - factor).clamp(0.0, 1.0));
    return hslDark.toColor();
  }
}

// ========== KEEP YOUR EXISTING CompletionQuestionDialog CLASS ==========

class CompletionQuestionDialog extends StatefulWidget {
  final Topic topic;
  final Function(bool) onAnswerSubmitted;
  final VoidCallback? onSkip;

  const CompletionQuestionDialog({
    Key? key,
    required this.topic,
    required this.onAnswerSubmitted,
    this.onSkip,
  }) : super(key: key);

  @override
  _CompletionQuestionDialogState createState() =>
      _CompletionQuestionDialogState();
}

class _CompletionQuestionDialogState extends State<CompletionQuestionDialog> {
  String? _selectedAnswer;
  TextEditingController _textAnswerController = TextEditingController();
  bool _isSubmitting = false;
  bool _showSolution = false;

  @override
  Widget build(BuildContext context) {
    final hasOptions =
        widget.topic.options != null && widget.topic.options!.isNotEmpty;
    final questionText =
        widget.topic.completionQuestionText ??
        'Complete this topic to continue';
    final solutionText = widget.topic.solutionText;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.quiz_rounded, color: Color(0xFF667eea)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Topic Completion Quiz',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF333333),
                    ),
                  ),
                ),
                if (widget.onSkip != null && !_showSolution)
                  IconButton(
                    icon: const Icon(
                      Icons.close,
                      size: 20,
                      color: Color(0xFF999999),
                    ),
                    onPressed: () {
                      widget.onSkip?.call();
                    },
                  ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Answer correctly to mark this topic as completed',
              style: TextStyle(fontSize: 14, color: Color(0xFF666666)),
            ),
            const SizedBox(height: 24),

            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF8F9FA),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Question:',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF666666),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    questionText,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF333333),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            if (hasOptions)
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: (widget.topic.options ?? []).map((option) {
                      final letter = option['letter']?.toString();
                      final text = option['text']?.toString();
                      final isSelected = _selectedAnswer == letter;

                      return GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          if (!_showSolution) {
                            setState(() {
                              _selectedAnswer = letter;
                            });
                          }
                        },
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? const Color(0xFF667eea).withOpacity(0.1)
                                : const Color(0xFFF8F9FA),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected
                                  ? const Color(0xFF667eea)
                                  : const Color(0xFFE0E0E0),
                              width: isSelected ? 2 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 24,
                                height: 24,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isSelected
                                      ? const Color(0xFF667eea)
                                      : Colors.transparent,
                                  border: Border.all(
                                    color: isSelected
                                        ? const Color(0xFF667eea)
                                        : const Color(0xFF999999),
                                  ),
                                ),
                                child: Center(
                                  child: Text(
                                    letter ?? '?',
                                    style: TextStyle(
                                      color: isSelected
                                          ? Colors.white
                                          : const Color(0xFF333333),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Text(
                                  text ?? 'Option',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Color(0xFF333333),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            if (!hasOptions)
              TextField(
                controller: _textAnswerController,
                maxLines: 3,
                decoration: InputDecoration(
                  // REMOVE const from here
                  hintText: 'Type your answer here...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: const Color(0xFFF8F9FA),
                ),
                enabled: !_showSolution,
              ),

            if (_showSolution && solutionText != null)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.withOpacity(0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Incorrect Answer',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.red,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        solutionText!,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF333333),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Try again with the correct answer.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.red,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: 24),

            Row(
              children: [
                if (widget.onSkip != null && !_showSolution)
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isSubmitting
                          ? null
                          : () {
                              widget.onSkip?.call();
                            },
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFFE0E0E0)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text(
                        'Skip',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF666666),
                        ),
                      ),
                    ),
                  ),
                if (widget.onSkip != null && !_showSolution)
                  const SizedBox(width: 12),

                Expanded(
                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : _submitAnswer,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _showSolution
                          ? const Color(0xFF667eea)
                          : const Color(0xFF667eea),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: _isSubmitting
                        ? SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            _showSolution ? 'Try Again' : 'Submit',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submitAnswer() async {
    if (widget.topic.options != null &&
        widget.topic.options!.isNotEmpty &&
        _selectedAnswer == null &&
        !_showSolution) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select an answer'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if ((widget.topic.options == null || widget.topic.options!.isEmpty) &&
        _textAnswerController.text.isEmpty &&
        !_showSolution) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter your answer'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final ApiService apiService = ApiService();

      final result = await apiService.submitTopicAnswer(
        topicId: int.tryParse(widget.topic.id) ?? 0,
        selectedAnswer: _selectedAnswer,
        answerText: _textAnswerController.text,
      );

      final isCorrect = result['is_correct'] ?? false;

      setState(() {
        _isSubmitting = false;
      });

      if (isCorrect) {
        Navigator.pop(context);
        widget.onAnswerSubmitted(true);
      } else {
        setState(() {
          _showSolution = true;
        });
      }
    } catch (e) {
      setState(() {
        _isSubmitting = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error submitting answer: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  void dispose() {
    _textAnswerController.dispose();
    super.dispose();
  }
}

// Add this class AFTER your _LectureScreenState class (at the bottom of the file)
class CodeElementBuilder extends MarkdownElementBuilder {
  final Function(String) onCopyCode;

  CodeElementBuilder({required this.onCopyCode});

  @override
  Widget? visitElementAfter(md.Element element, TextStyle? preferredStyle) {
    final codeContent = element.textContent;

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
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
                    const Icon(Icons.code, size: 16, color: Colors.grey),
                    const SizedBox(width: 8),
                    const Text(
                      'CODE',
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                GestureDetector(
                  onTap: () => onCopyCode(codeContent),
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
                        Icon(Icons.content_copy, size: 12, color: Colors.white),
                        SizedBox(width: 6),
                        Text(
                          'Copy',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
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

          // Code content
          Padding(
            padding: const EdgeInsets.all(16),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SelectableText(
                codeContent,
                style: const TextStyle(
                  fontFamily: 'RobotoMono',
                  fontSize: 14,
                  color: Color(0xFFD4D4D4),
                  height: 1.4,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

extension StringRepeat on String {
  String repeat(int times) {
    if (times <= 0) return '';
    return List.filled(times, this).join();
  }
}
