// lib/managers/offline_data_manager.dart
import 'package:hive/hive.dart';
import '../services/offline_service.dart';
import '../features/courses/models/course_models.dart';

class OfflineDataManager {
  static final OfflineDataManager _instance = OfflineDataManager._internal();
  factory OfflineDataManager() => _instance;
  OfflineDataManager._internal();

  final OfflineService _offlineService = OfflineService();
  
  // Track loaded offline courses
  final Map<String, bool> _offlineCoursesLoaded = {};
  
  /// Load all offline data on app start
  Future<void> loadAllOfflineData() async {
    try {
      print('🔄 Loading all offline data...');
      
      final downloadedIds = await _offlineService.getDownloadedCourseIds();
      print('📥 Found ${downloadedIds.length} downloaded courses');
      
      for (final courseId in downloadedIds) {
        await _preloadCourseData(courseId);
      }
      
      print('✅ All offline data loaded');
    } catch (e) {
      print('❌ Error loading offline data: $e');
    }
  }
  
  /// Preload course data into memory
  Future<void> _preloadCourseData(String courseId) async {
    try {
      if (_offlineCoursesLoaded[courseId] == true) {
        return; // Already loaded
      }
      
      print('📖 Preloading course: $courseId');
      
      // Load course data
      final course = await _offlineService.getOfflineCourse(courseId);
      if (course != null) {
        print('   ✅ Course loaded: ${course.code}');
      }
      
      // Load outlines
      final outlines = await _offlineService.getOfflineOutlines(courseId);
      print('   📑 Outlines loaded: ${outlines.length}');
      
      // Load topics
      final topics = await _offlineService.getOfflineTopics(courseId);
      print('   📚 Topics loaded: ${topics.length}');
      
      _offlineCoursesLoaded[courseId] = true;
      
    } catch (e) {
      print('⚠️ Error preloading course $courseId: $e');
    }
  }
  
  /// Check if course has offline data
  Future<bool> hasOfflineData(String courseId) async {
    try {
      final box = await Hive.openBox('offline_courses');
      return box.containsKey('course_$courseId');
    } catch (e) {
      return false;
    }
  }
  
  /// Get offline course with all data
  Future<Map<String, dynamic>?> getCompleteOfflineCourse(String courseId) async {
    try {
      final box = await Hive.openBox('offline_courses');
      final data = box.get('course_$courseId');
      
      if (data != null) {
        final mapData = Map<String, dynamic>.from(data);
        
        // Parse course
        if (mapData['course'] != null) {
          mapData['parsed_course'] = Course.fromJson(mapData['course']);
        }
        
        // Parse outlines
        if (mapData['outlines'] != null) {
          final outlinesJson = mapData['outlines'] as List;
          mapData['parsed_outlines'] = outlinesJson.map((json) => 
            CourseOutline.fromJson(Map<String, dynamic>.from(json))
          ).toList();
        }
        
        // Parse topics
        if (mapData['topics'] != null) {
          final topicsJson = mapData['topics'] as List;
          mapData['parsed_topics'] = topicsJson.map((json) => 
            Topic.fromJson(Map<String, dynamic>.from(json))
          ).toList();
        }
        
        return mapData;
      }
    } catch (e) {
      print('❌ Error getting complete offline course: $e');
    }
    return null;
  }
  
  /// Force reload offline data for a course
  Future<void> reloadOfflineCourse(String courseId) async {
    _offlineCoursesLoaded.remove(courseId);
    await _preloadCourseData(courseId);
  }
  
  /// Clear all loaded offline data from memory
  void clearMemoryCache() {
    _offlineCoursesLoaded.clear();
    print('🧹 Cleared offline data from memory');
  }
}