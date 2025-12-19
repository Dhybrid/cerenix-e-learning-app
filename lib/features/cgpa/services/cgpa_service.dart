// lib/features/cgpa/services/cgpa_service.dart
import 'package:hive/hive.dart';
import '../models/cgpa_models.dart';

class CGPAService {
  static const String _boxName = 'cgpa_box';
  
  /// Get the box
  static Box get _box {
    if (!Hive.isBoxOpen(_boxName)) {
      throw Exception('CGPA box is not open! Check main.dart initialization.');
    }
    return Hive.box(_boxName);
  }

  /// Save CGPA data - SIMPLE AND RELIABLE
  static Future<void> saveCGPAData(String userId, List<CGPALevel> levels) async {
    try {
      print('💾 [SAVE] User: $userId, Levels: ${levels.length}');
      
      // Debug: Print what we're saving
      for (var i = 0; i < levels.length; i++) {
        final level = levels[i];
        print('   Level $i: ${level.level}');
        print('   1st Sem: ${level.firstSemester.length} courses');
        print('   2nd Sem: ${level.secondSemester.length} courses');
      }
      
      // Save directly
      await _box.put('cgpa_$userId', levels);
      print('✅ Save successful');
      
    } catch (e) {
      print('❌ SAVE ERROR: $e');
      
      // More detailed error info
      if (e is HiveError) {
        print('   HiveError: ${e.message}');
        print('   Stack trace: ${e.stackTrace}');
      }
      
      rethrow;
    }
  }

  /// Load CGPA data - SIMPLE AND RELIABLE
  static Future<List<CGPALevel>> getCGPAData(String userId) async {
    try {
      print('📥 [LOAD] User: $userId');
      
      final dynamic rawData = _box.get('cgpa_$userId');
      
      if (rawData == null) {
        print('ℹ️ No data found for user: $userId');
        return [];
      }
      
      print('   Raw data type: ${rawData.runtimeType}');
      
      // Direct cast - should work if adapters are registered
      if (rawData is List) {
        print('   Data is List, length: ${rawData.length}');
        
        if (rawData.isEmpty) {
          return [];
        }
        
        // Check first item type
        final firstItem = rawData.first;
        print('   First item type: ${firstItem.runtimeType}');
        
        if (firstItem is CGPALevel) {
          print('   ✅ Valid CGPALevel objects found');
          return List<CGPALevel>.from(rawData);
        } else {
          print('   ⚠️ First item is NOT CGPALevel, it\'s: ${firstItem.runtimeType}');
          print('   Clearing corrupted data...');
          await _box.delete('cgpa_$userId');
          return [];
        }
      }
      
      print('   ❌ Data is not a List, it\'s: ${rawData.runtimeType}');
      return [];
      
    } catch (e) {
      print('❌ LOAD ERROR: $e');
      return [];
    }
  }

  /// Test function to verify adapters work
  static Future<void> testAdapters() async {
    print('🧪 Testing CGPA adapters...');
    
    try {
      // Create test objects
      final testCourse = CGPACourse(code: 'TEST101', unit: 3, grade: 'A');
      final testLevel = CGPALevel(
        level: '100',
        firstSemester: [testCourse],
        secondSemester: [],
      );
      
      print('   ✅ Test objects created');
      
      // Save test
      await _box.put('__test__', [testLevel]);
      print('   ✅ Test save successful');
      
      // Load test
      final loaded = _box.get('__test__');
      print('   ✅ Test load successful');
      print('   Loaded type: ${loaded.runtimeType}');
      
      // Clean up
      await _box.delete('__test__');
      print('   ✅ Test cleanup complete');
      
    } catch (e) {
      print('   ❌ Test failed: $e');
    }
  }

  /// Debug: Print all data
  static void debugPrintAll() {
    print('📦 === CGPA BOX DEBUG ===');
    print('🔑 Box: $_boxName');
    print('🔓 Is open: ${_box.isOpen}');
    print('🔑 Keys: ${_box.keys.toList()}');
    
    for (var key in _box.keys) {
      final value = _box.get(key);
      print('\n--- Key: $key ---');
      print('   Type: ${value.runtimeType}');
      
      if (value is List) {
        print('   Length: ${value.length}');
        if (value.isNotEmpty) {
          final first = value.first;
          print('   First item type: ${first.runtimeType}');
          
          if (first is CGPALevel) {
            print('   ✅ Valid CGPALevel');
            print('   Level: ${first.level}');
            print('   1st Sem courses: ${first.firstSemester.length}');
            print('   2nd Sem courses: ${first.secondSemester.length}');
          } else {
            print('   ❌ NOT CGPALevel: ${first.runtimeType}');
          }
        }
      }
    }
  }
}