// lib/features/cgpa/models/cgpa_models.dart
import 'package:hive/hive.dart';

part 'cgpa_models.g.dart';

@HiveType(typeId: 10)
class CGPALevel {
  @HiveField(0)
  final String level;
  
  @HiveField(1)
  final List<CGPACourse> firstSemester;
  
  @HiveField(2)
  final List<CGPACourse> secondSemester;

  CGPALevel({
    required this.level,
    required this.firstSemester,
    required this.secondSemester,
  });

  // Convert to Map for easy serialization
  Map<String, dynamic> toMap() {
    return {
      'level': level,
      'firstSemester': firstSemester.map((course) => course.toMap()).toList(),
      'secondSemester': secondSemester.map((course) => course.toMap()).toList(),
    };
  }

  // Create from Map
  factory CGPALevel.fromMap(Map<String, dynamic> map) {
    return CGPALevel(
      level: map['level'] ?? '',
      firstSemester: List<CGPACourse>.from(
        (map['firstSemester'] as List).map((course) => CGPACourse.fromMap(course))
      ),
      secondSemester: List<CGPACourse>.from(
        (map['secondSemester'] as List).map((course) => CGPACourse.fromMap(course))
      ),
    );
  }
}

@HiveType(typeId: 11)
class CGPACourse {
  @HiveField(0)
  final String code;
  
  @HiveField(1)
  final int unit;
  
  @HiveField(2)
  final String grade;

  CGPACourse({
    required this.code,
    required this.unit,
    required this.grade,
  });

  // Convert to Map for easy serialization
  Map<String, dynamic> toMap() {
    return {
      'code': code,
      'unit': unit,
      'grade': grade,
    };
  }

  // Create from Map
  factory CGPACourse.fromMap(Map<String, dynamic> map) {
    return CGPACourse(
      code: map['code'] ?? '',
      unit: map['unit'] ?? 0,
      grade: map['grade'] ?? 'A',
    );
  }
}