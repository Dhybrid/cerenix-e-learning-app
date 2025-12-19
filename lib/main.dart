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

// void main() async {
//   WidgetsFlutterBinding.ensureInitialized();


//   // Get application documents directory
//   final appDir = await getApplicationDocumentsDirectory();

//   // Initialize Hive
//   await Hive.initFlutter();
//   await Hive.openBox('user_box'); // Stores current user
//   await Hive.openBox('settings_box'); // For theme, notifications, etc.
//   await Hive.openBox('courses_box');

//   await Hive.openBox('cgpa_box'); // ADD THIS LINE

//   await Hive.openBox('offline_courses'); // Make sure this box is opened
//   await Hive.openBox('course_progress_cache'); // Open progress cache
//   await Hive.openBox('course_outlines_cache'); // Open outlines cache

//   // Initialize offline service with adapters
//   await OfflineService.initHive();

//   // Register adapters
//   Hive.registerAdapter(ChatSessionAdapter());
//   Hive.registerAdapter(ChatMessageAdapter());

//   // Open boxes

//   runApp(const CerenixApp());
// }

// lib/main.dart

// Import Hive adapters FIRST
import 'features/courses/models/course_hive_adapters.dart';


// Import your screens... (keep all your existing imports)

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    print('🚀 Starting app initialization...');

     try {
      await Hive.deleteBoxFromDisk('cgpa_box');
      print('✅ Cleared cgpa_box');
    } catch (e) {
      print('⚠️ Could not clear cgpa_box: $e');
    }
    
    // Step 1: Get application directory
    // final appDir = await getApplicationDocumentsDirectory();
    // print('📁 App directory: ${appDir.path}');
    
    // Step 2: Initialize Hive with Flutter
    // await Hive.initFlutter(appDir.path);

    // This above

    await Hive.initFlutter();
    print('✅ Hive initialized with default (correct) path');
    print('✅ Hive initialized');
    
    // Step 3: Register ALL Hive adapters BEFORE opening boxes
    print('📝 Registering Hive adapters...');
    
    // Register Chat adapters

    Hive.registerAdapter(CGPALevelAdapter());
    Hive.registerAdapter(CGPACourseAdapter());

    Hive.registerAdapter(ChatSessionAdapter());
    Hive.registerAdapter(ChatMessageAdapter());

    Hive.registerAdapter(ColorAdapter());
    Hive.registerAdapter(CourseAdapter());
    Hive.registerAdapter(CourseOutlineAdapter());

    print('✅ All adapters registered');
    
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
    // await Hive.openBox<List<dynamic>>('cgpa_box');
    await Hive.openBox('cgpa_box');


    
    print('📦 All boxes opened successfully');
    
    // Step 5: Initialize services
    // final offlineService = OfflineService();
    await OfflineService().initHive();
    print('✅ OfflineService initialized');
    
    
    // Step 6: Check what's in offline storage
    await _debugOfflineStorage();

    // Debug check
    await _clearCorruptedCGPA();
    
  } catch (e) {
    print('❌ ERROR during initialization: $e');
    // Don't crash - try to continue
  }

  runApp(const CerenixApp());
}

// Debug function to see what's in offline storage
Future<void> _debugOfflineStorage() async {
  try {
    final box = await Hive.openBox('offline_courses');
    final downloadedIds = box.get('downloaded_course_ids', defaultValue: <String>[]);
    
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

// Function to clear corrupted CGPA data
Future<void> _clearCorruptedCGPA() async {
  try {
    print('🧹 Checking for corrupted CGPA data...');
    final box = Hive.box('cgpa_box');
    
    // Check each key
    for (var key in box.keys) {
      final value = box.get(key);
      print('   Key: $key, Type: ${value.runtimeType}');
      
      // If data is stored as Map (corrupted), delete it
      if (value is List && value.isNotEmpty && value.first is Map) {
        print('   ❌ Found corrupted Map data at key: $key, deleting...');
        await box.delete(key);
      } else if (value is! List && value != null) {
        print('   ❌ Found non-List data at key: $key, deleting...');
        await box.delete(key);
      }
    }
    
    print('✅ CGPA data cleanup complete');
  } catch (e) {
    print('⚠️ Error cleaning CGPA data: $e');
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
          final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
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
          final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
          return PastQuestionsScreen(
            courseId: args['courseId'] ?? '',
            courseName: args['courseName'] ?? '',
            sessionId: args['sessionId'],
            sessionName: args['sessionName'] ?? '',
            topicId: args['topicId'],  // ADD THIS
            topicName: args['topicName'],  // ADD THIS
            randomMode: args['randomMode'] ?? false,
          );
        },

        '/question-gpt': (context) {
          final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
          return QuestionGPTScreen(
            question: args['question'] as PastQuestion,
            courseName: args['courseName'] ?? '',
            topicName: args['topicName'],
            showAnswer: args['showAnswer'] ?? false,
          );
        },
        '/test-questions': (_) => const TestQuestionsSelectionScreen(),
        '/test-questions-screen': (_) => const TestQuestionsScreen(
          session: '2022/2023',
          course: 'PHY 101',
          topic: 'Mechanics',
          randomMode: false,
        ),
        '/cbt-questions': (_) => const CBTSelectionScreen(),
        '/cbtquestions': (context) {
          final args = ModalRoute.of(context)!.settings.arguments as Map;
          return CBTQuestionsScreen(
            session: args['session'],
            course: args['course'],
            topic: args['topic'],
            randomMode: args['randomMode'],
            enableTimer: args['enableTimer'],
          );
        },
        // Add this route in your routes section:
        // '/study-guide': (context) {
        //   final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
        //   return StudyGuideScreen(
        //     university: args['university'],
        //     department: args['department'],
        //     level: args['level'],
        //     semester: args['semester'],
        //   );
        // },

        // Add this route in your routes section:
        '/study-guide': (_) => const StudyGuideScreen(
          university: 'University of Lagos', // Set your default university
          department: 'Computer Science',    // Set your default department
          level: 100,                        // Set your default level
          semester: 1,                       // Set your default semester
        ),

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
