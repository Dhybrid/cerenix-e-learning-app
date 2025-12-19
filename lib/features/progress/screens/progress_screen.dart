import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../../core/network/api_service.dart';

class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key});

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  final ApiService _apiService = ApiService();
  
  bool _isLoading = true;
  double _overallProgress = 0.0;
  int _totalCourses = 0;
  int _completedCourses = 0;
  int _totalOutlines = 0;
  int _completedOutlines = 0;
  int _totalTopics = 0;
  int _completedTopics = 0;
  
  // Streak tracking variables
  int _currentStreak = 0;
  int _longestStreak = 0;
  int _totalOpenedDays = 0;
  List<DateTime> _openedDates = [];
  
  // Store course progress data
  List<Map<String, dynamic>> _courseProgressList = [];
  
  @override
  void initState() {
    super.initState();
    _initializeData();
  }
  
  Future<void> _initializeData() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      // First, record today's app open for streak tracking
      await _recordAppOpen();
      
      // Then load all other data
      await Future.wait([
        _loadStreakData(),
        _loadCoursesWithProgress(),
      ]);
      
      // Calculate overall progress
      await _calculateOverallProgress();
      
      setState(() {
        _isLoading = false;
      });
      
    } catch (e) {
      print('❌ Error initializing data: $e');
      setState(() {
        _isLoading = false;
      });
    }
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
      
      print('📱 Recorded app open for streak: $dateKey');
      
    } catch (e) {
      print('⚠️ Error recording app open: $e');
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
            print('⚠️ Error parsing date $key: $e');
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
        _openedDates = openedDates;
        _currentStreak = currentStreak;
        _longestStreak = longestStreak;
        _totalOpenedDays = openedDates.length;
      });
      
      print('📊 Streak data loaded:');
      print('   Current streak: $currentStreak days');
      print('   Longest streak: $longestStreak days');
      print('   Total days opened: ${openedDates.length}');
      
    } catch (e) {
      print('⚠️ Error loading streak data: $e');
      setState(() {
        _currentStreak = 0;
        _longestStreak = 0;
        _totalOpenedDays = 0;
        _openedDates = [];
      });
    }
  }
  
  Future<void> _loadCoursesWithProgress() async {
    try {
      final progressBox = await Hive.openBox('course_progress_cache');
      final keys = progressBox.keys.toList();
      
      List<Map<String, dynamic>> courses = [];
      
      for (var key in keys) {
        if (key.startsWith('progress_')) {
          final courseId = key.replaceFirst('progress_', '');
          final progressValue = progressBox.get('progress_$courseId');
          final lastUpdated = progressBox.get('last_updated_$courseId');
          
          // Convert progress to int safely
          int progress = 0;
          if (progressValue != null) {
            if (progressValue is int) {
              progress = progressValue;
            } else if (progressValue is double) {
              progress = progressValue.round();
            } else if (progressValue is num) {
              progress = progressValue.toInt();
            }
          }
          
          // Store course data in a map
          courses.add({
            'id': courseId,
            'progress': progress,
            'lastUpdated': lastUpdated,
            'code': 'CRS${courses.length + 1}',
            'title': 'Course ${courses.length + 1}',
            'color': _getCourseColor(courses.length + 1),
          });
        }
      }
      
      _courseProgressList = courses;
      
    } catch (e) {
      print('Error loading courses with progress: $e');
      _courseProgressList = [];
    }
  }
  
  Future<void> _calculateOverallProgress() async {
    if (_courseProgressList.isEmpty) {
      setState(() {
        _overallProgress = 0.0;
        _totalCourses = 0;
        _completedCourses = 0;
        _totalOutlines = 0;
        _completedOutlines = 0;
        _totalTopics = 0;
        _completedTopics = 0;
      });
      return;
    }
    
    int totalCourses = _courseProgressList.length;
    int completedCourses = 0;
    double totalProgressSum = 0.0;
    
    // Count completed courses (100% progress)
    for (var course in _courseProgressList) {
      final progress = course['progress'] ?? 0;
      totalProgressSum += progress.toDouble();
      if (progress == 100) {
        completedCourses++;
      }
    }
    
    // Calculate overall progress average
    final double overallProgress = totalCourses > 0 ? totalProgressSum / totalCourses : 0.0;
    
    // For now, we'll skip the detailed outline/topic calculation since it requires API calls
    // You can add this later if needed
    
    setState(() {
      _overallProgress = overallProgress;
      _totalCourses = totalCourses;
      _completedCourses = completedCourses;
      // Setting placeholder values for now
      _totalOutlines = totalCourses * 3; // Estimate
      _completedOutlines = completedCourses * 3; // Estimate
      _totalTopics = totalCourses * 9; // Estimate
      _completedTopics = (totalProgressSum / 100 * totalCourses * 9).toInt(); // Estimate
    });
  }
  
  Color _getCourseColor(int index) {
    final colors = [
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.red,
      Colors.teal,
      Colors.indigo,
    ];
    return colors[index % colors.length];
  }
  
  double _getLearningRateScore() {
    // Calculate learning rate based on streak consistency and progress
    final double consistencyScore = (_currentStreak / 30) * 50; // Max 50 points for consistency
    final double progressScore = (_overallProgress / 100) * 50; // Max 50 points for progress
    
    // Cap scores at their maximum
    final double finalConsistency = consistencyScore.clamp(0, 50).toDouble();
    final double finalProgress = progressScore.clamp(0, 50).toDouble();
    
    return finalConsistency + finalProgress;
  }
  
  String _getLearningRateCategory(double score) {
    if (score >= 90) return 'Excellent';
    if (score >= 75) return 'Fast';
    if (score >= 60) return 'Good';
    if (score >= 40) return 'Moderate';
    return 'Beginner';
  }
  
  Color _getLearningRateColor(double score) {
    if (score >= 90) return Colors.green;
    if (score >= 75) return Colors.blue;
    if (score >= 60) return Colors.orange;
    if (score >= 40) return Colors.yellow[700]!;
    return Colors.grey;
  }
  
  String _getStreakMessage(int streak) {
    if (streak >= 30) {
      return 'Incredible! $streak consecutive days! 🎉';
    } else if (streak >= 14) {
      return 'Great consistency! $streak days in a row!';
    } else if (streak >= 7) {
      return 'One week streak! Building strong habits!';
    } else if (streak >= 3) {
      return 'Nice start! $streak day streak. Keep it up!';
    } else {
      return 'Starting your streak! Come back tomorrow!';
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Progress',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.black,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _initializeData,
            tooltip: 'Refresh Progress',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _initializeData,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Streak Section - UPDATED with real streak data
                    _buildStreakSection(),
                    const SizedBox(height: 24),
                    
                    // Stats Cards
                    _buildStatsSection(),
                    const SizedBox(height: 24),
                    
                    // Progress Overview
                    _buildProgressOverview(),
                    const SizedBox(height: 24),
                    
                    // Learning Rate
                    _buildLearningRate(),
                    const SizedBox(height: 24),
                    
                    // Final Remark
                    _buildFinalRemark(),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
    );
  }
  
  Widget _buildStreakSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.orange.shade400, Colors.red.shade400],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.orange.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(Icons.local_fire_department, color: Colors.white.withOpacity(0.8), size: 28),
              Column(
                children: [
                  Text(
                    '$_currentStreak',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 42,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Text(
                    'days',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              Icon(Icons.celebration, color: Colors.white.withOpacity(0.8), size: 28),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Current Streak',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _currentStreak > 0
                ? _getStreakMessage(_currentStreak)
                : 'Open the app tomorrow to start your streak!',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 14,
              height: 1.4,
            ),
          ),
          
          // Additional streak stats
          if (_totalOpenedDays > 0)
            Container(
              margin: const EdgeInsets.only(top: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildMiniStat('Longest', '$_longestStreak'),
                  Container(
                    width: 1,
                    height: 30,
                    color: Colors.white.withOpacity(0.3),
                  ),
                  _buildMiniStat('Total Days', '$_totalOpenedDays'),
                ],
              ),
            ),
        ],
      ),
    );
  }
  
  Widget _buildMiniStat(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.8),
            fontSize: 12,
          ),
        ),
      ],
    );
  }
  
  Widget _buildStatsSection() {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            'Overall Progress',
            '${_overallProgress.toStringAsFixed(1)}%',
            const Color(0xFFECFDF5),
            const Color(0xFF065F46),
            Icons.trending_up,
            Colors.green,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            'Completed Courses',
            '$_completedCourses/$_totalCourses',
            const Color(0xFFEFF6FF),
            const Color(0xFF1E40AF),
            Icons.school,
            Colors.blue,
          ),
        ),
      ],
    );
  }
  
  Widget _buildStatCard(String title, String value, Color bgColor, Color textColor, IconData icon, Color iconColor) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
        border: Border.all(color: bgColor.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: textColor.withOpacity(0.8),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildProgressOverview() {
    if (_courseProgressList.isEmpty) {
      return _buildEmptyState();
    }
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Course Progress',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 20),
          
          // Show top 3 courses
          ..._courseProgressList.take(3).map((courseData) {
            return Column(
              children: [
                _buildCourseProgressItem(courseData),
                if (_courseProgressList.indexOf(courseData) < _courseProgressList.take(3).length - 1)
                  const SizedBox(height: 16),
              ],
            );
          }).toList(),
          
          if (_courseProgressList.length > 3)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Center(
                child: Text(
                  '+ ${_courseProgressList.length - 3} more courses',
                  style: const TextStyle(
                    color: Colors.blue,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          
          const SizedBox(height: 20),
          
          // Additional stats
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _AdditionalStat(
                title: 'Topics Completed',
                value: '$_completedTopics/$_totalTopics',
              ),
              _AdditionalStat(
                title: 'Outlines Completed',
                value: '$_completedOutlines/$_totalOutlines',
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildCourseProgressItem(Map<String, dynamic> courseData) {
    final progress = courseData['progress'] ?? 0;
    final code = courseData['code'] ?? 'CRS';
    final color = courseData['color'] ?? Colors.blue;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Text(
                code,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              '$progress%',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: progress == 100 ? Colors.green : color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          height: 8,
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            children: [
              Container(
                width: (progress / 100) * (MediaQuery.of(context).size.width - 80),
                height: 8,
                decoration: BoxDecoration(
                  color: progress == 100 ? Colors.green : color,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
  
  Widget _buildLearningRate() {
    final learningRateScore = _getLearningRateScore();
    final learningRateCategory = _getLearningRateCategory(learningRateScore);
    final learningRateColor = _getLearningRateColor(learningRateScore);
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Learning Rate',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 20),
          
          Center(
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 120,
                  height: 120,
                  child: CircularProgressIndicator(
                    value: learningRateScore / 100,
                    strokeWidth: 12,
                    backgroundColor: Colors.grey.shade200,
                    valueColor: AlwaysStoppedAnimation<Color>(learningRateColor),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${learningRateScore.toStringAsFixed(0)}%',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: learningRateColor,
                      ),
                    ),
                    Text(
                      learningRateCategory,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Center(
            child: Text(
              'Based on your progress and consistency',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildFinalRemark() {
    String title;
    String message;
    IconData icon;
    
    // Updated to consider streak for final remark
    if (_currentStreak >= 30) {
      title = 'Legendary Streak!';
      message = '30+ consecutive days! Your dedication is inspiring! 🏆';
      icon = Icons.emoji_events;
    } else if (_currentStreak >= 14) {
      title = 'Amazing Consistency!';
      message = 'Two weeks strong! Keep building this daily habit!';
      icon = Icons.star;
    } else if (_currentStreak >= 7) {
      title = 'Great Habit!';
      message = 'One week streak! Your consistency is paying off!';
      icon = Icons.trending_up;
    } else if (_currentStreak >= 3) {
      title = 'Building Momentum!';
      message = 'Nice streak! Come back tomorrow to keep it going!';
      icon = Icons.directions_walk;
    } else if (_overallProgress >= 90) {
      title = 'Outstanding Progress!';
      message = 'You\'re almost at 100% completion! Keep up the excellent work!';
      icon = Icons.emoji_events;
    } else if (_overallProgress >= 70) {
      title = 'Great Progress!';
      message = 'You\'re making excellent progress. Keep maintaining this pace!';
      icon = Icons.star;
    } else if (_overallProgress >= 50) {
      title = 'Good Progress!';
      message = 'You\'re halfway there! Consistency will help you reach your goals.';
      icon = Icons.trending_up;
    } else if (_overallProgress >= 25) {
      title = 'Making Progress!';
      message = 'You\'ve started your learning journey. Keep going every day!';
      icon = Icons.directions_walk;
    } else {
      title = 'Ready to Start!';
      message = 'Begin your learning journey today. Every step counts!';
      icon = Icons.play_arrow;
    }
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF10B981).withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: const Color(0xFF10B981), size: 28),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF065F46),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            message,
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
  
  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(Icons.school, size: 60, color: Colors.grey[400]),
          const SizedBox(height: 20),
          const Text(
            'Start Your Learning Journey',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF666666),
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Begin learning courses to track your progress and build streaks!',
            style: TextStyle(
              color: Color(0xFF999999),
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _initializeData,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text(
              'Start Learning',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

class _AdditionalStat extends StatelessWidget {
  final String title;
  final String value;

  const _AdditionalStat({
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }
}