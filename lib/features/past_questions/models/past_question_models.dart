// lib/features/past_questions/models/past_question_models.dart
import 'package:flutter/material.dart';

// ==================== PAST QUESTION SESSION ====================

class PastQuestionSession {
  final String id;
  final String name;
  final bool isActive;

  PastQuestionSession({
    required this.id,
    required this.name,
    required this.isActive,
  });

  factory PastQuestionSession.fromJson(Map<String, dynamic> json) {
    return PastQuestionSession(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      isActive: json['is_active'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'is_active': isActive,
    };
  }
}

// ==================== SIMPLIFIED TOPIC MODEL FOR PAST QUESTIONS ====================

class PastQuestionTopic {
  final String id;
  final String title;
  final String? outlineTitle;
  final String? outlineId;
  final String? courseId;
  final String? courseCode;

  PastQuestionTopic({
    required this.id,
    required this.title,
    this.outlineTitle,
    this.outlineId,
    this.courseId,
    this.courseCode,
  });

  factory PastQuestionTopic.fromJson(Map<String, dynamic> json) {
    if (json == null || json is! Map<String, dynamic>) {
      return PastQuestionTopic.empty();
    }

    try {
      // Extract outline info
      final Map<String, dynamic>? outlineInfo = json['outline_info'] is Map 
          ? Map<String, dynamic>.from(json['outline_info'] as Map)
          : null;
      
      // Extract course info
      final Map<String, dynamic>? courseInfo = json['course_info'] is Map
          ? Map<String, dynamic>.from(json['course_info'] as Map)
          : null;
      
      return PastQuestionTopic(
        id: json['id']?.toString() ?? '',
        title: json['title']?.toString() ?? '',
        outlineTitle: outlineInfo?['title']?.toString(),
        outlineId: outlineInfo?['id']?.toString() ?? json['outline']?.toString(),
        courseId: courseInfo?['id']?.toString() ?? outlineInfo?['course_id']?.toString(),
        courseCode: courseInfo?['code']?.toString(),
      );
    } catch (e) {
      print('❌ Error parsing PastQuestionTopic from JSON: $e');
      print('❌ JSON data: $json');
      return PastQuestionTopic.empty();
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'outline_title': outlineTitle,
      'outline_id': outlineId,
      'course_id': courseId,
      'course_code': courseCode,
    };
  }

  // Helper method to create display map (for dropdown)
  Map<String, dynamic> toDisplayMap() {
    return {
      'id': id,
      'title': title,
      'outlineTitle': outlineTitle ?? 'No Outline',
      'outlineId': outlineId ?? '',
    };
  }

  // Check if this is a valid topic
  bool get isValid {
    return id.isNotEmpty && title.isNotEmpty;
  }

  // Create empty topic
  static PastQuestionTopic empty() {
    return PastQuestionTopic(
      id: '',
      title: '',
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PastQuestionTopic && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'PastQuestionTopic(id: $id, title: $title, outline: $outlineTitle)';
  }
}

// ==================== PAST QUESTION ====================

class PastQuestion {
  final String id;
  final Map<String, dynamic> courseInfo;
  final Map<String, dynamic> sessionInfo;
  final Map<String, dynamic>? topicInfo;
  final String? questionText;
  final String? questionImageUrl;
  final bool hasOptions;
  final String? optionA;
  final String? optionB;
  final String? optionC;
  final String? optionD;
  final String correctAnswer;
  final String? solutionText;
  final String? solutionImageUrl;
  final int marks;
  final int difficulty;
  final String? questionNumber;
  final bool isActive;
  final bool isMcq;
  
  // New fields for better filtering and display
  final String? courseId;
  final String? sessionId;
  final String? topicId;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  PastQuestion({
    required this.id,
    required this.courseInfo,
    required this.sessionInfo,
    this.topicInfo,
    this.questionText,
    this.questionImageUrl,
    required this.hasOptions,
    this.optionA,
    this.optionB,
    this.optionC,
    this.optionD,
    required this.correctAnswer,
    this.solutionText,
    this.solutionImageUrl,
    required this.marks,
    required this.difficulty,
    this.questionNumber,
    required this.isActive,
    required this.isMcq,
    // Initialize new fields
    this.courseId,
    this.sessionId,
    this.topicId,
    this.createdAt,
    this.updatedAt,
  });

  factory PastQuestion.fromJson(Map<String, dynamic> json) {
    // Handle the case where json might be null or not a Map
    if (json == null || json is! Map<String, dynamic>) {
      return PastQuestion.empty();
    }

    try {
      return PastQuestion(
        id: json['id']?.toString() ?? '',
        courseInfo: json['course_info'] is Map 
            ? Map<String, dynamic>.from(json['course_info'] as Map) 
            : <String, dynamic>{},
        sessionInfo: json['session_info'] is Map 
            ? Map<String, dynamic>.from(json['session_info'] as Map) 
            : <String, dynamic>{},
        topicInfo: json['topic_info'] is Map 
            ? Map<String, dynamic>.from(json['topic_info'] as Map) 
            : null,
        questionText: json['question_text']?.toString(),
        questionImageUrl: json['question_image_url']?.toString(),
        hasOptions: (json['has_options'] is bool) 
            ? json['has_options'] as bool 
            : (json['has_options']?.toString().toLowerCase() == 'true'),
        optionA: json['option_a']?.toString(),
        optionB: json['option_b']?.toString(),
        optionC: json['option_c']?.toString(),
        optionD: json['option_d']?.toString(),
        correctAnswer: json['correct_answer']?.toString() ?? '',
        solutionText: json['solution_text']?.toString(),
        solutionImageUrl: json['solution_image_url']?.toString(),
        marks: (json['marks'] is int) 
            ? json['marks'] as int 
            : int.tryParse(json['marks']?.toString() ?? '0') ?? 0,
        difficulty: (json['difficulty'] is int) 
            ? (json['difficulty'] as int).clamp(1, 3)
            : int.tryParse(json['difficulty']?.toString() ?? '1')?.clamp(1, 3) ?? 1,
        questionNumber: json['question_number']?.toString(),
        isActive: (json['is_active'] is bool) 
            ? json['is_active'] as bool 
            : (json['is_active']?.toString().toLowerCase() == 'true'),
        isMcq: (json['is_mcq'] is bool) 
            ? json['is_mcq'] as bool 
            : (json['has_options'] is bool) 
                ? json['has_options'] as bool 
                : false,
        // Parse new fields with null safety
        courseId: json['course_id']?.toString() ?? json['course']?.toString(),
        sessionId: json['session_id']?.toString() ?? json['session']?.toString(),
        topicId: json['topic_id']?.toString() ?? json['topic']?.toString(),
        createdAt: json['created_at'] != null 
            ? DateTime.tryParse(json['created_at'].toString()) 
            : null,
        updatedAt: json['updated_at'] != null 
            ? DateTime.tryParse(json['updated_at'].toString()) 
            : null,
      );
    } catch (e) {
      print('❌ Error parsing PastQuestion from JSON: $e');
      print('❌ JSON data: $json');
      return PastQuestion.empty();
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'course_info': courseInfo,
      'session_info': sessionInfo,
      'topic_info': topicInfo,
      'question_text': questionText,
      'question_image_url': questionImageUrl,
      'has_options': hasOptions,
      'option_a': optionA,
      'option_b': optionB,
      'option_c': optionC,
      'option_d': optionD,
      'correct_answer': correctAnswer,
      'solution_text': solutionText,
      'solution_image_url': solutionImageUrl,
      'marks': marks,
      'difficulty': difficulty,
      'question_number': questionNumber,
      'is_active': isActive,
      'is_mcq': isMcq,
      // Include new fields in JSON
      'course_id': courseId,
      'session_id': sessionId,
      'topic_id': topicId,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  // Helper method to get options as a map
  Map<String, String> getOptionsMap() {
    final Map<String, String> options = {};
    
    if (optionA != null && optionA!.isNotEmpty) options['A'] = optionA!;
    if (optionB != null && optionB!.isNotEmpty) options['B'] = optionB!;
    if (optionC != null && optionC!.isNotEmpty) options['C'] = optionC!;
    if (optionD != null && optionD!.isNotEmpty) options['D'] = optionD!;
    
    return options;
  }

  // Get options as a list with letters
  List<Map<String, String>> getOptionsList() {
    final List<Map<String, String>> options = [];
    
    if (optionA != null && optionA!.isNotEmpty) 
      options.add({'letter': 'A', 'text': optionA!});
    if (optionB != null && optionB!.isNotEmpty) 
      options.add({'letter': 'B', 'text': optionB!});
    if (optionC != null && optionC!.isNotEmpty) 
      options.add({'letter': 'C', 'text': optionC!});
    if (optionD != null && optionD!.isNotEmpty) 
      options.add({'letter': 'D', 'text': optionD!});
    
    return options;
  }

  // Get course code from course info
  String get courseCode {
    return courseInfo['code']?.toString() ?? 
           courseInfo['title']?.toString().split(' - ').first ?? 
           '';
  }

  // Get course title from course info
  String get courseTitle {
    return courseInfo['title']?.toString() ?? 
           courseInfo['code']?.toString() ?? 
           '';
  }

  // Get session name from session info
  String get sessionName {
    return sessionInfo['name']?.toString() ?? '';
  }

  // Get topic title from topic info
  String get topicTitle {
    if (topicInfo != null && topicInfo!['title'] != null) {
      return topicInfo!['title']?.toString() ?? 'General';
    }
    return 'General';
  }

  // New helper method to check if question has solution
  bool get hasSolution {
    return (solutionText != null && solutionText!.isNotEmpty) ||
           (solutionImageUrl != null && solutionImageUrl!.isNotEmpty);
  }

  // New helper method to check if question has image
  bool get hasImage {
    return questionImageUrl != null && questionImageUrl!.isNotEmpty;
  }

  // New helper method to get difficulty level as text
  String get difficultyText {
    switch (difficulty) {
      case 1:
        return 'Easy';
      case 2:
        return 'Medium';
      case 3:
        return 'Hard';
      default:
        return 'Medium';
    }
  }

  // New helper method to get difficulty color
  Color get difficultyColor {
    switch (difficulty) {
      case 1:
        return Colors.green;
      case 2:
        return Colors.orange;
      case 3:
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  // New helper method to get formatted question
  String get formattedQuestion {
    if (questionText != null && questionText!.isNotEmpty) {
      return questionText!;
    }
    if (hasImage) {
      return '[Image Question]';
    }
    if (questionNumber != null && questionNumber!.isNotEmpty) {
      return 'Question $questionNumber';
    }
    return 'Question $id';
  }

  // New helper method to check if answer is correct
  bool isAnswerCorrect(String selectedAnswer) {
    if (selectedAnswer.isEmpty || correctAnswer.isEmpty) return false;
    return selectedAnswer.trim().toUpperCase() == correctAnswer.trim().toUpperCase();
  }

  // New helper method to get answer explanation
  String get answerExplanation {
    if (solutionText != null && solutionText!.isNotEmpty) {
      return solutionText!;
    }
    if (correctAnswer.isNotEmpty) {
      return 'The correct answer is $correctAnswer';
    }
    return 'No solution available';
  }

  // Check if this is a valid question
  bool get isValid {
    return id.isNotEmpty && 
           courseInfo.isNotEmpty && 
           sessionInfo.isNotEmpty &&
           ((questionText != null && questionText!.isNotEmpty) ||
           (questionImageUrl != null && questionImageUrl!.isNotEmpty));
  }

  // Get formatted marks
  String get formattedMarks {
    return marks > 0 ? '$marks mark${marks > 1 ? 's' : ''}' : '';
  }

  // Get formatted time (if available)
  String get formattedTime {
    if (createdAt != null) {
      final now = DateTime.now();
      final difference = now.difference(createdAt!);
      
      if (difference.inDays > 30) {
        final months = difference.inDays ~/ 30;
        return '$months month${months > 1 ? 's' : ''} ago';
      } else if (difference.inDays > 0) {
        return '${difference.inDays} day${difference.inDays > 1 ? 's' : ''} ago';
      } else if (difference.inHours > 0) {
        return '${difference.inHours} hour${difference.inHours > 1 ? 's' : ''} ago';
      } else if (difference.inMinutes > 0) {
        return '${difference.inMinutes} minute${difference.inMinutes > 1 ? 's' : ''} ago';
      } else {
        return 'Just now';
      }
    }
    return '';
  }

  // New method to create a copy with updated fields
  PastQuestion copyWith({
    String? id,
    Map<String, dynamic>? courseInfo,
    Map<String, dynamic>? sessionInfo,
    Map<String, dynamic>? topicInfo,
    String? questionText,
    String? questionImageUrl,
    bool? hasOptions,
    String? optionA,
    String? optionB,
    String? optionC,
    String? optionD,
    String? correctAnswer,
    String? solutionText,
    String? solutionImageUrl,
    int? marks,
    int? difficulty,
    String? questionNumber,
    bool? isActive,
    bool? isMcq,
    String? courseId,
    String? sessionId,
    String? topicId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return PastQuestion(
      id: id ?? this.id,
      courseInfo: courseInfo ?? this.courseInfo,
      sessionInfo: sessionInfo ?? this.sessionInfo,
      topicInfo: topicInfo ?? this.topicInfo,
      questionText: questionText ?? this.questionText,
      questionImageUrl: questionImageUrl ?? this.questionImageUrl,
      hasOptions: hasOptions ?? this.hasOptions,
      optionA: optionA ?? this.optionA,
      optionB: optionB ?? this.optionB,
      optionC: optionC ?? this.optionC,
      optionD: optionD ?? this.optionD,
      correctAnswer: correctAnswer ?? this.correctAnswer,
      solutionText: solutionText ?? this.solutionText,
      solutionImageUrl: solutionImageUrl ?? this.solutionImageUrl,
      marks: marks ?? this.marks,
      difficulty: difficulty ?? this.difficulty,
      questionNumber: questionNumber ?? this.questionNumber,
      isActive: isActive ?? this.isActive,
      isMcq: isMcq ?? this.isMcq,
      courseId: courseId ?? this.courseId,
      sessionId: sessionId ?? this.sessionId,
      topicId: topicId ?? this.topicId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  // New method to create empty/default instance
  static PastQuestion empty() {
    return PastQuestion(
      id: '',
      courseInfo: {},
      sessionInfo: {},
      hasOptions: false,
      correctAnswer: '',
      marks: 0,
      difficulty: 1,
      isActive: false,
      isMcq: false,
      courseId: null,
      sessionId: null,
      topicId: null,
      createdAt: null,
      updatedAt: null,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PastQuestion && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'PastQuestion(id: $id, course: $courseCode, session: $sessionName, topic: $topicTitle)';
  }
}