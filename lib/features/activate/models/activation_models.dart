import 'package:flutter/material.dart';
import '../extensions/string_extensions.dart'; // Add this import
import 'dart:convert';

class BillingPlan {
  final String id;
  final String grade;
  final String name;
  final double price;
  final String duration;
  final int durationDays;
  final String durationDisplay;
  final String description;
  final List<String> features;
  final bool isActive;
  final bool isValid;

  BillingPlan({
    required this.id,
    required this.grade,
    required this.name,
    required this.price,
    required this.duration,
    required this.durationDays,
    required this.durationDisplay,
    required this.description,
    required this.features,
    required this.isActive,
    required this.isValid,
  });

  // Enhanced gradient colors for each grade
  List<Color> get gradientColors {
    switch (grade.toLowerCase()) {
      case 'regular':
        return [Color(0xFF2196F3), Color(0xFF21CBF3)]; // Blue gradient
      case 'premium':
        return [Color(0xFF9C27B0), Color(0xFFE91E63)]; // Purple to Pink gradient
      case 'gold':
        return [Color(0xFFFFD700), Color(0xFFFFA000)]; // Gold gradient
      default:
        return [Color(0xFF2196F3), Color(0xFF21CBF3)];
    }
  }

  // Get text color based on background
  Color get textColor {
    switch (grade.toLowerCase()) {
      case 'regular':
      case 'premium':
        return Colors.white;
      case 'gold':
        return Colors.black87; // Dark text for gold background
      default:
        return Colors.white;
    }
  }

  // Get button color based on grade
  Color get buttonColor {
    switch (grade.toLowerCase()) {
      case 'regular':
        return Colors.blue.shade700;
      case 'premium':
        return Colors.purple.shade700;
      case 'gold':
        return Colors.amber.shade800;
      default:
        return Colors.blue.shade700;
    }
  }

  // Add this helper method to check if plan should be shown
  bool get shouldShow => isValid; // Show if valid (regardless of isActive)

  // Add this helper method to check if plan is clickable
  bool get isClickable => isActive && isValid;

//   factory BillingPlan.fromJson(Map<String, dynamic> json) {
//   print('📋 [BillingPlan] Parsing BillingPlan JSON');
//   print('   - Available keys: ${json.keys}');
  
//   // Debug each field
//   json.forEach((key, value) {
//     print('     $key: $value (type: ${value.runtimeType})');
//   });

//   // Enhanced price parsing
//   double parsePrice(dynamic priceValue) {
//     print('   - Parsing price: $priceValue');
//     if (priceValue == null) return 0.0;
//     if (priceValue is double) return priceValue;
//     if (priceValue is int) return priceValue.toDouble();
//     if (priceValue is String) {
//       return double.tryParse(priceValue) ?? 0.0;
//     }
//     return 0.0;
//   }

//   // Enhanced duration display
//   String getDurationDisplay(String duration) {
//     switch (duration) {
//       case 'first_semester':
//         return 'First Semester';
//       case 'second_semester':
//         return 'Second Semester';
//       case 'full_session':
//         return 'Full Session';
//       default:
//         return duration.replaceAll('_', ' ').toLowerCase();
//     }
//   }

//   // Parse features safely
//   List<String> parseFeatures(dynamic features) {
//     if (features == null) return [];
//     if (features is List) {
//       return features.map((item) => item.toString()).toList();
//     }
//     return [];
//   }

//   final billingPlan = BillingPlan(
//     id: json['id']?.toString() ?? 'unknown_id',
//     grade: json['grade']?.toString() ?? 'regular',
//     name: json['name']?.toString() ?? 'Unnamed Plan',
//     price: parsePrice(json['price']),
//     duration: json['duration']?.toString() ?? 'first_semester',
//     durationDays: (json['duration_days'] is int) ? json['duration_days'] : (json['duration_days'] is String) ? int.tryParse(json['duration_days']) ?? 90 : 90,
//     durationDisplay: json['duration_display']?.toString() ?? getDurationDisplay(json['duration']?.toString() ?? 'first_semester'),
//     description: json['description']?.toString() ?? '',
//     features: parseFeatures(json['features']),
//     isActive: json['is_active'] ?? false,
//     isValid: json['is_valid'] ?? false,
//   );

//   print('✅ [BillingPlan] Parsed: ${billingPlan.name} - ₦${billingPlan.price} - Active: ${billingPlan.isActive} - Valid: ${billingPlan.isValid}');
//   return billingPlan;
// }

factory BillingPlan.fromJson(Map<String, dynamic> json) {
  print('📋 [BillingPlan] Parsing BillingPlan JSON');
  print('   - Available keys: ${json.keys}');
  
  // Debug each field
  json.forEach((key, value) {
    print('     $key: $value (type: ${value.runtimeType})');
  });

  // Enhanced price parsing
  double parsePrice(dynamic priceValue) {
    print('   - Parsing price: $priceValue');
    if (priceValue == null) return 0.0;
    if (priceValue is double) return priceValue;
    if (priceValue is int) return priceValue.toDouble();
    if (priceValue is String) {
      return double.tryParse(priceValue) ?? 0.0;
    }
    return 0.0;
  }

  // Enhanced duration display
  String getDurationDisplay(String duration) {
    switch (duration) {
      case 'first_semester':
        return 'First Semester';
      case 'second_semester':
        return 'Second Semester';
      case 'full_session':
        return 'Full Session';
      default:
        return duration.replaceAll('_', ' ').toTitleCase();
    }
  }

  // FIXED: Enhanced features parsing with proper JSON import
  List<String> parseFeatures(dynamic features) {
    print('   - Parsing features: $features (type: ${features.runtimeType})');
    
    if (features == null) {
      print('     - Features is null, returning empty list');
      return [];
    }
    
    if (features is List) {
      final parsed = features.map((item) {
        if (item is String) {
          return item;
        } else {
          return item.toString();
        }
      }).toList();
      print('     - Parsed features list: $parsed');
      return parsed;
    }
    
    if (features is String) {
      print('     - Features is string, trying to parse as JSON');
      try {
        // FIXED: Use json.decode from dart:convert import
        final decoded = jsonDecode(features);
        if (decoded is List) {
          final parsed = decoded.map((item) => item.toString()).toList();
          print('     - JSON parsed features: $parsed');
          return parsed;
        }
      } catch (e) {
        print('     - JSON parsing failed, using as single feature: $features');
        return [features];
      }
    }
    
    print('     - Default case, returning empty list');
    return [];
  }

  final billingPlan = BillingPlan(
    id: json['id']?.toString() ?? 'unknown_id',
    grade: json['grade']?.toString() ?? 'regular',
    name: json['name']?.toString() ?? 'Unnamed Plan',
    price: parsePrice(json['price']),
    duration: json['duration']?.toString() ?? 'first_semester',
    durationDays: (json['duration_days'] is int) ? json['duration_days'] : (json['duration_days'] is String) ? int.tryParse(json['duration_days']) ?? 90 : 90,
    durationDisplay: json['duration_display']?.toString() ?? getDurationDisplay(json['duration']?.toString() ?? 'first_semester'),
    description: json['description']?.toString() ?? '',
    features: parseFeatures(json['features']), // Use the fixed parser
    isActive: json['is_active'] ?? false,
    isValid: json['is_valid'] ?? false,
  );

  print('✅ [BillingPlan] Parsed: ${billingPlan.name}');
  print('   - Price: ₦${billingPlan.price}');
  print('   - Active: ${billingPlan.isActive}');
  print('   - Valid: ${billingPlan.isValid}');
  print('   - Features count: ${billingPlan.features.length}');
  print('   - Features: ${billingPlan.features}');
  
  return billingPlan;
}

  // ///

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'grade': grade,
      'name': name,
      'price': price,
      'duration': duration,
      'duration_days': durationDays,
      'duration_display': durationDisplay,
      'description': description,
      'features': features,
      'is_active': isActive,
      'is_valid': isValid,
    };
  }

  @override
  String toString() {
    return 'BillingPlan{id: $id, name: $name, grade: $grade, price: $price, isValid: $isValid}';
  }
}






class UserActivation {
  final String id;
  final String grade;
  final String activationMethod;
  final String universityName;
  final String semesterName;
  final String sessionName;
  final bool isActive;
  final bool isValid;
  final DateTime activatedAt;
  final String? duration;
  final String? planDuration;

  UserActivation({
    required this.id,
    required this.grade,
    required this.activationMethod,
    required this.universityName,
    required this.semesterName,
    required this.sessionName,
    required this.isActive,
    required this.isValid,
    required this.activatedAt,
    this.duration,
    this.planDuration,
  });

  factory UserActivation.fromJson(Map<String, dynamic> json) {
    print('📋 Parsing UserActivation JSON');
    
    // Enhanced date parsing
    DateTime parseActivatedAt(dynamic dateValue) {
      if (dateValue == null) return DateTime.now();
      if (dateValue is String) {
        try {
          return DateTime.parse(dateValue);
        } catch (e) {
          print('⚠️ Error parsing activated_at: $dateValue, using current time');
          return DateTime.now();
        }
      }
      return DateTime.now();
    }

    final userActivation = UserActivation(
      id: json['id']?.toString() ?? '',
      grade: json['grade'] ?? 'regular',
      activationMethod: json['activation_method'] ?? 'pin',
      universityName: json['university_name'] ?? json['university']?['name'] ?? 'Unknown University',
      semesterName: json['semester_name'] ?? json['semester']?['name'] ?? 'Unknown Semester',
      sessionName: json['session_name'] ?? json['session']?['name'] ?? 'Unknown Session',
      isActive: json['is_active'] ?? false,
      isValid: json['is_valid'] ?? false,
      activatedAt: parseActivatedAt(json['activated_at']),
      duration: json['duration'] ?? json['plan_duration'],
      planDuration: json['plan_duration'] ?? json['duration'],
    );

    print('✅ UserActivation parsed: ${userActivation.grade} - Active: ${userActivation.isActive} - Valid: ${userActivation.isValid}');
    return userActivation;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'grade': grade,
      'activation_method': activationMethod,
      'university_name': universityName,
      'semester_name': semesterName,
      'session_name': sessionName,
      'is_active': isActive,
      'is_valid': isValid,
      'activated_at': activatedAt.toIso8601String(),
      'duration': duration,
      'plan_duration': planDuration,
    };
  }

  @override
  String toString() {
    return 'UserActivation{id: $id, grade: $grade, method: $activationMethod, active: $isActive, valid: $isValid}';
  }
}

class ActivationResponse {
  final bool success;
  final String message;
  final String grade;
  final bool referralApplied;
  final UserActivation? activation;

  ActivationResponse({
    required this.success,
    required this.message,
    required this.grade,
    required this.referralApplied,
    this.activation,
  });

  factory ActivationResponse.fromJson(Map<String, dynamic> json) {
    print('📋 Parsing ActivationResponse JSON');
    
    final activationResponse = ActivationResponse(
      success: json['success'] ?? false,
      message: json['message'] ?? '',
      grade: json['grade'] ?? 'regular',
      referralApplied: json['referral_applied'] ?? false,
      activation: json['activation'] != null ? UserActivation.fromJson(json['activation']) : null,
    );

    print('✅ ActivationResponse parsed: Success: ${activationResponse.success} - ${activationResponse.message}');
    return activationResponse;
  }

  Map<String, dynamic> toJson() {
    return {
      'success': success,
      'message': message,
      'grade': grade,
      'referral_applied': referralApplied,
      'activation': activation?.toJson(),
    };
  }

  @override
  String toString() {
    return 'ActivationResponse{success: $success, message: $message, grade: $grade, referralApplied: $referralApplied}';
  }
}

class PaymentInitiationResponse {
  final bool success;
  final String authorizationUrl;
  final String accessCode;
  final String reference;
  final String? message;

  PaymentInitiationResponse({
    required this.success,
    required this.authorizationUrl,
    required this.accessCode,
    required this.reference,
    this.message,
  });

  factory PaymentInitiationResponse.fromJson(Map<String, dynamic> json) {
    print('📋 Parsing PaymentInitiationResponse JSON');
    
    final paymentResponse = PaymentInitiationResponse(
      success: json['success'] ?? false,
      authorizationUrl: json['authorization_url'] ?? '',
      accessCode: json['access_code'] ?? '',
      reference: json['reference'] ?? '',
      message: json['message'],
    );

    print('✅ PaymentInitiationResponse parsed: Success: ${paymentResponse.success} - Reference: ${paymentResponse.reference}');
    return paymentResponse;
  }

  Map<String, dynamic> toJson() {
    return {
      'success': success,
      'authorization_url': authorizationUrl,
      'access_code': accessCode,
      'reference': reference,
      'message': message,
    };
  }

  @override
  String toString() {
    return 'PaymentInitiationResponse{success: $success, reference: $reference, url: ${authorizationUrl.substring(0, 50)}...}';
  }
}

class PaymentVerificationResponse {
  final bool success;
  final String message;
  final String grade;
  final bool referralApplied;
  final UserActivation? activation;
  final String? duration;

  PaymentVerificationResponse({
    required this.success,
    required this.message,
    required this.grade,
    required this.referralApplied,
    this.activation,
    this.duration,
  });

  factory PaymentVerificationResponse.fromJson(Map<String, dynamic> json) {
    print('📋 Parsing PaymentVerificationResponse JSON');
    
    final verificationResponse = PaymentVerificationResponse(
      success: json['success'] ?? false,
      message: json['message'] ?? '',
      grade: json['grade'] ?? 'regular',
      referralApplied: json['referral_applied'] ?? false,
      activation: json['activation'] != null ? UserActivation.fromJson(json['activation']) : null,
      duration: json['duration'],
    );

    print('✅ PaymentVerificationResponse parsed: Success: ${verificationResponse.success} - ${verificationResponse.message}');
    return verificationResponse;
  }

  Map<String, dynamic> toJson() {
    return {
      'success': success,
      'message': message,
      'grade': grade,
      'referral_applied': referralApplied,
      'activation': activation?.toJson(),
      'duration': duration,
    };
  }
}

// Additional helper models for activation flow
class ActivationRequest {
  final String activationCode;
  final String? referralCode;

  ActivationRequest({
    required this.activationCode,
    this.referralCode,
  });

  Map<String, dynamic> toJson() {
    return {
      'activation_code': activationCode,
      if (referralCode != null && referralCode!.isNotEmpty) 'referral_code': referralCode,
    };
  }
}

class PaymentRequest {
  final String planId;
  final String? referralCode;

  PaymentRequest({
    required this.planId,
    this.referralCode,
  });

  Map<String, dynamic> toJson() {
    return {
      'plan_id': planId,
      if (referralCode != null && referralCode!.isNotEmpty) 'referral_code': referralCode,
    };
  }
}

class ReferralInfo {
  final String referralCode;
  final bool isUsed;
  final double rewardAmount;
  final int totalReferrals;

  ReferralInfo({
    required this.referralCode,
    required this.isUsed,
    required this.rewardAmount,
    required this.totalReferrals,
  });

  factory ReferralInfo.fromJson(Map<String, dynamic> json) {
    return ReferralInfo(
      referralCode: json['referral_code'] ?? '',
      isUsed: json['is_used'] ?? false,
      rewardAmount: (json['reward_amount'] is double) ? json['reward_amount'] : (json['reward_amount'] is int) ? json['reward_amount'].toDouble() : (json['reward_amount'] is String) ? double.tryParse(json['reward_amount']) ?? 0.0 : 0.0,
      totalReferrals: (json['total_referrals'] is int) ? json['total_referrals'] : (json['total_referrals'] is String) ? int.tryParse(json['total_referrals']) ?? 0 : 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'referral_code': referralCode,
      'is_used': isUsed,
      'reward_amount': rewardAmount,
      'total_referrals': totalReferrals,
    };
  }
}