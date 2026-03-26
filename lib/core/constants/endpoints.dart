class ApiEndpoints {
  // static const String baseUrl = "http://127.0.0.1:8000"; // IP Address
  static const String baseUrl = "http://192.168.1.81:8000"; // IP Addres
  // static const String baseUrl = "https://cerenix-backend.vercel.app"; // Production address

  static const String googleLogin = "$baseUrl/api/users/auth/google/";
  static const String emailRegister = "$baseUrl/api/users/auth/register/";
  static const String emailLogin = "$baseUrl/api/users/auth/login/";
  static const String updateProfile = "$baseUrl/api/users/profile/update/";

  static const String updateOnboarding =
      "$baseUrl/api/users/onboarding/update/";
  static const String logout = "$baseUrl/api/users/auth/logout/";

  // ADD THIS UPDATE USER PASSWORD
  static const String updatePassword =
      "$baseUrl/api/users/auth/update-password/";

  // Academics Endpoints
  static const String universities = "$baseUrl/api/academics/universities/";
  static const String faculties = "$baseUrl/api/academics/faculties/";
  static const String departments = "$baseUrl/api/academics/departments/";
  static const String levels = "$baseUrl/api/academics/levels/";
  static const String semesters = "$baseUrl/api/academics/semesters/";

  // Activation Endpoints
  static const String billingPlans = "$baseUrl/api/activation/billing-plans/";
  static const String activationStatus = "$baseUrl/api/activation/status/";
  static const String activateWithPin =
      "$baseUrl/api/activation/activate-with-pin/";
  static const String initiatePayment =
      "$baseUrl/api/activation/initiate-payment/";
  static const String paymentCallback =
      "$baseUrl/api/activation/payment-callback/";
  static const String userReferral =
      "$baseUrl/api/activation/referral/"; // ADD THIS LINE

  // AI CHAT ENDPOINT — THIS WAS WRONG BEFORE!
  static const String askCerava = "$baseUrl/api/ask/";

  // ADD THESE ADVERTISEMENT ENDPOINTS
  static const String advertisements =
      "$baseUrl/advertisements/api/advertisements/";
  static const String activeAdvertisements =
      "$baseUrl/advertisements/api/advertisements/active/";

  // lib/core/constants/endpoints.dart
  static const String informationCategories =
      "$baseUrl/information/api/categories/";
  static const String informationItems = "$baseUrl/information/api/items/";
  static const String informationItemDetail =
      "$baseUrl/information/api/items/"; // Add /{id}/

  // Advertisement endpoints - CORRECTED
  static const String popupAdvertisements =
      '$baseUrl/advertisements/api/popups/'; // CHANGED
  static const String popupAdvertisementClick =
      '$baseUrl/advertisements/api/popups/{id}/click/'; // CHANGED

  // Study Guide Endpoints
  // static String get studyGuides => '$baseUrl/api/documents/study-guides/';
  // static String get studyGuidesForMyProfile => '$baseUrl/api/documents/study-guides/for_my_profile/';

  // Study Guide Endpoints - FIXED URL
  static String get studyGuides => '$baseUrl/api/documents/study-guides/';
  static String get studyGuidesForMyProfile =>
      '$baseUrl/api/documents/study-guides/for_my_profile/';
  static String get studyGuidesByAcademic =>
      '$baseUrl/api/documents/study-guides/by-academic/';
}
