// lib/features/auth/models/user_profile.dart
import 'package:hive/hive.dart';

part 'user_profile.g.dart';

@HiveType(typeId: 10) // Use a unique typeId
class UserProfile {
  @HiveField(0)
  final String id;
  
  @HiveField(1)
  final String universityId;
  
  @HiveField(2)
  final String universityName;
  
  @HiveField(3)
  final String departmentId;
  
  @HiveField(4)
  final String departmentName;
  
  @HiveField(5)
  final String levelId;
  
  @HiveField(6)
  final String levelName;
  
  @HiveField(7)
  final String semesterId;
  
  @HiveField(8)
  final String semesterName;
  
  @HiveField(9)
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

  // Check if this profile matches another profile
  bool matches(UserProfile other) {
    return universityId == other.universityId &&
           departmentId == other.departmentId &&
           levelId == other.levelId &&
           semesterId == other.semesterId;
  }

  // Create a unique key for storage
  String get storageKey => '${universityId}_${departmentId}_${levelId}_${semesterId}';
}