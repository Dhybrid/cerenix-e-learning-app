// lib/features/home/screens/home_screen.dart
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../widgets/advert_carousel.dart';
import '../widgets/general_info_card.dart';
import '../../../core/widgets/custom_app_bar.dart';
import '../../../core/widgets/custom_drawer.dart';   
import '../../../core/constants/endpoints.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;
  
  // AI Bot Draggable Variables - Start hidden to the right
  double _aiBotPositionX = 350; // Start hidden off-screen to the right
  double _aiBotPositionY = 300; // Position closer to middle-bottom
  bool _aiBotIsDragging = false;
  final double _aiBotSize = 90;

  // Toggle: Recent / Calendar
  int _selectedTab = 0;

  // Streak tracking variables
  int _currentStreak = 0;
  int _longestStreak = 0;
  int _totalOpenedDays = 0;
  bool _isLoadingStreak = true;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this, 
      duration: const Duration(milliseconds: 1500)
    )..repeat(reverse: true);
    
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut)
    );

    // Show AI bot after a brief delay
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _animateAIBotToPosition();
    });

    // Load streak data
    _initializeStreakData();
  }

  void _animateAIBotToPosition() {
    setState(() {
      // Move to quarter of screen width, near bottom right but not exactly corner
      _aiBotPositionX = MediaQuery.of(context).size.width * 0.75 - _aiBotSize / 2;
      _aiBotPositionY = MediaQuery.of(context).size.height * 0.7 - _aiBotSize / 2;
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

  // Streak tracking functions
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
      while (openedDates.any((date) => 
          date.year == checkDate.year && 
          date.month == checkDate.month && 
          date.day == checkDate.day)) {
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

  // Get profile image URL - USING ApiEndpoints.baseUrl
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
              const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Colors.grey),
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
        showNotifications: true,
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
                _buildGeneralInfoSection(),
                const SizedBox(height: 28),
                _buildStreakSection(),
                const SizedBox(height: 100),
              ],
            ),
          ),
          _buildDraggableAIBot(),
        ],
      ),
    );
  }

  // UPDATED: Welcome section with actual user profile picture and name - NO CLICK ACTION
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
                  color: const Color(0xFF1A1A2E)
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
        // Profile picture with NO click action - exactly as in your original design
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
                  onBackgroundImageError: (exception, stackTrace) {
                    // Fallback to icon if image fails to load
                  },
                  child: profileImageUrl.isEmpty 
                      ? const Icon(Icons.person_rounded, color: Color(0xFF6366F1), size: 24)
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
        'route': '/scanner',
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
            borderRadius: BorderRadius.circular(12)
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
              child: const Text('See all', style: TextStyle(color: Color(0xFF6366F1)))
            ),
          ],
        ),
        const SizedBox(height: 12),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: _selectedTab == 0 ? _buildRecentCourses() : _buildCalendarTimer(),
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
            boxShadow: isActive ? [
              BoxShadow(
                color: Colors.black.withOpacity(0.1), 
                blurRadius: 8,
                offset: const Offset(0, 2),
              )
            ] : null,
          ),
          child: Text(
            text, 
            textAlign: TextAlign.center, 
            style: TextStyle(
              fontWeight: isActive ? FontWeight.w600 : FontWeight.normal, 
              color: isActive ? const Color(0xFF6366F1) : const Color(0xFF6B7280),
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRecentCourses() {
    final List<Map<String, dynamic>> courses = [
      {'code': 'PHY 101', 'progress': '21/43', 'color': Colors.blue},
      {'code': 'MTH 112', 'progress': '15/30', 'color': Colors.green},
      {'code': 'CHM 101', 'progress': '28/40', 'color': Colors.orange},
    ];

    return Column(
      key: const ValueKey(0),
      children: courses.map((course) => _courseCard(
        course['code'] as String,
        course['progress'] as String,
        course['color'] as Color,
      )).toList(),
    );
  }

  Widget _courseCard(String code, String progress, Color color) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 1,
      child: ListTile(
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
        subtitle: Text('$progress topics completed'),
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
        onTap: () => Navigator.pushNamed(context, '/course-detail'),
      ),
    );
  }

  // UPDATED: Simple Calendar & Timer Section with "Feature Coming Soon" - keeping your design
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
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

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
              onPressed: () => _showInfoBottomSheet(), 
              child: const Text('See more', style: TextStyle(color: Color(0xFF6366F1)))
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...List.generate(3, (index) => GeneralInfoCard(
          imagePath: index == 2 ? null : 'assets/images/info_${index == 0 ? 'updates' : 'tips'}.png',
          fallbackIcon: Icons.event,
          iconColor: const Color(0xFF6366F1),
          title: ['Latest Updates', 'Study Tips', 'Webinar'][index],
          subtitle: ['v2.1.0', 'Top 5', 'Tomorrow 3 PM'][index],
          expandedContent: const [Text('Details...')],
          onTap: () => _showInfoBottomSheet(),
        )),
      ],
    );
  }

  void _showInfoBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        builder: (_, controller) => Container(
          decoration: const BoxDecoration(
            color: Colors.white, 
            borderRadius: BorderRadius.vertical(top: Radius.circular(24))
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.all(12), 
                width: 40, 
                height: 4, 
                decoration: BoxDecoration(
                  color: Colors.grey[300], 
                  borderRadius: BorderRadius.circular(2)
                ),
              ),
              AppBar(
                title: const Text('General Info'), 
                leading: const BackButton(), 
                backgroundColor: Colors.transparent, 
                elevation: 0
              ),
              const Expanded(child: Center(child: Text('Full info here...'))),
            ],
          ),
        ),
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 1,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF59E0B).withOpacity(0.1), 
                    borderRadius: BorderRadius.circular(16)
                  ),
                  child: Icon(
                    Icons.local_fire_department_rounded, 
                    color: _currentStreak > 0 ? const Color(0xFFF59E0B) : Colors.grey,
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
                            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFF59E0B)),
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
            
            _aiBotPositionX = _aiBotPositionX.clamp(0.0, screenWidth - _aiBotSize);
            _aiBotPositionY = _aiBotPositionY.clamp(0.0, screenHeight - _aiBotSize - 100);
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
                          colors: [
                            Color(0xFF6366F1),
                            Color(0xFF8B5CF6),
                          ],
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