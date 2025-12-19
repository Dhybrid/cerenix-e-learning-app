import 'dart:math';
import 'package:flutter/material.dart';

// ==================== COURSE MODEL ====================
class Course {
  final String id;
  final String code;
  final String title;
  final String? description; // ADDED
  final String? imageUrl; // ADDED
  final String? abbreviation;
  final int creditUnits;
  final String universityId;
  final String universityName;
  final String levelId;
  final String levelName;
  final String semesterId;
  final String semesterName;
  final List<dynamic> departmentsInfo;
  int progress; // Mutable for updating progress

  // NEW: Fields for offline support
  bool isDownloaded = false;
  DateTime? downloadDate;
  String? localImagePath;



  // Color for UI - generated based on course code
  Color color;

  Course({
    required this.id,
    required this.code,
    required this.title,
    this.description,
    this.imageUrl,
    this.abbreviation,
    required this.creditUnits,
    required this.universityId,
    required this.universityName,
    required this.levelId,
    required this.levelName,
    required this.semesterId,
    required this.semesterName,
    required this.departmentsInfo,
    this.progress = 0,

    this.isDownloaded = false,
    this.downloadDate,
    this.localImagePath,

    Color? color,
  }) : color = color ?? generateColorFromCode(code); // Update this line //color = color ?? _generateColorFromCode(code);



  // In course_models.dart, update the fromJson factory:
factory Course.fromJson(Map<String, dynamic> json) {
  // Handle color from JSON
  Color color;
  if (json['color'] is int) {
    color = Color(json['color'] as int);
  } else if (json['color_value'] is int) {
    color = Color(json['color_value'] as int);
  } else {
    // Generate color from course code
    color = generateColorFromCode(json['code']?.toString() ?? '');
  }
  
  return Course(
    id: json['id']?.toString() ?? '',
    code: json['code']?.toString() ?? '',
    title: json['title']?.toString() ?? '',
    description: json['description']?.toString(),
    imageUrl: json['image_url']?.toString(),
    abbreviation: json['abbreviation']?.toString(),
    creditUnits: json['credit_units'] is int ? json['credit_units'] as int : 0,
    universityId: json['university_id']?.toString() ?? json['university']?.toString() ?? '',
    universityName: json['university_name']?.toString() ?? '',
    levelId: json['level_id']?.toString() ?? json['level']?.toString() ?? '',
    levelName: json['level_name']?.toString() ?? '',
    semesterId: json['semester_id']?.toString() ?? json['semester']?.toString() ?? '',
    semesterName: json['semester_name']?.toString() ?? '',
    departmentsInfo: json['departments_info'] ?? [],
    progress: json['progress'] is int ? json['progress'] as int : 0,
    isDownloaded: json['is_downloaded'] == true,
    downloadDate: json['download_date'] != null
        ? DateTime.tryParse(json['download_date'].toString())
        : null,
    localImagePath: json['local_image_path']?.toString(),
    color: color,
  );
}

  // Convert to Map for storage
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'code': code,
      'title': title,
      'description': description, // ADDED
      'image_url': imageUrl, // ADDED
      'abbreviation': abbreviation,
      'credit_units': creditUnits,
      'university_id': universityId,
      'university_name': universityName,
      'level_id': levelId,
      'level_name': levelName,
      'semester_id': semesterId,
      'semester_name': semesterName,
      'departments_info': departmentsInfo,
      'progress': progress,
      'is_downloaded': isDownloaded,
      'download_date': downloadDate?.toIso8601String(),
      'local_image_path': localImagePath,
      'color': color.value, // Store color as int
      'color_value': color.value, // Also store as color_value for compatibility
    };
  }


  // In your Course class in course_models.dart, add this method:
Course copyWith({
  String? id,
  String? code,
  String? title,
  String? description,
  String? imageUrl,
  String? abbreviation,
  int? creditUnits,
  String? universityId,
  String? universityName,
  String? levelId,
  String? levelName,
  String? semesterId,
  String? semesterName,
  List<dynamic>? departmentsInfo,
  int? progress,
  bool? isDownloaded,
  DateTime? downloadDate,
  String? localImagePath,
  Color? color,
}) {
  return Course(
    id: id ?? this.id,
    code: code ?? this.code,
    title: title ?? this.title,
    description: description ?? this.description,
    imageUrl: imageUrl ?? this.imageUrl,
    abbreviation: abbreviation ?? this.abbreviation,
    creditUnits: creditUnits ?? this.creditUnits,
    universityId: universityId ?? this.universityId,
    universityName: universityName ?? this.universityName,
    levelId: levelId ?? this.levelId,
    levelName: levelName ?? this.levelName,
    semesterId: semesterId ?? this.semesterId,
    semesterName: semesterName ?? this.semesterName,
    departmentsInfo: departmentsInfo ?? this.departmentsInfo,
    progress: progress ?? this.progress,
    isDownloaded: isDownloaded ?? this.isDownloaded,
    downloadDate: downloadDate ?? this.downloadDate,
    localImagePath: localImagePath ?? this.localImagePath,
    color: color ?? this.color,
  );
}

  // Helper method to mark as downloaded
  Course markAsDownloaded() {
    return Course(
      id: id,
      code: code,
      title: title,
      description: description,
      imageUrl: imageUrl,
      abbreviation: abbreviation,
      creditUnits: creditUnits,
      universityId: universityId,
      universityName: universityName,
      levelId: levelId,
      levelName: levelName,
      semesterId: semesterId,
      semesterName: semesterName,
      departmentsInfo: departmentsInfo,
      progress: progress,
      isDownloaded: true,
      downloadDate: DateTime.now(),
      localImagePath: localImagePath,
      color: color,
    );
  }

  // Generate consistent color based on course code
  static Color generateColorFromCode(String code) {
    final colors = [
      Color(0xFFFF6B6B), // Red
      Color(0xFF4ECDC4), // Teal
      Color(0xFF45B7D1), // Blue
      Color(0xFF96CEB4), // Green
      Color(0xFFFFEAA7), // Yellow
      Color(0xFFDDA0DD), // Purple
      Color(0xFFF7B267), // Orange
      Color(0xFF84DCC6), // Mint
      Color(0xFFA593E0), // Lavender
      Color(0xFFFF9A76), // Peach
    ];

    // Create a hash from the course code
    int hash = 0;
    for (int i = 0; i < code.length; i++) {
      hash = code.codeUnitAt(i) + ((hash << 5) - hash);
    }

    // Use hash to pick a color
    return colors[hash.abs() % colors.length];
  }

  @override
  String toString() {
    return 'Course{id: $id, code: $code, title: $title, progress: $progress%}';
  }
}

// ==================== COURSE OUTLINE MODEL ====================
class CourseOutline {
  final String id;
  final String courseId;
  final String courseCode;
  final String courseTitle;
  final String title;
  final int order;
  final DateTime createdAt;
  final List<Topic>? topics;

  CourseOutline({
    required this.id,
    required this.courseId,
    required this.courseCode,
    required this.courseTitle,
    required this.title,
    required this.order,
    required this.createdAt,
    this.topics,
  });

  factory CourseOutline.fromJson(Map<String, dynamic> json) {
    return CourseOutline(
      id: json['id'].toString(),
      courseId: json['course'].toString(),
      courseCode: json['course_code'] ?? '',
      courseTitle: json['course_title'] ?? '',
      title: json['title'] ?? '',
      order: json['order'] ?? 0,
      createdAt: DateTime.parse(
        json['created_at'] ?? DateTime.now().toString(),
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'course': courseId,
      'course_code': courseCode,
      'course_title': courseTitle,
      'title': title,
      'order': order,
      'created_at': createdAt.toIso8601String(),
    };
  }

  @override
  String toString() {
    return 'CourseOutline{id: $id, title: $title, course: $courseCode}';
  }
}

// ==================== TOPIC MODEL ====================

class Topic {
  final String id;
  final String outlineId;
  final Map<String, dynamic>? outlineInfo;
  final Map<String, dynamic>? courseInfo;
  final String title;
  final String? description;
  final String? content;
  final String? videoUrl;
  final String? image;
  final String? displayImageUrl;
  final String? videoPreviewUrl;
  final int order;
  final int durationMinutes;
  final bool isPublished;
  final DateTime createdAt;
  final DateTime updatedAt;
  final Map<String, dynamic>? userProgress;
  final int progressPercentage;
  final bool isCompleted;
  final int timeSpentMinutes;

  // Completion question fields
  final String? completionQuestionText;
  final String? completionQuestionImage;
  final String? completionQuestionImageUrl;
  final bool hasOptions;
  final List<Map<String, dynamic>>? options;
  final String? optionA;
  final String? optionB;
  final String? optionC;
  final String? optionD;
  final String? correctAnswer;
  final String? solutionText;
  final String? solutionImage;
  final String? solutionImageUrl;
  final bool hasCompletionQuestion;

  Topic({
    required this.id,
    required this.outlineId,
    this.outlineInfo,
    this.courseInfo,
    required this.title,
    this.description,
    this.content,
    this.videoUrl,
    this.image,
    this.displayImageUrl,
    this.videoPreviewUrl,
    required this.order,
    required this.durationMinutes,
    required this.isPublished,
    required this.createdAt,
    required this.updatedAt,
    this.userProgress,
    this.progressPercentage = 0,
    this.isCompleted = false,
    this.timeSpentMinutes = 0,

    // Completion question fields
    this.completionQuestionText,
    this.completionQuestionImage,
    this.completionQuestionImageUrl,
    this.hasOptions = false,
    this.options,
    this.optionA,
    this.optionB,
    this.optionC,
    this.optionD,
    this.correctAnswer,
    this.solutionText,
    this.solutionImage,
    this.solutionImageUrl,
    this.hasCompletionQuestion = false,
  });
  //  ## NEWLY ADDED FILED
  Topic copyWith({
    String? id,
    String? outlineId,
    Map<String, dynamic>? outlineInfo,
    Map<String, dynamic>? courseInfo,
    String? title,
    String? description,
    String? content,
    String? videoUrl,
    String? image,
    String? displayImageUrl,
    String? videoPreviewUrl,
    int? order,
    int? durationMinutes,
    bool? isPublished,
    DateTime? createdAt,
    DateTime? updatedAt,
    Map<String, dynamic>? userProgress,
    int? progressPercentage,
    bool? isCompleted,
    int? timeSpentMinutes,
    String? completionQuestionText,
    String? completionQuestionImage,
    String? completionQuestionImageUrl,
    bool? hasOptions,
    List<Map<String, dynamic>>? options,
    String? optionA,
    String? optionB,
    String? optionC,
    String? optionD,
    String? correctAnswer,
    String? solutionText,
    String? solutionImage,
    String? solutionImageUrl,
    bool? hasCompletionQuestion,
  }) {
    return Topic(
      id: id ?? this.id,
      outlineId: outlineId ?? this.outlineId,
      outlineInfo: outlineInfo ?? this.outlineInfo,
      courseInfo: courseInfo ?? this.courseInfo,
      title: title ?? this.title,
      description: description ?? this.description,
      content: content ?? this.content,
      videoUrl: videoUrl ?? this.videoUrl,
      image: image ?? this.image,
      displayImageUrl: displayImageUrl ?? this.displayImageUrl,
      videoPreviewUrl: videoPreviewUrl ?? this.videoPreviewUrl,
      order: order ?? this.order,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      isPublished: isPublished ?? this.isPublished,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      userProgress: userProgress ?? this.userProgress,
      progressPercentage: progressPercentage ?? this.progressPercentage,
      isCompleted: isCompleted ?? this.isCompleted,
      timeSpentMinutes: timeSpentMinutes ?? this.timeSpentMinutes,
      completionQuestionText:
          completionQuestionText ?? this.completionQuestionText,
      completionQuestionImage:
          completionQuestionImage ?? this.completionQuestionImage,
      completionQuestionImageUrl:
          completionQuestionImageUrl ?? this.completionQuestionImageUrl,
      hasOptions: hasOptions ?? this.hasOptions,
      options: options ?? this.options,
      optionA: optionA ?? this.optionA,
      optionB: optionB ?? this.optionB,
      optionC: optionC ?? this.optionC,
      optionD: optionD ?? this.optionD,
      correctAnswer: correctAnswer ?? this.correctAnswer,
      solutionText: solutionText ?? this.solutionText,
      solutionImage: solutionImage ?? this.solutionImage,
      solutionImageUrl: solutionImageUrl ?? this.solutionImageUrl,
      hasCompletionQuestion:
          hasCompletionQuestion ?? this.hasCompletionQuestion,
    );
  }
  // ### END OF NEWLY ADDED FILED

  factory Topic.fromJson(Map<String, dynamic> json) {
    // Helper function to safely convert to Map<String, dynamic>
    Map<String, dynamic>? safeMap(dynamic value) {
      if (value == null) return null;
      if (value is Map) {
        try {
          return Map<String, dynamic>.from(value);
        } catch (e) {
          return null;
        }
      }
      return null;
    }

    // Parse user progress
    Map<String, dynamic>? parsedUserProgress = safeMap(json['user_progress']);
    int parsedProgress = 0;
    bool parsedCompleted = false;
    int parsedTimeSpent = 0;

    if (parsedUserProgress != null) {
      parsedProgress = parsedUserProgress['progress_percentage'] is int
          ? parsedUserProgress['progress_percentage']
          : 0;
      parsedCompleted = parsedUserProgress['is_completed'] is bool
          ? parsedUserProgress['is_completed']
          : false;
      parsedTimeSpent = parsedUserProgress['time_spent_minutes'] is int
          ? parsedUserProgress['time_spent_minutes']
          : 0;
    }

    // Parse outline and course info
    Map<String, dynamic>? parsedOutlineInfo = safeMap(json['outline_info']);
    Map<String, dynamic>? parsedCourseInfo = safeMap(json['course_info']);

    // Parse options
    List<Map<String, dynamic>>? parsedOptions = [];
    if (json['options'] != null && json['options'] is List) {
      try {
        parsedOptions = (json['options'] as List).map((option) {
          if (option is Map) {
            try {
              return Map<String, dynamic>.from(option);
            } catch (e) {
              return <String, dynamic>{};
            }
          }
          return <String, dynamic>{};
        }).toList();
      } catch (e) {
        print('⚠️ Error parsing options: $e');
        parsedOptions = [];
      }
    }

    // Get dates safely
    DateTime parseDate(String? dateString) {
      if (dateString == null || dateString.isEmpty) return DateTime.now();
      try {
        return DateTime.parse(dateString);
      } catch (e) {
        return DateTime.now();
      }
    }

    return Topic(
      id: json['id']?.toString() ?? '',
      outlineId: json['outline']?.toString() ?? '',
      outlineInfo: parsedOutlineInfo,
      courseInfo: parsedCourseInfo,
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString(),
      content: json['content']?.toString(),
      videoUrl: json['video_url']?.toString(),
      image: json['image']?.toString(),
      displayImageUrl: json['display_image_url']?.toString(),
      videoPreviewUrl: json['video_preview_url']?.toString(),
      order: (json['order'] is int)
          ? json['order']
          : ((json['order'] is String) ? int.tryParse(json['order']) ?? 0 : 0),
      durationMinutes: (json['duration_minutes'] is int)
          ? json['duration_minutes']
          : ((json['duration_minutes'] is String)
                ? int.tryParse(json['duration_minutes']) ?? 0
                : 0),
      isPublished: json['is_published'] is bool ? json['is_published'] : true,
      createdAt: parseDate(json['created_at']?.toString()),
      updatedAt: parseDate(json['updated_at']?.toString()),
      userProgress: parsedUserProgress,
      progressPercentage: parsedProgress,
      isCompleted: parsedCompleted,
      timeSpentMinutes: parsedTimeSpent,

      // Completion question fields
      completionQuestionText: json['completion_question_text']?.toString(),
      completionQuestionImage: json['completion_question_image']?.toString(),
      completionQuestionImageUrl: json['completion_question_image_url']
          ?.toString(),
      hasOptions: json['has_options'] is bool ? json['has_options'] : false,
      options: parsedOptions,
      optionA: json['option_a']?.toString(),
      optionB: json['option_b']?.toString(),
      optionC: json['option_c']?.toString(),
      optionD: json['option_d']?.toString(),
      correctAnswer: json['correct_answer']?.toString(),
      solutionText: json['solution_text']?.toString(),
      solutionImage: json['solution_image']?.toString(),
      solutionImageUrl: json['solution_image_url']?.toString(),
      hasCompletionQuestion: json['has_completion_question'] is bool
          ? json['has_completion_question']
          : false,
    );
  }

  // Getters for UI convenience
  String get courseCode {
    if (courseInfo != null && courseInfo!['code'] != null) {
      return courseInfo!['code']!.toString();
    }
    return '';
  }

  String get courseTitle {
    if (courseInfo != null && courseInfo!['title'] != null) {
      return courseInfo!['title']!.toString();
    }
    return '';
  }

  bool get hasVideo => videoUrl != null && videoUrl!.isNotEmpty;
  bool get hasImage => image != null && image!.isNotEmpty;
  bool get hasQuestionImage =>
      completionQuestionImageUrl != null &&
      completionQuestionImageUrl!.isNotEmpty;
  bool get hasSolutionImage =>
      solutionImageUrl != null && solutionImageUrl!.isNotEmpty;

  bool get hasProgress => progressPercentage > 0;
  double get progressFraction => progressPercentage / 100.0;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'outline': outlineId,
      'outline_info': outlineInfo,
      'course_info': courseInfo,
      'title': title,
      'description': description,
      'content': content,
      'video_url': videoUrl,
      'image': image,
      'display_image_url': displayImageUrl,
      'video_preview_url': videoPreviewUrl,
      'order': order,
      'duration_minutes': durationMinutes,
      'is_published': isPublished,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'user_progress': userProgress,
      'completion_question_text': completionQuestionText,
      'completion_question_image': completionQuestionImage,
      'completion_question_image_url': completionQuestionImageUrl,
      'has_options': hasOptions,
      'options': options,
      'option_a': optionA,
      'option_b': optionB,
      'option_c': optionC,
      'option_d': optionD,
      'correct_answer': correctAnswer,
      'solution_text': solutionText,
      'solution_image': solutionImage,
      'solution_image_url': solutionImageUrl,
      'has_completion_question': hasCompletionQuestion,
    };
  }

  @override
  String toString() {
    return 'Topic{id: $id, title: $title, progress: $progressPercentage%, completed: $isCompleted}';
  }
}

// #$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$

// ==================== USER PROGRESS MODEL ====================
class UserProgress {
  final String id;
  final String topicId;
  final String topicTitle;
  final String courseCode;
  final bool isCompleted;
  final int progressPercentage;
  final int timeSpentMinutes;
  final DateTime lastAccessed;

  UserProgress({
    required this.id,
    required this.topicId,
    required this.topicTitle,
    required this.courseCode,
    required this.isCompleted,
    required this.progressPercentage,
    required this.timeSpentMinutes,
    required this.lastAccessed,
  });

  factory UserProgress.fromJson(Map<String, dynamic> json) {
    return UserProgress(
      id: json['id'].toString(),
      topicId: json['topic'].toString(),
      topicTitle: json['topic_title'] ?? '',
      courseCode: json['course_code'] ?? '',
      isCompleted: json['is_completed'] ?? false,
      progressPercentage: json['progress_percentage'] ?? 0,
      timeSpentMinutes: json['time_spent_minutes'] ?? 0,
      lastAccessed: DateTime.parse(
        json['last_accessed'] ?? DateTime.now().toString(),
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'topic': topicId,
      'topic_title': topicTitle,
      'course_code': courseCode,
      'is_completed': isCompleted,
      'progress_percentage': progressPercentage,
      'time_spent_minutes': timeSpentMinutes,
      'last_accessed': lastAccessed.toIso8601String(),
    };
  }

  @override
  String toString() {
    return 'UserProgress{topic: $topicTitle, progress: $progressPercentage%, completed: $isCompleted}';
  }
}

// ==================== RANDOM QUESTION REQUEST MODEL ====================
class RandomQuestionRequest {
  final int courseId;
  final int? topicId;
  final String? session;
  final String? questionType;
  final int? difficulty;
  final int count;

  RandomQuestionRequest({
    required this.courseId,
    this.topicId,
    this.session,
    this.questionType,
    this.difficulty,
    this.count = 10,
  });

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = {'course_id': courseId, 'n': count};

    if (topicId != null) data['topic_id'] = topicId;
    if (session != null && session!.isNotEmpty) data['session'] = session;
    if (questionType != null && questionType!.isNotEmpty)
      data['question_type'] = questionType;
    if (difficulty != null) data['difficulty'] = difficulty;

    return data;
  }
}

// ==================== COURSE PROGRESS SUMMARY MODEL ====================
class CourseProgressSummary {
  final String courseId;
  final String courseCode;
  final String courseTitle;
  final int totalTopics;
  final int completedTopics;
  final int totalQuestions;
  final int correctAnswers;
  final int totalTimeSpentMinutes;
  final DateTime lastAccessed;

  CourseProgressSummary({
    required this.courseId,
    required this.courseCode,
    required this.courseTitle,
    required this.totalTopics,
    required this.completedTopics,
    required this.totalQuestions,
    required this.correctAnswers,
    required this.totalTimeSpentMinutes,
    required this.lastAccessed,
  });

  int get progressPercentage {
    if (totalTopics == 0) return 0;
    return ((completedTopics / totalTopics) * 100).round();
  }

  double get accuracyPercentage {
    if (totalQuestions == 0) return 0.0;
    return (correctAnswers / totalQuestions) * 100;
  }

  factory CourseProgressSummary.fromJson(Map<String, dynamic> json) {
    return CourseProgressSummary(
      courseId: json['course_id'].toString(),
      courseCode: json['course_code'] ?? '',
      courseTitle: json['course_title'] ?? '',
      totalTopics: json['total_topics'] ?? 0,
      completedTopics: json['completed_topics'] ?? 0,
      totalQuestions: json['total_questions'] ?? 0,
      correctAnswers: json['correct_answers'] ?? 0,
      totalTimeSpentMinutes: json['total_time_spent_minutes'] ?? 0,
      lastAccessed: DateTime.parse(
        json['last_accessed'] ?? DateTime.now().toString(),
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'course_id': courseId,
      'course_code': courseCode,
      'course_title': courseTitle,
      'total_topics': totalTopics,
      'completed_topics': completedTopics,
      'progress_percentage': progressPercentage,
      'total_questions': totalQuestions,
      'correct_answers': correctAnswers,
      'accuracy_percentage': accuracyPercentage,
      'total_time_spent_minutes': totalTimeSpentMinutes,
      'last_accessed': lastAccessed.toIso8601String(),
    };
  }

  @override
  String toString() {
    return 'CourseProgressSummary{course: $courseCode, progress: $progressPercentage%, accuracy: ${accuracyPercentage.toStringAsFixed(1)}%}';
  }
}

// Add these classes to course_models.dart, after the CourseProgressSummary class

// ==================== USER PROFILE MODEL ====================
class UserProfile {
  final String id;
  final String universityId;
  final String universityName;
  final String departmentId;
  final String departmentName;
  final String levelId;
  final String levelName;
  final String semesterId;
  final String semesterName;
  final DateTime lastUpdated;

  UserProfile({
    required this.id,
    required this.universityId,
    required this.universityName,
    required this.departmentId,
    required this.departmentName,
    required this.levelId,
    required this.levelName,
    required this.semesterId,
    required this.semesterName,
    DateTime? lastUpdated,
  }) : lastUpdated = lastUpdated ?? DateTime.now();

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'university_id': universityId,
      'university_name': universityName,
      'department_id': departmentId,
      'department_name': departmentName,
      'level_id': levelId,
      'level_name': levelName,
      'semester_id': semesterId,
      'semester_name': semesterName,
      'last_updated': lastUpdated.toIso8601String(),
    };
  }

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id']?.toString() ?? '',
      universityId: json['university_id']?.toString() ?? '',
      universityName: json['university_name']?.toString() ?? '',
      departmentId: json['department_id']?.toString() ?? '',
      departmentName: json['department_name']?.toString() ?? '',
      levelId: json['level_id']?.toString() ?? '',
      levelName: json['level_name']?.toString() ?? '',
      semesterId: json['semester_id']?.toString() ?? '',
      semesterName: json['semester_name']?.toString() ?? '',
      lastUpdated: json['last_updated'] != null 
          ? DateTime.tryParse(json['last_updated'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  // Create a unique key for storage
  String get storageKey => '${universityId}_${levelId}_${semesterId}';

  // Check if this profile matches another
  bool matches(UserProfile? other) {
    if (other == null) return false;
    return universityId == other.universityId &&
           levelId == other.levelId &&
           semesterId == other.semesterId;
  }

  // Check if profile is valid (has basic academic info)
  bool get isValid {
    return universityId.isNotEmpty && 
           levelId.isNotEmpty && 
           semesterId.isNotEmpty;
  }

  @override
  String toString() {
    return 'UserProfile{university: $universityName, level: $levelName, semester: $semesterName}';
  }
}

// ==================== DOWNLOAD RECORD MODEL ====================
class DownloadRecord {
  final String courseId;
  final String userId;
  final UserProfile? userProfile; // User's academic info at time of download
  final DateTime downloadedAt;
  final String courseUniversityId;
  final String courseLevelId;
  final String courseSemesterId;

  DownloadRecord({
    required this.courseId,
    required this.userId,
    this.userProfile,
    required this.downloadedAt,
    required this.courseUniversityId,
    required this.courseLevelId,
    required this.courseSemesterId,
  });

  Map<String, dynamic> toJson() {
    return {
      'course_id': courseId,
      'user_id': userId,
      'user_profile': userProfile?.toJson(),
      'downloaded_at': downloadedAt.toIso8601String(),
      'course_university_id': courseUniversityId,
      'course_level_id': courseLevelId,
      'course_semester_id': courseSemesterId,
    };
  }

  factory DownloadRecord.fromJson(Map<String, dynamic> json) {
    return DownloadRecord(
      courseId: json['course_id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      userProfile: json['user_profile'] != null 
          ? UserProfile.fromJson(Map<String, dynamic>.from(json['user_profile']))
          : null,
      downloadedAt: json['downloaded_at'] != null
          ? DateTime.tryParse(json['downloaded_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      courseUniversityId: json['course_university_id']?.toString() ?? '',
      courseLevelId: json['course_level_id']?.toString() ?? '',
      courseSemesterId: json['course_semester_id']?.toString() ?? '',
    );
  }

  // Check if this download is valid for the given user profile
  bool isValidForUser(UserProfile userProfile) {
    return courseUniversityId == userProfile.universityId &&
           courseLevelId == userProfile.levelId &&
           courseSemesterId == userProfile.semesterId;
  }

  // Check if downloaded by specific user with specific profile
  bool downloadedBy(UserProfile userProfile) {
    if (this.userProfile == null) return false;
    return userId == userProfile.id && this.userProfile!.matches(userProfile);
  }

  @override
  String toString() {
    return 'DownloadRecord{course: $courseId, user: $userId, at: $downloadedAt}';
  }
}
