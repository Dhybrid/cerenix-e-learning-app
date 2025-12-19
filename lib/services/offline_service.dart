// lib/services/offline_service.dart
import 'dart:io';
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:dio/dio.dart';
import '../core/network/api_service.dart';
import '../features/courses/models/course_models.dart';
import '../features/courses/models/course_hive_adapters.dart';

class OfflineService {
  // Singleton instance
  static final OfflineService _instance = OfflineService._internal();
  factory OfflineService() => _instance;
  OfflineService._internal();

  // Hive box names
  static const String offlineCoursesBox = 'offline_courses';
  static const String recentCourseBox = 'recent_course';
  static const String coursesCacheBox = 'courses_cache';
  static const String userDataBox = 'user_data';
  static const String activationCacheBox = 'activation_cache';
  
  // API Service
  final ApiService _apiService = ApiService();
  
  // Dio instance for downloads
  final Dio _dio = Dio(BaseOptions(
    connectTimeout: Duration(seconds: 30),
    receiveTimeout: Duration(seconds: 30),
    sendTimeout: Duration(seconds: 30),
  ));
  
  // Track active downloads
  final Map<String, bool> _activeDownloads = {};
  
  // ==================== INITIALIZATION ====================
  
  // static Future<void> initHive() async {
  //   try {
  //     // Initialize Hive
  //     final appDir = await getApplicationDocumentsDirectory();
  //     Hive.init(appDir.path);
      
  //     // Register adapters
  //     if (!Hive.isAdapterRegistered(1)) {
  //       Hive.registerAdapter(CourseAdapter());
  //     }
  //     if (!Hive.isAdapterRegistered(2)) {
  //       Hive.registerAdapter(CourseOutlineAdapter());
  //     }
  //     if (!Hive.isAdapterRegistered(3)) {
  //       Hive.registerAdapter(TopicAdapter());
  //     }
      
  //     print('✅ Hive initialized successfully');
  //     print('📁 App directory: ${appDir.path}');
  //   } catch (e) {
  //     print('❌ Failed to initialize Hive: $e');
  //     rethrow;
  //   }
  // }

  // Change from static to instance method:
Future<void> initHive() async {  // Remove 'static'
  try {
    print('📝 Registering Hive adapters...');
    
    // Register Course adapters
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(CourseAdapter());
      print('✅ Registered CourseAdapter');
    }
    if (!Hive.isAdapterRegistered(2)) {
      Hive.registerAdapter(CourseOutlineAdapter());
      print('✅ Registered CourseOutlineAdapter');
    }
    if (!Hive.isAdapterRegistered(3)) {
      Hive.registerAdapter(TopicAdapter());
      print('✅ Registered TopicAdapter');
    }
    if (!Hive.isAdapterRegistered(4)) {
      Hive.registerAdapter(ColorAdapter());
      print('✅ Registered ColorAdapter');
    }
    
    print('✅ All adapters registered successfully');
  } catch (e) {
    print('❌ Failed to register Hive adapters: $e');
    rethrow;
  }
}
  
  // ==================== RECENT COURSE MANAGEMENT ====================
  
  /// Get the most recent course accessed by user
  Future<Course?> getRecentCourse() async {
    try {
      final box = await Hive.openBox<Course>(recentCourseBox);
      final recent = box.get('recent_course');
      
      if (recent != null) {
        // Check if still downloaded
        final isDownloaded = await isCourseDownloaded(recent.id);
        recent.isDownloaded = isDownloaded;
        print('✅ Loaded recent course: ${recent.code} (Downloaded: $isDownloaded)');
        return recent;
      }
    } catch (e) {
      print('❌ Error getting recent course: $e');
    }
    return null;
  }
  
  /// Save a course as the most recent one
  Future<void> saveRecentCourse(Course course) async {
    try {
      final box = await Hive.openBox<Course>(recentCourseBox);
      await box.put('recent_course', course);
      print('✅ Saved recent course: ${course.code}');
    } catch (e) {
      print('❌ Error saving recent course: $e');
    }
  }
  
  /// Clear the recent course
  Future<void> clearRecentCourse() async {
    try {
      final box = await Hive.openBox(recentCourseBox);
      await box.clear();
      print('🧹 Cleared recent course');
    } catch (e) {
      print('❌ Error clearing recent course: $e');
    }
  }
  
  // ==================== COURSE DOWNLOAD FUNCTIONALITY ====================
  
  /// Download a course for offline use
  Future<void> downloadCourseForOffline({
    required Course course,
    Function(double progress)? onProgress,
    Function()? onComplete,
    Function(String error)? onError,
  }) async {
    final courseId = course.id;
    
    // Prevent duplicate downloads
    if (_activeDownloads.containsKey(courseId) && _activeDownloads[courseId] == true) {
      print('⚠️ Course $courseId is already downloading');
      return;
    }
    
    // Check if already downloaded
    if (await isCourseDownloaded(courseId)) {
      print('⚠️ Course $courseId is already downloaded');
      onError?.call('Course is already downloaded');
      return;
    }
    
    // Mark as downloading
    _activeDownloads[courseId] = true;
    await _updateDownloadStatus(courseId, 'downloading', 0.0);
    
    print('🚀 Starting download for course: ${course.code} (ID: $courseId)');
    
    try {
      // Step 1: Verify user is logged in
      final userData = await _apiService.getCurrentUser();
      if (userData == null) {
        throw Exception('User not logged in. Please login to download courses.');
      }
      
      final userId = userData['id'].toString();
      onProgress?.call(0.05);
      
      // Step 2: Get course outlines
      print('📋 Fetching course outlines...');
      onProgress?.call(0.1);
      final outlines = await _apiService.getCourseOutlines(int.parse(courseId));
      print('   Found ${outlines.length} outlines');
      
      // Step 3: Get all topics for each outline
      onProgress?.call(0.2);
      print('📚 Fetching topics...');
      final allTopics = <Topic>[];
      for (var i = 0; i < outlines.length; i++) {
        final outline = outlines[i];
        try {
          final topics = await _apiService.getTopics(outlineId: int.parse(outline.id));
          allTopics.addAll(topics);
          print('   - Outline ${i + 1}: ${topics.length} topics');
        } catch (e) {
          print('⚠️ Warning: Could not fetch topics for outline ${outline.id}: $e');
          // Continue with other outlines
        }
        
        // Update progress
        final progress = 0.2 + (i / outlines.length) * 0.3;
        onProgress?.call(progress);
      }
      
      print('📊 Total topics found: ${allTopics.length}');
      onProgress?.call(0.5);
      
      // Step 4: Download course image if exists
      String? localImagePath;
      if (course.imageUrl != null && course.imageUrl!.isNotEmpty && course.imageUrl!.startsWith('http')) {
        print('🖼️ Downloading course image...');
        try {
          localImagePath = await _downloadImage(
            course.imageUrl!, 
            'course_${courseId}_${DateTime.now().millisecondsSinceEpoch}'
          );
          if (localImagePath != null) {
            print('   Course image saved to: $localImagePath');
          }
        } catch (e) {
          print('⚠️ Could not download course image: $e');
          // Continue without image
        }
      }
      onProgress?.call(0.6);
      
      // Step 5: Download topic images (optional, don't fail if images fail)
      final downloadedImages = <String, String>{};
      if (allTopics.isNotEmpty) {
        print('🖼️ Downloading topic images (if any)...');
        for (var i = 0; i < allTopics.length; i++) {
          final topic = allTopics[i];
          final topicImage = topic.image ?? topic.displayImageUrl;
          
          if (topicImage != null && topicImage.isNotEmpty && topicImage.startsWith('http')) {
            try {
              final imagePath = await _downloadImage(
                topicImage,
                'topic_${topic.id}_${DateTime.now().millisecondsSinceEpoch}'
              );
              if (imagePath != null) {
                downloadedImages[topic.id] = imagePath;
              }
            } catch (e) {
              print('⚠️ Could not download image for topic ${topic.id}: $e');
            }
          }
          
          // Update progress
          final progress = 0.6 + (i / allTopics.length) * 0.3;
          onProgress?.call(progress);
        }
      }
      
      print('📸 Downloaded ${downloadedImages.length} topic images');
      onProgress?.call(0.9);
      
      // Step 6: Prepare course data with downloaded flag
      final downloadedCourse = Course(
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
        isDownloaded: true,
        downloadDate: DateTime.now(),
        localImagePath: localImagePath,
        color: course.color,
      );
      
      // Step 7: Save everything to Hive
      print('💾 Saving to offline storage...');
      final offlineBox = await Hive.openBox(offlineCoursesBox);
      
      // Create comprehensive offline data structure
      final offlineData = {
        'course': downloadedCourse.toJson(),
        'outlines': outlines.map((o) => o.toJson()).toList(),
        'topics': allTopics.map((t) => t.toJson()).toList(),
        'images': downloadedImages,
        'user_id': userId,
        'download_date': DateTime.now().toIso8601String(),
        'file_size': await _estimateFileSize(downloadedImages, localImagePath),
      };
      
      // Save the data
      await offlineBox.put('course_$courseId', offlineData);
      
      // Update downloaded courses list
      final downloadedIds = offlineBox.get('downloaded_course_ids', defaultValue: <String>[]);
      if (!downloadedIds.contains(courseId)) {
        downloadedIds.add(courseId);
        await offlineBox.put('downloaded_course_ids', downloadedIds);
      }
      
      // Update download status
      await _updateDownloadStatus(courseId, 'downloaded', 1.0);
      
      // Step 8: Update cache with downloaded flag
      await _updateCourseInCache(downloadedCourse);
      
      onProgress?.call(1.0);
      print('✅ Successfully downloaded course: ${course.code}');
      print('   - Outlines: ${outlines.length}');
      print('   - Topics: ${allTopics.length}');
      print('   - Images: ${downloadedImages.length}');
      
      // Notify completion
      onComplete?.call();
      
    } catch (e) {
      print('❌ Failed to download course ${course.code}: $e');
      
      // Update status to failed
      await _updateDownloadStatus(courseId, 'failed', 0.0);
      
      // Notify error
      onError?.call(e.toString());
      
    } finally {
      // Clean up active downloads
      _activeDownloads.remove(courseId);
    }
  }
  
  /// Download a single image
  Future<String?> _downloadImage(String imageUrl, String fileName) async {
    try {
      // Create images directory if it doesn't exist
      final appDir = await getApplicationDocumentsDirectory();
      final imagesDir = Directory('${appDir.path}/offline_images');
      if (!await imagesDir.exists()) {
        await imagesDir.create(recursive: true);
      }
      
      // Generate safe filename
      final cleanFileName = fileName.replaceAll(RegExp(r'[^\w\-\.]'), '_');
      final fileExtension = _getImageExtension(imageUrl);
      final filePath = '${imagesDir.path}/$cleanFileName.$fileExtension';
      
      // Download the image
      await _dio.download(
        imageUrl,
        filePath,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            final percent = (received / total * 100);
            if (percent % 20 == 0) {
              print('     Downloading: ${percent.toStringAsFixed(0)}%');
            }
          }
        },
      );
      
      // Verify file was created
      final file = File(filePath);
      if (await file.exists()) {
        final size = await file.length();
        print('     Saved: ${(size / 1024).toStringAsFixed(1)} KB');
        return filePath;
      }
      
      return null;
    } catch (e) {
      print('⚠️ Image download failed for $imageUrl: $e');
      return null;
    }
  }
  
  /// Get image extension from URL
  String _getImageExtension(String url) {
    try {
      final uri = Uri.parse(url);
      final path = uri.path;
      final dotIndex = path.lastIndexOf('.');
      if (dotIndex != -1 && dotIndex < path.length - 1) {
        final ext = path.substring(dotIndex + 1).toLowerCase();
        // Limit to 4 characters for safety
        return ext.length <= 4 ? ext : 'jpg';
      }
    } catch (e) {
      print('⚠️ Could not parse image URL: $e');
    }
    return 'jpg'; // Default extension
  }
  
  /// Estimate total file size
  Future<int> _estimateFileSize(Map<String, String> images, String? courseImagePath) async {
    int totalSize = 0;
    
    // Add course image size
    if (courseImagePath != null) {
      final file = File(courseImagePath);
      if (await file.exists()) {
        totalSize += await file.length();
      }
    }
    
    // Add topic images size
    for (final imagePath in images.values) {
      final file = File(imagePath);
      if (await file.exists()) {
        totalSize += await file.length();
      }
    }
    
    return totalSize;
  }
  
  // ==================== COURSE STATUS & QUERIES ====================
  
  /// Check if a course is downloaded
  Future<bool> isCourseDownloaded(String courseId) async {
    try {
      final box = await Hive.openBox(offlineCoursesBox);
      final status = box.get('${courseId}_status');
      return status == 'downloaded';
    } catch (e) {
      return false;
    }
  }
  
  /// Get download status and progress
  Future<Map<String, dynamic>> getDownloadStatus(String courseId) async {
    try {
      final box = await Hive.openBox(offlineCoursesBox);
      final status = box.get('${courseId}_status');
      final progress = box.get('${courseId}_progress') ?? 0.0;
      
      return {
        'status': status,
        'progress': progress,
        'isDownloading': _activeDownloads.containsKey(courseId),
      };
    } catch (e) {
      return {
        'status': null,
        'progress': 0.0,
        'isDownloading': false,
      };
    }
  }
  
  /// Get all downloaded course IDs
  Future<List<String>> getDownloadedCourseIds() async {
    try {
      final box = await Hive.openBox(offlineCoursesBox);
      return box.get('downloaded_course_ids', defaultValue: <String>[]);
    } catch (e) {
      return [];
    }
  }
  
  /// Get offline course data
  Future<Map<String, dynamic>?> getOfflineCourseData(String courseId) async {
    try {
      final box = await Hive.openBox(offlineCoursesBox);
      return box.get('course_$courseId');
    } catch (e) {
      return null;
    }
  }
  
  /// Get offline course object
  Future<Course?> getOfflineCourse(String courseId) async {
    try {
      final data = await getOfflineCourseData(courseId);
      if (data != null && data['course'] != null) {
        return Course.fromJson(data['course']);
      }
    } catch (e) {
      print('❌ Error getting offline course: $e');
    }
    return null;
  }
  
  /// Get offline outlines for a course
  Future<List<CourseOutline>> getOfflineOutlines(String courseId) async {
    try {
      final data = await getOfflineCourseData(courseId);
      if (data != null && data['outlines'] != null) {
        final outlinesJson = data['outlines'] as List;
        return outlinesJson.map((json) => CourseOutline.fromJson(json)).toList();
      }
    } catch (e) {
      print('❌ Error getting offline outlines: $e');
    }
    return [];
  }
  
  /// Get all offline topics for a course
  Future<List<Topic>> getOfflineTopics(String courseId) async {
    try {
      final data = await getOfflineCourseData(courseId);
      if (data != null && data['topics'] != null) {
        final topicsJson = data['topics'] as List;
        return topicsJson.map((json) => Topic.fromJson(json)).toList();
      }
    } catch (e) {
      print('❌ Error getting offline topics: $e');
    }
    return [];
  }
  
  /// Get offline topics for a specific outline
  Future<List<Topic>> getOfflineTopicsForOutline(String courseId, String outlineId) async {
    try {
      final allTopics = await getOfflineTopics(courseId);
      return allTopics.where((topic) => topic.outlineId == outlineId).toList();
    } catch (e) {
      print('❌ Error getting topics for outline: $e');
      return [];
    }
  }
  
  /// Get local image path for a topic
  Future<String?> getTopicImagePath(String courseId, String topicId) async {
    try {
      final data = await getOfflineCourseData(courseId);
      if (data != null && data['images'] != null) {
        final images = Map<String, dynamic>.from(data['images']);
        return images[topicId]?.toString();
      }
    } catch (e) {
      print('❌ Error getting topic image path: $e');
    }
    return null;
  }
  
  // ==================== COURSE MANAGEMENT ====================
  
  /// Delete a downloaded course
  Future<void> deleteDownloadedCourse(String courseId) async {
    try {
      final box = await Hive.openBox(offlineCoursesBox);
      
      // Get course data to delete images
      final data = await getOfflineCourseData(courseId);
      if (data != null && data['images'] != null) {
        final images = Map<String, String>.from(data['images']);
        
        // Delete all downloaded images
        for (final imagePath in images.values) {
          try {
            final file = File(imagePath);
            if (await file.exists()) {
              await file.delete();
            }
          } catch (e) {
            print('⚠️ Could not delete image $imagePath: $e');
          }
        }
        
        // Delete course image if exists
        final course = await getOfflineCourse(courseId);
        if (course?.localImagePath != null) {
          try {
            final file = File(course!.localImagePath!);
            if (await file.exists()) {
              await file.delete();
            }
          } catch (e) {
            print('⚠️ Could not delete course image: $e');
          }
        }
      }
      
      // Remove from Hive
      await box.delete('course_$courseId');
      await box.delete('${courseId}_status');
      await box.delete('${courseId}_progress');
      
      // Update downloaded list
      final downloadedIds = box.get('downloaded_course_ids', defaultValue: <String>[]);
      downloadedIds.remove(courseId);
      await box.put('downloaded_course_ids', downloadedIds);
      
      // Update cache
      await _updateCourseInCache(Course.fromJson({
        'id': courseId,
        'code': '',
        'title': '',
        'credit_units': 0,
        'university': '',
        'university_name': '',
        'level': '',
        'level_name': '',
        'semester': '',
        'semester_name': '',
        'departments_info': [],
        'is_downloaded': false,
      }));
      
      print('🗑️ Successfully deleted offline course: $courseId');
    } catch (e) {
      print('❌ Error deleting downloaded course: $e');
      rethrow;
    }
  }
  
  /// Get total offline storage used
  Future<int> getOfflineStorageSize() async {
    try {
      int totalSize = 0;
      final appDir = await getApplicationDocumentsDirectory();
      final imagesDir = Directory('${appDir.path}/offline_images');
      
      if (await imagesDir.exists()) {
        final files = await imagesDir.list().toList();
        for (var file in files) {
          if (file is File) {
            totalSize += await file.length();
          }
        }
      }
      
      return totalSize;
    } catch (e) {
      print('❌ Error calculating storage size: $e');
      return 0;
    }
  }
  
  /// Clear all offline data (use with caution!)
  Future<void> clearAllOfflineData() async {
    try {
      // Delete all downloaded images
      final appDir = await getApplicationDocumentsDirectory();
      final imagesDir = Directory('${appDir.path}/offline_images');
      if (await imagesDir.exists()) {
        await imagesDir.delete(recursive: true);
      }
      
      // Clear all Hive boxes
      final boxes = [
        offlineCoursesBox,
        recentCourseBox,
        coursesCacheBox,
        userDataBox,
        activationCacheBox,
      ];
      
      for (final boxName in boxes) {
        try {
          final box = await Hive.openBox(boxName);
          await box.clear();
        } catch (e) {
          print('⚠️ Could not clear box $boxName: $e');
        }
      }
      
      print('🧹 Successfully cleared all offline data');
    } catch (e) {
      print('❌ Error clearing offline data: $e');
    }
  }
  
  // ==================== HELPER METHODS ====================
  
  /// Update download status in Hive
  Future<void> _updateDownloadStatus(String courseId, String status, double progress) async {
    try {
      final box = await Hive.openBox(offlineCoursesBox);
      await box.put('${courseId}_status', status);
      await box.put('${courseId}_progress', progress);
    } catch (e) {
      print('❌ Error updating download status: $e');
    }
  }
  
  /// Update course in cache
  // Future<void> _updateCourseInCache(Course course) async {
  //   try {
  //     final box = await Hive.openBox<List>(coursesCacheBox);
  //     List cachedCourses = box.get('courses', defaultValue: []);
      
  //     // Convert to list of maps for easier manipulation
  //     List<Map<String, dynamic>> coursesList = [];
  //     for (var item in cachedCourses) {
  //       if (item is Map<String, dynamic>) {
  //         coursesList.add(item);
  //       }
  //     }
      
  //     // Find and update the course
  //     bool found = false;
  //     for (int i = 0; i < coursesList.length; i++) {
  //       if (coursesList[i]['id'] == course.id) {
  //         coursesList[i] = course.toJson();
  //         found = true;
  //         break;
  //       }
  //     }
      
  //     // If not found, add it
  //     if (!found) {
  //       coursesList.add(course.toJson());
  //     }
      
  //     await box.put('courses', coursesList);
  //   } catch (e) {
  //     print('❌ Error updating cache: $e');
  //   }
  // }

  // Update this method in offline_service.dart
Future<void> _updateCourseInCache(Course course) async {
  try {
    // Open box without type or with dynamic type
    final box = await Hive.openBox(coursesCacheBox);
    
    // Get cached data - handle null properly
    final cachedData = box.get('courses');
    List<Map<String, dynamic>> coursesList = [];
    
    if (cachedData != null && cachedData is List) {
      // Convert to proper type
      for (var item in cachedData) {
        if (item is Map<String, dynamic>) {
          coursesList.add(item);
        }
      }
    }
    
    // Find and update the course
    bool found = false;
    for (int i = 0; i < coursesList.length; i++) {
      if (coursesList[i]['id'] == course.id) {
        coursesList[i] = course.toJson();
        found = true;
        break;
      }
    }
    
    // If not found, add it
    if (!found) {
      coursesList.add(course.toJson());
    }
    
    // Save back to box
    await box.put('courses', coursesList);
    
    print('✅ Updated course ${course.code} in cache');
  } catch (e) {
    print('❌ Error updating cache: $e');
  }
}

// Also update the _removeCourseFromCache method:
Future<void> _removeCourseFromCache(String courseId) async {
  try {
    final box = await Hive.openBox(coursesCacheBox);
    final cachedData = box.get('courses');
    
    if (cachedData != null && cachedData is List) {
      List<Map<String, dynamic>> coursesList = [];
      
      // Filter out the course to remove
      for (var item in cachedData) {
        if (item is Map<String, dynamic> && item['id'] != courseId) {
          coursesList.add(item);
        }
      }
      
      await box.put('courses', coursesList);
      print('✅ Removed course $courseId from cache');
    }
  } catch (e) {
    print('❌ Error removing from cache: $e');
  }
}

  // ################################
  
  /// Check if download is in progress for any course
  bool isAnyDownloadInProgress() {
    return _activeDownloads.isNotEmpty;
  }
  
  /// Cancel an active download
  Future<void> cancelDownload(String courseId) async {
    try {
      // Remove from active downloads
      _activeDownloads.remove(courseId);
      
      // Update status
      await _updateDownloadStatus(courseId, 'cancelled', 0.0);
      
      print('⏹️ Cancelled download for course: $courseId');
    } catch (e) {
      print('❌ Error cancelling download: $e');
    }
  }
  
  /// Check if user has any downloaded courses
  Future<bool> hasDownloadedCourses() async {
    try {
      final downloadedIds = await getDownloadedCourseIds();
      return downloadedIds.isNotEmpty;
    } catch (e) {
      return false;
    }
  }
  
  /// Get downloaded courses count
  Future<int> getDownloadedCoursesCount() async {
    try {
      final downloadedIds = await getDownloadedCourseIds();
      return downloadedIds.length;
    } catch (e) {
      return 0;
    }
  }
  
  /// Get all downloaded courses
  Future<List<Course>> getAllDownloadedCourses() async {
    try {
      final downloadedIds = await getDownloadedCourseIds();
      final courses = <Course>[];
      
      for (final courseId in downloadedIds) {
        final course = await getOfflineCourse(courseId);
        if (course != null) {
          courses.add(course);
        }
      }
      
      return courses;
    } catch (e) {
      print('❌ Error getting downloaded courses: $e');
      return [];
    }
  }
  
  // ==================== ACTIVATION STATUS ====================
  
  /// Check activation status (cached)
  Future<bool> isUserActivated() async {
    try {
      final box = await Hive.openBox(activationCacheBox);
      final cached = box.get('user_activated');
      return cached == true;
    } catch (e) {
      return false;
    }
  }
  
  /// Save activation status
  Future<void> saveActivationStatus(bool activated, {String? grade}) async {
    try {
      final box = await Hive.openBox(activationCacheBox);
      await box.put('user_activated', activated);
      if (grade != null) {
        await box.put('activation_grade', grade);
      }
      await box.put('activation_timestamp', DateTime.now().toIso8601String());
    } catch (e) {
      print('❌ Error saving activation status: $e');
    }
  }
  
  /// Get activation grade if any
  Future<String?> getActivationGrade() async {
    try {
      final box = await Hive.openBox(activationCacheBox);
      return box.get('activation_grade');
    } catch (e) {
      return null;
    }
  }
}