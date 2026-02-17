// lib/features/documents/screens/study_guide_screen.dart
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:hive_flutter/hive_flutter.dart';

// Import your existing models and services
import '../models/document_model.dart';
import '../services/download_service.dart';
import 'document_viewer_screen.dart';
import '../../../core/network/api_service.dart';

class StudyGuideScreen extends StatefulWidget {
  final String university;
  final String department;
  final int level;
  final int semester;

  const StudyGuideScreen({
    super.key,
    required this.university,
    required this.department,
    required this.level,
    required this.semester,
  });

  @override
  State<StudyGuideScreen> createState() => _StudyGuideScreenState();
}

class _StudyGuideScreenState extends State<StudyGuideScreen> {
  List<StudyDocument> _studyDocs = [];
  bool _isLoading = true;
  String? _errorMessage;
  String _userDepartment = '';
  String _userUniversity = '';
  int _userLevel = 0; // ADD THIS - store the actual user level
  int _userSemester = 0; // ADD THIS - store the actual user semester
  Map<String, bool> _downloadingFiles = {}; // Track downloading files

  // ========== ACTIVATION STATE ==========
  bool _isUserActivated = false;
  bool _checkingActivation = false;
  String _activationStatusMessage = 'Checking activation status...';
  // ========== END ACTIVATION STATE ==========

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    await _getUserAcademicInfo();
    await _checkActivationStatus(forceRefresh: true);
    await _loadStudyDocuments();
    // await _getUserAcademicInfo();
  }

  // ========== ACTIVATION STATUS CHECK ==========
  Future<void> _checkActivationStatus({bool forceRefresh = false}) async {
    setState(() {
      _checkingActivation = true;
    });

    try {
      final activationBox = await Hive.openBox('activation_cache');

      if (!forceRefresh) {
        // Try cached data first
        final cachedActivation = activationBox.get('user_activated');
        final cachedTimestamp = activationBox.get('activation_timestamp');

        if (cachedActivation != null && cachedTimestamp != null) {
          final timestamp = DateTime.parse(cachedTimestamp);
          final now = DateTime.now();
          final difference = now.difference(timestamp);

          // Use cached data if it's less than 5 minutes old
          if (difference.inMinutes < 5) {
            setState(() {
              _isUserActivated = cachedActivation;
              _checkingActivation = false;
              _activationStatusMessage = _isUserActivated
                  ? 'Account activated'
                  : 'Account not activated';
            });
            print('✅ Docs: Using cached activation status: $_isUserActivated');
            return;
          }
        }
      }

      // Always fetch fresh data when forceRefresh is true or cache expired
      try {
        final activationData = await ApiService().getActivationStatus();

        if (activationData != null && activationData.isValid) {
          setState(() {
            _isUserActivated = true;
            _activationStatusMessage =
                '${activationData.grade?.toUpperCase() ?? 'Activated'}';
          });

          // Cache the result with timestamp
          await activationBox.put('user_activated', true);
          await activationBox.put(
            'activation_timestamp',
            DateTime.now().toIso8601String(),
          );
          await activationBox.put('activation_grade', activationData.grade);
          print('✅ Docs: User is activated: ${activationData.grade}');
        } else {
          setState(() {
            _isUserActivated = false;
            _activationStatusMessage = 'Not Activated';
          });

          // Cache the result
          await activationBox.put('user_activated', false);
          await activationBox.put(
            'activation_timestamp',
            DateTime.now().toIso8601String(),
          );
          print('ℹ️ Docs: User is not activated');
        }
      } catch (e) {
        print('❌ Docs: Error fetching activation from API: $e');

        // Fallback to cached data if available
        final cachedActivation = activationBox.get('user_activated');
        if (cachedActivation != null) {
          setState(() {
            _isUserActivated = cachedActivation;
            _activationStatusMessage = _isUserActivated
                ? 'Account activated (offline)'
                : 'Account not activated (offline)';
          });
        } else {
          setState(() {
            _isUserActivated = false;
            _activationStatusMessage = 'Not Activated (offline)';
          });
        }
      }
    } catch (e) {
      print('❌ Docs: Error in activation check: $e');
      setState(() {
        _isUserActivated = false;
        _activationStatusMessage = 'Error checking activation';
      });
    } finally {
      if (mounted) {
        setState(() {
          _checkingActivation = false;
        });
      }
    }
  }

  // ========== ACTIVATION BANNER ==========
  Widget _buildActivationBanner() {
    return GestureDetector(
      onTap: () async {
        final result = await Navigator.pushNamed(context, '/activation');
        if (mounted) {
          await _checkActivationStatus(forceRefresh: true);
        }
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.orange.shade50,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.orange.shade200, width: 1.5),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.orange.shade100,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.lock_outline_rounded,
                color: Colors.orange.shade600,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Account Not Activated',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange.shade800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Documents are visible but cannot be opened or downloaded. Tap to activate your account.',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.orange.shade700,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              color: Colors.orange.shade600,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }

  // Future<void> _getUserAcademicInfo() async {
  //   try {
  //     final apiService = ApiService();
  //     final userData = await apiService.getCurrentUser();

  //     if (userData != null) {
  //       print('📋 StudyGuide: User data received: $userData');

  //       // Extract university name - following ProfileDetailsScreen pattern
  //       if (userData['university'] is Map) {
  //         _userUniversity =
  //             userData['university']['name'] ?? 'Unknown University';
  //         print('✅ StudyGuide: University from map: $_userUniversity');
  //       } else if (userData['university_name'] != null) {
  //         _userUniversity = userData['university_name'];
  //         print('✅ StudyGuide: University from string: $_userUniversity');
  //       } else if (userData['profile'] != null &&
  //           userData['profile']['university'] != null) {
  //         final profile = userData['profile'];
  //         if (profile['university'] is Map) {
  //           _userUniversity =
  //               profile['university']['name'] ?? 'Unknown University';
  //         } else if (profile['university_name'] != null) {
  //           _userUniversity = profile['university_name'];
  //         }
  //       }

  //       // Extract department name - following ProfileDetailsScreen pattern
  //       if (userData['department'] is Map) {
  //         _userDepartment =
  //             userData['department']['abbreviation'] ??
  //             userData['department']['name'] ??
  //             'Unknown Department';
  //         print('✅ StudyGuide: Department from map: $_userDepartment');
  //       } else if (userData['department_name'] != null) {
  //         _userDepartment = userData['department_name'];
  //         print('✅ StudyGuide: Department from string: $_userDepartment');
  //       } else if (userData['profile'] != null &&
  //           userData['profile']['department'] != null) {
  //         final profile = userData['profile'];
  //         if (profile['department'] is Map) {
  //           _userDepartment =
  //               profile['department']['abbreviation'] ??
  //               profile['department']['name'] ??
  //               'Unknown Department';
  //         } else if (profile['department_name'] != null) {
  //           _userDepartment = profile['department_name'];
  //         }
  //       }

  //       // Extract level information
  //       if (userData['level'] is Map) {
  //         final levelName = userData['level']['name'] ?? '';
  //         print('✅ StudyGuide: Level name from map: $levelName');
  //       }

  //       // Extract semester information
  //       if (userData['semester'] is Map) {
  //         final semesterName = userData['semester']['name'] ?? '';
  //         print('✅ StudyGuide: Semester name from map: $semesterName');
  //       }

  //       print('✅ StudyGuide: Final academic info:');
  //       print('   - University: $_userUniversity');
  //       print('   - Department: $_userDepartment');

  //       setState(() {});
  //     } else {
  //       print('⚠️ StudyGuide: No user data found');
  //     }
  //   } catch (e) {
  //     print('❌ StudyGuide: Error getting user academic info: $e');
  //   }
  // }

  Future<void> _getUserAcademicInfo() async {
    try {
      final apiService = ApiService();
      final userData = await apiService.getCurrentUser();

      if (userData != null) {
        print('📋 StudyGuide: User data received: $userData');

        // Extract university name
        if (userData['university'] is Map) {
          _userUniversity =
              userData['university']['name'] ?? 'Unknown University';
        } else if (userData['university_name'] != null) {
          _userUniversity = userData['university_name'];
        }

        // Extract department name
        if (userData['department'] is Map) {
          _userDepartment =
              userData['department']['abbreviation'] ??
              userData['department']['name'] ??
              'Unknown Department';
        } else if (userData['department_name'] != null) {
          _userDepartment = userData['department_name'];
        }

        // EXTRACT LEVEL - THIS IS CRITICAL
        if (userData['level'] is Map) {
          // Get level number from the level object
          final levelMap = userData['level'] as Map;

          // Try different ways to get the level number
          if (levelMap['level_number'] != null) {
            _userLevel = int.tryParse(levelMap['level_number'].toString()) ?? 0;
          } else if (levelMap['name'] != null) {
            final levelName = levelMap['name'].toString();
            // Extract number from names like "100 Level", "Level 100", etc.
            final match = RegExp(r'(\d+)').firstMatch(levelName);
            if (match != null) {
              final levelNum = int.tryParse(match.group(1) ?? '') ?? 0;
              // Convert 100 -> 1, 200 -> 2, etc.
              _userLevel = levelNum ~/ 100;
            }
          } else if (levelMap['id'] != null) {
            // If all else fails, use the ID as a fallback
            _userLevel = int.tryParse(levelMap['id'].toString()) ?? 0;
          }
        } else if (userData['level_id'] != null) {
          _userLevel = int.tryParse(userData['level_id'].toString()) ?? 0;
        } else if (userData['level_name'] != null) {
          final levelName = userData['level_name'].toString();
          final match = RegExp(r'(\d+)').firstMatch(levelName);
          if (match != null) {
            final levelNum = int.tryParse(match.group(1) ?? '') ?? 0;
            _userLevel = levelNum ~/ 100;
          }
        }

        // EXTRACT SEMESTER
        if (userData['semester'] is Map) {
          final semesterMap = userData['semester'] as Map;

          if (semesterMap['semester_number'] != null) {
            _userSemester =
                int.tryParse(semesterMap['semester_number'].toString()) ?? 1;
          } else if (semesterMap['name'] != null) {
            final semesterName = semesterMap['name'].toString().toLowerCase();
            if (semesterName.contains('first') || semesterName.contains('1')) {
              _userSemester = 1;
            } else if (semesterName.contains('second') ||
                semesterName.contains('2')) {
              _userSemester = 2;
            } else {
              _userSemester = 1; // default
            }
          }
        } else if (userData['semester_id'] != null) {
          _userSemester = int.tryParse(userData['semester_id'].toString()) ?? 1;
        }

        print('✅ StudyGuide: Final academic info:');
        print('   - University: $_userUniversity');
        print('   - Department: $_userDepartment');
        print('   - Level: $_userLevel (${_userLevel * 100} Level)');
        print('   - Semester: $_userSemester');

        setState(() {});
      } else {
        print('⚠️ StudyGuide: No user data found');
      }
    } catch (e) {
      print('❌ StudyGuide: Error getting user academic info: $e');
    }
  }

  Future<void> _loadStudyDocuments() async {
    print('🔄 Starting study guide load...');

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final apiService = ApiService();

      // Get study guides from API
      print('📡 Calling getStudyGuidesForUser()...');
      _studyDocs = await apiService.getStudyGuidesForUser();

      print('📊 Loaded ${_studyDocs.length} study guides');

      // Filter out any demo data that might have been added
      _studyDocs = _studyDocs.where((doc) {
        // Remove any docs with example.com URLs or fake data
        if (doc.fileUrl.contains('example.com') ||
            doc.fileUrl.isEmpty ||
            doc.title.contains('Sample') ||
            (doc.title.contains('Introduction to Programming') &&
                _userDepartment != 'Computer Science')) {
          return false;
        }
        return true;
      }).toList();

      if (_studyDocs.isEmpty) {
        print('ℹ️ No real study guides found after filtering.');
      }
    } catch (e) {
      _errorMessage =
          'Failed to load study materials. Please check your connection and try again.';
      print('❌ Error loading study guides: $e');

      // NO DEMO DATA - keep list empty
      _studyDocs = [];
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // NEW: Open document for viewing (stream or use downloaded file)
  Future<void> _openDocumentForViewing(StudyDocument doc) async {
    // Check if user is activated
    if (!_isUserActivated) {
      _showActivationRequiredDialog();
      return;
    }

    print('📖 Opening document for viewing: ${doc.title}');
    print('📎 File URL: ${doc.fileUrl}');

    try {
      // Show loading dialog
      _showLoadingDialog('Opening document...');

      // Check if file is already downloaded
      final isDownloaded = await DocumentDownloadService.isPdfDownloaded(
        doc.fileName,
      );

      String filePath;
      int fileSize;

      if (isDownloaded) {
        // Use downloaded file from protected storage
        final localPath = await DocumentDownloadService.getLocalPath(
          doc.fileName,
        );
        if (localPath == null) {
          Navigator.pop(context); // Close dialog
          _showError('Downloaded file not found');
          return;
        }

        filePath = localPath;
        final file = File(filePath);
        fileSize = file.lengthSync();
        print('✅ Using downloaded file: $filePath');
      } else {
        // Get file from temp storage or download it
        final tempFile = await DocumentDownloadService.getPdfForViewing(
          url: doc.fileUrl,
          fileName: doc.fileName,
        );

        if (tempFile == null) {
          Navigator.pop(context); // Close dialog
          _showError('Could not load document for viewing');
          return;
        }

        filePath = tempFile.path;
        fileSize = tempFile.lengthSync();
        print('✅ Using temp file for viewing: $filePath');
      }

      Navigator.pop(context); // Close loading dialog

      // Create DocumentItem
      final documentItem = DocumentItem.fromStudyGuide(
        id: doc.id,
        fileName: doc.fileName,
        path: filePath,
        size: fileSize,
        courseCode: doc.courseCode,
        courseName: doc.courseName,
        university: doc.university,
        department: doc.department,
        fileSizeFormatted: doc.fileSize,
        originalUrl: doc.fileUrl,
      );

      // Open in viewer
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => DocumentViewerScreen(
            document: documentItem,
            isOnlineViewing: !isDownloaded, // Track if viewing online
          ),
        ),
      );

      // Refresh download status
      _refreshDownloadStatus();
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context); // Close dialog if still open
      }
      print('❌ Error opening document: $e');
      _showError('Cannot open document: ${e.toString()}');
    }
  }

  // Download document for offline use
  Future<void> _downloadDocumentForOffline(StudyDocument doc) async {
    // Check if user is activated
    if (!_isUserActivated) {
      _showActivationRequiredDialog();
      return;
    }

    if (_downloadingFiles[doc.id] == true) {
      print('⏳ Already downloading: ${doc.title}');
      return;
    }

    print('⬇️ Starting download for offline: ${doc.title}');
    print('📎 File URL: ${doc.fileUrl}');

    try {
      setState(() {
        _downloadingFiles[doc.id] = true;
      });

      // Show downloading dialog
      _showDownloadingDialog(doc.title);

      File? downloadedFile;

      // Check if it's a Cloudinary URL
      final isCloudinary = doc.fileUrl.contains('cloudinary.com');
      print('☁️ Is Cloudinary URL: $isCloudinary');

      if (isCloudinary) {
        print('☁️ Using Cloudinary download...');
        downloadedFile = await DocumentDownloadService.downloadCloudinaryPdf(
          cloudinaryUrl: doc.fileUrl,
          fileName: doc.fileName,
        );
      } else {
        print('🌐 Using regular download...');
        downloadedFile = await DocumentDownloadService.downloadPdf(
          url: doc.fileUrl,
          fileName: doc.fileName,
        );
      }

      if (context.mounted) {
        Navigator.pop(context); // Close dialog
      }

      if (downloadedFile != null) {
        print('✅ Download successful: ${downloadedFile.path}');
        print('📊 File size: ${downloadedFile.lengthSync()} bytes');

        _showMessage('Downloaded successfully! Now available offline.');

        // Update UI to show downloaded status
        _refreshDownloadStatus();
      } else {
        _showError('Failed to download PDF');
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context); // Close dialog
      }
      print('❌ Download error: $e');
      _showError('Error downloading: ${e.toString()}');
    } finally {
      setState(() {
        _downloadingFiles[doc.id] = false;
      });
    }
  }

  void _refreshDownloadStatus() {
    setState(() {});
  }

  void _showActivationRequiredDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Account Not Activated'),
        icon: Icon(
          Icons.lock_outline_rounded,
          size: 40,
          color: Colors.orange.shade600,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'You need to activate your account to access documents.',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.remove_red_eye,
                        size: 16,
                        color: Colors.orange.shade700,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Documents are visible',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Colors.orange.shade800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.lock, size: 16, color: Colors.orange.shade700),
                      const SizedBox(width: 8),
                      Text(
                        'Cannot open or download',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Colors.orange.shade800,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final result = await Navigator.pushNamed(context, '/activation');
              if (mounted) {
                await _checkActivationStatus(forceRefresh: true);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange.shade600,
            ),
            child: const Text(
              'Activate Now',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  void _showLoadingDialog(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Loading'),
        content: SizedBox(
          height: 100,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDownloadingDialog(String fileName) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Downloading PDF'),
        content: SizedBox(
          height: 120,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(
                'Downloading: $fileName',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 8),
              const Text(
                'For offline use...',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 8),
              const Text(
                'Please wait...',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            _buildHeader(),

            // Main Content
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(30),
                    topRight: Radius.circular(30),
                  ),
                ),
                child: _buildContent(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final displayDepartment = _userDepartment.isNotEmpty
        ? _userDepartment
        : widget.department;
    final displayUniversity = _userUniversity.isNotEmpty
        ? _userUniversity
        : widget.university;

    // Use actual user level if available, otherwise fall back to widget level
    final int actualLevel = _userLevel > 0 ? _userLevel : widget.level;

    // Convert level number to display format (100, 200, etc.)
    // Convert level number to display format (100, 200, etc.)
    String levelDisplay;
    if (actualLevel == 1) {
      // ← FIX: Use actualLevel here
      levelDisplay = '100';
    } else if (actualLevel == 2) {
      levelDisplay = '200';
    } else if (actualLevel == 3) {
      levelDisplay = '300';
    } else if (actualLevel == 4) {
      levelDisplay = '400';
    } else if (actualLevel == 5) {
      levelDisplay = '500';
    } else {
      levelDisplay = actualLevel.toString();
    }

    // Use actual semester if available
    final int actualSemester = _userSemester > 0
        ? _userSemester
        : widget.semester;

    return Container(
      color: Colors.black,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white, size: 24),
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Study Guide',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$displayDepartment • Level $levelDisplay • Sem $actualSemester',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 12,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (displayUniversity.isNotEmpty)
                  Text(
                    displayUniversity,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 11,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          // Activation indicator
          if (!_checkingActivation && !_isUserActivated)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: Colors.orange.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.lock_outline_rounded,
                    size: 14,
                    color: Colors.orange.shade700,
                  ),
                  const SizedBox(width: 4),
                  const Text(
                    'Limited',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.orange,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          // Refresh button
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white, size: 22),
            onPressed: _loadInitialData,
            tooltip: 'Refresh',
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return Column(
      children: [
        // Activation banner for non-activated users
        if (!_isUserActivated && !_checkingActivation) _buildActivationBanner(),

        // Info Card
        _buildInfoCard(),

        // Documents List
        Expanded(
          child: _isLoading
              ? _buildLoadingState()
              : _errorMessage != null
              ? _buildErrorState()
              : _studyDocs.isEmpty
              ? _buildEmptyState()
              : _buildDocumentsList(),
        ),
      ],
    );
  }

  Widget _buildInfoCard() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade100),
      ),
      child: Row(
        children: [
          Icon(Icons.info, color: Colors.blue.shade600, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Study Materials',
                  style: TextStyle(
                    color: Colors.blue.shade800,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                if (_isUserActivated)
                  RichText(
                    text: TextSpan(
                      style: TextStyle(
                        color: Colors.blue.shade700,
                        fontSize: 12,
                      ),
                      children: [
                        const TextSpan(text: '• Tap to view (online)\n'),
                        const TextSpan(
                          text: '• Long press to download for offline use\n',
                        ),
                        const TextSpan(text: '• Downloaded files are '),
                        TextSpan(
                          text: 'app-protected',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade900,
                          ),
                        ),
                        const TextSpan(
                          text: ' - other apps cannot access them',
                        ),
                      ],
                    ),
                  )
                else
                  RichText(
                    text: TextSpan(
                      style: TextStyle(
                        color: Colors.blue.shade700,
                        fontSize: 12,
                      ),
                      children: [
                        const TextSpan(text: '• Documents are '),
                        TextSpan(
                          text: 'visible',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade900,
                          ),
                        ),
                        const TextSpan(
                          text: ' but cannot be opened or downloaded\n',
                        ),
                        const TextSpan(
                          text: '• Activate your account to unlock full access',
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          const Text(
            'Loading Study Materials...',
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
          const SizedBox(height: 8),
          Text(
            'Fetching guides for ${_userDepartment.isNotEmpty ? _userDepartment : widget.department}',
            style: const TextStyle(fontSize: 12, color: Colors.grey),
            textAlign: TextAlign.center,
          ),
          if (_checkingActivation) const SizedBox(height: 8),
          if (_checkingActivation)
            Text(
              _activationStatusMessage,
              style: const TextStyle(fontSize: 12, color: Colors.orange),
            ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 80, color: Colors.red),
            const SizedBox(height: 16),
            const Text(
              'Error Loading',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.red,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  const Text(
                    'Could not load study materials',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: Colors.red),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _errorMessage ?? 'Unknown error',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 12, color: Colors.red),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: _loadInitialData,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                  child: const Text('Try Again'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Widget _buildEmptyState() {
  //   return SingleChildScrollView(
  //     padding: const EdgeInsets.all(32.0),
  //     child: Center(
  //       child: Column(
  //         mainAxisAlignment: MainAxisAlignment.center,
  //         mainAxisSize: MainAxisSize.min,
  //         children: [
  //           Icon(Icons.library_books, size: 80, color: Colors.grey.shade400),
  //           const SizedBox(height: 16),
  //           const Text(
  //             'No Study Materials Available',
  //             style: TextStyle(
  //               fontSize: 20,
  //               fontWeight: FontWeight.w600,
  //               color: Colors.grey,
  //             ),
  //             textAlign: TextAlign.center,
  //           ),
  //           const SizedBox(height: 12),
  //           Container(
  //             padding: const EdgeInsets.all(16),
  //             decoration: BoxDecoration(
  //               color: Colors.grey.shade100,
  //               borderRadius: BorderRadius.circular(12),
  //             ),
  //             child: Column(
  //               mainAxisSize: MainAxisSize.min,
  //               children: [
  //                 const Text(
  //                   'Currently no study guides available for:',
  //                   textAlign: TextAlign.center,
  //                   style: TextStyle(fontSize: 14, color: Colors.grey),
  //                 ),
  //                 const SizedBox(height: 12),
  //                 _buildAcademicInfoCard(),
  //                 const SizedBox(height: 16),
  //                 const Text(
  //                   'Study guides will appear here once they are uploaded for your specific academic profile.',
  //                   textAlign: TextAlign.center,
  //                   style: TextStyle(
  //                     fontSize: 12,
  //                     color: Colors.grey,
  //                     height: 1.5,
  //                   ),
  //                 ),
  //               ],
  //             ),
  //           ),
  //           const SizedBox(height: 20),
  //           ElevatedButton(
  //             onPressed: _loadInitialData,
  //             style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
  //             child: const Text('Refresh'),
  //           ),
  //         ],
  //       ),
  //     ),
  //   );
  // }

  Widget _buildEmptyState() {
    final displayDepartment = _userDepartment.isNotEmpty
        ? _userDepartment
        : widget.department;
    final displayUniversity = _userUniversity.isNotEmpty
        ? _userUniversity
        : widget.university;

    // Use actual user level if available
    final int actualLevel = _userLevel > 0 ? _userLevel : widget.level;

    // Convert level number to display format
    String levelDisplay;
    if (actualLevel == 1) {
      levelDisplay = '100';
    } else if (actualLevel == 2) {
      levelDisplay = '200';
    } else if (actualLevel == 3) {
      levelDisplay = '300';
    } else if (actualLevel == 4) {
      levelDisplay = '400';
    } else if (actualLevel == 5) {
      levelDisplay = '500';
    } else {
      levelDisplay = actualLevel.toString();
    }

    // Use actual semester if available
    final int actualSemester = _userSemester > 0
        ? _userSemester
        : widget.semester;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(32.0),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.library_books, size: 80, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            const Text(
              'No Study Materials Available',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Currently no study guides available for:',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                  const SizedBox(height: 12),
                  _buildAcademicInfoCard(),
                  const SizedBox(height: 16),
                  Text(
                    'Study guides will appear here once they are uploaded for:',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$displayDepartment • Level $levelDisplay • Semester $actualSemester',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _loadInitialData,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
              child: const Text('Refresh'),
            ),
          ],
        ),
      ),
    );
  }

  // Widget _buildAcademicInfoCard() {
  //   final displayDepartment = _userDepartment.isNotEmpty
  //       ? _userDepartment
  //       : widget.department;
  //   final displayUniversity = _userUniversity.isNotEmpty
  //       ? _userUniversity
  //       : widget.university;

  //   return Container(
  //     padding: const EdgeInsets.all(12),
  //     decoration: BoxDecoration(
  //       color: Colors.white,
  //       borderRadius: BorderRadius.circular(8),
  //       border: Border.all(color: Colors.grey.shade300),
  //     ),
  //     child: Column(
  //       children: [
  //         if (displayUniversity.isNotEmpty)
  //           Row(
  //             children: [
  //               const Icon(Icons.school, size: 16, color: Colors.blue),
  //               const SizedBox(width: 8),
  //               Expanded(
  //                 child: Text(
  //                   displayUniversity,
  //                   style: const TextStyle(
  //                     fontSize: 14,
  //                     fontWeight: FontWeight.w500,
  //                   ),
  //                 ),
  //               ),
  //             ],
  //           ),
  //         if (displayUniversity.isNotEmpty && displayDepartment.isNotEmpty)
  //           const SizedBox(height: 8),
  //         if (displayDepartment.isNotEmpty)
  //           Row(
  //             children: [
  //               const Icon(Icons.business, size: 16, color: Colors.blue),
  //               const SizedBox(width: 8),
  //               Expanded(
  //                 child: Text(
  //                   displayDepartment,
  //                   style: const TextStyle(
  //                     fontSize: 14,
  //                     fontWeight: FontWeight.w500,
  //                   ),
  //                 ),
  //               ),
  //             ],
  //           ),
  //         const SizedBox(height: 8),
  //         Row(
  //           children: [
  //             const Icon(Icons.auto_stories, size: 16, color: Colors.blue),
  //             const SizedBox(width: 8),
  //             Text(
  //               'Level ${widget.level} • Semester ${widget.semester}',
  //               style: const TextStyle(
  //                 fontSize: 14,
  //                 fontWeight: FontWeight.w500,
  //               ),
  //             ),
  //           ],
  //         ),
  //       ],
  //     ),
  //   );
  // }

  Widget _buildAcademicInfoCard() {
    final displayDepartment = _userDepartment.isNotEmpty
        ? _userDepartment
        : widget.department;
    final displayUniversity = _userUniversity.isNotEmpty
        ? _userUniversity
        : widget.university;

    // Use actual user level if available
    final int actualLevel = _userLevel > 0 ? _userLevel : widget.level;
    final int actualSemester = _userSemester > 0
        ? _userSemester
        : widget.semester;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (displayUniversity.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  const Icon(Icons.school, size: 16, color: Colors.blue),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      displayUniversity,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          if (displayDepartment.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  const Icon(Icons.business, size: 16, color: Colors.blue),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      displayDepartment,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          Row(
            children: [
              const Icon(Icons.auto_stories, size: 16, color: Colors.blue),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Level ${actualLevel * 100} • Semester $actualSemester',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Widget _buildDocumentsList() {
  //   return Column(
  //     children: [
  //       // Header count and activation status
  //       Padding(
  //         padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
  //         child: Row(
  //           children: [
  //             Text(
  //               '${_studyDocs.length} Study Guide${_studyDocs.length == 1 ? '' : 's'}',
  //               style: const TextStyle(
  //                 fontSize: 14,
  //                 fontWeight: FontWeight.w600,
  //                 color: Colors.grey,
  //               ),
  //             ),
  //             const Spacer(),
  //             // Activation status indicator
  //             if (!_isUserActivated && !_checkingActivation)
  //               Chip(
  //                 label: const Text(
  //                   'View Only',
  //                   style: TextStyle(fontSize: 10),
  //                 ),
  //                 backgroundColor: Colors.orange.shade100,
  //                 visualDensity: VisualDensity.compact,
  //               ),
  //             if (_isUserActivated)
  //               Chip(
  //                 label: const Text(
  //                   'Full Access',
  //                   style: TextStyle(fontSize: 10),
  //                 ),
  //                 backgroundColor: Colors.green.shade100,
  //                 visualDensity: VisualDensity.compact,
  //               ),
  //             const SizedBox(width: 8),
  //             // Filter indicator
  //             Chip(
  //               label: Text(
  //                 'Filtered for ${_userDepartment.isNotEmpty ? _userDepartment : widget.department}',
  //                 style: const TextStyle(fontSize: 10),
  //               ),
  //               backgroundColor: Colors.blue.shade100,
  //               visualDensity: VisualDensity.compact,
  //             ),
  //           ],
  //         ),
  //       ),

  //       // Documents list
  //       Expanded(
  //         child: ListView.builder(
  //           padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
  //           itemCount: _studyDocs.length,
  //           itemBuilder: (context, index) {
  //             final doc = _studyDocs[index];
  //             return _buildDocumentCard(doc);
  //           },
  //         ),
  //       ),
  //     ],
  //   );
  // }

  Widget _buildDocumentsList() {
    return Column(
      children: [
        // Header count and activation status
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              Text(
                '${_studyDocs.length} Study Guide${_studyDocs.length == 1 ? '' : 's'}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey,
                ),
              ),
              const Spacer(),
              // Activation status indicator
              if (!_isUserActivated && !_checkingActivation)
                Chip(
                  label: const Text(
                    'View Only',
                    style: TextStyle(fontSize: 10),
                  ),
                  backgroundColor: Colors.orange.shade100,
                  visualDensity: VisualDensity.compact,
                ),
              if (_isUserActivated)
                Chip(
                  label: const Text(
                    'Full Access',
                    style: TextStyle(fontSize: 10),
                  ),
                  backgroundColor: Colors.green.shade100,
                  visualDensity: VisualDensity.compact,
                ),
              const SizedBox(width: 8),
              // Filter indicator
              Chip(
                label: Text(
                  'Filtered for ${_userDepartment.isNotEmpty ? _userDepartment : widget.department}',
                  style: const TextStyle(fontSize: 10),
                ),
                backgroundColor: Colors.blue.shade100,
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
        ),

        // Documents list with pull-to-refresh
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadInitialData,
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              itemCount: _studyDocs.length,
              itemBuilder: (context, index) {
                final doc = _studyDocs[index];
                return _buildDocumentCard(doc);
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDocumentCard(StudyDocument doc) {
    return FutureBuilder<bool>(
      future: DocumentDownloadService.isPdfDownloaded(doc.fileName),
      builder: (context, snapshot) {
        final isDownloaded = snapshot.data ?? false;
        final isLoading = snapshot.connectionState == ConnectionState.waiting;
        final isDownloading = _downloadingFiles[doc.id] == true;

        return GestureDetector(
          onTap: () => _openDocumentForViewing(doc),
          onLongPress: _isUserActivated
              ? () => _showDownloadOptions(doc, isDownloaded)
              : () => _showActivationRequiredDialog(),
          child: Card(
            margin: const EdgeInsets.only(bottom: 12),
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  // PDF Icon with status
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: isDownloading
                          ? Colors.orange.withOpacity(0.1)
                          : isDownloaded
                          ? Colors.green.withOpacity(0.1)
                          : Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isDownloading
                            ? Colors.orange
                            : isDownloaded
                            ? Colors.green
                            : Colors.blue,
                        width: 1.5,
                      ),
                    ),
                    child: Center(
                      child: isDownloading
                          ? const CircularProgressIndicator(strokeWidth: 2)
                          : Icon(
                              isDownloaded
                                  ? Icons.download_done
                                  : Icons.picture_as_pdf,
                              color: isDownloading
                                  ? Colors.orange
                                  : isDownloaded
                                  ? Colors.green
                                  : Colors.blue,
                              size: 24,
                            ),
                    ),
                  ),

                  const SizedBox(width: 12),

                  // Content
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Title
                        Text(
                          doc.title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            height: 1.2,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),

                        const SizedBox(height: 6),

                        // Course info
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            if (doc.courseCode.isNotEmpty &&
                                doc.courseCode != 'GEN')
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade100,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  doc.courseCode,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.blue.shade800,
                                  ),
                                ),
                              ),
                            if (doc.courseName.isNotEmpty &&
                                doc.courseName != 'General')
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  doc.courseName,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                              ),
                          ],
                        ),

                        const SizedBox(height: 6),

                        // File info and status
                        Row(
                          children: [
                            // File size
                            Row(
                              children: [
                                Icon(
                                  Icons.insert_drive_file,
                                  size: 12,
                                  color: Colors.grey.shade600,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  doc.fileSize,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(width: 12),

                            // Status indicator
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: isDownloading
                                    ? Colors.orange.withOpacity(0.1)
                                    : isDownloaded
                                    ? Colors.green.withOpacity(0.1)
                                    : Colors.blue.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: isDownloading
                                      ? Colors.orange
                                      : isDownloaded
                                      ? Colors.green
                                      : Colors.blue,
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    isDownloading
                                        ? Icons.downloading
                                        : isDownloaded
                                        ? Icons.check_circle
                                        : Icons.wifi,
                                    size: 10,
                                    color: isDownloading
                                        ? Colors.orange
                                        : isDownloaded
                                        ? Colors.green
                                        : Colors.blue,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    isLoading
                                        ? 'Checking...'
                                        : isDownloading
                                        ? 'Downloading...'
                                        : isDownloaded
                                        ? 'Offline'
                                        : 'Online',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w500,
                                      color: isDownloading
                                          ? Colors.orange
                                          : isDownloaded
                                          ? Colors.green
                                          : Colors.blue,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const Spacer(),

                            // Access indicator
                            if (!_isUserActivated)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.orange.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: Colors.orange,
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.lock_outline,
                                      size: 10,
                                      color: Colors.orange,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Locked',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w500,
                                        color: Colors.orange,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                            if (_isUserActivated)
                              Icon(
                                isDownloading
                                    ? Icons.downloading
                                    : isDownloaded
                                    ? Icons.offline_pin
                                    : Icons.online_prediction,
                                color: isDownloading
                                    ? Colors.orange
                                    : isDownloaded
                                    ? Colors.green
                                    : Colors.blue,
                                size: 18,
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showDownloadOptions(StudyDocument doc, bool isDownloaded) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                doc.title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 16),

              if (!isDownloaded)
                ListTile(
                  leading: const Icon(Icons.download, color: Colors.blue),
                  title: const Text('Download for Offline Use'),
                  subtitle: const Text('Save to app-protected storage'),
                  onTap: () {
                    Navigator.pop(context);
                    _downloadDocumentForOffline(doc);
                  },
                ),

              if (isDownloaded)
                ListTile(
                  leading: const Icon(Icons.delete, color: Colors.red),
                  title: const Text('Delete Downloaded File'),
                  subtitle: const Text('Remove from device storage'),
                  onTap: () {
                    Navigator.pop(context);
                    _deleteDownloadedFile(doc);
                  },
                ),

              ListTile(
                leading: const Icon(Icons.info, color: Colors.grey),
                title: const Text('File Information'),
                subtitle: Text('Size: ${doc.fileSize} • Type: PDF'),
                onTap: () {
                  Navigator.pop(context);
                  _showFileInfo(doc);
                },
              ),

              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _deleteDownloadedFile(StudyDocument doc) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Downloaded File?'),
        content: Text(
          'Are you sure you want to delete "${doc.title}" from your device?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final deleted = await DocumentDownloadService.deleteDownloadedPdf(
        doc.fileName,
      );
      if (deleted) {
        _showMessage('File deleted successfully');
        _refreshDownloadStatus();
      } else {
        _showError('Failed to delete file');
      }
    }
  }

  void _showFileInfo(StudyDocument doc) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('File Information'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Title: ${doc.title}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text('File: ${doc.fileName}'),
              const SizedBox(height: 8),
              Text('Size: ${doc.fileSize}'),
              const SizedBox(height: 8),
              Text('Course: ${doc.courseName} (${doc.courseCode})'),
              const SizedBox(height: 8),
              Text('University: ${doc.university}'),
              const SizedBox(height: 8),
              Text('Department: ${doc.department}'),
              const SizedBox(height: 8),
              Text(
                'Level: ${doc.levelDisplay} • Semester: ${doc.semesterDisplay}',
              ),
              const SizedBox(height: 8),
              Text(
                'Access: ${_isUserActivated ? 'Full Access' : 'View Only'}',
                style: TextStyle(
                  color: _isUserActivated ? Colors.green : Colors.orange,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
