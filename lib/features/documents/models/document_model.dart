// lib/features/documents/models/document_model.dart
import 'dart:math'; 
/// DocumentItem - for local file management (downloaded files)
class DocumentItem {
  final String id;
  final String name;
  final String path;
  final int size;
  final DateTime modifiedAt;
  final String type;
  final bool isStudyGuide; // New field to identify study PDFs
  final String? courseCode; // New: for study guides
  final String? courseName; // New: for study guides
  final String? university; // New: for study guides
  final String? department; // New: for study guides
  final String? fileSizeFormatted; // Formatted size for display
  final String? originalUrl; // Original URL from server

  DocumentItem({
    required this.id,
    required this.name,
    required this.path,
    required this.size,
    required this.modifiedAt,
    required this.type,
    this.isStudyGuide = false,
    this.courseCode,
    this.courseName,
    this.university,
    this.department,
    this.fileSizeFormatted,
    this.originalUrl,
  });

  // Helper method to create from study guide data
  factory DocumentItem.fromStudyGuide({
    required String id,
    required String fileName,
    required String path,
    required int size,
    String? courseCode,
    String? courseName,
    String? university,
    String? department,
    String? fileSizeFormatted,
    String? originalUrl,
  }) {
    return DocumentItem(
      id: id,
      name: fileName,
      path: path,
      size: size,
      modifiedAt: DateTime.now(),
      type: 'PDF',
      isStudyGuide: true,
      courseCode: courseCode,
      courseName: courseName,
      university: university,
      department: department,
      fileSizeFormatted: fileSizeFormatted,
      originalUrl: originalUrl,
    );
  }

  // Helper method to create from StudyDocument
  factory DocumentItem.fromStudyDocument({
    required StudyDocument studyDoc,
    required String path,
    required int size,
  }) {
    return DocumentItem(
      id: studyDoc.id,
      name: studyDoc.fileName,
      path: path,
      size: size,
      modifiedAt: DateTime.now(),
      type: 'PDF',
      isStudyGuide: true,
      courseCode: studyDoc.courseCode,
      courseName: studyDoc.courseName,
      university: studyDoc.university,
      department: studyDoc.department,
      fileSizeFormatted: studyDoc.fileSize,
      originalUrl: studyDoc.fileUrl,
    );
  }

  // Get formatted file size
  String get formattedSize {
    if (fileSizeFormatted != null && fileSizeFormatted!.isNotEmpty) {
      return fileSizeFormatted!;
    }
    return _formatBytes(size);
  }

  // Format bytes to human readable string
  static String _formatBytes(int bytes) {
    if (bytes <= 0) return "0 B";
    const suffixes = ["B", "KB", "MB", "GB", "TB"];
    final i = (log(bytes) / log(1024)).floor();
    return '${(bytes / pow(1024, i)).toStringAsFixed(i > 0 ? 1 : 0)} ${suffixes[i]}';
  }

  // Convert to Map for serialization (for caching)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'path': path,
      'size': size,
      'modifiedAt': modifiedAt.toIso8601String(),
      'type': type,
      'isStudyGuide': isStudyGuide,
      'courseCode': courseCode,
      'courseName': courseName,
      'university': university,
      'department': department,
      'fileSizeFormatted': fileSizeFormatted,
      'originalUrl': originalUrl,
    };
  }

  // Create from Map (for deserialization from cache)
  factory DocumentItem.fromMap(Map<String, dynamic> map) {
    return DocumentItem(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      path: map['path']?.toString() ?? '',
      size: map['size'] is int ? map['size'] as int : 
            map['size'] is String ? int.tryParse(map['size'] as String) ?? 0 : 0,
      modifiedAt: map['modifiedAt'] is DateTime ? map['modifiedAt'] as DateTime :
                  map['modifiedAt'] is String ? DateTime.parse(map['modifiedAt'] as String) :
                  DateTime.now(),
      type: map['type']?.toString() ?? 'PDF',
      isStudyGuide: map['isStudyGuide'] is bool ? map['isStudyGuide'] as bool : false,
      courseCode: map['courseCode']?.toString(),
      courseName: map['courseName']?.toString(),
      university: map['university']?.toString(),
      department: map['department']?.toString(),
      fileSizeFormatted: map['fileSizeFormatted']?.toString(),
      originalUrl: map['originalUrl']?.toString(),
    );
  }

  // Copy with method for immutability
  DocumentItem copyWith({
    String? id,
    String? name,
    String? path,
    int? size,
    DateTime? modifiedAt,
    String? type,
    bool? isStudyGuide,
    String? courseCode,
    String? courseName,
    String? university,
    String? department,
    String? fileSizeFormatted,
    String? originalUrl,
  }) {
    return DocumentItem(
      id: id ?? this.id,
      name: name ?? this.name,
      path: path ?? this.path,
      size: size ?? this.size,
      modifiedAt: modifiedAt ?? this.modifiedAt,
      type: type ?? this.type,
      isStudyGuide: isStudyGuide ?? this.isStudyGuide,
      courseCode: courseCode ?? this.courseCode,
      courseName: courseName ?? this.courseName,
      university: university ?? this.university,
      department: department ?? this.department,
      fileSizeFormatted: fileSizeFormatted ?? this.fileSizeFormatted,
      originalUrl: originalUrl ?? this.originalUrl,
    );
  }
}

/// StudyDocument - for API response (study guides from Django)
class StudyDocument {
  final String id;
  final String title;
  final String fileName;
  final String fileUrl;
  final String fileSize;
  final String courseCode;
  final String courseName;
  final String university;
  final String department;
  final int level;
  final int semester;
  final DateTime? uploadedAt;
  final bool isActive;
  final List<String>? departmentNames;
  final String? faculty;
  final String? levelName;
  final String? semesterName;

  StudyDocument({
    required this.id,
    required this.title,
    required this.fileName,
    required this.fileUrl,
    required this.fileSize,
    required this.courseCode,
    required this.courseName,
    required this.university,
    required this.department,
    required this.level,
    required this.semester,
    this.uploadedAt,
    this.isActive = true,
    this.departmentNames,
    this.faculty,
    this.levelName,
    this.semesterName,
  });

  // Factory constructor from JSON/Map
  factory StudyDocument.fromMap(Map<String, dynamic> map) {
    // Parse department names from list
    List<String>? deptNames;
    if (map['departments'] is List) {
      deptNames = [];
      for (var dept in map['departments'] as List) {
        if (dept is Map && dept['name'] != null) {
          deptNames.add(dept['name'].toString());
        }
      }
    }

    // Parse uploaded date
    DateTime? uploadedDate;
    if (map['uploaded_at'] != null) {
      if (map['uploaded_at'] is String) {
        uploadedDate = DateTime.tryParse(map['uploaded_at'] as String);
      }
    }

    return StudyDocument(
      id: map['id']?.toString() ?? 'unknown',
      title: map['name']?.toString() ?? 'Untitled',
      fileName: map['file_name']?.toString() ?? 
               _extractFileNameFromUrl(map['pdf_url']?.toString()) ?? 
               'document.pdf',
      fileUrl: map['pdf_url']?.toString() ?? map['pdf_file']?.toString() ?? '',
      fileSize: _parseFileSize(map),
      courseCode: map['course_code']?.toString() ?? 'GEN',
      courseName: map['course_name']?.toString() ?? 'General',
      university: map['university_name']?.toString() ?? 
                 _extractName(map['university']) ??
                 'Unknown University',
      department: _extractDepartmentDisplay(map['departments']),
      level: _parseLevel(map['level'] ?? map['level_id']),
      semester: _parseSemester(map['semester'] ?? map['semester_id']),
      uploadedAt: uploadedDate,
      isActive: map['is_active'] is bool ? map['is_active'] as bool : true,
      departmentNames: deptNames,
      faculty: map['faculty_name']?.toString() ?? 
               _extractName(map['faculty']),
      levelName: map['level_name']?.toString() ?? 
                 _extractName(map['level']),
      semesterName: map['semester_name']?.toString() ?? 
                    _extractName(map['semester']),
    );
  }

  // Convert to Map for serialization (for caching)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': title,
      'file_name': fileName,
      'pdf_url': fileUrl,
      'file_size': fileSize,
      'course_code': courseCode,
      'course_name': courseName,
      'university_name': university,
      'departments': departmentNames?.map((name) => {'name': name}).toList(),
      'department_display': department,
      'level': level,
      'semester': semester,
      'uploaded_at': uploadedAt?.toIso8601String(),
      'is_active': isActive,
      'faculty_name': faculty,
      'level_name': levelName,
      'semester_name': semesterName,
    };
  }

  // Get display text for level and semester
  String get levelDisplay {
    if (levelName != null && levelName!.isNotEmpty) {
      return levelName!;
    }
    return 'Level $level';
  }

  String get semesterDisplay {
    if (semesterName != null && semesterName!.isNotEmpty) {
      return semesterName!;
    }
    return 'Semester $semester';
  }

  // Check if file is downloadable
  bool get isDownloadable => fileUrl.isNotEmpty && fileUrl.startsWith('http');

  // Check if file is from Cloudinary
  bool get isCloudinaryFile => fileUrl.contains('cloudinary.com');

  // Copy with method for immutability
  StudyDocument copyWith({
    String? id,
    String? title,
    String? fileName,
    String? fileUrl,
    String? fileSize,
    String? courseCode,
    String? courseName,
    String? university,
    String? department,
    int? level,
    int? semester,
    DateTime? uploadedAt,
    bool? isActive,
    List<String>? departmentNames,
    String? faculty,
    String? levelName,
    String? semesterName,
  }) {
    return StudyDocument(
      id: id ?? this.id,
      title: title ?? this.title,
      fileName: fileName ?? this.fileName,
      fileUrl: fileUrl ?? this.fileUrl,
      fileSize: fileSize ?? this.fileSize,
      courseCode: courseCode ?? this.courseCode,
      courseName: courseName ?? this.courseName,
      university: university ?? this.university,
      department: department ?? this.department,
      level: level ?? this.level,
      semester: semester ?? this.semester,
      uploadedAt: uploadedAt ?? this.uploadedAt,
      isActive: isActive ?? this.isActive,
      departmentNames: departmentNames ?? this.departmentNames,
      faculty: faculty ?? this.faculty,
      levelName: levelName ?? this.levelName,
      semesterName: semesterName ?? this.semesterName,
    );
  }

  // Static helper methods
  static String _extractFileNameFromUrl(String? url) {
    if (url == null || url.isEmpty) return 'document.pdf';
    try {
      final uri = Uri.parse(url);
      final pathSegments = uri.pathSegments;
      if (pathSegments.isNotEmpty) {
        return pathSegments.last.split('?').first;
      }
    } catch (e) {
      print('Error extracting filename: $e');
    }
    return 'document.pdf';
  }

  static String _parseFileSize(Map<String, dynamic> map) {
    if (map['file_size'] != null) {
      return map['file_size'].toString();
    }
    if (map['size'] != null) {
      return map['size'].toString();
    }
    return 'Unknown size';
  }

  static String _extractName(dynamic data) {
    if (data == null) return '';
    if (data is Map) {
      if (data['name'] != null) return data['name'].toString();
      if (data['title'] != null) return data['title'].toString();
    }
    if (data is String) return data;
    return '';
  }

  static String _extractDepartmentDisplay(dynamic departmentsData) {
    if (departmentsData == null) return 'Multiple Departments';
    
    try {
      if (departmentsData is List) {
        final names = <String>[];
        for (var dept in departmentsData) {
          if (dept is Map && dept['name'] != null) {
            names.add(dept['name'].toString());
          }
        }
        if (names.isEmpty) return 'Multiple Departments';
        if (names.length > 3) {
          return '${names.take(3).join(', ')}, +${names.length - 3} more';
        }
        return names.join(', ');
      }
      if (departmentsData is Map && departmentsData['name'] != null) {
        return departmentsData['name'].toString();
      }
      if (departmentsData is String) return departmentsData;
    } catch (e) {
      print('Error extracting department display: $e');
    }
    
    return 'Multiple Departments';
  }

  static int _parseLevel(dynamic levelData) {
    if (levelData == null) return 1;
    
    if (levelData is Map) {
      if (levelData['level_number'] != null) {
        return int.tryParse(levelData['level_number'].toString()) ?? 1;
      }
      if (levelData['value'] != null) {
        return int.tryParse(levelData['value'].toString()) ?? 1;
      }
      if (levelData['name'] != null) {
        final name = levelData['name'].toString().toLowerCase();
        if (name.contains('100')) return 1;
        if (name.contains('200')) return 2;
        if (name.contains('300')) return 3;
        if (name.contains('400')) return 4;
        if (name.contains('500')) return 5;
      }
      if (levelData['id'] != null) {
        return int.tryParse(levelData['id'].toString()) ?? 1;
      }
    }
    if (levelData is int) return levelData;
    if (levelData is String) return int.tryParse(levelData) ?? 1;
    
    return 1;
  }

  static int _parseSemester(dynamic semesterData) {
    if (semesterData == null) return 1;
    
    if (semesterData is Map) {
      if (semesterData['semester_number'] != null) {
        return int.tryParse(semesterData['semester_number'].toString()) ?? 1;
      }
      if (semesterData['value'] != null) {
        return int.tryParse(semesterData['value'].toString()) ?? 1;
      }
      if (semesterData['name'] != null) {
        final name = semesterData['name'].toString().toLowerCase();
        if (name.contains('first') || name.contains('1')) return 1;
        if (name.contains('second') || name.contains('2')) return 2;
      }
      if (semesterData['id'] != null) {
        return int.tryParse(semesterData['id'].toString()) ?? 1;
      }
    }
    if (semesterData is int) return semesterData;
    if (semesterData is String) return int.tryParse(semesterData) ?? 1;
    
    return 1;
  }
}

/// Extension for easy conversion
extension StudyDocumentExtensions on StudyDocument {
  DocumentItem toDocumentItem({
    required String path,
    required int size,
  }) {
    return DocumentItem.fromStudyDocument(
      studyDoc: this,
      path: path,
      size: size,
    );
  }
}

/// Extension for DocumentItem
extension DocumentItemExtensions on DocumentItem {
  StudyDocument toStudyDocument() {
    return StudyDocument(
      id: id,
      title: name,
      fileName: name,
      fileUrl: originalUrl ?? '',
      fileSize: formattedSize,
      courseCode: courseCode ?? 'GEN',
      courseName: courseName ?? 'General',
      university: university ?? 'Unknown University',
      department: department ?? 'Multiple Departments',
      level: 1, // Default if not available
      semester: 1, // Default if not available
    );
  }
}