// // lib/features/cgpa/services/cgpa_service.dart
// import 'package:hive/hive.dart';
// import '../models/cgpa_models.dart';

// class CGPAService {
//   static const String _boxName = 'cgpa_box';
//   static Box? _boxInstance;
//   static bool _isInitializing = false;

//   /// Get the box - singleton pattern to prevent multiple openings
//   static Future<Box> get _box async {
//     // Return existing instance if available and open
//     if (_boxInstance != null && _boxInstance!.isOpen) {
//       return _boxInstance!;
//     }

//     // Prevent concurrent initialization
//     if (_isInitializing) {
//       print('⏳ CGPA box initialization already in progress, waiting...');
//       await Future.delayed(const Duration(milliseconds: 100));
//       return await _box;
//     }

//     _isInitializing = true;

//     try {
//       print('📦 Initializing CGPA box...');

//       // Check if box is already open globally (by Hive)
//       if (Hive.isBoxOpen(_boxName)) {
//         print('ℹ️ CGPA box is already open globally, reusing...');
//         _boxInstance = Hive.box(_boxName);
//         _isInitializing = false;
//         return _boxInstance!;
//       }

//       // Register adapters if needed (safety check)
//       try {
//         if (!Hive.isAdapterRegistered(10)) {
//           Hive.registerAdapter(CGPALevelAdapter());
//           print('✅ Registered CGPALevelAdapter (typeId: 10)');
//         }
//         if (!Hive.isAdapterRegistered(11)) {
//           Hive.registerAdapter(CGPACourseAdapter());
//           print('✅ Registered CGPACourseAdapter (typeId: 11)');
//         }
//       } catch (e) {
//         print('⚠️ Adapter registration check: $e');
//       }

//       // Try to open with proper type
//       print('🚀 Opening CGPA box as List<CGPALevel>...');

//       // Clear any previous errors by deleting corrupted box first
//       // try {
//       //   if (await Hive.boxExists(_boxName)) {
//       //     print('🔄 Deleting potentially corrupted box...');
//       //     await Hive.deleteBoxFromDisk(_boxName);
//       //     print('🗑️ Old box deleted');
//       //   }
//       // } catch (e) {
//       //   print('⚠️ Could not delete old box: $e');
//       // }

//       // Open fresh box
//       _boxInstance = await Hive.openBox<List<CGPALevel>>(_boxName);

//       print('✅ CGPA box opened successfully as List<CGPALevel>');
//       print('   Box path: ${_boxInstance!.path}');
//       print('   Is open: ${_boxInstance!.isOpen}');

//       return _boxInstance!;
//     } catch (e) {
//       print('❌ Failed to open as List<CGPALevel>: $e');

//       // Last resort: try dynamic type
//       try {
//         print('🔄 Attempting to open as dynamic type...');

//         if (await Hive.boxExists(_boxName)) {
//           await Hive.deleteBoxFromDisk(_boxName);
//         }

//         _boxInstance = await Hive.openBox(_boxName);
//         print('✅ CGPA box opened as dynamic type');
//         return _boxInstance!;
//       } catch (e2) {
//         print('❌❌ Failed to open CGPA box at all: $e2');
//         _isInitializing = false;
//         rethrow;
//       }
//     } finally {
//       _isInitializing = false;
//     }
//   }

//   /// Save CGPA data - simplified and reliable
//   static Future<void> saveCGPAData(
//     String userId,
//     List<CGPALevel> levels,
//   ) async {
//     if (userId.isEmpty) {
//       print('⚠️ Cannot save: userId is empty');
//       return;
//     }

//     try {
//       print('💾 [SAVE] User: $userId, Levels: ${levels.length}');

//       final box = await _box;
//       final key = 'cgpa_$userId';

//       // Debug print what we're saving
//       for (var i = 0; i < levels.length; i++) {
//         final level = levels[i];
//         print('   Level $i: ${level.level}');
//         print('   1st Sem courses: ${level.firstSemester.length}');
//         print('   2nd Sem courses: ${level.secondSemester.length}');
//       }

//       // Save the data
//       await box.put(key, levels);

//       // Verify save worked
//       final savedData = box.get(key);
//       print('✅ Save successful!');
//       print('   Saved type: ${savedData.runtimeType}');
//       print('   Saved length: ${savedData is List ? savedData.length : 'N/A'}');
//     } catch (e) {
//       print('❌ Error saving CGPA data: $e');

//       // Fallback: try to save as JSON
//       try {
//         print('🔄 Attempting JSON fallback save...');
//         final box = await _box;
//         final key = 'cgpa_${userId}_json';
//         final jsonData = levels.map((level) => level.toMap()).toList();
//         await box.put(key, jsonData);
//         print('✅ JSON fallback save successful');
//       } catch (e2) {
//         print('❌ JSON fallback also failed: $e2');
//         rethrow;
//       }
//     }
//   }

//   /// Load CGPA data - simplified and reliable
//   static Future<List<CGPALevel>> getCGPAData(String userId) async {
//     if (userId.isEmpty) {
//       print('⚠️ Cannot load: userId is empty');
//       return [];
//     }

//     try {
//       print('📥 [LOAD] User: $userId');

//       final box = await _box;
//       final key = 'cgpa_$userId';
//       final jsonKey = 'cgpa_${userId}_json';

//       // First try direct load
//       final rawData = box.get(key);

//       if (rawData == null) {
//         print('ℹ️ No direct data found, checking JSON fallback...');
//         final jsonData = box.get(jsonKey);

//         if (jsonData != null && jsonData is List) {
//           print('✅ Found JSON data, converting...');
//           return jsonData.map((data) => CGPALevel.fromMap(data)).toList();
//         }

//         print('ℹ️ No CGPA data found for user: $userId');
//         return [];
//       }

//       print('   Raw data type: ${rawData.runtimeType}');

//       if (rawData is List<CGPALevel>) {
//         print('✅ Valid List<CGPALevel> found');
//         return rawData;
//       } else if (rawData is List) {
//         print('ℹ️ List found (type checking)...');

//         if (rawData.isEmpty) {
//           return [];
//         }

//         // Check if first item is CGPALevel
//         final firstItem = rawData.first;
//         if (firstItem is CGPALevel) {
//           print('✅ First item is CGPALevel, casting list...');
//           return List<CGPALevel>.from(rawData);
//         } else if (firstItem is Map) {
//           print('⚠️ First item is Map, converting from Map...');
//           return rawData.map((data) => CGPALevel.fromMap(data)).toList();
//         } else {
//           print('❌ Unknown item type: ${firstItem.runtimeType}');
//           return [];
//         }
//       } else {
//         print('❌ Unexpected data type: ${rawData.runtimeType}');
//         return [];
//       }
//     } catch (e) {
//       print('❌ Error loading CGPA data: $e');
//       return [];
//     }
//   }

//   /// Clear all CGPA data for a user
//   static Future<void> clearUserData(String userId) async {
//     try {
//       final box = await _box;
//       await box.delete('cgpa_$userId');
//       await box.delete('cgpa_${userId}_json');
//       await box.delete('cgpa_${userId}_format');
//       print('✅ Cleared CGPA data for user: $userId');
//     } catch (e) {
//       print('⚠️ Error clearing user data: $e');
//     }
//   }

//   /// Clear ALL CGPA data (for debugging/reset)
//   static Future<void> clearAllData() async {
//     try {
//       final box = await _box;
//       await box.clear();
//       print('✅ Cleared ALL CGPA data');
//     } catch (e) {
//       print('⚠️ Error clearing all data: $e');
//     }
//   }

//   /// Debug: Print detailed box information
//   static Future<void> debugPrintAll() async {
//     print('📦 === CGPA BOX DEBUG ===');

//     try {
//       final box = await _box;

//       print('🔑 Box name: $_boxName');
//       print('🔓 Is open: ${box.isOpen}');
//       print('📁 Path: ${box.path}');
//       print('🔑 All keys: ${box.keys.toList()}');
//       print('📊 Total entries: ${box.length}');

//       if (box.isEmpty) {
//         print('ℹ️ Box is empty');
//         return;
//       }

//       for (var key in box.keys) {
//         print('\n--- Key: "$key" ---');
//         final value = box.get(key);
//         print('   Type: ${value.runtimeType}');

//         if (value is List) {
//           print('   List length: ${value.length}');

//           if (value.isNotEmpty) {
//             final first = value.first;
//             print('   First item type: ${first.runtimeType}');

//             if (first is CGPALevel) {
//               print('   ✅ Valid CGPALevel');
//               print('   Level: ${first.level}');
//               print('   1st Sem courses: ${first.firstSemester.length}');
//               print('   2nd Sem courses: ${first.secondSemester.length}');
//             } else if (first is Map) {
//               print('   📄 JSON/MAP format');
//             }
//           }
//         } else if (value is String) {
//           print('   String value: "$value"');
//         }
//       }

//       print('=== END DEBUG ===');
//     } catch (e) {
//       print('❌ Debug error: $e');
//     }
//   }

//   /// Get box status
//   static Future<Map<String, dynamic>> getBoxStatus() async {
//     try {
//       final box = await _box;
//       return {
//         'name': _boxName,
//         'isOpen': box.isOpen,
//         'keys': box.keys.toList(),
//         'length': box.length,
//         'path': box.path,
//       };
//     } catch (e) {
//       return {'name': _boxName, 'error': e.toString(), 'isOpen': false};
//     }
//   }

//   /// Close the box (call on app exit or when done)
//   static Future<void> closeBox() async {
//     if (_boxInstance != null && _boxInstance!.isOpen) {
//       await _boxInstance!.close();
//       _boxInstance = null;
//       print('🔒 CGPA box closed');
//     }
//   }

//   /// Test function to verify everything works
//   static Future<void> testService() async {
//     print('🧪 Testing CGPA Service...');

//     try {
//       // Test 1: Get box
//       final box = await _box;
//       print('✅ Test 1: Box opened successfully');

//       // Test 2: Create test data
//       final testCourse = CGPACourse(code: 'TEST101', unit: 3, grade: 'A');
//       final testLevel = CGPALevel(
//         level: '100',
//         firstSemester: [testCourse],
//         secondSemester: [],
//       );
//       print('✅ Test 2: Test objects created');

//       // Test 3: Save data
//       await saveCGPAData('test_user', [testLevel]);
//       print('✅ Test 3: Data saved');

//       // Test 4: Load data
//       final loaded = await getCGPAData('test_user');
//       print('✅ Test 4: Data loaded (${loaded.length} levels)');

//       // Test 5: Clean up
//       await clearUserData('test_user');
//       print('✅ Test 5: Cleanup complete');

//       print('🎉 All tests passed!');
//     } catch (e) {
//       print('❌ Test failed: $e');
//     }
//   }
// }
// lib/features/cgpa/services/cgpa_service.dart
import 'package:hive/hive.dart';
import '../models/cgpa_models.dart';

class CGPAService {
  static const String _boxName = 'cgpa_box';
  static Box? _boxInstance;
  static bool _isInitializing = false;
  static bool _hasInitialized = false;

  /// Initialize the service - call this once at app startup
  static Future<void> initialize() async {
    if (_hasInitialized) return;

    print('🔄 Initializing CGPAService...');
    try {
      // Ensure adapters are registered
      if (!Hive.isAdapterRegistered(10)) {
        Hive.registerAdapter(CGPALevelAdapter());
      }
      if (!Hive.isAdapterRegistered(11)) {
        Hive.registerAdapter(CGPACourseAdapter());
      }

      _hasInitialized = true;
      print('✅ CGPAService initialized');
    } catch (e) {
      print('❌ Failed to initialize CGPAService: $e');
    }
  }

  /// Get the box - singleton pattern to prevent multiple openings
  static Future<Box> get _box async {
    // Return existing instance if available and open
    if (_boxInstance != null && _boxInstance!.isOpen) {
      return _boxInstance!;
    }

    // Prevent concurrent initialization
    if (_isInitializing) {
      print('⏳ CGPA box initialization already in progress, waiting...');
      await Future.delayed(const Duration(milliseconds: 200));
      return await _box;
    }

    _isInitializing = true;

    try {
      print('📦 Opening CGPA box...');

      // Check if box is already open globally (by Hive or main.dart)
      if (Hive.isBoxOpen(_boxName)) {
        print('ℹ️ CGPA box is already open globally, reusing...');
        _boxInstance = Hive.box(_boxName);
        _isInitializing = false;
        return _boxInstance!;
      }

      // Open box - use simple openBox without type to avoid conflicts
      print('🚀 Opening CGPA box...');
      _boxInstance = await Hive.openBox(_boxName);

      print('✅ CGPA box opened successfully');
      print('   Box path: ${_boxInstance!.path}');
      print('   Is open: ${_boxInstance!.isOpen}');
      print('   Keys in box: ${_boxInstance!.keys.toList()}');

      return _boxInstance!;
    } catch (e) {
      print('❌ Failed to open CGPA box: $e');
      _isInitializing = false;

      // Try one more time with a delay
      try {
        print('🔄 Retrying to open CGPA box...');
        await Future.delayed(const Duration(milliseconds: 500));
        _boxInstance = await Hive.openBox(_boxName);
        print('✅ CGPA box opened on retry');
        return _boxInstance!;
      } catch (e2) {
        print('❌❌ Failed to open CGPA box after retry: $e2');
        rethrow;
      }
    } finally {
      _isInitializing = false;
    }
  }

  /// Save CGPA data
  static Future<void> saveCGPAData(
    String userId,
    List<CGPALevel> levels,
  ) async {
    if (userId.isEmpty) {
      print('⚠️ Cannot save: userId is empty');
      return;
    }

    try {
      print('💾 Saving CGPA data for user: $userId');
      print('   Number of levels to save: ${levels.length}');

      final box = await _box;
      final key = 'cgpa_$userId';

      // Save the data
      await box.put(key, levels);

      // Also save a JSON backup
      try {
        final backupKey = 'backup_$key';
        final jsonData = levels.map((level) => level.toMap()).toList();
        await box.put(backupKey, jsonData);
        print('✅ Backup saved');
      } catch (e) {
        print('⚠️ Could not save backup: $e');
      }

      print('✅ CGPA data saved successfully for user: $userId');
    } catch (e) {
      print('❌ Error saving CGPA data: $e');
      rethrow;
    }
  }

  /// Load CGPA data
  static Future<List<CGPALevel>> getCGPAData(String userId) async {
    if (userId.isEmpty) {
      print('⚠️ Cannot load: userId is empty');
      return [];
    }

    try {
      print('📥 Loading CGPA data for user: $userId');

      final box = await _box;
      final key = 'cgpa_$userId';
      final backupKey = 'backup_$key';

      print('   Looking for key: $key');
      print('   All keys in box: ${box.keys.toList()}');

      // First try direct load
      final rawData = box.get(key);

      if (rawData == null) {
        print('ℹ️ No direct data found, checking backup...');
        final backupData = box.get(backupKey);

        if (backupData != null && backupData is List) {
          print('✅ Found backup data, converting...');
          try {
            final levels = backupData
                .map((data) => CGPALevel.fromMap(data))
                .toList();
            print('   Converted ${levels.length} levels from backup');
            return levels;
          } catch (e) {
            print('❌ Error converting backup data: $e');
          }
        }

        print('ℹ️ No CGPA data found for user: $userId');
        return [];
      }

      print('   Raw data type: ${rawData.runtimeType}');

      if (rawData is List<CGPALevel>) {
        print('✅ Valid List<CGPALevel> found - ${rawData.length} levels');
        return rawData;
      } else if (rawData is List) {
        print('ℹ️ Raw List found - length: ${rawData.length}');

        if (rawData.isEmpty) {
          print('ℹ️ List is empty');
          return [];
        }

        // Try to cast to CGPALevel
        try {
          final levels = List<CGPALevel>.from(rawData.whereType<CGPALevel>());
          if (levels.isNotEmpty) {
            print('✅ Successfully cast ${levels.length} CGPALevel objects');
            return levels;
          }
        } catch (e) {
          print('❌ Could not cast to CGPALevel: $e');
        }

        // Try to convert from Map
        try {
          final levels = rawData
              .where((item) => item is Map)
              .map((item) => CGPALevel.fromMap(item))
              .toList();
          if (levels.isNotEmpty) {
            print('✅ Converted ${levels.length} levels from Map');
            return levels;
          }
        } catch (e) {
          print('❌ Could not convert from Map: $e');
        }

        print('❌ Could not process data');
        return [];
      } else {
        print('❌ Unexpected data type: ${rawData.runtimeType}');
        return [];
      }
    } catch (e) {
      print('❌ Error loading CGPA data: $e');
      return [];
    }
  }

  /// Check if user has CGPA data
  static Future<bool> hasCGPAData(String userId) async {
    try {
      final box = await _box;
      return box.containsKey('cgpa_$userId') ||
          box.containsKey('backup_cgpa_$userId');
    } catch (e) {
      return false;
    }
  }

  /// Debug: Print detailed box information
  static Future<void> debugPrintAll() async {
    print('📦 === CGPA BOX DEBUG ===');

    try {
      final box = await _box;

      print('🔑 Box name: $_boxName');
      print('🔓 Is open: ${box.isOpen}');
      print('📊 Total entries: ${box.length}');
      print('🔑 All keys: ${box.keys.toList()}');

      if (box.isEmpty) {
        print('ℹ️ Box is empty');
        return;
      }

      for (var key in box.keys) {
        print('\n--- Key: "$key" ---');
        final value = box.get(key);
        print('   Type: ${value.runtimeType}');

        if (value is List) {
          print('   List length: ${value.length}');

          if (value.isNotEmpty) {
            final first = value.first;
            print('   First item type: ${first.runtimeType}');

            if (first is CGPALevel) {
              print('   ✅ Valid CGPALevel');
              print('   Level: ${first.level}');
              print('   1st Sem courses: ${first.firstSemester.length}');
              print('   2nd Sem courses: ${first.secondSemester.length}');
            } else if (first is Map) {
              print('   📄 JSON/MAP format');
            }
          }
        }
      }

      print('=== END DEBUG ===');
    } catch (e) {
      print('❌ Debug error: $e');
    }
  }
}
