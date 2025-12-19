// lib/features/auth/models/onboarding_models.dart
class University {
  final String id;
  final String name;
  final String? abbreviation;
  final String? country;
  final String? imagePath;

  const University({
    required this.id,
    required this.name,
    this.abbreviation,
    this.country,
    this.imagePath,
  });

  factory University.fromJson(Map<String, dynamic> json) {
    return University(
      id: json['id'].toString(),
      name: json['name'],
      abbreviation: json['abbreviation'],
      country: json['country'],
      imagePath: json['image_url'] ?? json['image'],
    );
  }

  @override
  String toString() => name;
}

class Faculty {
  final String id;
  final String name;
  final String? abbreviation;
  final String universityId;

  const Faculty({
    required this.id,
    required this.name,
    this.abbreviation,
    required this.universityId,
  });

  factory Faculty.fromJson(Map<String, dynamic> json) {
    return Faculty(
      id: json['id'].toString(),
      name: json['name'],
      abbreviation: json['abbreviation'],
      universityId: json['university_id'].toString(),
    );
  }

  @override
  String toString() => name;
}

class Department {
  final String id;
  final String name;
  final String? abbreviation;
  final String facultyId;

  const Department({
    required this.id,
    required this.name,
    this.abbreviation,
    required this.facultyId,
  });

  factory Department.fromJson(Map<String, dynamic> json) {
    return Department(
      id: json['id'].toString(),
      name: json['name'],
      abbreviation: json['abbreviation'],
      facultyId: json['faculty_id'].toString(),
    );
  }

  @override
  String toString() => name;
}

class Level {
  final String id;
  final String name;
  final int value;

  const Level({
    required this.id,
    required this.name,
    required this.value,
  });

  factory Level.fromJson(Map<String, dynamic> json) {
    return Level(
      id: json['id'].toString(),
      name: json['name'],
      value: json['value'],
    );
  }

  @override
  String toString() => name;
}

class Semester {
  final String id;
  final String name;
  final int value;

  const Semester({
    required this.id,
    required this.name,
    required this.value,
  });

  factory Semester.fromJson(Map<String, dynamic> json) {
    return Semester(
      id: json['id'].toString(),
      name: json['name'],
      value: json['value'],
    );
  }

  @override
  String toString() => name;
}

class AcademicSession {
  final String id;
  final String name;
  final String value;

  const AcademicSession({
    required this.id,
    required this.name,
    required this.value,
  });

  @override
  String toString() => name;
}

class UserOnboardingData {
  final University? university;
  final Faculty? faculty;
  final Department? department;
  final Level? level;
  final Semester? semester;
  final AcademicSession? academicSession;

  const UserOnboardingData({
    this.university,
    this.faculty,
    this.department,
    this.level,
    this.semester,
    this.academicSession,
  });

  // Add static empty instance for const usage
  static const UserOnboardingData empty = UserOnboardingData();

  UserOnboardingData copyWith({
    University? university,
    Faculty? faculty,
    Department? department,
    Level? level,
    Semester? semester,
    AcademicSession? academicSession,
  }) {
    return UserOnboardingData(
      university: university ?? this.university,
      faculty: faculty ?? this.faculty,
      department: department ?? this.department,
      level: level ?? this.level,
      semester: semester ?? this.semester,
      academicSession: academicSession ?? this.academicSession,
    );
  }
}