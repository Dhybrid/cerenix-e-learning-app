import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';
import '../constants/endpoints.dart';
import '../../features/onboarding/models/onboarding_models.dart';
import '../../features/activate/models/activation_models.dart';
import '../../features/courses/models/course_models.dart';
import '../../features/past_questions/models/past_question_models.dart';
import '../../features/past_questions/models/test_question_models.dart';
import '../../features/documents/models/document_model.dart';
import 'dart:math';
import 'dart:async';
import 'dart:io';
// lib/core/network/api_service.dart — Add this import at the top
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  // Singleton — only one instance in the entire app
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  // Helper method to check if user is authenticated
  Future<bool> _isUserAuthenticated() async {
    try {
      final box = await Hive.openBox('user_box');
      final userData = box.get('current_user');
      return userData != null && userData['id'] != null;
    } catch (e) {
      return false;
    }
  }

  // Google Sign Up / Login
  // Future<Map<String, dynamic>?> googleLogin(String idToken) async {
  //   final response = await http.post(
  //     Uri.parse(ApiEndpoints.googleLogin),
  //     headers: {'Content-Type': 'application/json'},
  //     body: jsonEncode({'id_token': idToken}),
  //   );

  //   if (response.statusCode == 200) {
  //     final responseData = jsonDecode(response.body);

  //     // Handle both "welcome back" and normal login responses
  //     Map<String, dynamic> userData;
  //     if (responseData['message'] != null) {
  //       // This is a "welcome back" message
  //       userData = responseData['user'];
  //     } else {
  //       // Normal login response
  //       userData = responseData['user'];
  //     }

  //     // Store user data in Hive
  //     final box = await Hive.openBox('user_box');
  //     await box.put('current_user', userData);

  //     print('✅ User data saved to Hive: $userData');
  //     return userData;
  //   } else {
  //     final error = jsonDecode(response.body)['error'] ?? 'Login failed';
  //     throw Exception(error);
  //   }
  // }

  // Google Sign Up / Login
  Future<Map<String, dynamic>?> googleLogin(String idToken) async {
    try {
      final response = await http
          .post(
            Uri.parse(ApiEndpoints.googleLogin),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'id_token': idToken}),
          )
          .timeout(Duration(seconds: 30)); // Add timeout

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);

        // Handle both "welcome back" and normal login responses
        Map<String, dynamic> userData;
        if (responseData['message'] != null) {
          userData = responseData['user'];
        } else {
          userData = responseData['user'];
        }

        // Store user data in Hive
        final box = await Hive.openBox('user_box');
        await box.put('current_user', userData);

        print('✅ User data saved to Hive');
        return userData;
      } else {
        // USER-FRIENDLY MESSAGES:
        if (response.statusCode == 401) {
          throw Exception('Invalid credentials. Please try again.');
        } else if (response.statusCode == 500) {
          throw Exception('Server error. Please try again later.');
        } else if (response.statusCode == 404) {
          throw Exception('Service temporarily unavailable.');
        } else {
          throw Exception(
            'Login failed. Please check your connection and try again.',
          );
        }
      }
    } on TimeoutException {
      throw Exception(
        'Connection timeout. Please check your internet connection.',
      );
    } on SocketException {
      throw Exception('No internet connection. Please check your network.');
    } catch (e) {
      throw Exception('An error occurred during login. Please try again.');
    }
  }

  // Email Registration + Auto Login
  // Future<Map<String, dynamic>?> registerWithEmail({
  //   required String email,
  //   required String password,
  // }) async {
  //   final regResponse = await http.post(
  //     Uri.parse(ApiEndpoints.emailRegister),
  //     headers: {'Content-Type': 'application/json'},
  //     body: jsonEncode({'email': email, 'password': password}),
  //   );

  //   if (regResponse.statusCode != 200 && regResponse.statusCode != 201) {
  //     final error =
  //         jsonDecode(regResponse.body)['error'] ?? 'Registration failed';
  //     throw Exception(error);
  //   }

  //   // Auto login after register
  //   final loginResponse = await http.post(
  //     Uri.parse(ApiEndpoints.emailLogin),
  //     headers: {'Content-Type': 'application/json'},
  //     body: jsonEncode({'email': email, 'password': password}),
  //   );

  //   if (loginResponse.statusCode == 200) {
  //     final userData = jsonDecode(loginResponse.body)['user'];

  //     // Store user data in Hive
  //     final box = await Hive.openBox('user_box');
  //     await box.put('current_user', userData);

  //     print('✅ User data saved to Hive: $userData');
  //     return userData;
  //   } else {
  //     throw Exception("Auto login failed");
  //   }
  // }

  // Email Registration + Auto Login
  Future<Map<String, dynamic>?> registerWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final regResponse = await http
          .post(
            Uri.parse(ApiEndpoints.emailRegister),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'email': email, 'password': password}),
          )
          .timeout(Duration(seconds: 30));

      if (regResponse.statusCode != 200 && regResponse.statusCode != 201) {
        // USER-FRIENDLY MESSAGES:
        if (regResponse.statusCode == 400) {
          throw Exception(
            'Invalid email format or password requirements not met.',
          );
        } else if (regResponse.statusCode == 409) {
          throw Exception(
            'Email already registered. Please use a different email or login.',
          );
        } else {
          throw Exception('Registration failed. Please try again.');
        }
      }

      // Auto login after register
      final loginResponse = await http
          .post(
            Uri.parse(ApiEndpoints.emailLogin),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'email': email, 'password': password}),
          )
          .timeout(Duration(seconds: 30));

      if (loginResponse.statusCode == 200) {
        final userData = jsonDecode(loginResponse.body)['user'];

        final box = await Hive.openBox('user_box');
        await box.put('current_user', userData);

        print('✅ Registration successful');
        return userData;
      } else {
        throw Exception(
          "Registration complete. Please login with your credentials.",
        );
      }
    } on TimeoutException {
      throw Exception('Registration timeout. Please check your connection.');
    } on SocketException {
      throw Exception('No internet connection. Please check your network.');
    } catch (e) {
      throw Exception('Registration failed. Please try again.');
    }
  }

  // Get Universities
  Future<List<University>> getUniversities() async {
    final response = await http.get(
      Uri.parse(ApiEndpoints.universities),
      headers: {'Content-Type': 'application/json'},
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => University.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load universities: ${response.statusCode}');
    }
  }

  // Get Faculties for a University
  Future<List<Faculty>> getFaculties(String universityId) async {
    final response = await http.get(
      Uri.parse('${ApiEndpoints.faculties}?university_id=$universityId'),
      headers: {'Content-Type': 'application/json'},
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => Faculty.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load faculties: ${response.statusCode}');
    }
  }

  // Get Departments for a Faculty
  Future<List<Department>> getDepartments(String facultyId) async {
    final response = await http.get(
      Uri.parse('${ApiEndpoints.departments}?faculty_id=$facultyId'),
      headers: {'Content-Type': 'application/json'},
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => Department.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load departments: ${response.statusCode}');
    }
  }

  // Get Levels
  Future<List<Level>> getLevels() async {
    final response = await http.get(
      Uri.parse(ApiEndpoints.levels),
      headers: {'Content-Type': 'application/json'},
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => Level.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load levels: ${response.statusCode}');
    }
  }

  // Get Semesters
  Future<List<Semester>> getSemesters() async {
    final response = await http.get(
      Uri.parse(ApiEndpoints.semesters),
      headers: {'Content-Type': 'application/json'},
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => Semester.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load semesters: ${response.statusCode}');
    }
  }

  // Update Onboarding - CRITICAL FIX
  // Future<void> updateOnboarding({
  //   String? universityId,
  //   String? facultyId,
  //   String? departmentId,
  //   String? levelId,
  //   String? semesterId,
  // }) async {
  //   // Get user data from Hive to get email and ID
  //   final box = await Hive.openBox('user_box');
  //   final userData = box.get('current_user');

  //   if (userData == null) {
  //     throw Exception("User not found in local storage - please login again");
  //   }

  //   final Map<String, dynamic> data = {};

  //   // Send both email and user_id for identification
  //   if (userData['email'] != null) data['email'] = userData['email'];
  //   if (userData['id'] != null) data['user_id'] = userData['id'];

  //   // Add academic data
  //   if (universityId != null && universityId.isNotEmpty)
  //     data['university_id'] = universityId;
  //   if (facultyId != null && facultyId.isNotEmpty)
  //     data['faculty_id'] = facultyId;
  //   if (departmentId != null && departmentId.isNotEmpty)
  //     data['department_id'] = departmentId;
  //   if (levelId != null && levelId.isNotEmpty) data['level_id'] = levelId;
  //   if (semesterId != null && semesterId.isNotEmpty)
  //     data['semester_id'] = semesterId;

  //   print('📤 Sending onboarding data to Django: $data');

  //   final response = await http.post(
  //     Uri.parse(ApiEndpoints.updateOnboarding),
  //     headers: {'Content-Type': 'application/json'},
  //     body: jsonEncode(data),
  //   );

  //   print('📥 Response status: ${response.statusCode}');
  //   print('📥 Response body: ${response.body}');

  //   if (response.statusCode == 200) {
  //     // CRITICAL: Update local user data to mark onboarding as completed
  //     final updatedUserData = Map<String, dynamic>.from(userData);
  //     updatedUserData['onboarding_completed'] = true;

  //     print('💾 Saving to Hive - onboarding_completed: true');
  //     await box.put('current_user', updatedUserData);

  //     // Verify the save worked
  //     final verifiedData = box.get('current_user');
  //     print('✅ Verified Hive data after update: $verifiedData');
  //   } else {
  //     final errorData = jsonDecode(response.body);
  //     final error = errorData['error'] ?? 'Failed to update onboarding';
  //     throw Exception('$error (Status: ${response.statusCode})');
  //   }
  // }

  // Update Onboarding
  Future<void> updateOnboarding({
    String? universityId,
    String? facultyId,
    String? departmentId,
    String? levelId,
    String? semesterId,
  }) async {
    try {
      final box = await Hive.openBox('user_box');
      final userData = box.get('current_user');

      if (userData == null) {
        throw Exception("Please login to complete your profile.");
      }

      final Map<String, dynamic> data = {};

      if (userData['email'] != null) data['email'] = userData['email'];
      if (userData['id'] != null) data['user_id'] = userData['id'];

      if (universityId != null && universityId.isNotEmpty)
        data['university_id'] = universityId;
      if (facultyId != null && facultyId.isNotEmpty)
        data['faculty_id'] = facultyId;
      if (departmentId != null && departmentId.isNotEmpty)
        data['department_id'] = departmentId;
      if (levelId != null && levelId.isNotEmpty) data['level_id'] = levelId;
      if (semesterId != null && semesterId.isNotEmpty)
        data['semester_id'] = semesterId;

      final response = await http
          .post(
            Uri.parse(ApiEndpoints.updateOnboarding),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(data),
          )
          .timeout(Duration(seconds: 30));

      if (response.statusCode == 200) {
        final updatedUserData = Map<String, dynamic>.from(userData);
        updatedUserData['onboarding_completed'] = true;
        await box.put('current_user', updatedUserData);
      } else {
        if (response.statusCode == 400) {
          throw Exception(
            'Invalid academic information. Please check your selections.',
          );
        } else {
          throw Exception('Failed to save academic profile. Please try again.');
        }
      }
    } on TimeoutException {
      throw Exception('Request timeout. Please try again.');
    } on SocketException {
      throw Exception('No internet connection. Please check your network.');
    } catch (e) {
      throw Exception('Failed to save profile. Please try again.');
    }
  }

  String _getUserFriendlyErrorMessage(dynamic error, int statusCode) {
    if (error is String) {
      // Clean up technical messages
      if (error.contains('backend') || error.contains('server')) {
        return 'Server error. Please try again later.';
      }
      if (error.contains('connection') || error.contains('network')) {
        return 'Network error. Please check your connection.';
      }
      if (error.contains('timeout')) {
        return 'Request timeout. Please try again.';
      }
      // General cleanup
      return error
          .replaceAll('Failed to', 'Unable to')
          .replaceAll('Status:', '')
          .replaceAll(RegExp(r'\(\d+\)'), '')
          .trim();
    }

    // Status code based messages
    switch (statusCode) {
      case 400:
        return 'Invalid request. Please check your input.';
      case 401:
        return 'Session expired. Please login again.';
      case 403:
        return 'Access denied.';
      case 404:
        return 'Resource not found.';
      case 408:
        return 'Request timeout. Please try again.';
      case 409:
        return 'Conflict detected. Please try a different value.';
      case 500:
        return 'Server error. Please try again later.';
      case 502:
      case 503:
      case 504:
        return 'Service temporarily unavailable.';
      default:
        return 'An error occurred. Please try again.';
    }
  }

  // Check if user is logged in (for app startup)
  Future<bool> isUserLoggedIn() async {
    return await _isUserAuthenticated();
  }

  Future<Map<String, dynamic>?> getCurrentUser() async {
    try {
      final box = await Hive.openBox('user_box');
      final userData = box.get('current_user');

      if (userData == null) {
        print('❌ No user data found in Hive');
        return null;
      }

      // FIX: Properly convert Hive data to Map<String, dynamic>
      final userMap = Map<String, dynamic>.from(userData);
      print('✅ User data loaded from Hive: ${userMap['email']}');

      return userMap;
    } catch (e) {
      print('❌ Error getting user from Hive: $e');
      throw Exception('Failed to load user data: $e');
    }
  }

  // ========== UPDATED LOGOUT METHODS ==========

  // Logout user - IMPROVED VERSION
  Future<void> logout() async {
    try {
      // Try to call Django logout endpoint first
      await _djangoLogout();
    } catch (e) {
      print('⚠️ Django logout failed, continuing with local logout: $e');
    } finally {
      // Always clear local storage
      await _clearLocalStorage();
    }
  }

  // Django logout API call
  Future<void> _djangoLogout() async {
    try {
      final response = await http.post(
        Uri.parse('${ApiEndpoints.baseUrl}/api/users/auth/logout/'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        print('✅ Django logout successful');
      } else {
        print('⚠️ Django logout failed: ${response.statusCode}');
        // Don't throw error - we'll still clear local storage
      }
    } catch (e) {
      print('⚠️ Django logout error: $e');
      // Don't throw error - we'll still clear local storage
    }
  }

  // Clear local storage
  Future<void> _clearLocalStorage() async {
    try {
      final box = await Hive.openBox('user_box');
      await box.clear();
      print('🚪 User logged out - Hive cleared');
    } catch (e) {
      print('Error clearing local storage: $e');
    }
  }

  // ========== END OF UPDATED METHODS ==========

  // Clear all user data
  Future<void> clearAllUserData() async {
    try {
      final box = await Hive.openBox('user_box');
      await box.clear();
      print('✅ All user data cleared from Hive');
    } catch (e) {
      print('❌ Error clearing user data: $e');
    }
  }

  // Debug what's stored
  Future<void> debugHiveStorage() async {
    try {
      final box = await Hive.openBox('user_box');
      final userData = box.get('current_user');
      print('=== HIVE STORAGE DEBUG ===');
      print('User data: $userData');
      print('Box keys: ${box.keys.toList()}');
      print('Box values: ${box.values.toList()}');
      print('==========================');
    } catch (e) {
      print('Error reading Hive: $e');
    }
  }

  // Store last activity timestamp
  Future<void> _updateLastActivity() async {
    try {
      final box = await Hive.openBox('user_box');
      await box.put('last_activity', DateTime.now().toIso8601String());
      print('✅ Last activity updated: ${DateTime.now()}');
    } catch (e) {
      print('❌ Error updating last activity: $e');
    }
  }

  // Check if user should be auto-logged out (18 hours)
  Future<bool> shouldAutoLogout() async {
    try {
      final box = await Hive.openBox('user_box');
      final lastActivityString = box.get('last_activity');

      if (lastActivityString == null) {
        // No last activity recorded, assume new session
        await _updateLastActivity();
        return false;
      }

      final lastActivity = DateTime.parse(lastActivityString);
      final now = DateTime.now();
      final difference = now.difference(lastActivity);

      // 18 hours = 18 * 60 * 60 * 1000 = 64800000 milliseconds
      final eighteenHours = Duration(hours: 18);

      print('⏰ Auto-logout check:');
      print('   Last activity: $lastActivity');
      print('   Current time: $now');
      print(
        '   Difference: ${difference.inHours} hours ${difference.inMinutes.remainder(60)} minutes',
      );
      print('   Should logout: ${difference > eighteenHours}');

      return difference > eighteenHours;
    } catch (e) {
      print('❌ Error checking auto-logout: $e');
      return false;
    }
  }

  // Update last activity on every app interaction
  Future<void> updateUserActivity() async {
    await _updateLastActivity();
  }

  // Add this to your ApiService class
  // Future<Map<String, dynamic>?> loginWithEmail({
  //   required String email,
  //   required String password,
  // }) async {
  //   final response = await http.post(
  //     Uri.parse(ApiEndpoints.emailLogin),
  //     headers: {'Content-Type': 'application/json'},
  //     body: jsonEncode({'email': email, 'password': password}),
  //   );

  //   if (response.statusCode == 200) {
  //     final userData = jsonDecode(response.body)['user'];

  //     // Store user data in Hive
  //     final box = await Hive.openBox('user_box');
  //     await box.put('current_user', userData);

  //     print('✅ User logged in and data saved to Hive: $userData');
  //     return userData;
  //   } else {
  //     final error = jsonDecode(response.body)['error'] ?? 'Login failed';
  //     throw Exception(error);
  //   }
  // }

  // Add this to your ApiService class
  Future<Map<String, dynamic>?> loginWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse(ApiEndpoints.emailLogin),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'email': email, 'password': password}),
          )
          .timeout(Duration(seconds: 30));

      if (response.statusCode == 200) {
        final userData = jsonDecode(response.body)['user'];

        final box = await Hive.openBox('user_box');
        await box.put('current_user', userData);

        print('✅ Login successful');
        return userData;
      } else {
        // USER-FRIENDLY MESSAGES:
        if (response.statusCode == 401) {
          throw Exception('Invalid email or password. Please try again.');
        } else if (response.statusCode == 403) {
          throw Exception('Account disabled. Please contact support.');
        } else if (response.statusCode == 404) {
          throw Exception('Account not found. Please register first.');
        } else {
          throw Exception(
            'Login failed. Please check your connection and try again.',
          );
        }
      }
    } on TimeoutException {
      throw Exception(
        'Connection timeout. Please check your internet connection.',
      );
    } on SocketException {
      throw Exception('No internet connection. Please check your network.');
    } catch (e) {
      throw Exception('An error occurred. Please try again.');
    }
  }

  // Update User Profile - ENHANCED DEBUGGING VERSION
  Future<void> updateProfile({
    required dynamic userId,
    required String email,
    String? name,
    String? bio,
    String? phone,
    String? location,
  }) async {
    try {
      final Map<String, dynamic> requestData = {
        'user_id': userId.toString(),
        'email': email,
      };

      // Only include fields that are provided
      if (name != null && name.isNotEmpty) requestData['name'] = name;
      if (bio != null) requestData['bio'] = bio;
      if (phone != null && phone.isNotEmpty) requestData['phone'] = phone;
      if (location != null && location.isNotEmpty)
        requestData['location'] = location;

      print('📤 Sending profile update to Django: $requestData');
      print('📤 Endpoint: ${ApiEndpoints.updateProfile}');

      final response = await http
          .post(
            Uri.parse(ApiEndpoints.updateProfile),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(requestData),
          )
          .timeout(Duration(seconds: 10));

      print('📥 Response status: ${response.statusCode}');
      print('📥 Response headers: ${response.headers}');
      print('📥 Response body (raw): ${response.body}');

      if (response.statusCode == 200) {
        // Try to parse the response
        try {
          final responseData = jsonDecode(response.body);
          final updatedUserData = responseData['user'];

          print('✅ Profile updated on server: $updatedUserData');

          // Update local storage with new user data
          final box = await Hive.openBox('user_box');
          await box.put('current_user', updatedUserData);
          print('✅ Profile saved to Hive');
        } catch (e) {
          print('❌ JSON parsing error: $e');
          throw Exception('Invalid response format from server');
        }
      } else {
        print('❌ Server returned error status: ${response.statusCode}');

        // Try to parse error message
        try {
          final errorData = jsonDecode(response.body);
          final error =
              errorData['error'] ??
              'Failed to update profile (Status: ${response.statusCode})';
          throw Exception(error);
        } catch (e) {
          // If JSON parsing fails, use raw response
          throw Exception(
            'Server error: ${response.statusCode} - ${response.body}',
          );
        }
      }
    } catch (e) {
      print('❌ Network/API error: $e');
      rethrow;
    }
  }

  // Update User Password - FIXED VERSION (accepts dynamic userId)
  Future<void> updatePassword({
    required dynamic userId, // ← CHANGE TO dynamic
    required String email,
    String? currentPassword,
    required String newPassword,
  }) async {
    final Map<String, dynamic> requestData = {
      'user_id': userId.toString(), // ← CONVERT TO STRING HERE
      'email': email,
      'new_password': newPassword,
    };

    // Only include current_password if it's provided (for email users)
    if (currentPassword != null && currentPassword.isNotEmpty) {
      requestData['current_password'] = currentPassword;
    }

    print('📤 Sending password update to Django: $requestData');

    final response = await http.post(
      Uri.parse(ApiEndpoints.updatePassword),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(requestData),
    );

    print('📥 Password update response status: ${response.statusCode}');
    print('📥 Password update response body: ${response.body}');

    if (response.statusCode == 200) {
      print('✅ Password updated on server');

      // Update local storage with new password
      final box = await Hive.openBox('user_box');
      final currentUserData = box.get('current_user');
      if (currentUserData != null) {
        final updatedUserData = Map<String, dynamic>.from(currentUserData);
        updatedUserData['password'] = newPassword;
        await box.put('current_user', updatedUserData);
        print('✅ Password saved to Hive');
      }
    } else {
      final errorData = jsonDecode(response.body);
      final error = errorData['error'] ?? 'Failed to update password';
      throw Exception(error);
    }
  }

  // #######################################################################

  Future<List<BillingPlan>> getBillingPlans(String universityId) async {
    try {
      print(
        '📋 [ApiService] Getting billing plans for university: $universityId',
      );

      final url = '${ApiEndpoints.billingPlans}?university_id=$universityId';
      print('   - Full URL: $url');

      final response = await http.get(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
      );

      print('📥 [ApiService] Billing plans response: ${response.statusCode}');
      print('📥 [ApiService] Response body: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        print('   - Response data type: ${responseData.runtimeType}');

        if (responseData is List) {
          print(
            '✅ [ApiService] Billing plans loaded successfully: ${responseData.length} plans',
          );

          // CRITICAL DEBUG: Print ALL fields from each plan
          for (var i = 0; i < responseData.length; i++) {
            final planData = responseData[i];
            print('   🔍 Plan $i ALL FIELDS:');
            planData.forEach((key, value) {
              print('     - $key: $value (type: ${value.runtimeType})');
            });
            print('   ---');
          }

          // Try to parse plans
          try {
            final plans = responseData
                .map((json) => BillingPlan.fromJson(json))
                .toList();
            print('✅ Successfully parsed ${plans.length} billing plans');
            return plans;
          } catch (e) {
            print('❌ ERROR parsing billing plans: $e');
            print(
              '🔍 This means the JSON structure doesnt match BillingPlan model expectations',
            );
            return [];
          }
        } else {
          print(
            '❌ [ApiService] Expected List but got: ${responseData.runtimeType}',
          );
          print('   - Actual data: $responseData');
          return [];
        }
      } else {
        final errorData = jsonDecode(response.body);
        final error = errorData['error'] ?? 'Failed to load billing plans';
        print(
          '❌ [ApiService] API Error: $error (Status: ${response.statusCode})',
        );
        throw Exception('$error (Status: ${response.statusCode})');
      }
    } catch (e) {
      print('❌ [ApiService] Error loading billing plans: $e');
      rethrow;
    }
  }

  Future<UserActivation?> getActivationStatus() async {
    try {
      print('📊 Getting activation status...');

      // FIX: Get user data directly with proper type handling
      final userData = await getCurrentUser();
      if (userData == null || userData['id'] == null) {
        throw Exception("User not found. Please login again.");
      }

      final userId = userData['id'].toString();
      print('👤 Using user ID: $userId');

      final response = await http.get(
        Uri.parse('${ApiEndpoints.activationStatus}?user_id=$userId'),
        headers: {'Content-Type': 'application/json'},
      );

      print('📥 Activation status response: ${response.statusCode}');
      print('📥 Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // Handle both response formats
        if (data['is_active'] == true) {
          // User has active activation - full activation data
          print('✅ Active activation found');
          return UserActivation.fromJson(data);
        } else if (data['is_active'] == false) {
          // User has no active activation - return null
          print('ℹ️ No active activation found');
          return null;
        } else {
          // Unexpected response format
          print('⚠️ Unexpected activation status response format: $data');
          return null;
        }
      } else {
        final errorData = jsonDecode(response.body);
        final error = errorData['error'] ?? 'Failed to get activation status';
        throw Exception('$error (Status: ${response.statusCode})');
      }
    } catch (e) {
      print('❌ Error getting activation status: $e');
      rethrow;
    }
  }

  // Future<UserActivation?> getActivationStatus() async {
  //   try {
  //     print('📊 Checking activation status...');

  //     final userData = await getCurrentUser();
  //     if (userData == null || userData['id'] == null) {
  //       throw Exception("Please login to check your activation status.");
  //     }

  //     final userId = userData['id'].toString();

  //     final response = await http
  //         .get(
  //           Uri.parse('${ApiEndpoints.activationStatus}?user_id=$userId'),
  //           headers: {'Content-Type': 'application/json'},
  //         )
  //         .timeout(Duration(seconds: 30));

  //     print('📥 Activation status response: ${response.statusCode}');

  //     if (response.statusCode == 200) {
  //       final data = jsonDecode(response.body);

  //       if (data['is_active'] == true) {
  //         print('✅ Active subscription found');
  //         return UserActivation.fromJson(data);
  //       } else if (data['is_active'] == false) {
  //         print('ℹ️ No active subscription found');
  //         return null;
  //       } else {
  //         return null;
  //       }
  //     } else {
  //       // USER-FRIENDLY MESSAGES:
  //       if (response.statusCode == 404) {
  //         throw Exception(
  //           'Unable to check activation status. Please try again.',
  //         );
  //       } else {
  //         throw Exception(
  //           'Failed to load activation status. Please try again.',
  //         );
  //       }
  //     }
  //   } on TimeoutException {
  //     throw Exception('Connection timeout. Please check your internet.');
  //   } on SocketException {
  //     throw Exception('No internet connection. Please check your network.');
  //   } catch (e) {
  //     throw Exception('Unable to check activation status. Please try again.');
  //   }
  // }

  // FIXED: Enhanced Activate with PIN with proper user ID handling
  Future<ActivationResponse> activateWithPin({
    required String activationCode,
    String? referralCode,
  }) async {
    try {
      print('🔑 Activating with PIN...');

      // FIX: Use the fixed getCurrentUser method
      final userData = await getCurrentUser();
      if (userData == null || userData['id'] == null) {
        throw Exception("User not found. Please login again.");
      }

      final userId = userData['id'].toString();
      print('👤 Using user ID: $userId');

      final Map<String, dynamic> requestData = {
        'user_id': userId,
        'activation_code': activationCode,
      };

      if (referralCode != null && referralCode.isNotEmpty) {
        requestData['referral_code'] = referralCode;
        print('🎁 Referral code included: $referralCode');
      }

      final response = await http.post(
        Uri.parse(ApiEndpoints.activateWithPin),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestData),
      );

      print('📥 PIN activation response: ${response.statusCode}');
      print('📥 Response body: ${response.body}');

      if (response.statusCode == 200) {
        print('✅ PIN activation successful');
        return ActivationResponse.fromJson(jsonDecode(response.body));
      } else {
        final errorData = jsonDecode(response.body);
        final error = errorData['error'] ?? 'Activation failed';
        throw Exception(error);
      }
    } catch (e) {
      print('❌ PIN activation error: $e');
      rethrow;
    }
  }

  // Future<ActivationResponse> activateWithPin({
  //   required String activationCode,
  //   String? referralCode,
  // }) async {
  //   try {
  //     print('🔑 Activating with PIN...');

  //     final userData = await getCurrentUser();
  //     if (userData == null || userData['id'] == null) {
  //       throw Exception("Please login to activate your account.");
  //     }

  //     final userId = userData['id'].toString();

  //     final Map<String, dynamic> requestData = {
  //       'user_id': userId,
  //       'activation_code': activationCode,
  //     };

  //     if (referralCode != null && referralCode.isNotEmpty) {
  //       requestData['referral_code'] = referralCode;
  //     }

  //     final response = await http
  //         .post(
  //           Uri.parse(ApiEndpoints.activateWithPin),
  //           headers: {'Content-Type': 'application/json'},
  //           body: jsonEncode(requestData),
  //         )
  //         .timeout(Duration(seconds: 30));

  //     if (response.statusCode == 200) {
  //       print('✅ Activation successful');
  //       return ActivationResponse.fromJson(jsonDecode(response.body));
  //     } else {
  //       // USER-FRIENDLY MESSAGES:
  //       final errorData = jsonDecode(response.body);
  //       final errorMessage = errorData['error'];

  //       if (response.statusCode == 400) {
  //         if (errorMessage?.contains('invalid') ?? false) {
  //           throw Exception(
  //             'Invalid activation code. Please check and try again.',
  //           );
  //         } else if (errorMessage?.contains('already') ?? false) {
  //           throw Exception('This code has already been used.');
  //         } else if (errorMessage?.contains('expired') ?? false) {
  //           throw Exception('This activation code has expired.');
  //         }
  //       } else if (response.statusCode == 404) {
  //         throw Exception('Activation code not found.');
  //       } else if (response.statusCode == 409) {
  //         throw Exception('You already have an active subscription.');
  //       }

  //       throw Exception('Activation failed. Please try again.');
  //     }
  //   } on TimeoutException {
  //     throw Exception('Activation timeout. Please check your connection.');
  //   } on SocketException {
  //     throw Exception('No internet connection. Please check your network.');
  //   } catch (e) {
  //     throw Exception('Activation failed. Please try again.');
  //   }
  // }

  // FIXED: Enhanced Initiate Payment with proper user ID handling
  Future<PaymentInitiationResponse> initiatePayment({
    required String planId,
    String? referralCode,
  }) async {
    try {
      print('💳 Initiating payment for plan: $planId');

      // FIX: Use the fixed getCurrentUser method
      final userData = await getCurrentUser();
      if (userData == null || userData['id'] == null) {
        throw Exception("User not found. Please login again.");
      }

      final userId = userData['id'].toString();
      print('👤 Using user ID: $userId');

      final Map<String, dynamic> requestData = {
        'user_id': userId,
        'plan_id': planId,
      };

      if (referralCode != null && referralCode.isNotEmpty) {
        requestData['referral_code'] = referralCode;
        print('🎁 Referral code included: $referralCode');
      }

      final response = await http.post(
        Uri.parse(ApiEndpoints.initiatePayment),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestData),
      );

      print('📥 Payment initiation response: ${response.statusCode}');
      print('📥 Response body: ${response.body}');

      if (response.statusCode == 200) {
        print('✅ Payment initiation successful');
        return PaymentInitiationResponse.fromJson(jsonDecode(response.body));
      } else {
        final errorData = jsonDecode(response.body);
        final error = errorData['error'] ?? 'Payment initiation failed';
        throw Exception(error);
      }
    } catch (e) {
      print('❌ Payment initiation error: $e');
      rethrow;
    }
  }

  // Enhanced Verify Payment (no changes needed as it uses reference only)
  Future<ActivationResponse> verifyPayment(String reference) async {
    try {
      print('🔍 Verifying payment for reference: $reference');

      // Use basic headers since the endpoint allows any permission
      final Map<String, dynamic> requestData = {'reference': reference};

      final response = await http.post(
        Uri.parse(ApiEndpoints.paymentCallback),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestData),
      );

      print('📥 Payment verification response: ${response.statusCode}');
      print('📥 Response body: ${response.body}');

      if (response.statusCode == 200) {
        print('✅ Payment verification successful');
        return ActivationResponse.fromJson(jsonDecode(response.body));
      } else {
        final errorData = jsonDecode(response.body);
        final error = errorData['error'] ?? 'Payment verification failed';
        throw Exception(error);
      }
    } catch (e) {
      print('❌ Payment verification error: $e');
      rethrow;
    }
  }

  // FIXED: Get user referral code with proper user ID handling
  Future<Map<String, dynamic>> getUserReferral() async {
    try {
      print('🎯 Getting user referral code...');

      // FIX: Use the fixed getCurrentUser method
      final userData = await getCurrentUser();
      if (userData == null || userData['id'] == null) {
        throw Exception("User not found. Please login again.");
      }

      final userId = userData['id'].toString();
      print('👤 Using user ID: $userId');

      final response = await http.get(
        Uri.parse('${ApiEndpoints.userReferral}?user_id=$userId'),
        headers: {'Content-Type': 'application/json'},
      );

      print('📥 Referral response: ${response.statusCode}');
      print('📥 Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('✅ Referral code loaded successfully');
        return data;
      } else {
        final errorData = jsonDecode(response.body);
        final error = errorData['error'] ?? 'Failed to get referral code';
        throw Exception('$error (Status: ${response.statusCode})');
      }
    } catch (e) {
      print('❌ Error getting referral code: $e');
      rethrow;
    }
  }

  // ############################# PROFILE SECTION ENHANCE ############################

  // Add these methods to your ApiService class

  // Get user activation status for rank/grade
  Future<UserActivation?> getUserActivationStatus() async {
    try {
      final userData = await getCurrentUser();
      if (userData == null || userData['id'] == null) {
        return null;
      }

      final userId = userData['id'].toString();
      final response = await http.get(
        Uri.parse('${ApiEndpoints.activationStatus}?user_id=$userId'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['is_active'] == true) {
          return UserActivation.fromJson(data);
        }
      }
      return null;
    } catch (e) {
      print('❌ Error getting user activation status: $e');
      return null;
    }
  }

  // Get user referral code
  Future<Map<String, dynamic>?> getUserReferralInfo() async {
    try {
      final userData = await getCurrentUser();
      if (userData == null || userData['id'] == null) {
        return null;
      }

      final userId = userData['id'].toString();
      final response = await http.get(
        Uri.parse('${ApiEndpoints.userReferral}?user_id=$userId'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      print('❌ Error getting referral info: $e');
      return null;
    }
  }

  // Add these methods to your ApiService class
  // ####################################################################################

  // ==================== COURSE METHODS ====================

  // Get courses for the logged in user based on their academic info
  Future<List<Course>> getCoursesForUser() async {
    try {
      print('📚 Getting courses for logged in user...');

      // Get current user data
      final userData = await getCurrentUser();
      if (userData == null || userData['id'] == null) {
        throw Exception("User not found. Please login again.");
      }

      // Extract user academic information
      final userLevel = userData['level']?['id']?.toString();
      final userDepartment = userData['department']?['id']?.toString();
      final userUniversity = userData['university']?['id']?.toString();
      final userSemester = userData['semester']?['id']?.toString();

      // Validate that user has completed onboarding
      if (userUniversity == null || userLevel == null || userSemester == null) {
        throw Exception("Please complete your academic profile first.");
      }

      // Build query parameters
      final params = <String, String>{};

      // Always include university, level, and semester
      params['university'] = userUniversity;
      params['level'] = userLevel;
      params['semester'] = userSemester;

      // Department is optional (course can be for multiple departments)
      if (userDepartment != null && userDepartment.isNotEmpty) {
        params['department'] = userDepartment;
      }

      // Fetch courses from the API
      final uri = Uri.parse('${ApiEndpoints.baseUrl}/api/academics/courses/');
      final url = uri.replace(queryParameters: params);

      print('🌐 Fetching courses from: $url');

      final response = await http
          .get(url, headers: {'Content-Type': 'application/json'})
          .timeout(const Duration(seconds: 15));

      print('📥 Courses response: ${response.statusCode}');
      if (response.statusCode != 200) {
        print('📥 Error body: ${response.body}');
      }

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        print('✅ Successfully loaded ${data.length} courses');

        // Parse courses from JSON
        final courses = data.map((json) => Course.fromJson(json)).toList();

        // Load user progress for each course
        await _loadUserProgressForCourses(courses);

        // Cache courses for offline use
        await _cacheCourses(courses);

        return courses;
      } else if (response.statusCode == 404) {
        // No courses found for this filter - return empty list
        print('ℹ️ No courses found for the current filters');
        return [];
      } else {
        final errorData = json.decode(response.body);
        final error =
            errorData['error'] ??
            'Failed to load courses (Status: ${response.statusCode})';
        throw Exception(error);
      }
    } on TimeoutException {
      print('⏰ Request timeout - trying cached data');
      // Try to load from cache
      final cachedCourses = await _getCachedCourses();
      if (cachedCourses.isNotEmpty) {
        return cachedCourses;
      }
      throw Exception('Network timeout. Please check your connection.');
    } catch (e) {
      print('❌ Error getting courses for user: $e');

      // Try to load from cache as fallback
      try {
        final cachedCourses = await _getCachedCourses();
        if (cachedCourses.isNotEmpty) {
          print('✅ Loaded ${cachedCourses.length} courses from cache');
          return cachedCourses;
        }
      } catch (cacheError) {
        print('⚠️ Could not load cached courses: $cacheError');
      }

      rethrow;
    }
  }

  // Load user progress for courses (with real progress calculation)
  Future<void> _loadUserProgressForCourses(List<Course> courses) async {
    try {
      print('📊 Loading user progress for ${courses.length} courses...');

      final userData = await getCurrentUser();
      if (userData == null) return;

      final userId = userData['id'].toString();

      for (var course in courses) {
        try {
          // Try to get topics for this course
          final topics = await getTopics(courseId: int.parse(course.id));

          if (topics.isNotEmpty) {
            // Calculate progress based on completed topics
            int completedCount = 0;
            int totalTopics = topics.length;

            for (var topic in topics) {
              if (topic.isCompleted) {
                completedCount++;
              }
            }

            // Calculate percentage
            final progress = totalTopics > 0
                ? ((completedCount / totalTopics) * 100).round()
                : 0;

            course.progress = progress;
            print(
              '   - ${course.code}: $progress% ($completedCount/$totalTopics topics)',
            );

            // Save progress to local cache
            await _saveCourseProgress(course.id, progress);
          } else {
            // No topics found - check if we have cached progress
            final cachedProgress = await _getCachedCourseProgress(course.id);
            course.progress = cachedProgress;
            print('   - ${course.code}: ${cachedProgress}% (cached)');
          }
        } catch (e) {
          print('⚠️ Error loading progress for ${course.code}: $e');
          // Use cached progress
          final cachedProgress = await _getCachedCourseProgress(course.id);
          course.progress = cachedProgress;
        }
      }

      print('✅ User progress loaded for all courses');
    } catch (e) {
      print('❌ Error in _loadUserProgressForCourses: $e');
      // Set default progress if there's an error
      for (var course in courses) {
        final cachedProgress = await _getCachedCourseProgress(course.id);
        course.progress = cachedProgress;
      }
    }
  }

  // Get course outlines for a specific course
  Future<List<CourseOutline>> getCourseOutlines(int courseId) async {
    try {
      print('📋 Getting outlines for course ID: $courseId');

      final response = await http
          .get(
            Uri.parse(
              '${ApiEndpoints.baseUrl}/api/academics/course-outlines/?course=$courseId',
            ),
            headers: {'Content-Type': 'application/json'},
          )
          .timeout(const Duration(seconds: 10));

      print('📥 Outlines response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        print('✅ Successfully loaded ${data.length} outlines');

        final outlines = data
            .map((json) => CourseOutline.fromJson(json))
            .toList();

        // Cache outlines for offline use
        await _cacheCourseOutlines(courseId, outlines);

        return outlines;
      } else if (response.statusCode == 404) {
        // No outlines found for this course
        print('ℹ️ No outlines found for course ID: $courseId');
        return [];
      } else {
        final errorData = json.decode(response.body);
        final error = errorData['error'] ?? 'Failed to load course outlines';
        throw Exception('$error (Status: ${response.statusCode})');
      }
    } on TimeoutException {
      print('⏰ Request timeout - trying cached outlines');
      return await _getCachedCourseOutlines(courseId);
    } catch (e) {
      print('❌ Error getting course outlines: $e');

      // Try to return cached outlines as fallback
      try {
        final cachedOutlines = await _getCachedCourseOutlines(courseId);
        if (cachedOutlines.isNotEmpty) {
          print('✅ Loaded ${cachedOutlines.length} outlines from cache');
          return cachedOutlines;
        }
      } catch (cacheError) {
        print('⚠️ Could not load cached outlines: $cacheError');
      }

      rethrow;
    }
  }

  Future<List<Topic>> getTopics({int? courseId, int? outlineId}) async {
    try {
      print('📖 Getting topics...');

      // Get current user
      final userData = await getCurrentUser();
      if (userData == null || userData['id'] == null) {
        throw Exception("User not found. Please login again.");
      }
      final userId = userData['id'].toString();

      final uri = Uri.parse('${ApiEndpoints.baseUrl}/api/content/topics/');
      final params = <String, String>{};

      if (outlineId != null) {
        params['outline'] = outlineId.toString();
        print('   - Filtering by outline ID: $outlineId');
      } else if (courseId != null) {
        params['course'] = courseId.toString();
        print('   - Filtering by course ID: $courseId');
      } else {
        throw Exception('Either courseId or outlineId must be provided');
      }

      // ADD THIS: Include user_id in query params
      params['user_id'] = userId;

      final url = uri.replace(queryParameters: params);
      print('🌐 Fetching topics from: $url');

      final response = await http
          .get(url, headers: {'Content-Type': 'application/json'})
          .timeout(const Duration(seconds: 15));

      print('📥 Topics response: ${response.statusCode}');

      // Handle error responses
      if (response.statusCode >= 400) {
        print('❌ Error response body: ${response.body}');

        // If it's a 500 error with HTML, handle gracefully
        if (response.body.contains('<!DOCTYPE') ||
            response.body.contains('<html')) {
          throw Exception('Server error. Please try again later.');
        }

        // Try to parse JSON error
        try {
          final errorData = json.decode(response.body);
          final error =
              errorData['detail'] ??
              errorData['error'] ??
              'Failed to load topics';
          throw Exception('$error (Status: ${response.statusCode})');
        } catch (_) {
          throw Exception(
            'Server returned ${response.statusCode}: ${response.body}',
          );
        }
      }

      // Handle successful response
      final responseData = json.decode(response.body);

      print('📥 Response type: ${responseData.runtimeType}');

      List<dynamic> topicsData = [];

      // Handle different response formats
      if (responseData is List) {
        // Direct list response
        topicsData = responseData;
        print('✅ Direct list response with ${topicsData.length} topics');
      } else if (responseData is Map) {
        // Paginated response
        print('📥 Response keys: ${responseData.keys.toList()}');

        if (responseData.containsKey('results') &&
            responseData['results'] is List) {
          topicsData = responseData['results'];
          print('✅ Paginated response with ${topicsData.length} topics');
        } else if (responseData.containsKey('data') &&
            responseData['data'] is List) {
          topicsData = responseData['data'];
          print('✅ Data key response with ${topicsData.length} topics');
        } else if (responseData.containsKey('topics') &&
            responseData['topics'] is List) {
          topicsData = responseData['topics'];
          print('✅ Topics key response with ${topicsData.length} topics');
        } else {
          // Unknown structure - try to find any list
          print('⚠️ Unknown map structure. Searching for topics...');
          for (var value in responseData.values) {
            if (value is List) {
              topicsData = value;
              print('✅ Found ${topicsData.length} topics in nested list');
              break;
            }
          }
        }
      } else {
        print('❌ Unexpected response format: ${responseData.runtimeType}');
        throw Exception('Unexpected response format from server');
      }

      // Parse topics with proper error handling
      final List<Topic> topics = [];

      for (var item in topicsData) {
        try {
          if (item is Map) {
            // Convert to Map<String, dynamic> safely
            Map<String, dynamic> topicMap;

            try {
              topicMap = item.cast<String, dynamic>();
            } catch (castError) {
              // If cast fails, try manual conversion
              topicMap = {};
              item.forEach((key, value) {
                if (key is String) {
                  topicMap[key] = value;
                } else {
                  topicMap[key.toString()] = value;
                }
              });
            }

            // Parse the topic
            final topic = Topic.fromJson(topicMap);

            // Validate required fields
            if (topic.id.isNotEmpty && topic.title.isNotEmpty) {
              topics.add(topic);
              print('   - ✅ Added: ${topic.title} (ID: ${topic.id})');
            } else {
              print('   - ⚠️ Skipping: Missing ID or title');
            }
          } else {
            print('   - ⚠️ Skipping non-map item: ${item.runtimeType}');
          }
        } catch (e) {
          print('   - ❌ Error parsing topic: $e');
          print('     Item: $item');
          // Continue with next item
        }
      }

      print(
        '📊 Successfully parsed ${topics.length} out of ${topicsData.length} items',
      );

      // Cache topics for offline use
      if (topics.isNotEmpty) {
        final cacheKey = outlineId != null
            ? 'outline_$outlineId'
            : 'course_$courseId';
        await _cacheTopics(cacheKey, topics);
        print('✅ Cached ${topics.length} topics with key: $cacheKey');
      }

      return topics;
    } on TimeoutException {
      print('⏰ Request timeout - trying cached topics');
      final cacheKey = outlineId != null
          ? 'outline_$outlineId'
          : 'course_$courseId';
      return await _getCachedTopics(cacheKey);
    } catch (e) {
      print('❌ Error getting topics: $e');

      // Try to return cached topics as fallback
      try {
        final cacheKey = outlineId != null
            ? 'outline_$outlineId'
            : 'course_$courseId';
        final cachedTopics = await _getCachedTopics(cacheKey);
        if (cachedTopics.isNotEmpty) {
          print('✅ Loaded ${cachedTopics.length} topics from cache');
          return cachedTopics;
        }
      } catch (cacheError) {
        print('⚠️ Could not load cached topics: $cacheError');
      }

      // Return empty list to prevent UI crash
      return [];
    }
  }

  // Update user progress for a topic

  // // ##########################

  Future<Map<String, dynamic>> submitTopicAnswer({
    required int topicId,
    String? selectedAnswer,
    String? answerText,
  }) async {
    try {
      print('📝 Submitting answer for topic ID: $topicId');

      // GET CURRENT USER ID - ADD THIS SECTION
      final userData = await getCurrentUser();
      if (userData == null || userData['id'] == null) {
        throw Exception("User not found. Please login again.");
      }

      final userId = userData['id'].toString();

      // final Map<String, dynamic> requestData = {
      //   'user_id': userId, // ADD THIS LINE
      // };

      final Map<String, dynamic> requestData = {'user_id': userId};

      if (selectedAnswer != null && selectedAnswer.isNotEmpty) {
        requestData['selected_answer'] = selectedAnswer;
      } else if (answerText != null && answerText.isNotEmpty) {
        requestData['answer_text'] = answerText;
      } else {
        throw Exception(
          'Either selected_answer or answer_text must be provided',
        );
      }

      print('📤 Sending answer data: $requestData');

      final response = await http
          .post(
            Uri.parse(
              '${ApiEndpoints.baseUrl}/api/content/topics/$topicId/submit_completion/',
            ),
            headers: {'Content-Type': 'application/json'},
            body: json.encode(requestData),
          )
          .timeout(const Duration(seconds: 10));

      print('📥 Submit answer response: ${response.statusCode}');
      print('📥 Response body: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        print('✅ Answer submitted successfully');

        // Check if answer was correct and topic completed
        final isCorrect = responseData['is_correct'] ?? false;
        final topicCompleted = responseData['topic_completed'] ?? false;

        return {
          'success': true,
          'is_correct': isCorrect,
          'topic_completed': topicCompleted,
          'correct_answer': responseData['correct_answer'],
          'solution_text': responseData['solution_text'],
          'message': isCorrect ? 'Correct answer!' : 'Incorrect answer',
        };
      } else {
        final errorData = json.decode(response.body);
        final error =
            errorData['detail'] ??
            errorData['error'] ??
            'Failed to submit answer';
        throw Exception('$error (Status: ${response.statusCode})');
      }
    } on TimeoutException {
      print('⏰ Request timeout');
      throw Exception('Network timeout. Please try again.');
    } catch (e) {
      print('❌ Error submitting answer: $e');
      rethrow;
    }
  }

  // Also update your updateTopicProgress method to use the Django endpoint
  Future<Map<String, dynamic>> updateTopicProgress({
    required int topicId,
    required int progressPercentage,
    bool isCompleted = false,
    int? timeSpentMinutes,
  }) async {
    try {
      print('📊 Updating topic progress: $topicId -> $progressPercentage%');

      // GET CURRENT USER ID - ADD THIS SECTION
      final userData = await getCurrentUser();
      if (userData == null || userData['id'] == null) {
        throw Exception("User not found. Please login again.");
      }

      final userId = userData['id'].toString();

      final requestData = {
        'user_id': userId, // ADD THIS LINE
        'progress_percentage': progressPercentage.clamp(0, 100),
        'is_completed': isCompleted,
        'time_spent_minutes': timeSpentMinutes ?? 0,
      };

      final response = await http
          .post(
            Uri.parse(
              '${ApiEndpoints.baseUrl}/api/content/topics/$topicId/update_progress/',
            ),
            headers: {'Content-Type': 'application/json'},
            body: json.encode(requestData),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData = json.decode(response.body);
        print('✅ Topic progress updated on server for user: $userId');
        return responseData;
      } else {
        final errorData = json.decode(response.body);
        final error =
            errorData['detail'] ??
            errorData['error'] ??
            'Failed to update progress';
        throw Exception('$error (Status: ${response.statusCode})');
      }
    } on TimeoutException {
      print('⏰ Request timeout');
      throw Exception('Network timeout. Progress not saved.');
    } catch (e) {
      print('❌ Error updating topic progress: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> submitTopicCompletion({
    required int topicId,
    String? selectedAnswer,
    String? answerText,
  }) async {
    try {
      print('📝 Submitting topic completion for topic ID: $topicId');

      final userData = await getCurrentUser();
      if (userData == null || userData['id'] == null) {
        throw Exception("User not found. Please login again.");
      }

      final userId = userData['id'].toString();

      // Prepare request data matching your TopicCompletionRequestSerializer
      final Map<String, dynamic> requestData = {
        'user_id': userId, // ADD THIS LINE
      };

      if (selectedAnswer != null && selectedAnswer.isNotEmpty) {
        requestData['selected_answer'] = selectedAnswer;
      } else if (answerText != null && answerText.isNotEmpty) {
        requestData['answer_text'] = answerText;
      } else {
        throw Exception(
          'Either selected_answer or answer_text must be provided',
        );
      }

      print('📤 Sending completion data: $requestData');

      // Use the existing endpoint from your Django views
      final response = await http
          .post(
            Uri.parse(
              '${ApiEndpoints.baseUrl}/api/content/topics/$topicId/submit_completion/',
            ),
            headers: {'Content-Type': 'application/json'},
            body: json.encode(requestData),
          )
          .timeout(const Duration(seconds: 10));

      print('📥 Submit completion response: ${response.statusCode}');
      print('📥 Response body: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        print('✅ Topic completion submitted successfully');

        // If correct and topic completed, update local cache
        if (responseData['is_correct'] == true &&
            responseData['topic_completed'] == true) {
          await _updateLocalTopicProgress(topicId, 100, true);
        }

        return responseData;
      } else {
        final errorData = json.decode(response.body);
        final error =
            errorData['detail'] ??
            errorData['error'] ??
            'Failed to submit completion';
        throw Exception('$error (Status: ${response.statusCode})');
      }
    } on TimeoutException {
      print('⏰ Request timeout');
      throw Exception('Network timeout. Please try again.');
    } catch (e) {
      print('❌ Error submitting topic completion: $e');
      rethrow;
    }
  }

  // Also update this method to handle progress percentage:
  Future<void> _updateLocalTopicProgress(
    int topicId,
    int progressPercentage,
    bool isCompleted,
  ) async {
    try {
      final box = await Hive.openBox('topic_progress_cache');
      final progressData = {
        'topic_id': topicId,
        'progress_percentage': progressPercentage,
        'is_completed': isCompleted,
        'updated_at': DateTime.now().toIso8601String(),
      };
      await box.put('topic_$topicId', progressData);
      print(
        '✅ Progress saved locally for topic $topicId: $progressPercentage%',
      );

      // Also update the in-memory cache if you have one
      // This helps with immediate UI updates
    } catch (e) {
      print('⚠️ Error updating local topic progress: $e');
    }
  }
  // ##########################

  // ########################

  // ==================== CACHE METHODS ====================

  // Cache courses for offline use
  Future<void> _cacheCourses(List<Course> courses) async {
    try {
      final box = await Hive.openBox('courses_cache');
      final courseData = courses.map((course) => course.toJson()).toList();
      await box.put('all_courses', courseData);
      await box.put('last_updated', DateTime.now().toIso8601String());
      print('✅ Cached ${courses.length} courses');
    } catch (e) {
      print('⚠️ Error caching courses: $e');
    }
  }

  // Get cached courses
  Future<List<Course>> _getCachedCourses() async {
    try {
      final box = await Hive.openBox('courses_cache');
      final cachedData = box.get('all_courses');

      if (cachedData != null && cachedData is List) {
        final courses = cachedData
            .map((json) => Course.fromJson(json))
            .toList();
        print('📂 Loaded ${courses.length} courses from cache');
        return courses;
      }
    } catch (e) {
      print('⚠️ Error getting cached courses: $e');
    }
    return [];
  }

  // Cache course outlines
  Future<void> _cacheCourseOutlines(
    int courseId,
    List<CourseOutline> outlines,
  ) async {
    try {
      final box = await Hive.openBox('course_outlines_cache');
      final outlineData = outlines.map((outline) => outline.toJson()).toList();
      await box.put('course_$courseId', outlineData);
      print('✅ Cached ${outlines.length} outlines for course $courseId');
    } catch (e) {
      print('⚠️ Error caching outlines: $e');
    }
  }

  // Get cached course outlines
  Future<List<CourseOutline>> _getCachedCourseOutlines(int courseId) async {
    try {
      final box = await Hive.openBox('course_outlines_cache');
      final cachedData = box.get('course_$courseId');

      if (cachedData != null && cachedData is List) {
        final outlines = cachedData
            .map((json) => CourseOutline.fromJson(json))
            .toList();
        print(
          '📂 Loaded ${outlines.length} outlines from cache for course $courseId',
        );
        return outlines;
      }
    } catch (e) {
      print('⚠️ Error getting cached outlines: $courseId: $e');
    }
    return [];
  }

  // Cache topics
  // Future<void> _cacheTopics(String cacheKey, List<Topic> topics) async {
  //   try {
  //     final box = await Hive.openBox('topics_cache');
  //     final topicData = topics.map((topic) => topic.toJson()).toList();
  //     await box.put(cacheKey, topicData);
  //     print('✅ Cached ${topics.length} topics with key: $cacheKey');
  //   } catch (e) {
  //     print('⚠️ Error caching topics: $e');
  //   }
  // }

  // Cache topics
  Future<void> _cacheTopics(String cacheKey, List<Topic> topics) async {
    try {
      final box = await Hive.openBox('topics_cache');

      // Convert topics to JSON with proper type safety
      final List<Map<String, dynamic>> topicData = [];

      for (var topic in topics) {
        try {
          topicData.add(topic.toJson());
        } catch (e) {
          print('⚠️ Error serializing topic ${topic.id}: $e');
        }
      }

      await box.put(cacheKey, topicData);
      print('✅ Cached ${topicData.length} topics with key: $cacheKey');
    } catch (e) {
      print('⚠️ Error caching topics: $e');
    }
  }

  // Get cached topics
  Future<List<Topic>> _getCachedTopics(String cacheKey) async {
    try {
      final box = await Hive.openBox('topics_cache');
      final cachedData = box.get(cacheKey);

      if (cachedData != null && cachedData is List) {
        final topics = cachedData.map((json) => Topic.fromJson(json)).toList();
        print(
          '📂 Loaded ${topics.length} topics from cache with key: $cacheKey',
        );
        return topics;
      }
    } catch (e) {
      print('⚠️ Error getting cached topics for key $cacheKey: $e');
    }
    return [];
  }

  // Save course progress to local cache
  Future<void> _saveCourseProgress(String courseId, int progress) async {
    try {
      final box = await Hive.openBox('course_progress_cache');
      await box.put('progress_$courseId', progress);
      await box.put('last_updated_$courseId', DateTime.now().toIso8601String());
    } catch (e) {
      print('⚠️ Error saving course progress: $e');
    }
  }

  // Get cached course progress
  Future<int> _getCachedCourseProgress(String courseId) async {
    try {
      final box = await Hive.openBox('course_progress_cache');
      final progress = box.get('progress_$courseId');
      return progress ?? 0;
    } catch (e) {
      print('⚠️ Error getting cached course progress: $e');
      return 0;
    }
  }

  // Update local topic progress
  // Future<void> _updateLocalTopicProgress(int topicId, int progressPercentage, bool isCompleted) async {
  //   try {
  //     final box = await Hive.openBox('topic_progress_cache');
  //     final progressData = {
  //       'topic_id': topicId,
  //       'progress_percentage': progressPercentage,
  //       'is_completed': isCompleted,
  //       'updated_at': DateTime.now().toIso8601String(),
  //     };
  //     await box.put('topic_$topicId', progressData);
  //     print('✅ Progress saved locally for topic $topicId');
  //   } catch (e) {
  //     print('⚠️ Error updating local topic progress: $e');
  //   }
  // }

  // ==================== ADDITIONAL COURSE METHODS ====================

  // Get course progress summary
  Future<CourseProgressSummary> getCourseProgressSummary(int courseId) async {
    try {
      print('📊 Getting progress summary for course: $courseId');

      final userData = await getCurrentUser();
      if (userData == null) {
        throw Exception("User not found.");
      }

      // Get course details
      final courses = await getCoursesForUser();
      final course = courses.firstWhere((c) => c.id == courseId.toString());

      // Get topics for this course
      final topics = await getTopics(courseId: courseId);

      // Calculate summary
      int totalTopics = topics.length;
      int completedTopics = topics.where((topic) => topic.isCompleted).length;

      // For now, using placeholder values for questions
      // In a real app, you'd fetch actual quiz attempt data
      int totalQuestions = 0;
      int correctAnswers = 0;
      int totalTimeSpent = 0;

      // Calculate time spent from topics
      for (var topic in topics) {
        totalTimeSpent += topic.timeSpentMinutes;
      }

      final summary = CourseProgressSummary(
        courseId: course.id,
        courseCode: course.code,
        courseTitle: course.title,
        totalTopics: totalTopics,
        completedTopics: completedTopics,
        totalQuestions: totalQuestions,
        correctAnswers: correctAnswers,
        totalTimeSpentMinutes: totalTimeSpent,
        lastAccessed: DateTime.now(),
      );

      print(
        '✅ Course progress summary: ${summary.progressPercentage}% complete',
      );
      return summary;
    } catch (e) {
      print('❌ Error getting course progress summary: $e');
      rethrow;
    }
  }

  // Refresh course data (force reload from server)
  Future<List<Course>> refreshCourses() async {
    try {
      print('🔄 Refreshing courses from server...');

      // Clear cache to force reload
      try {
        final box = await Hive.openBox('courses_cache');
        await box.clear();
        print('✅ Cleared course cache');
      } catch (e) {
        print('⚠️ Error clearing cache: $e');
      }

      // Fetch fresh data
      return await getCoursesForUser();
    } catch (e) {
      print('❌ Error refreshing courses: $e');
      rethrow;
    }
  }

  // Check if user has access to a specific course
  Future<bool> hasCourseAccess(int courseId) async {
    try {
      final courses = await getCoursesForUser();
      return courses.any((course) => course.id == courseId.toString());
    } catch (e) {
      print('❌ Error checking course access: $e');
      return false;
    }
  }

  // Get recent courses (based on last accessed)
  Future<List<Course>> getRecentCourses({int limit = 5}) async {
    try {
      final courses = await getCoursesForUser();

      // Sort by progress (highest first) as a proxy for recent activity
      courses.sort((a, b) => b.progress.compareTo(a.progress));

      // Return limited number
      return courses.take(limit).toList();
    } catch (e) {
      print('❌ Error getting recent courses: $e');
      return [];
    }
  }

  // Sync offline progress with server
  Future<void> syncOfflineProgress() async {
    try {
      print('🔄 Syncing offline progress with server...');

      final box = await Hive.openBox('topic_progress_cache');
      final keys = box.keys.where((key) => key.startsWith('topic_')).toList();

      print('📱 Found ${keys.length} offline progress records to sync');

      for (var key in keys) {
        try {
          final progressData = box.get(key);
          if (progressData != null && progressData is Map) {
            final topicId = int.parse(key.replaceFirst('topic_', ''));
            final progressPercentage = progressData['progress_percentage'] ?? 0;
            final isCompleted = progressData['is_completed'] ?? false;

            // Update progress on server
            await updateTopicProgress(
              topicId: topicId,
              progressPercentage: progressPercentage,
              isCompleted: isCompleted,
            );

            // Remove from offline cache after successful sync
            await box.delete(key);
            print('✅ Synced progress for topic $topicId');
          }
        } catch (e) {
          print('⚠️ Error syncing progress for key $key: $e');
        }
      }

      print('✅ Offline progress sync completed');
    } catch (e) {
      print('❌ Error syncing offline progress: $e');
    }
  }

  // ###############################################################################################
  // #################### FOR PAST-QUESTIONS AND THINGS RELATED TO IT ##############################

  // ==================== PAST QUESTION METHODS ====================

  // 1. Get academic sessions for past questions
  Future<List<PastQuestionSession>> getPastQuestionSessions() async {
    try {
      print('📅 Getting past question sessions...');

      final url =
          '${ApiEndpoints.baseUrl}/api/content/academic-sessions/all_sessions/';
      final response = await http
          .get(Uri.parse(url), headers: {'Content-Type': 'application/json'})
          .timeout(const Duration(seconds: 10));

      print('📥 Sessions response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);

        // Handle both list and paginated responses
        List<dynamic> data;
        if (responseData is List) {
          data = responseData;
        } else if (responseData is Map && responseData.containsKey('results')) {
          data = responseData['results'];
          print(
            '📥 Paginated response: ${responseData['count']} total sessions',
          );
        } else {
          print('❌ Unexpected response format: ${responseData.runtimeType}');
          return [];
        }

        print('✅ Successfully loaded ${data.length} sessions');

        return data.map((json) => PastQuestionSession.fromJson(json)).toList();
      } else {
        print('⚠️ No sessions found, returning empty list');
        return [];
      }
    } catch (e) {
      print('❌ Error getting sessions: $e');
      return [];
    }
  }

  Future<List<PastQuestion>> getPastQuestions({
    required String courseId,
    String? sessionId,
    String? topicId,
  }) async {
    try {
      print('📝 Getting past questions...');
      print('   - Course ID: $courseId');
      print('   - Session ID: $sessionId');
      print('   - Topic ID: $topicId');

      // Build URL - IMPORTANT: Only send topic if it's not null
      final uri = Uri.parse(
        '${ApiEndpoints.baseUrl}/api/content/past-questions/',
      );
      final params = <String, String>{'course': courseId};

      if (sessionId != null && sessionId.isNotEmpty) {
        params['session'] = sessionId;
      }

      // CRITICAL: Only send topic if it's not null
      if (topicId != null && topicId.isNotEmpty) {
        params['topic'] = topicId;
      } else {
        print('   - No topic filter - returning ALL questions for course');
      }

      final url = uri.replace(queryParameters: params);
      print('🌐 API CALL: $url');
      print('🌐 Query Parameters: $params');

      // Rest of your existing method remains the same...
      final response = await http
          .get(url, headers: {'Content-Type': 'application/json'})
          .timeout(const Duration(seconds: 15));

      print('📥 Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        print('📥 Response type: ${responseData.runtimeType}');

        List<dynamic> data = [];

        if (responseData is List) {
          data = responseData;
        } else if (responseData is Map) {
          if (responseData.containsKey('results')) {
            data = responseData['results'];
          } else if (responseData.containsKey('data')) {
            data = responseData['data'];
          } else if (responseData.containsKey('questions')) {
            data = responseData['questions'];
          }
        }

        print('📊 Questions from backend: ${data.length}');

        // Parse questions...
        final questions = <PastQuestion>[];
        for (var json in data) {
          try {
            final question = PastQuestion.fromJson(json);
            if (question.isValid) {
              questions.add(question);
            }
          } catch (e) {
            print('⚠️ Error parsing question: $e');
          }
        }

        print('📊 Valid parsed questions: ${questions.length}');
        return questions;
      } else if (response.statusCode == 404) {
        print('ℹ️ 404 - No questions found');
        return [];
      } else {
        print('❌ Error ${response.statusCode}: ${response.body}');
        return [];
      }
    } catch (e) {
      print('❌ Exception: $e');
      return [];
    }
  }

  // ###########################################

  // 2b. Alternative: Get past questions with session filter only
  Future<List<PastQuestion>> getPastQuestionsBySession({
    required String courseId,
    required String sessionId,
  }) async {
    return getPastQuestions(courseId: courseId, sessionId: sessionId);
  }

  // 2c. Alternative: Get past questions with topic filter only
  Future<List<PastQuestion>> getPastQuestionsByTopicOnly({
    required String courseId,
    required String topicId,
  }) async {
    return getPastQuestions(courseId: courseId, topicId: topicId);
  }

  // 3. Get sessions for a specific course - FIXED VERSION
  Future<List<PastQuestionSession>> getSessionsForCourse(
    String courseId,
  ) async {
    try {
      print('📅 Getting sessions for course: $courseId');

      final url =
          '${ApiEndpoints.baseUrl}/api/content/past-questions/sessions/?course=$courseId';
      print('🌐 Fetching from: $url');

      final response = await http
          .get(Uri.parse(url), headers: {'Content-Type': 'application/json'})
          .timeout(const Duration(seconds: 10));

      print('📥 Course sessions response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);

        // Handle different response formats
        List<dynamic> data;
        if (responseData is List) {
          data = responseData;
        } else if (responseData is Map && responseData.containsKey('results')) {
          data = responseData['results'];
        } else if (responseData is Map && responseData.containsKey('data')) {
          data = responseData['data'];
        } else {
          print('⚠️ Unexpected response format: ${responseData.runtimeType}');
          return [];
        }

        print('✅ Successfully loaded ${data.length} sessions for course');
        return data.map((json) => PastQuestionSession.fromJson(json)).toList();
      } else if (response.statusCode == 404) {
        print('ℹ️ No sessions found for this course');
        return [];
      } else {
        print('⚠️ Failed to load sessions: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('❌ Error getting course sessions: $e');
      return [];
    }
  }

  // 4. Submit answer for a past question - ENHANCED VERSION
  Future<Map<String, dynamic>> submitPastQuestionAnswer({
    required String questionId,
    required String selectedAnswer,
    int timeTakenSeconds = 0,
  }) async {
    try {
      print('📝 Submitting answer for question: $questionId');
      print('   - Selected answer: $selectedAnswer');
      print('   - Time taken: ${timeTakenSeconds}s');

      final userData = await getCurrentUser();
      if (userData == null) {
        throw Exception("User not found. Please login again.");
      }

      final requestData = {
        'selected_answer': selectedAnswer,
        'time_taken_seconds': timeTakenSeconds,
      };

      print('📤 Sending request data: $requestData');

      final response = await http
          .post(
            Uri.parse(
              '${ApiEndpoints.baseUrl}/api/content/past-questions/$questionId/submit_answer/',
            ),
            headers: {'Content-Type': 'application/json'},
            body: json.encode(requestData),
          )
          .timeout(const Duration(seconds: 10));

      print('📥 Submit answer response: ${response.statusCode}');
      print('📥 Response body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData = json.decode(response.body);
        print('✅ Answer submitted successfully');

        // Return full response data for more detailed feedback
        return {
          'is_correct': responseData['is_correct'] ?? false,
          'correct_answer': responseData['correct_answer'],
          'explanation':
              responseData['explanation'] ?? responseData['solution_text'],
          'topic_completed': responseData['topic_completed'] ?? false,
          'score': responseData['score'] ?? 0,
          'message': responseData['message'] ?? 'Answer submitted successfully',
        };
      } else {
        final errorData = json.decode(response.body);
        final error =
            errorData['detail'] ??
            errorData['error'] ??
            'Failed to submit answer';
        throw Exception('$error (Status: ${response.statusCode})');
      }
    } on TimeoutException {
      print('⏰ Request timeout submitting answer');
      throw Exception('Request timeout. Please check your connection.');
    } catch (e) {
      print('❌ Error submitting answer: $e');
      rethrow;
    }
  }

  // 5. Get past questions by topic (grouped) - FIXED VERSION
  Future<Map<String, List<PastQuestion>>> getPastQuestionsByTopic({
    required String courseId,
    String? sessionId,
  }) async {
    try {
      print('📚 Getting past questions grouped by topic...');
      print('   - Course ID: $courseId');
      print('   - Session ID: $sessionId');

      final uri = Uri.parse(
        '${ApiEndpoints.baseUrl}/api/content/past-questions/by_topic/',
      );
      final params = <String, String>{'course': courseId};

      if (sessionId != null && sessionId.isNotEmpty) {
        params['session'] = sessionId;
      }

      final url = uri.replace(queryParameters: params);
      print('🌐 Fetching grouped questions from: $url');

      final response = await http
          .get(url, headers: {'Content-Type': 'application/json'})
          .timeout(const Duration(seconds: 15));

      print('📥 Grouped questions response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);

        List<dynamic> data;
        if (responseData is List) {
          data = responseData;
        } else if (responseData is Map && responseData.containsKey('results')) {
          data = responseData['results'];
        } else {
          print('⚠️ Unexpected response format: ${responseData.runtimeType}');
          return {};
        }

        print('✅ Successfully loaded ${data.length} topic groups');

        final result = <String, List<PastQuestion>>{};
        int totalQuestions = 0;

        for (var group in data) {
          try {
            final topicTitle =
                group['topic_title']?.toString() ?? 'General Questions';
            final topicId = group['topic_id']?.toString();
            final questionsData = (group['questions'] as List?) ?? [];

            final questions = <PastQuestion>[];
            for (var q in questionsData) {
              try {
                final question = PastQuestion.fromJson(q);
                if (question.isValid) {
                  questions.add(question);
                  totalQuestions++;
                }
              } catch (e) {
                print('⚠️ Error parsing question in group "$topicTitle": $e');
              }
            }

            if (questions.isNotEmpty) {
              result[topicTitle] = questions;
              print('   - $topicTitle: ${questions.length} questions');
            }
          } catch (e) {
            print('⚠️ Error processing topic group: $e');
          }
        }

        print('📊 Total questions across all topics: $totalQuestions');
        return result;
      } else if (response.statusCode == 404) {
        print('ℹ️ No grouped questions found');
        return {};
      } else {
        print('⚠️ Failed to load grouped questions: ${response.statusCode}');
        return {};
      }
    } catch (e) {
      print('❌ Error getting grouped questions: $e');
      return {};
    }
  }

  // 6. Get random past questions
  Future<List<PastQuestion>> getRandomPastQuestions({
    required String courseId,
    String? sessionId,
    String? topicId,
    int count = 10,
    int? difficulty,
  }) async {
    try {
      print('🎲 Getting $count random past questions...');
      print('   - Course ID: $courseId');
      print('   - Session ID: $sessionId');
      print('   - Topic ID: $topicId');
      print('   - Difficulty: $difficulty');

      final uri = Uri.parse(
        '${ApiEndpoints.baseUrl}/api/content/past-questions/random/',
      );
      final body = {'course_id': int.parse(courseId), 'n': count};

      if (sessionId != null && sessionId.isNotEmpty) {
        body['session_id'] = int.parse(sessionId);
      }

      if (topicId != null && topicId.isNotEmpty) {
        body['topic_id'] = int.parse(topicId);
      }

      if (difficulty != null && difficulty >= 1 && difficulty <= 3) {
        body['difficulty'] = difficulty;
      }

      final response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: json.encode(body),
          )
          .timeout(const Duration(seconds: 15));

      print('📥 Random questions response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);

        List<dynamic> data;
        if (responseData is List) {
          data = responseData;
        } else if (responseData is Map && responseData.containsKey('results')) {
          data = responseData['results'];
        } else if (responseData is Map &&
            responseData.containsKey('questions')) {
          data = responseData['questions'];
        } else {
          print('⚠️ Unexpected response format: ${responseData.runtimeType}');
          return [];
        }

        print('✅ Successfully loaded ${data.length} random questions');

        final questions = <PastQuestion>[];
        for (var json in data) {
          try {
            final question = PastQuestion.fromJson(json);
            if (question.isValid) {
              questions.add(question);
            }
          } catch (e) {
            print('⚠️ Error parsing random question: $e');
          }
        }

        return questions;
      } else if (response.statusCode == 404) {
        print('ℹ️ No questions found for random selection');
        return [];
      } else {
        final errorData = json.decode(response.body);
        final error =
            errorData['detail'] ??
            errorData['error'] ??
            'Failed to get random questions';
        throw Exception('$error (Status: ${response.statusCode})');
      }
    } catch (e) {
      print('❌ Error getting random questions: $e');
      return [];
    }
  }

  // 7. Get past question statistics
  Future<Map<String, dynamic>> getPastQuestionStats({
    required String courseId,
    String? sessionId,
  }) async {
    try {
      print('📊 Getting past question statistics...');

      final questions = await getPastQuestions(
        courseId: courseId,
        sessionId: sessionId,
      );

      if (questions.isEmpty) {
        return {
          'total_questions': 0,
          'mcq_count': 0,
          'theory_count': 0,
          'easy_count': 0,
          'medium_count': 0,
          'hard_count': 0,
          'total_marks': 0,
          'average_difficulty': 0,
        };
      }

      int mcqCount = 0;
      int theoryCount = 0;
      int easyCount = 0;
      int mediumCount = 0;
      int hardCount = 0;
      int totalMarks = 0;

      for (var question in questions) {
        if (question.isMcq) {
          mcqCount++;
        } else {
          theoryCount++;
        }

        switch (question.difficulty) {
          case 1:
            easyCount++;
            break;
          case 2:
            mediumCount++;
            break;
          case 3:
            hardCount++;
            break;
        }

        totalMarks += question.marks;
      }

      final averageDifficulty =
          ((easyCount * 1) + (mediumCount * 2) + (hardCount * 3)) /
          questions.length;

      return {
        'total_questions': questions.length,
        'mcq_count': mcqCount,
        'theory_count': theoryCount,
        'easy_count': easyCount,
        'medium_count': mediumCount,
        'hard_count': hardCount,
        'total_marks': totalMarks,
        'average_difficulty': averageDifficulty.roundToDouble(),
        'completion_percentage': 0, // Would need user progress data
      };
    } catch (e) {
      print('❌ Error getting stats: $e');
      return {
        'total_questions': 0,
        'mcq_count': 0,
        'theory_count': 0,
        'easy_count': 0,
        'medium_count': 0,
        'hard_count': 0,
        'total_marks': 0,
        'average_difficulty': 0,
      };
    }
  }

  // 8. Search past questions
  Future<List<PastQuestion>> searchPastQuestions({
    required String query,
    String? courseId,
    String? sessionId,
  }) async {
    try {
      print('🔍 Searching past questions: "$query"');

      final uri = Uri.parse(
        '${ApiEndpoints.baseUrl}/api/content/past-questions/',
      );
      final params = <String, String>{'search': query};

      if (courseId != null && courseId.isNotEmpty) {
        params['course'] = courseId;
      }

      if (sessionId != null && sessionId.isNotEmpty) {
        params['session'] = sessionId;
      }

      final url = uri.replace(queryParameters: params);
      print('🌐 Searching from: $url');

      final response = await http
          .get(url, headers: {'Content-Type': 'application/json'})
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);

        List<dynamic> data;
        if (responseData is List) {
          data = responseData;
        } else if (responseData is Map && responseData.containsKey('results')) {
          data = responseData['results'];
        } else {
          return [];
        }

        print('✅ Found ${data.length} matching questions');

        final questions = <PastQuestion>[];
        for (var json in data) {
          try {
            final question = PastQuestion.fromJson(json);
            if (question.isValid) {
              questions.add(question);
            }
          } catch (e) {
            print('⚠️ Error parsing search result: $e');
          }
        }

        return questions;
      }

      return [];
    } catch (e) {
      print('❌ Error searching questions: $e');
      return [];
    }
  }

  // 9. Cache past questions for offline use
  Future<void> _cachePastQuestions({
    required String cacheKey,
    required List<PastQuestion> questions,
  }) async {
    try {
      final box = await Hive.openBox('past_questions_cache');
      final questionData = questions.map((q) => q.toJson()).toList();
      await box.put(cacheKey, questionData);
      await box.put('${cacheKey}_timestamp', DateTime.now().toIso8601String());
      print('✅ Cached ${questions.length} past questions with key: $cacheKey');
    } catch (e) {
      print('⚠️ Error caching past questions: $e');
    }
  }

  // 10. Get cached past questions
  Future<List<PastQuestion>> _getCachedPastQuestions(String cacheKey) async {
    try {
      final box = await Hive.openBox('past_questions_cache');
      final cachedData = box.get(cacheKey);

      if (cachedData != null && cachedData is List) {
        final questions = cachedData
            .map((json) => PastQuestion.fromJson(json))
            .toList();
        print(
          '📂 Loaded ${questions.length} past questions from cache: $cacheKey',
        );
        return questions;
      }
    } catch (e) {
      print('⚠️ Error getting cached past questions: $e');
    }
    return [];
  }

  // ==================== PAST QUESTION TOPIC METHODS ====================

  // Get topics for past questions dropdown
  Future<List<Map<String, dynamic>>> getTopicsForPastQuestions({
    int? courseId,
    int? outlineId,
  }) async {
    try {
      print('📖 Getting topics for past questions...');

      final uri = Uri.parse('${ApiEndpoints.baseUrl}/api/content/topics/');
      final params = <String, String>{};

      if (outlineId != null) {
        params['outline'] = outlineId.toString();
        print('   - Filtering by outline ID: $outlineId');
      } else if (courseId != null) {
        params['course'] = courseId.toString();
        print('   - Filtering by course ID: $courseId');
      } else {
        throw Exception('Either courseId or outlineId must be provided');
      }

      final url = uri.replace(queryParameters: params);
      print('🌐 Fetching topics from: $url');

      final response = await http
          .get(url, headers: {'Content-Type': 'application/json'})
          .timeout(const Duration(seconds: 10));

      print('📥 Topics response: ${response.statusCode}');

      if (response.statusCode >= 400) {
        print('❌ Error response body: ${response.body}');
        throw Exception('Failed to load topics: ${response.statusCode}');
      }

      final responseData = json.decode(response.body);
      print('📥 Response type: ${responseData.runtimeType}');

      List<dynamic> topicsList = [];

      // Handle different response formats
      if (responseData is List) {
        topicsList = responseData;
      } else if (responseData is Map) {
        if (responseData.containsKey('results')) {
          topicsList = responseData['results'];
          print('📥 Paginated response: ${responseData['count']} total topics');
        } else if (responseData.containsKey('data')) {
          topicsList = responseData['data'];
        } else if (responseData.containsKey('topics')) {
          topicsList = responseData['topics'];
        } else {
          // Try to extract from values
          final values = responseData.values.toList();
          if (values.isNotEmpty && values.first is List) {
            topicsList = values.first;
          }
        }
      }

      print('✅ Successfully loaded ${topicsList.length} topics');

      // Convert to dropdown format
      final dropdownTopics = <Map<String, dynamic>>[];
      for (var json in topicsList) {
        try {
          // Extract info from JSON
          final Map<String, dynamic>? outlineInfo = json['outline_info'] is Map
              ? Map<String, dynamic>.from(json['outline_info'] as Map)
              : null;

          final Map<String, dynamic>? courseInfo = json['course_info'] is Map
              ? Map<String, dynamic>.from(json['course_info'] as Map)
              : null;

          final topic = {
            'id': json['id']?.toString() ?? '',
            'title': json['title']?.toString() ?? '',
            'outlineTitle': outlineInfo?['title']?.toString() ?? 'No Outline',
            'outlineId':
                outlineInfo?['id']?.toString() ??
                json['outline']?.toString() ??
                '',
            'courseId':
                courseInfo?['id']?.toString() ??
                outlineInfo?['course_id']?.toString(),
            'courseCode': courseInfo?['code']?.toString(),
          };

          // Only add if it has an ID and title
          if (topic['id']!.isNotEmpty && topic['title']!.isNotEmpty) {
            dropdownTopics.add(topic);
            print('   - Added topic: ${topic['title']} (ID: ${topic['id']})');
          }
        } catch (e) {
          print('⚠️ Error parsing topic: $e');
        }
      }

      print('✅ Converted ${dropdownTopics.length} topics for dropdown');
      return dropdownTopics;
    } on TimeoutException {
      print('⏰ Request timeout getting topics');
      throw Exception('Request timeout. Please check your connection.');
    } on SocketException {
      print('🌐 Network error getting topics');
      throw Exception(
        'You are offline. Please check your internet connection.',
      );
    } catch (e) {
      print('❌ Error getting topics for past questions: $e');
      rethrow;
    }
  }

  // ###############################################################################################
  // #################### FOR TEST-QUESTIONS AND THINGS RELATED TO IT ##############################

  // ==================== TEST QUESTION METHODS ====================

  // 1. Get academic sessions for Test questions
  Future<List<TestQuestionSession>> getTestQuestionSessions() async {
    try {
      print('📅 Getting test question sessions...');

      final url =
          '${ApiEndpoints.baseUrl}/api/content/academic-sessions/all_sessions/';
      final response = await http
          .get(Uri.parse(url), headers: {'Content-Type': 'application/json'})
          .timeout(const Duration(seconds: 10));

      print('📥 Sessions response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);

        // Handle both list and paginated responses
        List<dynamic> data;
        if (responseData is List) {
          data = responseData;
        } else if (responseData is Map && responseData.containsKey('results')) {
          data = responseData['results'];
          print(
            '📥 Paginated response: ${responseData['count']} total sessions',
          );
        } else {
          print('❌ Unexpected response format: ${responseData.runtimeType}');
          return [];
        }

        print('✅ Successfully loaded ${data.length} sessions');

        return data.map((json) => TestQuestionSession.fromJson(json)).toList();
      } else {
        print('⚠️ No sessions found, returning empty list');
        return [];
      }
    } catch (e) {
      print('❌ Error getting sessions: $e');
      return [];
    }
  }

  Future<List<TestQuestion>> getTestQuestions({
    required String courseId,
    String? sessionId,
    String? topicId,
  }) async {
    try {
      print('📝 Getting test questions...');
      print('   - Course ID: $courseId');
      print('   - Session ID: $sessionId');
      print('   - Topic ID: $topicId');

      // Build URL - IMPORTANT: Only send topic if it's not null
      final uri = Uri.parse(
        '${ApiEndpoints.baseUrl}/api/content/test-questions/',
      );
      final params = <String, String>{'course': courseId};

      if (sessionId != null && sessionId.isNotEmpty) {
        params['session'] = sessionId;
      }

      // CRITICAL: Only send topic if it's not null
      if (topicId != null && topicId.isNotEmpty) {
        params['topic'] = topicId;
      } else {
        print('   - No topic filter - returning ALL questions for course');
      }

      final url = uri.replace(queryParameters: params);
      print('🌐 API CALL: $url');
      print('🌐 Query Parameters: $params');

      // Rest of your existing method remains the same...
      final response = await http
          .get(url, headers: {'Content-Type': 'application/json'})
          .timeout(const Duration(seconds: 15));

      print('📥 Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        print('📥 Response type: ${responseData.runtimeType}');

        List<dynamic> data = [];

        if (responseData is List) {
          data = responseData;
        } else if (responseData is Map) {
          if (responseData.containsKey('results')) {
            data = responseData['results'];
          } else if (responseData.containsKey('data')) {
            data = responseData['data'];
          } else if (responseData.containsKey('questions')) {
            data = responseData['questions'];
          }
        }

        print('📊 Questions from backend: ${data.length}');

        // Parse questions...
        final questions = <TestQuestion>[];
        for (var json in data) {
          try {
            final question = TestQuestion.fromJson(json);
            if (question.isValid) {
              questions.add(question);
            }
          } catch (e) {
            print('⚠️ Error parsing question: $e');
          }
        }

        print('📊 Valid parsed questions: ${questions.length}');
        return questions;
      } else if (response.statusCode == 404) {
        print('ℹ️ 404 - No questions found');
        return [];
      } else {
        print('❌ Error ${response.statusCode}: ${response.body}');
        return [];
      }
    } catch (e) {
      print('❌ Exception: $e');
      return [];
    }
  }

  // ###########################################

  // 2b. Alternative: Get test questions with session filter only
  Future<List<TestQuestion>> getTestQuestionsBySession({
    required String courseId,
    required String sessionId,
  }) async {
    return getTestQuestions(courseId: courseId, sessionId: sessionId);
  }

  // 2c. Alternative: Get test questions with topic filter only
  Future<List<TestQuestion>> getTestQuestionsByTopicOnly({
    required String courseId,
    required String topicId,
  }) async {
    return getTestQuestions(courseId: courseId, topicId: topicId);
  }

  // 3. Get sessions for a specific course - FIXED VERSION
  Future<List<TestQuestionSession>> getTestSessionsForCourse(
    String courseId,
  ) async {
    try {
      print('📅 Getting sessions for course: $courseId');

      final url =
          '${ApiEndpoints.baseUrl}/api/content/test-questions/sessions/?course=$courseId';
      print('🌐 Fetching from: $url');

      final response = await http
          .get(Uri.parse(url), headers: {'Content-Type': 'application/json'})
          .timeout(const Duration(seconds: 10));

      print('📥 Course sessions response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);

        // Handle different response formats
        List<dynamic> data;
        if (responseData is List) {
          data = responseData;
        } else if (responseData is Map && responseData.containsKey('results')) {
          data = responseData['results'];
        } else if (responseData is Map && responseData.containsKey('data')) {
          data = responseData['data'];
        } else {
          print('⚠️ Unexpected response format: ${responseData.runtimeType}');
          return [];
        }

        print('✅ Successfully loaded ${data.length} sessions for course');
        return data.map((json) => TestQuestionSession.fromJson(json)).toList();
      } else if (response.statusCode == 404) {
        print('ℹ️ No sessions found for this course');
        return [];
      } else {
        print('⚠️ Failed to load sessions: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('❌ Error getting course sessions: $e');
      return [];
    }
  }

  // 4. Submit answer for a test question - ENHANCED VERSION
  Future<Map<String, dynamic>> submitTestQuestionAnswer({
    required String questionId,
    required String selectedAnswer,
    int timeTakenSeconds = 0,
  }) async {
    try {
      print('📝 Submitting answer for question: $questionId');
      print('   - Selected answer: $selectedAnswer');
      print('   - Time taken: ${timeTakenSeconds}s');

      final userData = await getCurrentUser();
      if (userData == null) {
        throw Exception("User not found. Please login again.");
      }

      final requestData = {
        'selected_answer': selectedAnswer,
        'time_taken_seconds': timeTakenSeconds,
      };

      print('📤 Sending request data: $requestData');

      final response = await http
          .post(
            Uri.parse(
              '${ApiEndpoints.baseUrl}/api/content/test-questions/$questionId/submit_answer/',
            ),
            headers: {'Content-Type': 'application/json'},
            body: json.encode(requestData),
          )
          .timeout(const Duration(seconds: 10));

      print('📥 Submit answer response: ${response.statusCode}');
      print('📥 Response body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData = json.decode(response.body);
        print('✅ Answer submitted successfully');

        // Return full response data for more detailed feedback
        return {
          'is_correct': responseData['is_correct'] ?? false,
          'correct_answer': responseData['correct_answer'],
          'explanation':
              responseData['explanation'] ?? responseData['solution_text'],
          'topic_completed': responseData['topic_completed'] ?? false,
          'score': responseData['score'] ?? 0,
          'message': responseData['message'] ?? 'Answer submitted successfully',
        };
      } else {
        final errorData = json.decode(response.body);
        final error =
            errorData['detail'] ??
            errorData['error'] ??
            'Failed to submit answer';
        throw Exception('$error (Status: ${response.statusCode})');
      }
    } on TimeoutException {
      print('⏰ Request timeout submitting answer');
      throw Exception('Request timeout. Please check your connection.');
    } catch (e) {
      print('❌ Error submitting answer: $e');
      rethrow;
    }
  }

  // 5. Get test questions by topic (grouped) - FIXED VERSION
  Future<Map<String, List<TestQuestion>>> getTestQuestionsByTopic({
    required String courseId,
    String? sessionId,
  }) async {
    try {
      print('📚 Getting test questions grouped by topic...');
      print('   - Course ID: $courseId');
      print('   - Session ID: $sessionId');

      final uri = Uri.parse(
        '${ApiEndpoints.baseUrl}/api/content/test-questions/by_topic/',
      );
      final params = <String, String>{'course': courseId};

      if (sessionId != null && sessionId.isNotEmpty) {
        params['session'] = sessionId;
      }

      final url = uri.replace(queryParameters: params);
      print('🌐 Fetching grouped questions from: $url');

      final response = await http
          .get(url, headers: {'Content-Type': 'application/json'})
          .timeout(const Duration(seconds: 15));

      print('📥 Grouped questions response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);

        List<dynamic> data;
        if (responseData is List) {
          data = responseData;
        } else if (responseData is Map && responseData.containsKey('results')) {
          data = responseData['results'];
        } else {
          print('⚠️ Unexpected response format: ${responseData.runtimeType}');
          return {};
        }

        print('✅ Successfully loaded ${data.length} topic groups');

        final result = <String, List<TestQuestion>>{};
        int totalQuestions = 0;

        for (var group in data) {
          try {
            final topicTitle =
                group['topic_title']?.toString() ?? 'General Questions';
            final topicId = group['topic_id']?.toString();
            final questionsData = (group['questions'] as List?) ?? [];

            final questions = <TestQuestion>[];
            for (var q in questionsData) {
              try {
                final question = TestQuestion.fromJson(q);
                if (question.isValid) {
                  questions.add(question);
                  totalQuestions++;
                }
              } catch (e) {
                print('⚠️ Error parsing question in group "$topicTitle": $e');
              }
            }

            if (questions.isNotEmpty) {
              result[topicTitle] = questions;
              print('   - $topicTitle: ${questions.length} questions');
            }
          } catch (e) {
            print('⚠️ Error processing topic group: $e');
          }
        }

        print('📊 Total questions across all topics: $totalQuestions');
        return result;
      } else if (response.statusCode == 404) {
        print('ℹ️ No grouped questions found');
        return {};
      } else {
        print('⚠️ Failed to load grouped questions: ${response.statusCode}');
        return {};
      }
    } catch (e) {
      print('❌ Error getting grouped questions: $e');
      return {};
    }
  }

  // 6. Get random test questions
  Future<List<TestQuestion>> getRandomTestQuestions({
    required String courseId,
    String? sessionId,
    String? topicId,
    int count = 10,
    int? difficulty,
  }) async {
    try {
      print('🎲 Getting $count random test questions...');
      print('   - Course ID: $courseId');
      print('   - Session ID: $sessionId');
      print('   - Topic ID: $topicId');
      print('   - Difficulty: $difficulty');

      final uri = Uri.parse(
        '${ApiEndpoints.baseUrl}/api/content/test-questions/random/',
      );
      final body = {'course_id': int.parse(courseId), 'n': count};

      if (sessionId != null && sessionId.isNotEmpty) {
        body['session_id'] = int.parse(sessionId);
      }

      if (topicId != null && topicId.isNotEmpty) {
        body['topic_id'] = int.parse(topicId);
      }

      if (difficulty != null && difficulty >= 1 && difficulty <= 3) {
        body['difficulty'] = difficulty;
      }

      final response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: json.encode(body),
          )
          .timeout(const Duration(seconds: 15));

      print('📥 Random questions response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);

        List<dynamic> data;
        if (responseData is List) {
          data = responseData;
        } else if (responseData is Map && responseData.containsKey('results')) {
          data = responseData['results'];
        } else if (responseData is Map &&
            responseData.containsKey('questions')) {
          data = responseData['questions'];
        } else {
          print('⚠️ Unexpected response format: ${responseData.runtimeType}');
          return [];
        }

        print('✅ Successfully loaded ${data.length} random questions');

        final questions = <TestQuestion>[];
        for (var json in data) {
          try {
            final question = TestQuestion.fromJson(json);
            if (question.isValid) {
              questions.add(question);
            }
          } catch (e) {
            print('⚠️ Error parsing random question: $e');
          }
        }

        return questions;
      } else if (response.statusCode == 404) {
        print('ℹ️ No questions found for random selection');
        return [];
      } else {
        final errorData = json.decode(response.body);
        final error =
            errorData['detail'] ??
            errorData['error'] ??
            'Failed to get random questions';
        throw Exception('$error (Status: ${response.statusCode})');
      }
    } catch (e) {
      print('❌ Error getting random questions: $e');
      return [];
    }
  }

  // 7. Get test question statistics
  Future<Map<String, dynamic>> getTestQuestionStats({
    required String courseId,
    String? sessionId,
  }) async {
    try {
      print('📊 Getting test question statistics...');

      final questions = await getTestQuestions(
        courseId: courseId,
        sessionId: sessionId,
      );

      if (questions.isEmpty) {
        return {
          'total_questions': 0,
          'mcq_count': 0,
          'theory_count': 0,
          'easy_count': 0,
          'medium_count': 0,
          'hard_count': 0,
          'total_marks': 0,
          'average_difficulty': 0,
        };
      }

      int mcqCount = 0;
      int theoryCount = 0;
      int easyCount = 0;
      int mediumCount = 0;
      int hardCount = 0;
      int totalMarks = 0;

      for (var question in questions) {
        if (question.isMcq) {
          mcqCount++;
        } else {
          theoryCount++;
        }

        switch (question.difficulty) {
          case 1:
            easyCount++;
            break;
          case 2:
            mediumCount++;
            break;
          case 3:
            hardCount++;
            break;
        }

        totalMarks += question.marks;
      }

      final averageDifficulty =
          ((easyCount * 1) + (mediumCount * 2) + (hardCount * 3)) /
          questions.length;

      return {
        'total_questions': questions.length,
        'mcq_count': mcqCount,
        'theory_count': theoryCount,
        'easy_count': easyCount,
        'medium_count': mediumCount,
        'hard_count': hardCount,
        'total_marks': totalMarks,
        'average_difficulty': averageDifficulty.roundToDouble(),
        'completion_percentage': 0, // Would need user progress data
      };
    } catch (e) {
      print('❌ Error getting stats: $e');
      return {
        'total_questions': 0,
        'mcq_count': 0,
        'theory_count': 0,
        'easy_count': 0,
        'medium_count': 0,
        'hard_count': 0,
        'total_marks': 0,
        'average_difficulty': 0,
      };
    }
  }

  // 8. Search test questions
  Future<List<TestQuestion>> searchTestQuestions({
    required String query,
    String? courseId,
    String? sessionId,
  }) async {
    try {
      print('🔍 Searching test questions: "$query"');

      final uri = Uri.parse(
        '${ApiEndpoints.baseUrl}/api/content/test-questions/',
      );
      final params = <String, String>{'search': query};

      if (courseId != null && courseId.isNotEmpty) {
        params['course'] = courseId;
      }

      if (sessionId != null && sessionId.isNotEmpty) {
        params['session'] = sessionId;
      }

      final url = uri.replace(queryParameters: params);
      print('🌐 Searching from: $url');

      final response = await http
          .get(url, headers: {'Content-Type': 'application/json'})
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);

        List<dynamic> data;
        if (responseData is List) {
          data = responseData;
        } else if (responseData is Map && responseData.containsKey('results')) {
          data = responseData['results'];
        } else {
          return [];
        }

        print('✅ Found ${data.length} matching questions');

        final questions = <TestQuestion>[];
        for (var json in data) {
          try {
            final question = TestQuestion.fromJson(json);
            if (question.isValid) {
              questions.add(question);
            }
          } catch (e) {
            print('⚠️ Error parsing search result: $e');
          }
        }

        return questions;
      }

      return [];
    } catch (e) {
      print('❌ Error searching questions: $e');
      return [];
    }
  }

  // 9. Cache test questions for offline use
  Future<void> _cacheTestQuestions({
    required String cacheKey,
    required List<TestQuestion> questions,
  }) async {
    try {
      final box = await Hive.openBox('test_questions_cache');
      final questionData = questions.map((q) => q.toJson()).toList();
      await box.put(cacheKey, questionData);
      await box.put('${cacheKey}_timestamp', DateTime.now().toIso8601String());
      print('✅ Cached ${questions.length} test questions with key: $cacheKey');
    } catch (e) {
      print('⚠️ Error caching test questions: $e');
    }
  }

  // 10. Get cached test questions
  Future<List<TestQuestion>> _getCachedTestQuestions(String cacheKey) async {
    try {
      final box = await Hive.openBox('test_questions_cache');
      final cachedData = box.get(cacheKey);

      if (cachedData != null && cachedData is List) {
        final questions = cachedData
            .map((json) => TestQuestion.fromJson(json))
            .toList();
        print(
          '📂 Loaded ${questions.length} text questions from cache: $cacheKey',
        );
        return questions;
      }
    } catch (e) {
      print('⚠️ Error getting cached text questions: $e');
    }
    return [];
  }

  // ==================== TEST QUESTION TOPIC METHODS ====================

  // Get topics for test questions dropdown
  Future<List<Map<String, dynamic>>> getTopicsForTestQuestions({
    int? courseId,
    int? outlineId,
  }) async {
    try {
      print('📖 Getting topics for test questions...');

      final uri = Uri.parse('${ApiEndpoints.baseUrl}/api/content/topics/');
      final params = <String, String>{};

      if (outlineId != null) {
        params['outline'] = outlineId.toString();
        print('   - Filtering by outline ID: $outlineId');
      } else if (courseId != null) {
        params['course'] = courseId.toString();
        print('   - Filtering by course ID: $courseId');
      } else {
        throw Exception('Either courseId or outlineId must be provided');
      }

      final url = uri.replace(queryParameters: params);
      print('🌐 Fetching topics from: $url');

      final response = await http
          .get(url, headers: {'Content-Type': 'application/json'})
          .timeout(const Duration(seconds: 10));

      print('📥 Topics response: ${response.statusCode}');

      if (response.statusCode >= 400) {
        print('❌ Error response body: ${response.body}');
        throw Exception('Failed to load topics: ${response.statusCode}');
      }

      final responseData = json.decode(response.body);
      print('📥 Response type: ${responseData.runtimeType}');

      List<dynamic> topicsList = [];

      // Handle different response formats
      if (responseData is List) {
        topicsList = responseData;
      } else if (responseData is Map) {
        if (responseData.containsKey('results')) {
          topicsList = responseData['results'];
          print('📥 Paginated response: ${responseData['count']} total topics');
        } else if (responseData.containsKey('data')) {
          topicsList = responseData['data'];
        } else if (responseData.containsKey('topics')) {
          topicsList = responseData['topics'];
        } else {
          // Try to extract from values
          final values = responseData.values.toList();
          if (values.isNotEmpty && values.first is List) {
            topicsList = values.first;
          }
        }
      }

      print('✅ Successfully loaded ${topicsList.length} topics');

      // Convert to dropdown format
      final dropdownTopics = <Map<String, dynamic>>[];
      for (var json in topicsList) {
        try {
          // Extract info from JSON
          final Map<String, dynamic>? outlineInfo = json['outline_info'] is Map
              ? Map<String, dynamic>.from(json['outline_info'] as Map)
              : null;

          final Map<String, dynamic>? courseInfo = json['course_info'] is Map
              ? Map<String, dynamic>.from(json['course_info'] as Map)
              : null;

          final topic = {
            'id': json['id']?.toString() ?? '',
            'title': json['title']?.toString() ?? '',
            'outlineTitle': outlineInfo?['title']?.toString() ?? 'No Outline',
            'outlineId':
                outlineInfo?['id']?.toString() ??
                json['outline']?.toString() ??
                '',
            'courseId':
                courseInfo?['id']?.toString() ??
                outlineInfo?['course_id']?.toString(),
            'courseCode': courseInfo?['code']?.toString(),
          };

          // Only add if it has an ID and title
          if (topic['id']!.isNotEmpty && topic['title']!.isNotEmpty) {
            dropdownTopics.add(topic);
            print('   - Added topic: ${topic['title']} (ID: ${topic['id']})');
          }
        } catch (e) {
          print('⚠️ Error parsing topic: $e');
        }
      }

      print('✅ Converted ${dropdownTopics.length} topics for dropdown');
      return dropdownTopics;
    } on TimeoutException {
      print('⏰ Request timeout getting topics');
      throw Exception('Request timeout. Please check your connection.');
    } on SocketException {
      print('🌐 Network error getting topics');
      throw Exception(
        'You are offline. Please check your internet connection.',
      );
    } catch (e) {
      print('❌ Error getting topics for test questions: $e');
      rethrow;
    }
  }

  // ##################################################################
  // ################# GETTING OFFLINE QUESTIONS ######################
  // ################
  // Get past questions from offline storage
  Future<List<PastQuestion>> getOfflinePastQuestions(String courseId) async {
    try {
      print('📂 Getting offline past questions for course: $courseId');

      final offlineBox = await Hive.openBox('offline_courses');
      final courseData = offlineBox.get('course_$courseId');

      if (courseData == null) {
        print('⚠️ No offline data found for course: $courseId');
        return [];
      }

      if (courseData['past_questions'] == null) {
        print('⚠️ No past questions found in offline data');
        return [];
      }

      final pastQuestionsData = courseData['past_questions'] as List;
      print('✅ Found ${pastQuestionsData.length} past questions offline');

      // Replace image URLs with local paths if available
      final List<PastQuestion> pastQuestions = [];

      for (var pqData in pastQuestionsData) {
        try {
          final pqMap = Map<String, dynamic>.from(pqData);

          // Check for local image paths
          if (courseData['downloaded_images'] != null) {
            final downloadedImages = Map<String, String>.from(
              courseData['downloaded_images'],
            );

            // Replace question image URL with local path
            final questionImageKey = 'past_question_${pqMap['id']}';
            if (downloadedImages.containsKey(questionImageKey)) {
              pqMap['question_image'] = downloadedImages[questionImageKey];
            }

            // Replace solution image URL with local path
            final solutionImageKey = 'past_question_solution_${pqMap['id']}';
            if (downloadedImages.containsKey(solutionImageKey)) {
              pqMap['solution_image'] = downloadedImages[solutionImageKey];
            }
          }

          final pastQuestion = PastQuestion.fromJson(pqMap);
          pastQuestions.add(pastQuestion);
        } catch (e) {
          print('⚠️ Error parsing offline past question: $e');
        }
      }

      return pastQuestions;
    } catch (e) {
      print('❌ Error getting offline past questions: $e');
      return [];
    }
  }

  // Get test questions from offline storage
  Future<List<TestQuestion>> getOfflineTestQuestions(String courseId) async {
    try {
      print('📂 Getting offline test questions for course: $courseId');

      final offlineBox = await Hive.openBox('offline_courses');
      final courseData = offlineBox.get('course_$courseId');

      if (courseData == null) {
        print('⚠️ No offline data found for course: $courseId');
        return [];
      }

      if (courseData['test_questions'] == null) {
        print('⚠️ No test questions found in offline data');
        return [];
      }

      final testQuestionsData = courseData['test_questions'] as List;
      print('✅ Found ${testQuestionsData.length} test questions offline');

      // Replace image URLs with local paths if available
      final List<TestQuestion> testQuestions = [];

      for (var tqData in testQuestionsData) {
        try {
          final tqMap = Map<String, dynamic>.from(tqData);

          // Check for local image paths
          if (courseData['downloaded_images'] != null) {
            final downloadedImages = Map<String, String>.from(
              courseData['downloaded_images'],
            );

            // Replace question image URL with local path
            final questionImageKey = 'test_question_${tqMap['id']}';
            if (downloadedImages.containsKey(questionImageKey)) {
              tqMap['question_image'] = downloadedImages[questionImageKey];
            }

            // Replace solution image URL with local path
            final solutionImageKey = 'test_question_solution_${tqMap['id']}';
            if (downloadedImages.containsKey(solutionImageKey)) {
              tqMap['solution_image'] = downloadedImages[solutionImageKey];
            }
          }

          final testQuestion = TestQuestion.fromJson(tqMap);
          testQuestions.add(testQuestion);
        } catch (e) {
          print('⚠️ Error parsing offline test question: $e');
        }
      }

      return testQuestions;
    } catch (e) {
      print('❌ Error getting offline test questions: $e');
      return [];
    }
  }

  // In your ApiService class
  Future<Map<String, dynamic>> getCourseOfflineStatus(String courseId) async {
    try {
      final offlineBox = await Hive.openBox('offline_courses');
      final courseData = offlineBox.get('course_$courseId');

      if (courseData == null) {
        return {
          'is_downloaded': false,
          'has_past_questions': false,
          'has_test_questions': false,
          'past_question_count': 0,
          'test_question_count': 0,
        };
      }

      final pastQuestions = courseData['past_questions'] as List?;
      final testQuestions = courseData['test_questions'] as List?;

      return {
        'is_downloaded': true,
        'has_past_questions': pastQuestions != null && pastQuestions.isNotEmpty,
        'has_test_questions': testQuestions != null && testQuestions.isNotEmpty,
        'past_question_count': pastQuestions?.length ?? 0,
        'test_question_count': testQuestions?.length ?? 0,
      };
    } catch (e) {
      print('❌ Error checking course offline status: $e');
      return {
        'is_downloaded': false,
        'has_past_questions': false,
        'has_test_questions': false,
        'past_question_count': 0,
        'test_question_count': 0,
      };
    }
  }

  // #############################################################################
  // #############################################################################
  // ######################## QUESTIONS PAST FLAGS ####################################

  // lib/core/network/api_service.dart — Add these methods

  // ==================== FLAGGING METHODS ====================

  // 1. Flag a past question

  Future<Map<String, dynamic>> flagPastQuestion({
    required String questionId,
    required String reason,
    String? description,
  }) async {
    try {
      print('🚩 === FLAG QUESTION START ===');

      // Get current user ID
      final userData = await getCurrentUser();

      if (userData == null) {
        print('❌ User authentication failed - no user data');
        throw Exception('User authentication required. Please login first.');
      }

      final userId = userData['id'];

      if (userId == null) {
        print('❌ No user ID found in user data');
        throw Exception('User ID not found. Please login again.');
      }

      print('📱 User data:');
      print('   - ID: $userId (type: ${userId.runtimeType})');
      print('   - Username: ${userData['username']}');
      print('   - Email: ${userData['email']}');
      print('🚩 Question ID: $questionId');
      print('🎯 Reason: $reason');

      // Prepare request body
      final requestBody = {
        'user_id': userId, // Send as-is, Django will handle conversion
        'reason': reason,
        'description': description ?? '',
      };

      print('📦 Request body: $requestBody');

      final url =
          '${ApiEndpoints.baseUrl}/api/content/past-questions/$questionId/flag/';
      print('🌐 URL: $url');

      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: json.encode(requestBody),
      );

      print('📥 Response status: ${response.statusCode}');
      print('📥 Response body: ${response.body}');

      if (response.statusCode == 201 || response.statusCode == 200) {
        final data = json.decode(response.body);
        print('✅ Question flagged successfully');
        print('   Response data: $data');
        return data;
      } else {
        // Parse error response
        final errorResponse = json.decode(response.body);
        final errorMessage =
            errorResponse['detail'] ??
            errorResponse['message'] ??
            'Failed to flag question (Status: ${response.statusCode})';

        print('❌ Server error: $errorMessage');
        throw Exception(errorMessage);
      }
    } on http.ClientException catch (e) {
      print('❌ Network error: $e');
      throw Exception('Network error: $e');
    } on FormatException catch (e) {
      print('❌ JSON parsing error: $e');
      throw Exception('Invalid server response');
    } catch (e) {
      print('❌ Unexpected error: $e');
      rethrow;
    } finally {
      print('🚩 === FLAG QUESTION END ===');
    }
  }

  // Also update the unflag method:

  Future<Map<String, dynamic>> unflagPastQuestion({
    required String questionId,
  }) async {
    try {
      print('🚩 === UNFLAG QUESTION START ===');

      // Get current user ID
      final userData = await getCurrentUser();

      if (userData == null) {
        print('❌ User authentication failed - no user data');
        throw Exception('User authentication required. Please login first.');
      }

      final userId = userData['id'];

      if (userId == null) {
        print('❌ No user ID found in user data');
        throw Exception('User ID not found. Please login again.');
      }

      print('📱 User ID: $userId');
      print('🚩 Question ID: $questionId');

      // Prepare request body
      final requestBody = {'user_id': userId};

      print('📦 Request body: $requestBody');

      final url =
          '${ApiEndpoints.baseUrl}/api/content/past-questions/$questionId/unflag/';
      print('🌐 URL: $url');

      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: json.encode(requestBody),
      );

      print('📥 Response status: ${response.statusCode}');
      print('📥 Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('✅ Flag removed successfully');
        return data;
      } else {
        final errorResponse = json.decode(response.body);
        final errorMessage =
            errorResponse['detail'] ??
            errorResponse['message'] ??
            'Failed to remove flag (Status: ${response.statusCode})';

        print('❌ Server error: $errorMessage');
        throw Exception(errorMessage);
      }
    } catch (e) {
      print('❌ Error unflagging question: $e');
      rethrow;
    } finally {
      print('🚩 === UNFLAG QUESTION END ===');
    }
  }

  // 3. Get flag status for a question - FIXED VERSION (handles unauthenticated users)
  Future<Map<String, dynamic>> getQuestionFlagStatus({
    required String questionId,
  }) async {
    try {
      print('🚩 Getting flag status for question: $questionId');

      // Get current user ID
      final userData = await getCurrentUser();
      final userId = userData?['id']?.toString();

      // Build URL with user_id query parameter if available
      String url =
          '${ApiEndpoints.baseUrl}/api/content/past-questions/$questionId/flag-status/';
      if (userId != null && userId.isNotEmpty) {
        url += '?user_id=$userId';
      }

      print('🌐 Fetching flag status from: $url');

      final response = await http.get(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
      );

      print('📥 Flag status response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('✅ Flag status data: $data');

        return {
          'is_authenticated': data['is_authenticated'] ?? false,
          'is_flagged': data['is_flagged'] ?? false,
          'total_flags': data['total_flags'] ?? 0,
          'message': data['message'] ?? '',
        };
      } else if (response.statusCode == 401) {
        print('⚠️ Authentication required for flag status');
        return {
          'is_authenticated': false,
          'is_flagged': false,
          'total_flags': 0,
          'message': 'Authentication required',
        };
      } else {
        print('⚠️ Error response body: ${response.body}');
        throw Exception('Failed to get flag status: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error in getQuestionFlagStatus: $e');

      // Return a safe default response on error
      return {
        'is_authenticated': false,
        'is_flagged': false,
        'total_flags': 0,
        'message': 'Error fetching flag status: $e',
      };
    }
  }

  // 4. Get user's flagged questions
  Future<List<dynamic>> getUserFlaggedQuestions({bool? isResolved}) async {
    try {
      print('🚩 Getting user flagged questions');
      print('   - Resolved filter: $isResolved');

      final uri = Uri.parse(
        '${ApiEndpoints.baseUrl}/api/content/flagged-questions/',
      );
      final params = <String, String>{};

      if (isResolved != null) {
        params['is_resolved'] = isResolved.toString();
      }

      final url = uri.replace(queryParameters: params);
      print('🌐 Fetching from: $url');

      final response = await http
          .get(
            url,
            headers: {
              'Content-Type': 'application/json',
              ...await _getAuthHeaders(),
            },
          )
          .timeout(const Duration(seconds: 10));

      print('📥 Flagged questions response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);

        List<dynamic> data = [];
        if (responseData is List) {
          data = responseData;
        } else if (responseData is Map && responseData.containsKey('results')) {
          data = responseData['results'];
        }

        print('✅ Successfully loaded ${data.length} flagged questions');
        return data;
      } else if (response.statusCode == 401) {
        print('⚠️ User not authenticated');
        return [];
      } else {
        print('⚠️ Failed to load flagged questions: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('❌ Error getting flagged questions: $e');
      return [];
    }
  }

  // Helper method to get auth headers
  // Future<Map<String, String>> _getAuthHeaders() async {
  //   final headers = <String, String>{'Content-Type': 'application/json'};

  //   try {
  //     // Try to get token from storage
  //     final prefs = await SharedPreferences.getInstance();
  //     final token = prefs.getString('token');

  //     if (token != null && token.isNotEmpty) {
  //       headers['Authorization'] = 'Token $token';
  //       print('✅ Token found and added to headers');
  //     } else {
  //       print('⚠️ No token found in SharedPreferences');
  //     }
  //   } catch (e) {
  //     print('❌ Error getting token from SharedPreferences: $e');
  //   }

  //   return headers;
  // }

  // NEW METHOD: Make authenticated HTTP requests
  Future<http.Response> _makeHttpRequest(Uri url) async {
    try {
      // Get auth headers with proper token
      final headers = await _getAuthHeaders();

      print('Making request to: $url');
      print('Headers: $headers');

      final response = await http
          .get(url, headers: headers)
          .timeout(const Duration(seconds: 30));

      return response;
    } catch (e) {
      print('HTTP request failed: $e');
      rethrow;
    }
  }

  // NEW METHOD: Get authentication headers with token
  Future<Map<String, String>> _getAuthHeaders() async {
    final headers = <String, String>{'Content-Type': 'application/json'};

    try {
      // Check if user is logged in
      final box = await Hive.openBox('user_box');
      final userData = box.get('current_user');

      if (userData != null && userData['id'] != null) {
        print('User is logged in, ID: ${userData['id']}');

        // Get token from SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        final token = prefs.getString('token');

        if (token != null && token.isNotEmpty) {
          headers['Authorization'] = 'Token $token';
          print('✅ Added auth token to headers');
        } else {
          print('⚠️ No token found in SharedPreferences');

          // If no token but user is logged in, we might need to send user_id
          headers['User-Id'] = userData['id'].toString();
        }
      } else {
        print('⚠️ User not logged in or no user data found');
      }
    } catch (e) {
      print('❌ Error getting auth headers: $e');
    }

    return headers;
  }

  // Add these helper methods for authentication
  Future<String?> _getToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      print(
        '🔑 Token from SharedPreferences: ${token != null ? "Found" : "Not found"}',
      );
      return token;
    } catch (e) {
      print('❌ Error getting token: $e');
      return null;
    }
  }

  Future<int?> _getUserId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getInt('user_id');
      print('👤 User ID from SharedPreferences: $userId');
      return userId;
    } catch (e) {
      print('❌ Error getting user ID: $e');
      return null;
    }
  }

  // #############################################################################
  // ######################## QUESTIONS TEST FLAGS ####################################

  // lib/core/network/api_service.dart — Add these methods

  // ==================== FLAGGING METHODS ====================

  // 1. Flag a test question

  Future<Map<String, dynamic>> flagTestQuestion({
    required String questionId,
    required String reason,
    String? description,
  }) async {
    try {
      print('🚩 === FLAG QUESTION START ===');

      // Get current user ID
      final userData = await getCurrentUser();

      if (userData == null) {
        print('❌ User authentication failed - no user data');
        throw Exception('User authentication required. Please login first.');
      }

      final userId = userData['id'];

      if (userId == null) {
        print('❌ No user ID found in user data');
        throw Exception('User ID not found. Please login again.');
      }

      print('📱 User data:');
      print('   - ID: $userId (type: ${userId.runtimeType})');
      print('   - Username: ${userData['username']}');
      print('   - Email: ${userData['email']}');
      print('🚩 Question ID: $questionId');
      print('🎯 Reason: $reason');

      // Prepare request body
      final requestBody = {
        'user_id': userId, // Send as-is, Django will handle conversion
        'reason': reason,
        'description': description ?? '',
      };

      print('📦 Request body: $requestBody');

      final url =
          '${ApiEndpoints.baseUrl}/api/content/test-questions/$questionId/flag/';
      print('🌐 URL: $url');

      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: json.encode(requestBody),
      );

      print('📥 Response status: ${response.statusCode}');
      print('📥 Response body: ${response.body}');

      if (response.statusCode == 201 || response.statusCode == 200) {
        final data = json.decode(response.body);
        print('✅ Question flagged successfully');
        print('   Response data: $data');
        return data;
      } else {
        // Parse error response
        final errorResponse = json.decode(response.body);
        final errorMessage =
            errorResponse['detail'] ??
            errorResponse['message'] ??
            'Failed to flag question (Status: ${response.statusCode})';

        print('❌ Server error: $errorMessage');
        throw Exception(errorMessage);
      }
    } on http.ClientException catch (e) {
      print('❌ Network error: $e');
      throw Exception('Network error: $e');
    } on FormatException catch (e) {
      print('❌ JSON parsing error: $e');
      throw Exception('Invalid server response');
    } catch (e) {
      print('❌ Unexpected error: $e');
      rethrow;
    } finally {
      print('🚩 === FLAG QUESTION END ===');
    }
  }

  // Also update the unflag method:

  Future<Map<String, dynamic>> unflagTestQuestion({
    required String questionId,
  }) async {
    try {
      print('🚩 === UNFLAG QUESTION START ===');

      // Get current user ID
      final userData = await getCurrentUser();

      if (userData == null) {
        print('❌ User authentication failed - no user data');
        throw Exception('User authentication required. Please login first.');
      }

      final userId = userData['id'];

      if (userId == null) {
        print('❌ No user ID found in user data');
        throw Exception('User ID not found. Please login again.');
      }

      print('📱 User ID: $userId');
      print('🚩 Question ID: $questionId');

      // Prepare request body
      final requestBody = {'user_id': userId};

      print('📦 Request body: $requestBody');

      final url =
          '${ApiEndpoints.baseUrl}/api/content/test-questions/$questionId/unflag/';
      print('🌐 URL: $url');

      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: json.encode(requestBody),
      );

      print('📥 Response status: ${response.statusCode}');
      print('📥 Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('✅ Flag removed successfully');
        return data;
      } else {
        final errorResponse = json.decode(response.body);
        final errorMessage =
            errorResponse['detail'] ??
            errorResponse['message'] ??
            'Failed to remove flag (Status: ${response.statusCode})';

        print('❌ Server error: $errorMessage');
        throw Exception(errorMessage);
      }
    } catch (e) {
      print('❌ Error unflagging question: $e');
      rethrow;
    } finally {
      print('🚩 === UNFLAG QUESTION END ===');
    }
  }

  // 3. Get flag status for a question - FIXED VERSION (handles unauthenticated users)
  Future<Map<String, dynamic>> getTestQuestionFlagStatus({
    required String questionId,
  }) async {
    try {
      print('🚩 Getting flag status for question: $questionId');

      // Get current user ID
      final userData = await getCurrentUser();
      final userId = userData?['id']?.toString();

      // Build URL with user_id query parameter if available
      String url =
          '${ApiEndpoints.baseUrl}/api/content/test-questions/$questionId/flag-status/';
      if (userId != null && userId.isNotEmpty) {
        url += '?user_id=$userId';
      }

      print('🌐 Fetching flag status from: $url');

      final response = await http.get(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
      );

      print('📥 Flag status response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('✅ Flag status data: $data');

        return {
          'is_authenticated': data['is_authenticated'] ?? false,
          'is_flagged': data['is_flagged'] ?? false,
          'total_flags': data['total_flags'] ?? 0,
          'message': data['message'] ?? '',
        };
      } else if (response.statusCode == 401) {
        print('⚠️ Authentication required for flag status');
        return {
          'is_authenticated': false,
          'is_flagged': false,
          'total_flags': 0,
          'message': 'Authentication required',
        };
      } else {
        print('⚠️ Error response body: ${response.body}');
        throw Exception('Failed to get flag status: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error in getTestQuestionFlagStatus: $e');

      // Return a safe default response on error
      return {
        'is_authenticated': false,
        'is_flagged': false,
        'total_flags': 0,
        'message': 'Error fetching flag status: $e',
      };
    }
  }

  // 4. Get user's flagged questions
  Future<List<dynamic>> getUserFlaggedTestQuestions({bool? isResolved}) async {
    try {
      print('🚩 Getting user flagged questions');
      print('   - Resolved filter: $isResolved');

      final uri = Uri.parse(
        '${ApiEndpoints.baseUrl}/api/content/test-flagged-questions/',
      );
      final params = <String, String>{};

      if (isResolved != null) {
        params['is_resolved'] = isResolved.toString();
      }

      final url = uri.replace(queryParameters: params);
      print('🌐 Fetching from: $url');

      final response = await http
          .get(
            url,
            headers: {
              'Content-Type': 'application/json',
              ...await _getAuthHeaders(),
            },
          )
          .timeout(const Duration(seconds: 10));

      print('📥 Flagged questions response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);

        List<dynamic> data = [];
        if (responseData is List) {
          data = responseData;
        } else if (responseData is Map && responseData.containsKey('results')) {
          data = responseData['results'];
        }

        print('✅ Successfully loaded ${data.length} flagged questions');
        return data;
      } else if (response.statusCode == 401) {
        print('⚠️ User not authenticated');
        return [];
      } else {
        print('⚠️ Failed to load flagged questions: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('❌ Error getting flagged questions: $e');
      return [];
    }
  }

  // ###########################################################################
  // Add these methods to your ApiService class in the appropriate section

  // ==================== STUDY GUIDE METHODS ====================

  // ==================== MAIN METHOD ====================

  Future<List<StudyDocument>> getStudyGuidesForUser() async {
    try {
      print('📚 Getting study guides for logged in user...');

      // Get current user data
      final userData = await getCurrentUser();
      if (userData == null || userData['id'] == null) {
        throw Exception("User not found. Please login again.");
      }

      final userId = userData['id'].toString();
      print('👤 User ID: $userId');

      // Extract academic information DIRECTLY from userData
      String? universityId;
      String? departmentId;
      String? levelId;
      String? semesterId;

      // Extract from userData (not from profile)
      if (userData['university'] is Map) {
        universityId = userData['university']['id']?.toString();
      }

      if (userData['department'] is Map) {
        departmentId = userData['department']['id']?.toString();
      }

      if (userData['level'] is Map) {
        levelId = userData['level']['id']?.toString();
      }

      if (userData['semester'] is Map) {
        semesterId = userData['semester']['id']?.toString();
      }

      print('🎓 User academic IDs:');
      print('   - University: $universityId');
      print('   - Department: $departmentId');
      print('   - Level: $levelId');
      print('   - Semester: $semesterId');

      // If any required field is missing, use the by_user_id endpoint
      if (universityId == null || levelId == null || semesterId == null) {
        print('⚠️ Missing academic IDs, using user_id endpoint...');
        return await _getStudyGuidesByUserId(userId);
      }

      // Build query parameters
      final params = <String, String>{
        'university': universityId,
        'level': levelId,
        'semester': semesterId,
      };

      // Department is optional
      if (departmentId != null &&
          departmentId.isNotEmpty &&
          departmentId != 'null') {
        params['department'] = departmentId;
      }

      // Fetch study guides - try WITHOUT token first
      final uri = Uri.parse('${ApiEndpoints.studyGuides}');
      final url = uri.replace(queryParameters: params);

      print('🌐 Fetching study guides from: $url');

      final response = await http
          .get(url, headers: {'Content-Type': 'application/json'})
          .timeout(const Duration(seconds: 15));

      print('📥 Study guides response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        print('✅ Successfully loaded study guides');

        return _parseStudyGuidesResponse(responseData);
      } else if (response.statusCode == 401) {
        print('🔑 Authentication failed, trying user_id endpoint...');
        return await _getStudyGuidesByUserId(userId);
      } else if (response.statusCode == 404) {
        print('ℹ️ No study guides found for your academic profile');
        return [];
      } else {
        print('❌ Error ${response.statusCode}: ${response.body}');
        return await _getStudyGuidesByUserId(userId);
      }
    } on TimeoutException {
      print('⏰ Request timeout - trying cached guides');
      return await _getCachedStudyGuides();
    } catch (e) {
      print('❌ Error getting study guides: $e');
      return [];
    }
  }

  // ==================== PARSING METHODS ====================

  /// Parse study guides from response
  List<StudyDocument> _parseStudyGuidesResponse(dynamic responseData) {
    List<dynamic> data = [];

    if (responseData is List) {
      data = responseData;
    } else if (responseData is Map) {
      if (responseData.containsKey('results')) {
        data = responseData['results'];
        print('📊 Paginated response: ${responseData['count']} total guides');
      } else if (responseData.containsKey('data')) {
        data = responseData['data'];
      } else if (responseData.containsKey('study_guides')) {
        data = responseData['study_guides'];
      } else {
        for (var value in responseData.values) {
          if (value is List) {
            data = value;
            break;
          }
        }
      }
    }

    return _parseStudyGuidesList(data);
  }

  /// Parse list of study guides
  List<StudyDocument> _parseStudyGuidesList(List<dynamic> data) {
    print('✅ Successfully loaded ${data.length} study guides');

    final List<StudyDocument> guides = [];

    for (var item in data) {
      try {
        Map<String, dynamic> guideMap = {};

        if (item is Map) {
          item.forEach((key, value) {
            guideMap[key.toString()] = value;
          });
        }

        // Parse the study guide
        final guide = StudyDocument(
          id: guideMap['id']?.toString() ?? 'unknown',
          title: guideMap['name']?.toString() ?? 'Untitled',
          fileName:
              guideMap['file_name']?.toString() ??
              _extractFileNameFromUrl(guideMap['pdf_url']?.toString()) ??
              'document.pdf',
          fileUrl:
              guideMap['pdf_url']?.toString() ??
              guideMap['pdf_file']?.toString() ??
              '',
          fileSize: _getFileSizeFromGuide(guideMap),
          courseCode: guideMap['course_code']?.toString() ?? 'GEN',
          courseName: guideMap['course_name']?.toString() ?? 'General',
          university:
              guideMap['university_name']?.toString() ??
              _extractFieldName(guideMap['university']) ??
              'Unknown University',
          department: _extractDepartmentNames(guideMap['departments']),
          level: _parseLevel(guideMap['level'] ?? guideMap['level_id']),
          semester: _parseSemester(
            guideMap['semester'] ?? guideMap['semester_id'],
          ),
        );

        if (guide.fileUrl.isNotEmpty && guide.fileUrl.startsWith('http')) {
          guides.add(guide);
          print('   - ✅ Added: ${guide.title} (${guide.fileSize})');
        }
      } catch (e) {
        print('   - ❌ Error parsing study guide: $e');
      }
    }

    print(
      '📊 Successfully parsed ${guides.length} out of ${data.length} items',
    );

    if (guides.isNotEmpty) {
      _cacheStudyGuides(guides);
    }

    return guides;
  }

  // ==================== NEW FILE SIZE METHODS ====================

  /// Get file size from guide data
  String _getFileSizeFromGuide(Map<String, dynamic> guideMap) {
    try {
      if (guideMap['file_size'] != null) {
        return _formatFileSizeForDisplay(guideMap['file_size']);
      }

      if (guideMap['pdf_file'] is Map && guideMap['pdf_file']['size'] != null) {
        return _formatFileSizeForDisplay(guideMap['pdf_file']['size']);
      }

      return 'Unknown size';
    } catch (e) {
      return 'Unknown size';
    }
  }

  /// Get actual file size from Cloudinary
  Future<String> _getActualFileSize(String fileUrl) async {
    try {
      if (fileUrl.isEmpty || !fileUrl.startsWith('http')) {
        return 'Unknown size';
      }

      final response = await http
          .head(Uri.parse(fileUrl), headers: {'User-Agent': 'CerenixApp/1.0'})
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final contentLength = response.headers['content-length'];
        if (contentLength != null) {
          final bytes = int.tryParse(contentLength) ?? 0;
          return _formatFileSizeForDisplay(bytes);
        }
      }

      return 'Unknown size';
    } catch (e) {
      return 'Unknown size';
    }
  }

  // ==================== UPDATED HELPER METHODS ====================

  /// Extract field name from object
  String _extractFieldName(dynamic fieldData) {
    if (fieldData == null) return 'Unknown';

    if (fieldData is Map) {
      if (fieldData['name'] != null) return fieldData['name'].toString();
      if (fieldData['title'] != null) return fieldData['title'].toString();
      if (fieldData['university_name'] != null)
        return fieldData['university_name'].toString();
    } else if (fieldData is String) {
      return fieldData;
    }

    return 'Unknown';
  }

  /// Extract department names
  String _extractDepartmentNames(dynamic departmentsData) {
    if (departmentsData == null) return 'Multiple Departments';

    try {
      if (departmentsData is List) {
        final departmentNames = <String>[];

        for (var dept in departmentsData) {
          if (dept is Map && dept['name'] != null) {
            departmentNames.add(dept['name'].toString());
          }
        }

        if (departmentNames.isEmpty) {
          return 'Multiple Departments';
        } else if (departmentNames.length > 3) {
          return '${departmentNames.take(3).join(', ')}, +${departmentNames.length - 3} more';
        } else {
          return departmentNames.join(', ');
        }
      } else if (departmentsData is Map && departmentsData['name'] != null) {
        return departmentsData['name'].toString();
      } else if (departmentsData is String) {
        return departmentsData;
      }
    } catch (e) {
      print('⚠️ Error extracting department names: $e');
    }

    return 'Multiple Departments';
  }

  /// Parse level from response
  int _parseLevel(dynamic levelData) {
    try {
      if (levelData == null) return 1;

      if (levelData is Map) {
        if (levelData['level_number'] != null) {
          return int.tryParse(levelData['level_number'].toString()) ?? 1;
        } else if (levelData['value'] != null) {
          return int.tryParse(levelData['value'].toString()) ?? 1;
        } else if (levelData['name'] != null) {
          final name = levelData['name'].toString().toLowerCase();
          if (name.contains('100')) return 1;
          if (name.contains('200')) return 2;
          if (name.contains('300')) return 3;
          if (name.contains('400')) return 4;
          if (name.contains('500')) return 5;
        } else if (levelData['id'] != null) {
          return int.tryParse(levelData['id'].toString()) ?? 1;
        }
      } else if (levelData is int) {
        return levelData;
      } else if (levelData is String) {
        return int.tryParse(levelData) ?? 1;
      }
    } catch (e) {
      print('⚠️ Error parsing level: $e');
    }

    return 1;
  }

  /// Parse semester from response
  int _parseSemester(dynamic semesterData) {
    try {
      if (semesterData == null) return 1;

      if (semesterData is Map) {
        if (semesterData['semester_number'] != null) {
          return int.tryParse(semesterData['semester_number'].toString()) ?? 1;
        } else if (semesterData['value'] != null) {
          return int.tryParse(semesterData['value'].toString()) ?? 1;
        } else if (semesterData['name'] != null) {
          final name = semesterData['name'].toString().toLowerCase();
          if (name.contains('first') || name.contains('1')) return 1;
          if (name.contains('second') || name.contains('2')) return 2;
        } else if (semesterData['id'] != null) {
          return int.tryParse(semesterData['id'].toString()) ?? 1;
        }
      } else if (semesterData is int) {
        return semesterData;
      } else if (semesterData is String) {
        return int.tryParse(semesterData) ?? 1;
      }
    } catch (e) {
      print('⚠️ Error parsing semester: $e');
    }

    return 1;
  }

  /// Format file size for display
  String _formatFileSizeForDisplay(dynamic size) {
    try {
      int bytes;

      if (size is int) {
        bytes = size;
      } else if (size is String) {
        bytes = int.tryParse(size) ?? 0;
      } else if (size is double) {
        bytes = size.toInt();
      } else {
        bytes = 0;
      }

      if (bytes <= 0) return 'Unknown size';
      if (bytes < 1024) return '$bytes B';
      if (bytes < 1048576) return '${(bytes / 1024).toStringAsFixed(1)} KB';
      if (bytes < 1073741824)
        return '${(bytes / 1048576).toStringAsFixed(1)} MB';
      return '${(bytes / 1073741824).toStringAsFixed(2)} GB';
    } catch (e) {
      return 'Unknown size';
    }
  }

  // ==================== KEEP THESE EXISTING METHODS ====================
  // DON'T replace these - they should stay as-is:

  /// Get study guides by user ID (fallback method)
  Future<List<StudyDocument>> _getStudyGuidesByUserId(String userId) async {
    try {
      print('🔄 Trying user ID endpoint for user: $userId');

      final response = await http
          .get(
            Uri.parse('${ApiEndpoints.studyGuides}by_user_id/?user_id=$userId'),
            headers: {'Content-Type': 'application/json'},
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        print(
          '✅ Successfully loaded ${data.length} guides via user ID endpoint',
        );
        return _parseStudyGuidesList(data);
      }

      return [];
    } catch (e) {
      print('❌ User ID endpoint failed: $e');
      return [];
    }
  }

  /// Helper to extract academic ID from multiple possible locations
  String? _extractAcademicId(
    dynamic profile,
    Map<String, dynamic> userData,
    String field,
  ) {
    // First, handle if profile is null
    if (profile == null) {
      return _extractFromUserData(userData, field);
    }

    // If profile is a Map (should be from your JSON)
    if (profile is Map) {
      final fieldData = profile[field];

      if (fieldData is Map) {
        // Handle Map type: {"id": 1, "name": "University"}
        if (fieldData['id'] != null) {
          return fieldData['id'].toString();
        }
      } else if (fieldData != null) {
        // Handle if it's already an ID
        return fieldData.toString();
      }
    }

    // Fallback to userData
    return _extractFromUserData(userData, field);
  }

  /// Helper to extract from userData
  String? _extractFromUserData(Map<String, dynamic> userData, String field) {
    final fieldData = userData[field];

    if (fieldData is Map) {
      if (fieldData['id'] != null) {
        return fieldData['id'].toString();
      }
    } else if (fieldData != null) {
      return fieldData.toString();
    }

    return null;
  }

  /// Extract filename from URL
  String? _extractFileNameFromUrl(String? url) {
    if (url == null || url.isEmpty) return null;

    try {
      final uri = Uri.parse(url);
      final pathSegments = uri.pathSegments;
      if (pathSegments.isNotEmpty) {
        final lastSegment = pathSegments.last;
        // Remove any query parameters from the filename
        return lastSegment.split('?').first;
      }
    } catch (e) {
      print('⚠️ Error extracting filename: $e');
    }

    return 'document.pdf';
  }

  /// Get cached study guides
  Future<List<StudyDocument>> _getCachedStudyGuides() async {
    try {
      final box = await Hive.openBox('study_guides_cache');
      final cachedData = box.get('all_guides');

      if (cachedData != null && cachedData is List) {
        final guides = cachedData.map((map) => _mapToGuide(map)).toList();
        print('📂 Loaded ${guides.length} guides from cache');
        return guides;
      }
    } catch (e) {
      print('⚠️ Error getting cached guides: $e');
    }
    return [];
  }

  /// Cache study guides for offline use
  Future<void> _cacheStudyGuides(List<StudyDocument> guides) async {
    try {
      final box = await Hive.openBox('study_guides_cache');
      final guideData = guides.map((guide) => _guideToMap(guide)).toList();
      await box.put('all_guides', guideData);
      await box.put('last_updated', DateTime.now().toIso8601String());
      print('✅ Cached ${guides.length} study guides');
    } catch (e) {
      print('⚠️ Error caching study guides: $e');
    }
  }

  /// Convert StudyDocument to Map for caching
  Map<String, dynamic> _guideToMap(StudyDocument guide) {
    return {
      'id': guide.id,
      'title': guide.title,
      'fileName': guide.fileName,
      'fileUrl': guide.fileUrl,
      'fileSize': guide.fileSize,
      'courseCode': guide.courseCode,
      'courseName': guide.courseName,
      'university': guide.university,
      'department': guide.department,
      'level': guide.level,
      'semester': guide.semester,
    };
  }

  /// Convert Map back to StudyDocument
  StudyDocument _mapToGuide(Map<dynamic, dynamic> map) {
    return StudyDocument(
      id: map['id']?.toString() ?? 'unknown',
      title: map['title']?.toString() ?? 'Untitled',
      fileName: map['fileName']?.toString() ?? 'document.pdf',
      fileUrl: map['fileUrl']?.toString() ?? '',
      fileSize: map['fileSize']?.toString() ?? 'Unknown size',
      courseCode: map['courseCode']?.toString() ?? 'GEN',
      courseName: map['courseName']?.toString() ?? 'General',
      university: map['university']?.toString() ?? 'Unknown University',
      department: map['department']?.toString() ?? 'Multiple Departments',
      level: map['level'] is int ? map['level'] as int : 1,
      semester: map['semester'] is int ? map['semester'] as int : 1,
    );
  }
}
