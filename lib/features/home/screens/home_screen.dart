// // lib/features/home/screens/home_screen.dart
// import 'package:flutter/material.dart';
// import 'package:hive_flutter/hive_flutter.dart';
// import '../widgets/advert_carousel.dart';
// import '../widgets/general_info_card.dart';
// import '../../../core/widgets/custom_app_bar.dart';
// import '../../../core/widgets/custom_drawer.dart';
// import '../../../core/constants/endpoints.dart';
// import '../../../features/courses/models/course_models.dart'; // Already have this
// import '../../../core/network/api_service.dart'; // ADD THIS LINE

// class HomeScreen extends StatefulWidget {
//   const HomeScreen({super.key});
//   @override
//   State<HomeScreen> createState() => _HomeScreenState();
// }

// class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
//   final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
//   late final AnimationController _pulseController;
//   late final Animation<double> _pulseAnimation;

//   // AI Bot Draggable Variables - Start hidden to the right
//   double _aiBotPositionX = 350; // Start hidden off-screen to the right
//   double _aiBotPositionY = 300; // Position closer to middle-bottom
//   bool _aiBotIsDragging = false;
//   final double _aiBotSize = 90;

//   // Toggle: Recent / Calendar
//   int _selectedTab = 0;

//   // Streak tracking variables
//   int _currentStreak = 0;
//   int _longestStreak = 0;
//   int _totalOpenedDays = 0;
//   bool _isLoadingStreak = true;

//   // ADD THESE FIELDS:
//   List<Course> _recentCourses = [];
//   bool _loadingRecentCourses = false;
//   String? _currentUserId;
//   static const String recentCourseBox =
//       'recent_course'; // Same as courses screen
//   static const String offlineCoursesBox =
//       'offline_courses'; // For download status

//   @override
//   void initState() {
//     super.initState();
//     _pulseController = AnimationController(
//       vsync: this,
//       duration: const Duration(milliseconds: 1500),
//     )..repeat(reverse: true);

//     _pulseAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
//       CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
//     );

//     // Show AI bot after a brief delay
//     WidgetsBinding.instance.addPostFrameCallback((_) {
//       _animateAIBotToPosition();
//     });

//     // Load streak data
//     _initializeStreakData();

//     // ADD THIS LINE: Load recent courses
//     _loadRecentCourses();
//   }

//   void _animateAIBotToPosition() {
//     setState(() {
//       // Move to quarter of screen width, near bottom right but not exactly corner
//       _aiBotPositionX =
//           MediaQuery.of(context).size.width * 0.75 - _aiBotSize / 2;
//       _aiBotPositionY =
//           MediaQuery.of(context).size.height * 0.7 - _aiBotSize / 2;
//     });
//   }

//   @override
//   void dispose() {
//     _pulseController.dispose();
//     super.dispose();
//   }

//   Future<void> _initializeStreakData() async {
//     await _recordAppOpen();
//     await _loadStreakData();
//   }

//   // ADD THIS METHOD: Refresh recent courses when home screen becomes visible
//   Future<void> _refreshRecentCourses() async {
//     await _loadRecentCourses();
//   }

//   // You can call this in didChangeDependencies or using a Focus listener
//   @override
//   void didChangeDependencies() {
//     super.didChangeDependencies();
//     // Refresh when screen comes back into focus
//     _refreshRecentCourses();
//   }

//   // ADD THIS METHOD: Get current user ID
//   Future<void> _getCurrentUserId() async {
//     try {
//       final box = await Hive.openBox('user_box');
//       final userData = box.get('current_user');
//       if (userData != null) {
//         _currentUserId = userData['id'].toString();
//         print('👤 Home: Got user ID: $_currentUserId');
//       }
//     } catch (e) {
//       print('⚠️ Home: Error getting user ID: $e');
//     }
//   }

//   // ADD THIS METHOD: Load recent courses
//   Future<void> _loadRecentCourses() async {
//     if (_loadingRecentCourses) return;

//     setState(() {
//       _loadingRecentCourses = true;
//     });

//     try {
//       await _getCurrentUserId();

//       if (_currentUserId == null) {
//         print('⚠️ Home: No user ID, cannot load recent courses');
//         return;
//       }

//       // Get the most recent course from storage
//       final box = await Hive.openBox(recentCourseBox);
//       final userKey = 'recent_course_$_currentUserId';
//       final recentData = box.get(userKey);

//       if (recentData != null) {
//         Course? recentCourse;

//         // Handle different data types
//         if (recentData is Map) {
//           try {
//             final Map<String, dynamic> jsonData = {};
//             recentData.forEach((key, value) {
//               if (key is String) {
//                 jsonData[key] = value;
//               } else if (key is int || key is double) {
//                 jsonData[key.toString()] = value;
//               }
//             });
//             recentCourse = Course.fromJson(jsonData);
//           } catch (e) {
//             print('❌ Home: Error parsing recent course: $e');
//           }
//         } else if (recentData is Course) {
//           recentCourse = recentData;
//         }

//         if (recentCourse != null) {
//           // Get all courses to find 3 most recent
//           final allCourses = await _getAllUserCourses();

//           // Sort by most recent (put the single recent course first)
//           List<Course> recentCoursesList = [];

//           // Add the most recent course
//           recentCoursesList.add(recentCourse);

//           // Add up to 2 more courses (excluding the already added one)
//           int addedCount = 0;
//           for (var course in allCourses) {
//             if (course.id != recentCourse.id && addedCount < 2) {
//               recentCoursesList.add(course);
//               addedCount++;
//             }
//             if (recentCoursesList.length >= 3) break;
//           }

//           // Load progress for each course
//           await _loadRecentCoursesProgress(recentCoursesList);

//           setState(() {
//             _recentCourses = recentCoursesList;
//           });

//           print('✅ Home: Loaded ${_recentCourses.length} recent courses');
//         }
//       } else {
//         print('ℹ️ Home: No recent course found, loading first 3 courses');

//         // If no recent course, just show first 3 courses
//         final allCourses = await _getAllUserCourses();
//         final firstThreeCourses = allCourses.take(3).toList();

//         await _loadRecentCoursesProgress(firstThreeCourses);

//         setState(() {
//           _recentCourses = firstThreeCourses;
//         });
//       }
//     } catch (e) {
//       print('❌ Home: Error loading recent courses: $e');
//       setState(() {
//         _recentCourses = [];
//       });
//     } finally {
//       setState(() {
//         _loadingRecentCourses = false;
//       });
//     }
//   }

//   // ADD THIS METHOD: Get all user courses
//   Future<List<Course>> _getAllUserCourses() async {
//     try {
//       final courses = await ApiService().getCoursesForUser();
//       return courses;
//     } catch (e) {
//       print('⚠️ Home: Error getting all courses: $e');
//       return [];
//     }
//   }

//   // ADD THIS METHOD: Load progress for recent courses
//   Future<void> _loadRecentCoursesProgress(List<Course> courses) async {
//     try {
//       for (var course in courses) {
//         try {
//           final topics = await ApiService().getTopics(
//             courseId: int.parse(course.id),
//           );

//           if (topics.isNotEmpty) {
//             int completedCount = 0;
//             for (var topic in topics) {
//               if (topic.isCompleted) {
//                 completedCount++;
//               }
//             }

//             final progress = topics.isNotEmpty
//                 ? ((completedCount / topics.length) * 100).round()
//                 : 0;

//             course.progress = progress;
//           } else {
//             course.progress = 0;
//           }
//         } catch (e) {
//           course.progress = 0;
//         }
//       }
//     } catch (e) {
//       print('⚠️ Home: Error loading recent courses progress: $e');
//     }
//   }

//   // ADD THIS METHOD: Check if course is downloaded
//   Future<bool> _isCourseDownloaded(String courseId) async {
//     try {
//       final box = await Hive.openBox(offlineCoursesBox);
//       final downloadedCourseIds = box.get(
//         'downloaded_course_ids',
//         defaultValue: <String>[],
//       );
//       return downloadedCourseIds.contains(courseId);
//     } catch (e) {
//       return false;
//     }
//   }

//   // ADD THIS METHOD: Get course color
//   Color _getCourseColor(int index) {
//     final colors = [Colors.blue, Colors.green, Colors.orange];
//     return colors[index % colors.length];
//   }

//   // Streak tracking functions
//   Future<void> _recordAppOpen() async {
//     try {
//       final now = DateTime.now();
//       final today = DateTime(now.year, now.month, now.day);

//       // Open or create the streak box
//       final streakBox = await Hive.openBox('app_streak_tracking');

//       // Check if we already recorded today's open
//       final lastRecordedDate = streakBox.get('last_recorded_date');
//       if (lastRecordedDate != null) {
//         final lastDate = DateTime.parse(lastRecordedDate);
//         // If we already recorded today, don't record again
//         if (lastDate.isAtSameMomentAs(today)) {
//           return;
//         }
//       }

//       // Record today's open
//       final dateKey = today.toIso8601String();
//       streakBox.put(dateKey, true);
//       streakBox.put('last_recorded_date', dateKey);

//       print('📱 Home: Recorded app open for streak: $dateKey');
//     } catch (e) {
//       print('⚠️ Home: Error recording app open: $e');
//     }
//   }

//   Future<void> _loadStreakData() async {
//     try {
//       final streakBox = await Hive.openBox('app_streak_tracking');
//       final now = DateTime.now();
//       final today = DateTime(now.year, now.month, now.day);

//       // Get all recorded dates
//       final allKeys = streakBox.keys.toList();
//       List<DateTime> openedDates = [];

//       for (var key in allKeys) {
//         if (key != 'last_recorded_date' && streakBox.get(key) == true) {
//           try {
//             final date = DateTime.parse(key);
//             openedDates.add(date);
//           } catch (e) {
//             print('⚠️ Home: Error parsing date $key: $e');
//           }
//         }
//       }

//       // Sort dates
//       openedDates.sort((a, b) => a.compareTo(b));

//       // Calculate streaks
//       int currentStreak = 0;
//       int longestStreak = 0;
//       int tempStreak = 0;

//       // Check current streak (consecutive days up to today)
//       DateTime checkDate = today;
//       while (openedDates.any(
//         (date) =>
//             date.year == checkDate.year &&
//             date.month == checkDate.month &&
//             date.day == checkDate.day,
//       )) {
//         currentStreak++;
//         checkDate = checkDate.subtract(const Duration(days: 1));
//       }

//       // Calculate longest streak
//       if (openedDates.isNotEmpty) {
//         tempStreak = 1;
//         for (int i = 1; i < openedDates.length; i++) {
//           final prevDate = openedDates[i - 1];
//           final currDate = openedDates[i];
//           final difference = currDate.difference(prevDate).inDays;

//           if (difference == 1) {
//             tempStreak++;
//           } else {
//             if (tempStreak > longestStreak) {
//               longestStreak = tempStreak;
//             }
//             tempStreak = 1;
//           }
//         }

//         // Check last streak
//         if (tempStreak > longestStreak) {
//           longestStreak = tempStreak;
//         }
//       }

//       setState(() {
//         _currentStreak = currentStreak;
//         _longestStreak = longestStreak;
//         _totalOpenedDays = openedDates.length;
//         _isLoadingStreak = false;
//       });

//       print('📊 Home: Streak data loaded:');
//       print('   Current streak: $currentStreak days');
//       print('   Longest streak: $longestStreak days');
//       print('   Total days opened: ${openedDates.length}');
//     } catch (e) {
//       print('⚠️ Home: Error loading streak data: $e');
//       setState(() {
//         _currentStreak = 0;
//         _longestStreak = 0;
//         _totalOpenedDays = 0;
//         _isLoadingStreak = false;
//       });
//     }
//   }

//   String _getStreakMessage(int streak) {
//     if (streak >= 30) return 'Legendary consistency! 🏆';
//     if (streak >= 14) return 'Great commitment!';
//     if (streak >= 7) return 'Building strong habits!';
//     if (streak >= 3) return 'Keep the momentum going!';
//     return 'Consistency is key to mastery.';
//   }

//   // Get user data from Hive
//   Map<String, dynamic>? _getUserData() {
//     try {
//       final box = Hive.box('user_box');
//       final userData = box.get('current_user');
//       return userData != null ? Map<String, dynamic>.from(userData) : null;
//     } catch (e) {
//       return null;
//     }
//   }

//   // Get user name
//   String _getUserName() {
//     final userData = _getUserData();
//     return userData?['name']?.toString() ?? 'Student';
//   }

//   // Get profile image URL - USING ApiEndpoints.baseUrl
//   String _getProfileImageUrl() {
//     try {
//       final userData = _getUserData();
//       if (userData == null) return '';

//       final avatarUrl = userData['avatar']?.toString() ?? '';
//       if (avatarUrl.isEmpty) return '';

//       if (avatarUrl.startsWith('http')) return avatarUrl;

//       // Handle relative URLs using ApiEndpoints.baseUrl
//       return avatarUrl.startsWith('/')
//           ? '${ApiEndpoints.baseUrl}$avatarUrl'
//           : '${ApiEndpoints.baseUrl}/$avatarUrl';
//     } catch (e) {
//       return '';
//     }
//   }

//   void _showPastQuestionsBottomSheet() {
//     showModalBottomSheet(
//       context: context,
//       isScrollControlled: true,
//       backgroundColor: Colors.transparent,
//       builder: (context) => _buildPastQuestionsSheet(),
//     );
//   }

//   Widget _buildPastQuestionsSheet() {
//     return Container(
//       height: MediaQuery.of(context).size.height * 0.75,
//       decoration: const BoxDecoration(
//         color: Colors.white,
//         borderRadius: BorderRadius.only(
//           topLeft: Radius.circular(32),
//           topRight: Radius.circular(32),
//         ),
//       ),
//       child: Column(
//         children: [
//           // Drag Handle
//           Container(
//             margin: const EdgeInsets.only(top: 12, bottom: 8),
//             width: 40,
//             height: 4,
//             decoration: BoxDecoration(
//               color: Colors.grey.shade300,
//               borderRadius: BorderRadius.circular(2),
//             ),
//           ),

//           // Header
//           Padding(
//             padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
//             child: Row(
//               mainAxisAlignment: MainAxisAlignment.spaceBetween,
//               children: [
//                 const Text(
//                   'Study Materials',
//                   style: TextStyle(
//                     fontSize: 24,
//                     fontWeight: FontWeight.w700,
//                     color: Color(0xFF1A1A2E),
//                   ),
//                 ),
//                 IconButton(
//                   icon: Container(
//                     padding: const EdgeInsets.all(6),
//                     decoration: BoxDecoration(
//                       color: Colors.grey.shade100,
//                       borderRadius: BorderRadius.circular(12),
//                     ),
//                     child: const Icon(Icons.close_rounded, size: 20),
//                   ),
//                   onPressed: () => Navigator.pop(context),
//                 ),
//               ],
//             ),
//           ),

//           const SizedBox(height: 8),

//           // Vertical List (No Grid to avoid overflow)
//           Expanded(
//             child: SingleChildScrollView(
//               padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
//               child: Column(
//                 children: [
//                   _buildStudyOption(
//                     icon: Icons.history_edu_rounded,
//                     title: 'Past Questions',
//                     subtitle: 'Previous exam papers and solutions',
//                     color: const Color(0xFF6366F1),
//                     onTap: () {
//                       Navigator.pop(context);
//                       Navigator.pushNamed(context, '/past-questions');
//                     },
//                   ),
//                   const SizedBox(height: 12),
//                   _buildStudyOption(
//                     icon: Icons.quiz_rounded,
//                     title: 'Test Questions',
//                     subtitle: 'Practice tests and quizzes',
//                     color: const Color(0xFF10B981),
//                     onTap: () {
//                       Navigator.pop(context);
//                       Navigator.pushNamed(context, '/test-questions');
//                     },
//                   ),
//                   const SizedBox(height: 12),
//                   _buildStudyOption(
//                     icon: Icons.computer_rounded,
//                     title: 'CBT Practice',
//                     subtitle: 'Computer based test simulations',
//                     color: const Color(0xFFF59E0B),
//                     onTap: () {
//                       Navigator.pop(context);
//                       Navigator.pushNamed(context, '/cbt-questions');
//                     },
//                   ),
//                   const SizedBox(height: 12),
//                   _buildStudyOption(
//                     icon: Icons.library_books_rounded,
//                     title: 'Study Guides',
//                     subtitle: 'Comprehensive study materials',
//                     color: const Color(0xFFEF4444),
//                     onTap: () {
//                       Navigator.pop(context);
//                       Navigator.pushNamed(context, '/study-guide');
//                     },
//                   ),
//                   const SizedBox(height: 20),
//                 ],
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildStudyOption({
//     required IconData icon,
//     required String title,
//     required String subtitle,
//     required Color color,
//     required VoidCallback onTap,
//   }) {
//     return Material(
//       borderRadius: BorderRadius.circular(16),
//       color: Colors.white,
//       elevation: 1,
//       child: InkWell(
//         borderRadius: BorderRadius.circular(16),
//         onTap: onTap,
//         child: Container(
//           padding: const EdgeInsets.all(16),
//           width: double.infinity,
//           decoration: BoxDecoration(
//             borderRadius: BorderRadius.circular(16),
//             border: Border.all(color: Colors.grey.shade100),
//           ),
//           child: Row(
//             children: [
//               Container(
//                 padding: const EdgeInsets.all(12),
//                 decoration: BoxDecoration(
//                   color: color.withOpacity(0.1),
//                   borderRadius: BorderRadius.circular(12),
//                 ),
//                 child: Icon(icon, color: color, size: 24),
//               ),
//               const SizedBox(width: 16),
//               Expanded(
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     Text(
//                       title,
//                       style: const TextStyle(
//                         fontSize: 16,
//                         fontWeight: FontWeight.w600,
//                         color: Color(0xFF1A1A2E),
//                       ),
//                     ),
//                     const SizedBox(height: 4),
//                     Text(
//                       subtitle,
//                       style: TextStyle(
//                         fontSize: 12,
//                         color: Colors.grey.shade600,
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//               const Icon(
//                 Icons.arrow_forward_ios_rounded,
//                 size: 16,
//                 color: Colors.grey,
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       key: _scaffoldKey,
//       backgroundColor: const Color(0xFFF8FAFC),
//       appBar: CustomAppBar(
//         scaffoldKey: _scaffoldKey,
//         title: 'Cerenix',
//         showNotifications: true,
//         showProfile: false,
//       ),
//       drawer: const CustomDrawer(),
//       body: Stack(
//         children: [
//           SingleChildScrollView(
//             padding: const EdgeInsets.all(16),
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 _buildWelcomeSection(),
//                 const SizedBox(height: 20),
//                 const AdvertCarousel(height: 140),
//                 const SizedBox(height: 24),
//                 _buildFeatureGrid(),
//                 const SizedBox(height: 28),
//                 _buildRecentOrCalendarSection(),
//                 const SizedBox(height: 28),
//                 _buildGeneralInfoSection(),
//                 const SizedBox(height: 28),
//                 _buildStreakSection(),
//                 const SizedBox(height: 100),
//               ],
//             ),
//           ),
//           _buildDraggableAIBot(),
//         ],
//       ),
//     );
//   }

//   // UPDATED: Welcome section with actual user profile picture and name - NO CLICK ACTION
//   Widget _buildWelcomeSection() {
//     final profileImageUrl = _getProfileImageUrl();
//     final userName = _getUserName();

//     return Row(
//       children: [
//         Expanded(
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               Text(
//                 'Hello, $userName',
//                 style: Theme.of(context).textTheme.headlineSmall?.copyWith(
//                   fontWeight: FontWeight.bold,
//                   color: const Color(0xFF1A1A2E),
//                 ),
//               ),
//               const SizedBox(height: 4),
//               const Text(
//                 'Ready to dive into knowledge?',
//                 style: TextStyle(color: Color(0xFF6B7280), fontSize: 14),
//               ),
//             ],
//           ),
//         ),
//         // Profile picture with NO click action - exactly as in your original design
//         Container(
//           width: 52,
//           height: 52,
//           decoration: BoxDecoration(
//             shape: BoxShape.circle,
//             border: Border.all(color: const Color(0xFF6366F1), width: 2),
//           ),
//           child: profileImageUrl.isNotEmpty
//               ? CircleAvatar(
//                   radius: 24,
//                   backgroundImage: NetworkImage(profileImageUrl),
//                   onBackgroundImageError: (exception, stackTrace) {
//                     // Fallback to icon if image fails to load
//                   },
//                   child: profileImageUrl.isEmpty
//                       ? const Icon(
//                           Icons.person_rounded,
//                           color: Color(0xFF6366F1),
//                           size: 24,
//                         )
//                       : null,
//                 )
//               : CircleAvatar(
//                   radius: 24,
//                   backgroundColor: const Color(0xFF6366F1).withOpacity(0.1),
//                   child: const Icon(
//                     Icons.person_rounded,
//                     color: Color(0xFF6366F1),
//                     size: 24,
//                   ),
//                 ),
//         ),
//       ],
//     );
//   }

//   Widget _buildFeatureGrid() {
//     final List<Map<String, dynamic>> features = [
//       {
//         'title': 'Courses',
//         'image': 'assets/images/course.png',
//         'route': '/courses',
//         'color': const Color(0xFF6366F1),
//       },
//       {
//         'title': 'Past Questions',
//         'image': 'assets/images/pastQuestions.png',
//         'route': '/past-questions',
//         'color': const Color(0xFF10B981),
//       },
//       {
//         'title': 'CGPA Calc',
//         'image': 'assets/images/CGPA.png',
//         'route': '/cgpa',
//         'color': const Color(0xFFF59E0B),
//       },
//       {
//         'title': 'Activate App',
//         'image': 'assets/images/activate.png',
//         'route': '/activate',
//         'color': const Color(0xFFEF4444),
//       },
//       {
//         'title': 'Scan Doc',
//         'image': 'assets/images/scan.png',
//         'route': '/scanner',
//         'color': const Color(0xFF8B5CF6),
//       },
//       {
//         'title': 'AI Board',
//         'image': 'assets/images/aiBoard.png',
//         'route': '/ai-board',
//         'color': const Color(0xFFEC4899),
//       },
//     ];

//     return GridView.builder(
//       shrinkWrap: true,
//       physics: const NeverScrollableScrollPhysics(),
//       gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
//         crossAxisCount: 3,
//         childAspectRatio: 1.0,
//         crossAxisSpacing: 12,
//         mainAxisSpacing: 12,
//       ),
//       itemCount: features.length,
//       itemBuilder: (context, index) {
//         final feature = features[index];
//         return _buildFeatureCard(feature);
//       },
//     );
//   }

//   Widget _buildFeatureCard(Map<String, dynamic> feature) {
//     return Material(
//       borderRadius: BorderRadius.circular(16),
//       color: Colors.transparent,
//       child: InkWell(
//         borderRadius: BorderRadius.circular(16),
//         onTap: () {
//           if (feature['title'] == 'Past Questions') {
//             _showPastQuestionsBottomSheet();
//           } else {
//             Navigator.pushNamed(context, feature['route']);
//           }
//         },
//         child: Container(
//           decoration: BoxDecoration(
//             borderRadius: BorderRadius.circular(16),
//             color: Colors.white,
//             boxShadow: [
//               BoxShadow(
//                 color: Colors.black.withOpacity(0.05),
//                 blurRadius: 8,
//                 offset: const Offset(0, 2),
//               ),
//             ],
//           ),
//           child: Column(
//             mainAxisAlignment: MainAxisAlignment.center,
//             children: [
//               Container(
//                 width: 60,
//                 height: 60,
//                 decoration: BoxDecoration(
//                   borderRadius: BorderRadius.circular(16),
//                   color: (feature['color'] as Color).withOpacity(0.15),
//                 ),
//                 child: Center(
//                   child: Image.asset(
//                     feature['image'],
//                     width: 36,
//                     height: 36,
//                     fit: BoxFit.contain,
//                     errorBuilder: (context, error, stackTrace) {
//                       return Icon(
//                         Icons.auto_awesome_rounded,
//                         color: feature['color'] as Color,
//                         size: 28,
//                       );
//                     },
//                   ),
//                 ),
//               ),
//               const SizedBox(height: 12),
//               Text(
//                 feature['title'],
//                 style: const TextStyle(
//                   fontSize: 12,
//                   fontWeight: FontWeight.w600,
//                   color: Color(0xFF1A1A2E),
//                 ),
//                 textAlign: TextAlign.center,
//                 maxLines: 2,
//                 overflow: TextOverflow.ellipsis,
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }

//   Widget _buildRecentOrCalendarSection() {
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         Container(
//           padding: const EdgeInsets.all(4),
//           decoration: BoxDecoration(
//             color: const Color(0xFFF1F5F9),
//             borderRadius: BorderRadius.circular(12),
//           ),
//           child: Row(
//             children: [
//               _tabButton('Recent Courses', 0),
//               _tabButton('Calendar & Timer', 1),
//             ],
//           ),
//         ),
//         const SizedBox(height: 16),
//         Row(
//           mainAxisAlignment: MainAxisAlignment.spaceBetween,
//           children: [
//             Text(
//               _selectedTab == 0 ? 'Recent Courses' : 'Calendar & Timer',
//               style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
//             ),
//             TextButton(
//               onPressed: () {},
//               child: const Text(
//                 'See all',
//                 style: TextStyle(color: Color(0xFF6366F1)),
//               ),
//             ),
//           ],
//         ),
//         const SizedBox(height: 12),
//         AnimatedSwitcher(
//           duration: const Duration(milliseconds: 300),
//           child: _selectedTab == 0
//               ? _buildRecentCourses()
//               : _buildCalendarTimer(),
//         ),
//       ],
//     );
//   }

//   Widget _tabButton(String text, int index) {
//     final isActive = _selectedTab == index;
//     return Expanded(
//       child: GestureDetector(
//         onTap: () => setState(() => _selectedTab = index),
//         child: AnimatedContainer(
//           duration: const Duration(milliseconds: 200),
//           padding: const EdgeInsets.symmetric(vertical: 10),
//           decoration: BoxDecoration(
//             color: isActive ? Colors.white : Colors.transparent,
//             borderRadius: BorderRadius.circular(10),
//             boxShadow: isActive
//                 ? [
//                     BoxShadow(
//                       color: Colors.black.withOpacity(0.1),
//                       blurRadius: 8,
//                       offset: const Offset(0, 2),
//                     ),
//                   ]
//                 : null,
//           ),
//           child: Text(
//             text,
//             textAlign: TextAlign.center,
//             style: TextStyle(
//               fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
//               color: isActive
//                   ? const Color(0xFF6366F1)
//                   : const Color(0xFF6B7280),
//               fontSize: 13,
//             ),
//           ),
//         ),
//       ),
//     );
//   }

//   // Widget _buildRecentCourses() {
//   //   final List<Map<String, dynamic>> courses = [
//   //     {'code': 'PHY 101', 'progress': '21/43', 'color': Colors.blue},
//   //     {'code': 'MTH 112', 'progress': '15/30', 'color': Colors.green},
//   //     {'code': 'CHM 101', 'progress': '28/40', 'color': Colors.orange},
//   //   ];

//   //   return Column(
//   //     key: const ValueKey(0),
//   //     children: courses
//   //         .map(
//   //           (course) => _courseCard(
//   //             course['code'] as String,
//   //             course['progress'] as String,
//   //             course['color'] as Color,
//   //           ),
//   //         )
//   //         .toList(),
//   //   );
//   // }

//   // Widget _courseCard(String code, String progress, Color color) {
//   //   return Card(
//   //     margin: const EdgeInsets.only(bottom: 12),
//   //     shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
//   //     elevation: 1,
//   //     child: ListTile(
//   //       leading: Container(
//   //         width: 44,
//   //         height: 44,
//   //         decoration: BoxDecoration(
//   //           color: color,
//   //           borderRadius: BorderRadius.circular(12),
//   //         ),
//   //         child: Center(
//   //           child: Text(
//   //             code.substring(0, 1),
//   //             style: const TextStyle(
//   //               color: Colors.white,
//   //               fontWeight: FontWeight.bold,
//   //               fontSize: 16,
//   //             ),
//   //           ),
//   //         ),
//   //       ),
//   //       title: Text(code, style: const TextStyle(fontWeight: FontWeight.w600)),
//   //       subtitle: Text('$progress topics completed'),
//   //       trailing: Container(
//   //         padding: const EdgeInsets.all(6),
//   //         decoration: BoxDecoration(
//   //           color: const Color(0xFF6366F1).withOpacity(0.1),
//   //           borderRadius: BorderRadius.circular(8),
//   //         ),
//   //         child: const Icon(
//   //           Icons.arrow_forward_ios_rounded,
//   //           size: 14,
//   //           color: Color(0xFF6366F1),
//   //         ),
//   //       ),
//   //       onTap: () => Navigator.pushNamed(context, '/course-detail'),
//   //     ),
//   //   );
//   // }

//   // REPLACE THIS ENTIRE METHOD:
//   Widget _buildRecentCourses() {
//     return Column(
//       key: const ValueKey(0),
//       children: [
//         if (_loadingRecentCourses)
//           _buildRecentCoursesLoading()
//         else if (_recentCourses.isEmpty)
//           _buildNoRecentCourses()
//         else
//           ..._recentCourses.asMap().entries.map((entry) {
//             final index = entry.key;
//             final course = entry.value;
//             final color = _getCourseColor(index);

//             return _courseCard(
//               course.code,
//               '${course.progress}% completed', // Show percentage
//               color,
//               course,
//             );
//           }).toList(),
//       ],
//     );
//   }

//   // ADD THESE HELPER METHODS:

//   Widget _buildRecentCoursesLoading() {
//     return Padding(
//       padding: const EdgeInsets.symmetric(vertical: 20),
//       child: Center(
//         child: Column(
//           children: [
//             CircularProgressIndicator(),
//             SizedBox(height: 10),
//             Text('Loading recent courses...'),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _buildNoRecentCourses() {
//     return Card(
//       margin: const EdgeInsets.only(bottom: 12),
//       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
//       elevation: 1,
//       child: ListTile(
//         leading: Container(
//           width: 44,
//           height: 44,
//           decoration: BoxDecoration(
//             color: Colors.grey.shade300,
//             borderRadius: BorderRadius.circular(12),
//           ),
//           child: Center(
//             child: Icon(Icons.menu_book, color: Colors.grey.shade600),
//           ),
//         ),
//         title: Text(
//           'No courses available',
//           style: TextStyle(fontWeight: FontWeight.w600),
//         ),
//         subtitle: Text('Start exploring courses from the Courses tab'),
//         trailing: Container(
//           padding: const EdgeInsets.all(6),
//           decoration: BoxDecoration(
//             color: const Color(0xFF6366F1).withOpacity(0.1),
//             borderRadius: BorderRadius.circular(8),
//           ),
//           child: Icon(
//             Icons.arrow_forward_ios_rounded,
//             size: 14,
//             color: Color(0xFF6366F1),
//           ),
//         ),
//         onTap: () => Navigator.pushNamed(context, '/courses'),
//       ),
//     );
//   }

//   // UPDATE THIS METHOD: Modified to accept Course object
//   Widget _courseCard(String code, String progress, Color color, Course course) {
//     return Card(
//       margin: const EdgeInsets.only(bottom: 12),
//       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
//       elevation: 1,
//       child: FutureBuilder<bool>(
//         future: _isCourseDownloaded(course.id),
//         builder: (context, snapshot) {
//           final isDownloaded = snapshot.data ?? false;

//           return ListTile(
//             leading: Container(
//               width: 44,
//               height: 44,
//               decoration: BoxDecoration(
//                 color: color,
//                 borderRadius: BorderRadius.circular(12),
//               ),
//               child: Center(
//                 child: Text(
//                   code.substring(0, 1),
//                   style: const TextStyle(
//                     color: Colors.white,
//                     fontWeight: FontWeight.bold,
//                     fontSize: 16,
//                   ),
//                 ),
//               ),
//             ),
//             title: Text(
//               code,
//               style: const TextStyle(fontWeight: FontWeight.w600),
//             ),
//             subtitle: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Text(progress),
//                 if (isDownloaded)
//                   Container(
//                     margin: EdgeInsets.only(top: 2),
//                     padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
//                     decoration: BoxDecoration(
//                       color: Colors.green.withOpacity(0.1),
//                       borderRadius: BorderRadius.circular(4),
//                     ),
//                     child: Text(
//                       'Offline',
//                       style: TextStyle(
//                         fontSize: 10,
//                         color: Colors.green.shade700,
//                         fontWeight: FontWeight.w500,
//                       ),
//                     ),
//                   ),
//               ],
//             ),
//             trailing: Container(
//               padding: const EdgeInsets.all(6),
//               decoration: BoxDecoration(
//                 color: const Color(0xFF6366F1).withOpacity(0.1),
//                 borderRadius: BorderRadius.circular(8),
//               ),
//               child: const Icon(
//                 Icons.arrow_forward_ios_rounded,
//                 size: 14,
//                 color: Color(0xFF6366F1),
//               ),
//             ),
//             onTap: () => _navigateToCourseDetails(course),
//           );
//         },
//       ),
//     );
//   }

//   // ADD THIS METHOD: Navigate to course details
//   void _navigateToCourseDetails(Course course) async {
//     // Save as recent course
//     if (_currentUserId != null) {
//       try {
//         final box = await Hive.openBox(recentCourseBox);
//         final userKey = 'recent_course_$_currentUserId';
//         await box.put(userKey, course.toJson());
//         print('✅ Home: Saved recent course: ${course.code}');
//       } catch (e) {
//         print('⚠️ Home: Error saving recent course: $e');
//       }
//     }

//     // Navigate to course details
//     Navigator.pushNamed(context, '/course-detail', arguments: course);
//   }

//   // UPDATED: Simple Calendar & Timer Section with "Feature Coming Soon" - keeping your design

//   Widget _buildCalendarTimer() {
//     return Card(
//       key: const ValueKey(1),
//       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
//       elevation: 2,
//       child: Container(
//         height: 200,
//         padding: const EdgeInsets.all(20),
//         child: Column(
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: [
//             Icon(
//               Icons.calendar_month_rounded,
//               size: 64,
//               color: Colors.grey.shade400,
//             ),
//             const SizedBox(height: 16),
//             const Text(
//               'Feature Coming Soon',
//               style: TextStyle(
//                 fontSize: 18,
//                 fontWeight: FontWeight.w600,
//                 color: Color(0xFF6B7280),
//               ),
//             ),
//             const SizedBox(height: 8),
//             Text(
//               'Calendar and timer features will be available soon',
//               style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
//               textAlign: TextAlign.center,
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _buildGeneralInfoSection() {
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         Row(
//           mainAxisAlignment: MainAxisAlignment.spaceBetween,
//           children: [
//             const Text(
//               'General Info',
//               style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
//             ),
//             TextButton(
//               onPressed: () => _showInfoBottomSheet(),
//               child: const Text(
//                 'See more',
//                 style: TextStyle(color: Color(0xFF6366F1)),
//               ),
//             ),
//           ],
//         ),
//         const SizedBox(height: 12),
//         ...List.generate(
//           3,
//           (index) => GeneralInfoCard(
//             imagePath: index == 2
//                 ? null
//                 : 'assets/images/info_${index == 0 ? 'updates' : 'tips'}.png',
//             fallbackIcon: Icons.event,
//             iconColor: const Color(0xFF6366F1),
//             title: ['Latest Updates', 'Study Tips', 'Webinar'][index],
//             subtitle: ['v2.1.0', 'Top 5', 'Tomorrow 3 PM'][index],
//             expandedContent: const [Text('Details...')],
//             onTap: () => _showInfoBottomSheet(),
//           ),
//         ),
//       ],
//     );
//   }

//   void _showInfoBottomSheet() {
//     showModalBottomSheet(
//       context: context,
//       isScrollControlled: true,
//       backgroundColor: Colors.transparent,
//       builder: (_) => DraggableScrollableSheet(
//         initialChildSize: 0.9,
//         builder: (_, controller) => Container(
//           decoration: const BoxDecoration(
//             color: Colors.white,
//             borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
//           ),
//           child: Column(
//             children: [
//               Container(
//                 margin: const EdgeInsets.all(12),
//                 width: 40,
//                 height: 4,
//                 decoration: BoxDecoration(
//                   color: Colors.grey[300],
//                   borderRadius: BorderRadius.circular(2),
//                 ),
//               ),
//               AppBar(
//                 title: const Text('General Info'),
//                 leading: const BackButton(),
//                 backgroundColor: Colors.transparent,
//                 elevation: 0,
//               ),
//               const Expanded(child: Center(child: Text('Full info here...'))),
//             ],
//           ),
//         ),
//       ),
//     );
//   }

//   Widget _buildStreakSection() {
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         Row(
//           mainAxisAlignment: MainAxisAlignment.spaceBetween,
//           children: [
//             const Text(
//               'Streak',
//               style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
//             ),
//             IconButton(
//               icon: const Icon(Icons.refresh_rounded, size: 20),
//               onPressed: _initializeStreakData,
//               color: const Color(0xFF6366F1),
//               tooltip: 'Refresh streak',
//             ),
//           ],
//         ),
//         const SizedBox(height: 12),
//         Card(
//           shape: RoundedRectangleBorder(
//             borderRadius: BorderRadius.circular(16),
//           ),
//           elevation: 1,
//           child: Padding(
//             padding: const EdgeInsets.all(20),
//             child: Row(
//               children: [
//                 Container(
//                   padding: const EdgeInsets.all(16),
//                   decoration: BoxDecoration(
//                     color: const Color(0xFFF59E0B).withOpacity(0.1),
//                     borderRadius: BorderRadius.circular(16),
//                   ),
//                   child: Icon(
//                     Icons.local_fire_department_rounded,
//                     color: _currentStreak > 0
//                         ? const Color(0xFFF59E0B)
//                         : Colors.grey,
//                     size: 36,
//                   ),
//                 ),
//                 const SizedBox(width: 16),
//                 Expanded(
//                   child: Column(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: [
//                       Text(
//                         '${_currentStreak}-Day Streak',
//                         style: const TextStyle(
//                           fontSize: 18,
//                           fontWeight: FontWeight.bold,
//                         ),
//                       ),
//                       Text(
//                         _isLoadingStreak
//                             ? 'Loading...'
//                             : (_currentStreak > 0
//                                   ? _getStreakMessage(_currentStreak)
//                                   : 'Open the app tomorrow to start your streak!'),
//                         style: const TextStyle(color: Color(0xFF6B7280)),
//                         maxLines: 2,
//                       ),
//                       if (_totalOpenedDays > 0 && !_isLoadingStreak)
//                         Padding(
//                           padding: const EdgeInsets.only(top: 4),
//                           child: Text(
//                             'Total: $_totalOpenedDays days • Longest: $_longestStreak days',
//                             style: const TextStyle(
//                               fontSize: 12,
//                               color: Color(0xFF9CA3AF),
//                             ),
//                           ),
//                         ),
//                     ],
//                   ),
//                 ),
//                 AnimatedSwitcher(
//                   duration: const Duration(milliseconds: 300),
//                   child: _isLoadingStreak
//                       ? const SizedBox(
//                           width: 40,
//                           height: 40,
//                           child: CircularProgressIndicator(
//                             strokeWidth: 3,
//                             valueColor: AlwaysStoppedAnimation<Color>(
//                               Color(0xFFF59E0B),
//                             ),
//                           ),
//                         )
//                       : Text(
//                           '$_currentStreak',
//                           key: ValueKey(_currentStreak),
//                           style: TextStyle(
//                             fontSize: 36,
//                             fontWeight: FontWeight.bold,
//                             color: _currentStreak > 0
//                                 ? const Color(0xFFF59E0B)
//                                 : Colors.grey,
//                           ),
//                         ),
//                 ),
//               ],
//             ),
//           ),
//         ),
//       ],
//     );
//   }

//   Widget _buildDraggableAIBot() {
//     return AnimatedPositioned(
//       duration: const Duration(milliseconds: 800),
//       curve: Curves.easeOutCubic,
//       left: _aiBotPositionX,
//       top: _aiBotPositionY,
//       child: GestureDetector(
//         onPanStart: (details) {
//           setState(() => _aiBotIsDragging = true);
//         },
//         onPanUpdate: (details) {
//           setState(() {
//             _aiBotPositionX += details.delta.dx;
//             _aiBotPositionY += details.delta.dy;

//             // Keep within screen bounds
//             final screenWidth = MediaQuery.of(context).size.width;
//             final screenHeight = MediaQuery.of(context).size.height;

//             _aiBotPositionX = _aiBotPositionX.clamp(
//               0.0,
//               screenWidth - _aiBotSize,
//             );
//             _aiBotPositionY = _aiBotPositionY.clamp(
//               0.0,
//               screenHeight - _aiBotSize - 100,
//             );
//           });
//         },
//         onPanEnd: (details) {
//           setState(() => _aiBotIsDragging = false);
//         },
//         onTap: () {
//           Navigator.pushNamed(context, '/ai-voice');
//         },
//         child: AnimatedBuilder(
//           animation: _pulseAnimation,
//           builder: (context, child) {
//             return Transform.scale(
//               scale: _aiBotIsDragging ? 1.1 : _pulseAnimation.value,
//               child: ClipOval(
//                 child: Image.asset(
//                   'assets/images/waveAI.gif',
//                   width: _aiBotSize,
//                   height: _aiBotSize,
//                   fit: BoxFit.cover,
//                   errorBuilder: (context, error, stackTrace) {
//                     return Container(
//                       width: _aiBotSize,
//                       height: _aiBotSize,
//                       decoration: const BoxDecoration(
//                         gradient: LinearGradient(
//                           begin: Alignment.topLeft,
//                           end: Alignment.bottomRight,
//                           colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
//                         ),
//                         shape: BoxShape.circle,
//                       ),
//                       child: const Icon(
//                         Icons.auto_awesome_rounded,
//                         color: Colors.white,
//                         size: 36,
//                       ),
//                     );
//                   },
//                 ),
//               ),
//             );
//           },
//         ),
//       ),
//     );
//   }
// }

// lib/features/home/screens/home_screen.dart
// Add this import at the top with other imports
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../widgets/advert_carousel.dart';
import '../widgets/general_info_card.dart';
import '../../../core/widgets/custom_app_bar.dart';
import '../../../core/widgets/custom_drawer.dart';
import '../../../core/constants/endpoints.dart';
import '../../../features/courses/models/course_models.dart';
import '../../../core/network/api_service.dart';
import '../../../features/info/screens/general_info_screen.dart'; // ADD THIS IMPORT
import '../../../features/popup/models/popup_advertisement.dart';
import '../../../features/popup/widgets/popup_advertisement_widget.dart';
import '../../../features/popup/services/popup_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  // AI Bot Draggable Variables - Start hidden to the right
  double _aiBotPositionX = 350;
  double _aiBotPositionY = 300;
  bool _aiBotIsDragging = false;
  final double _aiBotSize = 90;

  // Toggle: Recent / Calendar
  int _selectedTab = 0;

  // Streak tracking variables
  int _currentStreak = 0;
  int _longestStreak = 0;
  int _totalOpenedDays = 0;
  bool _isLoadingStreak = true;

  // Course fields
  List<Course> _recentCourses = [];
  bool _loadingRecentCourses = false;
  String? _currentUserId;
  static const String recentCourseBox = 'recent_course';
  static const String offlineCoursesBox = 'offline_courses';

  // ADD THESE: Information items fields
  List<InformationItem> _recentInfoItems = [];
  bool _loadingRecentInfo = false;

  // Add these variables
  PopupAdvertisement? _currentPopup;
  bool _showPopup = false;
  bool _checkingPopup = false;
  final PopupService _popupService = PopupService();

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Show AI bot after a brief delay
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _animateAIBotToPosition();
    });

    // Load streak data
    _initializeStreakData();

    // Load recent courses
    _loadRecentCourses();

    // ADD THIS: Load recent information items
    _loadRecentInformationItems();

    // ADD THIS: Check for popup after a delay
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndShowPopup();
    });
  }

  // ###################### ADDING POPUPS #######################
  // ADD THIS METHOD: Check and show popup
  // In your home_screen.dart
  Future<void> _checkAndShowPopup() async {
    if (_checkingPopup) return;

    _checkingPopup = true;

    print('🔍 Starting popup check...');

    try {
      // Get user ID
      await _getCurrentUserId();
      print('👤 Current user ID: $_currentUserId');

      if (_currentUserId != null) {
        // Record session start
        print('📱 Recording session start...');
        await _popupService.recordSessionStart(int.tryParse(_currentUserId!));

        // Get popup for user
        print('🌐 Getting popup for user ID: $_currentUserId');
        final popup = await _popupService.getPopupForUser(
          int.tryParse(_currentUserId!),
        );

        if (popup != null) {
          print('🎯 Found popup: ${popup.title}');
          print('   - ID: ${popup.id}');
          print('   - Show delay: ${popup.showDelay}s');
          print('   - Display frequency: ${popup.displayFrequency}');

          // Check if we should show based on frequency
          final shouldShow = await _popupService.shouldShowPopup(
            popup,
            int.tryParse(_currentUserId!),
          );

          print('📊 Should show popup? $shouldShow');

          if (shouldShow) {
            setState(() {
              _currentPopup = popup;
            });

            print('⏰ Showing popup after ${popup.showDelay} seconds delay');

            // Show after delay
            Future.delayed(Duration(seconds: popup.showDelay), () {
              if (mounted) {
                setState(() {
                  _showPopup = true;
                });
                print('🎉 Popup is now visible!');
              }
            });
          } else {
            print('⏸️ Popup not shown due to frequency settings');
          }
        } else {
          print('ℹ️ No popup returned from server');
        }
      } else {
        print('⚠️ No user ID available for popup check');
      }
    } catch (e) {
      print('❌ Error checking popup: $e');
      print('Stack trace: ${e.toString()}');
    } finally {
      _checkingPopup = false;
      print('✅ Popup check completed');
    }
  }

  // ADD THIS METHOD: Close popup
  void _closePopup() {
    setState(() {
      _showPopup = false;
    });

    // Record that popup was shown
    if (_currentPopup != null && _currentUserId != null) {
      _popupService.recordPopupShown(
        _currentPopup!,
        int.tryParse(_currentUserId!),
      );
    }
  }
  // ###################### POPUP ENDS #########################

  void _animateAIBotToPosition() {
    setState(() {
      _aiBotPositionX =
          MediaQuery.of(context).size.width * 0.75 - _aiBotSize / 2;
      _aiBotPositionY =
          MediaQuery.of(context).size.height * 0.7 - _aiBotSize / 2;
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _initializeStreakData() async {
    await _recordAppOpen();
    await _loadStreakData();
  }

  Future<void> _refreshRecentCourses() async {
    await _loadRecentCourses();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _refreshRecentCourses();
  }

  // ADD THIS METHOD: Load recent information items
  Future<void> _loadRecentInformationItems() async {
    if (_loadingRecentInfo) return;

    setState(() {
      _loadingRecentInfo = true;
    });

    try {
      // Get user ID first
      await _getCurrentUserId();

      if (_currentUserId == null) {
        print('⚠️ Home: No user ID, cannot load information items');
        return;
      }

      // Build URL with user_id
      String url = '${ApiEndpoints.informationItems}?user_id=$_currentUserId';
      print('🌐 Home: Loading recent info from: $url');

      // Get auth token
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      // Prepare headers
      final headers = <String, String>{'Content-Type': 'application/json'};
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Token $token';
      }

      // Make request
      final response = await http
          .get(Uri.parse(url), headers: headers)
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        List<InformationItem> loadedItems = [];

        // Parse response based on format
        if (responseData is List) {
          loadedItems = responseData
              .map((item) => InformationItem.fromJson(item))
              .toList();
        } else if (responseData is Map) {
          if (responseData.containsKey('items') &&
              responseData['items'] is List) {
            loadedItems = (responseData['items'] as List)
                .map((item) => InformationItem.fromJson(item))
                .toList();
          } else if (responseData.containsKey('results') &&
              responseData['results'] is List) {
            loadedItems = (responseData['results'] as List)
                .map((item) => InformationItem.fromJson(item))
                .toList();
          } else if (responseData.containsKey('data') &&
              responseData['data'] is List) {
            loadedItems = (responseData['data'] as List)
                .map((item) => InformationItem.fromJson(item))
                .toList();
          }
        }

        // Sort by date (most recent first) and take first 3
        loadedItems.sort((a, b) {
          // Simple string comparison - you might want to parse dates properly
          return b.date.compareTo(a.date);
        });

        // Take first 3 items
        final recentItems = loadedItems.take(3).toList();

        // Load read status
        final prefs = await SharedPreferences.getInstance();
        for (var item in recentItems) {
          item.isRead = prefs.getBool('read_${item.id}') ?? false;
        }

        setState(() {
          _recentInfoItems = recentItems;
        });

        print(
          '✅ Home: Loaded ${_recentInfoItems.length} recent information items',
        );
      } else {
        print(
          '⚠️ Home: Failed to load information items: ${response.statusCode}',
        );
      }
    } catch (e) {
      print('❌ Home: Error loading information items: $e');
    } finally {
      setState(() {
        _loadingRecentInfo = false;
      });
    }
  }

  // ADD THIS METHOD: Navigate to information detail
  void _navigateToInfoDetail(InformationItem item) async {
    // Mark as read
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('read_${item.id}', true);

    // Update local state
    setState(() {
      for (var infoItem in _recentInfoItems) {
        if (infoItem.id == item.id) {
          infoItem.isRead = true;
        }
      }
    });

    // Navigate to detail screen
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => InfoDetailScreen(infoItem: item)),
    );
  }

  // Helper method to get appropriate icon for info type
  IconData _getInfoIcon(InformationItem item) {
    if (item.requiresActivation) return Icons.lock;
    if (item.isTargeted) return Icons.school;
    if (item.isFeatured) return Icons.star;
    return Icons.info;
  }

  // Helper method to get appropriate color for info type
  Color _getInfoColor(InformationItem item) {
    if (item.requiresActivation) return Colors.orange;
    if (item.isTargeted) return Colors.purple;
    if (item.isFeatured) return Colors.amber;
    return const Color(0xFF6366F1);
  }

  // Helper method to get appropriate subtitle
  String _getInfoSubtitle(InformationItem item) {
    if (item.requiresActivation) return 'Activation Required';
    if (item.isTargeted) return 'Targeted Information';
    return item.category;
  }

  // Existing methods remain the same until the _buildGeneralInfoSection method
  Future<void> _getCurrentUserId() async {
    try {
      final box = await Hive.openBox('user_box');
      final userData = box.get('current_user');
      if (userData != null) {
        _currentUserId = userData['id'].toString();
        print('👤 Home: Got user ID: $_currentUserId');
      }
    } catch (e) {
      print('⚠️ Home: Error getting user ID: $e');
    }
  }

  Future<void> _loadRecentCourses() async {
    if (_loadingRecentCourses) return;

    setState(() {
      _loadingRecentCourses = true;
    });

    try {
      await _getCurrentUserId();

      if (_currentUserId == null) {
        print('⚠️ Home: No user ID, cannot load recent courses');
        return;
      }

      // Get the most recent course from storage
      final box = await Hive.openBox(recentCourseBox);
      final userKey = 'recent_course_$_currentUserId';
      final recentData = box.get(userKey);

      if (recentData != null) {
        Course? recentCourse;

        // Handle different data types
        if (recentData is Map) {
          try {
            final Map<String, dynamic> jsonData = {};
            recentData.forEach((key, value) {
              if (key is String) {
                jsonData[key] = value;
              } else if (key is int || key is double) {
                jsonData[key.toString()] = value;
              }
            });
            recentCourse = Course.fromJson(jsonData);
          } catch (e) {
            print('❌ Home: Error parsing recent course: $e');
          }
        } else if (recentData is Course) {
          recentCourse = recentData;
        }

        if (recentCourse != null) {
          // Get all courses to find 3 most recent
          final allCourses = await _getAllUserCourses();

          // Sort by most recent (put the single recent course first)
          List<Course> recentCoursesList = [];

          // Add the most recent course
          recentCoursesList.add(recentCourse);

          // Add up to 2 more courses (excluding the already added one)
          int addedCount = 0;
          for (var course in allCourses) {
            if (course.id != recentCourse.id && addedCount < 2) {
              recentCoursesList.add(course);
              addedCount++;
            }
            if (recentCoursesList.length >= 3) break;
          }

          // Load progress for each course
          await _loadRecentCoursesProgress(recentCoursesList);

          setState(() {
            _recentCourses = recentCoursesList;
          });

          print('✅ Home: Loaded ${_recentCourses.length} recent courses');
        }
      } else {
        print('ℹ️ Home: No recent course found, loading first 3 courses');

        // If no recent course, just show first 3 courses
        final allCourses = await _getAllUserCourses();
        final firstThreeCourses = allCourses.take(3).toList();

        await _loadRecentCoursesProgress(firstThreeCourses);

        setState(() {
          _recentCourses = firstThreeCourses;
        });
      }
    } catch (e) {
      print('❌ Home: Error loading recent courses: $e');
      setState(() {
        _recentCourses = [];
      });
    } finally {
      setState(() {
        _loadingRecentCourses = false;
      });
    }
  }

  Future<List<Course>> _getAllUserCourses() async {
    try {
      final courses = await ApiService().getCoursesForUser();
      return courses;
    } catch (e) {
      print('⚠️ Home: Error getting all courses: $e');
      return [];
    }
  }

  Future<void> _loadRecentCoursesProgress(List<Course> courses) async {
    try {
      for (var course in courses) {
        try {
          final topics = await ApiService().getTopics(
            courseId: int.parse(course.id),
          );

          if (topics.isNotEmpty) {
            int completedCount = 0;
            for (var topic in topics) {
              if (topic.isCompleted) {
                completedCount++;
              }
            }

            final progress = topics.isNotEmpty
                ? ((completedCount / topics.length) * 100).round()
                : 0;

            course.progress = progress;
          } else {
            course.progress = 0;
          }
        } catch (e) {
          course.progress = 0;
        }
      }
    } catch (e) {
      print('⚠️ Home: Error loading recent courses progress: $e');
    }
  }

  Future<bool> _isCourseDownloaded(String courseId) async {
    try {
      final box = await Hive.openBox(offlineCoursesBox);
      final downloadedCourseIds = box.get(
        'downloaded_course_ids',
        defaultValue: <String>[],
      );
      return downloadedCourseIds.contains(courseId);
    } catch (e) {
      return false;
    }
  }

  Color _getCourseColor(int index) {
    final colors = [Colors.blue, Colors.green, Colors.orange];
    return colors[index % colors.length];
  }

  Future<void> _recordAppOpen() async {
    try {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      // Open or create the streak box
      final streakBox = await Hive.openBox('app_streak_tracking');

      // Check if we already recorded today's open
      final lastRecordedDate = streakBox.get('last_recorded_date');
      if (lastRecordedDate != null) {
        final lastDate = DateTime.parse(lastRecordedDate);
        // If we already recorded today, don't record again
        if (lastDate.isAtSameMomentAs(today)) {
          return;
        }
      }

      // Record today's open
      final dateKey = today.toIso8601String();
      streakBox.put(dateKey, true);
      streakBox.put('last_recorded_date', dateKey);

      print('📱 Home: Recorded app open for streak: $dateKey');
    } catch (e) {
      print('⚠️ Home: Error recording app open: $e');
    }
  }

  Future<void> _loadStreakData() async {
    try {
      final streakBox = await Hive.openBox('app_streak_tracking');
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      // Get all recorded dates
      final allKeys = streakBox.keys.toList();
      List<DateTime> openedDates = [];

      for (var key in allKeys) {
        if (key != 'last_recorded_date' && streakBox.get(key) == true) {
          try {
            final date = DateTime.parse(key);
            openedDates.add(date);
          } catch (e) {
            print('⚠️ Home: Error parsing date $key: $e');
          }
        }
      }

      // Sort dates
      openedDates.sort((a, b) => a.compareTo(b));

      // Calculate streaks
      int currentStreak = 0;
      int longestStreak = 0;
      int tempStreak = 0;

      // Check current streak (consecutive days up to today)
      DateTime checkDate = today;
      while (openedDates.any(
        (date) =>
            date.year == checkDate.year &&
            date.month == checkDate.month &&
            date.day == checkDate.day,
      )) {
        currentStreak++;
        checkDate = checkDate.subtract(const Duration(days: 1));
      }

      // Calculate longest streak
      if (openedDates.isNotEmpty) {
        tempStreak = 1;
        for (int i = 1; i < openedDates.length; i++) {
          final prevDate = openedDates[i - 1];
          final currDate = openedDates[i];
          final difference = currDate.difference(prevDate).inDays;

          if (difference == 1) {
            tempStreak++;
          } else {
            if (tempStreak > longestStreak) {
              longestStreak = tempStreak;
            }
            tempStreak = 1;
          }
        }

        // Check last streak
        if (tempStreak > longestStreak) {
          longestStreak = tempStreak;
        }
      }

      setState(() {
        _currentStreak = currentStreak;
        _longestStreak = longestStreak;
        _totalOpenedDays = openedDates.length;
        _isLoadingStreak = false;
      });

      print('📊 Home: Streak data loaded:');
      print('   Current streak: $currentStreak days');
      print('   Longest streak: $longestStreak days');
      print('   Total days opened: ${openedDates.length}');
    } catch (e) {
      print('⚠️ Home: Error loading streak data: $e');
      setState(() {
        _currentStreak = 0;
        _longestStreak = 0;
        _totalOpenedDays = 0;
        _isLoadingStreak = false;
      });
    }
  }

  String _getStreakMessage(int streak) {
    if (streak >= 30) return 'Legendary consistency! 🏆';
    if (streak >= 14) return 'Great commitment!';
    if (streak >= 7) return 'Building strong habits!';
    if (streak >= 3) return 'Keep the momentum going!';
    return 'Consistency is key to mastery.';
  }

  // Get user data from Hive
  Map<String, dynamic>? _getUserData() {
    try {
      final box = Hive.box('user_box');
      final userData = box.get('current_user');
      return userData != null ? Map<String, dynamic>.from(userData) : null;
    } catch (e) {
      return null;
    }
  }

  // Get user name
  String _getUserName() {
    final userData = _getUserData();
    return userData?['name']?.toString() ?? 'Student';
  }

  // Get profile image URL
  String _getProfileImageUrl() {
    try {
      final userData = _getUserData();
      if (userData == null) return '';

      final avatarUrl = userData['avatar']?.toString() ?? '';
      if (avatarUrl.isEmpty) return '';

      if (avatarUrl.startsWith('http')) return avatarUrl;

      // Handle relative URLs using ApiEndpoints.baseUrl
      return avatarUrl.startsWith('/')
          ? '${ApiEndpoints.baseUrl}$avatarUrl'
          : '${ApiEndpoints.baseUrl}/$avatarUrl';
    } catch (e) {
      return '';
    }
  }

  void _showPastQuestionsBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildPastQuestionsSheet(),
    );
  }

  Widget _buildPastQuestionsSheet() {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(32),
          topRight: Radius.circular(32),
        ),
      ),
      child: Column(
        children: [
          // Drag Handle
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Study Materials',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1A1A2E),
                  ),
                ),
                IconButton(
                  icon: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.close_rounded, size: 20),
                  ),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // Vertical List (No Grid to avoid overflow)
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Column(
                children: [
                  _buildStudyOption(
                    icon: Icons.history_edu_rounded,
                    title: 'Past Questions',
                    subtitle: 'Previous exam papers and solutions',
                    color: const Color(0xFF6366F1),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.pushNamed(context, '/past-questions');
                    },
                  ),
                  const SizedBox(height: 12),
                  _buildStudyOption(
                    icon: Icons.quiz_rounded,
                    title: 'Test Questions',
                    subtitle: 'Practice tests and quizzes',
                    color: const Color(0xFF10B981),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.pushNamed(context, '/test-questions');
                    },
                  ),
                  const SizedBox(height: 12),
                  _buildStudyOption(
                    icon: Icons.computer_rounded,
                    title: 'CBT Practice',
                    subtitle: 'Computer based test simulations',
                    color: const Color(0xFFF59E0B),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.pushNamed(context, '/cbt-questions');
                    },
                  ),
                  const SizedBox(height: 12),
                  _buildStudyOption(
                    icon: Icons.library_books_rounded,
                    title: 'Study Guides',
                    subtitle: 'Comprehensive study materials',
                    color: const Color(0xFFEF4444),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.pushNamed(context, '/study-guide');
                    },
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStudyOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      borderRadius: BorderRadius.circular(16),
      color: Colors.white,
      elevation: 1,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade100),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1A1A2E),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios_rounded,
                size: 16,
                color: Colors.grey,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: CustomAppBar(
        scaffoldKey: _scaffoldKey,
        title: 'Cerenix',
        showNotifications: false,
        showProfile: false,
      ),
      drawer: const CustomDrawer(),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildWelcomeSection(),
                const SizedBox(height: 20),
                const AdvertCarousel(height: 140),
                const SizedBox(height: 24),
                _buildFeatureGrid(),
                const SizedBox(height: 28),
                _buildRecentOrCalendarSection(),
                const SizedBox(height: 28),
                _buildGeneralInfoSection(), // This will now show real info items
                const SizedBox(height: 28),
                _buildStreakSection(),
                const SizedBox(height: 100),
              ],
            ),
          ),
          _buildDraggableAIBot(),

          // ADD THIS: Popup overlay
          if (_showPopup && _currentPopup != null)
            PopupAdvertisementWidget(
              popup: _currentPopup!,
              userId: int.tryParse(_currentUserId ?? ''),
              onClose: _closePopup,
            ),
        ],
      ),
    );
  }

  Widget _buildWelcomeSection() {
    final profileImageUrl = _getProfileImageUrl();
    final userName = _getUserName();

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Hello, $userName',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF1A1A2E),
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Ready to dive into knowledge?',
                style: TextStyle(color: Color(0xFF6B7280), fontSize: 14),
              ),
            ],
          ),
        ),
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFF6366F1), width: 2),
          ),
          child: profileImageUrl.isNotEmpty
              ? CircleAvatar(
                  radius: 24,
                  backgroundImage: NetworkImage(profileImageUrl),
                  onBackgroundImageError: (exception, stackTrace) {},
                  child: profileImageUrl.isEmpty
                      ? const Icon(
                          Icons.person_rounded,
                          color: Color(0xFF6366F1),
                          size: 24,
                        )
                      : null,
                )
              : CircleAvatar(
                  radius: 24,
                  backgroundColor: const Color(0xFF6366F1).withOpacity(0.1),
                  child: const Icon(
                    Icons.person_rounded,
                    color: Color(0xFF6366F1),
                    size: 24,
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildFeatureGrid() {
    final List<Map<String, dynamic>> features = [
      {
        'title': 'Courses',
        'image': 'assets/images/course.png',
        'route': '/courses',
        'color': const Color(0xFF6366F1),
      },
      {
        'title': 'Past Questions',
        'image': 'assets/images/pastQuestions.png',
        'route': '/past-questions',
        'color': const Color(0xFF10B981),
      },
      {
        'title': 'CGPA Calc',
        'image': 'assets/images/CGPA.png',
        'route': '/cgpa',
        'color': const Color(0xFFF59E0B),
      },
      {
        'title': 'Activate App',
        'image': 'assets/images/activate.png',
        'route': '/activate',
        'color': const Color(0xFFEF4444),
      },
      {
        'title': 'Scan Doc',
        'image': 'assets/images/scan.png',
        'route': '/coming-soon',
        'color': const Color(0xFF8B5CF6),
      },
      {
        'title': 'AI Board',
        'image': 'assets/images/aiBoard.png',
        'route': '/ai-board',
        'color': const Color(0xFFEC4899),
      },
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 1.0,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: features.length,
      itemBuilder: (context, index) {
        final feature = features[index];
        return _buildFeatureCard(feature);
      },
    );
  }

  Widget _buildFeatureCard(Map<String, dynamic> feature) {
    return Material(
      borderRadius: BorderRadius.circular(16),
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          if (feature['title'] == 'Past Questions') {
            _showPastQuestionsBottomSheet();
          } else {
            Navigator.pushNamed(context, feature['route']);
          }
        },
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: (feature['color'] as Color).withOpacity(0.15),
                ),
                child: Center(
                  child: Image.asset(
                    feature['image'],
                    width: 36,
                    height: 36,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return Icon(
                        Icons.auto_awesome_rounded,
                        color: feature['color'] as Color,
                        size: 28,
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                feature['title'],
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1A1A2E),
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecentOrCalendarSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              _tabButton('Recent Courses', 0),
              _tabButton('Calendar & Timer', 1),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _selectedTab == 0 ? 'Recent Courses' : 'Calendar & Timer',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            TextButton(
              onPressed: () {},
              child: const Text(
                'See all',
                style: TextStyle(color: Color(0xFF6366F1)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: _selectedTab == 0
              ? _buildRecentCourses()
              : _buildCalendarTimer(),
        ),
      ],
    );
  }

  Widget _tabButton(String text, int index) {
    final isActive = _selectedTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedTab = index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isActive ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
              color: isActive
                  ? const Color(0xFF6366F1)
                  : const Color(0xFF6B7280),
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRecentCourses() {
    return Column(
      key: const ValueKey(0),
      children: [
        if (_loadingRecentCourses)
          _buildRecentCoursesLoading()
        else if (_recentCourses.isEmpty)
          _buildNoRecentCourses()
        else
          ..._recentCourses.asMap().entries.map((entry) {
            final index = entry.key;
            final course = entry.value;
            final color = _getCourseColor(index);

            return _courseCard(
              course.code,
              '${course.progress}% completed',
              color,
              course,
            );
          }).toList(),
      ],
    );
  }

  Widget _buildRecentCoursesLoading() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Center(
        child: Column(
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 10),
            Text('Loading recent courses...'),
          ],
        ),
      ),
    );
  }

  Widget _buildNoRecentCourses() {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 1,
      child: ListTile(
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: Colors.grey.shade300,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Icon(Icons.menu_book, color: Colors.grey.shade600),
          ),
        ),
        title: Text(
          'No courses available',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text('Start exploring courses from the Courses tab'),
        trailing: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: const Color(0xFF6366F1).withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            Icons.arrow_forward_ios_rounded,
            size: 14,
            color: Color(0xFF6366F1),
          ),
        ),
        onTap: () => Navigator.pushNamed(context, '/courses'),
      ),
    );
  }

  Widget _courseCard(String code, String progress, Color color, Course course) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 1,
      child: FutureBuilder<bool>(
        future: _isCourseDownloaded(course.id),
        builder: (context, snapshot) {
          final isDownloaded = snapshot.data ?? false;

          return ListTile(
            leading: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  code.substring(0, 1),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
            title: Text(
              code,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(progress),
                if (isDownloaded)
                  Container(
                    margin: EdgeInsets.only(top: 2),
                    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'Offline',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.green.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
              ],
            ),
            trailing: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFF6366F1).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.arrow_forward_ios_rounded,
                size: 14,
                color: Color(0xFF6366F1),
              ),
            ),
            onTap: () => _navigateToCourseDetails(course),
          );
        },
      ),
    );
  }

  void _navigateToCourseDetails(Course course) async {
    if (_currentUserId != null) {
      try {
        final box = await Hive.openBox(recentCourseBox);
        final userKey = 'recent_course_$_currentUserId';
        await box.put(userKey, course.toJson());
        print('✅ Home: Saved recent course: ${course.code}');
      } catch (e) {
        print('⚠️ Home: Error saving recent course: $e');
      }
    }

    Navigator.pushNamed(context, '/course-detail', arguments: course);
  }

  Widget _buildCalendarTimer() {
    return Card(
      key: const ValueKey(1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 2,
      child: Container(
        height: 200,
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.calendar_month_rounded,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            const Text(
              'Feature Coming Soon',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Color(0xFF6B7280),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Calendar and timer features will be available soon',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // UPDATED: _buildGeneralInfoSection to show real information items
  Widget _buildGeneralInfoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'General Info',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            TextButton(
              onPressed: () {
                // Navigate to full information screen
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => GeneralInfoScreen()),
                );
              },
              child: const Text(
                'See more',
                style: TextStyle(color: Color(0xFF6366F1)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        if (_loadingRecentInfo)
          _buildInfoLoading()
        else if (_recentInfoItems.isEmpty)
          _buildNoInfoItems()
        else
          ..._recentInfoItems.map((item) => _buildInfoCard(item)).toList(),
      ],
    );
  }

  Widget _buildInfoLoading() {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 1,
      child: ListTile(
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: Colors.grey.shade300,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Color(0xFF6366F1),
            ),
          ),
        ),
        title: Text('Loading information...'),
        subtitle: Text('Fetching latest updates'),
      ),
    );
  }

  Widget _buildNoInfoItems() {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 1,
      child: ListTile(
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: Colors.grey.shade300,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Icon(Icons.info_outline, color: Colors.grey.shade600),
          ),
        ),
        title: Text(
          'No information available',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text('Check back later for updates'),
        trailing: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: const Color(0xFF6366F1).withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            Icons.arrow_forward_ios_rounded,
            size: 14,
            color: Color(0xFF6366F1),
          ),
        ),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => GeneralInfoScreen()),
          );
        },
      ),
    );
  }

  Widget _buildInfoCard(InformationItem item) {
    final iconColor = _getInfoColor(item);
    final icon = _getInfoIcon(item);
    final subtitle = _getInfoSubtitle(item);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 1,
      child: ListTile(
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(child: Icon(icon, color: iconColor, size: 20)),
        ),
        title: Text(
          item.title,
          style: TextStyle(
            fontWeight: item.isRead ? FontWeight.w500 : FontWeight.w700,
            color: item.isRead ? Colors.black54 : Colors.black87,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              subtitle,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            SizedBox(height: 2),
            Text(
              item.date,
              style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
            ),
          ],
        ),
        trailing: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: const Color(0xFF6366F1).withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            Icons.arrow_forward_ios_rounded,
            size: 14,
            color: Color(0xFF6366F1),
          ),
        ),
        onTap: () => _navigateToInfoDetail(item),
      ),
    );
  }

  Widget _buildStreakSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Streak',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            IconButton(
              icon: const Icon(Icons.refresh_rounded, size: 20),
              onPressed: _initializeStreakData,
              color: const Color(0xFF6366F1),
              tooltip: 'Refresh streak',
            ),
          ],
        ),
        const SizedBox(height: 12),
        Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 1,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF59E0B).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    Icons.local_fire_department_rounded,
                    color: _currentStreak > 0
                        ? const Color(0xFFF59E0B)
                        : Colors.grey,
                    size: 36,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${_currentStreak}-Day Streak',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        _isLoadingStreak
                            ? 'Loading...'
                            : (_currentStreak > 0
                                  ? _getStreakMessage(_currentStreak)
                                  : 'Open the app tomorrow to start your streak!'),
                        style: const TextStyle(color: Color(0xFF6B7280)),
                        maxLines: 2,
                      ),
                      if (_totalOpenedDays > 0 && !_isLoadingStreak)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            'Total: $_totalOpenedDays days • Longest: $_longestStreak days',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF9CA3AF),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: _isLoadingStreak
                      ? const SizedBox(
                          width: 40,
                          height: 40,
                          child: CircularProgressIndicator(
                            strokeWidth: 3,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Color(0xFFF59E0B),
                            ),
                          ),
                        )
                      : Text(
                          '$_currentStreak',
                          key: ValueKey(_currentStreak),
                          style: TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.bold,
                            color: _currentStreak > 0
                                ? const Color(0xFFF59E0B)
                                : Colors.grey,
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDraggableAIBot() {
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeOutCubic,
      left: _aiBotPositionX,
      top: _aiBotPositionY,
      child: GestureDetector(
        onPanStart: (details) {
          setState(() => _aiBotIsDragging = true);
        },
        onPanUpdate: (details) {
          setState(() {
            _aiBotPositionX += details.delta.dx;
            _aiBotPositionY += details.delta.dy;

            // Keep within screen bounds
            final screenWidth = MediaQuery.of(context).size.width;
            final screenHeight = MediaQuery.of(context).size.height;

            _aiBotPositionX = _aiBotPositionX.clamp(
              0.0,
              screenWidth - _aiBotSize,
            );
            _aiBotPositionY = _aiBotPositionY.clamp(
              0.0,
              screenHeight - _aiBotSize - 100,
            );
          });
        },
        onPanEnd: (details) {
          setState(() => _aiBotIsDragging = false);
        },
        onTap: () {
          Navigator.pushNamed(context, '/ai-voice');
        },
        child: AnimatedBuilder(
          animation: _pulseAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: _aiBotIsDragging ? 1.1 : _pulseAnimation.value,
              child: ClipOval(
                child: Image.asset(
                  'assets/images/waveAI.gif',
                  width: _aiBotSize,
                  height: _aiBotSize,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      width: _aiBotSize,
                      height: _aiBotSize,
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.auto_awesome_rounded,
                        color: Colors.white,
                        size: 36,
                      ),
                    );
                  },
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
