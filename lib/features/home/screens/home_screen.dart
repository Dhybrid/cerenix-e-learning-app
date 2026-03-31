import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/constants/endpoints.dart';
import '../../../core/network/api_service.dart';
import '../../../core/widgets/custom_app_bar.dart';
import '../../../core/widgets/custom_drawer.dart';
import '../../../features/courses/models/course_models.dart';
import '../../../features/info/screens/general_info_screen.dart';
import '../../../features/popup/models/popup_advertisement.dart';
import '../../../features/popup/services/popup_service.dart';
import '../../../features/popup/widgets/popup_advertisement_widget.dart';
import '../widgets/advert_carousel.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final PopupService _popupService = PopupService();

  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  double _aiBotPositionX = 350;
  double _aiBotPositionY = 300;
  bool _aiBotIsDragging = false;
  final double _aiBotSize = 90;

  int _selectedTab = 0;

  int _currentStreak = 0;
  int _longestStreak = 0;
  int _totalOpenedDays = 0;
  bool _isLoadingStreak = true;

  List<Course> _recentCourses = [];
  bool _loadingRecentCourses = false;
  String? _currentUserId;
  static const String recentCourseBox = 'recent_course';
  static const String offlineCoursesBox = 'offline_courses';

  List<InformationItem> _recentInfoItems = [];
  bool _loadingRecentInfo = false;

  PopupAdvertisement? _currentPopup;
  bool _showPopup = false;
  bool _checkingPopup = false;
  bool _homeAssetsPrimed = false;

  final List<Map<String, dynamic>> _featureItems = const [
    {
      'title': 'Courses',
      'image': 'assets/images/course.png',
      'route': '/courses',
      'color': Color(0xFF2563EB),
    },
    {
      'title': 'Past Questions',
      'image': 'assets/images/pastQuestions.png',
      'route': '/past-questions',
      'color': Color(0xFF10B981),
    },
    {
      'title': 'CGPA Calc',
      'image': 'assets/images/CGPA.png',
      'route': '/cgpa',
      'color': Color(0xFFF59E0B),
    },
    {
      'title': 'Activate App',
      'image': 'assets/images/activate.png',
      'route': '/activate',
      'color': Color(0xFFEF4444),
    },
    {
      'title': 'Scan Doc',
      'image': 'assets/images/scan.png',
      'route': '/coming-soon',
      'color': Color(0xFF8B5CF6),
    },
    {
      'title': 'AI Board',
      'image': 'assets/images/aiBoard.png',
      'route': '/ai-board',
      'color': Color(0xFFEC4899),
    },
  ];

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

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _animateAIBotToPosition();
      _primeHomeAssets();
      _checkAndShowPopup();
    });

    _initializeStreakData();
    _loadRecentCourses();
    _loadRecentInformationItems();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _refreshRecentCourses();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  ColorScheme get _scheme => Theme.of(context).colorScheme;
  bool get _isDark => Theme.of(context).brightness == Brightness.dark;

  Color get _pageBackground =>
      _isDark ? const Color(0xFF09111F) : const Color(0xFFF8FAFC);

  Color get _surfaceColor => _isDark ? const Color(0xFF101A2B) : Colors.white;

  Color get _secondarySurfaceColor =>
      _isDark ? const Color(0xFF162235) : const Color(0xFFF8FAFC);

  Color get _borderColor =>
      _isDark ? Colors.white.withOpacity(0.08) : const Color(0xFFE2E8F0);

  Color get _titleColor =>
      _isDark ? const Color(0xFFF8FAFC) : const Color(0xFF1A1A2E);

  Color get _bodyColor =>
      _isDark ? const Color(0xFFCBD5E1) : const Color(0xFF6B7280);

  Future<void> _primeHomeAssets() async {
    if (_homeAssetsPrimed || !mounted) {
      return;
    }

    _homeAssetsPrimed = true;
    final devicePixelRatio = MediaQuery.of(context).devicePixelRatio;
    final cacheWidth = (120 * devicePixelRatio).round();

    for (final feature in _featureItems) {
      try {
        if (!mounted) {
          return;
        }
        await precacheImage(
          ResizeImage(
            AssetImage(feature['image'] as String),
            width: cacheWidth,
          ),
          context,
        );
      } catch (_) {}
    }

    try {
      if (!mounted) {
        return;
      }
      await precacheImage(
        const AssetImage('assets/images/waveAI.gif'),
        context,
      );
    } catch (_) {}
  }

  Future<void> _initializeStreakData() async {
    await _recordAppOpen();
    await _loadStreakData();
  }

  Future<void> _refreshRecentCourses() async {
    await _loadRecentCourses();
  }

  Future<void> _checkAndShowPopup() async {
    if (_checkingPopup) {
      return;
    }

    _checkingPopup = true;

    try {
      await _getCurrentUserId();

      if (_currentUserId != null) {
        final userId = int.tryParse(_currentUserId!);

        final popup = await _popupService.getPopupForUser(userId);

        if (popup != null && mounted) {
          setState(() {
            _currentPopup = popup;
          });

          Future.delayed(Duration(seconds: popup.showDelay), () {
            if (!mounted || _currentPopup?.id != popup.id) {
              return;
            }
            setState(() {
              _showPopup = true;
            });
          });
        }

        await _popupService.recordSessionStart(userId);
      }
    } catch (e) {
      print('❌ Error checking popup: $e');
    } finally {
      _checkingPopup = false;
    }
  }

  void _closePopup() {
    setState(() {
      _showPopup = false;
    });

    if (_currentPopup != null && _currentUserId != null) {
      _popupService.recordPopupShown(
        _currentPopup!,
        int.tryParse(_currentUserId!),
      );
    }
  }

  void _animateAIBotToPosition() {
    setState(() {
      _aiBotPositionX =
          MediaQuery.of(context).size.width * 0.75 - _aiBotSize / 2;
      _aiBotPositionY =
          MediaQuery.of(context).size.height * 0.7 - _aiBotSize / 2;
    });
  }

  Future<void> _loadRecentInformationItems() async {
    if (_loadingRecentInfo) {
      return;
    }

    setState(() {
      _loadingRecentInfo = true;
    });

    try {
      await _getCurrentUserId();

      if (_currentUserId == null) {
        return;
      }

      final url = '${ApiEndpoints.informationItems}?user_id=$_currentUserId';
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      final headers = <String, String>{'Content-Type': 'application/json'};
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Token $token';
      }

      final response = await http
          .get(Uri.parse(url), headers: headers)
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        List<InformationItem> loadedItems = [];

        if (responseData is List) {
          loadedItems = responseData
              .map((item) => InformationItem.fromJson(item))
              .toList();
        } else if (responseData is Map) {
          if (responseData['items'] is List) {
            loadedItems = (responseData['items'] as List)
                .map((item) => InformationItem.fromJson(item))
                .toList();
          } else if (responseData['results'] is List) {
            loadedItems = (responseData['results'] as List)
                .map((item) => InformationItem.fromJson(item))
                .toList();
          } else if (responseData['data'] is List) {
            loadedItems = (responseData['data'] as List)
                .map((item) => InformationItem.fromJson(item))
                .toList();
          }
        }

        loadedItems.sort((a, b) => b.date.compareTo(a.date));
        final recentItems = loadedItems.take(3).toList();

        for (final item in recentItems) {
          item.isRead = prefs.getBool('read_${item.id}') ?? false;
        }

        if (!mounted) {
          return;
        }

        setState(() {
          _recentInfoItems = recentItems;
        });
      }
    } catch (e) {
      print('❌ Home: Error loading information items: $e');
    } finally {
      if (mounted) {
        setState(() {
          _loadingRecentInfo = false;
        });
      }
    }
  }

  Future<void> _navigateToInfoDetail(InformationItem item) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('read_${item.id}', true);

    if (mounted) {
      setState(() {
        for (final infoItem in _recentInfoItems) {
          if (infoItem.id == item.id) {
            infoItem.isRead = true;
          }
        }
      });
    }

    if (!mounted) {
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => InfoDetailScreen(infoItem: item)),
    );
  }

  IconData _getInfoIcon(InformationItem item) {
    if (item.requiresActivation) return Icons.lock;
    if (item.isTargeted) return Icons.school;
    if (item.isFeatured) return Icons.star;
    return Icons.info;
  }

  Color _getInfoColor(InformationItem item) {
    if (item.requiresActivation) return Colors.orange;
    if (item.isTargeted) return Colors.purple;
    if (item.isFeatured) return Colors.amber;
    return const Color(0xFF6366F1);
  }

  String _getInfoSubtitle(InformationItem item) {
    if (item.requiresActivation) return 'Activation Required';
    if (item.isTargeted) return 'Targeted Information';
    return item.category;
  }

  Future<void> _getCurrentUserId() async {
    try {
      final box = await Hive.openBox('user_box');
      final userData = box.get('current_user');
      if (userData != null) {
        _currentUserId = userData['id'].toString();
      }
    } catch (e) {
      print('⚠️ Home: Error getting user ID: $e');
    }
  }

  Future<void> _loadRecentCourses() async {
    if (_loadingRecentCourses) {
      return;
    }

    setState(() {
      _loadingRecentCourses = true;
    });

    try {
      await _getCurrentUserId();

      if (_currentUserId == null) {
        return;
      }

      final box = await Hive.openBox(recentCourseBox);
      final userKey = 'recent_course_$_currentUserId';
      final recentData = box.get(userKey);

      if (recentData != null) {
        Course? recentCourse;

        if (recentData is Map) {
          try {
            final jsonData = <String, dynamic>{};
            recentData.forEach((key, value) {
              jsonData[key.toString()] = value;
            });
            recentCourse = Course.fromJson(jsonData);
          } catch (e) {
            print('❌ Home: Error parsing recent course: $e');
          }
        } else if (recentData is Course) {
          recentCourse = recentData;
        }

        if (recentCourse != null) {
          final allCourses = await _getAllUserCourses();
          final recentCoursesList = <Course>[recentCourse];

          for (final course in allCourses) {
            if (course.id != recentCourse.id && recentCoursesList.length < 3) {
              recentCoursesList.add(course);
            }
          }

          await _loadRecentCoursesProgress(recentCoursesList);

          if (!mounted) {
            return;
          }
          setState(() {
            _recentCourses = recentCoursesList;
          });
        }
      } else {
        final allCourses = await _getAllUserCourses();
        final firstThreeCourses = allCourses.take(3).toList();
        await _loadRecentCoursesProgress(firstThreeCourses);

        if (!mounted) {
          return;
        }
        setState(() {
          _recentCourses = firstThreeCourses;
        });
      }
    } catch (e) {
      print('❌ Home: Error loading recent courses: $e');
      if (mounted) {
        setState(() {
          _recentCourses = [];
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _loadingRecentCourses = false;
        });
      }
    }
  }

  Future<List<Course>> _getAllUserCourses() async {
    try {
      return await ApiService().getCoursesForUser();
    } catch (e) {
      print('⚠️ Home: Error getting all courses: $e');
      return [];
    }
  }

  Future<void> _loadRecentCoursesProgress(List<Course> courses) async {
    try {
      for (final course in courses) {
        try {
          final topics = await ApiService().getTopics(
            courseId: int.parse(course.id),
          );

          if (topics.isNotEmpty) {
            final completedCount = topics
                .where((topic) => topic.isCompleted)
                .length;
            course.progress = ((completedCount / topics.length) * 100).round();
          } else {
            course.progress = 0;
          }
        } catch (_) {
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
    } catch (_) {
      return false;
    }
  }

  Color _getCourseColor(int index) {
    const colors = [Colors.blue, Colors.green, Colors.orange];
    return colors[index % colors.length];
  }

  Future<void> _recordAppOpen() async {
    try {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final streakBox = await Hive.openBox('app_streak_tracking');

      final lastRecordedDate = streakBox.get('last_recorded_date');
      if (lastRecordedDate != null) {
        final lastDate = DateTime.parse(lastRecordedDate);
        if (lastDate.isAtSameMomentAs(today)) {
          return;
        }
      }

      final dateKey = today.toIso8601String();
      streakBox.put(dateKey, true);
      streakBox.put('last_recorded_date', dateKey);
    } catch (e) {
      print('⚠️ Home: Error recording app open: $e');
    }
  }

  Future<void> _loadStreakData() async {
    try {
      final streakBox = await Hive.openBox('app_streak_tracking');
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final allKeys = streakBox.keys.toList();
      final openedDates = <DateTime>[];

      for (final key in allKeys) {
        if (key != 'last_recorded_date' && streakBox.get(key) == true) {
          try {
            openedDates.add(DateTime.parse(key));
          } catch (_) {}
        }
      }

      openedDates.sort((a, b) => a.compareTo(b));

      int currentStreak = 0;
      int longestStreak = 0;
      int tempStreak = 0;

      var checkDate = today;
      while (openedDates.any(
        (date) =>
            date.year == checkDate.year &&
            date.month == checkDate.month &&
            date.day == checkDate.day,
      )) {
        currentStreak++;
        checkDate = checkDate.subtract(const Duration(days: 1));
      }

      if (openedDates.isNotEmpty) {
        tempStreak = 1;
        for (var i = 1; i < openedDates.length; i++) {
          final difference = openedDates[i]
              .difference(openedDates[i - 1])
              .inDays;
          if (difference == 1) {
            tempStreak++;
          } else {
            if (tempStreak > longestStreak) {
              longestStreak = tempStreak;
            }
            tempStreak = 1;
          }
        }
        if (tempStreak > longestStreak) {
          longestStreak = tempStreak;
        }
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _currentStreak = currentStreak;
        _longestStreak = longestStreak;
        _totalOpenedDays = openedDates.length;
        _isLoadingStreak = false;
      });
    } catch (e) {
      print('⚠️ Home: Error loading streak data: $e');
      if (!mounted) {
        return;
      }
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

  Map<String, dynamic>? _getUserData() {
    try {
      final box = Hive.box('user_box');
      final userData = box.get('current_user');
      return userData != null ? Map<String, dynamic>.from(userData) : null;
    } catch (_) {
      return null;
    }
  }

  String _getUserName() {
    final userData = _getUserData();
    return userData?['name']?.toString() ?? 'Student';
  }

  String _getProfileImageUrl() {
    try {
      final userData = _getUserData();
      if (userData == null) {
        return '';
      }

      final avatarUrl = userData['avatar']?.toString() ?? '';
      if (avatarUrl.isEmpty) {
        return '';
      }

      if (avatarUrl.startsWith('http')) {
        return avatarUrl;
      }

      return avatarUrl.startsWith('/')
          ? '${ApiEndpoints.baseUrl}$avatarUrl'
          : '${ApiEndpoints.baseUrl}/$avatarUrl';
    } catch (_) {
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
      decoration: BoxDecoration(
        color: _surfaceColor,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(32),
          topRight: Radius.circular(32),
        ),
      ),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: _isDark ? Colors.white24 : Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Study Materials',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: _titleColor,
                  ),
                ),
                IconButton(
                  icon: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: _secondarySurfaceColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.close_rounded,
                      size: 20,
                      color: _titleColor,
                    ),
                  ),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
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
      color: _surfaceColor,
      elevation: 0,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _borderColor),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.14),
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
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: _titleColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(fontSize: 12, color: _bodyColor),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 16,
                color: _bodyColor,
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
      backgroundColor: _pageBackground,
      appBar: CustomAppBar(
        scaffoldKey: _scaffoldKey,
        title: 'Cerenix',
        showNotifications: false,
        showProfile: false,
      ),
      drawer: const CustomDrawer(),
      body: Stack(
        children: [
          Positioned.fill(child: _buildBackgroundDecor()),
          SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildWelcomeSection(),
                const SizedBox(height: 20),
                _buildAdvertCard(),
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

  Widget _buildBackgroundDecor() {
    return IgnorePointer(
      child: Stack(
        children: [
          Container(color: _pageBackground),
          Positioned(
            top: -70,
            right: -40,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _scheme.primary.withOpacity(_isDark ? 0.12 : 0.10),
              ),
            ),
          ),
          Positioned(
            top: 210,
            left: -60,
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(
                  0xFF10B981,
                ).withOpacity(_isDark ? 0.10 : 0.08),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWelcomeSection() {
    final profileImageUrl = _getProfileImageUrl();
    final userName = _getUserName();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: _isDark
              ? const [Color(0xFF0F172A), Color(0xFF1E3A8A)]
              : const [Color(0xFF0F172A), Color(0xFF2563EB)],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1D4ED8).withOpacity(_isDark ? 0.18 : 0.14),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Hello, $userName',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Ready to dive into knowledge?',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.82),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
            child: profileImageUrl.isNotEmpty
                ? CircleAvatar(
                    radius: 26,
                    backgroundImage: NetworkImage(profileImageUrl),
                    onBackgroundImageError: (_, __) {},
                  )
                : CircleAvatar(
                    radius: 26,
                    backgroundColor: Colors.white.withOpacity(0.12),
                    child: const Icon(
                      Icons.person_rounded,
                      color: Colors.white,
                      size: 26,
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdvertCard() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: _surfaceColor,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(_isDark ? 0.18 : 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: const AdvertCarousel(height: 140),
    );
  }

  Widget _buildFeatureGrid() {
    final screenWidth = MediaQuery.of(context).size.width;
    final childAspectRatio = screenWidth < 380 ? 0.78 : 0.84;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: childAspectRatio,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: _featureItems.length,
      itemBuilder: (context, index) {
        return _buildFeatureCard(_featureItems[index]);
      },
    );
  }

  Widget _buildFeatureCard(Map<String, dynamic> feature) {
    final color = feature['color'] as Color;

    return Material(
      borderRadius: BorderRadius.circular(16),
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          if (feature['title'] == 'Past Questions') {
            _showPastQuestionsBottomSheet();
          } else {
            Navigator.pushNamed(context, feature['route'] as String);
          }
        },
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: _surfaceColor,
            border: Border.all(color: _borderColor),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(_isDark ? 0.14 : 0.04),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 112;
              final iconShellSize = compact ? 52.0 : 58.0;
              final iconSize = compact ? 30.0 : 34.0;
              final titleFontSize = compact ? 11.0 : 12.0;

              return Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: compact ? 6 : 8,
                  vertical: compact ? 10 : 12,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: iconShellSize,
                      height: iconShellSize,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        color: color.withValues(alpha: 0.14),
                      ),
                      child: Center(
                        child: _buildFeatureArt(
                          feature['image'] as String,
                          color: color,
                          width: iconSize,
                          height: iconSize,
                        ),
                      ),
                    ),
                    SizedBox(height: compact ? 10 : 12),
                    Text(
                      feature['title'] as String,
                      style: TextStyle(
                        fontSize: titleFontSize,
                        fontWeight: FontWeight.w600,
                        color: _titleColor,
                        height: 1.2,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              );
            },
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
            color: _secondarySurfaceColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _borderColor),
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
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: _titleColor,
              ),
            ),
            TextButton(
              onPressed: _selectedTab == 0
                  ? () => Navigator.pushNamed(context, '/courses')
                  : null,
              child: Text(
                _selectedTab == 0 ? 'See all' : 'Soon',
                style: TextStyle(
                  color: _selectedTab == 0
                      ? _scheme.primary
                      : _bodyColor.withOpacity(0.7),
                ),
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
            color: isActive ? _surfaceColor : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(_isDark ? 0.14 : 0.08),
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
              color: isActive ? _scheme.primary : _bodyColor,
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
            final color = _getCourseColor(entry.key);
            final course = entry.value;
            return _courseCard(
              course.code,
              '${course.progress}% completed',
              color,
              course,
            );
          }),
      ],
    );
  }

  Widget _buildRecentCoursesLoading() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Center(
        child: Column(
          children: [
            CircularProgressIndicator(color: _scheme.primary),
            const SizedBox(height: 10),
            Text(
              'Loading recent courses...',
              style: TextStyle(color: _bodyColor),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoRecentCourses() {
    return _buildSimpleListCard(
      icon: Icons.menu_book,
      iconColor: _bodyColor,
      title: 'No courses available',
      subtitle: 'Start exploring courses from the Courses tab',
      onTap: () => Navigator.pushNamed(context, '/courses'),
    );
  }

  Widget _courseCard(String code, String progress, Color color, Course course) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: FutureBuilder<bool>(
        future: _isCourseDownloaded(course.id),
        builder: (context, snapshot) {
          final isDownloaded = snapshot.data ?? false;

          return Material(
            color: _surfaceColor,
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => _navigateToCourseDetails(course),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _borderColor),
                ),
                child: Row(
                  children: [
                    Container(
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
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            code,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: _titleColor,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            progress,
                            style: TextStyle(color: _bodyColor, fontSize: 12),
                          ),
                          if (isDownloaded)
                            Container(
                              margin: const EdgeInsets.only(top: 6),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.green.withOpacity(0.14),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'Offline',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.green.shade700,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 14,
                        color: color,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _navigateToCourseDetails(Course course) async {
    if (_currentUserId != null) {
      try {
        final box = await Hive.openBox(recentCourseBox);
        final userKey = 'recent_course_$_currentUserId';
        await box.put(userKey, course.toJson());
      } catch (e) {
        print('⚠️ Home: Error saving recent course: $e');
      }
    }

    if (!mounted) {
      return;
    }
    Navigator.pushNamed(context, '/course-detail', arguments: course);
  }

  Widget _buildCalendarTimer() {
    return Container(
      key: const ValueKey(1),
      height: 200,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _surfaceColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _borderColor),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.calendar_month_rounded,
            size: 64,
            color: _isDark ? Colors.white38 : Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            'Feature Coming Soon',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: _titleColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Calendar and timer features will be available soon',
            style: TextStyle(fontSize: 14, color: _bodyColor),
            textAlign: TextAlign.center,
          ),
        ],
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
            Text(
              'General Info',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: _titleColor,
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => GeneralInfoScreen()),
                );
              },
              child: Text('See more', style: TextStyle(color: _scheme.primary)),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_loadingRecentInfo)
          _buildInfoLoading()
        else if (_recentInfoItems.isEmpty)
          _buildNoInfoItems()
        else
          ..._recentInfoItems.map(_buildInfoCard),
      ],
    );
  }

  Widget _buildInfoLoading() {
    return _buildSimpleListCard(
      icon: Icons.hourglass_top_rounded,
      iconColor: _scheme.primary,
      title: 'Loading information...',
      subtitle: 'Fetching latest updates',
      trailing: SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: _scheme.primary,
        ),
      ),
    );
  }

  Widget _buildNoInfoItems() {
    return _buildSimpleListCard(
      icon: Icons.info_outline,
      iconColor: _bodyColor,
      title: 'No information available',
      subtitle: 'Check back later for updates',
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => GeneralInfoScreen()),
        );
      },
    );
  }

  Widget _buildInfoCard(InformationItem item) {
    final iconColor = _getInfoColor(item);
    final icon = _getInfoIcon(item);
    final subtitle = _getInfoSubtitle(item);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: _surfaceColor,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _navigateToInfoDetail(item),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _borderColor),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: iconColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(child: Icon(icon, color: iconColor, size: 20)),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        style: TextStyle(
                          fontWeight: item.isRead
                              ? FontWeight.w500
                              : FontWeight.w700,
                          color: item.isRead
                              ? _titleColor.withOpacity(0.76)
                              : _titleColor,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(fontSize: 12, color: _bodyColor),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item.date,
                        style: TextStyle(
                          fontSize: 11,
                          color: _bodyColor.withOpacity(0.8),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: _scheme.primary.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 14,
                    color: _scheme.primary,
                  ),
                ),
              ],
            ),
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
            Text(
              'Streak',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: _titleColor,
              ),
            ),
            IconButton(
              icon: Icon(
                Icons.refresh_rounded,
                size: 20,
                color: _scheme.primary,
              ),
              onPressed: _initializeStreakData,
              tooltip: 'Refresh streak',
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: _surfaceColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _borderColor),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF59E0B).withOpacity(0.12),
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
                        '$_currentStreak-Day Streak',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: _titleColor,
                        ),
                      ),
                      Text(
                        _isLoadingStreak
                            ? 'Loading...'
                            : (_currentStreak > 0
                                  ? _getStreakMessage(_currentStreak)
                                  : 'Open the app tomorrow to start your streak!'),
                        style: TextStyle(color: _bodyColor),
                        maxLines: 2,
                      ),
                      if (_totalOpenedDays > 0 && !_isLoadingStreak)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            'Total: $_totalOpenedDays days • Longest: $_longestStreak days',
                            style: TextStyle(
                              fontSize: 12,
                              color: _bodyColor.withOpacity(0.85),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: _isLoadingStreak
                      ? SizedBox(
                          width: 40,
                          height: 40,
                          child: CircularProgressIndicator(
                            strokeWidth: 3,
                            valueColor: const AlwaysStoppedAnimation<Color>(
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

  Widget _buildSimpleListCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    final trailingWidget =
        trailing ??
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: _scheme.primary.withOpacity(0.10),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            Icons.arrow_forward_ios_rounded,
            size: 14,
            color: _scheme.primary,
          ),
        );

    return Material(
      color: _surfaceColor,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _borderColor),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: _titleColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(subtitle, style: TextStyle(color: _bodyColor)),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              trailingWidget,
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureArt(
    String assetPath, {
    required Color color,
    required double width,
    required double height,
  }) {
    final cacheWidth = (width * MediaQuery.of(context).devicePixelRatio * 1.5)
        .round();

    return Image.asset(
      assetPath,
      width: width,
      height: height,
      fit: BoxFit.contain,
      cacheWidth: cacheWidth,
      filterQuality: FilterQuality.high,
      gaplessPlayback: true,
      errorBuilder: (context, error, stackTrace) {
        return Icon(Icons.auto_awesome_rounded, size: 28, color: color);
      },
    );
  }

  Widget _buildDraggableAIBot() {
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeOutCubic,
      left: _aiBotPositionX,
      top: _aiBotPositionY,
      child: GestureDetector(
        onPanStart: (_) {
          setState(() => _aiBotIsDragging = true);
        },
        onPanUpdate: (details) {
          setState(() {
            _aiBotPositionX += details.delta.dx;
            _aiBotPositionY += details.delta.dy;

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
        onPanEnd: (_) {
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
