// lib/features/popup/services/popup_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/endpoints.dart';
import '../models/popup_advertisement.dart';

class PopupService {
  // Debug mode for troubleshooting
  static const bool debugMode = true;

  Future<PopupAdvertisement?> getPopupForUser(int? userId) async {
    try {
      // CORRECTED URL: Use /api/popups/ instead of /api/popup-advertisements/
      String url =
          '${ApiEndpoints.baseUrl}/advertisements/api/popups/'; // CHANGED
      if (userId != null) {
        url =
            '${ApiEndpoints.baseUrl}/advertisements/api/popups/?user_id=$userId'; // CHANGED
      }

      _debugPrint('🌐 Fetching popup from: $url');

      // Get auth token
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      // Prepare headers
      final headers = <String, String>{'Content-Type': 'application/json'};
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Token $token';
        _debugPrint('🔑 Using auth token');
      }

      // Make request with detailed logging
      _debugPrint('📡 Sending GET request to: $url');
      _debugPrint('📡 Headers: $headers');

      final response = await http
          .get(Uri.parse(url), headers: headers)
          .timeout(const Duration(seconds: 30));

      _debugPrint('📡 Response status: ${response.statusCode}');
      _debugPrint('📡 Response headers: ${response.headers}');

      if (response.statusCode == 200) {
        final dynamic responseData = json.decode(response.body);
        _debugPrint('📦 Response type: ${responseData.runtimeType}');

        // Handle different response formats
        PopupAdvertisement? popup;

        if (responseData is Map) {
          // Convert Map<dynamic, dynamic> to Map<String, dynamic>
          final Map<String, dynamic> responseMap = _convertToMap(responseData);

          _debugPrint('📦 Response keys: ${responseMap.keys}');
          _debugPrint('📦 Full response: $responseMap');

          if (responseMap['popup'] != null) {
            // Format: {'popup': {...}, 'count': 1, ...}
            final popupData = responseMap['popup'];
            if (popupData is Map) {
              final popupDataMap = _convertToMap(popupData);
              popup = PopupAdvertisement.fromJson(popupDataMap);
              _debugPrint(
                '✅ Loaded popup from "popup" key: ${popup.title ?? "No Title"} (ID: ${popup.id})',
              );
            }
          } else if (responseMap['results'] != null &&
              responseMap['results'] is List) {
            // Format: {'results': [{...}], 'count': 1, ...}
            final results = responseMap['results'] as List;
            if (results.isNotEmpty) {
              final firstResult = results.first;
              if (firstResult is Map) {
                final firstResultMap = _convertToMap(firstResult);
                popup = PopupAdvertisement.fromJson(firstResultMap);
                _debugPrint(
                  '✅ Loaded popup from "results" list: ${popup.title ?? "No Title"} (ID: ${popup.id})',
                );
              }
            }
          } else if (responseMap.containsKey('id')) {
            // Direct popup object
            popup = PopupAdvertisement.fromJson(responseMap);
            _debugPrint(
              '✅ Loaded popup from direct object: ${popup.title ?? "No Title"} (ID: ${popup.id})',
            );
          }

          if (popup != null) {
            // Additional debug info
            _debugPrint('🎯 Popup Details:');
            _debugPrint('   - Title: ${popup.title}');
            _debugPrint('   - Image URL: ${popup.imageUrl}');
            _debugPrint('   - Target URL: ${popup.targetUrl}');
            _debugPrint('   - Show Delay: ${popup.showDelay}s');
            _debugPrint('   - Frequency: ${popup.displayFrequency}');
            _debugPrint('   - Active: ${popup.isActive}');
            return popup;
          } else {
            _debugPrint('ℹ️ No popup available for user');
            _debugPrint('   Response structure:');
            responseMap.forEach((key, value) {
              _debugPrint('   - $key: ${value.runtimeType}');
            });
            return null;
          }
        } else if (responseData is List) {
          // Direct list response
          final List<dynamic> responseList = responseData;
          if (responseList.isNotEmpty) {
            final firstItem = responseList.first;
            if (firstItem is Map) {
              final firstItemMap = _convertToMap(firstItem);
              popup = PopupAdvertisement.fromJson(firstItemMap);
              _debugPrint(
                '✅ Loaded popup from direct list: ${popup.title ?? "No Title"} (ID: ${popup.id})',
              );
              return popup;
            }
          }
          _debugPrint('ℹ️ Empty list response');
          return null;
        } else {
          _debugPrint(
            '⚠️ Unexpected response type: ${responseData.runtimeType}',
          );
          return null;
        }
      } else if (response.statusCode == 404) {
        _debugPrint('❌ Endpoint not found (404). Check your URL path');
        _debugPrint('   URL tried: $url');
        _debugPrint('   Response body: ${response.body}');
        return null;
      } else if (response.statusCode == 500) {
        _debugPrint('❌ Server error (500). Check Django server logs');
        _debugPrint('   Response body: ${response.body}');
        return null;
      } else {
        _debugPrint('⚠️ Failed to load popup: ${response.statusCode}');
        _debugPrint('   Response body: ${response.body}');
        return null;
      }
    } catch (e) {
      _debugPrint('❌ Error loading popup: $e');
      _debugPrint('Stack trace: ${e.toString()}');

      // Network error details
      if (e is http.ClientException) {
        _debugPrint('🌐 Network error: ${e.message}');
        _debugPrint('🌐 URI: ${e.uri}');
      }

      return null;
    }
  }

  Future<bool> recordPopupClick(int popupId, int? userId) async {
    try {
      // CORRECTED URL: Use /api/popups/ instead of /api/popup-advertisements/
      final url =
          '${ApiEndpoints.baseUrl}/advertisements/api/popups/$popupId/click/'; // CHANGED
      _debugPrint('🌐 Recording click at: $url');

      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      final headers = <String, String>{'Content-Type': 'application/json'};

      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Token $token';
      }

      final body = <String, dynamic>{};
      if (userId != null) {
        body['user_id'] = userId;
      }

      _debugPrint('📡 Sending POST request with body: $body');
      final response = await http.post(
        Uri.parse(url),
        headers: headers,
        body: json.encode(body),
      );

      _debugPrint('📡 Click response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        _debugPrint('✅ Popup click recorded for ID: $popupId');
        _debugPrint('   Response: $responseData');
        return true;
      } else {
        _debugPrint('⚠️ Failed to record click: ${response.statusCode}');
        _debugPrint('   Response body: ${response.body}');
        return false;
      }
    } catch (e) {
      _debugPrint('❌ Error recording click: $e');
      return false;
    }
  }

  // Check if popup should be shown based on frequency
  Future<bool> shouldShowPopup(PopupAdvertisement popup, int? userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Key for storing popup view history
      final popupKey = 'popup_${popup.id}_${userId ?? 'anonymous'}';

      // Get last shown time
      final lastShownStr = prefs.getString(popupKey);

      if (lastShownStr == null) {
        // Never shown before
        _debugPrint('📊 Popup ${popup.id} never shown before');
        return true;
      }

      final lastShown = DateTime.parse(lastShownStr);
      final now = DateTime.now();

      // Calculate hours since last shown
      final hoursSince = now.difference(lastShown).inHours;
      _debugPrint('📊 Popup ${popup.id}: ${hoursSince}h since last shown');

      // Check based on frequency
      switch (popup.displayFrequency) {
        case 'first_open':
          if (hoursSince >= popup.hoursBeforeShow) {
            _debugPrint(
              '📊 First open: ${hoursSince}h >= ${popup.hoursBeforeShow}h (SHOW)',
            );
            return true;
          } else {
            _debugPrint(
              '📊 First open: ${hoursSince}h < ${popup.hoursBeforeShow}h (DONT SHOW)',
            );
            return false;
          }

        case 'session_start':
          // Show at every session start
          // We'll track sessions separately
          final sessionKey = 'last_session_${userId ?? 'anonymous'}';
          final lastSessionStr = prefs.getString(sessionKey);

          if (lastSessionStr == null) {
            _debugPrint('📊 Session start: No previous session (SHOW)');
            return true;
          }

          final lastSession = DateTime.parse(lastSessionStr);
          final hoursSinceSession = now.difference(lastSession).inHours;

          // Consider a new session if more than 1 hour has passed
          final shouldShow = hoursSinceSession > 1;
          _debugPrint(
            '📊 Session start: ${hoursSinceSession}h since last session (${shouldShow ? 'SHOW' : 'DONT SHOW'})',
          );
          return shouldShow;

        case 'time_interval':
          if (hoursSince >= popup.intervalHours) {
            _debugPrint(
              '📊 Time interval: ${hoursSince}h >= ${popup.intervalHours}h (SHOW)',
            );
            return true;
          } else {
            _debugPrint(
              '📊 Time interval: ${hoursSince}h < ${popup.intervalHours}h (DONT SHOW)',
            );
            return false;
          }

        case 'once_per_user':
          if (popup.trackUserViews) {
            // Check if user has seen it before
            final hasSeenKey =
                'popup_seen_${popup.id}_${userId ?? 'anonymous'}';
            final hasSeen = prefs.getBool(hasSeenKey) ?? false;
            _debugPrint(
              '📊 Once per user: Has seen? $hasSeen (${!hasSeen ? 'SHOW' : 'DONT SHOW'})',
            );
            return !hasSeen;
          }
          _debugPrint('📊 Once per user: No tracking (SHOW)');
          return true;

        default:
          _debugPrint(
            '📊 Unknown frequency: ${popup.displayFrequency} (SHOW by default)',
          );
          return true;
      }
    } catch (e) {
      _debugPrint('❌ Error checking popup frequency: $e');
      // If there's an error, show the popup to avoid blocking
      return true;
    }
  }

  // Record that popup was shown
  Future<void> recordPopupShown(PopupAdvertisement popup, int? userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now();

      // Record last shown time
      final popupKey = 'popup_${popup.id}_${userId ?? 'anonymous'}';
      await prefs.setString(popupKey, now.toIso8601String());
      _debugPrint(
        '📊 Recorded popup ${popup.id} shown at ${now.toIso8601String()}',
      );

      // Record that user has seen it (for once_per_user)
      if (popup.trackUserViews) {
        final hasSeenKey = 'popup_seen_${popup.id}_${userId ?? 'anonymous'}';
        await prefs.setBool(hasSeenKey, true);
        _debugPrint('📊 Marked popup ${popup.id} as seen by user');
      }
    } catch (e) {
      _debugPrint('❌ Error recording popup shown: $e');
    }
  }

  // Record session start
  Future<void> recordSessionStart(int? userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now();

      final sessionKey = 'last_session_${userId ?? 'anonymous'}';
      final previousSession = prefs.getString(sessionKey);

      await prefs.setString(sessionKey, now.toIso8601String());

      _debugPrint('📊 Recorded session start at ${now.toIso8601String()}');
      if (previousSession != null) {
        final lastSession = DateTime.parse(previousSession);
        final hoursSince = now.difference(lastSession).inHours;
        _debugPrint('📊 Hours since last session: $hoursSince');
      }
    } catch (e) {
      _debugPrint('❌ Error recording session: $e');
    }
  }

  // Test endpoint connectivity
  Future<void> testEndpoint() async {
    _debugPrint('🧪 Testing popup endpoint connectivity...');

    try {
      // Test without user_id first
      final testUrl =
          '${ApiEndpoints.baseUrl}/advertisements/api/popups/'; // CHANGED
      _debugPrint('🧪 Testing URL: $testUrl');

      final response = await http.get(Uri.parse(testUrl));
      _debugPrint('🧪 Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final dynamic data = json.decode(response.body);
        _debugPrint('🧪 Response type: ${data.runtimeType}');

        if (data is Map) {
          final dataMap = _convertToMap(data);
          _debugPrint('🧪 Response structure:');
          dataMap.forEach((key, value) {
            _debugPrint('   - $key: ${value.runtimeType}');
          });
        } else if (data is List) {
          _debugPrint('🧪 Response is a list with ${data.length} items');
        }
      } else {
        _debugPrint('🧪 Response body: ${response.body}');
      }
    } catch (e) {
      _debugPrint('🧪 Error testing endpoint: $e');
    }
  }

  // Helper method to convert Map<dynamic, dynamic> to Map<String, dynamic>
  Map<String, dynamic> _convertToMap(Map<dynamic, dynamic> dynamicMap) {
    final Map<String, dynamic> stringMap = {};

    dynamicMap.forEach((key, value) {
      if (key != null) {
        stringMap[key.toString()] = value;
      }
    });

    return stringMap;
  }

  // Helper method for debug printing
  void _debugPrint(String message) {
    if (debugMode) {
      print(message);
    }
  }
}
