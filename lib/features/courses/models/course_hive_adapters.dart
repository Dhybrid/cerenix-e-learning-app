// lib/features/courses/models/course_hive_adapters.dart
import 'dart:ui';
import 'package:hive/hive.dart';
import 'course_models.dart';

// Color adapter - typeId: 1
class ColorAdapter extends TypeAdapter<Color> {
  @override
  final int typeId = 1;

  @override
  Color read(BinaryReader reader) {
    try {
      final value = reader.readInt();
      return Color(value);
    } catch (e) {
      print('❌ Error reading Color from Hive: $e');
      return const Color(0xFF667eea);
    }
  }

  @override
  void write(BinaryWriter writer, Color obj) {
    writer.writeInt(obj.value);
  }
}

// Course adapter - typeId: 2
class CourseAdapter extends TypeAdapter<Course> {
  @override
  final int typeId = 2;

  @override
  Course read(BinaryReader reader) {
    try {
      final map = Map<String, dynamic>.from(reader.readMap());
      
      // Handle color field
      if (map['color'] != null && map['color'] is int) {
        map['color'] = Color(map['color'] as int);
      } else if (map['color_value'] != null) {
        map['color'] = Color(map['color_value'] as int);
      }
      
      return Course.fromJson(map);
    } catch (e) {
      print('❌ Error reading Course from Hive: $e');
      return Course(
        id: '0',
        code: 'ERROR',
        title: 'Error loading course',
        description: 'Error loading course data',
        creditUnits: 0,
        universityId: '0',
        universityName: 'Unknown',
        levelId: '0',
        levelName: 'Unknown',
        semesterId: '0',
        semesterName: 'Unknown',
        departmentsInfo: [],
        progress: 0,
        isDownloaded: false,
        color: const Color(0xFF667eea),
      );
    }
  }

  @override
  void write(BinaryWriter writer, Course obj) {
    try {
      final json = obj.toJson();
      
      // Store color as separate value
      json['color_value'] = obj.color.value;
      json['color'] = obj.color.value; // Store as int
      
      writer.writeMap(json);
    } catch (e) {
      print('❌ Error writing Course to Hive: $e');
      writer.writeMap({
        'id': obj.id,
        'code': obj.code,
        'title': obj.title,
        'color': obj.color.value,
      });
    }
  }
}

// CourseOutline adapter - typeId: 3
class CourseOutlineAdapter extends TypeAdapter<CourseOutline> {
  @override
  final int typeId = 3;

  @override
  CourseOutline read(BinaryReader reader) {
    try {
      final map = Map<String, dynamic>.from(reader.readMap());
      return CourseOutline.fromJson(map);
    } catch (e) {
      print('❌ Error reading CourseOutline from Hive: $e');
      return CourseOutline(
        id: '0',
        courseId: '0',
        courseCode: 'ERROR',
        courseTitle: 'Error loading outline',
        title: 'Error',
        order: 0,
        createdAt: DateTime.now(),
      );
    }
  }

  @override
  void write(BinaryWriter writer, CourseOutline obj) {
    try {
      writer.writeMap(obj.toJson());
    } catch (e) {
      print('❌ Error writing CourseOutline to Hive: $e');
      writer.writeMap({
        'id': obj.id,
        'title': obj.title,
        'course': obj.courseId,
      });
    }
  }
}

// ############################# ADDING FOR PROFILE HERE #########################
// Add this after TopicAdapter, before the helper functions

// UserProfile adapter - typeId: 5
class UserProfileAdapter extends TypeAdapter<UserProfile> {
  @override
  final int typeId = 5;

  @override
  UserProfile read(BinaryReader reader) {
    try {
      final map = Map<String, dynamic>.from(reader.readMap());
      
      // Parse dates safely
      DateTime parseDate(String? dateString) {
        if (dateString == null || dateString.isEmpty) return DateTime.now();
        try {
          return DateTime.parse(dateString);
        } catch (e) {
          return DateTime.now();
        }
      }
      
      return UserProfile(
        id: map['id']?.toString() ?? '',
        universityId: map['university_id']?.toString() ?? '',
        universityName: map['university_name']?.toString() ?? '',
        departmentId: map['department_id']?.toString() ?? '',
        departmentName: map['department_name']?.toString() ?? '',
        levelId: map['level_id']?.toString() ?? '',
        levelName: map['level_name']?.toString() ?? '',
        semesterId: map['semester_id']?.toString() ?? '',
        semesterName: map['semester_name']?.toString() ?? '',
        lastUpdated: parseDate(map['last_updated']?.toString()),
      );
    } catch (e) {
      print('❌ Error reading UserProfile from Hive: $e');
      return UserProfile(
        id: '0',
        universityId: '0',
        universityName: 'Unknown',
        departmentId: '0',
        departmentName: 'Unknown',
        levelId: '0',
        levelName: 'Unknown',
        semesterId: '0',
        semesterName: 'Unknown',
        lastUpdated: DateTime.now(),
      );
    }
  }

  @override
  void write(BinaryWriter writer, UserProfile obj) {
    try {
      writer.writeMap(obj.toJson());
    } catch (e) {
      print('❌ Error writing UserProfile to Hive: $e');
      writer.writeMap({
        'id': obj.id,
        'university_name': obj.universityName,
        'level_name': obj.levelName,
        'semester_name': obj.semesterName,
      });
    }
  }
}

// DownloadRecord adapter - typeId: 6 (to track which user downloaded what)
class DownloadRecordAdapter extends TypeAdapter<DownloadRecord> {
  @override
  final int typeId = 6;

  @override
  DownloadRecord read(BinaryReader reader) {
    try {
      final map = Map<String, dynamic>.from(reader.readMap());
      
      DateTime parseDate(String? dateString) {
        if (dateString == null || dateString.isEmpty) return DateTime.now();
        try {
          return DateTime.parse(dateString);
        } catch (e) {
          return DateTime.now();
        }
      }
      
      // Parse user profile if exists
      Map<String, dynamic>? userProfileMap;
      if (map['user_profile'] != null && map['user_profile'] is Map) {
        userProfileMap = Map<String, dynamic>.from(map['user_profile'] as Map);
      }
      
      return DownloadRecord(
        courseId: map['course_id']?.toString() ?? '',
        userId: map['user_id']?.toString() ?? '',
        userProfile: userProfileMap != null ? UserProfile.fromJson(userProfileMap) : null,
        downloadedAt: parseDate(map['downloaded_at']?.toString()),
        courseUniversityId: map['course_university_id']?.toString() ?? '',
        courseLevelId: map['course_level_id']?.toString() ?? '',
        courseSemesterId: map['course_semester_id']?.toString() ?? '',
      );
    } catch (e) {
      print('❌ Error reading DownloadRecord from Hive: $e');
      return DownloadRecord(
        courseId: '0',
        userId: '0',
        downloadedAt: DateTime.now(),
        courseUniversityId: '0',
        courseLevelId: '0',
        courseSemesterId: '0',
      );
    }
  }

  @override
  void write(BinaryWriter writer, DownloadRecord obj) {
    try {
      writer.writeMap(obj.toJson());
    } catch (e) {
      print('❌ Error writing DownloadRecord to Hive: $e');
      writer.writeMap({
        'course_id': obj.courseId,
        'user_id': obj.userId,
        'downloaded_at': obj.downloadedAt.toIso8601String(),
      });
    }
  }
}
// ###################################### ADDNIG FOR PROFILES ENDS HERE ########################

// Topic adapter - typeId: 4
class TopicAdapter extends TypeAdapter<Topic> {
  @override
  final int typeId = 4;

  @override
  Topic read(BinaryReader reader) {
    try {
      final map = Map<String, dynamic>.from(reader.readMap());
      
      // Handle dates safely
      DateTime parseDate(String? dateString) {
        if (dateString == null || dateString.isEmpty) return DateTime.now();
        try {
          return DateTime.parse(dateString);
        } catch (e) {
          return DateTime.now();
        }
      }
      
      // Parse user progress
      Map<String, dynamic>? userProgress;
      if (map['user_progress'] != null && map['user_progress'] is Map) {
        try {
          userProgress = Map<String, dynamic>.from(map['user_progress'] as Map);
        } catch (e) {
          userProgress = null;
        }
      }
      
      // Get isCompleted from user_progress if available
      bool isCompleted = false;
      if (userProgress != null && userProgress['is_completed'] is bool) {
        isCompleted = userProgress['is_completed'] as bool;
      } else if (map['is_completed'] is bool) {
        isCompleted = map['is_completed'] as bool;
      }
      
      // Create Topic object with proper constructor
      return Topic(
        id: map['id']?.toString() ?? '',
        outlineId: map['outline']?.toString() ?? '',
        outlineInfo: map['outline_info'] is Map 
            ? Map<String, dynamic>.from(map['outline_info'] as Map) 
            : null,
        courseInfo: map['course_info'] is Map 
            ? Map<String, dynamic>.from(map['course_info'] as Map) 
            : null,
        title: map['title']?.toString() ?? '',
        description: map['description']?.toString(),
        content: map['content']?.toString(),
        videoUrl: map['video_url']?.toString(),
        image: map['image']?.toString(),
        displayImageUrl: map['display_image_url']?.toString(),
        videoPreviewUrl: map['video_preview_url']?.toString(),
        order: (map['order'] is int)
            ? map['order'] as int
            : (map['order'] is String)
                ? int.tryParse(map['order'] as String) ?? 0
                : 0,
        durationMinutes: (map['duration_minutes'] is int)
            ? map['duration_minutes'] as int
            : 0,
        isPublished: map['is_published'] is bool ? map['is_published'] as bool : true,
        createdAt: parseDate(map['created_at']?.toString()),
        updatedAt: parseDate(map['updated_at']?.toString()),
        userProgress: userProgress,
        progressPercentage: 0,
        isCompleted: isCompleted,
        timeSpentMinutes: 0,
        
        // Completion question fields
        completionQuestionText: map['completion_question_text']?.toString(),
        completionQuestionImage: map['completion_question_image']?.toString(),
        completionQuestionImageUrl: map['completion_question_image_url']?.toString(),
        hasOptions: map['has_options'] is bool ? map['has_options'] as bool : false,
        options: _parseOptions(map['options']),
        optionA: map['option_a']?.toString(),
        optionB: map['option_b']?.toString(),
        optionC: map['option_c']?.toString(),
        optionD: map['option_d']?.toString(),
        correctAnswer: map['correct_answer']?.toString(),
        solutionText: map['solution_text']?.toString(),
        solutionImage: map['solution_image']?.toString(),
        solutionImageUrl: map['solution_image_url']?.toString(),
        hasCompletionQuestion: map['has_completion_question'] is bool 
            ? map['has_completion_question'] as bool 
            : false,
      );
    } catch (e) {
      print('❌ Error reading Topic from Hive: $e');
      print('📄 Error details: ${e.toString()}');
      
      return Topic(
        id: '0',
        outlineId: '0',
        title: 'Error loading topic',
        order: 0,
        durationMinutes: 0,
        isPublished: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        isCompleted: false,
      );
    }
  }

  List<Map<String, dynamic>>? _parseOptions(dynamic optionsData) {
    if (optionsData == null) return null;
    if (optionsData is List) {
      try {
        return optionsData.map((item) {
          if (item is Map) {
            return Map<String, dynamic>.from(item);
          }
          return <String, dynamic>{};
        }).toList();
      } catch (e) {
        return null;
      }
    }
    return null;
  }

  @override
  void write(BinaryWriter writer, Topic obj) {
    try {
      writer.writeMap(obj.toJson());
    } catch (e) {
      print('❌ Error writing Topic to Hive: $e');
      writer.writeMap({
        'id': obj.id,
        'title': obj.title,
        'outline': obj.outlineId,
        'is_completed': obj.isCompleted,
      });
    }
  }
}

// Helper function to check if course adapters are registered
bool areCourseAdaptersRegistered() {
  try {
    // return Hive.isAdapterRegistered(1) && 
    //        Hive.isAdapterRegistered(2) && 
    //        Hive.isAdapterRegistered(3) && 
    //        Hive.isAdapterRegistered(4) &&
    //        Hive.isAdapterRegistered(5) && // ADD THIS
    //        Hive.isAdapterRegistered(6);   // ADD THIS;
    return Hive.isAdapterRegistered(1) && 
           Hive.isAdapterRegistered(2) && 
           Hive.isAdapterRegistered(3) && 
           Hive.isAdapterRegistered(4) &&
           Hive.isAdapterRegistered(5) && // ADD THIS
           Hive.isAdapterRegistered(6);   // ADD THIS
  } catch (e) {
    return false;
  }
}

// Helper function to register all course adapters
Future<void> registerCourseAdapters() async {
  try {
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(ColorAdapter());
      print('✅ Registered ColorAdapter (typeId: 1)');
    }
    
    if (!Hive.isAdapterRegistered(2)) {
      Hive.registerAdapter(CourseAdapter());
      print('✅ Registered CourseAdapter (typeId: 2)');
    }
    
    if (!Hive.isAdapterRegistered(3)) {
      Hive.registerAdapter(CourseOutlineAdapter());
      print('✅ Registered CourseOutlineAdapter (typeId: 3)');
    }
    
    if (!Hive.isAdapterRegistered(4)) {
      Hive.registerAdapter(TopicAdapter());
      print('✅ Registered TopicAdapter (typeId: 4)');
    }

    // NEW: Register the new adapters
    if (!Hive.isAdapterRegistered(5)) {
      Hive.registerAdapter(UserProfileAdapter());
      print('✅ Registered UserProfileAdapter (typeId: 5)');
    }
    
    if (!Hive.isAdapterRegistered(6)) {
      Hive.registerAdapter(DownloadRecordAdapter());
      print('✅ Registered DownloadRecordAdapter (typeId: 6)');
    }
    
    print('✅ All course adapters registered successfully');
  } catch (e) {
    print('❌ Error registering course adapters: $e');
  }
}