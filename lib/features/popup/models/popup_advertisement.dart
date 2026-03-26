// lib/features/popup/models/popup_advertisement.dart
import '../../../core/constants/endpoints.dart';

class PopupAdvertisement {
  final int id;
  final String? title;
  final String imageUrl;
  final String? targetUrl;
  final String? description;
  final String displayFrequency;
  final int showDelay;
  final int hoursBeforeShow;
  final int intervalHours;
  final bool trackUserViews;
  final String targetType;
  final List<int>? universities;
  final List<int>? faculties;
  final String activationTarget;
  final String? activationGrades;
  final String showToNonActivated;
  final String activationMessage;
  final bool isActive;
  final DateTime startDate;
  final DateTime? endDate;
  final int priority;
  final int totalImpressions;
  final int totalClicks;
  final bool requiresActivation;
  final String? activationPrompt;

  PopupAdvertisement({
    required this.id,
    this.title,
    required this.imageUrl,
    this.targetUrl,
    this.description,
    required this.displayFrequency,
    required this.showDelay,
    required this.hoursBeforeShow,
    required this.intervalHours,
    required this.trackUserViews,
    required this.targetType,
    this.universities,
    this.faculties,
    required this.activationTarget,
    this.activationGrades,
    required this.showToNonActivated,
    required this.activationMessage,
    required this.isActive,
    required this.startDate,
    this.endDate,
    required this.priority,
    required this.totalImpressions,
    required this.totalClicks,
    required this.requiresActivation,
    this.activationPrompt,
  });

  factory PopupAdvertisement.fromJson(Map<String, dynamic> json) {
    // Helper methods for safe parsing
    int safeInt(dynamic value, [int defaultValue = 0]) {
      if (value == null) return defaultValue;
      if (value is int) return value;
      if (value is String) {
        return int.tryParse(value) ?? defaultValue;
      }
      if (value is double) return value.toInt();
      if (value is bool) return value ? 1 : 0;
      return defaultValue;
    }

    String safeString(dynamic value, [String defaultValue = '']) {
      if (value == null) return defaultValue;
      if (value is String) return value;
      return value.toString();
    }

    bool safeBool(dynamic value, [bool defaultValue = false]) {
      if (value == null) return defaultValue;
      if (value is bool) return value;
      if (value is String) {
        final lower = value.toLowerCase();
        return lower == 'true' || lower == '1' || lower == 'yes';
      }
      if (value is int) return value != 0;
      return defaultValue;
    }

    DateTime safeDateTime(dynamic value) {
      if (value == null) return DateTime.now();
      if (value is DateTime) return value;
      if (value is String) {
        try {
          return DateTime.parse(value);
        } catch (e) {
          return DateTime.now();
        }
      }
      return DateTime.now();
    }

    List<int>? safeIntList(dynamic value) {
      if (value == null) return null;
      if (value is List) {
        try {
          return value.map((e) => safeInt(e)).toList();
        } catch (e) {
          return null;
        }
      }
      return null;
    }

    return PopupAdvertisement(
      id: safeInt(json['id']),
      title: json['title'] != null ? safeString(json['title']) : null,
      imageUrl: safeString(json['image_url'] ?? json['image']),
      targetUrl: json['target_url'] != null
          ? safeString(json['target_url'])
          : null,
      description: json['description'] != null
          ? safeString(json['description'])
          : null,
      displayFrequency: safeString(json['display_frequency'], 'first_open'),
      showDelay: safeInt(json['show_delay'], 3),
      hoursBeforeShow: safeInt(json['hours_before_show'], 24),
      intervalHours: safeInt(json['interval_hours'], 4),
      trackUserViews: safeBool(json['track_user_views'], true),
      targetType: safeString(json['target_type'], 'general'),
      universities: safeIntList(json['universities']),
      faculties: safeIntList(json['faculties']),
      activationTarget: safeString(json['activation_target'], 'all'),
      activationGrades: json['activation_grades'] != null
          ? safeString(json['activation_grades'])
          : null,
      showToNonActivated: safeString(json['show_to_non_activated'], 'show'),
      activationMessage: safeString(json['activation_message'], ''),
      isActive: safeBool(json['is_active'], true),
      startDate: safeDateTime(json['start_date']),
      endDate: json['end_date'] != null ? safeDateTime(json['end_date']) : null,
      priority: safeInt(json['priority'], 0),
      totalImpressions: safeInt(json['total_impressions'], 0),
      totalClicks: safeInt(json['total_clicks'], 0),
      requiresActivation: safeBool(json['requires_activation'], false),
      activationPrompt: json['activation_prompt'] != null
          ? safeString(json['activation_prompt'])
          : null,
    );
  }

  // Convert to JSON for storage
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'image_url': imageUrl,
      'target_url': targetUrl,
      'description': description,
      'display_frequency': displayFrequency,
      'show_delay': showDelay,
      'hours_before_show': hoursBeforeShow,
      'interval_hours': intervalHours,
      'track_user_views': trackUserViews,
      'target_type': targetType,
      'universities': universities,
      'faculties': faculties,
      'activation_target': activationTarget,
      'activation_grades': activationGrades,
      'show_to_non_activated': showToNonActivated,
      'activation_message': activationMessage,
      'is_active': isActive,
      'start_date': startDate.toIso8601String(),
      'end_date': endDate?.toIso8601String(),
      'priority': priority,
      'total_impressions': totalImpressions,
      'total_clicks': totalClicks, // FIXED: Changed totalCliks to totalClicks
      'requires_activation': requiresActivation,
      'activation_prompt': activationPrompt,
    };
  }

  // Helper methods
  bool get isGeneral => targetType == 'general';
  bool get isTargeted => targetType == 'targeted';

  List<String> get activationGradesList {
    if (activationGrades == null || activationGrades!.isEmpty) return [];
    return activationGrades!.split(',').map((g) => g.trim()).toList();
  }

  bool get hasTargetUrl => targetUrl != null && targetUrl!.isNotEmpty;

  bool get shouldShowActivationPrompt {
    return requiresActivation && showToNonActivated == 'show';
  }

  // Check if popup is currently valid
  bool get isValid {
    final now = DateTime.now();
    if (!isActive) return false;
    if (startDate.isAfter(now)) return false;
    if (endDate != null && endDate!.isBefore(now)) return false;
    return true;
  }

  // Get image display URL (handle relative URLs)
  // String get displayImageUrl {
  //   if (imageUrl.startsWith('http')) return imageUrl;
  //   if (imageUrl.startsWith('/')) {
  //     // Assuming you have a base URL constant
  //     return 'http://127.0.0.1:8000$imageUrl'; // Adjust to your actual base URL
  //   }
  //   return imageUrl;
  // }

  // Get image display URL using base URL from endpoints
  String get displayImageUrl {
    if (imageUrl.startsWith('http')) return imageUrl;
    if (imageUrl.startsWith('/')) {
      // Use baseUrl from endpoints without trailing slash
      final baseUrl = ApiEndpoints.baseUrl;
      // Remove trailing slash from baseUrl if present
      final cleanBaseUrl = baseUrl.endsWith('/')
          ? baseUrl.substring(0, baseUrl.length - 1)
          : baseUrl;
      return '$cleanBaseUrl$imageUrl';
    }
    return imageUrl;
  }

  @override
  String toString() {
    return 'PopupAdvertisement(id: $id, title: $title, isValid: $isValid)';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PopupAdvertisement &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
