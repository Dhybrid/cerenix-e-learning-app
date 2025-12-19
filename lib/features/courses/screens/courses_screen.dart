// lib/features/courses/screens/courses_screen.dart
import 'dart:io';
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
  bool _checkingActivation = false;
  String _activationStatusMessage = 'Checking activation...';
  
  // Download states
  Map<String, bool> downloadingCourses = {};
  Map<String, double> downloadProgress = {};
  Map<String, bool> isCourseDownloaded = {};
  
  final String? advertImageUrl = 'assets/images/advertboard.jpeg';
  
  // Hive boxes
  static const String recentCourseBox = 'recent_course';
  static const String coursesCacheBox = 'courses_cache';
  static const String activationCacheBox = 'activation_cache';
  static const String offlineCoursesBox = 'offline_courses';
  static const String userOfflineDataBox = 'user_offline_data';
  static const String userProfileBox = 'user_profile_cache';

  // @override
  // void initState() {
  //   super.initState();
  //   filteredCourses = [];
  //   _searchController.addListener(_filterCourses);
  //   _loadInitialData();
  // }

  // Call it in initState:
@override
void initState() {
  super.initState();
  filteredCourses = [];
  _searchController.addListener(_filterCourses);
  
  // Debug Hive immediately
  WidgetsBinding.instance.addPostFrameCallback((_) {
    _emergencyDebugHive();
  });
  
  _loadInitialData();
}

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    print('🚀 Starting initial data load...');
    
    setState(() {
      isLoading = true;
      hasError = false;
      errorMessage = '';
    });
    
    try {
      // Load cached profile first (fast)
      await _loadCachedUserProfile();
      
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
      
    } catch (e) {
      print('❌ Error in initial load: $e');
      setState(() {
        isLoading = false;
        hasError = true;
        errorMessage = 'Failed to load courses. Please check your connection.';
      });
    }
  }

  // Load cached profile from Hive
  Future<void> _loadCachedUserProfile() async {
    try {
      final profileBox = await Hive.openBox(userProfileBox);
      final cachedProfile = profileBox.get('current_user_profile');
      
      if (cachedProfile != null) {
        if (cachedProfile is UserProfile) {
          _currentUserProfile = cachedProfile;
        } else if (cachedProfile is Map<String, dynamic>) {
          _currentUserProfile = UserProfile.fromJson(cachedProfile);
        }
        print('👤 Loaded cached user profile: ${_currentUserProfile?.toString()}');
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

  // Refresh profile in background
  Future<void> _refreshUserProfileInBackground() async {
    try {
      final userData = await _apiService.getCurrentUser();
      if (userData != null) {
        // Extract university info
        String universityId = userData['university_id']?.toString() ?? '';
        String universityName = userData['university_name']?.toString() ?? '';
        if (userData['university'] is Map<String, dynamic>) {
          final university = userData['university'] as Map<String, dynamic>;
          universityId = university['id']?.toString() ?? universityId;
          universityName = university['name']?.toString() ?? universityName;
        }

        // Extract department info
        String departmentId = userData['department_id']?.toString() ?? '';
        String departmentName = userData['department_name']?.toString() ?? '';
        if (userData['department'] is Map<String, dynamic>) {
          final department = userData['department'] as Map<String, dynamic>;
          departmentId = department['id']?.toString() ?? departmentId;
          departmentName = department['name']?.toString() ?? departmentName;
        }

        // Extract level info
        String levelId = userData['level_id']?.toString() ?? '';
        String levelName = userData['level_name']?.toString() ?? '';
        if (userData['level'] is Map<String, dynamic>) {
          final level = userData['level'] as Map<String, dynamic>;
          levelId = level['id']?.toString() ?? levelId;
          levelName = level['name']?.toString() ?? levelName;
        }

        // Extract semester info
        String semesterId = userData['semester_id']?.toString() ?? '';
        String semesterName = userData['semester_name']?.toString() ?? '';
        if (userData['semester'] is Map<String, dynamic>) {
          final semester = userData['semester'] as Map<String, dynamic>;
          semesterId = semester['id']?.toString() ?? semesterId;
          semesterName = semester['name']?.toString() ?? semesterName;
        }

        final newProfile = UserProfile(
          id: userData['id']?.toString() ?? '',
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
        final bool profileChanged = _currentUserProfile == null || 
            !_currentUserProfile!.matches(newProfile) ||
            _currentUserProfile!.departmentId != newProfile.departmentId;
        
        if (profileChanged) {
          _currentUserProfile = newProfile;
          await _saveUserProfileToCache(newProfile);
          print('🔄 User profile updated: ${_currentUserProfile?.toString()}');
          
          // Reload courses with new profile
          if (mounted) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _loadCoursesWithProfile(newProfile);
            });
          }
        }
      }
    } catch (e) {
      print('⚠️ Could not refresh user profile: $e');
    }
  }

  Future<void> _loadCoursesWithProfile(UserProfile profile) async {
    print('📚 Loading courses with profile: ${profile.departmentName} (${profile.departmentId})');
    
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

  Future<void> _loadOnlineCoursesWithProfile(UserProfile profile) async {
    try {
      print('🌐 Fetching courses from API...');
      final courses = await _apiService.getCoursesForUser();
      
      if (courses.isEmpty) {
        print('⚠️ No courses returned from API');
        await _loadCachedOrDownloadedCoursesWithProfile(profile);
        return;
      }
      
      // Filter courses by department AND other academic info
      final filteredCoursesList = _filterCoursesByProfile(courses, profile);
      
      if (filteredCoursesList.isEmpty) {
        print('⚠️ No courses match your department and academic profile');
        setState(() {
          allCourses = [];
          filteredCourses = [];
          isLoading = false;
          hasError = false;
          errorMessage = 'No courses available for your department and academic level.';
        });
        return;
      }
      
      await _loadCoursesProgress(filteredCoursesList);
      final enhancedCourses = await _enhanceCoursesWithDownloadStatus(filteredCoursesList);
      
      setState(() {
        allCourses = enhancedCourses;
        filteredCourses = enhancedCourses;
        isLoading = false;
        hasError = false;
      });
      
      await _cacheCourses(enhancedCourses);
      
      print('✅ Loaded ${enhancedCourses.length} filtered courses for ${profile.departmentName}');
      
    } catch (e) {
      print('⚠️ API error: $e');
      await _loadCachedOrDownloadedCoursesWithProfile(profile);
    }
  }

  // Proper filtering method including department
  // List<Course> _filterCoursesByProfile(List<Course> courses, UserProfile profile) {
  //   return courses.where((course) {
  //     // Check if course matches university, level, and semester
  //     final matchesAcademic = 
  //         course.universityId == profile.universityId &&
  //         course.levelId == profile.levelId &&
  //         course.semesterId == profile.semesterId;
      
  //     if (!matchesAcademic) {
  //       return false;
  //     }
      
  //     // Check if course is for user's department
  //     // departmentsInfo is a list of department mappings
  //     if (course.departmentsInfo.isNotEmpty) {
  //       final bool isForUserDepartment = course.departmentsInfo.any((deptInfo) {
  //         // Check different possible field names
  //         final deptId = deptInfo['department_id']?.toString() ?? 
  //                       deptInfo['id']?.toString() ?? 
  //                       deptInfo['department']?.toString() ?? '';
  //         return deptId == profile.departmentId;
  //       });
        
  //       if (!isForUserDepartment) {
  //         print('⚠️ Course ${course.code} is not for department ${profile.departmentId}');
  //         return false;
  //       }
  //     } else {
  //       // If course has no department info, skip it
  //       print('⚠️ Course ${course.code} has no department info');
  //       return false;
  //     }
      
  //     return true;
  //   }).toList();
  // }
  // Proper filtering method including department
List<Course> _filterCoursesByProfile(List<Course> courses, UserProfile profile) {
  return courses.where((course) {
    // ONLY CHECK DEPARTMENT - remove university/level/semester checks
    // departmentsInfo is a list of department mappings
    if (course.departmentsInfo.isNotEmpty) {
      final bool isForUserDepartment = course.departmentsInfo.any((deptInfo) {
        // Check different possible field names
        final deptId = deptInfo['department_id']?.toString() ?? 
                      deptInfo['id']?.toString() ?? 
                      deptInfo['department']?.toString() ?? '';
        return deptId == profile.departmentId;
      });
      
      if (!isForUserDepartment) {
        print('⚠️ Course ${course.code} is not for department ${profile.departmentId}');
        return false;
      }
    } else {
      // If course has no department info, skip it
      print('⚠️ Course ${course.code} has no department info');
      return false;
    }
    
    return true;
  }).toList();
}
  // ######################

  Future<void> _loadOfflineCoursesWithProfile(UserProfile profile) async {
    print('📴 Loading offline courses for ${profile.departmentName}');
    await _loadCachedOrDownloadedCoursesWithProfile(profile);
  }

  // Future<void> _loadCachedOrDownloadedCoursesWithProfile(UserProfile profile) async {
  //   try {
  //     // Try cached courses first
  //     final cachedCourses = await _loadCachedCourses();
      
  //     if (cachedCourses.isNotEmpty) {
  //       print('📂 Found ${cachedCourses.length} cached courses');
  //       final filteredCachedCourses = _filterCoursesByProfile(cachedCourses, profile);
        
  //       if (filteredCachedCourses.isNotEmpty) {
  //         print('✅ Filtered to ${filteredCachedCourses.length} cached courses for ${profile.departmentName}');
  //         final enhancedCourses = await _enhanceCoursesWithDownloadStatus(filteredCachedCourses);
          
  //         setState(() {
  //           allCourses = enhancedCourses;
  //           filteredCourses = enhancedCourses;
  //           isLoading = false;
  //           hasError = false;
  //           errorMessage = 'Offline mode: Showing cached courses';
  //         });
  //         return;
  //       }
  //     }
      
  //     // Try downloaded courses
  //     await _loadDownloadedCoursesOnlyWithProfile(profile);
      
  //   } catch (e) {
  //     print('❌ Error loading cached courses: $e');
  //     await _loadDownloadedCoursesOnlyWithProfile(profile);
  //   }
  // }
  Future<void> _loadCachedOrDownloadedCoursesWithProfile(UserProfile profile) async {
  print('🔄 Trying to load courses from cache/downloads...');
  
  try {
    // FIRST: Try downloaded courses directly (skip cached courses)
    print('📥 FIRST: Checking downloaded courses...');
    await _loadDownloadedCoursesOnlyWithProfile(profile);
    
    // If downloaded courses loaded successfully, return
    if (!isLoading && !hasError && allCourses.isNotEmpty) {
      print('✅ Successfully loaded downloaded courses');
      return;
    }
    
    // SECOND: If no downloaded courses, try cached courses
    print('📂 SECOND: No downloaded courses, checking cached courses...');
    final cachedCourses = await _loadCachedCourses();
    
    if (cachedCourses.isNotEmpty) {
      print('📂 Found ${cachedCourses.length} cached courses');
      
      // Filter cached courses by department ONLY (not university/level/semester)
      final filteredCachedCourses = cachedCourses.where((course) {
        if (course.departmentsInfo.isNotEmpty) {
          return course.departmentsInfo.any((deptInfo) {
            final deptId = deptInfo['department_id']?.toString() ?? 
                          deptInfo['id']?.toString() ?? 
                          deptInfo['department']?.toString() ?? '';
            return deptId == profile.departmentId;
          });
        }
        return false;
      }).toList();
      
      if (filteredCachedCourses.isNotEmpty) {
        print('✅ Filtered to ${filteredCachedCourses.length} cached courses for ${profile.departmentName}');
        final enhancedCourses = await _enhanceCoursesWithDownloadStatus(filteredCachedCourses);
        
        setState(() {
          allCourses = enhancedCourses;
          filteredCourses = enhancedCourses;
          isLoading = false;
          hasError = false;
          errorMessage = 'Offline mode: Showing cached courses';
        });
        return;
      }
    }
    
    // THIRD: If we get here, show error
    print('❌ No cached or downloaded courses found');
    setState(() {
      isLoading = false;
      hasError = true;
      errorMessage = 'No courses available offline. Please connect to download courses.';
    });
    
  } catch (e) {
    print('❌ Error loading cached/downloaded courses: $e');
    setState(() {
      isLoading = false;
      hasError = true;
      errorMessage = 'Failed to load offline courses.';
    });
  }
}
  // ######################

  // Future<void> _loadDownloadedCoursesOnlyWithProfile(UserProfile profile) async {
  //   try {
  //     final offlineBox = await Hive.openBox(offlineCoursesBox);
  //     final downloadedCourseIds = offlineBox.get('downloaded_course_ids', defaultValue: <String>[]);
      
  //     print('📥 Found ${downloadedCourseIds.length} downloaded courses');
  //     print('👤 Current user profile for filtering:');
  //     print('   - Department: ${profile.departmentId} (${profile.departmentName})');
  //     print('   - Level: ${profile.levelId} (${profile.levelName})');
  //     print('   - Semester: ${profile.semesterId} (${profile.semesterName})');
  //     print('   - University: ${profile.universityId} (${profile.universityName})');
      
  //     final downloadedCourses = <Course>[];
      
  //     for (var courseId in downloadedCourseIds) {
  //       try {
  //         final courseData = offlineBox.get('course_$courseId');
  //         if (courseData != null && courseData['course'] != null) {
  //           final courseJson = Map<String, dynamic>.from(courseData['course']);
            
  //           // Create course object directly from stored data
  //           Color color;
  //           if (courseJson['color'] is int) {
  //             color = Color(courseJson['color'] as int);
  //           } else if (courseJson['color_value'] is int) {
  //             color = Color(courseJson['color_value'] as int);
  //           } else {
  //             color = Course.generateColorFromCode(courseJson['code']?.toString() ?? '');
  //           }
            
  //           final course = Course(
  //             id: courseJson['id']?.toString() ?? courseId,
  //             code: courseJson['code']?.toString() ?? '',
  //             title: courseJson['title']?.toString() ?? '',
  //             description: courseJson['description']?.toString(),
  //             imageUrl: courseJson['image_url']?.toString(),
  //             abbreviation: courseJson['abbreviation']?.toString(),
  //             creditUnits: courseJson['credit_units'] is int ? courseJson['credit_units'] as int : 0,
  //             universityId: courseJson['university_id']?.toString() ?? '',
  //             universityName: courseJson['university_name']?.toString() ?? '',
  //             levelId: courseJson['level_id']?.toString() ?? '',
  //             levelName: courseJson['level_name']?.toString() ?? '',
  //             semesterId: courseJson['semester_id']?.toString() ?? '',
  //             semesterName: courseJson['semester_name']?.toString() ?? '',
  //             departmentsInfo: courseJson['departments_info'] ?? [],
  //             progress: courseJson['progress'] is int ? courseJson['progress'] as int : 0,
  //             isDownloaded: true,
  //             downloadDate: courseJson['download_date'] != null
  //                 ? DateTime.tryParse(courseJson['download_date'].toString())
  //                 : null,
  //             localImagePath: courseJson['local_image_path']?.toString(),
  //             color: color,
  //           );
            
  //           // Apply academic filters (university, level, semester)
  //           final matchesAcademic = 
  //               course.universityId == profile.universityId &&
  //               course.levelId == profile.levelId &&
  //               course.semesterId == profile.semesterId;
            
  //           if (!matchesAcademic) {
  //             print('⚠️ Course ${course.code} filtered out - academic mismatch');
  //             print('   Course data: University=${course.universityId}, Level=${course.levelId}, Semester=${course.semesterId}');
  //             continue; // Skip this course
  //           }
            
  //           // Apply department filter
  //           bool isForUserDepartment = false;
  //           if (course.departmentsInfo.isNotEmpty) {
  //             isForUserDepartment = course.departmentsInfo.any((deptInfo) {
  //               final deptId = deptInfo['department_id']?.toString() ?? 
  //                             deptInfo['id']?.toString() ?? 
  //                             deptInfo['department']?.toString() ?? '';
  //               return deptId == profile.departmentId;
  //             });
  //           }
            
  //           if (!isForUserDepartment) {
  //             print('⚠️ Course ${course.code} filtered out - department mismatch');
  //             print('   Course departments: ${course.departmentsInfo}');
  //             continue; // Skip this course
  //           }
            
  //           // Load progress from topics if available
  //           final topicsData = courseData['topics'] as List?;
  //           if (topicsData != null && topicsData.isNotEmpty) {
  //             int completedTopics = 0;
  //             for (var topic in topicsData) {
  //               if (topic['user_progress'] != null && 
  //                   topic['user_progress']['is_completed'] == true) {
  //                 completedTopics++;
  //               }
  //             }
  //             course.progress = topicsData.isNotEmpty ? 
  //                 ((completedTopics / topicsData.length) * 100).round() : 0;
  //           }
            
  //           downloadedCourses.add(course);
  //           print('✅ Added downloaded course: ${course.code}');
  //         }
  //       } catch (e) {
  //         print('⚠️ Error loading downloaded course $courseId: $e');
  //       }
  //     }
      
  //     if (downloadedCourses.isNotEmpty) {
  //       print('✅ Loaded ${downloadedCourses.length} downloaded courses for ${profile.departmentName}');
        
  //       setState(() {
  //         allCourses = downloadedCourses;
  //         filteredCourses = downloadedCourses;
  //         isLoading = false;
  //         hasError = false;
  //         errorMessage = 'Offline mode: Showing downloaded courses';
  //       });
  //     } else {
  //       print('⚠️ No downloaded courses match current profile for ${profile.departmentName}');
        
  //       // Debug: Show what was actually downloaded
  //       await _debugShowDownloadedCourses();
        
  //       setState(() {
  //         isLoading = false;
  //         hasError = true;
  //         errorMessage = 'No downloaded courses match your current academic profile. Please connect to download courses for your department.';
  //       });
  //     }
  //   } catch (e) {
  //     print('❌ Error loading downloaded courses: $e');
  //     setState(() {
  //       isLoading = false;
  //       hasError = true;
  //       errorMessage = 'Failed to load courses. Please check your connection.';
  //     });
  //   }
  // }

  Future<void> _loadDownloadedCoursesOnlyWithProfile(UserProfile profile) async {
  print('🔄 SIMPLE OFFLINE LOAD FOR PROFILE: ${profile.departmentId}');
  
  try {
    // 1. Open Hive box
    final offlineBox = await Hive.openBox(offlineCoursesBox);
    
    // 2. Get ALL downloaded course IDs
    final downloadedCourseIds = offlineBox.get('downloaded_course_ids', defaultValue: <String>[]);
    print('📦 Total downloaded courses in Hive: ${downloadedCourseIds.length}');
    
    // 3. If NO courses, show error immediately
    if (downloadedCourseIds.isEmpty) {
      print('❌ Hive is EMPTY - no courses ever downloaded');
      setState(() {
        isLoading = false;
        hasError = true;
        errorMessage = 'No courses downloaded. Please download courses when online.';
      });
      return;
    }
    
    // 4. Show ALL downloaded courses WITHOUT ANY FILTERING
    final downloadedCourses = <Course>[];
    
    for (var courseId in downloadedCourseIds) {
      try {
        final courseData = offlineBox.get('course_$courseId');
        if (courseData != null && courseData['course'] != null) {
          final courseJson = Map<String, dynamic>.from(courseData['course']);
          
          // Create basic course object
          final course = Course(
            id: courseJson['id']?.toString() ?? courseId,
            code: courseJson['code']?.toString() ?? 'Unknown',
            title: courseJson['title']?.toString() ?? 'No Title',
            description: courseJson['description']?.toString(),
            imageUrl: courseJson['image_url']?.toString(),
            abbreviation: courseJson['abbreviation']?.toString(),
            creditUnits: courseJson['credit_units'] is int ? courseJson['credit_units'] as int : 0,
            universityId: courseJson['university_id']?.toString() ?? '',
            universityName: courseJson['university_name']?.toString() ?? '',
            levelId: courseJson['level_id']?.toString() ?? '',
            levelName: courseJson['level_name']?.toString() ?? '',
            semesterId: courseJson['semester_id']?.toString() ?? '',
            semesterName: courseJson['semester_name']?.toString() ?? '',
            departmentsInfo: courseJson['departments_info'] ?? [],
            progress: courseJson['progress'] is int ? courseJson['progress'] as int : 0,
            isDownloaded: true,
            downloadDate: DateTime.now(),
            localImagePath: courseJson['local_image_path']?.toString(),
            color: Course.generateColorFromCode(courseJson['code']?.toString() ?? ''),
          );
          
          downloadedCourses.add(course);
          print('✅ Loaded: ${course.code}');
        }
      } catch (e) {
        print('⚠️ Skipping course $courseId: $e');
      }
    }
    
    // 5. SHOW THEM ALL - NO FILTERING
    if (downloadedCourses.isNotEmpty) {
      print('🎉 SUCCESS: Showing ${downloadedCourses.length} downloaded courses');
      
      setState(() {
        allCourses = downloadedCourses;
        filteredCourses = downloadedCourses;
        isLoading = false;
        hasError = false;
        errorMessage = 'Offline: Showing ALL downloaded courses';
      });
    } else {
      print('❌ Courses found in Hive but couldn\'t load any');
      setState(() {
        isLoading = false;
        hasError = true;
        errorMessage = 'Downloaded courses corrupted. Please re-download.';
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
  // ########################


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
        if (data != null && data['course'] != null) {
          final course = Map<String, dynamic>.from(data['course']);
          print('     Code: ${course['code']}');
          print('     Title: ${course['title']}');
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
      final downloadedCourseIds = offlineBox.get('downloaded_course_ids', defaultValue: <String>[]);
      
      print('🔍 DEBUG: Downloaded course IDs: $downloadedCourseIds');
      
      for (var courseId in downloadedCourseIds) {
        final courseData = offlineBox.get('course_$courseId');
        if (courseData != null && courseData['course'] != null) {
          final courseJson = Map<String, dynamic>.from(courseData['course']);
          print('   - Course $courseId: ${courseJson['code']}');
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

  // Main course loading method
  Future<void> _loadCourses() async {
    print('📚 Loading courses...');
    
    setState(() {
      isLoading = true;
      hasError = false;
      errorMessage = '';
    });
    
    try {
      if (_currentUserProfile == null) {
        print('⚠️ No user profile - loading without filtering');
        await _loadCoursesWithoutProfile();
      } else {
        await _loadCoursesWithProfile(_currentUserProfile!);
      }
    } catch (e) {
      print('❌ Error loading courses: $e');
      setState(() {
        isLoading = false;
        hasError = true;
        errorMessage = 'Failed to load courses. Please check your connection.';
      });
    }
  }

  Future<void> _loadCoursesWithoutProfile() async {
    try {
      final connectivityResult = await _connectivity.checkConnectivity();
      final isConnected = connectivityResult != ConnectivityResult.none;
      
      if (isConnected) {
        final courses = await _apiService.getCoursesForUser();
        
        if (courses.isEmpty) {
          final cachedCourses = await _loadCachedCourses();
          setState(() {
            allCourses = cachedCourses;
            filteredCourses = cachedCourses;
            isLoading = false;
            errorMessage = 'No courses available. Please set your academic profile.';
          });
          return;
        }
        
        await _loadCoursesProgress(courses);
        final enhancedCourses = await _enhanceCoursesWithDownloadStatus(courses);
        
        setState(() {
          allCourses = enhancedCourses;
          filteredCourses = enhancedCourses;
          isLoading = false;
        });
        
        await _cacheCourses(enhancedCourses);
        
      } else {
        final cachedCourses = await _loadCachedCourses();
        if (cachedCourses.isNotEmpty) {
          final enhancedCourses = await _enhanceCoursesWithDownloadStatus(cachedCourses);
          setState(() {
            allCourses = enhancedCourses;
            filteredCourses = enhancedCourses;
            isLoading = false;
            errorMessage = 'Offline mode: Showing all cached courses';
          });
        } else {
          setState(() {
            isLoading = false;
            hasError = true;
            errorMessage = 'No courses available. Please connect to the internet.';
          });
        }
      }
    } catch (e) {
      print('❌ Error loading courses without profile: $e');
      setState(() {
        isLoading = false;
        hasError = true;
        errorMessage = 'Failed to load courses.';
      });
    }
  }

  Future<void> _checkActivationStatus() async {
    try {
      final activationBox = await Hive.openBox(activationCacheBox);
      final cachedActivation = activationBox.get('user_activated');
      
      if (cachedActivation == true) {
        if (mounted) {
          setState(() {
            _isUserActivated = true;
            _activationStatusMessage = 'Activated';
            _checkingActivation = false;
          });
        }
        return;
      }
      
      try {
        final activationData = await ApiService().getActivationStatus();
        
        if (activationData != null && activationData.isValid) {
          await activationBox.put('user_activated', true);
          await activationBox.put('activation_grade', activationData.grade);
          await activationBox.put('activation_timestamp', DateTime.now().toIso8601String());
          
          if (mounted) {
            setState(() {
              _isUserActivated = true;
              _activationStatusMessage = '${activationData.grade?.toUpperCase() ?? 'Activated'}';
              _checkingActivation = false;
            });
          }
        } else {
          await activationBox.put('user_activated', false);
          if (mounted) {
            setState(() {
              _isUserActivated = false;
              _activationStatusMessage = 'Not Activated';
              _checkingActivation = false;
            });
          }
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _isUserActivated = cachedActivation ?? false;
            _activationStatusMessage = _isUserActivated 
                ? 'Activated (offline)' 
                : 'Not Activated (offline)';
            _checkingActivation = false;
          });
        }
      }
    } catch (e) {
      print('❌ Error checking activation: $e');
      if (mounted) {
        setState(() {
          _isUserActivated = false;
          _activationStatusMessage = 'Error checking activation';
          _checkingActivation = false;
        });
      }
    }
  }

  Future<void> _loadRecentCourseFromStorage() async {
    try {
      final box = await Hive.openBox(recentCourseBox);
      final recentData = box.get('recent_course');
      
      if (recentData != null) {
        Course? course;
        
        if (recentData is Map<String, dynamic>) {
          course = Course.fromJson(recentData);
        } else if (recentData is Course) {
          course = recentData;
        }
        
        if (course != null) {
          final isDownloaded = await _isCourseDownloaded(course.id);
          setState(() {
            recentCourse = course;
          });
          print('✅ Loaded recent course: ${course.code} (Downloaded: $isDownloaded)');
        }
      }
    } catch (e) {
      print('❌ Error loading recent course: $e');
    }
  }

  Future<void> _saveRecentCourseToStorage(Course course) async {
    try {
      final box = await Hive.openBox(recentCourseBox);
      await box.put('recent_course', course);
      print('✅ Saved recent course to Hive: ${course.code}');
    } catch (e) {
      print('❌ Error saving recent course to Hive: $e');
      
      try {
        final box = await Hive.openBox(recentCourseBox);
        await box.put('recent_course', course.toJson());
        print('✅ Saved recent course as JSON fallback: ${course.code}');
      } catch (e2) {
        print('❌ JSON fallback also failed: $e2');
      }
    }
  }

  Future<List<Course>> _enhanceCoursesWithDownloadStatus(List<Course> courses) async {
    final enhancedCourses = <Course>[];
    
    try {
      final offlineBox = await Hive.openBox(offlineCoursesBox);
      final downloadedCourseIds = offlineBox.get('downloaded_course_ids', defaultValue: <String>[]);
      
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
      
      if (cachedData != null) {
        if (cachedData is List<Course>) {
          print('✅ Loaded ${cachedData.length} courses as Hive objects');
          return cachedData;
        } else if (cachedData is List) {
          final courses = cachedData.map((json) => Course.fromJson(json)).toList();
          print('✅ Loaded ${courses.length} courses from JSON cache');
          return courses;
        }
      }
    } catch (e) {
      print('❌ Error loading cached courses: $e');
    }
    return [];
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
      final downloadedCourseIds = box.get('downloaded_course_ids', defaultValue: <String>[]);
      
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
      final downloadedCourseIds = box.get('downloaded_course_ids', defaultValue: <String>[]);
      return downloadedCourseIds.contains(courseId);
    } catch (e) {
      return false;
    }
  }

  Future<void> _loadCoursesProgress(List<Course> courses) async {
    try {
      print('📊 Loading progress for ${courses.length} courses...');
      
      final userData = await _apiService.getCurrentUser();
      if (userData == null) {
        print('⚠️ No user data found');
        return;
      }
      
      final userId = userData['id'].toString();
      
      for (var course in courses) {
        try {
          print('📖 Calculating progress for course: ${course.code}');
          
          final topics = await _apiService.getTopics(courseId: int.parse(course.id));
          
          if (topics.isNotEmpty) {
            print('   - Found ${topics.length} topics');
            
            int completedCount = 0;
            
            for (var topic in topics) {
              if (topic.isCompleted) {
                completedCount++;
              }
            }
            
            final progress = topics.isNotEmpty ? ((completedCount / topics.length) * 100).round() : 0;
            course.progress = progress;
            
            print('   - Progress: $progress% ($completedCount/${topics.length} topics)');
            
            await _saveProgress(course.id, progress);
          } else {
            print('   - No topics found for this course');
            final cachedProgress = await _getCachedProgress(course.id);
            course.progress = cachedProgress;
          }
        } catch (e) {
          print('⚠️ Error loading progress for ${course.code}: $e');
          final cachedProgress = await _getCachedProgress(course.id);
          course.progress = cachedProgress;
        }
      }
      
      print('✅ Course progress loading complete');
    } catch (e) {
      print('❌ Error loading course progress: $e');
      for (var course in courses) {
        course.progress = await _getCachedProgress(course.id);
      }
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
        filteredCourses = allCourses.where((course) =>
          course.code.toLowerCase().contains(query) ||
          course.title.toLowerCase().contains(query) ||
          (course.abbreviation?.toLowerCase().contains(query) ?? false)
        ).toList();
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
      arguments: course
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
    final deptId = deptInfo['department_id']?.toString() ?? 
                  deptInfo['id']?.toString() ?? 
                  deptInfo['department']?.toString() ?? '';
    return deptId == _currentUserProfile!.departmentId;
  });

  if (!isForUserDepartment) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('❌ ${course.code} is not available for your department'),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
    return;
  }

  if (downloadingCourses[course.id] == true || isCourseDownloaded[course.id] == true) {
    return;
  }

  setState(() {
    downloadingCourses[course.id] = true;
    downloadProgress[course.id] = 0.0;
  });

  try {
    print('📥 Starting download for course: ${course.code} for department ${_currentUserProfile!.departmentName}');
    
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
      downloadProgress[course.id] = 0.1;
    });
    
    // Step 1: Get course outlines
    final outlines = await _apiService.getCourseOutlines(int.parse(course.id));
    final outlinesJson = outlines.map((outline) => outline.toJson()).toList();
    courseData['outlines'] = outlinesJson;
    
    // Update progress
    setState(() {
      downloadProgress[course.id] = 0.3;
    });
    
    // Step 2: Get topics for each outline
    final allTopics = <Map<String, dynamic>>[];
    for (var outline in outlines) {
      try {
        final topics = await _apiService.getTopics(outlineId: int.parse(outline.id));
        allTopics.addAll(topics.map((topic) => topic.toJson()).toList());
      } catch (e) {
        print('⚠️ Error getting topics for outline ${outline.id}: $e');
      }
    }
    courseData['topics'] = allTopics;
    
    // Update progress
    setState(() {
      downloadProgress[course.id] = 0.5;
    });
    
    // Step 3: Download images
    final downloadedImages = <String, String>{};
    
    // Download course image if exists
    if (course.imageUrl != null && course.imageUrl!.isNotEmpty) {
      try {
        final imagePath = await _downloadImage(course.imageUrl!, 'course_${course.id}');
        if (imagePath != null) {
          downloadedImages['course_image'] = imagePath;
          courseData['local_image_path'] = imagePath;
        }
      } catch (e) {
        print('⚠️ Error downloading course image: $e');
      }
    }
    
    // Download topic images
    int topicImageCount = 0;
    for (var topic in allTopics) {
      if (topic['image'] != null && topic['image'] is String && 
          (topic['image'] as String).isNotEmpty && 
          (topic['image'] as String).startsWith('http')) {
        try {
          final imagePath = await _downloadImage(
            topic['image'] as String, 
            'topic_${topic['id']}_$topicImageCount'
          );
          if (imagePath != null) {
            downloadedImages[topic['id'].toString()] = imagePath;
            topicImageCount++;
          }
        } catch (e) {
          print('⚠️ Error downloading topic image for ${topic['id']}: $e');
        }
      }
    }
    
    courseData['downloaded_images'] = downloadedImages;
    
    // Update progress
    setState(() {
      downloadProgress[course.id] = 0.8;
    });
    
    // Save to Hive
    final offlineBox = await Hive.openBox(offlineCoursesBox);
    
    // Save course data as JSON
    await offlineBox.put('course_${course.id}', courseData);
    
    // Update downloaded courses list
    final downloadedCourseIds = offlineBox.get('downloaded_course_ids', defaultValue: <String>[]);
    if (!downloadedCourseIds.contains(course.id)) {
      downloadedCourseIds.add(course.id);
      await offlineBox.put('downloaded_course_ids', downloadedCourseIds);
    }
    
    // Save user-course relationship
    final userOfflineBox = await Hive.openBox(userOfflineDataBox);
    final userCourses = userOfflineBox.get('user_${userId}_courses', defaultValue: <String>[]);
    if (!userCourses.contains(course.id)) {
      userCourses.add(course.id);
      await userOfflineBox.put('user_${userId}_courses', userCourses);
    }
    
    // Save user profile if not already saved
    if (_currentUserProfile != null) {
      await userOfflineBox.put('user_${userId}_profile', _currentUserProfile!.toJson());
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
    print('   - ${downloadedImages.length} images');
    
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

  Future<String?> _downloadImage(String imageUrl, String fileName) async {
    try {
      if (!imageUrl.startsWith('http')) {
        print('⚠️ Skipping invalid image URL: $imageUrl');
        return null;
      }
      
      final appDir = await getApplicationDocumentsDirectory();
      final imagesDir = Directory('${appDir.path}/offline_images');
      if (!await imagesDir.exists()) {
        await imagesDir.create(recursive: true);
      }
      
      final cleanFileName = fileName.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_');
      final fileExtension = imageUrl.split('.').last.split('?').first;
      final filePath = '${imagesDir.path}/${cleanFileName}_${DateTime.now().millisecondsSinceEpoch}.${fileExtension.length <= 4 ? fileExtension : 'jpg'}';
      
      print('📷 Downloading image: $imageUrl');
      
      await _dio.download(
        imageUrl,
        filePath,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            final progress = received / total;
            print('   Image download progress: ${(progress * 100).toStringAsFixed(1)}%');
          }
        },
      );
      
      print('✅ Image saved to: $filePath');
      return filePath;
    } catch (e) {
      print('❌ Error downloading image: $e');
      return null;
    }
  }

  Future<void> _deleteDownloadedCourse(Course course) async {
    try {
      final offlineBox = await Hive.openBox(offlineCoursesBox);
      
      final courseData = offlineBox.get('course_${course.id}');
      if (courseData != null && courseData['downloaded_images'] != null) {
        final images = Map<String, String>.from(courseData['downloaded_images']);
        
        for (final imagePath in images.values) {
          try {
            final file = File(imagePath);
            if (await file.exists()) {
              await file.delete();
              print('🗑️ Deleted image: $imagePath');
            }
          } catch (e) {
            print('⚠️ Could not delete image $imagePath: $e');
          }
        }
      }
      
      await offlineBox.delete('course_${course.id}');
      
      final downloadedCourseIds = offlineBox.get('downloaded_course_ids', defaultValue: <String>[]);
      downloadedCourseIds.remove(course.id);
      await offlineBox.put('downloaded_course_ids', downloadedCourseIds);
      
      final userData = await _apiService.getCurrentUser();
      if (userData != null) {
        final userId = userData['id'].toString();
        final userOfflineBox = await Hive.openBox(userOfflineDataBox);
        final userCourses = userOfflineBox.get('user_${userId}_courses', defaultValue: <String>[]);
        userCourses.remove(course.id);
        await userOfflineBox.put('user_${userId}_courses', userCourses);
      }
      
      setState(() {
        isCourseDownloaded[course.id] = false;
        
        final index = allCourses.indexWhere((c) => c.id == course.id);
        if (index != -1) {
          allCourses[index] = allCourses[index].copyWith(
            isDownloaded: false,
            downloadDate: null,
            localImagePath: null,
          );
        }
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🗑️ Course removed from offline storage'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 2),
        ),
      );
      
      print('🗑️ Course ${course.code} deleted from offline storage');
    } catch (e) {
      print('❌ Error deleting downloaded course: $e');
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Failed to remove ${course.code}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 2),
        ),
      );
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
        storedProfile = UserProfile.fromJson(Map<String, dynamic>.from(profileData));
      }
      
      final userCourses = userOfflineBox.get('user_${userId}_courses', defaultValue: <String>[]);
      final downloadedCourseIds = offlineBox.get('downloaded_course_ids', defaultValue: <String>[]);
      
      final coursesToRemove = <String>[];
      
      for (var courseId in userCourses) {
        try {
          final userSpecificKey = 'user_${userId}_course_${courseId}';
          final courseData = offlineBox.get(userSpecificKey) ?? offlineBox.get('course_$courseId');
          
          if (courseData != null) {
            if (_currentUserProfile != null && 
                _currentUserProfile!.departmentId.isNotEmpty) {
              
              final downloadRecordJson = courseData['download_record'];
              if (downloadRecordJson != null) {
                final downloadRecord = DownloadRecord.fromJson(
                  Map<String, dynamic>.from(downloadRecordJson)
                );
                
                // Check if downloaded for different department
                if (downloadRecord.userProfile != null &&
                    downloadRecord.userProfile!.departmentId != _currentUserProfile!.departmentId) {
                  print('🗑️ Removing download from different department: $courseId');
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
          final images = Map<String, String>.from(courseData['downloaded_images']);
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
        
        final userCourses = userOfflineBox.get('user_${userId}_courses', defaultValue: <String>[]);
        
        for (var courseId in userCourses) {
          offlineBox.delete('user_${userId}_course_$courseId');
          offlineBox.delete('course_$courseId');
          
          final courseData = offlineBox.get('course_$courseId');
          if (courseData != null && courseData['downloaded_images'] != null) {
            final images = Map<String, String>.from(courseData['downloaded_images']);
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
        
        final downloadedCourseIds = offlineBox.get('downloaded_course_ids', defaultValue: <String>[]);
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
        backgroundColor: const Color(0xFFF8FAFC),
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
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
                hintStyle: TextStyle(
                  color: Color(0xFF999999),
                  fontSize: 16,
                ),
              ),
              style: const TextStyle(fontSize: 16),
            ),
          ),
          if (_searchController.text.isNotEmpty)
            GestureDetector(
              onTap: _clearSearch,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8F9FA),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close_rounded, size: 18, color: Color(0xFF666666)),
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
                    Colors.black.withOpacity(0.3),
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
              color: const Color(0xFF667eea).withOpacity(0.3),
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
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(Icons.add_photo_alternate_rounded, size: 16, color: Colors.white),
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
              style: TextStyle(
                color: Color(0xFF666666),
                fontSize: 16,
              ),
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
              style: const TextStyle(
                color: Color(0xFF666666),
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
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
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    String message;
    if (_currentUserProfile != null && _currentUserProfile!.departmentId.isNotEmpty) {
      message = 'No courses available for ${_currentUserProfile!.departmentName} at your academic level.';
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
              style: const TextStyle(
                color: Color(0xFF666666),
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            if (_currentUserProfile == null || _currentUserProfile!.departmentId.isEmpty)
              ElevatedButton(
                onPressed: () async {
                  final result = await Navigator.pushNamed(context, '/academic_setup');
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
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, 15),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Recent Course',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF333333),
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
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
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
                          colors: [course.color, _darkenColor(course.color, 0.2)],
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
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF333333),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        course.title,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF666666),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (isDownloaded && !isDownloading)
                        Container(
                          margin: const EdgeInsets.only(top: 4),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.green.withOpacity(0.3)),
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
                              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF667eea)),
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
                                const Icon(Icons.delete_outline_rounded, color: Colors.red, size: 20),
                                const SizedBox(width: 8),
                                const Text('Remove offline'),
                              ],
                            ),
                          ),
                        ],
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.1),
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
                    const Icon(Icons.arrow_forward_ios_rounded, 
                         size: 18, 
                         color: Color(0xFF667eea)),
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
            color: const Color(0xFFF0F0F0),
            shape: BoxShape.circle,
          ),
        ),
        Container(
          width: 40,
          height: 40,
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              '$progress%',
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: Color(0xFF333333),
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
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 30, 20, 20),
          child: Text(
            'All Courses',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF333333),
            ),
          ),
        ),
        if (filteredCourses.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              'No courses found matching your search',
              style: TextStyle(
                color: Color(0xFF999999),
                fontSize: 16,
              ),
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
          boxShadow: [
            BoxShadow(
              color: course.color.withOpacity(0.3),
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
                  color: Colors.white.withOpacity(0.2),
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
                  color: Colors.white.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            
            // Download button overlay
            Positioned(
              top: 10,
              right: 10,
              child: _buildDownloadButton(course, isDownloaded, isDownloading, progress),
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
                      color: Color(0xFF333333),
                    ),
                  ),
                  
                  // Course Title
                  Text(
                    course.title,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF333333),
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
                          color: Colors.white.withOpacity(0.4),
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
                                      _darkenColor(course.color, 0.1)
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
                              color: Color(0xFF333333),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            '${course.progress}%',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF333333),
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

  Widget _buildDownloadButton(Course course, bool isDownloaded, bool isDownloading, double progress) {
    if (isDownloading) {
      return Container(
        width: 36,
        height: 36,
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.9),
          shape: BoxShape.circle,
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            CircularProgressIndicator(
              value: progress,
              strokeWidth: 2,
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF667eea)),
            ),
            Text(
              '${(progress * 100).toInt()}',
              style: const TextStyle(
                fontSize: 8,
                fontWeight: FontWeight.bold,
              ),
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
                const Icon(Icons.delete_outline_rounded, color: Colors.red, size: 20),
                const SizedBox(width: 8),
                const Text('Remove offline'),
              ],
            ),
          ),
        ],
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.9),
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
          color: Colors.white.withOpacity(0.9),
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