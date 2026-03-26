// lib/features/courses/screens/course_detail_screen.dart
import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../../../core/network/api_service.dart';
import '../../../core/services/activation_status_service.dart';
import '../../../core/services/event_bus.dart';
import '../../../features/courses/models/course_models.dart';
import '../../../core/constants/endpoints.dart';
import 'lectures.dart';
import '../../../services/offline_service.dart';
import '../../../managers/offline_data_manager.dart';

class CourseDetailsScreen extends StatefulWidget {
  final Course course;

  const CourseDetailsScreen({Key? key, required this.course}) : super(key: key);

  @override
  State<CourseDetailsScreen> createState() => _CourseDetailsScreenState();
}

class _CourseDetailsScreenState extends State<CourseDetailsScreen> {
  final ApiService _apiService = ApiService();
  final Connectivity _connectivity = Connectivity();

  List<CourseOutline> outlines = [];
  Map<String, int> outlineProgress = {};
  bool isLoading = true;
  bool hasError = false;
  String errorMessage = '';

  // Activation status
  bool _isUserActivated = false;
  bool _checkingActivation = false;
  String _activationStatusMessage = 'Checking activation status...';

  // Track when screen was last refreshed
  DateTime? _lastRefreshTime;
  static const Duration _refreshInterval = Duration(minutes: 5);
  StreamSubscription<ActivationStatusChangedEvent>? _activationChangedSubscription;

  @override
  void initState() {
    super.initState();
    _activationChangedSubscription = EventBusService.instance
        .on<ActivationStatusChangedEvent>()
        .listen((event) {
          if (!mounted) return;
          setState(() {
            _isUserActivated = event.isActivated;
            _activationStatusMessage = event.isActivated
                ? (event.grade?.toUpperCase() ?? 'Activated')
                : 'Not Activated';
            _checkingActivation = false;
          });
        });

    // Start loading immediately
    _loadData();
  }

  @override
  void dispose() {
    _activationChangedSubscription?.cancel();
    super.dispose();
  }

  /// Main data loading method
  // Future<void> _loadData() async {
  //   setState(() {
  //     isLoading = true;
  //     hasError = false;
  //   });

  //   try {
  //     // Check connectivity
  //     final connectivityResult = await _connectivity.checkConnectivity();
  //     final isConnected = connectivityResult != ConnectivityResult.none;

  //     // FIRST: Try to get offline outlines if course is downloaded (FASTEST)
  //     if (widget.course.isDownloaded) {
  //       final offlineOutlines = await _getDirectOfflineOutlines(
  //         widget.course.id,
  //       );
  //       if (offlineOutlines.isNotEmpty) {
  //         print(
  //           '✅ Showing ${offlineOutlines.length} offline outlines immediately',
  //         );

  //         // Load cached progress
  //         await _loadCachedProgress(offlineOutlines);

  //         setState(() {
  //           outlines = offlineOutlines;
  //           isLoading = false;
  //         });

  //         // Still try to get fresh data in background if online
  //         if (isConnected) {
  //           _fetchFreshData(isConnected);
  //         }
  //         return;
  //       }
  //     }

  //     // SECOND: Try cached outlines
  //     final cachedOutlines = await _getCachedOutlines(widget.course.id);
  //     if (cachedOutlines.isNotEmpty) {
  //       print('✅ Showing ${cachedOutlines.length} cached outlines');

  //       await _loadCachedProgress(cachedOutlines);

  //       setState(() {
  //         outlines = cachedOutlines;
  //         isLoading = false;
  //       });

  //       // Still try to get fresh data in background if online
  //       if (isConnected) {
  //         _fetchFreshData(isConnected);
  //       }
  //       return;
  //     }

  //     // THIRD: No cache, no offline - fetch from API
  //     if (isConnected) {
  //       print('🌐 No cache, fetching from API...');
  //       final apiOutlines = await _apiService.getCourseOutlines(
  //         int.parse(widget.course.id),
  //       );

  //       if (apiOutlines.isNotEmpty) {
  //         await _calculateOutlineProgress(apiOutlines, fromOffline: false);

  //         setState(() {
  //           outlines = apiOutlines;
  //           isLoading = false;
  //         });

  //         await _cacheOutlines(apiOutlines);
  //       } else {
  //         // No outlines found
  //         setState(() {
  //           isLoading = false;
  //           outlines = [];
  //         });
  //       }
  //     } else {
  //       // Offline and no downloaded content
  //       setState(() {
  //         isLoading = false;
  //         hasError = true;
  //         errorMessage = widget.course.isDownloaded
  //             ? 'Course was downloaded but no content found. Try re-downloading.'
  //             : 'No internet connection. Please download this course for offline access.';
  //       });
  //     }
  //   } catch (e) {
  //     print('❌ Error loading data: $e');
  //     setState(() {
  //       isLoading = false;
  //       hasError = true;
  //       errorMessage = 'Failed to load course content. Please try again.';
  //     });
  //   }
  // }

  /// Main data loading method
  Future<void> _loadData() async {
    setState(() {
      isLoading = true;
      hasError = false;
    });

    try {
      // Check connectivity
      final connectivityResult = await _connectivity.checkConnectivity();
      final isConnected = connectivityResult != ConnectivityResult.none;

      // FIRST: Try to get offline outlines if course is downloaded (FASTEST)
      if (widget.course.isDownloaded) {
        final offlineOutlines = await _getDirectOfflineOutlines(
          widget.course.id,
        );
        if (offlineOutlines.isNotEmpty) {
          print(
            '✅ Showing ${offlineOutlines.length} offline outlines immediately',
          );

          // Show outlines immediately without progress
          setState(() {
            outlines = offlineOutlines;
            isLoading = false;
          });

          // Load progress in background (don't await)
          _loadCachedProgress(offlineOutlines).then((_) {
            // Still try to get fresh data in background if online
            if (isConnected) {
              _fetchFreshData(isConnected);
            }
          });
          return;
        }
      }

      // SECOND: Try cached outlines
      final cachedOutlines = await _getCachedOutlines(widget.course.id);
      if (cachedOutlines.isNotEmpty) {
        print('✅ Showing ${cachedOutlines.length} cached outlines');

        // Show outlines immediately without progress
        setState(() {
          outlines = cachedOutlines;
          isLoading = false;
        });

        // Load progress in background (don't await)
        _loadCachedProgress(cachedOutlines).then((_) {
          // Still try to get fresh data in background if online
          if (isConnected) {
            _fetchFreshData(isConnected);
          }
        });
        return;
      }

      // THIRD: No cache, no offline - fetch from API
      if (isConnected) {
        print('🌐 No cache, fetching from API...');
        final apiOutlines = await _apiService.getCourseOutlines(
          int.parse(widget.course.id),
        );

        if (apiOutlines.isNotEmpty) {
          // Show outlines immediately without progress
          setState(() {
            outlines = apiOutlines;
            isLoading = false;
          });

          // Calculate progress in background (don't await)
          _calculateOutlineProgress(apiOutlines, fromOffline: false);
          await _cacheOutlines(apiOutlines);
        } else {
          // No outlines found
          setState(() {
            isLoading = false;
            outlines = [];
          });
        }
      } else {
        // Offline and no downloaded content
        setState(() {
          isLoading = false;
          hasError = true;
          errorMessage = widget.course.isDownloaded
              ? 'Course was downloaded but no content found. Try re-downloading.'
              : 'No internet connection. Please download this course for offline access.';
        });
      }
    } catch (e) {
      print('❌ Error loading data: $e');
      setState(() {
        isLoading = false;
        hasError = true;
        errorMessage = 'Failed to load course content. Please try again.';
      });
    }
  }

  /// Fetch fresh data in background (doesn't block UI)
  // Future<void> _fetchFreshData(bool isConnected) async {
  //   try {
  //     // Check activation in background
  //     _checkActivationStatus(forceRefresh: true);

  //     if (!isConnected) return;

  //     final freshOutlines = await _apiService.getCourseOutlines(
  //       int.parse(widget.course.id),
  //     );

  //     if (freshOutlines.isNotEmpty && mounted) {
  //       await _calculateOutlineProgress(freshOutlines, fromOffline: false);

  //       setState(() {
  //         outlines = freshOutlines;
  //       });

  //       await _cacheOutlines(freshOutlines);
  //       print('✅ Updated with fresh outlines');
  //     }

  //     _lastRefreshTime = DateTime.now();
  //   } catch (e) {
  //     print('⚠️ Background fetch error: $e');
  //   }
  // }

  /// Fetch fresh data in background (doesn't block UI)
  Future<void> _fetchFreshData(bool isConnected) async {
    try {
      // Check activation in background
      _checkActivationStatus(forceRefresh: true);

      if (!isConnected) return;

      final freshOutlines = await _apiService.getCourseOutlines(
        int.parse(widget.course.id),
      );

      if (freshOutlines.isNotEmpty && mounted) {
        // Update UI with fresh outlines
        setState(() {
          outlines = freshOutlines;
        });

        // Calculate progress in background (don't await)
        _calculateOutlineProgress(freshOutlines, fromOffline: false);
        await _cacheOutlines(freshOutlines);
        print('✅ Updated with fresh outlines');
      }

      _lastRefreshTime = DateTime.now();
    } catch (e) {
      print('⚠️ Background fetch error: $e');
    }
  }

  /// Get cached outlines
  Future<List<CourseOutline>> _getCachedOutlines(String courseId) async {
    try {
      final box = await Hive.openBox('course_outlines_cache');
      final cachedData = box.get('outlines_$courseId');

      if (cachedData != null && cachedData is List) {
        return cachedData.map((json) => CourseOutline.fromJson(json)).toList();
      }
    } catch (e) {
      print('⚠️ Error getting cached outlines: $e');
    }
    return [];
  }

  /// Load cached progress
  Future<void> _loadCachedProgress(List<CourseOutline> outlines) async {
    try {
      final progressBox = await Hive.openBox('outline_progress_cache');

      for (var outline in outlines) {
        final cachedProgress = progressBox.get('outline_${outline.id}');
        outlineProgress[outline.id] = cachedProgress ?? 0;
      }

      print('📊 Loaded cached progress for ${outlines.length} outlines');
    } catch (e) {
      print('⚠️ Error loading cached progress: $e');
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkForRefresh();
    });
  }

  void _checkForRefresh() {
    if (_lastRefreshTime != null) {
      final now = DateTime.now();
      final difference = now.difference(_lastRefreshTime!);
      if (difference > _refreshInterval) {
        _refreshAllData();
      }
    }
  }

  Future<void> _refreshAllData() async {
    print('🔄 Refreshing all data...');
    await _checkActivationStatus(forceRefresh: true);
    await _loadData();
    _lastRefreshTime = DateTime.now();
  }

  Future<void> _checkActivationStatus({bool forceRefresh = false}) async {
    if (mounted) {
      setState(() {
        _checkingActivation = true;
      });
    }

    try {
      final cachedStatus = await ActivationStatusService.getCachedStatus();
      if (cachedStatus.hasCachedValue && mounted) {
        setState(() {
          _isUserActivated = cachedStatus.isActivated;
          _activationStatusMessage = cachedStatus.isActivated
              ? (cachedStatus.grade?.toUpperCase() ?? 'Activated')
              : 'Not Activated';
        });
      }

      final status = await ActivationStatusService.resolveStatus(
        forceRefresh: forceRefresh,
      );

      if (!mounted) return;

      setState(() {
        _isUserActivated = status.isActivated;
        _activationStatusMessage = status.isActivated
            ? (status.grade?.toUpperCase() ?? 'Activated')
            : 'Not Activated';
      });
    } catch (e) {
      print('❌ Error in activation check: $e');
      if (mounted) {
        setState(() {
          _activationStatusMessage = _isUserActivated
              ? 'Activated'
              : 'Not Activated';
          _checkingActivation = false;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _checkingActivation = false;
        });
      }
    }
  }

  Future<void> _cacheOutlines(List<CourseOutline> outlines) async {
    try {
      final courseId = widget.course.id;
      final box = await Hive.openBox('course_outlines_cache');
      final outlinesData = outlines.map((outline) => outline.toJson()).toList();

      await box.put('outlines_$courseId', outlinesData);
      await box.put(
        'outlines_timestamp_$courseId',
        DateTime.now().toIso8601String(),
      );

      print('💾 Cached ${outlines.length} outlines for course $courseId');

      // Also cache progress
      final progressBox = await Hive.openBox('outline_progress_cache');
      outlineProgress.forEach((outlineId, progress) {
        progressBox.put('outline_$outlineId', progress);
      });
    } catch (e) {
      print('❌ Error caching outlines: $e');
    }
  }

  Future<void> _calculateOutlineProgress(
    List<CourseOutline> outlines, {
    bool fromOffline = false,
  }) async {
    try {
      int totalCompletedTopics = 0;
      int totalTopics = 0;

      for (var outline in outlines) {
        try {
          List<Topic> topics = [];

          if (fromOffline) {
            topics = await _getOfflineTopicsForOutline(
              widget.course.id,
              outline.id,
            );
          } else {
            topics = await _apiService.getTopics(
              outlineId: int.parse(outline.id),
            );
          }

          if (topics.isNotEmpty) {
            int completedTopics = 0;
            for (var topic in topics) {
              if (topic.isCompleted) {
                completedTopics++;
              }
            }

            final progress = ((completedTopics / topics.length) * 100).round();
            outlineProgress[outline.id] = progress;

            totalCompletedTopics += completedTopics;
            totalTopics += topics.length;
          } else {
            outlineProgress[outline.id] = 0;
          }
        } catch (e) {
          print('⚠️ Error calculating progress for outline ${outline.id}: $e');
          outlineProgress[outline.id] = 0;
        }
      }

      final overallProgress = totalTopics > 0
          ? ((totalCompletedTopics / totalTopics) * 100).round()
          : 0;
      final finalProgress = overallProgress > 100 ? 100 : overallProgress;

      if (mounted) {
        setState(() {
          widget.course.progress = finalProgress;
        });
      }

      await _saveCourseProgressToCache(finalProgress);
    } catch (e) {
      print('⚠️ Error in outline progress calculation: $e');
    }
  }

  Future<List<Topic>> _getOfflineTopicsForOutline(
    String courseId,
    String outlineId,
  ) async {
    try {
      final offlineBox = await Hive.openBox('offline_courses');
      final courseData = offlineBox.get('course_$courseId');

      if (courseData != null && courseData['topics'] != null) {
        final topicsJson = courseData['topics'] as List;
        final allTopics = topicsJson
            .map((json) => Topic.fromJson(json))
            .toList();

        return allTopics
            .where((topic) => topic.outlineId == outlineId)
            .toList();
      }
    } catch (e) {
      print('❌ Error getting offline topics: $e');
    }
    return [];
  }

  Future<void> _saveCourseProgressToCache(int progress) async {
    try {
      final courseId = widget.course.id;
      final box = await Hive.openBox('course_progress_cache');
      await box.put('progress_$courseId', progress);
      await box.put('last_updated_$courseId', DateTime.now().toIso8601String());
      print('💾 Saved course $courseId progress to cache: $progress%');
    } catch (e) {
      print('⚠️ Error saving course progress to cache: $e');
    }
  }

  Future<void> _invalidateProgressCache() async {
    try {
      final courseId = widget.course.id;
      final box = await Hive.openBox('course_progress_cache');
      await box.delete('progress_$courseId');
      await box.delete('last_updated_$courseId');
      print('🗑️ Invalidated progress cache for course $courseId');
    } catch (e) {
      print('⚠️ Error invalidating progress cache: $e');
    }
  }

  Future<void> _invalidateActivationCache() async {
    try {
      final activationBox = await Hive.openBox('activation_cache');
      await activationBox.delete('user_activated');
      await activationBox.delete('activation_timestamp');
      await activationBox.delete('activation_grade');
      print('🗑️ Invalidated activation cache');
    } catch (e) {
      print('⚠️ Error invalidating activation cache: $e');
    }
  }

  Future<void> _refreshOutlines({bool forceRefresh = false}) async {
    if (forceRefresh) {
      await _invalidateProgressCache();
    }
    await _loadData();
  }

  Future<List<CourseOutline>> _getDirectOfflineOutlines(String courseId) async {
    try {
      print('🔍 Getting offline outlines for course: $courseId');

      final offlineBox = await Hive.openBox('offline_courses');
      final courseData = offlineBox.get('course_$courseId');

      if (courseData == null) {
        return [];
      }

      final data = Map<String, dynamic>.from(courseData);

      if (data['outlines'] != null && data['outlines'] is List) {
        final outlinesJson = data['outlines'] as List;
        final outlines = <CourseOutline>[];

        for (var outlineData in outlinesJson) {
          try {
            if (outlineData is Map<String, dynamic>) {
              outlines.add(CourseOutline.fromJson(outlineData));
            } else if (outlineData is Map) {
              final json = Map<String, dynamic>.from(outlineData);
              outlines.add(CourseOutline.fromJson(json));
            }
          } catch (e) {
            print('   ❌ Error parsing outline: $e');
          }
        }

        return outlines;
      }
    } catch (e) {
      print('❌ Error in _getDirectOfflineOutlines: $e');
    }
    return [];
  }

  void _navigateToOutline(CourseOutline outline, int index) async {
    if (_isOutlineLocked(index)) {
      _showLockedOutlineDialog(index);
      return;
    }

    final connectivityResult = await _connectivity.checkConnectivity();
    final isConnected = connectivityResult != ConnectivityResult.none;

    if (!isConnected && !widget.course.isDownloaded) {
      _showOfflineErrorDialog();
      return;
    }

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LectureScreen(
          course: widget.course,
          outline: outline,
          outlines: outlines,
          onProgressUpdated: (progressChanged) {
            if (progressChanged) {
              Future.delayed(Duration(milliseconds: 300), () {
                if (mounted) {
                  _refreshOutlines(forceRefresh: true);
                }
              });
            }
          },
        ),
      ),
    );

    if (mounted) {
      await _refreshOutlines(forceRefresh: true);
      await _checkActivationStatus(forceRefresh: true);
    }
  }

  void _showOfflineErrorDialog() {
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
            Text(
              'You are currently offline and this course is not downloaded.',
              style: const TextStyle(
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
                          'To access this content offline:',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.blue.shade800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '1. Connect to the internet\n2. Download the course from the courses screen\n3. You can then access it offline',
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
            child: const Text('OK', style: TextStyle(color: Color(0xFF666666))),
          ),
        ],
      ),
    );
  }

  bool _isOutlineLocked(int index) {
    if (_isUserActivated) return false;
    return index > 0;
  }

  void _showLockedOutlineDialog(int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(
              Icons.lock_outline_rounded,
              color: Colors.orange.shade600,
              size: 28,
            ),
            const SizedBox(width: 12),
            const Text(
              'Outline Locked',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Outline ${index + 1} is locked because your account is not activated.',
              style: const TextStyle(
                fontSize: 15,
                height: 1.4,
                color: Color(0xFF666666),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    color: Colors.orange.shade600,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Activate your account to unlock all outlines.',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.orange.shade800,
                      ),
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
            onPressed: () async {
              Navigator.pop(context);
              final result = await Navigator.pushNamed(context, '/activation');
              if (mounted) {
                await _checkActivationStatus(forceRefresh: true);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange.shade600,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text(
              'Activate Now',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  String? _convertImageUrl(String? imageUrl) {
    if (imageUrl == null || imageUrl.isEmpty) return null;
    if (imageUrl.startsWith('http')) return imageUrl;
    String imagePath = imageUrl.replaceFirst('file://', '');
    return '${ApiEndpoints.baseUrl}$imagePath';
  }

  String _getCourseDescription() {
    String? description = widget.course.description;
    if (description == null || description.isEmpty) {
      description =
          'This course covers ${widget.course.title.toLowerCase()}. Master fundamental concepts and practical applications through interactive lessons.';
    }
    final words = description.split(' ');
    if (words.length > 30) {
      description = words.take(30).join(' ') + '...';
    }
    return description;
  }

  DecorationImage? _getBackgroundImage() {
    if (widget.course.isDownloaded && widget.course.localImagePath != null) {
      try {
        final file = File(widget.course.localImagePath!);
        if (file.existsSync()) {
          return DecorationImage(
            image: FileImage(file),
            fit: BoxFit.cover,
            colorFilter: ColorFilter.mode(
              widget.course.color.withOpacity(0.7),
              BlendMode.darken,
            ),
          );
        }
      } catch (e) {
        print('⚠️ Error loading local image: $e');
      }
    }

    String? courseImageUrl = widget.course.imageUrl != null
        ? _convertImageUrl(widget.course.imageUrl)
        : null;

    if (courseImageUrl != null && courseImageUrl.startsWith('http')) {
      return DecorationImage(
        image: NetworkImage(courseImageUrl),
        fit: BoxFit.cover,
        colorFilter: ColorFilter.mode(
          widget.course.color.withOpacity(0.7),
          BlendMode.darken,
        ),
      );
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: RefreshIndicator(
        onRefresh: () async {
          await _refreshAllData();
        },
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverAppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              leading: IconButton(
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.9),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.arrow_back_ios_new_rounded,
                    size: 18,
                    color: Color(0xFF333333),
                  ),
                ),
                onPressed: () {
                  Navigator.pop(context, true);
                },
              ),
              title: const Text(
                'Course Details',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              pinned: true,
              floating: true,
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  decoration: BoxDecoration(
                    image: _getBackgroundImage(),
                    gradient: _getBackgroundImage() == null
                        ? LinearGradient(
                            colors: [
                              widget.course.color,
                              _darkenColor(widget.course.color, 0.3),
                            ],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          )
                        : null,
                  ),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 20),
                    alignment: Alignment.bottomCenter,
                    child: _buildCourseHeaderCard(),
                  ),
                ),
              ),
              expandedHeight: 280,
              actions: [
                if (_checkingActivation)
                  Padding(
                    padding: const EdgeInsets.only(right: 16),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    ),
                  ),
                if (!hasError && widget.course.isDownloaded)
                  Padding(
                    padding: const EdgeInsets.only(right: 16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.download_done_rounded,
                            size: 14,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Offline',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),

            SliverToBoxAdapter(
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(40),
                    topRight: Radius.circular(40),
                  ),
                ),
                child: Column(
                  children: [
                    const SizedBox(height: 30),

                    if (!_isUserActivated && !_checkingActivation)
                      _buildActivationBanner(),

                    _buildCourseDescription(),
                    const SizedBox(height: 30),

                    if (isLoading) _buildLoadingState(),
                    if (hasError) _buildErrorState(),
                    if (!isLoading && !hasError && outlines.isNotEmpty)
                      _buildCourseOutlineSection(),
                    if (!isLoading && !hasError && outlines.isEmpty)
                      _buildEmptyState(),

                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActivationBanner() {
    return GestureDetector(
      onTap: () async {
        final result = await Navigator.pushNamed(context, '/activation');
        if (mounted) {
          await _checkActivationStatus(forceRefresh: true);
        }
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
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
                    'Only the first outline is available. Tap to activate and unlock all content.',
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

  Widget _buildCourseHeaderCard() {
    int completedOutlines = 0;
    for (var outline in outlines) {
      if ((outlineProgress[outline.id] ?? 0) == 100) {
        completedOutlines++;
      }
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.course.code,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF333333),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.course.title,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF666666),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (widget.course.isDownloaded)
                      Container(
                        margin: const EdgeInsets.only(top: 8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.green.withOpacity(0.3),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.download_done_rounded,
                              size: 14,
                              color: Colors.green.shade700,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Available offline',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: Colors.green.shade700,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: widget.course.color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: widget.course.color.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      '${widget.course.progress}%',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: widget.course.progress == 100
                            ? Colors.green
                            : widget.course.color,
                      ),
                    ),
                    Text(
                      'Complete',
                      style: TextStyle(
                        fontSize: 10,
                        color: widget.course.progress == 100
                            ? Colors.green.withOpacity(0.8)
                            : widget.course.color.withOpacity(0.8),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Course Progress',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF666666),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${outlines.length} ${outlines.length == 1 ? 'Outline' : 'Outlines'}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF999999),
                        ),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${widget.course.progress}% Complete',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: widget.course.progress == 100
                              ? Colors.green
                              : widget.course.color,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${completedOutlines}/${outlines.length} completed',
                        style: TextStyle(
                          fontSize: 11,
                          color: widget.course.color.withOpacity(0.7),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              LayoutBuilder(
                builder: (context, constraints) {
                  final containerWidth = constraints.maxWidth;
                  final progressWidth =
                      (widget.course.progress / 100) * containerWidth;

                  return Container(
                    height: 8,
                    width: containerWidth,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0F0F0),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Stack(
                      children: [
                        Container(
                          width: containerWidth,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0F0F0),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 800),
                          curve: Curves.easeOut,
                          width: widget.course.progress == 100
                              ? containerWidth
                              : progressWidth.clamp(0, containerWidth),
                          decoration: BoxDecoration(
                            gradient: widget.course.progress == 100
                                ? const LinearGradient(
                                    colors: [Colors.green, Colors.green],
                                  )
                                : LinearGradient(
                                    colors: [
                                      widget.course.color,
                                      _darkenColor(widget.course.color, 0.2),
                                    ],
                                  ),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCourseDescription() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'About This Course',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF333333),
            ),
          ),
          const SizedBox(height: 15),
          Text(
            _getCourseDescription(),
            style: const TextStyle(
              fontSize: 15,
              color: Color(0xFF666666),
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Padding(
      padding: EdgeInsets.all(40),
      child: Center(
        child: Column(
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 20),
            Text(
              'Loading course content...',
              style: TextStyle(color: Color(0xFF666666), fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Center(
        child: Column(
          children: [
            const Icon(Icons.error_outline, size: 60, color: Colors.orange),
            const SizedBox(height: 20),
            Text(
              errorMessage,
              style: const TextStyle(color: Color(0xFF666666), fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => _refreshOutlines(forceRefresh: true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF667eea),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text('Retry', style: TextStyle(color: Colors.white)),
            ),
            if (widget.course.isDownloaded) const SizedBox(height: 10),
            if (widget.course.isDownloaded)
              ElevatedButton(
                onPressed: () {
                  _loadData();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text(
                  'Load Offline Content',
                  style: TextStyle(color: Colors.white),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCourseOutlineSection() {
    if (outlines.isEmpty) {
      return _buildEmptyState();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Course Outline',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF333333),
                ),
              ),
              Text(
                '${outlines.length} ${outlines.length == 1 ? 'Lesson' : 'Lessons'}',
                style: const TextStyle(fontSize: 14, color: Color(0xFF999999)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        ...outlines
            .map(
              (outline) =>
                  _buildOutlineItem(outline, outlines.indexOf(outline)),
            )
            .toList(),
      ],
    );
  }

  Widget _buildOutlineItem(CourseOutline outline, int index) {
    final progress = outlineProgress[outline.id] ?? 0;
    final isLocked = _isOutlineLocked(index);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        elevation: 2,
        child: InkWell(
          onTap: isLocked ? null : () => _navigateToOutline(outline, index),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.withOpacity(0.1), width: 1),
              color: isLocked ? Colors.grey.shade50 : Colors.white,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isLocked
                            ? Colors.grey.shade200
                            : const Color(0xFFF0F0F0),
                      ),
                    ),
                    if (!isLocked && progress > 0)
                      SizedBox(
                        width: 44,
                        height: 44,
                        child: CircularProgressIndicator(
                          value: progress / 100,
                          strokeWidth: 3,
                          backgroundColor: const Color(0xFFF0F0F0),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            progress == 100
                                ? Colors.green
                                : widget.course.color,
                          ),
                        ),
                      ),
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: isLocked
                            ? Colors.grey.shade300
                            : progress == 100
                            ? Colors.green
                            : widget.course.color.withOpacity(0.1),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: Center(
                        child: isLocked
                            ? Icon(
                                Icons.lock_outline_rounded,
                                size: 18,
                                color: Colors.grey.shade600,
                              )
                            : progress == 100
                            ? const Icon(
                                Icons.check_rounded,
                                size: 20,
                                color: Colors.white,
                              )
                            : Text(
                                '${index + 1}',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: progress == 100
                                      ? Colors.white
                                      : widget.course.color,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        outline.title,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: isLocked
                              ? Colors.grey.shade600
                              : const Color(0xFF333333),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: isLocked ? 8 : 12),
                      if (isLocked)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.orange.shade100),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.lock_outline_rounded,
                                size: 14,
                                color: Colors.orange.shade600,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Activate account',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.orange.shade700,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Progress',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF666666),
                                  ),
                                ),
                                Text(
                                  '$progress%',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: progress == 100
                                        ? Colors.green
                                        : widget.course.color,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            LayoutBuilder(
                              builder: (context, constraints) {
                                final containerWidth = constraints.maxWidth;
                                final progressWidth =
                                    (progress / 100) * containerWidth;
                                return Container(
                                  height: 6,
                                  width: containerWidth,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF0F0F0),
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                  child: Stack(
                                    children: [
                                      Container(
                                        width: containerWidth,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF0F0F0),
                                          borderRadius: BorderRadius.circular(
                                            3,
                                          ),
                                        ),
                                      ),
                                      AnimatedContainer(
                                        duration: const Duration(
                                          milliseconds: 800,
                                        ),
                                        curve: Curves.easeOut,
                                        width: progress == 100
                                            ? containerWidth
                                            : progressWidth.clamp(
                                                0,
                                                containerWidth,
                                              ),
                                        decoration: BoxDecoration(
                                          color: progress == 100
                                              ? Colors.green
                                              : widget.course.color,
                                          borderRadius: BorderRadius.circular(
                                            3,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isLocked
                        ? Colors.grey.shade200
                        : progress == 100
                        ? Colors.green.withOpacity(0.1)
                        : widget.course.color.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isLocked
                        ? Icons.lock_outline_rounded
                        : progress == 100
                        ? Icons.check_rounded
                        : Icons.play_arrow_rounded,
                    size: 18,
                    color: isLocked
                        ? Colors.grey.shade500
                        : progress == 100
                        ? Colors.green
                        : widget.course.color,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.menu_book, size: 60, color: Colors.grey[400]),
            const SizedBox(height: 20),
            const Text(
              'No course outlines available yet',
              style: TextStyle(color: Color(0xFF666666), fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              widget.course.isDownloaded
                  ? 'This course was downloaded but no outlines were found. Try re-downloading the course.'
                  : 'Course content will be added soon by your instructor',
              style: const TextStyle(color: Color(0xFF999999), fontSize: 14),
              textAlign: TextAlign.center,
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
