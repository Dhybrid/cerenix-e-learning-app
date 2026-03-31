// lib/features/profile/screens/update_level_screen.dart
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../../../core/network/api_service.dart';
import '../../../../core/services/activation_status_service.dart';
import '../../../../core/constants/endpoints.dart';

class UpdateLevelScreen extends StatefulWidget {
  const UpdateLevelScreen({super.key});

  @override
  State<UpdateLevelScreen> createState() => _UpdateLevelScreenState();
}

class _UpdateLevelScreenState extends State<UpdateLevelScreen>
    with WidgetsBindingObserver {
  Map<String, dynamic> _userData = {};
  bool _isLoading = true;
  String? _errorMessage;
  bool _isActivated = false; // Changed to false by default
  String _activationStatus = 'Not Activated'; // NEW: Track activation status

  bool get _isDark => Theme.of(context).brightness == Brightness.dark;
  Color get _pageBackground =>
      _isDark ? const Color(0xFF09111F) : Colors.grey.shade50;
  Color get _surfaceColor => _isDark ? const Color(0xFF101A2B) : Colors.white;
  Color get _borderColor =>
      _isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE5E7EB);
  Color get _titleColor => _isDark ? const Color(0xFFF8FAFC) : Colors.black87;
  Color get _bodyColor =>
      _isDark ? const Color(0xFFCBD5E1) : Colors.grey.shade600;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    ActivationStatusService.listenable.addListener(_handleActivationStatusChanged);
    _loadUserData();
  }

  @override
  void dispose() {
    ActivationStatusService.listenable.removeListener(
      _handleActivationStatusChanged,
    );
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Refresh data when app comes to foreground
      _refreshData();
    }
  }

  Future<void> _loadUserData() async {
    try {
      final box = await Hive.openBox('user_box');
      final userData = box.get('current_user');

      if (userData != null) {
        setState(() {
          _userData = Map<String, dynamic>.from(userData);
        });
        print('👤 Loaded user data - Avatar: ${_userData['avatar']}');

        // Load activation status
        await _loadActivationStatus();
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load user data: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // NEW: Load activation status
  Future<void> _loadActivationStatus() async {
    try {
      await ActivationStatusService.initialize();
      final status = await ActivationStatusService.resolveStatus(
        forceRefresh: false,
      );

      _applyActivationSnapshot(status);

      if (status.isStale || !status.hasCachedValue) {
        ActivationStatusService.refreshInBackground(forceRefresh: true);
      }
    } catch (e) {
      print('❌ Error loading activation status: $e');
      setState(() {
        _isActivated = false;
        _activationStatus = 'Not Activated';
      });
    }
  }

  void _handleActivationStatusChanged() {
    if (!mounted) return;
    _applyActivationSnapshot(ActivationStatusService.current);
  }

  void _applyActivationSnapshot(ActivationStatusSnapshot snapshot) {
    if (!mounted) return;

    setState(() {
      _isActivated = snapshot.isActivated;
      _activationStatus = snapshot.isActivated
          ? (snapshot.grade?.toUpperCase() ?? 'Activated')
          : 'Not Activated';
    });
  }

  Future<void> _refreshData() async {
    try {
      final box = await Hive.openBox('user_box');
      final currentUser = box.get('current_user');

      if (currentUser != null) {
        final userId = currentUser['id'];
        final email = currentUser['email'];

        // Force refresh from backend by updating profile
        await ApiService().updateProfile(
          userId: userId,
          email: email,
          name: _userData['name'] ?? currentUser['name'],
          bio: _userData['bio'] ?? '',
          phone: _userData['phone'] ?? '',
          location: _userData['location'] ?? '',
        );

        // Reload from Hive after update
        final updatedUserData = box.get('current_user');
        if (updatedUserData != null) {
          setState(() {
            _userData = Map<String, dynamic>.from(updatedUserData);
          });
          print('🔄 Academic data refreshed: $_userData');
        }

        // Also refresh activation status
        await _loadActivationStatus();
      }
    } catch (e) {
      print('⚠️ Could not refresh academic data: $e');
      // Continue with existing data - don't show error for background refresh
    }
  }

  // Get user information with proper fallbacks
  String get _userName => _userData['name'] ?? 'User Name';

  // Academic information with proper nested access
  String get _userLevel {
    if (_userData['level'] is Map) {
      return _userData['level']?['name'] ?? 'Not set';
    }
    return 'Not set';
  }

  String get _userDepartment {
    if (_userData['department'] is Map) {
      return _userData['department']?['name'] ?? 'Not set';
    }
    return 'Not set';
  }

  String get _userFaculty {
    if (_userData['faculty'] is Map) {
      return _userData['faculty']?['name'] ?? 'Not set';
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

  // Build avatar URL properly - FIXED VERSION
  String get _avatarUrl {
    final avatarUrl = _userData['avatar']?.toString() ?? '';
    print('🖼️ Raw avatar URL from API: $avatarUrl');

    if (avatarUrl.isEmpty) {
      print('❌ No avatar URL found');
      return '';
    }

    // If it's already a full URL (starts with http), use it directly
    if (avatarUrl.startsWith('http')) {
      print('✅ Using full avatar URL: $avatarUrl');
      return avatarUrl;
    }

    // If it's a relative path, construct the full URL
    String fullUrl;
    if (avatarUrl.startsWith('/')) {
      fullUrl = '${ApiEndpoints.baseUrl}$avatarUrl';
    } else {
      fullUrl = '${ApiEndpoints.baseUrl}/$avatarUrl';
    }

    print('✅ Constructed avatar URL: $fullUrl');
    return fullUrl;
  }

  // NEW: Helper method to get activation status color
  Color _getActivationColor(bool isActivated) {
    return isActivated ? Colors.green.shade600 : Colors.orange.shade600;
  }

  // NEW: Helper method to get activation status icon
  IconData _getActivationIcon(bool isActivated) {
    return isActivated ? Icons.verified_rounded : Icons.person_outline_rounded;
  }

  // NEW: Helper method to get activation status message
  String _getActivationMessage(bool isActivated) {
    return isActivated
        ? 'Your account is activated and you have full access to all Cerenix AI features.'
        : 'Activate your account to unlock full access to Cerenix AI features and premium content.';
  }

  Future<void> _updateLevel() async {
    try {
      // Use push instead of pushReplacement so we can get a result when returning
      final result = await Navigator.pushNamed(
        context,
        '/academic_setup',
        arguments: {'userData': _userData, 'isUpdating': true},
      );

      // If we get a result (like 'updated'), refresh the data immediately
      if (result == 'updated' || result == true) {
        await _refreshData();
      } else {
        // Even if no result, refresh when returning to this screen
        await _refreshData();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to navigate: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildDefaultAvatar() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.purple.shade400, Colors.purple.shade600],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        shape: BoxShape.circle,
      ),
      child: const Icon(Icons.person_rounded, color: Colors.white, size: 30),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: _pageBackground,
        appBar: AppBar(
          backgroundColor: _surfaceColor,
          elevation: 1,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: _titleColor),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            'Academic Profile',
            style: TextStyle(
              color: _titleColor,
              fontWeight: FontWeight.w700,
              fontSize: 18,
            ),
          ),
          centerTitle: false,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: _pageBackground,
      appBar: AppBar(
        backgroundColor: _surfaceColor,
        elevation: 1,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: _titleColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Academic Profile',
          style: TextStyle(
            color: _titleColor,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        centerTitle: false,
      ),
      body: RefreshIndicator(
        onRefresh: _refreshData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              // Profile Header with Avatar
              _buildProfileHeader(),
              const SizedBox(height: 24),

              // Activation Status Card - UPDATED
              _buildActivationCard(),
              const SizedBox(height: 24),

              // Academic Information Section
              _buildAcademicInfoSection(),
              const SizedBox(height: 32),

              // Update Level Button
              _buildUpdateButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: _isDark ? 0.22 : 0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.purple.shade200, width: 2),
            ),
            child: ClipOval(
              child: _avatarUrl.isNotEmpty
                  ? Image.network(
                      _avatarUrl,
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) {
                          print('✅ Avatar loaded successfully');
                          return child;
                        }
                        print('🔄 Avatar loading...');
                        return _buildDefaultAvatar();
                      },
                      errorBuilder: (context, error, stackTrace) {
                        print('❌ Avatar load error: $error');
                        return _buildDefaultAvatar();
                      },
                    )
                  : _buildDefaultAvatar(),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _userName,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: _titleColor,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.purple.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.purple.shade200),
                  ),
                  child: Text(
                    _userLevel,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.purple.shade700,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _userDepartment,
                  style: TextStyle(
                    fontSize: 14,
                    color: _bodyColor,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // UPDATED: Activation Card with real activation status
  Widget _buildActivationCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _isActivated ? Colors.green.shade50 : Colors.orange.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _isActivated ? Colors.green.shade400 : Colors.orange.shade400,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: _isDark ? 0.18 : 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: _getActivationColor(_isActivated),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _getActivationIcon(_isActivated),
                  color: Colors.white,
                  size: 14,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                _activationStatus,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: _getActivationColor(_isActivated),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _getActivationMessage(_isActivated),
            style: TextStyle(
              fontSize: 14,
              color: _isActivated
                  ? Colors.green.shade800
                  : Colors.orange.shade800,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
          if (!_isActivated) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 40,
              child: ElevatedButton(
                onPressed: () {
                  // Navigate to activation screen
                  Navigator.pushNamed(context, '/activate');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange.shade600,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  elevation: 2,
                ),
                child: const Text(
                  'Activate Account',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAcademicInfoSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: _isDark ? 0.22 : 0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Academic Information',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: _titleColor,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Your current academic details and institution information',
            style: TextStyle(fontSize: 14, color: _bodyColor),
          ),
          const SizedBox(height: 24),

          // University - Full Name
          _buildAcademicInfoRow(
            Icons.school_rounded,
            'University',
            _userUniversity,
            Colors.blue.shade600,
          ),
          const SizedBox(height: 18),

          // Faculty - Full Name
          _buildAcademicInfoRow(
            Icons.account_balance_rounded,
            'Faculty',
            _userFaculty,
            Colors.purple.shade600,
          ),
          const SizedBox(height: 18),

          // Department - Full Name
          _buildAcademicInfoRow(
            Icons.business_center_rounded,
            'Department',
            _userDepartment,
            Colors.orange.shade600,
          ),
          const SizedBox(height: 18),

          // Level - Full Name
          _buildAcademicInfoRow(
            Icons.timeline_rounded,
            'Current Level',
            _userLevel,
            Colors.green.shade600,
          ),
          const SizedBox(height: 18),

          // Semester - Full Name
          _buildAcademicInfoRow(
            Icons.calendar_month_rounded,
            'Current Semester',
            _userSemester,
            Colors.red.shade600,
          ),
        ],
      ),
    );
  }

  Widget _buildAcademicInfoRow(
    IconData icon,
    String label,
    String value,
    Color color,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 22),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                value,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.black87,
                  fontWeight: FontWeight.w700,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildUpdateButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _updateLevel,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          padding: EdgeInsets.zero,
        ),
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.purple.shade500,
                Colors.purple.shade600,
                Colors.purple.shade700,
              ],
            ),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.purple.withOpacity(0.4),
                blurRadius: 15,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Container(
            alignment: Alignment.center,
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.upgrade_rounded, size: 22),
                SizedBox(width: 12),
                Text(
                  'Update Academic Information',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
