// lib/services/cache_manager.dart
import 'package:hive/hive.dart';
import '../features/courses/models/course_models.dart';

class CacheManager {
  static const String coursesCacheBox = 'courses_cache';
  static const String recentCourseBox = 'recent_course';
  
  // Singleton instance
  static final CacheManager _instance = CacheManager._internal();
  factory CacheManager() => _instance;
  CacheManager._internal();
  
  // Cache courses
  Future<void> cacheCourses(List<Course> courses) async {
    try {
      final box = await Hive.openBox(coursesCacheBox);
      final courseData = courses.map((course) => course.toJson()).toList();
      await box.put('courses', courseData);
      print('✅ Cached ${courses.length} courses');
    } catch (e) {
      print('❌ Error caching courses: $e');
    }
  }
  
  // Get cached courses
  Future<List<Course>> getCachedCourses() async {
    try {
      final box = await Hive.openBox(coursesCacheBox);
      final cachedData = box.get('courses');
      
      if (cachedData != null && cachedData is List) {
        return cachedData.map((json) => Course.fromJson(json)).toList();
      }
    } catch (e) {
      print('❌ Error getting cached courses: $e');
    }
    return [];
  }
  
  // Update a single course in cache
  Future<void> updateCourseInCache(Course course) async {
    try {
      final cachedCourses = await getCachedCourses();
      final index = cachedCourses.indexWhere((c) => c.id == course.id);
      
      if (index != -1) {
        cachedCourses[index] = course;
      } else {
        cachedCourses.add(course);
      }
      
      await cacheCourses(cachedCourses);
      print('✅ Updated course in cache: ${course.code}');
    } catch (e) {
      print('❌ Error updating course in cache: $e');
    }
  }
  
  // Remove course from cache
  Future<void> removeCourseFromCache(String courseId) async {
    try {
      final cachedCourses = await getCachedCourses();
      cachedCourses.removeWhere((course) => course.id == courseId);
      await cacheCourses(cachedCourses);
      print('✅ Removed course from cache: $courseId');
    } catch (e) {
      print('❌ Error removing course from cache: $e');
    }
  }
  
  // Clear all cached courses
  Future<void> clearCourseCache() async {
    try {
      final box = await Hive.openBox(coursesCacheBox);
      await box.clear();
      print('🧹 Cleared course cache');
    } catch (e) {
      print('❌ Error clearing course cache: $e');
    }
  }
}