// lib/features/courses/screens/courses_screen.dart
import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:dio/dio.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../../../core/network/api_service.dart';
import '../../../core/widgets/custom_app_bar.dart';
import '../../../core/widgets/custom_drawer.dart';
import '../../../features/courses/models/course_models.dart';
import '../../../features/courses/models/course_hive_adapters.dart';
import '../../../features/past_questions/models/past_question_models.dart';
import '../../../core/constants/endpoints.dart';
import 'package:flutter/foundation.dart'; // Add this import
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/services/activation_status_service.dart';

class CoursesScreen extends StatefulWidget {
  const CoursesScreen({super.key});

  @override
  State<CoursesScreen> createState() => _CoursesScreenState();
}

class _CoursesScreenState extends State<CoursesScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final ApiService _apiService = ApiService();
  final Dio _dio = Dio();
  final Connectivity _connectivity = Connectivity();

  List<Course> filteredCourses = [];
  List<Course> allCourses = [];
  Course? recentCourse;

  bool isLoading = true;
  bool hasError = false;
  String errorMessage = '';

  // User profile for filtering
  UserProfile? _currentUserProfile;

  // Activation status
  bool _isUserActivated = false;
  bool _checkingActivation = true;
  String _activationStatusMessage = 'Checking activation...';

  // Download states
  Map<String, bool> downloadingCourses = {};
  Map<String, double> downloadProgress = {};
  Map<String, bool> isCourseDownloaded = {};

  final String? advertImageUrl = 'assets/images/courseboard.png';

  // Hive boxes
  static const String recentCourseBox = 'recent_course';
  static const String coursesCacheBox = 'courses_cache';
  static const String activationCacheBox = 'activation_cache';
  static const String offlineCoursesBox = 'offline_courses';
  static const String userOfflineDataBox = 'user_offline_data';
  static const String userProfileBox = 'user_profile_cache';

  // Add this field to store current user ID
  String? _currentUserId;

  bool get _isDark => Theme.of(context).brightness == Brightness.dark;
  Color get _pageBackground =>
      _isDark ? const Color(0xFF09111F) : const Color(0xFFF8FAFC);
  Color get _surfaceColor => _isDark ? const Color(0xFF101A2B) : Colors.white;
  Color get _secondarySurfaceColor =>
      _isDark ? const Color(0xFF162235) : const Color(0xFFF8FAFC);
  Color get _borderColor =>
      _isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE2E8F0);
  Color get _titleColor =>
      _isDark ? const Color(0xFFF8FAFC) : const Color(0xFF333333);
  Color get _bodyColor =>
      _isDark ? const Color(0xFFCBD5E1) : const Color(0xFF666666);

  @override
  // void initState() {
  //   super.initState();
  //   filteredCourses = [];
  //   _searchController.addListener(_filterCourses);
  //   // Load cached data IMMEDIATELY before any async operations
  //   WidgetsBinding.instance.addPostFrameCallback((_) async {
  //     // Step 1: Get user ID first (fast - from Hive)
  //     await _ensureUserID();
  //     // Step 2: Load cached courses INSTANTLY (this shows UI immediately)
  //     final cachedCourses = await _loadCachedCourses();
  //     if (cachedCourses.isNotEmpty && mounted) {
  //       setState(() {
  //         allCourses = cachedCourses;
  //         filteredCourses = cachedCourses;
  //         isLoading = false; // UI shows immediately!
  //       });
  //       print('✅ SHOWED ${cachedCourses.length} CACHED COURSES INSTANTLY');
  //     }
  //     // Step 3: Load cached profile (fast)
  //     await _loadCachedUserProfile();
  //     // Step 4: Fetch fresh data in background (user won't notice delay)
  //     _fetchFreshDataInBackground();
  //   });
  //   // Emergency timeout - but we already showed cached courses so user isn't waiting
  //   Future.delayed(const Duration(seconds: 3), () {
  //     if (mounted && isLoading && allCourses.isEmpty) {
  //       print('⚠️ Emergency - no courses yet, forcing load');
  //       _loadCourses();
  //     }
  //   });
  // }
  @override
  void initState() {
    super.initState();
    filteredCourses = [];
    _searchController.addListener(_filterCourses);
    ActivationStatusService.listenable.addListener(
      _handleActivationStatusChanged,
    );
    _applyActivationSnapshot(ActivationStatusService.current);
    unawaited(_checkActivationStatus(forceRefresh: true));

    // Load cached data IMMEDIATELY before any async operations
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Step 1: Get user ID first (fast - from Hive)
      await _ensureUserID();

      // Step 2: Load download status instantly (FAST)
      await _loadDownloadStatuses();

      // Step 3: Load cached courses INSTANTLY (this shows UI immediately)
      final cachedCourses = await _loadCachedCourses();
      if (cachedCourses.isNotEmpty && mounted) {
        // Enhance with download status before showing
        final enhancedCourses = await _enhanceCoursesWithDownloadStatus(
          cachedCourses,
        );
        setState(() {
          allCourses = enhancedCourses;
          filteredCourses = enhancedCourses;
          isLoading = false; // UI shows immediately!
        });
        print(
          '✅ SHOWED ${enhancedCourses.length} CACHED COURSES WITH DOWNLOAD ICONS',
        );
      }

      // Step 4: Load cached profile (fast)
      await _loadCachedUserProfile();

      // Step 5: Fetch fresh data in background
      _fetchFreshDataInBackground();
    });

    // Emergency timeout
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted && isLoading && allCourses.isEmpty) {
        print('⚠️ Emergency - no courses yet, forcing load');
        _loadCourses();
      }
    });
  }

  /// Fetches fresh data in the background without blocking UI
  Future<void> _fetchFreshDataInBackground() async {
    try {
      // FIRST: Load download status instantly from offline box (FAST)
      await _loadDownloadStatuses();

      // Update UI with download status immediately
      if (mounted && allCourses.isNotEmpty) {
        // Enhance existing courses with download status
        final enhancedCourses = await _enhanceCoursesWithDownloadStatus(
          allCourses,
        );
        setState(() {
          allCourses = enhancedCourses;
          filteredCourses = enhancedCourses;
        });
        print('✅ Updated download status icons instantly');
      }

      // THEN: Fetch fresh courses in background
      final freshCourses = await _apiService.getCoursesForUser();

      if (freshCourses.isNotEmpty && mounted) {
        // Enhance with download status
        final enhancedCourses = await _enhanceCoursesWithDownloadStatus(
          freshCourses,
        );

        // Update UI with fresh courses
        setState(() {
          allCourses = enhancedCourses;
          filteredCourses = enhancedCourses;
        });

        // Cache for next time
        await _cacheCourses(enhancedCourses);

        print('✅ UPDATED WITH ${enhancedCourses.length} FRESH COURSES');
      }

      // Load other data in background
      await Future.wait([
        _checkActivationStatus(),
        _loadRecentCourseFromStorage(),
      ]);

      // Fix any corrupted data
      await _fixExistingRecentCourseData();
      await _debugRecentCourseStorage();
      await _cleanupOrphanedRecentCourses();

      // Refresh profile in background
      _refreshUserProfileInBackground();
    } catch (e) {
      print('⚠️ Background fetch error: $e');
    }
  }

  /// Fetches fresh data in the background without blocking UI
  // Future<void> _fetchFreshDataInBackground() async {
  //   try {
  //     // Check connectivity
  //     final connectivityResult = await _connectivity.checkConnectivity();
  //     final isConnected = connectivityResult != ConnectivityResult.none;

  //     if (!isConnected) return; // Don't try to fetch if offline

  //     // Fetch fresh courses (this is the slow part)
  //     final freshCourses = await _apiService.getCoursesForUser();

  //     if (freshCourses.isNotEmpty && mounted) {
  //       // Enhance with download status
  //       final enhancedCourses = await _enhanceCoursesWithDownloadStatus(
  //         freshCourses,
  //       );

  //       // Update UI with fresh courses
  //       setState(() {
  //         allCourses = enhancedCourses;
  //         filteredCourses = enhancedCourses;
  //       });

  //       // Cache for next time (don't await - let it run in background)
  //       _cacheCourses(enhancedCourses);

  //       print('✅ UPDATED WITH ${enhancedCourses.length} FRESH COURSES');
  //     }

  //     // Load other data in background (don't await these either)
  //     _checkActivationStatus();
  //     _loadRecentCourseFromStorage();
  //     _refreshUserProfileInBackground();
  //     _cleanupOrphanedRecentCourses();
  //   } catch (e) {
  //     print('⚠️ Background fetch error: $e');
  //   }
  // }

  // ADD THIS NEW METHOD
  Future<void> _forceLoadCourses() async {
    if (allCourses.isEmpty && !hasError) {
      print('🚨 Forcing course load after timeout');
      setState(() {
        isLoading = true;
      });

      // Check connectivity and try again
      final connectivityResult = await _connectivity.checkConnectivity();
      final isConnected = connectivityResult != ConnectivityResult.none;

      if (isConnected) {
        // Try online load with current profile
        if (_currentUserProfile != null) {
          await _loadOnlineCoursesWithProfile(_currentUserProfile!);
        } else {
          // Try to get profile again
          await _refreshUserProfileInBackground();
          if (_currentUserProfile != null) {
            await _loadOnlineCoursesWithProfile(_currentUserProfile!);
          } else {
            // Last resort - load without profile
            await _loadCoursesWithoutProfile();
          }
        }
      } else {
        // Offline - try loading downloaded courses
        await _loadOfflineCourses();
      }
    }
  }

  @override
  void dispose() {
    ActivationStatusService.listenable.removeListener(
      _handleActivationStatusChanged,
    );
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

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
      _checkingActivation = !snapshot.hasCachedValue;
    });
  }

  Future<void> _loadInitialData() async {
    print('🚀 Starting initial data load...');

    if (!mounted) return;

    setState(() {
      isLoading = true;
      hasError = false;
      errorMessage = '';
    });

    try {
      // Get current user ID first - ensure we have it
      await _ensureUserID();

      if (_currentUserId == null) {
        print('⚠️ Could not get user ID, will try later');
      }

      // Load cached profile first (fast)
      await _loadCachedUserProfile();

      // Clean up orphaned recent courses
      await _cleanupOrphanedRecentCourses();

      // Load other data in parallel
      await Future.wait([
        _checkActivationStatus(),
        _loadRecentCourseFromStorage(),
        _loadDownloadStatuses(),
      ]);

      // Then load courses
      await _loadCourses();

      // Refresh profile in background
      _refreshUserProfileInBackground();

      // ADD THIS: After loading, check if we need to retry
      if (allCourses.isEmpty && mounted) {
        print('⚠️ No courses loaded, will retry after profile refresh');
        // Schedule a retry after profile refresh
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted && allCourses.isEmpty && !isLoading) {
            print('🔄 Retrying course load with refreshed profile');
            _loadCourses();
          }
        });
      }
    } catch (e) {
      print('❌ Error in initial load: $e');
      if (mounted) {
        setState(() {
          isLoading = false;
          hasError = true;
          errorMessage =
              'Failed to load courses. Please check your connection.';
        });
      }
    }
  }

  Future<void> _loadCachedUserProfile() async {
    try {
      final profileBox = await Hive.openBox(userProfileBox);
      final cachedProfile = profileBox.get('current_user_profile');

      if (cachedProfile != null) {
        print('📦 Found cached profile type: ${cachedProfile.runtimeType}');

        if (cachedProfile is UserProfile) {
          _currentUserProfile = cachedProfile;
          print('✅ Loaded cached user profile as object');
        } else if (cachedProfile is Map<String, dynamic>) {
          _currentUserProfile = UserProfile.fromJson(cachedProfile);
          print('✅ Loaded cached user profile from JSON');
        } else if (cachedProfile is Map) {
          try {
            final json = Map<String, dynamic>.from(cachedProfile);
            _currentUserProfile = UserProfile.fromJson(json);
            print('✅ Loaded cached user profile from Map');
          } catch (e) {
            print('⚠️ Error converting cached profile: $e');
          }
        }

        if (_currentUserProfile != null) {
          print(
            '👤 Loaded cached user profile: ${_currentUserProfile?.toString()}',
          );
        }
      } else {
        print('⚠️ No cached user profile found');
      }
    } catch (e) {
      print('❌ Error loading cached user profile: $e');
    }
  }

  // Save profile to cache
  Future<void> _saveUserProfileToCache(UserProfile profile) async {
    try {
      final profileBox = await Hive.openBox(userProfileBox);
      await profileBox.put('current_user_profile', profile);
      print('💾 Saved user profile to cache');
    } catch (e) {
      print('❌ Error saving user profile to cache: $e');
    }
  }

  Future<void> _refreshUserProfileInBackground() async {
    try {
      final userData = await _apiService.getCurrentUser();
      if (userData == null) {
        print('⚠️ No user data available');
        return;
      }

      print('🔄 Parsing user data: ${userData.keys}');

      // Get current user ID
      _currentUserId = userData['id']?.toString();

      // Helper function to extract nested data
      dynamic extractNested(dynamic data, List<String> keys) {
        dynamic current = data;
        for (var key in keys) {
          if (current is Map && current.containsKey(key)) {
            current = current[key];
          } else {
            return null;
          }
        }
        return current;
      }

      // Extract university info
      String universityId = '';
      String universityName = '';

      final university = extractNested(userData, ['university']);
      if (university is Map) {
        universityId = university['id']?.toString() ?? '';
        universityName = university['name']?.toString() ?? '';
      } else {
        universityId = userData['university_id']?.toString() ?? '';
        universityName = userData['university_name']?.toString() ?? '';
      }

      // Extract department info
      String departmentId = '';
      String departmentName = '';

      final department = extractNested(userData, ['department']);
      if (department is Map) {
        departmentId = department['id']?.toString() ?? '';
        departmentName = department['name']?.toString() ?? '';
      } else {
        departmentId = userData['department_id']?.toString() ?? '';
        departmentName = userData['department_name']?.toString() ?? '';
      }

      // Extract level info
      String levelId = '';
      String levelName = '';

      final level = extractNested(userData, ['level']);
      if (level is Map) {
        levelId = level['id']?.toString() ?? '';
        levelName = level['name']?.toString() ?? '';
      } else {
        levelId = userData['level_id']?.toString() ?? '';
        levelName = userData['level_name']?.toString() ?? '';
      }

      // Extract semester info
      String semesterId = '';
      String semesterName = '';

      final semester = extractNested(userData, ['semester']);
      if (semester is Map) {
        semesterId = semester['id']?.toString() ?? '';
        semesterName = semester['name']?.toString() ?? '';
      } else {
        semesterId = userData['semester_id']?.toString() ?? '';
        semesterName = userData['semester_name']?.toString() ?? '';
      }

      print('📊 Extracted profile info:');
      print('   University: $universityId - $universityName');
      print('   Department: $departmentId - $departmentName');
      print('   Level: $levelId - $levelName');
      print('   Semester: $semesterId - $semesterName');

      final newProfile = UserProfile(
        id: _currentUserId ?? '',
        universityId: universityId,
        universityName: universityName,
        departmentId: departmentId,
        departmentName: departmentName,
        levelId: levelId,
        levelName: levelName,
        semesterId: semesterId,
        semesterName: semesterName,
      );

      // Check if profile changed
      final bool profileChanged =
          _currentUserProfile == null ||
          !_currentUserProfile!.matches(newProfile) ||
          _currentUserProfile!.departmentId != newProfile.departmentId;

      if (profileChanged || departmentId.isNotEmpty) {
        _currentUserProfile = newProfile;

        try {
          final profileBox = await Hive.openBox(userProfileBox);
          await profileBox.put('current_user_profile', newProfile.toJson());
          print('✅ User profile saved to cache as JSON');
        } catch (e) {
          print('⚠️ Error saving profile to cache: $e');
          // Try alternative approach
          try {
            final profileBox = await Hive.openBox(userProfileBox);
            await profileBox.put('current_user_profile', newProfile);
            print('✅ User profile saved to cache as object');
          } catch (e2) {
            print('❌ Failed to save profile: $e2');
          }
        }

        print('✅ User profile updated: ${_currentUserProfile?.toString()}');

        //     // If department was previously empty, reload courses
        //     if (_currentUserProfile!.departmentId.isNotEmpty &&
        //         (allCourses.isEmpty || hasError)) {
        //       if (mounted) {
        //         WidgetsBinding.instance.addPostFrameCallback((_) {
        //           _loadCoursesWithProfile(newProfile);
        //         });
        //       }
        //     }
        //   }
        // } catch (e) {
        //   print('❌ Error refreshing user profile: $e');
        // }
        // If department was previously empty, reload courses
      }
    } catch (e) {
      print('❌ Error refreshing user profile: $e');
    }
  }

  Future<void> _loadCoursesWithProfile(UserProfile profile) async {
    print(
      '📚 Loading courses with profile: ${profile.departmentName} (${profile.departmentId})',
    );

    setState(() {
      isLoading = true;
    });

    try {
      final connectivityResult = await _connectivity.checkConnectivity();
      final isConnected = connectivityResult != ConnectivityResult.none;

      if (isConnected) {
        await _loadOnlineCoursesWithProfile(profile);
      } else {
        await _loadOfflineCoursesWithProfile(profile);
      }
    } catch (e) {
      print('❌ Error loading courses: $e');
      setState(() {
        isLoading = false;
        hasError = true;
        errorMessage = 'Failed to load courses.';
      });
    }
  }

  // Future<void> _loadOnlineCoursesWithProfile(UserProfile profile) async {
  //   try {
  //     print('🌐 Fetching courses from API...');
  //     final courses = await _apiService.getCoursesForUser();

  //     if (courses.isEmpty) {
  //       print('⚠️ No courses returned from API');
  //       await _loadCachedOrDownloadedCoursesWithProfile(profile);
  //       return;
  //     }

  //     // Filter courses by department AND other academic info
  //     final filteredCoursesList = _filterCoursesByProfile(courses, profile);

  //     if (filteredCoursesList.isEmpty) {
  //       print('⚠️ No courses match your department and academic profile');
  //       setState(() {
  //         allCourses = [];
  //         filteredCourses = [];
  //         isLoading = false;
  //         hasError = false;
  //         errorMessage =
  //             'No courses available for your department and academic level.';
  //       });
  //       return;
  //     }

  //     await _loadCoursesProgress(filteredCoursesList);
  //     final enhancedCourses = await _enhanceCoursesWithDownloadStatus(
  //       filteredCoursesList,
  //     );

  //     setState(() {
  //       allCourses = enhancedCourses;
  //       filteredCourses = enhancedCourses;
  //       isLoading = false;
  //       hasError = false;
  //     });

  //     await _cacheCourses(enhancedCourses);

  //     print(
  //       '✅ Loaded ${enhancedCourses.length} filtered courses for ${profile.departmentName}',
  //     );
  //   } catch (e) {
  //     print('⚠️ API error: $e');
  //     await _loadCachedOrDownloadedCoursesWithProfile(profile);
  //   }
  // }

  // UPDATE THIS METHOD
  Future<void> _loadOnlineCoursesWithProfile(UserProfile profile) async {
    try {
      print('🌐 Fetching courses from API...');

      // Add retry mechanism
      List<Course> courses = [];
      int retryCount = 0;
      const maxRetries = 3;

      while (retryCount < maxRetries) {
        try {
          courses = await _apiService.getCoursesForUser();
          break; // Success, exit loop
        } catch (e) {
          retryCount++;
          print('⚠️ API attempt $retryCount failed: $e');
          if (retryCount == maxRetries) {
            throw e; // Rethrow after max retries
          }
          await Future.delayed(Duration(milliseconds: 500 * retryCount));
        }
      }

      if (courses.isEmpty) {
        print('⚠️ No courses returned from API');
        await _loadCachedOrDownloadedCoursesWithProfile(profile);
        return;
      }

      // Filter courses by department AND other academic info
      final filteredCoursesList = _filterCoursesByProfile(courses, profile);

      if (filteredCoursesList.isEmpty) {
        print('⚠️ No courses match your department and academic profile');
        // DON'T show error immediately, check if there are any courses at all
        if (courses.isNotEmpty) {
          print('ℹ️ There are courses but none match your department');
          setState(() {
            allCourses = [];
            filteredCourses = [];
            isLoading = false;
            hasError = false;
            errorMessage =
                'No courses match your department. Please check your academic profile.';
          });
          return;
        } else {
          setState(() {
            allCourses = [];
            filteredCourses = [];
            isLoading = false;
            hasError = false;
            errorMessage = 'No courses available.';
          });
          return;
        }
      }

      await _loadCoursesProgress(filteredCoursesList);
      final enhancedCourses = await _enhanceCoursesWithDownloadStatus(
        filteredCoursesList,
      );

      setState(() {
        allCourses = enhancedCourses;
        filteredCourses = enhancedCourses;
        isLoading = false;
        hasError = false;
      });

      await _cacheCourses(enhancedCourses);

      print(
        '✅ Loaded ${enhancedCourses.length} filtered courses for ${profile.departmentName}',
      );
    } catch (e) {
      print('⚠️ API error: $e');
      await _loadCachedOrDownloadedCoursesWithProfile(profile);
    }
  }

  List<Course> _filterCoursesByProfile(
    List<Course> courses,
    UserProfile profile,
  ) {
    print('🔍 Filtering courses for department: ${profile.departmentId}');

    // If profile doesn't have department info, return empty list
    if (profile.departmentId.isEmpty) {
      print('⚠️ Profile has no department ID, showing all courses');
      return courses;
    }

    return courses.where((course) {
      // Debug log for each course
      print(
        '   Course: ${course.code} - Departments: ${course.departmentsInfo.length}',
      );

      // If course has no department info, skip it
      if (course.departmentsInfo.isEmpty) {
        print('   ⚠️ Course ${course.code} has no department info');
        return false;
      }

      // Check if course is for user's department
      final bool isForUserDepartment = course.departmentsInfo.any((deptInfo) {
        // Try multiple possible field names
        final deptId =
            deptInfo['department_id']?.toString() ??
            deptInfo['id']?.toString() ??
            deptInfo['department']?.toString() ??
            '';

        final match = deptId == profile.departmentId;
        if (match) {
          print('   ✅ Course ${course.code} matches department $deptId');
        }
        return match;
      });

      if (!isForUserDepartment) {
        print(
          '   ⚠️ Course ${course.code} not for department ${profile.departmentId}',
        );
      }

      return isForUserDepartment;
    }).toList();
  }

  Future<void> _loadOfflineCoursesWithProfile(UserProfile profile) async {
    print('📴 Loading offline courses for ${profile.departmentName}');

    try {
      // Get connectivity status to confirm we're offline
      final connectivityResult = await _connectivity.checkConnectivity();
      final isOffline = connectivityResult == ConnectivityResult.none;

      if (!isOffline) {
        print('⚠️ Device shows online, but trying offline mode');
      }

      await _loadCachedOrDownloadedCoursesWithProfile(profile);
    } catch (e) {
      print('❌ Error in _loadOfflineCoursesWithProfile: $e');
      setState(() {
        isLoading = false;
        hasError = true;
        errorMessage =
            'Failed to load offline courses. Please check your storage.';
      });
    }
  }

  Future<void> _ensureUserID() async {
    if (_currentUserId != null) return;

    try {
      final userData = await _apiService.getCurrentUser();
      if (userData != null) {
        _currentUserId = userData['id'].toString();
        print('👤 Got user ID in _ensureUserID: $_currentUserId');

        // Migrate old recent courses after getting user ID
        await _migrateOldRecentCourses();
      } else {
        print('⚠️ Could not get user data for ID');
      }
    } catch (e) {
      print('❌ Error getting user ID: $e');
    }
  }

  Future<void> _loadCachedOrDownloadedCoursesWithProfile(
    UserProfile profile,
  ) async {
    print('🔄 Loading courses with profile offline...');
    // Just load offline courses - the profile filtering will happen in _loadOfflineCourses
    await _loadOfflineCourses();
  }

  Future<void> _loadDownloadedCoursesOnlyWithProfile(
    UserProfile profile,
  ) async {
    print(
      '🔄 Loading downloaded courses for user $_currentUserId, department: ${profile.departmentName}',
    );

    try {
      final offlineBox = await Hive.openBox(offlineCoursesBox);
      final downloadedCourseIds = offlineBox.get(
        'downloaded_course_ids',
        defaultValue: <String>[],
      );

      print(
        '📦 Total downloaded courses in Hive: ${downloadedCourseIds.length}',
      );

      final downloadedCourses = <Course>[];

      for (var courseId in downloadedCourseIds) {
        try {
          final courseData = offlineBox.get('course_$courseId');
          if (courseData != null && courseData['course'] != null) {
            final courseJson = Map<String, dynamic>.from(courseData['course']);

            // ====== CRITICAL FIX: Check if downloaded by current user ======
            final downloadedByUserId = courseData['user_id']?.toString();

            // If we have a user_id stored, check if it matches current user
            if (downloadedByUserId != null &&
                downloadedByUserId != _currentUserId) {
              print(
                '⚠️ Skipping course $courseId - downloaded by different user: $downloadedByUserId (Current: $_currentUserId)',
              );
              continue; // Skip - not downloaded by current user
            }
            // ===============================================================

            // Create course object
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

            downloadedCourses.add(course);
            print('✅ Loaded: ${course.code} for user $_currentUserId');
          }
        } catch (e) {
          print('⚠️ Skipping course $courseId: $e');
        }
      }

      // SHOW DOWNLOADED COURSES
      if (downloadedCourses.isNotEmpty) {
        print(
          '🎉 SUCCESS: Showing ${downloadedCourses.length} downloaded courses for user $_currentUserId',
        );

        setState(() {
          allCourses = downloadedCourses;
          filteredCourses = downloadedCourses;
          isLoading = false;
          hasError = false;
          errorMessage = 'Offline: Showing YOUR downloaded courses';
        });
      } else {
        print('❌ No downloaded courses found for user $_currentUserId');
        setState(() {
          isLoading = false;
          hasError = true;
          errorMessage =
              'You have no downloaded courses. Please download courses when online.';
        });
      }
    } catch (e) {
      print('❌ CRITICAL Hive Error: $e');
      setState(() {
        isLoading = false;
        hasError = true;
        errorMessage = 'Storage error. Try restarting the app.';
      });
    }
  }
  // #####################

  Future<List<Course>> _getDownloadedCoursesForCurrentUser(
    UserProfile profile,
  ) async {
    print('🔍 Getting downloaded courses for user $_currentUserId...');

    final downloadedCourses = <Course>[];

    try {
      final offlineBox = await Hive.openBox(offlineCoursesBox);
      final downloadedCourseIds = offlineBox.get(
        'downloaded_course_ids',
        defaultValue: <String>[],
      );

      print(
        '📦 Found ${downloadedCourseIds.length} downloaded course IDs in Hive',
      );

      for (var courseId in downloadedCourseIds) {
        try {
          final courseData = offlineBox.get('course_$courseId');
          if (courseData == null || courseData['course'] == null) {
            print('⚠️ Course $courseId data is missing or corrupted');
            continue;
          }

          final courseJson = Map<String, dynamic>.from(courseData['course']);

          // IMPORTANT: If we don't have a user ID yet, show all downloaded courses
          if (_currentUserId == null) {
            print('⚠️ No user ID, showing all downloaded courses');
            // Continue without user filtering
          } else {
            // CRITICAL: Check if this course was downloaded by the current user
            final downloadedByUserId = courseData['user_id']?.toString();

            if (downloadedByUserId != null &&
                downloadedByUserId != _currentUserId) {
              print(
                '⏭️ Skipping course $courseId - downloaded by different user: $downloadedByUserId',
              );
              continue;
            }
          }

          // Create course object
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

          downloadedCourses.add(course);
          print(
            '✅ Loaded downloaded course: ${course.code} for user $_currentUserId',
          );
        } catch (e) {
          print('⚠️ Error loading downloaded course $courseId: $e');
        }
      }

      print('📊 Total downloaded courses loaded: ${downloadedCourses.length}');

      // Filter by department if profile has department info
      if (profile.departmentId.isNotEmpty) {
        final filtered = downloadedCourses.where((course) {
          // If course has no department info, include it (for backward compatibility)
          if (course.departmentsInfo.isEmpty) {
            print(
              '⚠️ Course ${course.code} has no department info, including anyway',
            );
            return true;
          }

          return course.departmentsInfo.any((deptInfo) {
            final deptId =
                deptInfo['department_id']?.toString() ??
                deptInfo['id']?.toString() ??
                deptInfo['department']?.toString() ??
                '';
            return deptId == profile.departmentId;
          });
        }).toList();

        print(
          '🔍 Filtered to ${filtered.length} courses matching department ${profile.departmentId}',
        );
        return filtered;
      }

      return downloadedCourses;
    } catch (e) {
      print('❌ Error in _getDownloadedCoursesForCurrentUser: $e');
      return [];
    }
  }

  // Add this method and call it somewhere (like in initState)
  Future<void> _emergencyDebugHive() async {
    print('🚨 EMERGENCY HIVE DEBUG 🚨');
    try {
      final box = await Hive.openBox(offlineCoursesBox);

      // Check if box exists
      print('📦 Box exists: true');
      print('📦 Box keys: ${box.keys.toList()}');

      // Check downloaded_course_ids
      final ids = box.get('downloaded_course_ids', defaultValue: <String>[]);
      print('📦 Downloaded course IDs: $ids');
      print('📦 Number of IDs: ${ids.length}');

      // Check each course
      for (var id in ids) {
        final hasCourse = box.containsKey('course_$id');
        print('   - course_$id exists: $hasCourse');
        if (hasCourse) {
          final data = box.get('course_$id');
          if (data != null) {
            final userWhoDownloaded = data['user_id']?.toString();
            print('     Downloaded by user: $userWhoDownloaded');
            if (data['course'] != null) {
              final course = Map<String, dynamic>.from(data['course']);
              print('     Code: ${course['code']}');
              print('     Title: ${course['title']}');
            }
          }
        }
      }
    } catch (e) {
      print('❌ Hive Debug Error: $e');
    }
    print('🚨 END DEBUG 🚨');
  }

  // Debug method to show what's actually downloaded
  Future<void> _debugShowDownloadedCourses() async {
    try {
      final offlineBox = await Hive.openBox(offlineCoursesBox);
      final downloadedCourseIds = offlineBox.get(
        'downloaded_course_ids',
        defaultValue: <String>[],
      );

      print('🔍 DEBUG: Downloaded course IDs: $downloadedCourseIds');

      for (var courseId in downloadedCourseIds) {
        final courseData = offlineBox.get('course_$courseId');
        if (courseData != null && courseData['course'] != null) {
          final courseJson = Map<String, dynamic>.from(courseData['course']);
          print('   - Course $courseId: ${courseJson['code']}');
          print('     Downloaded by user: ${courseData['user_id']}');
          print('     Current user: $_currentUserId');
          print('     University: ${courseJson['university_id']}');
          print('     Level: ${courseJson['level_id']}');
          print('     Semester: ${courseJson['semester_id']}');
          print('     Departments: ${courseJson['departments_info']}');
        }
      }
    } catch (e) {
      print('❌ Debug error: $e');
    }
  }

  // Future<void> _loadCourses() async {
  //   print('📚 Loading courses...');
  //   print('👤 Current user ID: $_currentUserId');
  //   print('👤 Current profile: ${_currentUserProfile?.toString()}');

  //   if (!mounted) return;

  //   setState(() {
  //     isLoading = true;
  //     hasError = false;
  //     errorMessage = '';
  //   });

  //   try {
  //     // ALWAYS check connectivity first
  //     final connectivityResult = await _connectivity.checkConnectivity();
  //     final isConnected = connectivityResult != ConnectivityResult.none;

  //     print('📡 Connectivity: ${isConnected ? "Online" : "Offline"}');

  //     if (isConnected) {
  //       print('🌐 Online mode - fetching from API');
  //       // If online and have profile, load with profile
  //       if (_currentUserProfile != null) {
  //         await _loadOnlineCoursesWithProfile(_currentUserProfile!);
  //       } else {
  //         await _loadCoursesWithoutProfile();
  //       }
  //     } else {
  //       print('📴 OFFLINE MODE - loading from storage');
  //       // Offline mode - load downloaded courses
  //       await _loadOfflineCourses();
  //     }
  //   } catch (e) {
  //     print('❌ Error in _loadCourses: $e');
  //     if (mounted) {
  //       setState(() {
  //         isLoading = false;
  //         hasError = true;
  //         errorMessage = 'Failed to load courses.';
  //       });
  //     }
  //   }
  // }
  // In courses_screen.dart - Replace your entire _loadCourses method
  Future<void> _loadCourses() async {
    print('📚 Loading courses...');
    print('👤 Current user ID: $_currentUserId');

    if (!mounted) return;

    setState(() {
      isLoading = true;
      hasError = false;
      errorMessage = '';
    });

    try {
      // Check connectivity
      final connectivityResult = await _connectivity.checkConnectivity();
      final isConnected = connectivityResult != ConnectivityResult.none;

      if (isConnected) {
        // ONLINE: Just call the API directly - let Django handle filtering
        print('🌐 Online mode - fetching from API');
        final courses = await _apiService.getCoursesForUser();

        if (courses.isEmpty) {
          print('⚠️ No courses returned from API');

          // Try cache as fallback
          final cachedCourses = await _loadCachedCourses();
          if (cachedCourses.isNotEmpty) {
            print('✅ Loaded ${cachedCourses.length} courses from cache');
            setState(() {
              allCourses = cachedCourses;
              filteredCourses = cachedCourses;
              isLoading = false;
            });
            return;
          }

          setState(() {
            allCourses = [];
            filteredCourses = [];
            isLoading = false;
            errorMessage = 'No courses available for your academic profile.';
          });
          return;
        }

        // Load progress for courses
        await _loadCoursesProgress(courses);

        // Enhance with download status
        final enhancedCourses = await _enhanceCoursesWithDownloadStatus(
          courses,
        );

        setState(() {
          allCourses = enhancedCourses;
          filteredCourses = enhancedCourses;
          isLoading = false;
          hasError = false;
        });

        // Cache for offline use
        await _cacheCourses(enhancedCourses);

        print('✅ Loaded ${enhancedCourses.length} courses successfully');
      } else {
        // OFFLINE: Load downloaded courses
        print('📴 Offline mode - loading from storage');
        await _loadOfflineCourses();
      }
    } catch (e) {
      print('❌ Error loading courses: $e');

      // Try cache on error
      try {
        final cachedCourses = await _loadCachedCourses();
        if (cachedCourses.isNotEmpty) {
          print(
            '✅ Loaded ${cachedCourses.length} courses from cache (fallback)',
          );
          setState(() {
            allCourses = cachedCourses;
            filteredCourses = cachedCourses;
            isLoading = false;
            errorMessage = 'Showing cached courses. Pull to refresh.';
          });
          return;
        }
      } catch (cacheError) {
        print('⚠️ Cache fallback failed: $cacheError');
      }

      if (mounted) {
        setState(() {
          isLoading = false;
          hasError = true;
          errorMessage =
              'Failed to load courses. Please check your connection.';
        });
      }
    }
  }

  Future<void> _loadOfflineCourses() async {
    print('📴 _loadOfflineCourses called');
    print('👤 User ID: $_currentUserId');

    if (!mounted) return;

    try {
      // Check Hive for downloaded courses immediately
      final offlineBox = await Hive.openBox(offlineCoursesBox);
      final downloadedCourseIds = offlineBox.get(
        'downloaded_course_ids',
        defaultValue: <String>[],
      );

      print('📦 Downloaded course IDs: $downloadedCourseIds');
      print('📦 Number of downloaded courses: ${downloadedCourseIds.length}');

      if (downloadedCourseIds.isEmpty) {
        print('❌ No downloaded courses found');
        if (mounted) {
          setState(() {
            isLoading = false;
            hasError = true;
            errorMessage =
                'No courses downloaded. Please connect to download courses.';
          });
        }
        return;
      }

      // Load each downloaded course
      final downloadedCourses = <Course>[];

      for (var courseId in downloadedCourseIds) {
        try {
          print('📖 Loading course $courseId from Hive...');
          final courseData = offlineBox.get('course_$courseId');

          if (courseData == null) {
            print('⚠️ Course $courseId data is null');
            continue;
          }

          if (courseData['course'] == null) {
            print('⚠️ Course $courseId has no course data');
            continue;
          }

          // Check user ID
          final downloadedByUserId = courseData['user_id']?.toString();
          print(
            '   Downloaded by: $downloadedByUserId, Current user: $_currentUserId',
          );

          // Show course if it matches current user OR if user ID is null (legacy courses)
          if (_currentUserId == null ||
              downloadedByUserId == null ||
              downloadedByUserId == _currentUserId) {
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

            downloadedCourses.add(course);
            print('✅ Loaded: ${course.code}');
          } else {
            print('⏭️ Skipping course $courseId - different user');
          }
        } catch (e) {
          print('⚠️ Error loading course $courseId: $e');
        }
      }

      if (downloadedCourses.isEmpty) {
        print('❌ No courses loaded for current user');
        if (mounted) {
          setState(() {
            isLoading = false;
            hasError = true;
            errorMessage = 'No courses downloaded for your account.';
          });
        }
        return;
      }

      print(
        '🎉 Successfully loaded ${downloadedCourses.length} downloaded courses',
      );

      // Update download status map
      for (var course in downloadedCourses) {
        isCourseDownloaded[course.id] = true;
      }

      if (mounted) {
        setState(() {
          allCourses = downloadedCourses;
          filteredCourses = downloadedCourses;
          isLoading = false;
          hasError = false;
          errorMessage = 'Offline: Showing your downloaded courses';
        });
      }
    } catch (e) {
      print('❌ Error in _loadOfflineCourses: $e');
      if (mounted) {
        setState(() {
          isLoading = false;
          hasError = true;
          errorMessage = 'Error loading offline courses.';
        });
      }
    }
  }

  Future<void> _loadCoursesWithoutProfile() async {
    try {
      final connectivityResult = await _connectivity.checkConnectivity();
      final isConnected = connectivityResult != ConnectivityResult.none;

      if (isConnected) {
        print('🌐 Online - fetching courses from API');
        final courses = await _apiService.getCoursesForUser();

        if (courses.isEmpty) {
          print('⚠️ No courses from API, checking cache...');
          final cachedCourses = await _loadCachedCourses();
          if (cachedCourses.isNotEmpty) {
            final enhancedCourses = await _enhanceCoursesWithDownloadStatus(
              cachedCourses,
            );
            if (mounted) {
              setState(() {
                allCourses = enhancedCourses;
                filteredCourses = enhancedCourses;
                isLoading = false;
                errorMessage = 'Showing cached courses';
              });
            }
          } else {
            if (mounted) {
              setState(() {
                allCourses = [];
                filteredCourses = [];
                isLoading = false;
                errorMessage =
                    'No courses available. Please set your academic profile.';
              });
            }
          }
          return;
        }

        await _loadCoursesProgress(courses);
        final enhancedCourses = await _enhanceCoursesWithDownloadStatus(
          courses,
        );

        if (mounted) {
          setState(() {
            allCourses = enhancedCourses;
            filteredCourses = enhancedCourses;
            isLoading = false;
          });
        }

        await _cacheCourses(enhancedCourses);
      } else {
        // OFFLINE - load offline courses directly
        print('📴 Offline - loading from storage');
        await _loadOfflineCourses();
      }
    } catch (e) {
      print('❌ Error loading courses without profile: $e');
      if (mounted) {
        setState(() {
          isLoading = false;
          hasError = true;
          errorMessage = 'Failed to load courses.';
        });
      }
    }
  }

  Future<void> _checkActivationStatus({bool forceRefresh = false}) async {
    final hadCachedState = ActivationStatusService.current.hasCachedValue;

    if (!hadCachedState && !_checkingActivation && mounted) {
      setState(() {
        _checkingActivation = true;
      });
    }

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
      print('❌ Error checking activation: $e');
      if (mounted) {
        setState(() {
          _activationStatusMessage = _isUserActivated
              ? 'Activated'
              : 'Not Activated';
          _checkingActivation = false;
        });
      }
    } finally {
      if (!hadCachedState && mounted) {
        setState(() {
          _checkingActivation = false;
        });
      }
    }
  }

  Future<void> _refreshActivationStatus() async {
    await _checkActivationStatus(forceRefresh: true);
  }

  Future<void> _loadRecentCourseFromStorage() async {
    try {
      if (_currentUserId == null) {
        print('⚠️ Cannot load recent course: No user ID');
        return;
      }

      final box = await Hive.openBox(recentCourseBox);
      final userKey = 'recent_course_$_currentUserId';
      final recentData = box.get(userKey);

      if (recentData == null) {
        print('ℹ️ No recent course found for user $_currentUserId');
        return;
      }

      Course? course;

      // Handle LinkedMap (Hive's internal Map type)
      if (recentData is Map) {
        try {
          // Convert LinkedMap<dynamic, dynamic> to Map<String, dynamic>
          final Map<String, dynamic> jsonData = {};
          recentData.forEach((key, value) {
            if (key is String) {
              jsonData[key] = value;
            } else if (key is int || key is double) {
              jsonData[key.toString()] = value;
            }
          });

          print('📋 Parsing JSON data with keys: ${jsonData.keys.toList()}');
          course = Course.fromJson(jsonData);
        } catch (e) {
          print('❌ Error parsing Map to Course: $e');
          print('📋 Raw data: $recentData');
        }
      }
      // Fallback to Course object (if adapter was working before)
      else if (recentData is Course) {
        course = recentData;
      } else {
        print('⚠️ Unexpected data type: ${recentData.runtimeType}');
      }

      if (course != null) {
        final isDownloaded = await _isCourseDownloaded(course.id);
        if (mounted) {
          setState(() {
            recentCourse = course;
          });
        }
        print(
          '✅ Loaded recent course for user $_currentUserId: ${course.code} (Downloaded: $isDownloaded)',
        );
      } else {
        print('⚠️ Could not parse recent course data');
        // Try to debug what's actually in the data
        print('🔍 Raw recentData type: ${recentData.runtimeType}');
        print('🔍 Raw recentData: $recentData');
      }
    } catch (e) {
      print('❌ Error loading recent course: $e');
    }
  }

  Future<void> _debugRecentCourseStorage() async {
    print('🔍 === DEBUG RECENT COURSE STORAGE ===');
    try {
      final box = await Hive.openBox(recentCourseBox);
      print('📦 Box keys: ${box.keys.toList()}');

      if (_currentUserId != null) {
        final userKey = 'recent_course_$_currentUserId';
        final data = box.get(userKey);
        print('👤 User key ($userKey) exists: ${data != null}');
        if (data != null) {
          print('   Data type: ${data.runtimeType}');
          if (data is Map) {
            print('   ✅ Is Map (JSON)');
          } else if (data is Course) {
            print('   ✅ Is Course object');
          }
        }
      }

      // Also check global
      final globalData = box.get('recent_course');
      print('🌍 Global recent course exists: ${globalData != null}');
    } catch (e) {
      print('❌ Debug error: $e');
    }
    print('🔍 === END DEBUG ===');
  }

  Future<void> _cleanupOrphanedRecentCourses() async {
    try {
      final box = await Hive.openBox(recentCourseBox);
      final allKeys = box.keys.toList();

      print('🧹 Cleaning up orphaned recent courses...');

      for (var key in allKeys) {
        // Check if it's a user-specific recent course
        if (key.toString().startsWith('recent_course_user_')) {
          final userIdFromKey = key.toString().replaceFirst(
            'recent_course_user_',
            '',
          );

          // If this user is not the current user, check if user still exists
          if (userIdFromKey != _currentUserId) {
            // Check if user exists in user_box
            final userBox = await Hive.openBox('user_box');
            final userExists = userBox.keys.any(
              (userKey) => userKey.toString().contains(userIdFromKey),
            );

            if (!userExists) {
              print(
                '🗑️ Removing orphaned recent course for user $userIdFromKey',
              );
              await box.delete(key);
            }
          }
        }
      }
    } catch (e) {
      print('⚠️ Error cleaning up orphaned recent courses: $e');
    }
  }

  Future<void> _migrateOldRecentCourses() async {
    try {
      final box = await Hive.openBox(recentCourseBox);
      final globalRecentData = box.get('recent_course');

      if (globalRecentData != null && _currentUserId != null) {
        final userKey = 'recent_course_user_$_currentUserId';

        // Check if user doesn't already have a recent course
        if (box.get(userKey) == null) {
          await box.put(userKey, globalRecentData);
          print('🔄 Migrated global recent course to user-specific storage');
        }

        // Keep the global one for backward compatibility
      }
    } catch (e) {
      print('⚠️ Error migrating recent courses: $e');
    }
  }

  Future<void> _saveRecentCourseToStorage(Course course) async {
    try {
      if (_currentUserId == null) {
        print('⚠️ Cannot save recent course: No user ID');
        return;
      }

      final box = await Hive.openBox(recentCourseBox);
      final userKey = 'recent_course_$_currentUserId';

      // ALWAYS save as JSON to avoid adapter issues
      // Convert Course to Map<String, dynamic> explicitly
      final courseJson = course.toJson();

      // Ensure all values are JSON-serializable
      final cleanJson = Map<String, dynamic>.from(courseJson);

      // Make sure color is saved as int
      if (course.color != null) {
        cleanJson['color'] = course.color.value;
        cleanJson['color_value'] = course.color.value;
      }

      // Save it
      await box.put(userKey, cleanJson);

      print(
        '✅ Saved recent course as JSON for user $_currentUserId: ${course.code}',
      );
      print('📋 Saved keys: ${cleanJson.keys.toList()}');

      if (mounted) {
        setState(() {
          recentCourse = course;
        });
      }
    } catch (e) {
      print('❌ Error saving recent course: $e');
    }
  }

  Future<void> _fixExistingRecentCourseData() async {
    try {
      final box = await Hive.openBox(recentCourseBox);

      if (_currentUserId != null) {
        final userKey = 'recent_course_$_currentUserId';
        final data = box.get(userKey);

        if (data != null && data is! Map<String, dynamic>) {
          print('🔧 Fixing corrupted recent course data...');

          // Try to convert to Map<String, dynamic>
          if (data is Map) {
            final Map<String, dynamic> cleanData = {};
            data.forEach((key, value) {
              if (key is String) {
                cleanData[key] = value;
              } else if (key is int || key is double) {
                cleanData[key.toString()] = value;
              }
            });

            await box.put(userKey, cleanData);
            print('✅ Fixed recent course data');
          } else if (data is Course) {
            // If it's already a Course object, convert to JSON
            await box.put(userKey, data.toJson());
            print('✅ Converted Course object to JSON');
          } else {
            // Unrecognized type, delete it
            await box.delete(userKey);
            print('🗑️ Deleted unrecognized recent course data');
          }
        }
      }
    } catch (e) {
      print('⚠️ Error fixing recent course data: $e');
    }
  }

  Future<List<Course>> _enhanceCoursesWithDownloadStatus(
    List<Course> courses,
  ) async {
    final enhancedCourses = <Course>[];

    try {
      final offlineBox = await Hive.openBox(offlineCoursesBox);
      final downloadedCourseIds = offlineBox.get(
        'downloaded_course_ids',
        defaultValue: <String>[],
      );

      for (var course in courses) {
        final isDownloaded = downloadedCourseIds.contains(course.id);

        String? localImagePath;
        if (isDownloaded) {
          try {
            final courseData = offlineBox.get('course_${course.id}');
            if (courseData != null && courseData['local_image_path'] != null) {
              localImagePath = courseData['local_image_path'];
            }
          } catch (e) {
            print('⚠️ Error getting local image path for ${course.id}: $e');
          }
        }

        final enhancedCourse = Course(
          id: course.id,
          code: course.code,
          title: course.title,
          description: course.description,
          imageUrl: course.imageUrl,
          abbreviation: course.abbreviation,
          creditUnits: course.creditUnits,
          universityId: course.universityId,
          universityName: course.universityName,
          levelId: course.levelId,
          levelName: course.levelName,
          semesterId: course.semesterId,
          semesterName: course.semesterName,
          departmentsInfo: course.departmentsInfo,
          progress: course.progress,
          isDownloaded: isDownloaded,
          downloadDate: isDownloaded ? DateTime.now() : null,
          localImagePath: localImagePath,
          color: course.color,
        );

        enhancedCourses.add(enhancedCourse);
      }
    } catch (e) {
      print('⚠️ Error enhancing courses: $e');
      return courses;
    }

    return enhancedCourses;
  }

  Future<List<Course>> _loadCachedCourses() async {
    try {
      final box = await Hive.openBox(coursesCacheBox);
      final cachedData = box.get('cached_courses');

      if (cachedData == null) {
        print('📦 No cached courses found');
        return [];
      }

      print('📦 Found cached data type: ${cachedData.runtimeType}');

      if (cachedData is List<Course>) {
        print('✅ Loaded ${cachedData.length} courses as Hive objects');
        return cachedData;
      } else if (cachedData is List) {
        print('📦 Processing List of ${cachedData.length} items');

        final courses = <Course>[];
        for (var i = 0; i < cachedData.length; i++) {
          try {
            final item = cachedData[i];
            if (item is Course) {
              courses.add(item);
            } else if (item is Map<String, dynamic>) {
              courses.add(Course.fromJson(item));
            } else if (item is Map) {
              // Handle LinkedMap or other Map types
              try {
                final json = Map<String, dynamic>.from(item);
                courses.add(Course.fromJson(json));
              } catch (e) {
                print('⚠️ Error converting map at index $i: $e');
              }
            }
          } catch (e) {
            print('⚠️ Error processing cached item at index $i: $e');
          }
        }

        print('✅ Loaded ${courses.length} courses from cache');
        return courses;
      }

      print('⚠️ Unknown cached data type: ${cachedData.runtimeType}');
      return [];
    } catch (e) {
      print('❌ Error loading cached courses: $e');
      return [];
    }
  }

  Future<void> _cacheCourses(List<Course> courses) async {
    try {
      final box = await Hive.openBox(coursesCacheBox);
      await box.put('cached_courses', courses);
      print('✅ Cached ${courses.length} courses as Hive objects');
    } catch (e) {
      print('❌ Error caching courses as Hive objects: $e');

      try {
        final box = await Hive.openBox(coursesCacheBox);
        final courseData = courses.map((course) => course.toJson()).toList();
        await box.put('cached_courses', courseData);
        print('✅ Cached ${courses.length} courses as JSON fallback');
      } catch (e2) {
        print('❌ JSON fallback also failed: $e2');
      }
    }
  }

  Future<void> _loadDownloadStatuses() async {
    try {
      final box = await Hive.openBox(offlineCoursesBox);
      final downloadedCourseIds = box.get(
        'downloaded_course_ids',
        defaultValue: <String>[],
      );

      for (var courseId in downloadedCourseIds) {
        isCourseDownloaded[courseId] = true;
      }

      print('📥 Loaded ${downloadedCourseIds.length} downloaded courses');
    } catch (e) {
      print('❌ Error loading download statuses: $e');
    }
  }

  Future<bool> _isCourseDownloaded(String courseId) async {
    try {
      final box = await Hive.openBox(offlineCoursesBox);
      final downloadedCourseIds = box.get(
        'downloaded_course_ids',
        defaultValue: <String>[],
      );
      return downloadedCourseIds.contains(courseId);
    } catch (e) {
      return false;
    }
  }

  // Future<void> _loadCoursesProgress(List<Course> courses) async {
  //   try {
  //     print('📊 Loading progress for ${courses.length} courses...');

  //     final userData = await _apiService.getCurrentUser();
  //     if (userData == null) {
  //       print('⚠️ No user data found');
  //       return;
  //     }

  //     final userId = userData['id'].toString();

  //     for (var course in courses) {
  //       try {
  //         print('📖 Calculating progress for course: ${course.code}');

  //         final topics = await _apiService.getTopics(
  //           courseId: int.parse(course.id),
  //         );

  //         if (topics.isNotEmpty) {
  //           print('   - Found ${topics.length} topics');

  //           int completedCount = 0;

  //           for (var topic in topics) {
  //             if (topic.isCompleted) {
  //               completedCount++;
  //             }
  //           }

  //           final progress = topics.isNotEmpty
  //               ? ((completedCount / topics.length) * 100).round()
  //               : 0;
  //           course.progress = progress;

  //           print(
  //             '   - Progress: $progress% ($completedCount/${topics.length} topics)',
  //           );

  //           await _saveProgress(course.id, progress);
  //         } else {
  //           print('   - No topics found for this course');
  //           final cachedProgress = await _getCachedProgress(course.id);
  //           course.progress = cachedProgress;
  //         }
  //       } catch (e) {
  //         print('⚠️ Error loading progress for ${course.code}: $e');
  //         final cachedProgress = await _getCachedProgress(course.id);
  //         course.progress = cachedProgress;
  //       }
  //     }

  //     print('✅ Course progress loading complete');
  //   } catch (e) {
  //     print('❌ Error loading course progress: $e');
  //     for (var course in courses) {
  //       course.progress = await _getCachedProgress(course.id);
  //     }
  //   }
  // }

  // In courses_screen.dart - Replace your _loadCoursesProgress method
  Future<void> _loadCoursesProgress(List<Course> courses) async {
    print('📊 Loading progress for ${courses.length} courses...');

    // FIRST: Show cached progress immediately (fast)
    for (var course in courses) {
      final cachedProgress = await _getCachedProgress(course.id);
      course.progress = cachedProgress;
    }

    // Update UI with cached progress
    if (mounted) {
      setState(() {});
    }

    // THEN: Try to fetch real progress in the background (slow)
    try {
      final userData = await _apiService.getCurrentUser();
      if (userData == null) return;

      // Create a list of futures for all topic requests
      final List<Future> progressFutures = [];

      for (var course in courses) {
        progressFutures.add(_fetchCourseProgress(course));
      }

      // Wait for all progress fetches with a timeout
      await Future.wait(progressFutures).timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          print('⏰ Progress fetch timeout - using cached values');
          return [];
        },
      );

      // Update UI with real progress
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      print('⚠️ Background progress fetch error: $e');
      // Already showing cached progress, so no need to show error
    }
  }

  // Helper method to fetch progress for a single course
  Future<void> _fetchCourseProgress(Course course) async {
    try {
      final topics = await _apiService
          .getTopics(courseId: int.parse(course.id))
          .timeout(const Duration(seconds: 3));

      if (topics.isNotEmpty) {
        int completedCount = 0;
        for (var topic in topics) {
          if (topic.isCompleted) completedCount++;
        }

        final progress = ((completedCount / topics.length) * 100).round();
        course.progress = progress;
        await _saveProgress(course.id, progress);

        print('   - ${course.code}: $progress% (real)');
      }
    } catch (e) {
      print('   - ${course.code}: using cached (fetch failed)');
      // Keep cached progress
    }
  }

  Future<int> _getCachedProgress(String courseId) async {
    try {
      final box = await Hive.openBox('course_progress');
      return box.get(courseId) ?? 0;
    } catch (e) {
      return 0;
    }
  }

  Future<void> _saveProgress(String courseId, int progress) async {
    try {
      final box = await Hive.openBox('course_progress');
      await box.put(courseId, progress);
    } catch (e) {
      print('❌ Error saving progress: $e');
    }
  }

  void _filterCourses() {
    final query = _searchController.text.toLowerCase();
    if (query.isEmpty) {
      setState(() {
        filteredCourses = allCourses;
      });
    } else {
      setState(() {
        filteredCourses = allCourses
            .where(
              (course) =>
                  course.code.toLowerCase().contains(query) ||
                  course.title.toLowerCase().contains(query) ||
                  (course.abbreviation?.toLowerCase().contains(query) ?? false),
            )
            .toList();
      });
    }
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() {
      filteredCourses = allCourses;
    });
  }

  void _unfocusSearch() {
    _searchFocusNode.unfocus();
  }

  void _navigateToCourseDetails(Course course) async {
    await _saveRecentCourseToStorage(course);
    setState(() {
      recentCourse = course;
    });

    final result = await Navigator.pushNamed(
      context,
      '/course-detail',
      arguments: course,
    );

    if (mounted && result == true) {
      await refreshCourseProgress();
    }
  }

  Future<void> refreshCourseProgress() async {
    if (!isLoading) {
      print('🔄 Refreshing course progress...');
      await _loadCoursesProgress(allCourses);
      if (mounted) {
        setState(() {});
      }
    }
  }

  Future<void> _downloadCourseForOffline(Course course) async {
    if (_currentUserProfile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('❌ Please set your academic profile first'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
      return;
    }

    // Check if course is for user's department before downloading
    final bool isForUserDepartment = course.departmentsInfo.any((deptInfo) {
      final deptId =
          deptInfo['department_id']?.toString() ??
          deptInfo['id']?.toString() ??
          deptInfo['department']?.toString() ??
          '';
      return deptId == _currentUserProfile!.departmentId;
    });

    if (!isForUserDepartment) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '❌ ${course.code} is not available for your department',
          ),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
      return;
    }

    if (downloadingCourses[course.id] == true ||
        isCourseDownloaded[course.id] == true) {
      return;
    }

    setState(() {
      downloadingCourses[course.id] = true;
      downloadProgress[course.id] = 0.0;
    });

    try {
      print(
        '📥 Starting download for course: ${course.code} for department ${_currentUserProfile!.departmentName}',
      );

      final userData = await _apiService.getCurrentUser();
      if (userData == null) throw Exception('User not logged in');

      final userId = userData['id'].toString();

      Map<String, dynamic> courseJson = course.toJson();
      courseJson['color_value'] = course.color.value;
      courseJson['color'] = course.color.value;

      // Store with current user profile
      final downloadRecord = DownloadRecord(
        courseId: course.id,
        userId: userId,
        userProfile: _currentUserProfile,
        downloadedAt: DateTime.now(),
        courseUniversityId: course.universityId,
        courseLevelId: course.levelId,
        courseSemesterId: course.semesterId,
      );

      final courseData = {
        'course': courseJson,
        'download_record': downloadRecord.toJson(),
        'download_date': DateTime.now().toIso8601String(),
        'user_id': userId,
      };

      // Update progress
      setState(() {
        downloadProgress[course.id] = 0.05;
      });

      // Step 1: Get course outlines
      final outlines = await _apiService.getCourseOutlines(
        int.parse(course.id),
      );
      final outlinesJson = outlines.map((outline) => outline.toJson()).toList();
      courseData['outlines'] = outlinesJson;

      // Update progress
      setState(() {
        downloadProgress[course.id] = 0.15;
      });

      // Step 2: Get topics for each outline
      final allTopics = <Map<String, dynamic>>[];
      for (var outline in outlines) {
        try {
          final topics = await _apiService.getTopics(
            outlineId: int.parse(outline.id),
          );
          for (var topic in topics) {
            final topicJson = topic.toJson();

            // Extract image URL from topic
            String? topicImageUrl =
                topicJson['display_image_url'] ?? topicJson['image'];
            if (topicImageUrl == null || topicImageUrl.isEmpty) {
              // Try other possible fields
              topicImageUrl =
                  topicJson['image_url'] ??
                  topicJson['thumbnail_url'] ??
                  topicJson['cover_image'];
            }

            // Add original image URL for reference
            if (topicImageUrl != null && topicImageUrl.isNotEmpty) {
              topicJson['original_image_url'] = topicImageUrl;
            }

            allTopics.add(topicJson);
          }
        } catch (e) {
          print('⚠️ Error getting topics for outline ${outline.id}: $e');
        }
      }
      courseData['topics'] = allTopics;

      // Update progress
      setState(() {
        downloadProgress[course.id] = 0.25;
      });

      // ============ DOWNLOAD PAST QUESTIONS ============
      // try {
      //   print('📝 Downloading past questions for course: ${course.code}');
      //   final pastQuestions = await _apiService.getPastQuestions(
      //     courseId: course.id,
      //   );

      //   if (pastQuestions.isNotEmpty) {
      //     final pastQuestionsJson = pastQuestions.map((pq) {
      //       final json = pq.toJson();

      //       // IMPORTANT: Ensure session info is properly included
      //       print('🔍 PastQuestion sessionInfo: ${pq.sessionInfo}');
      //       print('🔍 PastQuestion sessionId: ${pq.sessionId}');

      //       // If sessionInfo is empty but we have sessionId, add basic session info
      //       if (pq.sessionInfo.isEmpty &&
      //           pq.sessionId != null &&
      //           pq.sessionId!.isNotEmpty) {
      //         json['session_info'] = {
      //           'id': pq.sessionId,
      //           'name': 'Session ${pq.sessionId}',
      //           'is_active': true,
      //         };
      //       }

      //       // Store original image URLs for reference
      //       if (pq.questionImageUrl != null &&
      //           pq.questionImageUrl!.isNotEmpty) {
      //         json['original_question_image_url'] = pq.questionImageUrl;
      //       }
      //       if (pq.solutionImageUrl != null &&
      //           pq.solutionImageUrl!.isNotEmpty) {
      //         json['original_solution_image_url'] = pq.solutionImageUrl;
      //       }

      //       return json;
      //     }).toList();

      //     courseData['past_questions'] = pastQuestionsJson;
      //     print('✅ Downloaded ${pastQuestions.length} past questions');
      //   } else {
      //     print('ℹ️ No past questions found for this course');
      //     courseData['past_questions'] = [];
      //   }
      // } catch (e) {
      //   print('⚠️ Error downloading past questions: $e');
      //   courseData['past_questions'] = [];
      // }

      // // Update progress
      // setState(() {
      //   downloadProgress[course.id] = 0.35;
      // });

      // ============ DOWNLOAD PAST QUESTIONS ============
      try {
        print('📝 Downloading past questions for course: ${course.code}');
        final pastQuestions = await _apiService.getPastQuestions(
          courseId: course.id,
        );

        if (pastQuestions.isNotEmpty) {
          final pastQuestionsJson = pastQuestions.map((pq) {
            // Get the JSON from the question
            final json = pq.toJson();

            // Create a clean map to ensure proper types for Hive storage
            final cleanJson = <String, dynamic>{};

            // Copy all properties ensuring String keys
            json.forEach((key, value) {
              if (key is String) {
                cleanJson[key] = value;
              } else if (key is int || key is double) {
                cleanJson[key.toString()] = value;
              }
            });

            // DEBUG: Log session info from the API
            print('🔍 PastQuestion ID: ${pq.id}');
            print('   - SessionId from API: ${pq.sessionId}');
            print('   - SessionInfo from API: ${pq.sessionInfo}');
            print('   - SessionInfo type: ${pq.sessionInfo.runtimeType}');

            // CRITICAL FIX: Ensure session_info is properly structured
            // Check if session_info exists and is properly formatted
            if (pq.sessionInfo != null && pq.sessionInfo.isNotEmpty) {
              // Session info exists from API - ensure it's properly structured
              final sessionInfoMap = <String, dynamic>{};
              pq.sessionInfo.forEach((key, value) {
                if (key is String) {
                  sessionInfoMap[key] = value;
                } else if (key is int || key is double) {
                  sessionInfoMap[key.toString()] = value;
                }
              });

              // Ensure session_info has at least id and name
              if (!sessionInfoMap.containsKey('id') && pq.sessionId != null) {
                sessionInfoMap['id'] = pq.sessionId;
              }
              if (!sessionInfoMap.containsKey('name') && pq.sessionId != null) {
                sessionInfoMap['name'] = 'Session ${pq.sessionId}';
              }
              if (!sessionInfoMap.containsKey('is_active')) {
                sessionInfoMap['is_active'] = true;
              }

              cleanJson['session_info'] = sessionInfoMap;
              print('   ✅ Using API session_info (structured)');
            }
            // If no session_info from API but we have session_id
            else if (pq.sessionId != null && pq.sessionId!.isNotEmpty) {
              // Create session_info from session_id
              cleanJson['session_info'] = {
                'id': pq.sessionId,
                'name': 'Session ${pq.sessionId}',
                'is_active': true,
              };
              print('   ✅ Created session_info from session_id');
            }
            // If no session info at all
            else {
              // Use a default session info
              cleanJson['session_info'] = {
                'id': 'unknown',
                'name': 'Unknown Session',
                'is_active': true,
              };
              print('   ⚠️ No session info, using default');
            }

            // CRITICAL: Also ensure session_id field is populated
            if (pq.sessionId != null && pq.sessionId!.isNotEmpty) {
              cleanJson['session_id'] = pq.sessionId;
            } else if (cleanJson['session_info'] != null) {
              // Get session_id from session_info if available
              final sessionInfo = cleanJson['session_info'] as Map;
              if (sessionInfo['id'] != null) {
                cleanJson['session_id'] = sessionInfo['id'].toString();
              }
            }

            // Ensure topic_info is properly structured (if exists)
            if (pq.topicInfo != null && pq.topicInfo!.isNotEmpty) {
              final topicInfoMap = <String, dynamic>{};
              pq.topicInfo!.forEach((key, value) {
                if (key is String) {
                  topicInfoMap[key] = value;
                } else if (key is int || key is double) {
                  topicInfoMap[key.toString()] = value;
                }
              });
              cleanJson['topic_info'] = topicInfoMap;
            }

            // Store original image URLs for reference
            if (pq.questionImageUrl != null &&
                pq.questionImageUrl!.isNotEmpty) {
              cleanJson['original_question_image_url'] = pq.questionImageUrl;
              print('   ✅ Stored original question image URL');
            }
            if (pq.solutionImageUrl != null &&
                pq.solutionImageUrl!.isNotEmpty) {
              cleanJson['original_solution_image_url'] = pq.solutionImageUrl;
              print('   ✅ Stored original solution image URL');
            }

            // Log final structure
            print('   ✅ Final session_info: ${cleanJson['session_info']}');
            print('   ✅ Final session_id: ${cleanJson['session_id']}');
            print('   ✅ Final topic_info: ${cleanJson['topic_info']}');

            return cleanJson;
          }).toList();

          courseData['past_questions'] = pastQuestionsJson;
          print('✅ Downloaded ${pastQuestions.length} past questions');

          // Debug: Show sample of what was saved
          if (pastQuestionsJson.isNotEmpty) {
            print('📋 Sample saved past question structure:');
            final sample = pastQuestionsJson.first;
            print('   - ID: ${sample['id']}');
            print('   - Session ID: ${sample['session_id']}');
            print('   - Session Info: ${sample['session_info']}');
            print(
              '   - Has question image: ${sample['question_image_url'] != null}',
            );
          }
        } else {
          print('ℹ️ No past questions found for this course');
          courseData['past_questions'] = [];
        }
      } catch (e) {
        print('⚠️ Error downloading past questions: $e');
        print('📋 Stack trace: ${e.toString()}');
        courseData['past_questions'] = [];
      }

      // Update progress
      setState(() {
        downloadProgress[course.id] = 0.35;
      });

      // ============ DOWNLOAD TEST QUESTIONS ============
      // try {
      //   print('📝 Downloading test questions for course: ${course.code}');
      //   final testQuestions = await _apiService.getTestQuestions(
      //     courseId: course.id,
      //   );

      //   if (testQuestions.isNotEmpty) {
      //     final testQuestionsJson = testQuestions.map((tq) {
      //       final json = tq.toJson();

      //       // IMPORTANT: Ensure session info is properly included
      //       print('🔍 TestQuestion sessionInfo: ${tq.sessionInfo}');
      //       print('🔍 TestQuestion sessionId: ${tq.sessionId}');

      //       // If sessionInfo is empty but we have sessionId, add basic session info
      //       if (tq.sessionInfo.isEmpty &&
      //           tq.sessionId != null &&
      //           tq.sessionId!.isNotEmpty) {
      //         json['session_info'] = {
      //           'id': tq.sessionId,
      //           'name': 'Session ${tq.sessionId}',
      //           'is_active': true,
      //         };
      //       }

      //       // Store original image URLs for reference
      //       if (tq.questionImageUrl != null &&
      //           tq.questionImageUrl!.isNotEmpty) {
      //         json['original_question_image_url'] = tq.questionImageUrl;
      //       }
      //       if (tq.solutionImageUrl != null &&
      //           tq.solutionImageUrl!.isNotEmpty) {
      //         json['original_solution_image_url'] = tq.solutionImageUrl;
      //       }

      //       return json;
      //     }).toList();

      //     courseData['test_questions'] = testQuestionsJson;
      //     print('✅ Downloaded ${testQuestions.length} test questions');
      //   } else {
      //     print('ℹ️ No test questions found for this course');
      //     courseData['test_questions'] = [];
      //   }
      // } catch (e) {
      //   print('⚠️ Error downloading test questions: $e');
      //   courseData['test_questions'] = [];
      // }

      // // Update progress
      // setState(() {
      //   downloadProgress[course.id] = 0.45;
      // });

      // ============ DOWNLOAD TEST QUESTIONS ============
      try {
        print('📝 Downloading test questions for course: ${course.code}');
        final testQuestions = await _apiService.getTestQuestions(
          courseId: course.id,
        );

        if (testQuestions.isNotEmpty) {
          final testQuestionsJson = testQuestions.map((tq) {
            final json = tq.toJson();
            final cleanJson = <String, dynamic>{};

            json.forEach((key, value) {
              if (key is String) {
                cleanJson[key] = value;
              } else if (key is int || key is double) {
                cleanJson[key.toString()] = value;
              }
            });

            // Ensure session_info is properly structured
            if (tq.sessionInfo != null && tq.sessionInfo.isNotEmpty) {
              final sessionInfoMap = <String, dynamic>{};
              tq.sessionInfo.forEach((key, value) {
                if (key is String) {
                  sessionInfoMap[key] = value;
                } else if (key is int || key is double) {
                  sessionInfoMap[key.toString()] = value;
                }
              });

              if (!sessionInfoMap.containsKey('id') && tq.sessionId != null) {
                sessionInfoMap['id'] = tq.sessionId;
              }
              if (!sessionInfoMap.containsKey('name') && tq.sessionId != null) {
                sessionInfoMap['name'] = 'Session ${tq.sessionId}';
              }
              if (!sessionInfoMap.containsKey('is_active')) {
                sessionInfoMap['is_active'] = true;
              }

              cleanJson['session_info'] = sessionInfoMap;
            } else if (tq.sessionId != null && tq.sessionId!.isNotEmpty) {
              cleanJson['session_info'] = {
                'id': tq.sessionId,
                'name': 'Session ${tq.sessionId}',
                'is_active': true,
              };
            } else {
              cleanJson['session_info'] = {
                'id': 'unknown',
                'name': 'Unknown Session',
                'is_active': true,
              };
            }

            // Ensure session_id field is populated
            if (tq.sessionId != null && tq.sessionId!.isNotEmpty) {
              cleanJson['session_id'] = tq.sessionId;
            } else if (cleanJson['session_info'] != null) {
              final sessionInfo = cleanJson['session_info'] as Map;
              if (sessionInfo['id'] != null) {
                cleanJson['session_id'] = sessionInfo['id'].toString();
              }
            }

            // Store original image URLs
            if (tq.questionImageUrl != null &&
                tq.questionImageUrl!.isNotEmpty) {
              cleanJson['original_question_image_url'] = tq.questionImageUrl;
            }
            if (tq.solutionImageUrl != null &&
                tq.solutionImageUrl!.isNotEmpty) {
              cleanJson['original_solution_image_url'] = tq.solutionImageUrl;
            }

            return cleanJson;
          }).toList();

          courseData['test_questions'] = testQuestionsJson;
          print('✅ Downloaded ${testQuestions.length} test questions');
        } else {
          print('ℹ️ No test questions found for this course');
          courseData['test_questions'] = [];
        }
      } catch (e) {
        print('⚠️ Error downloading test questions: $e');
        courseData['test_questions'] = [];
      }
      // ============ DOWNLOAD ACADEMIC SESSIONS ============
      try {
        print('📅 Downloading academic sessions...');
        final sessions = await _apiService.getPastQuestionSessions();

        if (sessions.isNotEmpty) {
          final sessionsJson = sessions
              .map((session) => session.toJson())
              .toList();
          courseData['sessions'] = sessionsJson;
          print('✅ Downloaded ${sessions.length} academic sessions');

          // Also save to global cache
          final offlineBox = await Hive.openBox(offlineCoursesBox);
          await offlineBox.put('offline_sessions_cache', sessionsJson);
        } else {
          print('ℹ️ No academic sessions found');
          courseData['sessions'] = [];
        }
      } catch (e) {
        print('⚠️ Error downloading academic sessions: $e');
        courseData['sessions'] = [];
      }

      // Update progress
      setState(() {
        downloadProgress[course.id] = 0.55;
      });

      // Step 3: Download images
      final downloadedImages = <String, Map<String, dynamic>>{};
      int totalImages = 0;
      int downloadedImagesCount = 0;

      // Count total images
      if (course.imageUrl != null && course.imageUrl!.isNotEmpty) totalImages++;

      // Count topic images
      for (var topic in allTopics) {
        if (topic['original_image_url'] != null) totalImages++;

        for (final htmlContent in [
          topic['content'] as String?,
          topic['completion_question_text'] as String?,
          topic['solution_text'] as String?,
        ]) {
          if (htmlContent != null && htmlContent.isNotEmpty) {
            totalImages += _extractImageUrlsFromHtml(htmlContent).length;
          }
        }
      }

      final pastQuestionsList = courseData['past_questions'] as List? ?? [];
      for (var pq in pastQuestionsList) {
        if (pq is Map) {
          if (pq['original_question_image_url'] != null) totalImages++;
          if (pq['original_solution_image_url'] != null) totalImages++;
        }
      }

      final testQuestionsList = courseData['test_questions'] as List? ?? [];
      for (var tq in testQuestionsList) {
        if (tq is Map) {
          if (tq['original_question_image_url'] != null) totalImages++;
          if (tq['original_solution_image_url'] != null) totalImages++;
        }
      }

      print('📊 Total images to download: $totalImages');

      // Download course image if exists
      if (course.imageUrl != null && course.imageUrl!.isNotEmpty) {
        try {
          print('🖼️ Downloading course image...');
          final imagePath = await _downloadImage(
            course.imageUrl!,
            'course_${course.id}',
          );
          if (imagePath != null) {
            downloadedImages['course_image'] = {
              'path': imagePath,
              'original_url': course.imageUrl,
              'type': 'course',
            };
            courseData['local_image_path'] = imagePath;
            downloadedImagesCount++;
          }

          // Update progress based on images downloaded
          if (totalImages > 0) {
            setState(() {
              downloadProgress[course.id] =
                  0.55 + (0.30 * (downloadedImagesCount / totalImages));
            });
          }
        } catch (e) {
          print('⚠️ Error downloading course image: $e');
        }
      }

      // Download topic images
      for (var topic in allTopics) {
        final originalUrl = topic['original_image_url'];
        if (originalUrl != null &&
            originalUrl is String &&
            originalUrl.isNotEmpty) {
          try {
            print('🖼️ Downloading topic image for topic ${topic['id']}...');
            final imagePath = await _downloadImage(
              originalUrl,
              'topic_${topic['id']}',
            );
            if (imagePath != null) {
              downloadedImages['topic_${topic['id']}'] = {
                'path': imagePath,
                'original_url': originalUrl,
                'type': 'topic',
              };
              topic['local_image_path'] = imagePath;
              downloadedImagesCount++;
            }

            // Update progress
            if (totalImages > 0) {
              setState(() {
                downloadProgress[course.id] =
                    0.55 + (0.30 * (downloadedImagesCount / totalImages));
              });
            }
          } catch (e) {
            print('⚠️ Error downloading topic image for ${topic['id']}: $e');
          }
        }
      }

      // Download embedded lecture images from topic content and lecture text
      int ckeditorImageCount = 0;
      for (var topic in allTopics) {
        final htmlSources = <String, String?>{
          'content': topic['content'] as String?,
          'question': topic['completion_question_text'] as String?,
          'solution': topic['solution_text'] as String?,
        };

        for (final htmlEntry in htmlSources.entries) {
          final content = htmlEntry.value;
          if (content == null || content.isEmpty) {
            continue;
          }

          try {
            final imageUrls = _extractImageUrlsFromHtml(content);

            for (var imageUrl in imageUrls) {
              if (imageUrl.isNotEmpty) {
                try {
                  print(
                    '🖼️ Downloading embedded lecture image for topic ${topic['id']} (${htmlEntry.key})...',
                  );
                  final imagePath = await _downloadImage(
                    imageUrl,
                    'topic_${topic['id']}_${htmlEntry.key}_$ckeditorImageCount',
                  );
                  if (imagePath != null) {
                    downloadedImages['topic_${topic['id']}_${htmlEntry.key}_$ckeditorImageCount'] =
                        {
                          'path': imagePath,
                          'original_url': imageUrl,
                          'type': 'lecture_inline',
                        };
                    ckeditorImageCount++;
                    downloadedImagesCount++;

                    // Update progress
                    if (totalImages > 0) {
                      setState(() {
                        downloadProgress[course.id] =
                            0.55 +
                            (0.30 * (downloadedImagesCount / totalImages));
                      });
                    }
                  }
                } catch (e) {
                  print(
                    '⚠️ Error downloading embedded lecture image for topic ${topic['id']}: $e',
                  );
                }
              }
            }
          } catch (e) {
            print(
              '⚠️ Error extracting embedded lecture images from topic ${topic['id']}: $e',
            );
          }
        }
      }

      // Download past question images
      for (var pq in pastQuestionsList) {
        if (pq is Map) {
          final questionImageUrl = pq['original_question_image_url'];
          final solutionImageUrl = pq['original_solution_image_url'];

          if (questionImageUrl != null &&
              questionImageUrl is String &&
              questionImageUrl.isNotEmpty) {
            try {
              print(
                '🖼️ Downloading past question image for PQ ${pq['id']}...',
              );
              final imagePath = await _downloadImage(
                questionImageUrl,
                'past_question_${pq['id']}',
              );
              if (imagePath != null) {
                downloadedImages['past_question_${pq['id']}'] = {
                  'path': imagePath,
                  'original_url': questionImageUrl,
                  'type': 'past_question',
                };
                pq['local_question_image_path'] = imagePath;
                downloadedImagesCount++;

                // Update progress
                if (totalImages > 0) {
                  setState(() {
                    downloadProgress[course.id] =
                        0.55 + (0.30 * (downloadedImagesCount / totalImages));
                  });
                }
              }
            } catch (e) {
              print(
                '⚠️ Error downloading past question image for ${pq['id']}: $e',
              );
            }
          }

          if (solutionImageUrl != null &&
              solutionImageUrl is String &&
              solutionImageUrl.isNotEmpty) {
            try {
              print(
                '🖼️ Downloading past question solution image for PQ ${pq['id']}...',
              );
              final imagePath = await _downloadImage(
                solutionImageUrl,
                'past_question_solution_${pq['id']}',
              );
              if (imagePath != null) {
                downloadedImages['past_question_solution_${pq['id']}'] = {
                  'path': imagePath,
                  'original_url': solutionImageUrl,
                  'type': 'past_question_solution',
                };
                pq['local_solution_image_path'] = imagePath;
                downloadedImagesCount++;

                // Update progress
                if (totalImages > 0) {
                  setState(() {
                    downloadProgress[course.id] =
                        0.55 + (0.30 * (downloadedImagesCount / totalImages));
                  });
                }
              }
            } catch (e) {
              print(
                '⚠️ Error downloading past question solution image for ${pq['id']}: $e',
              );
            }
          }
        }
      }

      // Download test question images
      for (var tq in testQuestionsList) {
        if (tq is Map) {
          final questionImageUrl = tq['original_question_image_url'];
          final solutionImageUrl = tq['original_solution_image_url'];

          if (questionImageUrl != null &&
              questionImageUrl is String &&
              questionImageUrl.isNotEmpty) {
            try {
              print(
                '🖼️ Downloading test question image for TQ ${tq['id']}...',
              );
              final imagePath = await _downloadImage(
                questionImageUrl,
                'test_question_${tq['id']}',
              );
              if (imagePath != null) {
                downloadedImages['test_question_${tq['id']}'] = {
                  'path': imagePath,
                  'original_url': questionImageUrl,
                  'type': 'test_question',
                };
                tq['local_question_image_path'] = imagePath;
                downloadedImagesCount++;

                // Update progress
                if (totalImages > 0) {
                  setState(() {
                    downloadProgress[course.id] =
                        0.55 + (0.30 * (downloadedImagesCount / totalImages));
                  });
                }
              }
            } catch (e) {
              print(
                '⚠️ Error downloading test question image for ${tq['id']}: $e',
              );
            }
          }

          if (solutionImageUrl != null &&
              solutionImageUrl is String &&
              solutionImageUrl.isNotEmpty) {
            try {
              print(
                '🖼️ Downloading test question solution image for TQ ${tq['id']}...',
              );
              final imagePath = await _downloadImage(
                solutionImageUrl,
                'test_question_solution_${tq['id']}',
              );
              if (imagePath != null) {
                downloadedImages['test_question_solution_${tq['id']}'] = {
                  'path': imagePath,
                  'original_url': solutionImageUrl,
                  'type': 'test_question_solution',
                };
                tq['local_solution_image_path'] = imagePath;
                downloadedImagesCount++;

                // Update progress
                if (totalImages > 0) {
                  setState(() {
                    downloadProgress[course.id] =
                        0.55 + (0.30 * (downloadedImagesCount / totalImages));
                  });
                }
              }
            } catch (e) {
              print(
                '⚠️ Error downloading test question solution image for ${tq['id']}: $e',
              );
            }
          }
        }
      }

      courseData['downloaded_images'] = downloadedImages;

      // Update progress
      setState(() {
        downloadProgress[course.id] = 0.85;
      });

      // Save to Hive
      final offlineBox = await Hive.openBox(offlineCoursesBox);

      // Save course data as JSON
      await offlineBox.put('course_${course.id}', courseData);

      // Update downloaded courses list
      final downloadedCourseIds = offlineBox.get(
        'downloaded_course_ids',
        defaultValue: <String>[],
      );
      if (!downloadedCourseIds.contains(course.id)) {
        downloadedCourseIds.add(course.id);
        await offlineBox.put('downloaded_course_ids', downloadedCourseIds);
      }

      // Save user-course relationship
      final userOfflineBox = await Hive.openBox(userOfflineDataBox);
      final userCourses = userOfflineBox.get(
        'user_${userId}_courses',
        defaultValue: <String>[],
      );
      if (!userCourses.contains(course.id)) {
        userCourses.add(course.id);
        await userOfflineBox.put('user_${userId}_courses', userCourses);
      }

      // Save user profile if not already saved
      if (_currentUserProfile != null) {
        await userOfflineBox.put(
          'user_${userId}_profile',
          _currentUserProfile!.toJson(),
        );
        // Also update cache
        await _saveUserProfileToCache(_currentUserProfile!);
      }

      // Update progress and UI
      setState(() {
        downloadProgress[course.id] = 1.0;
        isCourseDownloaded[course.id] = true;
      });

      // Update the course in the list
      final index = allCourses.indexWhere((c) => c.id == course.id);
      if (index != -1) {
        allCourses[index] = allCourses[index].copyWith(
          isDownloaded: true,
          downloadDate: DateTime.now(),
          localImagePath: courseData['local_image_path'] as String?,
        );
      }

      print('✅ Course ${course.code} downloaded successfully for offline use');
      print('📊 Downloaded data includes:');
      print('   - ${outlinesJson.length} outlines');
      print('   - ${allTopics.length} topics');

      final pastQuestionsCount = pastQuestionsList.length;
      final testQuestionsCount = testQuestionsList.length;
      final sessionsCount = (courseData['sessions'] is List)
          ? (courseData['sessions'] as List).length
          : 0;

      print('   - $pastQuestionsCount past questions');
      print('   - $testQuestionsCount test questions');
      print('   - $sessionsCount academic sessions');
      print('   - ${downloadedImages.length} images downloaded');
      print('   - Downloaded by user: $userId');

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ ${course.code} downloaded for offline use'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );

      // Wait a bit then reset download state
      await Future.delayed(const Duration(seconds: 1));
    } catch (e) {
      print('❌ Error downloading course: $e');
      print('📋 Stack trace: ${e.toString()}');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Failed to download ${course.code}: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          downloadingCourses[course.id] = false;
          downloadProgress.remove(course.id);
        });
      }
    }
  }

  List<String> _extractImageUrlsFromHtml(String htmlContent) {
    final List<String> imageUrls = [];

    try {
      // Extract images from <img> tags (most reliable)
      final imgTagPattern = RegExp(
        '<img[^>]*src\\s*=\\s*([\'"])([^\'"]*)\\1',
        caseSensitive: false,
      );
      final imgMatches = imgTagPattern.allMatches(htmlContent);

      for (final match in imgMatches) {
        final imageUrl = match.group(2) ?? '';
        if (imageUrl.isNotEmpty && !imageUrl.startsWith('data:')) {
          // Clean the URL
          String cleanUrl = imageUrl.trim();

          // Remove query parameters
          final queryIndex = cleanUrl.indexOf('?');
          if (queryIndex != -1) {
            cleanUrl = cleanUrl.substring(0, queryIndex);
          }

          // Remove fragments
          final fragmentIndex = cleanUrl.indexOf('#');
          if (fragmentIndex != -1) {
            cleanUrl = cleanUrl.substring(0, fragmentIndex);
          }

          if (!imageUrls.contains(cleanUrl)) {
            imageUrls.add(cleanUrl);
            print('📷 Found image URL: $cleanUrl');
          }
        }
      }

      // Additional simple checks for common patterns
      if (htmlContent.contains('uploads/')) {
        // Look for uploads/ patterns (simple substring search)
        final uploadsStart = 'uploads/';
        int startIndex = 0;

        while ((startIndex = htmlContent.indexOf(uploadsStart, startIndex)) !=
            -1) {
          // Find the end of the URL (space, quote, bracket, etc.)
          int endIndex = startIndex + uploadsStart.length;
          while (endIndex < htmlContent.length) {
            final char = htmlContent[endIndex];
            if (char == ' ' ||
                char == '"' ||
                char == "'" ||
                char == '>' ||
                char == '<') {
              break;
            }
            endIndex++;
          }

          if (endIndex > startIndex + uploadsStart.length) {
            final url = htmlContent.substring(startIndex, endIndex);
            // Check if it ends with an image extension
            if (_isImageUrl(url) && !imageUrls.contains(url)) {
              imageUrls.add(url);
              print('📷 Found uploads image: $url');
            }
          }

          startIndex = endIndex;
        }
      }

      // Check for media/ patterns
      if (htmlContent.contains('media/')) {
        final mediaStart = 'media/';
        int startIndex = 0;

        while ((startIndex = htmlContent.indexOf(mediaStart, startIndex)) !=
            -1) {
          int endIndex = startIndex + mediaStart.length;
          while (endIndex < htmlContent.length) {
            final char = htmlContent[endIndex];
            if (char == ' ' ||
                char == '"' ||
                char == "'" ||
                char == '>' ||
                char == '<') {
              break;
            }
            endIndex++;
          }

          if (endIndex > startIndex + mediaStart.length) {
            final url = htmlContent.substring(startIndex, endIndex);
            if (_isImageUrl(url) && !imageUrls.contains(url)) {
              imageUrls.add(url);
              print('📷 Found media image: $url');
            }
          }

          startIndex = endIndex;
        }
      }

      print('📊 Extracted ${imageUrls.length} images from HTML');
    } catch (e) {
      print('❌ Error extracting image URLs from HTML: $e');
    }

    return imageUrls;
  }

  bool _isImageUrl(String url) {
    // Check if URL ends with an image extension
    final lowerUrl = url.toLowerCase();
    return lowerUrl.endsWith('.jpg') ||
        lowerUrl.endsWith('.jpeg') ||
        lowerUrl.endsWith('.png') ||
        lowerUrl.endsWith('.gif') ||
        lowerUrl.endsWith('.bmp') ||
        lowerUrl.endsWith('.webp') ||
        lowerUrl.endsWith('.svg');
  }

  Future<String?> _downloadImage(String imageUrl, String fileName) async {
    try {
      // Skip if empty URL
      if (imageUrl.isEmpty) {
        print('⚠️ Skipping empty image URL');
        return null;
      }

      // Convert relative URLs to absolute URLs
      String fullImageUrl = imageUrl;

      if (!imageUrl.startsWith('http://') && !imageUrl.startsWith('https://')) {
        // Handle different relative URL patterns
        if (imageUrl.startsWith('/')) {
          // Django media path starting with /
          fullImageUrl = '${ApiEndpoints.baseUrl}$imageUrl';
        } else if (imageUrl.startsWith('media/')) {
          // Django media path without starting /
          fullImageUrl = '${ApiEndpoints.baseUrl}/$imageUrl';
        } else if (imageUrl.startsWith('uploads/')) {
          // CKEditor uploads path
          fullImageUrl = '${ApiEndpoints.baseUrl}/media/$imageUrl';
        } else if (imageUrl.startsWith('ckeditor/')) {
          // CKEditor path
          fullImageUrl = '${ApiEndpoints.baseUrl}/media/$imageUrl';
        } else {
          // Assume it's a relative path
          fullImageUrl = '${ApiEndpoints.baseUrl}/media/$imageUrl';
        }
      }

      // Clean up any double slashes
      fullImageUrl = fullImageUrl.replaceAll('//media/', '/media/');
      if (fullImageUrl.contains(':///')) {
        fullImageUrl = fullImageUrl.replaceAll(':///', '://');
      }

      print('📷 Downloading image: $fullImageUrl');
      print('📷 Original URL: $imageUrl');

      // Check if we're on web platform
      if (kIsWeb) {
        print('🌐 Web platform - storing image data in Hive');

        try {
          // For web, download the image as bytes and store in Hive
          final response = await _dio.get(
            fullImageUrl,
            options: Options(responseType: ResponseType.bytes),
          );

          if (response.statusCode == 200 && response.data != null) {
            // Generate a unique key for the image
            final imageKey =
                'image_${DateTime.now().millisecondsSinceEpoch}_${fileName.hashCode}';

            // Store image bytes in Hive
            final imageBox = await Hive.openBox('offline_images');
            await imageBox.put(imageKey, {
              'data': response.data,
              'url': imageUrl, // Store original URL for reference
              'full_url': fullImageUrl,
              'filename': fileName,
              'timestamp': DateTime.now().toIso8601String(),
            });

            print('✅ Image stored in Hive with key: $imageKey');

            // Return a special format to identify Hive-stored images
            return 'hive://$imageKey';
          } else {
            print('⚠️ Failed to download image: HTTP ${response.statusCode}');
            return null;
          }
        } catch (e) {
          print('⚠️ Error downloading image on web: $e');
          // On web, if we can't download, return the URL as fallback
          return fullImageUrl;
        }
      }

      // For mobile/desktop: Save to file system
      try {
        final appDir = await getApplicationDocumentsDirectory();
        final imagesDir = Directory('${appDir.path}/offline_images');
        if (!await imagesDir.exists()) {
          await imagesDir.create(recursive: true);
        }

        // Clean filename
        final cleanFileName = fileName
            .replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_')
            .replaceAll(RegExp(r'_+'), '_')
            .trim();

        // Get file extension
        String fileExtension = 'jpg';
        final urlWithoutQuery = fullImageUrl.split('?').first;
        final extensionMatch = RegExp(
          r'\.([a-zA-Z0-9]+)$',
        ).firstMatch(urlWithoutQuery);
        if (extensionMatch != null && extensionMatch.group(1)!.length <= 4) {
          fileExtension = extensionMatch.group(1)!;
        }

        final filePath =
            '${imagesDir.path}/${cleanFileName}_${DateTime.now().millisecondsSinceEpoch}.$fileExtension';

        // Download the file
        await _dio.download(
          fullImageUrl,
          filePath,
          onReceiveProgress: (received, total) {
            if (total != -1) {
              final progress = received / total;
              if (progress % 0.1 < 0.01) {
                // Log every 10%
                print(
                  '   Image download: ${(progress * 100).toStringAsFixed(0)}%',
                );
              }
            }
          },
        );

        // Verify file was created
        final file = File(filePath);
        if (await file.exists()) {
          final fileSize = await file.length();
          print(
            '✅ Image saved: $filePath (${(fileSize / 1024).toStringAsFixed(1)} KB)',
          );
          return filePath;
        } else {
          print('⚠️ File was not created: $filePath');
          return null;
        }
      } catch (e) {
        print('❌ Error saving image to file: $e');

        // Check if it's a MissingPluginException (might be in test environment)
        if (e.toString().contains('MissingPluginException')) {
          print('⚠️ Platform not fully supported, using URL as fallback');
          return fullImageUrl;
        }

        return null;
      }
    } catch (e) {
      print('❌ Error in _downloadImage: $e');
      print('   Image URL: $imageUrl');
      return null;
    }
  }

  Widget _loadImageFromAnySource(String? source, {BoxFit fit = BoxFit.cover}) {
    if (source == null || source.isEmpty) {
      return Container(
        color: Colors.grey.shade200,
        child: const Icon(Icons.image, color: Colors.grey),
      );
    }

    // Check if it's a Hive-stored image (web)
    if (source.startsWith('hive://')) {
      final imageKey = source.replaceFirst('hive://', '');
      return FutureBuilder(
        future: _loadHiveImage(imageKey),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Container(
              color: Colors.grey.shade200,
              child: const CircularProgressIndicator(),
            );
          } else if (snapshot.hasError || snapshot.data == null) {
            return Container(
              color: Colors.grey.shade200,
              child: const Icon(Icons.broken_image, color: Colors.grey),
            );
          } else {
            return Image.memory(
              snapshot.data!,
              fit: fit,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  color: Colors.grey.shade200,
                  child: const Icon(Icons.broken_image, color: Colors.grey),
                );
              },
            );
          }
        },
      );
    }

    // Check if it's a local file path
    if (source.startsWith('/') && !source.startsWith('http')) {
      return Image.file(
        File(source),
        fit: fit,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            color: Colors.grey.shade200,
            child: const Icon(Icons.broken_image, color: Colors.grey),
          );
        },
      );
    }

    // It's a network URL
    return CachedNetworkImage(
      imageUrl: source.startsWith('http')
          ? source
          : '${ApiEndpoints.baseUrl}${source.startsWith('/') ? '' : '/'}$source',
      fit: fit,
      placeholder: (context, url) => Container(
        color: Colors.grey.shade200,
        child: const CircularProgressIndicator(),
      ),
      errorWidget: (context, url, error) => Container(
        color: Colors.grey.shade200,
        child: const Icon(Icons.broken_image, color: Colors.grey),
      ),
    );
  }

  Future<Uint8List?> _loadHiveImage(String imageKey) async {
    try {
      final imageBox = await Hive.openBox('offline_images');
      final imageData = imageBox.get(imageKey);

      if (imageData != null && imageData['data'] != null) {
        return Uint8List.fromList(List<int>.from(imageData['data']));
      }
      return null;
    } catch (e) {
      print('❌ Error loading Hive image: $e');
      return null;
    }
  }

  // Future<void> _deleteDownloadedCourse(Course course) async {
  //   try {
  //     final offlineBox = await Hive.openBox(offlineCoursesBox);

  //     final courseData = offlineBox.get('course_${course.id}');
  //     if (courseData != null) {
  //       // Delete all downloaded images
  //       if (courseData['downloaded_images'] != null) {
  //         final images = Map<String, String>.from(
  //           courseData['downloaded_images'],
  //         );

  //         for (final imagePath in images.values) {
  //           try {
  //             final file = File(imagePath);
  //             if (await file.exists()) {
  //               await file.delete();
  //               print('🗑️ Deleted image: $imagePath');
  //             }
  //           } catch (e) {
  //             print('⚠️ Could not delete image $imagePath: $e');
  //           }
  //         }
  //       }
  //     }

  //     await offlineBox.delete('course_${course.id}');

  //     final downloadedCourseIds = offlineBox.get(
  //       'downloaded_course_ids',
  //       defaultValue: <String>[],
  //     );
  //     downloadedCourseIds.remove(course.id);
  //     await offlineBox.put('downloaded_course_ids', downloadedCourseIds);

  //     final userData = await _apiService.getCurrentUser();
  //     if (userData != null) {
  //       final userId = userData['id'].toString();
  //       final userOfflineBox = await Hive.openBox(userOfflineDataBox);
  //       final userCourses = userOfflineBox.get(
  //         'user_${userId}_courses',
  //         defaultValue: <String>[],
  //       );
  //       userCourses.remove(course.id);
  //       await userOfflineBox.put('user_${userId}_courses', userCourses);
  //     }

  //     setState(() {
  //       isCourseDownloaded[course.id] = false;

  //       final index = allCourses.indexWhere((c) => c.id == course.id);
  //       if (index != -1) {
  //         allCourses[index] = allCourses[index].copyWith(
  //           isDownloaded: false,
  //           downloadDate: null,
  //           localImagePath: null,
  //         );
  //       }
  //     });

  //     ScaffoldMessenger.of(context).showSnackBar(
  //       const SnackBar(
  //         content: Text('🗑️ Course removed from offline storage'),
  //         backgroundColor: Colors.orange,
  //         duration: Duration(seconds: 2),
  //       ),
  //     );

  //     print('🗑️ Course ${course.code} deleted from offline storage');
  //   } catch (e) {
  //     print('❌ Error deleting downloaded course: $e');

  //     ScaffoldMessenger.of(context).showSnackBar(
  //       SnackBar(
  //         content: Text('❌ Failed to remove ${course.code}'),
  //         backgroundColor: Colors.red,
  //         duration: const Duration(seconds: 2),
  //       ),
  //     );
  //   }
  // }

  Future<void> _deleteDownloadedCourse(Course course) async {
    try {
      print(
        '🗑️ Starting deletion of course: ${course.code} (ID: ${course.id})',
      );

      final offlineBox = await Hive.openBox(offlineCoursesBox);
      final userOfflineBox = await Hive.openBox(userOfflineDataBox);

      // Get the course data first to check what needs to be deleted
      final courseData = offlineBox.get('course_${course.id}');

      if (courseData != null) {
        print('📦 Found course data in Hive');

        // Delete downloaded images from Hive (for web platform)
        if (kIsWeb) {
          try {
            final downloadedImages =
                courseData['downloaded_images'] as Map<String, dynamic>?;
            if (downloadedImages != null) {
              print(
                '🖼️ Deleting ${downloadedImages.length} images from Hive...',
              );

              final imageBox = await Hive.openBox('offline_images');
              for (final entry in downloadedImages.entries) {
                final imageInfo = entry.value as Map<String, dynamic>;
                final imagePath = imageInfo['path'] as String?;

                if (imagePath != null && imagePath.startsWith('hive://')) {
                  final imageKey = imagePath.replaceFirst('hive://', '');
                  await imageBox.delete(imageKey);
                  print('   Deleted Hive image: $imageKey');
                }
              }
            }
          } catch (e) {
            print('⚠️ Error deleting images from Hive: $e');
          }
        } else {
          // Delete downloaded images from file system (for mobile/desktop)
          if (courseData['downloaded_images'] != null) {
            try {
              final images = Map<String, dynamic>.from(
                courseData['downloaded_images'],
              );
              print('🖼️ Deleting ${images.length} images from file system...');

              for (final entry in images.entries) {
                final imageInfo = entry.value as Map<String, dynamic>;
                final imagePath = imageInfo['path'] as String?;

                if (imagePath != null && imagePath.startsWith('/')) {
                  try {
                    final file = File(imagePath);
                    if (await file.exists()) {
                      await file.delete();
                      print('   Deleted file: $imagePath');
                    }
                  } catch (e) {
                    print('⚠️ Could not delete image $imagePath: $e');
                  }
                }
              }
            } catch (e) {
              print('⚠️ Error processing downloaded images: $e');
            }
          }
        }

        // Delete the course data from Hive
        await offlineBox.delete('course_${course.id}');
        print('✅ Deleted course data from Hive');
      } else {
        print('⚠️ No course data found in Hive for course ${course.id}');
      }

      // Update downloaded courses list
      final downloadedCourseIds = offlineBox.get(
        'downloaded_course_ids',
        defaultValue: <String>[],
      );

      final originalCount = downloadedCourseIds.length;
      downloadedCourseIds.remove(course.id);
      final newCount = downloadedCourseIds.length;

      if (originalCount != newCount) {
        await offlineBox.put('downloaded_course_ids', downloadedCourseIds);
        print('✅ Updated downloaded_course_ids: removed course ${course.id}');
      } else {
        print('⚠️ Course ${course.id} was not in downloaded_course_ids list');
      }

      // Remove user-course relationship
      final userData = await _apiService.getCurrentUser();
      if (userData != null) {
        final userId = userData['id'].toString();

        // Remove from user-specific courses list
        final userCourses = userOfflineBox.get(
          'user_${userId}_courses',
          defaultValue: <String>[],
        );

        final userOriginalCount = userCourses.length;
        userCourses.remove(course.id);
        final userNewCount = userCourses.length;

        if (userOriginalCount != userNewCount) {
          await userOfflineBox.put('user_${userId}_courses', userCourses);
          print('✅ Removed course from user_${userId}_courses');
        }

        // Also delete any user-specific course data
        await userOfflineBox.delete('user_${userId}_course_${course.id}');

        // Clean up any orphaned user data
        await _cleanupOrphanedUserData(userId);
      }

      // Clean up any cached data for this course
      await _cleanupCachedCourseData(course.id);

      // Update UI state
      if (mounted) {
        setState(() {
          // Remove download status
          isCourseDownloaded.remove(course.id);
          downloadingCourses.remove(course.id);
          downloadProgress.remove(course.id);

          // Update the course in the list
          final index = allCourses.indexWhere((c) => c.id == course.id);
          if (index != -1) {
            allCourses[index] = allCourses[index].copyWith(
              isDownloaded: false,
              downloadDate: null,
              localImagePath: null,
            );
          }

          // Also update filtered courses
          final filteredIndex = filteredCourses.indexWhere(
            (c) => c.id == course.id,
          );
          if (filteredIndex != -1) {
            filteredCourses[filteredIndex] = filteredCourses[filteredIndex]
                .copyWith(
                  isDownloaded: false,
                  downloadDate: null,
                  localImagePath: null,
                );
          }
        });
      }

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('🗑️ "${course.code}" removed from offline storage'),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 2),
        ),
      );

      print(
        '✅ Course ${course.code} successfully deleted from offline storage',
      );
    } catch (e) {
      print('❌ Error deleting downloaded course: $e');
      print('📋 Stack trace: $e');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Failed to remove ${course.code}: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _cleanupOrphanedUserData(String userId) async {
    try {
      final userOfflineBox = await Hive.openBox(userOfflineDataBox);

      // Check if user has any courses left
      final userCourses = userOfflineBox.get(
        'user_${userId}_courses',
        defaultValue: <String>[],
      );

      if (userCourses.isEmpty) {
        print(
          '🧹 User $userId has no downloaded courses, cleaning up orphaned data...',
        );

        // Remove user profile if no courses left
        await userOfflineBox.delete('user_${userId}_profile');
        print('   Removed orphaned user profile');

        // You could also clean up other user-specific data here
      }
    } catch (e) {
      print('⚠️ Error cleaning up orphaned user data: $e');
    }
  }

  Future<void> _cleanupCachedCourseData(String courseId) async {
    try {
      print('🧹 Cleaning up cached data for course $courseId');

      // Clean up from various cache boxes
      final boxesToClean = [
        'courses_cache',
        'course_outlines_cache',
        'course_topics_cache',
        'course_progress',
      ];

      for (final boxName in boxesToClean) {
        try {
          final box = await Hive.openBox(boxName);
          final keys = box.keys.toList();

          for (final key in keys) {
            final keyStr = key.toString();
            if (keyStr.contains(courseId)) {
              await box.delete(key);
              print('   Deleted from $boxName: $keyStr');
            }
          }

          // Also try deleting with common patterns
          final patterns = [
            'course_$courseId',
            'outlines_$courseId',
            'topics_$courseId',
            courseId, // The ID itself
          ];

          for (final pattern in patterns) {
            if (box.containsKey(pattern)) {
              await box.delete(pattern);
              print('   Deleted pattern from $boxName: $pattern');
            }
          }

          await box.close();
        } catch (e) {
          print('⚠️ Error cleaning up $boxName: $e');
        }
      }

      print('✅ Successfully cleaned up cached data for course $courseId');
    } catch (e) {
      print('❌ Error in _cleanupCachedCourseData: $e');
    }
  }

  Future<void> _cleanupInvalidDownloads() async {
    try {
      final userData = await _apiService.getCurrentUser();
      if (userData == null) return;

      final userId = userData['id'].toString();
      final offlineBox = await Hive.openBox(offlineCoursesBox);
      final userOfflineBox = await Hive.openBox(userOfflineDataBox);

      final profileData = userOfflineBox.get('user_${userId}_profile');
      UserProfile? storedProfile;
      if (profileData != null) {
        storedProfile = UserProfile.fromJson(
          Map<String, dynamic>.from(profileData),
        );
      }

      final userCourses = userOfflineBox.get(
        'user_${userId}_courses',
        defaultValue: <String>[],
      );
      final downloadedCourseIds = offlineBox.get(
        'downloaded_course_ids',
        defaultValue: <String>[],
      );

      final coursesToRemove = <String>[];

      for (var courseId in userCourses) {
        try {
          final userSpecificKey = 'user_${userId}_course_${courseId}';
          final courseData =
              offlineBox.get(userSpecificKey) ??
              offlineBox.get('course_$courseId');

          if (courseData != null) {
            if (_currentUserProfile != null &&
                _currentUserProfile!.departmentId.isNotEmpty) {
              final downloadRecordJson = courseData['download_record'];
              if (downloadRecordJson != null) {
                final downloadRecord = DownloadRecord.fromJson(
                  Map<String, dynamic>.from(downloadRecordJson),
                );

                // Check if downloaded for different department
                if (downloadRecord.userProfile != null &&
                    downloadRecord.userProfile!.departmentId !=
                        _currentUserProfile!.departmentId) {
                  print(
                    '🗑️ Removing download from different department: $courseId',
                  );
                  coursesToRemove.add(courseId);
                }
              }
            }
          }
        } catch (e) {
          print('⚠️ Error checking course $courseId: $e');
        }
      }

      for (var courseId in coursesToRemove) {
        offlineBox.delete('user_${userId}_course_$courseId');
        offlineBox.delete('course_$courseId');

        userCourses.remove(courseId);
        downloadedCourseIds.remove(courseId);

        final courseData = offlineBox.get('course_$courseId');
        if (courseData != null && courseData['downloaded_images'] != null) {
          final images = Map<String, String>.from(
            courseData['downloaded_images'],
          );
          for (final imagePath in images.values) {
            try {
              final file = File(imagePath);
              if (await file.exists()) {
                await file.delete();
              }
            } catch (e) {
              print('⚠️ Could not delete image: $e');
            }
          }
        }
      }

      await userOfflineBox.put('user_${userId}_courses', userCourses);
      await offlineBox.put('downloaded_course_ids', downloadedCourseIds);

      print('✅ Cleaned up ${coursesToRemove.length} invalid downloads');
    } catch (e) {
      print('❌ Error cleaning up downloads: $e');
    }
  }

  Future<void> _clearUserDownloads() async {
    try {
      final userData = await _apiService.getCurrentUser();
      if (userData != null) {
        final userId = userData['id'].toString();
        final offlineBox = await Hive.openBox(offlineCoursesBox);
        final userOfflineBox = await Hive.openBox(userOfflineDataBox);

        final userCourses = userOfflineBox.get(
          'user_${userId}_courses',
          defaultValue: <String>[],
        );

        for (var courseId in userCourses) {
          offlineBox.delete('user_${userId}_course_$courseId');
          offlineBox.delete('course_$courseId');

          final courseData = offlineBox.get('course_$courseId');
          if (courseData != null && courseData['downloaded_images'] != null) {
            final images = Map<String, String>.from(
              courseData['downloaded_images'],
            );
            for (final imagePath in images.values) {
              try {
                final file = File(imagePath);
                if (await file.exists()) {
                  await file.delete();
                }
              } catch (e) {
                print('⚠️ Could not delete image: $e');
              }
            }
          }
        }

        await userOfflineBox.delete('user_${userId}_courses');
        await userOfflineBox.delete('user_${userId}_profile');

        final downloadedCourseIds = offlineBox.get(
          'downloaded_course_ids',
          defaultValue: <String>[],
        );
        for (var courseId in userCourses) {
          downloadedCourseIds.remove(courseId);
        }
        await offlineBox.put('downloaded_course_ids', downloadedCourseIds);

        print('✅ Cleared all downloads for user $userId');
      }
    } catch (e) {
      print('❌ Error clearing user downloads: $e');
    }
  }

  // Refresh courses
  Future<void> _refreshCourses() async {
    print('🔄 Manual refresh triggered');
    await _loadCourses();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _unfocusSearch,
      child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: _pageBackground,
        appBar: CustomAppBar(
          scaffoldKey: _scaffoldKey,
          title: 'Courses',
          showNotifications: false,
          showProfile: true,
        ),
        drawer: const CustomDrawer(),
        body: RefreshIndicator(
          onRefresh: _refreshCourses,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Search Bar
                _buildSearchBar(),

                // Activation Status Banner
                if (!_isUserActivated && !_checkingActivation)
                  _buildActivationBanner(),

                // Advert Board
                _buildAdvertBoard(),

                // Loading state
                if (isLoading) _buildLoadingState(),

                // Error state
                if (hasError && !isLoading) _buildErrorState(),

                // Recent Course Section
                if (!isLoading && !hasError && recentCourse != null)
                  _buildRecentCourse(recentCourse!),

                // All Courses Section
                if (!isLoading && !hasError) _buildAllCoursesSection(),

                // Empty state
                if (!isLoading && !hasError && allCourses.isEmpty)
                  _buildEmptyState(),

                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
      decoration: BoxDecoration(
        color: _surfaceColor,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: _borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: _isDark ? 0.18 : 0.10),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.search_rounded, size: 24, color: Color(0xFF667eea)),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: _searchController,
              focusNode: _searchFocusNode,
              decoration: const InputDecoration(
                border: InputBorder.none,
                hintText: 'Search for courses...',
                hintStyle: TextStyle(fontSize: 16),
              ),
              style: TextStyle(fontSize: 16, color: _titleColor),
            ),
          ),
          if (_searchController.text.isNotEmpty)
            GestureDetector(
              onTap: _clearSearch,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: _secondarySurfaceColor,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.close_rounded, size: 18, color: _bodyColor),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildActivationBanner() {
    return GestureDetector(
      onTap: () async {
        final result = await Navigator.pushNamed(context, '/activation');
        if (mounted) {
          await _checkActivationStatus();
        }
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
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
                    'Activate your account to unlock all course content and features.',
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

  Widget _buildAdvertBoard() {
    return GestureDetector(
      onTap: () {
        print('Change advert image clicked');
      },
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          image: advertImageUrl != null
              ? DecorationImage(
                  image: AssetImage(advertImageUrl!),
                  fit: BoxFit.cover,
                  colorFilter: ColorFilter.mode(
                    Colors.black.withValues(alpha: 0.3),
                    BlendMode.darken,
                  ),
                )
              : null,
          gradient: advertImageUrl == null
              ? const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                )
              : null,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF667eea).withValues(alpha: 0.3),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        height: 140,
        child: Stack(
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '🎓 Enhance Your Learning',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Discover new courses and advance your skills',
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(
                      Icons.add_photo_alternate_rounded,
                      size: 16,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      'Change promotional image',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
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
              'Loading your courses...',
              style: TextStyle(color: Color(0xFF666666), fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }

  // Widget _buildErrorState() {
  //   return Padding(
  //     padding: const EdgeInsets.all(40),
  //     child: Center(
  //       child: Column(
  //         children: [
  //           const Icon(Icons.error_outline, size: 60, color: Colors.orange),
  //           const SizedBox(height: 20),
  //           Text(
  //             errorMessage,
  //             style: const TextStyle(color: Color(0xFF666666), fontSize: 16),
  //             textAlign: TextAlign.center,
  //           ),
  //           const SizedBox(height: 20),
  //           ElevatedButton(
  //             onPressed: _refreshCourses,
  //             style: ElevatedButton.styleFrom(
  //               backgroundColor: const Color(0xFF667eea),
  //               shape: RoundedRectangleBorder(
  //                 borderRadius: BorderRadius.circular(10),
  //               ),
  //             ),
  //             child: const Text('Retry', style: TextStyle(color: Colors.white)),
  //           ),
  //         ],
  //       ),
  //     ),
  //   );
  // }

  Widget _buildErrorState() {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 60, color: Colors.orange),
            const SizedBox(height: 20),
            Text(
              errorMessage,
              style: TextStyle(color: _bodyColor, fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),

            // Show additional info if offline
            if (errorMessage.contains('offline') ||
                errorMessage.contains('Offline'))
              Column(
                children: [
                  const SizedBox(height: 10),
                  Text(
                    'Your downloaded courses should appear here.',
                    style: TextStyle(color: _bodyColor, fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'User ID: $_currentUserId',
                    style: const TextStyle(
                      color: Color(0xFF999999),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),

            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: _refreshCourses,
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
                const SizedBox(width: 10),
                OutlinedButton(
                  onPressed: () async {
                    await _emergencyDebugHive();
                    await _debugShowDownloadedCourses();
                  },
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFF667eea)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text(
                    'Debug',
                    style: TextStyle(color: Color(0xFF667eea)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    String message;
    if (_currentUserProfile != null &&
        _currentUserProfile!.departmentId.isNotEmpty) {
      message =
          'No courses available for ${_currentUserProfile!.departmentName} at your academic level.';
    } else {
      message = 'No courses found. Please set your academic profile.';
    }

    return Padding(
      padding: const EdgeInsets.all(40),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.menu_book, size: 60, color: Colors.grey[400]),
            const SizedBox(height: 20),
            Text(
              message,
              style: TextStyle(color: _bodyColor, fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            if (_currentUserProfile == null ||
                _currentUserProfile!.departmentId.isEmpty)
              ElevatedButton(
                onPressed: () async {
                  final result = await Navigator.pushNamed(
                    context,
                    '/academic_setup',
                  );
                  if (mounted && result == 'updated') {
                    await _refreshUserProfileInBackground();
                    await _loadCourses();
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF667eea),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text(
                  'Set Academic Profile',
                  style: TextStyle(color: Colors.white),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentCourse(Course course) {
    final isDownloaded = isCourseDownloaded[course.id] ?? false;
    final isDownloading = downloadingCourses[course.id] ?? false;
    final progress = downloadProgress[course.id] ?? 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, 15),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Recent Course',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: _titleColor,
                ),
              ),
            ],
          ),
        ),
        GestureDetector(
          onTap: () => _navigateToCourseDetails(course),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: _surfaceColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _borderColor),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: _isDark ? 0.16 : 0.08),
                  blurRadius: 15,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              children: [
                // Course Icon with download status
                Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            course.color,
                            _darkenColor(course.color, 0.2),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Center(
                        child: Text(
                          course.abbreviation ?? course.code.split(' ')[0],
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                    if (isDownloading)
                      CircularProgressIndicator(
                        value: progress,
                        backgroundColor: Colors.white.withOpacity(0.3),
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    if (isDownloaded && !isDownloading)
                      Positioned(
                        top: -5,
                        right: -5,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.green,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: const Icon(
                            Icons.download_done_rounded,
                            size: 14,
                            color: Colors.white,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 16),
                // Course Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        course.code,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: _titleColor,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        course.title,
                        style: TextStyle(fontSize: 14, color: _bodyColor),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (isDownloaded && !isDownloading)
                        Container(
                          margin: const EdgeInsets.only(top: 4),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: Colors.green.withOpacity(0.3),
                            ),
                          ),
                          child: Text(
                            'Available offline',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.green.shade700,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                // Action buttons and progress
                Column(
                  children: [
                    if (!isDownloaded && !isDownloading)
                      IconButton(
                        onPressed: () => _downloadCourseForOffline(course),
                        icon: const Icon(
                          Icons.download_rounded,
                          size: 24,
                          color: Color(0xFF667eea),
                        ),
                        tooltip: 'Download for offline',
                      )
                    else if (isDownloading)
                      SizedBox(
                        width: 44,
                        height: 44,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            CircularProgressIndicator(
                              value: progress,
                              strokeWidth: 3,
                              valueColor: const AlwaysStoppedAnimation<Color>(
                                Color(0xFF667eea),
                              ),
                            ),
                            Text(
                              '${(progress * 100).toInt()}%',
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      )
                    else if (isDownloaded)
                      PopupMenuButton<String>(
                        onSelected: (value) {
                          if (value == 'delete') {
                            _deleteDownloadedCourse(course);
                          }
                        },
                        itemBuilder: (context) => [
                          PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.delete_outline_rounded,
                                  color: Colors.red,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                const Text('Remove offline'),
                              ],
                            ),
                          ),
                        ],
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.green.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.download_done_rounded,
                            size: 18,
                            color: Colors.green.shade700,
                          ),
                        ),
                      ),
                    const SizedBox(height: 8),
                    const Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 18,
                      color: Color(0xFF667eea),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
      ],
    );
  }

  Widget _buildCircularProgress(int progress) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: _isDark ? _secondarySurfaceColor : const Color(0xFFF0F0F0),
            shape: BoxShape.circle,
          ),
        ),
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: _isDark ? _surfaceColor : Colors.white,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              '$progress%',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: _titleColor,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAllCoursesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(20, 30, 20, 20),
          child: Text(
            'All Courses',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: _titleColor,
            ),
          ),
        ),
        if (filteredCourses.isEmpty)
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              'No courses found matching your search',
              style: TextStyle(color: _bodyColor, fontSize: 16),
              textAlign: TextAlign.center,
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 15),
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 15,
                mainAxisSpacing: 15,
                childAspectRatio: 0.85,
              ),
              itemCount: filteredCourses.length,
              itemBuilder: (context, index) {
                return _buildCourseBox(filteredCourses[index]);
              },
            ),
          ),
      ],
    );
  }

  Widget _buildCourseBox(Course course) {
    final isDownloaded = isCourseDownloaded[course.id] ?? false;
    final isDownloading = downloadingCourses[course.id] ?? false;
    final progress = downloadProgress[course.id] ?? 0.0;

    return GestureDetector(
      onTap: () => _navigateToCourseDetails(course),
      child: Container(
        decoration: BoxDecoration(
          color: course.color,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: _isDark
                ? Colors.white.withValues(alpha: 0.08)
                : course.color.withValues(alpha: 0.16),
          ),
          boxShadow: [
            BoxShadow(
              color: course.color.withValues(alpha: _isDark ? 0.20 : 0.30),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Background pattern
            Positioned(
              top: -15,
              right: -15,
              child: Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  color: (_isDark ? Colors.black : Colors.white).withValues(
                    alpha: _isDark ? 0.18 : 0.20,
                  ),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Positioned(
              bottom: -20,
              left: -20,
              child: Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: (_isDark ? Colors.black : Colors.white).withValues(
                    alpha: _isDark ? 0.14 : 0.15,
                  ),
                  shape: BoxShape.circle,
                ),
              ),
            ),

            // Download button overlay
            Positioned(
              top: 10,
              right: 10,
              child: _buildDownloadButton(
                course,
                isDownloaded,
                isDownloading,
                progress,
              ),
            ),

            // Content
            Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Course Code
                  Text(
                    course.code,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),

                  // Course Title
                  Text(
                    course.title,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),

                  // Progress indicator
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Progress bar
                      Container(
                        height: 6,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(
                            alpha: _isDark ? 0.18 : 0.4,
                          ),
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              flex: course.progress,
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      _darkenColor(course.color, 0.3),
                                      _darkenColor(course.color, 0.1),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 100 - course.progress,
                              child: const SizedBox(),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),
                      // Progress percentage
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Progress',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.white,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            '${course.progress}%',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDownloadButton(
    Course course,
    bool isDownloaded,
    bool isDownloading,
    double progress,
  ) {
    if (isDownloading) {
      return Container(
        width: 36,
        height: 36,
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: (_isDark ? const Color(0xFF101A2B) : Colors.white).withValues(
            alpha: 0.92,
          ),
          shape: BoxShape.circle,
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            CircularProgressIndicator(
              value: progress,
              strokeWidth: 2,
              valueColor: const AlwaysStoppedAnimation<Color>(
                Color(0xFF667eea),
              ),
            ),
            Text(
              '${(progress * 100).toInt()}',
              style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      );
    }

    if (isDownloaded) {
      return PopupMenuButton<String>(
        onSelected: (value) {
          if (value == 'delete') {
            _deleteDownloadedCourse(course);
          }
        },
        itemBuilder: (context) => [
          PopupMenuItem(
            value: 'delete',
            child: Row(
              children: [
                const Icon(
                  Icons.delete_outline_rounded,
                  color: Colors.red,
                  size: 20,
                ),
                const SizedBox(width: 8),
                const Text('Remove offline'),
              ],
            ),
          ),
        ],
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: (_isDark ? const Color(0xFF101A2B) : Colors.white)
                .withValues(alpha: 0.92),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.download_done_rounded,
            size: 16,
            color: Colors.green.shade700,
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: () => _downloadCourseForOffline(course),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: (_isDark ? const Color(0xFF101A2B) : Colors.white).withValues(
            alpha: 0.92,
          ),
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.download_rounded,
          size: 16,
          color: Color(0xFF667eea),
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
