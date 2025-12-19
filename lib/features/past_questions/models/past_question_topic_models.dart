// lib/features/past_questions/models/past_question_topic_models.dart
import 'package:flutter/material.dart';

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

  // Helper method to create display map (for dropdown)
  Map<String, dynamic> toDisplayMap() {
    return {
      'id': id,
      'title': title,
      'outlineTitle': outlineTitle,
      'outlineId': outlineId,
    };
  }

  static PastQuestionTopic empty() {
    return PastQuestionTopic(
      id: '',
      title: '',
    );
  }

  @override
  String toString() {
    return 'PastQuestionTopic(id: $id, title: $title, outline: $outlineTitle)';
  }
}