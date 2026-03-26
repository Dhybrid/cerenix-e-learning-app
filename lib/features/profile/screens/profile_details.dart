import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';
import '../../../core/network/api_service.dart';
import '../../../core/constants/endpoints.dart';
// ADD THIS IMPORT:
import '../../../features/courses/models/course_models.dart';
import '../../../core/services/event_bus.dart';

class ProfileDetailsScreen extends StatefulWidget {
  const ProfileDetailsScreen({super.key});

  @override
  State<ProfileDetailsScreen> createState() => _ProfileDetailsScreenState();
}

class _ProfileDetailsScreenState extends State<ProfileDetailsScreen> {
  bool _showCopiedMessage = false;
  Map<String, dynamic> _userData = {};
  bool _isLoading = false;
  String? _errorMessage;
  final RefreshController _refreshController = RefreshController(
    initialRefresh: false,
  );
  bool _hasData = false;

  // NEW FIELDS FOR RANK AND REFERRAL
  String _userRank = 'Regular';
  String _referralCode = '';
  Map<String, dynamic>? _currentActivation;

  // ADD THESE TWO LINES HERE:
  List<Course> _userCourses = []; // Add this line
  bool _loadingCourses = false; // Add this line

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _fetchUserCourses(); // ADD THIS LINE
  }

  // ADD THIS METHOD: Fetch user courses
  Future<void> _fetchUserCourses() async {
    if (_loadingCourses) return;

    setState(() {
      _loadingCourses = true;
    });

    try {
      // Fetch courses for the logged-in user
      final courses = await ApiService().getCoursesForUser();

      if (courses.isNotEmpty) {
        // Load progress for each course
        await _loadCoursesProgress(courses);

        setState(() {
          _userCourses = courses;
        });
      } else {
        setState(() {
          _userCourses = [];
        });
      }
    } catch (e) {
      print('❌ Error fetching user courses: $e');
      setState(() {
        _userCourses = [];
      });
    } finally {
      setState(() {
        _loadingCourses = false;
      });
    }
  }

  // ADD THIS METHOD: Load course progress
  Future<void> _loadCoursesProgress(List<Course> courses) async {
    try {
      for (var course in courses) {
        try {
          // Get topics for this course
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

            // Calculate progress percentage
            final progress = topics.isNotEmpty
                ? ((completedCount / topics.length) * 100).round()
                : 0;

            // Update course progress
            course.progress = progress;
          } else {
            course.progress = 0;
          }
        } catch (e) {
          course.progress = 0;
        }
      }
    } catch (e) {
      for (var course in courses) {
        course.progress = 0;
      }
    }
  }

  // ADD THIS METHOD: Helper for course colors
  Color _getCourseColor(int index) {
    // Alternate between blue and orange
    return index.isEven ? Colors.blue : Colors.orange;
  }

  // UPDATED: Enhanced data loading with rank and referral
  Future<void> _loadUserData() async {
    try {
      setState(() {
        _isLoading = true;
      });

      final box = await Hive.openBox('user_box');
      final userData = box.get('current_user');

      if (userData != null) {
        setState(() {
          _userData = Map<String, dynamic>.from(userData);
          _hasData = true;
        });

        // Load activation status for rank
        await _loadActivationStatus();

        // Load referral code
        await _loadReferralCode();

        print('📱 Loaded complete user data');
        print('   - Rank: $_userRank');
        print('   - Referral Code: $_referralCode');
      } else {
        setState(() {
          _errorMessage = 'No user data found. Please login again.';
          _hasData = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load user data: $e';
        _hasData = false;
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // NEW: Load activation status to determine rank
  Future<void> _loadActivationStatus() async {
    try {
      final activationData = await ApiService().getActivationStatus();

      if (activationData != null) {
        setState(() {
          _currentActivation = activationData.toJson();
          _userRank = activationData.grade ?? 'Regular';
        });
        print('✅ User rank: ${activationData.grade}');
      } else {
        setState(() {
          _userRank = 'Regular';
        });
        print('ℹ️ No active activation, using default rank: Regular');
      }
    } catch (e) {
      print('❌ Error loading activation status: $e');
      setState(() {
        _userRank = 'Regular';
      });
    }
  }

  // NEW: Load user referral code
  Future<void> _loadReferralCode() async {
    try {
      final referralInfo = await ApiService().getUserReferral();

      if (referralInfo != null && referralInfo['referral_code'] != null) {
        setState(() {
          _referralCode = referralInfo['referral_code'];
        });
        print('✅ User referral code: $_referralCode');
      } else {
        setState(() {
          _referralCode = 'Not Available';
        });
        print('ℹ️ No referral code available');
      }
    } catch (e) {
      print('❌ Error loading referral code: $e');
      setState(() {
        _referralCode = 'Error Loading';
      });
    }
  }

  // UPDATED: Enhanced refresh method
  Future<void> _refreshData() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final box = await Hive.openBox('user_box');
      final currentUser = box.get('current_user');

      if (currentUser != null) {
        final userId = currentUser['id'];
        final email = currentUser['email'];

        // Update profile to get fresh data
        await ApiService().updateProfile(
          userId: userId,
          email: email,
          name: _userData['name'] ?? currentUser['name'],
          bio: _userData['bio'] ?? '',
          phone: _userData['phone'] ?? '',
          location: _userData['location'] ?? '',
        );

        // Reload all data
        await _loadUserData();

        // ADD THIS LINE: Refresh courses
        await _fetchUserCourses();

        // BROADCAST THAT PROFILE WAS UPDATED
        EventBusService.instance.fire(ProfileUpdatedEvent(_userData));
        EventBusService.instance.fire(CoursesRefreshEvent());

        print('🔄 Refreshed all user data');
      }
    } catch (e) {
      print('⚠️ Refresh failed: $e');
      setState(() {
        _errorMessage = 'Failed to refresh data: $e';
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to refresh: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
      _refreshController.refreshCompleted();
    }
  }

  void _onRefresh() async {
    await _refreshData();
  }

  bool _hasAcademicData() {
    return _userData['level'] != null ||
        _userData['department'] != null ||
        _userData['faculty'] != null ||
        _userData['university'] != null;
  }

  // Get user information with proper fallbacks
  String get _userName => _userData['name'] ?? 'User Name';
  String get _userBio => _userData['bio']?.toString() ?? "No bio available";

  // Academic information with proper nested access
  String get _userLevel {
    if (_userData['level'] is Map) {
      return _userData['level']?['name'] ?? 'Not set';
    }
    return 'Not set';
  }

  String get _userDepartment {
    if (_userData['department'] is Map) {
      return _userData['department']?['abbreviation'] ??
          _userData['department']?['name'] ??
          'Not set';
    }
    return 'Not set';
  }

  String get _userFaculty {
    if (_userData['faculty'] is Map) {
      return _userData['faculty']?['abbreviation'] ??
          _userData['faculty']?['name'] ??
          'Not set';
    }
    return 'Not set';
  }

  String get _userUniversity {
    if (_userData['university'] is Map) {
      return _userData['university']?['name'] ?? 'Not set';
    }
    return 'Not set';
  }

  String get _userSemester {
    if (_userData['semester'] is Map) {
      return _userData['semester']?['name'] ?? 'Not set';
    }
    return 'Not set';
  }

  // Build avatar URL properly
  String get _avatarUrl {
    final avatarUrl = _userData['avatar']?.toString() ?? '';
    if (avatarUrl.isNotEmpty && avatarUrl.startsWith('http')) {
      return avatarUrl;
    }
    if (avatarUrl.isNotEmpty && !avatarUrl.startsWith('http')) {
      return '${ApiEndpoints.baseUrl}$avatarUrl';
    }
    return '';
  }

  // NEW: Helper method to get rank display color
  Color _getRankColor(String rank) {
    switch (rank.toLowerCase()) {
      case 'gold':
        return Colors.amber;
      case 'premium':
        return Colors.purple;
      case 'regular':
      default:
        return Colors.blue;
    }
  }

  // NEW: Helper method to get rank display icon
  IconData _getRankIcon(String rank) {
    switch (rank.toLowerCase()) {
      case 'gold':
        return Icons.workspace_premium_rounded;
      case 'premium':
        return Icons.star_rounded;
      case 'regular':
      default:
        return Icons.person_rounded;
    }
  }

  void _showReferralDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildReferralSheet(),
    );
  }

  // UPDATED: Copy referral code only
  void _copyReferralCode() {
    if (_referralCode.isEmpty ||
        _referralCode == 'Not Available' ||
        _referralCode == 'Error Loading') {
      return;
    }

    Clipboard.setData(ClipboardData(text: _referralCode));

    setState(() {
      _showCopiedMessage = true;
    });

    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _showCopiedMessage = false;
        });
      }
    });
  }

  // UPDATED: Share referral code only
  void _shareReferralCode() {
    if (_referralCode.isEmpty ||
        _referralCode == 'Not Available' ||
        _referralCode == 'Error Loading') {
      return;
    }

    Share.share(
      'Join me on Cerenix! Use my referral code: $_referralCode\n\nGet exclusive rewards when you sign up with this code! 🎉',
    );
  }

  Widget _buildLoadingIndicator() {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 10,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        color: Colors.blue.withOpacity(0.1),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 8),
            Text(
              'Refreshing...',
              style: TextStyle(
                color: Colors.blue.shade700,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            'Unable to load profile',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _errorMessage ?? 'Please check your connection and try again',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade500),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _refreshData,
            icon: const Icon(Icons.refresh),
            label: const Text('Try Again'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Show error screen if no data and we have an error
    if (!_hasData && _errorMessage != null) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        body: _buildErrorWidget(),
      );
    }

    // Show empty state if no data but no error (still loading initially)
    if (!_hasData && _errorMessage == null) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text('Loading profile...'),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Stack(
        children: [
          SmartRefresher(
            controller: _refreshController,
            onRefresh: _onRefresh,
            header: ClassicHeader(
              height: 60,
              completeIcon: Icon(Icons.check, color: Colors.blue),
              failedIcon: Icon(Icons.error, color: Colors.red),
              idleIcon: Icon(Icons.arrow_downward, color: Colors.grey),
              releaseIcon: Icon(Icons.refresh, color: Colors.blue),
              completeText: 'Refresh completed',
              failedText: 'Refresh failed',
              idleText: 'Pull down to refresh',
              releaseText: 'Release to refresh',
              refreshingText: 'Refreshing...',
              textStyle: TextStyle(color: Colors.grey.shade600),
            ),
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                children: [
                  // Top curved section with blue-orange gradient
                  Container(
                    height: 200,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.blue.shade800,
                          Colors.blue.shade600,
                          Colors.orange.shade400,
                        ],
                      ),
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(80),
                        bottomRight: Radius.circular(80),
                      ),
                    ),
                    child: Stack(
                      children: [
                        // Background decorative elements
                        Positioned(
                          top: -30,
                          right: -30,
                          child: Container(
                            width: 120,
                            height: 120,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.15),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: -40,
                          left: -30,
                          child: Container(
                            width: 100,
                            height: 100,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),

                        // Back button and level at the top
                        Padding(
                          padding: const EdgeInsets.only(
                            top: 25,
                            left: 15,
                            right: 15,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              // Back button
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.3),
                                  shape: BoxShape.circle,
                                ),
                                child: IconButton(
                                  icon: const Icon(
                                    Icons.arrow_back_rounded,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                  onPressed: () => Navigator.pop(context),
                                ),
                              ),

                              // Level indicator
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.3),
                                  borderRadius: BorderRadius.circular(15),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.school_rounded,
                                      color: Colors.white,
                                      size: 14,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      _userLevel,
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Very bold PROFILE text at the top center
                        const Positioned(
                          top: 80,
                          left: 0,
                          right: 0,
                          child: Center(
                            child: Text(
                              'PROFILE',
                              style: TextStyle(
                                fontSize: 36,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                letterSpacing: 3,
                                shadows: [
                                  Shadow(
                                    blurRadius: 10,
                                    color: Colors.black26,
                                    offset: Offset(2, 2),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Profile picture floating between sections
                  Transform.translate(
                    offset: const Offset(0, -60),
                    child: Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 4),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: _avatarUrl.isNotEmpty
                            ? Image.network(
                                _avatarUrl,
                                fit: BoxFit.cover,
                                loadingBuilder:
                                    (context, child, loadingProgress) {
                                      if (loadingProgress == null) return child;
                                      return _buildDefaultAvatar();
                                    },
                                errorBuilder: (context, error, stackTrace) {
                                  return _buildDefaultAvatar();
                                },
                              )
                            : _buildDefaultAvatar(),
                      ),
                    ),
                  ),

                  // User info with professional layout
                  Transform.translate(
                    offset: const Offset(0, -50),
                    child: Column(
                      children: [
                        Text(
                          _userName,
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 6),
                        // Department and Faculty abbreviations
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              _userDepartment,
                              style: TextStyle(
                                fontSize: 15,
                                color: Colors.blue.shade600,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                              ),
                              child: Container(
                                width: 4,
                                height: 4,
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade400,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                            Text(
                              _userFaculty,
                              style: TextStyle(
                                fontSize: 15,
                                color: Colors.blue.shade600,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _userUniversity,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),

                  // Profile content
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 5,
                    ),
                    child: Column(
                      children: [
                        const SizedBox(height: 5),

                        // User stats with improved pipes - UPDATED WITH ACTUAL RANK
                        _buildUserStats(),
                        const SizedBox(height: 15),

                        // Bio section
                        _buildBioSection(),
                        const SizedBox(height: 15),

                        // Course information
                        _buildCourseInfo(),
                        const SizedBox(height: 15),

                        // Current courses
                        _buildCurrentCourses(),
                        const SizedBox(height: 20),

                        // Invite friends button
                        _buildInviteButton(),

                        const SizedBox(height: 15),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Small loading indicator at top when refreshing
          if (_isLoading) _buildLoadingIndicator(),

          // Copied Success Message
          if (_showCopiedMessage)
            Positioned(
              top: MediaQuery.of(context).padding.top + 10,
              left: 20,
              right: 20,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: Colors.green,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.check_circle, color: Colors.white, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Referral code copied!',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDefaultAvatar() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.shade400, Colors.orange.shade300],
        ),
        shape: BoxShape.circle,
      ),
      child: const Icon(Icons.person_rounded, color: Colors.white, size: 40),
    );
  }

  // UPDATED: User stats with actual rank
  Widget _buildUserStats() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.shade50, Colors.orange.shade50],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem(
            _userRank,
            'Rank',
            _getRankIcon(_userRank),
            _getRankColor(_userRank),
          ),
          Container(width: 2, height: 35, color: Colors.grey.shade300),
          _buildStatItem(
            '15',
            'Rewards',
            Icons.card_giftcard_rounded,
            Colors.orange,
          ),
          Container(width: 2, height: 35, color: Colors.grey.shade300),
          _buildStatItem(
            '85%',
            'Strength',
            Icons.fitness_center_rounded,
            Colors.blue,
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(
    String value,
    String label,
    IconData icon,
    Color color,
  ) {
    return Flexible(
      child: Column(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: color,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildBioSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'About Me',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _userBio,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade700,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCourseInfo() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Academic Information',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                ),
              ),
              TextButton(
                onPressed: () {
                  // Navigate to courses screen
                },
                child: const Text(
                  'See More',
                  style: TextStyle(
                    color: Colors.blue,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildInfoItem(
                  'Level',
                  _userLevel,
                  Icons.school_rounded,
                  Colors.blue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildInfoItem(
                  'Department',
                  _userDepartment,
                  Icons.business_rounded,
                  Colors.orange,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildInfoItem(
                  'Faculty',
                  _userFaculty,
                  Icons.account_balance_rounded,
                  Colors.blue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildInfoItem(
                  'Semester',
                  _userSemester,
                  Icons.calendar_today_rounded,
                  Colors.orange,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoItem(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withOpacity(0.05), color.withOpacity(0.1)],
        ),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: color,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // Widget _buildCurrentCourses() {
  //   return Container(
  //     padding: const EdgeInsets.all(20),
  //     decoration: BoxDecoration(
  //       color: Colors.white,
  //       borderRadius: BorderRadius.circular(20),
  //       boxShadow: [
  //         BoxShadow(
  //           color: Colors.black.withOpacity(0.1),
  //           blurRadius: 15,
  //           offset: const Offset(0, 5),
  //         ),
  //       ],
  //     ),
  //     child: Column(
  //       crossAxisAlignment: CrossAxisAlignment.start,
  //       children: [
  //         const Text(
  //           'Ongoing Courses',
  //           style: TextStyle(
  //             fontSize: 18,
  //             fontWeight: FontWeight.w700,
  //             color: Colors.black87,
  //           ),
  //         ),
  //         const SizedBox(height: 16),
  //         Column(
  //           children: [
  //             _buildCourseItem('PHY 101', 'General Physics I', '85%', Colors.blue),
  //             const SizedBox(height: 10),
  //             _buildCourseItem('MTH 101', 'Elementary Mathematics I', '92%', Colors.orange),
  //             const SizedBox(height: 10),
  //             _buildCourseItem('CHM 101', 'General Chemistry I', '78%', Colors.blue),
  //             const SizedBox(height: 10),
  //             _buildCourseItem('CSC 101', 'Introduction to Computing', '95%', Colors.orange),
  //           ],
  //         ),
  //       ],
  //     ),
  //   );
  // }

  Widget _buildCurrentCourses() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Ongoing Courses',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),

          if (_loadingCourses)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: CircularProgressIndicator(),
              ),
            )
          else if (_userCourses.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text(
                  'No courses available',
                  style: TextStyle(color: Colors.grey, fontSize: 14),
                ),
              ),
            )
          else
            _buildCoursesList(),
        ],
      ),
    );
  }

  // ADD THIS HELPER METHOD:
  Widget _buildCoursesList() {
    return StatefulBuilder(
      builder: (context, setState) {
        // Track if we're showing all courses or just first 4
        var showAll = false;

        // Determine which courses to show
        final coursesToShow = showAll || _userCourses.length <= 4
            ? _userCourses
            : _userCourses.sublist(0, 4);

        return Column(
          children: [
            // Course items
            Column(
              children: coursesToShow.asMap().entries.map((entry) {
                final index = entry.key;
                final course = entry.value;
                final color = _getCourseColor(index);

                return Padding(
                  padding: EdgeInsets.only(
                    bottom: index < coursesToShow.length - 1 ? 10 : 0,
                  ),
                  child: _buildCourseItem(
                    course.code,
                    course.title,
                    '${course.progress}%',
                    color,
                  ),
                );
              }).toList(),
            ),

            // Show All/Show Less button
            if (_userCourses.length > 4)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      showAll = !showAll;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          showAll
                              ? 'Show Less'
                              : 'Show All (${_userCourses.length})',
                          style: TextStyle(
                            color: Colors.blue.shade700,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Icon(
                          showAll ? Icons.expand_less : Icons.expand_more,
                          color: Colors.blue.shade700,
                          size: 18,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  // KEEP THIS METHOD EXACTLY AS IT IS (it's already correct):
  Widget _buildCourseItem(
    String code,
    String title,
    String progress,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withOpacity(0.05), color.withOpacity(0.1)],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                code.split(' ')[0],
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  code,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                Text(
                  title,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              progress,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Widget _buildCourseItem(String code, String title, String progress, Color color) {
  //   return Container(
  //     padding: const EdgeInsets.all(12),
  //     decoration: BoxDecoration(
  //       gradient: LinearGradient(
  //         colors: [
  //           color.withOpacity(0.05),
  //           color.withOpacity(0.1),
  //         ],
  //       ),
  //       borderRadius: BorderRadius.circular(12),
  //       border: Border.all(color: color.withOpacity(0.2)),
  //     ),
  //     child: Row(
  //       children: [
  //         Container(
  //           width: 40,
  //           height: 40,
  //           decoration: BoxDecoration(
  //             color: color.withOpacity(0.15),
  //             borderRadius: BorderRadius.circular(8),
  //           ),
  //           child: Center(
  //             child: Text(
  //               code.split(' ')[0],
  //               style: TextStyle(
  //                 fontSize: 12,
  //                 fontWeight: FontWeight.w700,
  //                 color: color,
  //               ),
  //             ),
  //           ),
  //         ),
  //         const SizedBox(width: 12),
  //         Expanded(
  //           child: Column(
  //             crossAxisAlignment: CrossAxisAlignment.start,
  //             children: [
  //               Text(
  //                 code,
  //                 style: const TextStyle(
  //                   fontSize: 14,
  //                   fontWeight: FontWeight.w600,
  //                   color: Colors.black87,
  //                 ),
  //               ),
  //               Text(
  //                 title,
  //                 style: TextStyle(
  //                   fontSize: 12,
  //                   color: Colors.grey.shade600,
  //                 ),
  //               ),
  //             ],
  //           ),
  //         ),
  //         Container(
  //           padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
  //           decoration: BoxDecoration(
  //             color: color.withOpacity(0.15),
  //             borderRadius: BorderRadius.circular(12),
  //           ),
  //           child: Text(
  //             progress,
  //             style: TextStyle(
  //               fontSize: 12,
  //               fontWeight: FontWeight.w700,
  //               color: color,
  //             ),
  //           ),
  //         ),
  //       ],
  //     ),
  //   );
  // }

  Widget _buildInviteButton() {
    return Container(
      width: double.infinity,
      height: 50,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.shade500, Colors.orange.shade400],
        ),
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(15),
          onTap: _showReferralDialog,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.person_add_alt_1_rounded,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 8),
              const Text(
                'Invite Friends',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // UPDATED: Referral sheet with ONLY referral code (no link)
  Widget _buildReferralSheet() {
    return Container(
      height: MediaQuery.of(context).size.height * 0.50,
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(30),
          topRight: Radius.circular(30),
        ),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade400,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Invite Friends & Earn',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Share your referral code and get exclusive rewards',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 25),

            // Referral Code Display with Copy Functionality
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.blue.shade50, Colors.orange.shade50],
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.blue.shade100),
              ),
              child: Column(
                children: [
                  Text(
                    'Your Referral Code',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.blue.shade600,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Referral Code with Copy Button
                  GestureDetector(
                    onTap:
                        _referralCode.isNotEmpty &&
                            _referralCode != 'Not Available' &&
                            _referralCode != 'Error Loading'
                        ? _copyReferralCode
                        : null,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 16,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(
                          color: Colors.blue.shade200,
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.blue.shade100,
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _referralCode,
                            style: TextStyle(
                              fontSize: 24,
                              color: Colors.blue.shade800,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 2,
                            ),
                          ),
                          if (_referralCode.isNotEmpty &&
                              _referralCode != 'Not Available' &&
                              _referralCode != 'Error Loading') ...[
                            const SizedBox(width: 12),
                            Icon(
                              Icons.content_copy_rounded,
                              color: Colors.blue.shade600,
                              size: 20,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Copy Instruction
                  if (_referralCode.isNotEmpty &&
                      _referralCode != 'Not Available' &&
                      _referralCode != 'Error Loading')
                    GestureDetector(
                      onTap: _copyReferralCode,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.content_copy_rounded,
                            size: 16,
                            color: Colors.blue.shade500,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Tap to copy code',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.blue.shade500,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Error or Unavailable Message
                  if (_referralCode == 'Not Available' ||
                      _referralCode == 'Error Loading')
                    Text(
                      _referralCode == 'Not Available'
                          ? 'Referral code not available at the moment'
                          : 'Failed to load referral code',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.red.shade500,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Action Buttons
            if (_referralCode.isNotEmpty &&
                _referralCode != 'Not Available' &&
                _referralCode != 'Error Loading')
              Row(
                children: [
                  // Copy Button
                  Expanded(
                    child: SizedBox(
                      height: 50,
                      child: ElevatedButton.icon(
                        onPressed: _copyReferralCode,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue.shade50,
                          foregroundColor: Colors.blue.shade700,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(color: Colors.blue.shade300),
                          ),
                          elevation: 2,
                        ),
                        icon: const Icon(Icons.content_copy_rounded, size: 20),
                        label: const Text(
                          'Copy Code',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Share Button
                  Expanded(
                    child: SizedBox(
                      height: 50,
                      child: ElevatedButton.icon(
                        onPressed: _shareReferralCode,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue.shade600,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 4,
                        ),
                        icon: const Icon(Icons.share_rounded, size: 20),
                        label: const Text(
                          'Share Code',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),

            const SizedBox(height: 10),

            // Instructions
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green.shade100),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.emoji_events_rounded,
                        color: Colors.green.shade600,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'How it works:',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.green.shade700,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Share your referral code with friends. When they sign up using your code, both of you get exclusive rewards!',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.green.shade600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
