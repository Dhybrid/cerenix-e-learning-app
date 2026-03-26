// lib/main.dart
import 'package:flutter/material.dart';
import 'core/theme/app_theme.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';

import 'features/cgpa/models/cgpa_models.dart';

import 'services/offline_service.dart';

import 'features/cereva/models/chat_models.dart';
import 'features/courses/models/course_models.dart';

import 'features/onboarding/screens/onboarding_screen.dart';
import 'features/onboarding/screens/terms_conditions_screen.dart';
import 'features/onboarding/screens/academic_setup_screen.dart';
import 'features/onboarding/models/onboarding_models.dart'; // ADD THIS

import 'features/splash/screens/splash_screen.dart';
import 'features/main/screens/main_layout.dart'; // ADD THIS IMPORT
// import 'features/home/screens/home_screen.dart';

import 'features/auth/screens/signin_screen.dart';
import 'features/auth/screens/signup_screen.dart';

import 'features/courses/screens/courses_screen.dart';
import 'features/courses/screens/course_detail_screen.dart';
import 'features/courses/screens/lectures.dart';
// import 'features/courses/screens/past_questions_screen.dart';

// import 'features/past_questions/screens/past_questions_screen.dart';
import 'features/past_questions/screens/past_questions_screen.dart';
import 'features/past_questions/screens/past_questions_selection_screen.dart';
import 'features/past_questions/screens/cbt_selection_screen.dart';
import 'features/past_questions/screens/cbt_questions_screen.dart';
import 'features/past_questions/screens/test_questions_screen.dart';
import 'features/past_questions/screens/test_question_selection_screen.dart';

import 'features/past_questions/screens/question_gpt_screen.dart';
import 'features/past_questions/models/past_question_models.dart';

import 'features/cgpa/screens/cgpa_home_screen.dart';

import 'features/cereva/screens/ai_screen.dart';

import 'features/cereva/screens/cereva_home.dart';
import 'features/scanner/screens/scanner_screen.dart';
import 'features/cereva/screens/ai_voice_screen.dart';
import 'features/ai_board/screens/ai_board_screen.dart';
import 'features/cereva/screens/ai_gpt.dart';
import 'features/cereva/screens/voice_chat_welcome_screen.dart';

import 'features/documents/screens/document_selector_screen.dart';

import 'features/documents/screens/study_guide_screen.dart';
import 'features/documents/screens/document_viewer_screen.dart';

import 'features/calendar/screens/calendar_screen.dart';
import 'features/calendar/screens/timer_screen.dart';

import 'features/progress/screens/progress_screen.dart';

import 'features/profile/screens/profile_details.dart';
import 'features/profile/screens/profile_screen.dart';
import 'features/profile/screens/update_level_screen.dart';
import 'features/profile/screens/edit_profile_screen.dart';

import 'features/activate/screens/activate_screen.dart';
import 'features/billing/screens/billing_screen.dart';

import 'features/all_features/screens/features_screen.dart';

import 'features/info/screens/general_info_screen.dart';
import 'features/info/screens/notification_screen.dart';
import 'features/home/screens/coming_soon_screen.dart';
import 'features/debug/debug_screen_logOut.dart';

// lib/main.dart

// Import Hive adapters FIRST
import 'features/courses/models/course_hive_adapters.dart';

// Import your screens... (keep all your existing imports)

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    print('🚀 Starting app initialization...');

    await Hive.initFlutter();
    print('✅ Hive initialized with default (correct) path');

    // Step 3: Register ALL Hive adapters BEFORE opening boxes
    print('📝 Registering Hive adapters...');

    // Register adapters in CORRECT ORDER to avoid conflicts
    try {
      // Check if adapters are already registered to avoid conflicts
      if (!Hive.isAdapterRegistered(11)) {
        Hive.registerAdapter(CGPACourseAdapter());
        print('✅ CGPACourseAdapter registered (typeId: 11)');
      }

      if (!Hive.isAdapterRegistered(10)) {
        Hive.registerAdapter(CGPALevelAdapter());
        print('✅ CGPALevelAdapter registered (typeId: 10)');
      }
    } catch (e) {
      print('⚠️ CGPA adapter registration error: $e');
    }

    // Register other adapters with typeId checks
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(ChatSessionAdapter());
      print('✅ ChatSessionAdapter registered');
    }

    if (!Hive.isAdapterRegistered(2)) {
      Hive.registerAdapter(ChatMessageAdapter());
      print('✅ ChatMessageAdapter registered');
    }

    if (!Hive.isAdapterRegistered(3)) {
      Hive.registerAdapter(ColorAdapter());
      print('✅ ColorAdapter registered');
    }

    if (!Hive.isAdapterRegistered(4)) {
      Hive.registerAdapter(CourseAdapter());
      print('✅ CourseAdapter registered');
    }

    if (!Hive.isAdapterRegistered(5)) {
      Hive.registerAdapter(CourseOutlineAdapter());
      print('✅ CourseOutlineAdapter registered');
    }

    try {
      if (!Hive.isAdapterRegistered(33)) {
        // Register UserProfile adapter
        Hive.registerAdapter(UserProfileAdapter());
        print('✅ UserProfileAdapter registered (typeId: 33)');
      }
    } catch (e) {
      print('⚠️ UserProfileAdapter error: $e');
    }

    try {
      if (!Hive.isAdapterRegistered(36)) {
        Hive.registerAdapter(DownloadRecordAdapter());
        print('✅ DownloadRecordAdapter registered (typeId: 6)');
      }
    } catch (e) {
      print('⚠️ DownloadRecordAdapter error: $e');
    }
    // Register Chat adapter

    // Hive.registerAdapter(ChatSessionAdapter());
    // Hive.registerAdapter(ChatMessageAdapter());

    // Hive.registerAdapter(ColorAdapter());
    // Hive.registerAdapter(CourseAdapter());
    // Hive.registerAdapter(CourseOutlineAdapter());

    // 4. Try to register CGPA adapters (they might not be generated yet

    // Verify CGPA adapters
    print('🔍 Verifying CGPA adapters:');
    print('   CGPALevelAdapter (10): ${Hive.isAdapterRegistered(10)}');
    print('   CGPACourseAdapter (11): ${Hive.isAdapterRegistered(11)}');

    // Open offline boxes FIRST
    await Hive.openBox('offline_courses');
    await Hive.openBox('courses_cache');
    await Hive.openBox('recent_course');
    await Hive.openBox('course_progress_cache');
    await Hive.openBox('course_outlines_cache');
    await Hive.openBox('activation_cache');
    await Hive.openBox('user_offline_data');
    // Open other boxes
    await Hive.openBox('user_box');
    await Hive.openBox('settings_box');
    await Hive.openBox('document_downloads'); // Add this line

    try {
      await Hive.openBox('cgpa_box');
      print('✅ CGPA box opened in main.dart');
    } catch (e) {
      print('⚠️ Could not open CGPA box in main.dart: $e');
    }

    print('📦 All boxes opened successfully');

    // Step 5: Initialize services
    // final offlineService = OfflineService();
    await OfflineService().initHive();
    print('✅ OfflineService initialized');

    // Test CGPA immediately
    await _testCGPAService();

    // Call it in main() after Hive.initFlutter()
    await _checkCGPABox();

    // Step 6: Check what's in offline storage
    await _debugOfflineStorage();
  } catch (e) {
    print('❌ ERROR during initialization: $e');
    // Don't crash - try to continue
  }

  runApp(const CerenixApp());
}

// Add this function to main.dart
Future<void> _checkCGPABox() async {
  print('🔍 Checking CGPA box manually...');

  try {
    // Try to open without deleting
    final box = await Hive.openBox('cgpa_box');
    print('✅ Box opened successfully');
    print('   Keys: ${box.keys.toList()}');
    print('   Length: ${box.length}');

    // Check for user 3 data
    final user3Data = box.get('cgpa_3');
    print('   User 3 data exists: ${user3Data != null}');

    if (user3Data != null) {
      print('   Type: ${user3Data.runtimeType}');
      if (user3Data is List) {
        print('   List length: ${user3Data.length}');
      }
    }

    await box.close();
  } catch (e) {
    print('❌ Error checking box: $e');
  }
}

// Test CGPA service
Future<void> _testCGPAService() async {
  print('🧪 Testing CGPA Service...');
  try {
    if (!Hive.isBoxOpen('cgpa_box')) {
      print('❌ CGPA box is not open!');
      return;
    }

    final cgpaBox = Hive.box('cgpa_box');

    // Clean any old test data
    await cgpaBox.delete('__test_cgpa__');

    // Create test objects
    final testCourse = CGPACourse(code: 'TEST101', unit: 3, grade: 'A');
    final testLevel = CGPALevel(
      level: '100',
      firstSemester: [testCourse],
      secondSemester: [],
    );

    print('   Created test objects');

    // Save test
    await cgpaBox.put('__test_cgpa__', [testLevel]);
    print('✅ Test data saved');

    // Load test
    final loaded = cgpaBox.get('__test_cgpa__');
    print('✅ Test data loaded');
    print('   Type: ${loaded.runtimeType}');

    if (loaded is List) {
      print('   List length: ${loaded.length}');
      if (loaded.isNotEmpty && loaded[0] is CGPALevel) {
        print('   ✅ Valid CGPALevel object!');
      }
    }

    // Clean up
    await cgpaBox.delete('__test_cgpa__');
    print('✅ Test cleanup complete');
  } catch (e) {
    print('❌ CGPA service test failed: $e');
  }
}

// Debug function to see what's in offline storage
Future<void> _debugOfflineStorage() async {
  try {
    final box = await Hive.openBox('offline_courses');
    final downloadedIds = box.get(
      'downloaded_course_ids',
      defaultValue: <String>[],
    );

    print('📊 === OFFLINE STORAGE CHECK ===');
    print('📥 Downloaded course IDs: ${downloadedIds.length}');
    print('📋 IDs: $downloadedIds');

    for (var courseId in downloadedIds) {
      print('\n🔍 Checking course: $courseId');
      final courseData = box.get('course_$courseId');

      if (courseData != null) {
        final data = Map<String, dynamic>.from(courseData);
        print('   ✅ Has offline data');
        print('   📄 Keys: ${data.keys.toList()}');

        if (data['outlines'] != null) {
          final outlines = data['outlines'] as List;
          print('   📑 Outlines: ${outlines.length}');
        }

        if (data['topics'] != null) {
          final topics = data['topics'] as List;
          print('   📚 Topics: ${topics.length}');
        }

        if (data['course'] != null) {
          print('   📖 Course data exists');
        }
      } else {
        print('   ❌ No offline data found!');
      }
    }

    print('📊 === END OFFLINE CHECK ===');
  } catch (e) {
    print('⚠️ Error checking offline storage: $e');
  }
}

class CerenixApp extends StatelessWidget {
  const CerenixApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cerenix',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      initialRoute: '/',
      routes: {
        '/': (_) => const SplashScreen(),
        '/home': (_) => const MainLayout(), // CHANGE THIS LINE
        '/coming-soon': (_) => const ComingSoonScreen(),

        '/onboarding': (context) => const CerenixOnboardingScreen(),
        '/signup': (context) => const SignupPage(),
        '/signin': (context) => const SigninPage(),
        '/academic_setup': (context) => const AcademicSetupScreen(),
        '/terms': (context) =>
            const TermsAndConditionsScreen(userData: UserOnboardingData.empty),

        // '/home': (_) => const HomeScreen(),
        '/courses': (_) => const CoursesScreen(),

        // '/course-detail': (context) {
        //   final course = ModalRoute.of(context)!.settings.arguments;
        //   return CourseDetailsScreen(course: course);
        // },
        '/course-detail': (context) {
          final args = ModalRoute.of(context)!.settings.arguments;

          if (args is Course) {
            // If argument is already a Course object
            return CourseDetailsScreen(course: args);
          } else if (args is Map<String, dynamic>) {
            // If argument is a Map (from older code), convert it to Course
            try {
              final course = Course.fromJson(args);
              return CourseDetailsScreen(course: course);
            } catch (e) {
              print('Error converting map to Course: $e');
              return const Scaffold(
                body: Center(child: Text('Error: Invalid course data')),
              );
            }
          } else {
            // Handle null or other types
            return const Scaffold(
              body: Center(child: Text('Course not found')),
            );
          }
        },

        // '/lecture': (context) {
        //   final args =
        //       ModalRoute.of(context)!.settings.arguments
        //           as Map<String, dynamic>;
        //   return LectureScreen(
        //     course: args['course'],
        //     outline: args['outline'],
        //     outlines: args['outlines'],
        //   );
        // },
        '/lecture': (context) {
          final args =
              ModalRoute.of(context)!.settings.arguments
                  as Map<String, dynamic>;
          return LectureScreen(
            course: args['course'],
            outline: args['outline'],
            outlines: args['outlines'],
          );
        },

        // UPDATE THESE PAST QUESTION ROUTES:
        '/past-questions': (_) =>
            const PastQuestionsSelectionScreen(), // Changed to selection screen
        // In your lib/main.dart, update the route for past-questions-screen:
        '/past-questions-screen': (context) {
          final args =
              ModalRoute.of(context)!.settings.arguments
                  as Map<String, dynamic>;
          return PastQuestionsScreen(
            courseId: args['courseId'] ?? '',
            courseName: args['courseName'] ?? '',
            sessionId: args['sessionId'],
            sessionName: args['sessionName'] ?? '',
            topicId: args['topicId'], // ADD THIS
            topicName: args['topicName'], // ADD THIS
            randomMode: args['randomMode'] ?? false,
          );
        },

        '/question-gpt': (context) {
          final args =
              ModalRoute.of(context)!.settings.arguments
                  as Map<String, dynamic>;
          return QuestionGPTScreen(
            question: args['question'] as PastQuestion,
            courseName: args['courseName'] ?? '',
            topicName: args['topicName'],
            showAnswer: args['showAnswer'] ?? false,
          );
        },
        '/test-questions': (_) => const TestQuestionsSelectionScreen(),
        // In your lib/main.dart, update the route for past-questions-screen:
        '/test-questions-screen': (context) {
          final args =
              ModalRoute.of(context)!.settings.arguments
                  as Map<String, dynamic>;
          return TestQuestionsScreen(
            courseId: args['courseId'] ?? '',
            courseName: args['courseName'] ?? '',
            sessionId: args['sessionId'],
            sessionName: args['sessionName'] ?? '',
            topicId: args['topicId'], // ADD THIS
            topicName: args['topicName'], // ADD THIS
            randomMode: args['randomMode'] ?? false,
          );
        },
        '/cbt-questions': (_) => const CBTSelectionScreen(),

        '/cbtquestions': (context) {
          final args =
              ModalRoute.of(context)!.settings.arguments
                  as Map<String, dynamic>;
          return CBTQuestionsScreen(
            courseId: args['courseId'] ?? '',
            courseName: args['courseName'] ?? '',
            sessionId: args['sessionId'],
            sessionName: args['sessionName'] ?? '',
            topicId: args['topicId'],
            topicName: args['topicName'],
            randomMode: args['randomMode'] ?? false,
            enableTimer: args['enableTimer'] ?? false,
            isOffline: args['isOffline'] ?? true, // CBT is offline-only
          );
        },

        // '/cbtquestions': (context) {
        //   final args =
        //       ModalRoute.of(context)!.settings.arguments
        //           as Map<String, dynamic>;
        //   return CbtMainScreen(
        //     courseId: args['courseId'] ?? '',
        //     courseName: args['courseName'] ?? '',
        //     sessionId: args['sessionId'],
        //     sessionName: args['sessionName'] ?? '',
        //     topicId: args['topicId'],
        //     topicName: args['topicName'],
        //     questionCount:
        //         args['questionCount'] ?? 20, // Default to 20 questions
        //     timeLimit: args['timeLimit'] ?? 30, // Default to 30 minutes
        //   );
        // },

        // Add this route in your routes section:
        // '/study-guide': (_) => const StudyGuideScreen(
        //   university: 'University of Lagos', // Set your default university
        //   department: 'Computer Science', // Set your default department
        //   level: 100, // Set your default level
        //   semester: 1, // Set your default semester
        // ),
        '/study-guide': (context) {
          final args =
              ModalRoute.of(context)!.settings.arguments
                  as Map<String, dynamic>?;

          // Default values (should rarely be used)
          final defaultUniversity =
              args?['university'] ?? 'University of Lagos';
          final defaultDepartment = args?['department'] ?? 'Computer Science';
          final defaultLevel = args?['level'] ?? 100;
          final defaultSemester = args?['semester'] ?? 1;

          return StudyGuideScreen(
            university: defaultUniversity,
            department: defaultDepartment,
            level: defaultLevel,
            semester: defaultSemester,
          );
        },

        '/ai': (_) => const AIScreen(),
        '/ai-home': (_) => const AIHomeScreen(),
        '/scanner': (_) => const NewScannerScreen(),
        '/ai-voice': (_) => const VoiceWelcomeScreen(),
        '/voice-chat': (_) => const VoiceChatScreen(),
        '/ai-board': (_) => const AIBoardScreen(),
        '/gpt': (_) => const AIChatScreen(),

        '/progress': (_) => const ProgressScreen(),
        '/cgpa': (_) => const CGPACalculatorScreen(),
        '/profile': (_) => const ProfileScreen(),
        '/profile-details': (_) => const ProfileDetailsScreen(),
        '/activate': (_) => const ActivationScreen(),
        '/billing': (_) => const BillingScreen(),

        '/features': (_) => const FeaturesScreen(),

        '/calendar': (_) => const CalendarTimerScreen(),
        '/timer': (_) => const TimerScreen(),
        '/general-info': (_) => const GeneralInfoScreen(),
        '/notification': (context) => const NotificationScreen(),

        '/update-level': (_) => const UpdateLevelScreen(),
        '/settings': (_) => const EditProfileScreen(),

        '/documents': (_) => const DocumentSelectorScreen(),
        '/debug': (context) => DebugScreen(),
      },
    );
  }
}
