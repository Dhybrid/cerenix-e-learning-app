// lib/features/auth/screens/academic_setup_screen.dart
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/onboarding_models.dart';
import '../../../core/network/api_service.dart';
import '../../../core/constants/endpoints.dart';
import 'terms_conditions_screen.dart';

class AcademicSetupScreen extends StatefulWidget {
  final UserOnboardingData? existingData;

  const AcademicSetupScreen({super.key, this.existingData});

  @override
  State<AcademicSetupScreen> createState() => _AcademicSetupScreenState();
}

class _AcademicSetupScreenState extends State<AcademicSetupScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  UserOnboardingData _userData = UserOnboardingData.empty;
  final Map<String, TextEditingController> _searchControllers = {
    'university': TextEditingController(),
    'faculty': TextEditingController(),
    'department': TextEditingController(),
  };

  // API Data
  List<University> _universities = [];
  List<Faculty> _faculties = [];
  List<Department> _departments = [];
  List<Level> _levels = [];
  List<Semester> _semesters = [];

  bool _isLoading = false;
  bool _isRefreshing = false;
  String _loadingMessage = 'Loading...';
  String? _errorMessage;

  final List<Map<String, dynamic>> _onboardingSteps = [
    {
      'title': 'Select Your University',
      'subtitle': 'Choose your institution',
      'type': 'university',
    },
    {
      'title': 'Choose Your Faculty',
      'subtitle': 'Select your faculty/school',
      'type': 'faculty',
    },
    {
      'title': 'Pick Your Department',
      'subtitle': 'Choose your department',
      'type': 'department',
    },
    {
      'title': 'Select Your Level',
      'subtitle': 'What year are you in?',
      'type': 'level',
    },
    {
      'title': 'Select Semester',
      'subtitle': 'Choose your current semester',
      'type': 'semester',
    },
  ];

  @override
  void initState() {
    super.initState();
    _userData = widget.existingData ?? UserOnboardingData.empty;
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _loadingMessage = 'Loading universities...';
    });

    try {
      await _loadUniversities();
      await _loadLevels();
      await _loadSemesters();
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load data: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _refreshData() async {
    if (_isRefreshing) return;
    
    setState(() {
      _isRefreshing = true;
      _errorMessage = null;
    });

    try {
      switch (_currentPage) {
        case 0:
          await _loadUniversities();
          break;
        case 1:
          if (_userData.university != null) {
            await _loadFaculties(_userData.university!.id);
          }
          break;
        case 2:
          if (_userData.faculty != null) {
            await _loadDepartments(_userData.faculty!.id);
          }
          break;
        case 3:
          await _loadLevels();
          break;
        case 4:
          await _loadSemesters();
          break;
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to refresh: $e';
      });
    } finally {
      setState(() {
        _isRefreshing = false;
      });
    }
  }

  Future<void> _loadUniversities() async {
    try {
      final universities = await ApiService().getUniversities();
      setState(() {
        _universities = universities;
      });
    } catch (e) {
      throw Exception('Failed to load universities: $e');
    }
  }

  Future<void> _loadFaculties(String universityId) async {
    try {
      final faculties = await ApiService().getFaculties(universityId);
      setState(() {
        _faculties = faculties;
      });
    } catch (e) {
      throw Exception('Failed to load faculties: $e');
    }
  }

  Future<void> _loadDepartments(String facultyId) async {
    try {
      final departments = await ApiService().getDepartments(facultyId);
      setState(() {
        _departments = departments;
      });
    } catch (e) {
      throw Exception('Failed to load departments: $e');
    }
  }

  Future<void> _loadLevels() async {
    try {
      final levels = await ApiService().getLevels();
      setState(() {
        _levels = levels;
      });
    } catch (e) {
      throw Exception('Failed to load levels: $e');
    }
  }

  Future<void> _loadSemesters() async {
    try {
      final semesters = await ApiService().getSemesters();
      setState(() {
        _semesters = semesters;
      });
    } catch (e) {
      throw Exception('Failed to load semesters: $e');
    }
  }

  @override
  void dispose() {
    _searchControllers.forEach((key, controller) => controller.dispose());
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < _onboardingSteps.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    } else {
      _completeOnboarding();
    }
  }

  void _previousPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _completeOnboarding() async {
    setState(() {
      _isLoading = true;
      _loadingMessage = 'Completing onboarding...';
    });

    try {
      await ApiService().updateOnboarding(
        universityId: _userData.university?.id,
        facultyId: _userData.faculty?.id,
        departmentId: _userData.department?.id,
        levelId: _userData.level?.id,
        semesterId: _userData.semester?.id,
      );
      
      print('Onboarding completed successfully!'); // Debug
    

      // Update local user data
      final box = await Hive.openBox('user_box');
      final currentUser = box.get('current_user');
      if (currentUser != null) {
        currentUser['onboarding_completed'] = true;
        await box.put('current_user', currentUser);
      }

      if (!mounted) return;
      
      Navigator.pushReplacementNamed(context, '/home');

      // Navigate to Terms & Conditions instead of home
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => TermsAndConditionsScreen(userData: _userData),
      ),
    );
      
    } catch (e) {
      _showError('Failed to complete onboarding: $e');
      print('Onboarding error details: $e'); // Add this for debugging
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  // FIXED: University card with proper image URL handling
  Widget _buildUniversityCard(University university, bool isSelected, VoidCallback onTap) {
    // Build full image URL from backend path
    String? fullImageUrl = university.imagePath;
    if (fullImageUrl != null && !fullImageUrl.startsWith('http')) {
      fullImageUrl = '${ApiEndpoints.baseUrl}$fullImageUrl';
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 100,
        margin: const EdgeInsets.all(4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected ? const Color(0xFF6366F1) : Colors.grey.shade300,
                  width: isSelected ? 2 : 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.shade200,
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(11),
                child: fullImageUrl != null
                    ? Image.network(
                        fullImageUrl,
                        width: 48,
                        height: 48,
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return _buildUniversityFallback(university, isSelected);
                        },
                        errorBuilder: (context, error, stackTrace) {
                          return _buildUniversityFallback(university, isSelected);
                        },
                      )
                    : _buildUniversityFallback(university, isSelected),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              university.abbreviation ?? 'UNI',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: isSelected ? const Color(0xFF6366F1) : Colors.grey.shade700,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUniversityFallback(University university, bool isSelected) {
    return Container(
      color: Colors.grey.shade100,
      child: Center(
        child: Text(
          university.abbreviation ?? university.name.substring(0, 2),
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF6366F1),
          ),
        ),
      ),
    );
  }

  Widget _buildFacultyCard(Faculty faculty, bool isSelected, VoidCallback onTap) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Material(
        elevation: isSelected ? 1 : 0,
        borderRadius: BorderRadius.circular(12),
        color: isSelected ? const Color(0xFF6366F1).withOpacity(0.05) : Colors.white,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(12),
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? const Color(0xFF6366F1) : Colors.grey.shade200,
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFF6366F1) : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(
                      faculty.abbreviation?.substring(0, 2) ?? faculty.name.substring(0, 2),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: isSelected ? Colors.white : const Color(0xFF6366F1),
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
                        faculty.abbreviation ?? faculty.name,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isSelected ? const Color(0xFF6366F1) : const Color(0xFF1F2937),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        faculty.name,
                        style: TextStyle(
                          fontSize: 11,
                          color: isSelected ? const Color(0xFF6366F1).withOpacity(0.8) : Colors.grey.shade600,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                if (isSelected)
                  const Icon(
                    Icons.check_circle_rounded,
                    color: Color(0xFF6366F1),
                    size: 18,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDepartmentCard(Department department, bool isSelected, VoidCallback onTap) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Material(
        elevation: isSelected ? 1 : 0,
        borderRadius: BorderRadius.circular(12),
        color: isSelected ? const Color(0xFF6366F1).withOpacity(0.05) : Colors.white,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(12),
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? const Color(0xFF6366F1) : Colors.grey.shade200,
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFF6366F1) : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(
                      department.abbreviation?.substring(0, 2) ?? department.name.substring(0, 2),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: isSelected ? Colors.white : const Color(0xFF6366F1),
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
                        department.abbreviation ?? department.name,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isSelected ? const Color(0xFF6366F1) : const Color(0xFF1F2937),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        department.name,
                        style: TextStyle(
                          fontSize: 11,
                          color: isSelected ? const Color(0xFF6366F1).withOpacity(0.8) : Colors.grey.shade600,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                if (isSelected)
                  const Icon(
                    Icons.check_circle_rounded,
                    color: Color(0xFF6366F1),
                    size: 18,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLevelCard(Level level, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        margin: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: isSelected 
              ? const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF6366F1),
                    Color(0xFF8B5CF6),
                  ],
                )
              : LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.grey.shade50,
                    Colors.grey.shade100,
                  ],
                ),
          boxShadow: isSelected 
              ? [
                  BoxShadow(
                    color: const Color(0xFF6366F1).withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.grey.shade300,
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Container(
          width: double.infinity,
          height: 70,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? const Color(0xFF6366F1) : Colors.transparent,
              width: 2,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    level.name,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: isSelected ? Colors.white : const Color(0xFF1F2937),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Year ${level.value ~/ 100}',
                    style: TextStyle(
                      fontSize: 12,
                      color: isSelected ? Colors.white.withOpacity(0.8) : Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
              if (isSelected)
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    size: 16,
                    color: Color(0xFF6366F1),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSemesterCard(Semester semester, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        margin: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: isSelected 
              ? const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF6366F1),
                    Color(0xFF8B5CF6),
                  ],
                )
              : LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white,
                    Colors.grey.shade50,
                  ],
                ),
          boxShadow: isSelected 
              ? [
                  BoxShadow(
                    color: const Color(0xFF6366F1).withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.grey.shade200,
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
          border: Border.all(
            color: isSelected ? const Color(0xFF6366F1) : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Container(
          width: double.infinity,
          height: 100,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    semester.name,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: isSelected ? Colors.white : const Color(0xFF1F2937),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Semester ${semester.value}',
                    style: TextStyle(
                      fontSize: 14,
                      color: isSelected ? Colors.white.withOpacity(0.9) : Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
              if (isSelected)
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    size: 20,
                    color: Color(0xFF6366F1),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchField(String type, String hintText, ValueChanged<String> onChanged) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: TextField(
        controller: _searchControllers[type],
        onChanged: onChanged,
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 14),
          prefixIcon: Icon(Icons.search_rounded, color: Colors.grey.shade500, size: 20),
          suffixIcon: _searchControllers[type]!.text.isNotEmpty
              ? IconButton(
                  icon: Icon(Icons.clear_rounded, color: Colors.grey.shade500, size: 20),
                  onPressed: () {
                    _searchControllers[type]!.clear();
                    onChanged('');
                    FocusScope.of(context).unfocus();
                  },
                )
              : null,
          filled: true,
          fillColor: Colors.grey.shade50,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF6366F1), width: 1.5),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
        style: const TextStyle(fontSize: 14),
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off_rounded, size: 60, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            'No data found',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade500,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade400,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          if (_errorMessage != null)
            ElevatedButton(
              onPressed: _refreshData,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6366F1),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Try Again'),
            ),
        ],
      ),
    );
  }

  Widget _buildUniversityPage() {
    if (_isLoading && _universities.isEmpty) {
      return _buildLoadingState('Loading universities...');
    }

    if (_errorMessage != null && _universities.isEmpty) {
      return _buildEmptyState(_errorMessage!);
    }

    return _buildGridSelectionPage(
      title: 'Select Your University',
      subtitle: 'Choose your institution',
      items: _universities,
      selectedItem: _userData.university,
      onItemSelected: (university) async {
        setState(() {
          _userData = _userData.copyWith(university: university);
          _userData = _userData.copyWith(faculty: null, department: null);
          _faculties = [];
          _departments = [];
        });
        
        if (university.id.isNotEmpty) {
          await _loadFaculties(university.id);
        }
      },
      buildItem: _buildUniversityCard,
    );
  }

  Widget _buildFacultyPage() {
    if (_userData.university == null) {
      return _buildEmptyState('Please select a university first');
    }

    if (_isLoading && _faculties.isEmpty) {
      return _buildLoadingState('Loading faculties...');
    }

    if (_errorMessage != null && _faculties.isEmpty) {
      return _buildEmptyState(_errorMessage!);
    }

    final filteredFaculties = _faculties
        .where((faculty) => faculty.universityId == _userData.university?.id)
        .toList();

    return _buildListSelectionPage(
      title: 'Choose Your Faculty',
      subtitle: 'Select your faculty/school',
      items: filteredFaculties,
      selectedItem: _userData.faculty,
      onItemSelected: (faculty) async {
        setState(() {
          _userData = _userData.copyWith(faculty: faculty);
          _userData = _userData.copyWith(department: null);
          _departments = [];
        });
        
        if (faculty.id.isNotEmpty) {
          await _loadDepartments(faculty.id);
        }
      },
      buildItem: _buildFacultyCard,
    );
  }

  Widget _buildDepartmentPage() {
    if (_userData.faculty == null) {
      return _buildEmptyState('Please select a faculty first');
    }

    if (_isLoading && _departments.isEmpty) {
      return _buildLoadingState('Loading departments...');
    }

    if (_errorMessage != null && _departments.isEmpty) {
      return _buildEmptyState(_errorMessage!);
    }

    final filteredDepartments = _departments
        .where((dept) => dept.facultyId == _userData.faculty?.id)
        .toList();

    return _buildListSelectionPage(
      title: 'Pick Your Department',
      subtitle: 'Choose your department',
      items: filteredDepartments,
      selectedItem: _userData.department,
      onItemSelected: (department) {
        setState(() {
          _userData = _userData.copyWith(department: department);
        });
      },
      buildItem: _buildDepartmentCard,
    );
  }

  Widget _buildLevelPage() {
    if (_isLoading && _levels.isEmpty) {
      return _buildLoadingState('Loading levels...');
    }

    if (_errorMessage != null && _levels.isEmpty) {
      return _buildEmptyState(_errorMessage!);
    }

    return _buildGridSelectionPage(
      title: 'Select Your Level',
      subtitle: 'What year are you in?',
      items: _levels,
      selectedItem: _userData.level,
      onItemSelected: (level) {
        setState(() {
          _userData = _userData.copyWith(level: level);
        });
      },
      buildItem: _buildLevelCard,
      crossAxisCount: 2,
    );
  }

  Widget _buildSemesterPage() {
    if (_isLoading && _semesters.isEmpty) {
      return _buildLoadingState('Loading semesters...');
    }

    if (_errorMessage != null && _semesters.isEmpty) {
      return _buildEmptyState(_errorMessage!);
    }

    return Column(
      children: [
        const SizedBox(height: 20),
        ..._semesters.map((semester) {
          final isSelected = _userData.semester == semester;
          return _buildSemesterCard(semester, isSelected, () {
            setState(() {
              _userData = _userData.copyWith(semester: semester);
            });
          });
        }).toList(),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildLoadingState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6366F1)),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGridSelectionPage<T>({
    required String title,
    required String subtitle,
    required List<T> items,
    required T? selectedItem,
    required Function(T, bool, VoidCallback) buildItem,
    required Function(T) onItemSelected,
    int crossAxisCount = 3,
  }) {
    List<T> filteredItems = items;

    return StatefulBuilder(
      builder: (context, setState) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (title != 'Select Your Level')
              _buildSearchField(
                title.toLowerCase().contains('university') ? 'university' : 
                title.toLowerCase().contains('faculty') ? 'faculty' : 'department',
                'Search ${title.toLowerCase().replaceFirst('select ', '').replaceFirst('choose ', '').replaceFirst('pick ', '')}...',
                (query) {
                  setState(() {
                    filteredItems = items.where((item) {
                      final displayText = _getItemDisplayText(item);
                      return displayText.toLowerCase().contains(query.toLowerCase());
                    }).toList();
                  });
                },
              ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _refreshData,
                color: const Color(0xFF6366F1),
                child: filteredItems.isEmpty
                    ? _buildEmptyState('No ${title.toLowerCase().replaceFirst('select ', '').replaceFirst('choose ', '').replaceFirst('pick ', '')} found')
                    : GridView.builder(
                        padding: const EdgeInsets.only(bottom: 8),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: crossAxisCount,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 12,
                          childAspectRatio: crossAxisCount == 2 ? 1.6 : 0.9,
                        ),
                        itemCount: filteredItems.length,
                        itemBuilder: (context, index) {
                          final item = filteredItems[index];
                          final isSelected = selectedItem == item;
                          return buildItem(item, isSelected, () => onItemSelected(item));
                        },
                      ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildListSelectionPage<T>({
    required String title,
    required String subtitle,
    required List<T> items,
    required T? selectedItem,
    required Function(T, bool, VoidCallback) buildItem,
    required Function(T) onItemSelected,
  }) {
    List<T> filteredItems = items;

    return StatefulBuilder(
      builder: (context, setState) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSearchField(
              title.toLowerCase().contains('faculty') ? 'faculty' : 'department',
              'Search ${title.toLowerCase().replaceFirst('select ', '').replaceFirst('choose ', '').replaceFirst('pick ', '')}...',
              (query) {
                setState(() {
                  filteredItems = items.where((item) {
                    final displayText = _getItemDisplayText(item);
                    return displayText.toLowerCase().contains(query.toLowerCase());
                  }).toList();
                });
              },
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _refreshData,
                color: const Color(0xFF6366F1),
                child: filteredItems.isEmpty
                    ? _buildEmptyState('No ${title.toLowerCase().replaceFirst('select ', '').replaceFirst('choose ', '').replaceFirst('pick ', '')} found')
                    : ListView.builder(
                        padding: const EdgeInsets.only(bottom: 8),
                        itemCount: filteredItems.length,
                        itemBuilder: (context, index) {
                          final item = filteredItems[index];
                          final isSelected = selectedItem == item;
                          return buildItem(item, isSelected, () => onItemSelected(item));
                        },
                      ),
              ),
            ),
          ],
        );
      },
    );
  }

  String _getItemDisplayText(dynamic item) {
    if (item is University) return item.abbreviation ?? item.name;
    if (item is Faculty) return item.abbreviation ?? item.name;
    if (item is Department) return item.abbreviation ?? item.name;
    if (item is Level) return item.name;
    if (item is Semester) return item.name;
    return item.toString();
  }

  bool get _canProceed {
    switch (_currentPage) {
      case 0:
        return _userData.university != null;
      case 1:
        return _userData.faculty != null;
      case 2:
        return _userData.department != null;
      case 3:
        return _userData.level != null;
      case 4:
        return _userData.semester != null;
      default:
        return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && _currentPage == 0) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6366F1)),
              ),
              const SizedBox(height: 16),
              Text(
                _loadingMessage,
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.arrow_back_ios_new_rounded,
              size: 16,
              color: Colors.grey.shade700,
            ),
          ),
          onPressed: () => _currentPage > 0 ? _previousPage() : Navigator.pop(context),
        ),
        title: Text(
          'Step ${_currentPage + 1} of ${_onboardingSteps.length}',
          style: TextStyle(
            color: Colors.grey.shade600,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: LinearProgressIndicator(
                value: (_currentPage + 1) / _onboardingSteps.length,
                backgroundColor: Colors.grey.shade200,
                color: const Color(0xFF6366F1),
                borderRadius: BorderRadius.circular(8),
                minHeight: 6,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _onboardingSteps[_currentPage]['title'],
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1F2937),
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _onboardingSteps[_currentPage]['subtitle'],
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: PageView(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  onPageChanged: (page) {
                    setState(() => _currentPage = page);
                    _searchControllers.forEach((key, controller) => controller.clear());
                    _errorMessage = null;
                  },
                  children: [
                    _buildUniversityPage(),
                    _buildFacultyPage(),
                    _buildDepartmentPage(),
                    _buildLevelPage(),
                    _buildSemesterPage(),
                  ],
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
              child: Row(
                children: [
                  if (_currentPage > 0)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _previousPage,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF6366F1),
                          side: const BorderSide(color: Color(0xFF6366F1)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          textStyle: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        child: const Text('Back'),
                      ),
                    ),
                  if (_currentPage > 0) const SizedBox(width: 12),
                  Expanded(
                    flex: _currentPage > 0 ? 1 : 2,
                    child: ElevatedButton(
                      onPressed: _canProceed ? _nextPage : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6366F1),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        elevation: 1,
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : Text(
                              _currentPage == _onboardingSteps.length - 1 ? 'Continue' : 'Next',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
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