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
      
      print('📱 Connectivity: $_isOfflineMode, Course Downloaded: $_isCourseDownloaded');
      
      if (_isOfflineMode && !_isCourseDownloaded) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'You are offline and this course is not downloaded. Please connect to the internet or download the course first.';
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
      final downloadedCourseIds = offlineBox.get('downloaded_course_ids', defaultValue: <String>[]);
      
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
        topics = await _getOfflineTopics(widget.course.id, selectedOutlineId.toString());
        
        if (topics.isNotEmpty) {
          print('✅ Loaded ${topics.length} topics from offline storage');
        } else if (!_isOfflineMode) {
          // Offline storage empty but we're online - try API
          print('📂 No offline topics, trying API...');
          topics = await _apiService.getTopics(outlineId: selectedOutlineId);
        } else {
          // Offline and no offline data available
          throw Exception('No topics available offline. Please re-download the course.');
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
        if (_currentTopic?.videoUrl != null && _currentTopic!.videoUrl!.isNotEmpty) {
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

  // Get offline topics
  // Future<List<Topic>> _getOfflineTopics(String courseId, String outlineId) async {
  //   try {
  //     final offlineBox = await Hive.openBox('offline_courses');
  //     final courseData = offlineBox.get('course_$courseId');
      
  //     if (courseData != null && courseData['topics'] != null) {
  //       final topicsJson = courseData['topics'] as List;
  //       final allTopics = topicsJson.map((json) => Topic.fromJson(json)).toList();
        
  //       // Filter topics by outlineId
  //       final outlineTopics = allTopics.where((topic) => topic.outlineId == outlineId).toList();
        
  //       print('📂 Found ${outlineTopics.length} topics for outline $outlineId in offline storage');
  //       return outlineTopics;
  //     }
  //   } catch (e) {
  //     print('❌ Error getting offline topics: $e');
  //   }
  //   return [];
  // }

  // Get offline topics - FIXED VERSION
Future<List<Topic>> _getOfflineTopics(String courseId, String outlineId) async {
  try {
    print('🔍 Getting offline topics for course: $courseId, outline: $outlineId');
    
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
      
      print('📊 Filtered to ${outlineTopics.length} topics for outline $outlineId');
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
          final downloadedImages = Map<String, String>.from(courseData['downloaded_images']);
          
          // Try to find the image by topic ID
          if (_currentTopic != null && downloadedImages.containsKey(_currentTopic!.id)) {
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
            if (entry.key.contains('topic') && entry.value.contains(imagePath.split('/').last)) {
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
        ..setNavigationDelegate(NavigationDelegate(
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
            print('❌ Web resource error: ${error.errorCode} - ${error.description}');
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
        ))
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
    if (_currentTopic?.videoUrl != null && _currentTopic!.videoUrl!.isNotEmpty) {
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
    if (_currentTopic == null || _currentTopic!.completionQuestionText == null) {
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
                print('✅ Correct answer! Topic will be marked as completed by Django...');
                
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
        topics = await _getOfflineTopics(widget.course.id, selectedOutlineId.toString());
      } else {
        topics = await _apiService.getTopics(outlineId: selectedOutlineId);
      }
      
      if (topics.isNotEmpty) {
        setState(() {
          _topics = topics;
          if (_currentTopic != null) {
            final currentIndex = topics.indexWhere((t) => t.id == _currentTopic!.id);
            if (currentIndex != -1) {
              _currentTopic = topics[currentIndex];
              _currentTopicIndex = currentIndex;
              selectedTopicId = _currentTopic!.id;
            }
          }
        });
        print('✅ Topics refreshed. Completed: ${topics.where((t) => t.isCompleted).length}/${topics.length}');
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
      int progress = totalTopics > 0 ? ((completedCount / totalTopics) * 100).round() : 0;
      
      final box = await Hive.openBox('course_progress_cache');
      await box.put('progress_$courseId', progress);
      
      print('💾 Updated course $courseId progress in cache: $progress%');
      
    } catch (e) {
      print('⚠️ Error updating course progress cache: $e');
    }
  }

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
            courseCode: _getCourseCode(widget.course),
            topicTitle: _currentTopic!.title,
            topicId: _currentTopic!.id,
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
      await launchUrl(
        url,
        mode: LaunchMode.externalApplication,
      );
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
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.blue,
                  ),
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
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
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
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
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
      backgroundColor: courseColor.withOpacity(0.05),
      body: Stack(
        children: [
          Column(
            children: [
              _buildHeader(courseColor),
              
              // Offline indicator banner
              if (_isOfflineMode && _isCourseDownloaded)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  color: Colors.green.withOpacity(0.1),
                  child: Row(
                    children: [
                      Icon(Icons.download_done_rounded, size: 16, color: Colors.green.shade700),
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
                        Icon(Icons.wifi_off_rounded, size: 16, color: Colors.green.shade700),
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
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: Colors.white),
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
    double progress = totalTopics > 0 ? (completedCount / totalTopics) * 100 : 0;
    
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
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF999999),
                ),
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
                  final index = _topics.indexWhere((topic) => topic.id == newValue.id);
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
                            const Icon(Icons.check_circle, size: 16, color: Colors.green),
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
                          const Icon(Icons.check_circle, size: 16, color: Colors.green),
                        if (isCompleted) const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${topic.order}. ${topic.title}',
                            style: TextStyle(
                              fontSize: 14,
                              color: isSelected ? courseColor : const Color(0xFF333333),
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
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
          await launchUrl(
            youtubeAppUri,
            mode: LaunchMode.externalApplication,
          );
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
                          Icon(Icons.videocam_off, size: 60, color: Colors.grey[700]),
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
                      Icon(Icons.videocam_off, size: 60, color: Colors.grey[700]),
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
                  colors: [
                    Colors.transparent,
                    Colors.black.withOpacity(0.7),
                  ],
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
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
                      shadows: [
                        Shadow(
                          color: Colors.black,
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.touch_app, size: 16, color: Colors.white70),
                      const SizedBox(width: 5),
                      const Text(
                        'Tap to watch in YouTube app',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                          shadows: [
                            Shadow(
                              color: Colors.black,
                              blurRadius: 5,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (_currentTopic?.durationMinutes != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Row(
                        children: [
                          const Icon(Icons.timer, size: 16, color: Colors.white70),
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
            colors: [
              Colors.black.withOpacity(0.7),
              Colors.transparent,
            ],
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
            Icon(Icons.image_not_supported, size: 40, color: courseColor.withOpacity(0.5)),
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

  Widget _buildContentCard(Topic topic, Color courseColor) {
    return Material(
      elevation: 4,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Padding(
          padding: const EdgeInsets.all(25),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                topic.title,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF333333),
                  height: 1.3,
                ),
              ),
              if (topic.description != null && topic.description!.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  topic.description!,
                  style: const TextStyle(
                    fontSize: 16,
                    color: Color(0xFF666666),
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
              const SizedBox(height: 15),
              
              // Stats
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
                        'Duration'
                      ),
                    _buildStatItem(
                      Icons.book_rounded, 
                      'Topic ${topic.order}', 
                      'Position'
                    ),
                    if (topic.completionQuestionText != null && topic.completionQuestionText!.isNotEmpty)
                      _buildStatItem(
                        Icons.quiz_rounded, 
                        'Quiz', 
                        'Assessment'
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 25),
              
              // Content
              if (topic.content != null && topic.content!.isNotEmpty)
                Text(
                  topic.content!,
                  style: const TextStyle(
                    fontSize: 16,
                    color: Color(0xFF666666),
                    height: 1.6,
                  ),
                )
              else
                Text(
                  'No detailed content available for this topic.',
                  style: const TextStyle(
                    fontSize: 16,
                    color: Color(0xFF999999),
                    fontStyle: FontStyle.italic,
                  ),
                ),
            ],
          ),
        ),
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
          style: const TextStyle(
            fontSize: 12,
            color: Color(0xFF999999),
          ),
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
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
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
                  isLastTopic ? Icons.check_rounded : Icons.arrow_forward_ios_rounded,
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
          const Icon(
            Icons.mic_rounded,
            color: Colors.white,
            size: 24,
          ),
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
            style: TextStyle(
              fontSize: 16,
              color: Color(0xFF666666),
            ),
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
              color: _isOfflineMode ? Colors.orange : Colors.red
            ),
            const SizedBox(height: 20),
            Text(
              _errorMessage,
              style: const TextStyle(
                fontSize: 16,
                color: Color(0xFF666666),
              ),
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
              style: TextStyle(
                color: Color(0xFF999999),
                fontSize: 14,
              ),
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
  _CompletionQuestionDialogState createState() => _CompletionQuestionDialogState();
}

class _CompletionQuestionDialogState extends State<CompletionQuestionDialog> {
  String? _selectedAnswer;
  TextEditingController _textAnswerController = TextEditingController();
  bool _isSubmitting = false;
  bool _showSolution = false;

  @override
  Widget build(BuildContext context) {
    final hasOptions = widget.topic.options != null && widget.topic.options!.isNotEmpty;
    final questionText = widget.topic.completionQuestionText ?? 'Complete this topic to continue';
    final solutionText = widget.topic.solutionText;

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        constraints: const BoxConstraints(
          maxWidth: 500,
          maxHeight: 600,
        ),
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
                    icon: const Icon(Icons.close, size: 20, color: Color(0xFF999999)),
                    onPressed: () {
                      widget.onSkip?.call();
                    },
                  ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Answer correctly to mark this topic as completed',
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF666666),
              ),
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
                            color: isSelected ? const Color(0xFF667eea).withOpacity(0.1) : const Color(0xFFF8F9FA),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected ? const Color(0xFF667eea) : const Color(0xFFE0E0E0),
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
                                  color: isSelected ? const Color(0xFF667eea) : Colors.transparent,
                                  border: Border.all(
                                    color: isSelected ? const Color(0xFF667eea) : const Color(0xFF999999),
                                  ),
                                ),
                                child: Center(
                                  child: Text(
                                    letter ?? '?',
                                    style: TextStyle(
                                      color: isSelected ? Colors.white : const Color(0xFF333333),
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
            
            // if (!hasOptions)
            //   TextField(
            //     controller: _textAnswerController,
            //     maxLines: 3,
            //     decoration: const InputDecoration(
            //       hintText: 'Type your answer here...',
            //       border: OutlineInputBorder(
            //         borderRadius: BorderRadius.circular(12.0),
            //       ),
            //       filled: true,
            //       fillColor: Color(0xFFF8F9FA),
            //     ),
            //     enabled: !_showSolution,
            //   ),
            if (!hasOptions)
              TextField(
                controller: _textAnswerController,
                maxLines: 3,
                decoration: InputDecoration( // REMOVE const from here
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
                      onPressed: _isSubmitting ? null : () {
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
                if (widget.onSkip != null && !_showSolution) const SizedBox(width: 12),
                
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : _submitAnswer,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _showSolution ? const Color(0xFF667eea) : const Color(0xFF667eea),
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
    if (widget.topic.options != null && widget.topic.options!.isNotEmpty && _selectedAnswer == null && !_showSolution) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select an answer'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    
    if ((widget.topic.options == null || widget.topic.options!.isEmpty) && _textAnswerController.text.isEmpty && !_showSolution) {
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