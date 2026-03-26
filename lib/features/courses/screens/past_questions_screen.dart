// // lib/features/courses/screens/related_past_questions_screen.dart
// import 'package:flutter/material.dart';
// import 'package:cached_network_image/cached_network_image.dart';
// import '../../../core/network/api_service.dart';
// import '../../past_questions/models/past_question_models.dart';

// class RelatedPastQuestionsScreen extends StatefulWidget {
//   final String courseId;
//   final String courseCode;
//   final String topicTitle;
//   final String? topicId;

//   const RelatedPastQuestionsScreen({
//     Key? key,
//     required this.courseId,
//     required this.courseCode,
//     required this.topicTitle,
//     this.topicId,
//   }) : super(key: key);

//   @override
//   State<RelatedPastQuestionsScreen> createState() => _RelatedPastQuestionsScreenState();
// }

// class _RelatedPastQuestionsScreenState extends State<RelatedPastQuestionsScreen> {
//   final ApiService _apiService = ApiService();

//   List<PastQuestion> _questions = [];
//   final List<bool> _showSolution = [];
//   final List<bool> _isBookmarked = [];
//   final List<bool> _isFlagged = [];
//   bool _isLoading = true;
//   bool _isOffline = false;
//   String _errorMessage = '';
//   int _selectedQuestionIndex = 0;

//   @override
//   void initState() {
//     super.initState();
//     _loadQuestions();
//   }

//   Future<void> _loadQuestions() async {
//     if (!mounted) return;

//     setState(() {
//       _isLoading = true;
//       _errorMessage = '';
//     });

//     try {
//       print('📥 Loading related past questions...');
//       print('   - Course ID: ${widget.courseId}');
//       print('   - Topic ID: ${widget.topicId}');
//       print('   - Topic Title: ${widget.topicTitle}');

//       final questions = await _apiService.getPastQuestions(
//         courseId: widget.courseId,
//         topicId: widget.topicId,
//       );

//       if (!mounted) return;

//       print('✅ Loaded ${questions.length} related questions');

//       setState(() {
//         _questions = questions;
//         _showSolution.clear();
//         _isBookmarked.clear();
//         _isFlagged.clear();

//         _showSolution.addAll(List.generate(_questions.length, (index) => false));
//         _isBookmarked.addAll(List.generate(_questions.length, (index) => false));
//         _isFlagged.addAll(List.generate(_questions.length, (index) => false));
//       });
//     } catch (e) {
//       print('❌ Error loading related questions: $e');

//       if (!mounted) return;

//       final errorString = e.toString();

//       if (errorString.contains('offline') || errorString.contains('internet')) {
//         setState(() {
//           _isOffline = true;
//           _errorMessage = 'You are offline. Please check your internet connection.';
//         });
//       } else {
//         setState(() {
//           _errorMessage = 'Failed to load questions. Please try again.';
//         });
//       }
//     } finally {
//       if (mounted) {
//         setState(() {
//           _isLoading = false;
//         });
//       }
//     }
//   }

//   void _toggleBookmark(int index) {
//     setState(() {
//       _isBookmarked[index] = !_isBookmarked[index];
//     });

//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(
//         content: Text(
//           _isBookmarked[index]
//             ? 'Question bookmarked!'
//             : 'Bookmark removed',
//         ),
//         backgroundColor: Colors.orange,
//         duration: const Duration(seconds: 2),
//       ),
//     );
//   }

//   void _showFlagDialog(int index) {
//     String? selectedReason;

//     showDialog(
//       context: context,
//       builder: (context) => StatefulBuilder(
//         builder: (context, setDialogState) {
//           return AlertDialog(
//             title: Text('Flag Question ${index + 1}'),
//             content: Column(
//               mainAxisSize: MainAxisSize.min,
//               children: [
//                 const Text('Why are you flagging this question?'),
//                 const SizedBox(height: 16),

//                 // Flag options
//                 Wrap(
//                   spacing: 8,
//                   runSpacing: 8,
//                   children: [
//                     _buildFlagOption('Incorrect question', selectedReason, (reason) {
//                       setDialogState(() => selectedReason = reason);
//                     }),
//                     _buildFlagOption('Wrong answer', selectedReason, (reason) {
//                       setDialogState(() => selectedReason = reason);
//                     }),
//                     _buildFlagOption('Poor formatting', selectedReason, (reason) {
//                       setDialogState(() => selectedReason = reason);
//                     }),
//                     _buildFlagOption('Other issue', selectedReason, (reason) {
//                       setDialogState(() => selectedReason = reason);
//                     }),
//                   ],
//                 ),
//               ],
//             ),
//             actions: [
//               TextButton(
//                 onPressed: () => Navigator.pop(context),
//                 child: const Text('Cancel'),
//               ),
//               ElevatedButton(
//                 onPressed: selectedReason != null ? () {
//                   setState(() {
//                     _isFlagged[index] = true;
//                   });
//                   Navigator.pop(context);
//                   ScaffoldMessenger.of(context).showSnackBar(
//                     const SnackBar(
//                       content: Text('Question flagged for review'),
//                       backgroundColor: Colors.purple,
//                       duration: Duration(seconds: 2),
//                     ),
//                   );
//                 } : null,
//                 child: const Text('Flag'),
//               ),
//             ],
//           );
//         },
//       ),
//     );
//   }

//   Widget _buildFlagOption(String reason, String? selectedReason, Function(String) onSelect) {
//     final isSelected = selectedReason == reason;

//     return ChoiceChip(
//       label: Text(reason),
//       selected: isSelected,
//       onSelected: (_) => onSelect(reason),
//       backgroundColor: isSelected ? Colors.purple.withOpacity(0.1) : null,
//       selectedColor: Colors.purple.withOpacity(0.3),
//       labelStyle: TextStyle(
//         color: isSelected ? Colors.purple : Colors.black,
//       ),
//     );
//   }

//   void _toggleSolution(int index) {
//     setState(() {
//       _showSolution[index] = !_showSolution[index];
//     });
//   }

//   void _askAI(int index) {
//     final question = _questions[index];

//     // Navigate to AI explanation screen
//     Navigator.pushNamed(
//       context,
//       '/question-gpt',
//       arguments: {
//         'question': question,
//         'courseName': widget.courseCode,
//         'topicName': widget.topicTitle,
//       },
//     );
//   }

//   Widget _buildQuestionCard(int index) {
//     final question = _questions[index];
//     final isCurrent = index == _selectedQuestionIndex;

//     return Container(
//       margin: const EdgeInsets.only(bottom: 12),
//       decoration: BoxDecoration(
//         color: Colors.white,
//         borderRadius: BorderRadius.circular(12),
//         boxShadow: isCurrent
//             ? [
//                 BoxShadow(
//                   color: Colors.blue.withOpacity(0.3),
//                   blurRadius: 8,
//                   spreadRadius: 1,
//                 ),
//               ]
//             : [
//                 BoxShadow(
//                   color: Colors.black.withOpacity(0.05),
//                   blurRadius: 4,
//                   offset: const Offset(0, 2),
//                 ),
//               ],
//         border: isCurrent
//             ? Border.all(color: Colors.blue, width: 2)
//             : Border.all(color: Colors.grey.shade200),
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           // Question header
//           Container(
//             padding: const EdgeInsets.all(12),
//             decoration: BoxDecoration(
//               color: Colors.grey.shade50,
//               borderRadius: const BorderRadius.only(
//                 topLeft: Radius.circular(12),
//                 topRight: Radius.circular(12),
//               ),
//             ),
//             child: Row(
//               children: [
//                 Container(
//                   padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
//                   decoration: BoxDecoration(
//                     color: Colors.blue,
//                     borderRadius: BorderRadius.circular(6),
//                   ),
//                   child: Text(
//                     'Q${index + 1}',
//                     style: const TextStyle(
//                       color: Colors.white,
//                       fontWeight: FontWeight.bold,
//                       fontSize: 12,
//                     ),
//                   ),
//                 ),
//                 const SizedBox(width: 8),
//                 Expanded(
//                   child: Text(
//                     'Question ${index + 1}',
//                     style: const TextStyle(
//                       fontWeight: FontWeight.w600,
//                       fontSize: 14,
//                     ),
//                   ),
//                 ),
//                 if (_isBookmarked[index])
//                   const Icon(Icons.bookmark, color: Colors.orange, size: 18),
//                 if (_isFlagged[index])
//                   const Padding(
//                     padding: EdgeInsets.only(left: 4),
//                     child: Icon(Icons.flag, color: Colors.purple, size: 18),
//                   ),
//               ],
//             ),
//           ),

//           // Question content
//           Padding(
//             padding: const EdgeInsets.all(12),
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 // Question text
//                 if (question.questionText != null && question.questionText!.isNotEmpty)
//                   Text(
//                     question.questionText!,
//                     style: const TextStyle(
//                       fontSize: 15,
//                       fontWeight: FontWeight.w500,
//                       color: Colors.black87,
//                       height: 1.4,
//                     ),
//                   ),

//                 // Question image
//                 if (question.questionImageUrl != null && question.questionImageUrl!.isNotEmpty)
//                   Padding(
//                     padding: const EdgeInsets.only(top: 8),
//                     child: ClipRRect(
//                       borderRadius: BorderRadius.circular(8),
//                       child: CachedNetworkImage(
//                         imageUrl: question.questionImageUrl!,
//                         placeholder: (context, url) => Container(
//                           height: 150,
//                           color: Colors.grey.shade100,
//                           child: const Center(
//                             child: CircularProgressIndicator(),
//                           ),
//                         ),
//                         errorWidget: (context, url, error) => Container(
//                           height: 150,
//                           color: Colors.grey.shade100,
//                           child: const Center(
//                             child: Icon(Icons.error, color: Colors.red),
//                           ),
//                         ),
//                         fit: BoxFit.cover,
//                       ),
//                     ),
//                   ),

//                 // Options (if MCQ)
//                 if (question.hasOptions)
//                   Padding(
//                     padding: const EdgeInsets.only(top: 12),
//                     child: Column(
//                       crossAxisAlignment: CrossAxisAlignment.start,
//                       children: question.getOptionsMap().entries.map((option) {
//                         return Padding(
//                           padding: const EdgeInsets.only(bottom: 6),
//                           child: Row(
//                             children: [
//                               Container(
//                                 width: 24,
//                                 height: 24,
//                                 decoration: BoxDecoration(
//                                   shape: BoxShape.circle,
//                                   border: Border.all(color: Colors.grey.shade400),
//                                 ),
//                                 child: Center(
//                                   child: Text(
//                                     option.key,
//                                     style: const TextStyle(
//                                       fontWeight: FontWeight.bold,
//                                       fontSize: 12,
//                                     ),
//                                   ),
//                                 ),
//                               ),
//                               const SizedBox(width: 8),
//                               Expanded(
//                                 child: Text(
//                                   option.value,
//                                   style: const TextStyle(fontSize: 14),
//                                 ),
//                               ),
//                             ],
//                           ),
//                         );
//                       }).toList(),
//                     ),
//                   ),

//                 // Actions
//                 const SizedBox(height: 16),
//                 Row(
//                   children: [
//                     Expanded(
//                       child: OutlinedButton.icon(
//                         onPressed: () => _toggleSolution(index),
//                         style: OutlinedButton.styleFrom(
//                           side: BorderSide(color: Colors.grey.shade300),
//                         ),
//                         icon: Icon(
//                           _showSolution[index]
//                               ? Icons.visibility_off
//                               : Icons.lightbulb_outline,
//                           size: 16,
//                         ),
//                         label: Text(
//                           _showSolution[index] ? 'Hide Solution' : 'Show Solution',
//                           style: const TextStyle(fontSize: 13),
//                         ),
//                       ),
//                     ),
//                     const SizedBox(width: 8),
//                     Expanded(
//                       child: OutlinedButton.icon(
//                         onPressed: () => _askAI(index),
//                         style: OutlinedButton.styleFrom(
//                           side: const BorderSide(color: Colors.green),
//                         ),
//                         icon: const Icon(Icons.auto_awesome, size: 16, color: Colors.green),
//                         label: const Text(
//                           'Ask AI',
//                           style: TextStyle(fontSize: 13, color: Colors.green),
//                         ),
//                       ),
//                     ),
//                   ],
//                 ),

//                 // Solution (if shown)
//                 if (_showSolution[index])
//                   Padding(
//                     padding: const EdgeInsets.only(top: 16),
//                     child: Container(
//                       padding: const EdgeInsets.all(12),
//                       decoration: BoxDecoration(
//                         color: Colors.amber.withOpacity(0.05),
//                         borderRadius: BorderRadius.circular(8),
//                         border: Border.all(color: Colors.amber.withOpacity(0.2)),
//                       ),
//                       child: Column(
//                         crossAxisAlignment: CrossAxisAlignment.start,
//                         children: [
//                           const Row(
//                             children: [
//                               Icon(Icons.lightbulb, color: Colors.amber, size: 16),
//                               SizedBox(width: 6),
//                               Text(
//                                 'Solution',
//                                 style: TextStyle(
//                                   fontWeight: FontWeight.bold,
//                                   fontSize: 14,
//                                 ),
//                               ),
//                             ],
//                           ),
//                           const SizedBox(height: 8),

//                           if (question.solutionText != null && question.solutionText!.isNotEmpty)
//                             Text(
//                               question.solutionText!,
//                               style: const TextStyle(
//                                 fontSize: 13,
//                                 color: Colors.black87,
//                               ),
//                             ),

//                           if (question.solutionImageUrl != null && question.solutionImageUrl!.isNotEmpty)
//                             Padding(
//                               padding: const EdgeInsets.only(top: 8),
//                               child: ClipRRect(
//                                 borderRadius: BorderRadius.circular(8),
//                                 child: CachedNetworkImage(
//                                   imageUrl: question.solutionImageUrl!,
//                                   placeholder: (context, url) => Container(
//                                     height: 120,
//                                     color: Colors.grey.shade100,
//                                   ),
//                                   errorWidget: (context, url, error) => Container(
//                                     height: 120,
//                                     color: Colors.grey.shade100,
//                                     child: const Icon(Icons.error),
//                                   ),
//                                   fit: BoxFit.cover,
//                                 ),
//                               ),
//                             ),
//                         ],
//                       ),
//                     ),
//                   ),
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildLoadingState() {
//     return Center(
//       child: Column(
//         mainAxisAlignment: MainAxisAlignment.center,
//         children: [
//           CircularProgressIndicator(),
//           const SizedBox(height: 20),
//           Text(
//             'Loading related questions...',
//             style: TextStyle(
//               fontSize: 16,
//               color: Colors.grey.shade600,
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildErrorState() {
//     return Center(
//       child: Padding(
//         padding: const EdgeInsets.all(20),
//         child: Column(
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: [
//             Icon(
//               _isOffline ? Icons.wifi_off : Icons.error_outline,
//               size: 64,
//               color: Colors.grey.shade400,
//             ),
//             const SizedBox(height: 20),
//             Text(
//               _isOffline ? 'You are offline' : 'Error loading questions',
//               style: const TextStyle(
//                 fontSize: 18,
//                 fontWeight: FontWeight.w600,
//               ),
//             ),
//             const SizedBox(height: 10),
//             Text(
//               _errorMessage,
//               textAlign: TextAlign.center,
//               style: TextStyle(
//                 color: Colors.grey.shade600,
//               ),
//             ),
//             const SizedBox(height: 20),
//             ElevatedButton(
//               onPressed: _loadQuestions,
//               child: const Text('Retry'),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _buildEmptyState() {
//     return Center(
//       child: Padding(
//         padding: const EdgeInsets.all(20),
//         child: Column(
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: [
//             Icon(Icons.quiz_outlined, size: 64, color: Colors.grey.shade400),
//             const SizedBox(height: 20),
//             Text(
//               'No related questions found',
//               style: const TextStyle(
//                 fontSize: 18,
//                 fontWeight: FontWeight.w600,
//               ),
//             ),
//             const SizedBox(height: 10),
//             Text(
//               'There are no past questions related to this topic yet.',
//               textAlign: TextAlign.center,
//               style: TextStyle(
//                 color: Colors.grey.shade600,
//               ),
//             ),
//             const SizedBox(height: 20),
//             TextButton(
//               onPressed: () => Navigator.pop(context),
//               child: const Text('Go Back'),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: Colors.grey.shade50,
//       appBar: AppBar(
//         title: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             const Text(
//               'Related Past Questions',
//               style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
//             ),
//             const SizedBox(height: 2),
//             Text(
//               '${widget.courseCode} - ${widget.topicTitle}',
//               style: TextStyle(
//                 fontSize: 12,
//                 color: Colors.white.withOpacity(0.9),
//               ),
//             ),
//           ],
//         ),
//         backgroundColor: Colors.blue,
//         foregroundColor: Colors.white,
//         actions: [
//           IconButton(
//             icon: const Icon(Icons.refresh),
//             onPressed: _isLoading ? null : _loadQuestions,
//           ),
//         ],
//       ),
//       body: _isLoading
//           ? _buildLoadingState()
//           : _questions.isEmpty
//               ? _buildEmptyState()
//               : SingleChildScrollView(
//                   padding: const EdgeInsets.all(16),
//                   child: Column(
//                     children: [
//                       // Question count
//                       Container(
//                         padding: const EdgeInsets.all(12),
//                         decoration: BoxDecoration(
//                           color: Colors.white,
//                           borderRadius: BorderRadius.circular(8),
//                           boxShadow: [
//                             BoxShadow(
//                               color: Colors.black.withOpacity(0.05),
//                               blurRadius: 4,
//                             ),
//                           ],
//                         ),
//                         child: Row(
//                           children: [
//                             const Icon(Icons.quiz, color: Colors.blue, size: 18),
//                             const SizedBox(width: 8),
//                             Text(
//                               '${_questions.length} Related Questions',
//                               style: const TextStyle(
//                                 fontWeight: FontWeight.w600,
//                                 fontSize: 14,
//                               ),
//                             ),
//                             const Spacer(),
//                             if (_questions.length > 1)
//                               Row(
//                                 children: [
//                                   IconButton(
//                                     icon: const Icon(Icons.arrow_back_ios, size: 16),
//                                     onPressed: _selectedQuestionIndex > 0
//                                         ? () {
//                                             setState(() {
//                                               _selectedQuestionIndex--;
//                                             });
//                                             // Scroll to question
//                                           }
//                                         : null,
//                                   ),
//                                   Text(
//                                     '${_selectedQuestionIndex + 1}/${_questions.length}',
//                                     style: const TextStyle(fontSize: 12),
//                                   ),
//                                   IconButton(
//                                     icon: const Icon(Icons.arrow_forward_ios, size: 16),
//                                     onPressed: _selectedQuestionIndex < _questions.length - 1
//                                         ? () {
//                                             setState(() {
//                                               _selectedQuestionIndex++;
//                                             });
//                                           }
//                                         : null,
//                                   ),
//                                 ],
//                               ),
//                           ],
//                         ),
//                       ),

//                       const SizedBox(height: 16),

//                       // Show selected question or all questions
//                       _buildQuestionCard(_selectedQuestionIndex),

//                       // Or show all questions in a list
//                       // ..._questions.map((question) => _buildQuestionCard(_questions.indexOf(question))).toList(),
//                     ],
//                   ),
//                 ),
//     );
//   }
// }

// lib/features/courses/screens/related_past_questions_screen.dart
import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;
import '../../../core/network/api_service.dart';
import '../../../core/constants/endpoints.dart';
import '../../past_questions/models/past_question_models.dart';

class RelatedPastQuestionsScreen extends StatefulWidget {
  final String courseId;
  final String courseName;
  final String topicTitle;
  final String? topicId;
  final String? sessionId;
  final String sessionName;

  const RelatedPastQuestionsScreen({
    super.key,
    required this.courseId,
    required this.courseName,
    required this.topicTitle,
    this.topicId,
    this.sessionId,
    this.sessionName = 'Related Questions',
  });

  @override
  State<RelatedPastQuestionsScreen> createState() =>
      _RelatedPastQuestionsScreenState();
}

class _RelatedPastQuestionsScreenState
    extends State<RelatedPastQuestionsScreen> {
  final ApiService _apiService = ApiService();

  List<PastQuestion> _questions = [];
  final List<bool> _showSolution = [];
  final List<bool> _isBookmarked = [];
  final List<bool> _isFlagged = [];
  final List<int> _flagCounts = [];
  final Map<String, String> _offlineDownloadedImageMap = {};
  bool _isLoading = true;
  bool _isOffline = false;
  bool _isEmptyTopic = false;
  String _errorMessage = '';

  // ========== ACTIVATION STATE ==========
  bool _isUserActivated = false;
  bool _checkingActivation = false;
  String _activationStatusMessage = 'Checking activation status...';
  int _maxQuestionsForNonActivated = 2;
  // ========== END ACTIVATION STATE ==========

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    await _checkActivationStatus(forceRefresh: true);
    await _loadQuestions();
  }

  // ========== ACTIVATION STATUS CHECK ==========

  Future<void> _checkActivationStatus({bool forceRefresh = false}) async {
    setState(() {
      _checkingActivation = true;
    });

    try {
      final activationBox = await Hive.openBox('activation_cache');

      if (!forceRefresh) {
        final cachedActivation = activationBox.get('user_activated');
        final cachedTimestamp = activationBox.get('activation_timestamp');

        if (cachedActivation != null && cachedTimestamp != null) {
          final timestamp = DateTime.parse(cachedTimestamp);
          final now = DateTime.now();
          final difference = now.difference(timestamp);

          if (difference.inMinutes < 5) {
            setState(() {
              _isUserActivated = cachedActivation;
              _checkingActivation = false;
              _activationStatusMessage = _isUserActivated
                  ? 'Account activated'
                  : 'Account not activated';
            });
            print('✅ Using cached activation status: $_isUserActivated');
            return;
          }
        }
      }

      try {
        final activationData = await _apiService.getActivationStatus();

        if (activationData != null && activationData.isValid) {
          setState(() {
            _isUserActivated = true;
            _activationStatusMessage =
                '${activationData.grade?.toUpperCase() ?? 'Activated'}';
          });

          await activationBox.put('user_activated', true);
          await activationBox.put(
            'activation_timestamp',
            DateTime.now().toIso8601String(),
          );
          await activationBox.put('activation_grade', activationData.grade);
          print('✅ User is activated: ${activationData.grade}');
        } else {
          setState(() {
            _isUserActivated = false;
            _activationStatusMessage = 'Not Activated';
          });

          await activationBox.put('user_activated', false);
          await activationBox.put(
            'activation_timestamp',
            DateTime.now().toIso8601String(),
          );
          print('ℹ️ User is not activated');
        }
      } catch (e) {
        print('❌ Error fetching activation from API: $e');

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
      print('❌ Error in activation check: $e');
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

  Future<void> _loadQuestions() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _isOffline = false;
      _isEmptyTopic = false;
      _errorMessage = '';
    });

    try {
      print('📥 Loading related past questions...');
      print('   Course: ${widget.courseId} - ${widget.courseName}');
      print('   Topic: ${widget.topicId} - ${widget.topicTitle}');
      print('   Session: ${widget.sessionId}');

      bool isOnline = false;
      try {
        final connectivityResult = await Connectivity().checkConnectivity();
        isOnline = connectivityResult != ConnectivityResult.none;

        if (isOnline) {
          print('📶 Device shows connectivity');
          try {
            final response = await http
                .head(
                  Uri.parse('${ApiEndpoints.baseUrl}/api/health/'),
                  headers: {'Accept': 'application/json'},
                )
                .timeout(const Duration(seconds: 10));

            isOnline = response.statusCode < 500;
            print('🌐 Server reachable: $isOnline (${response.statusCode})');
          } catch (e) {
            print('⚠️ Server check failed: $e');
            try {
              await InternetAddress.lookup(
                'google.com',
              ).timeout(const Duration(seconds: 3));
              isOnline = true;
              print('🌐 DNS test passed');
            } catch (e) {
              print('⚠️ DNS test also failed: $e');
              isOnline = false;
            }
          }
        }
      } catch (e) {
        print('⚠️ Connectivity check error: $e');
        isOnline = false;
      }

      if (isOnline) {
        print('🌐 Online - attempting to fetch from API...');

        final apiQuestions = await _fetchQuestionsFromAPI()
            .timeout(
              const Duration(seconds: 15),
              onTimeout: () {
                print('⏰ API timeout - falling back to offline');
                return [];
              },
            )
            .catchError((error) {
              print('❌ API error: $error');
              return [];
            });

        if (!mounted) return;

        if (apiQuestions.isNotEmpty) {
          print('✅ API returned ${apiQuestions.length} related questions');
          await _loadFlagStatus(apiQuestions);
          _showQuestions(apiQuestions, isOffline: false);
          await _cacheQuestionsForOffline(apiQuestions);
          return;
        } else {
          print('⚠️ API returned empty or failed');
        }
      } else {
        print('📴 No connectivity detected');
        setState(() {
          _isOffline = true;
        });
      }

      print('📂 Checking for offline questions...');
      List<PastQuestion> offlineQuestions =
          await _loadQuestionsFromOfflineStorage();
      offlineQuestions = _filterOfflineQuestions(offlineQuestions);

      if (offlineQuestions.isNotEmpty) {
        print('✅ Found ${offlineQuestions.length} offline questions');
        _showQuestions(offlineQuestions, isOffline: true);
        return;
      }

      print('📭 No questions found from any source');

      if (isOnline) {
        _showNoQuestions(
          isOffline: false,
          isEmptyTopic: true,
          message: 'No related questions found for "${widget.topicTitle}".',
        );
      } else {
        _showNoQuestions(
          isOffline: true,
          message:
              'No internet connection and no downloaded questions found.\n\n'
              'Please download courses when online or check your internet connection.',
        );
      }
    } catch (e) {
      print('❌ Error in _loadQuestions: $e');

      if (!mounted) return;

      _showNoQuestions(
        isOffline: true,
        message: 'Failed to load questions. ${e.toString().split(':').first}',
      );
    }
  }

  Future<List<PastQuestion>> _fetchQuestionsFromAPI() async {
    if (widget.topicId != null && widget.topicId!.isNotEmpty) {
      return await _apiService.getPastQuestions(
        courseId: widget.courseId,
        topicId: widget.topicId,
      );
    } else {
      return await _apiService.getPastQuestions(courseId: widget.courseId);
    }
  }

  Future<List<PastQuestion>> _loadQuestionsFromOfflineStorage() async {
    try {
      print(
        '📂 Loading offline related questions for course: ${widget.courseId}',
      );

      final offlineBox = await Hive.openBox('offline_courses');

      final downloadedCourseIds = offlineBox.get(
        'downloaded_course_ids',
        defaultValue: <String>[],
      );

      if (!downloadedCourseIds.contains(widget.courseId)) {
        print('⚠️ Course ${widget.courseId} not downloaded for offline use');
        return [];
      }

      final courseData = offlineBox.get('course_${widget.courseId}');

      if (courseData == null) {
        print('⚠️ No offline data found for course: ${widget.courseId}');
        return [];
      }

      _offlineDownloadedImageMap.clear();
      if (courseData.containsKey('downloaded_images')) {
        final downloadedImages = courseData['downloaded_images'];
        if (downloadedImages is Map) {
          downloadedImages.forEach((key, value) {
            if (value is Map) {
              final originalUrl = value['original_url']?.toString();
              final localPath = value['path']?.toString();

              if (originalUrl != null &&
                  originalUrl.isNotEmpty &&
                  localPath != null &&
                  localPath.isNotEmpty) {
                _offlineDownloadedImageMap[originalUrl] = localPath;
                final normalizedOriginal = _normalizeImageUrl(originalUrl);
                _offlineDownloadedImageMap[normalizedOriginal] = localPath;
              }
            }
          });
          print(
            '🖼️ Loaded ${_offlineDownloadedImageMap.length} offline image mappings',
          );
        }
      }

      final pastQuestionsData = courseData['past_questions'] as List?;
      if (pastQuestionsData == null || pastQuestionsData.isEmpty) {
        print('⚠️ No past questions found in offline data');
        return [];
      }

      print(
        '✅ Found ${pastQuestionsData.length} past questions in offline storage',
      );

      final List<PastQuestion> pastQuestions = [];

      for (var pqData in pastQuestionsData) {
        try {
          Map<String, dynamic> pqMap;
          if (pqData is Map) {
            pqMap = {};
            pqData.forEach((key, value) {
              if (key is String) {
                pqMap[key] = value;
              } else if (key is int || key is double) {
                pqMap[key.toString()] = value;
              }
            });
          } else if (pqData is Map<String, dynamic>) {
            pqMap = pqData;
          } else {
            print('⚠️ Unexpected data type: ${pqData.runtimeType}');
            continue;
          }

          print('🔍 Processing question ID: ${pqMap['id']}');

          if (pqMap['session_info'] == null ||
              (pqMap['session_info'] is Map &&
                  (pqMap['session_info'] as Map).isEmpty)) {
            if (pqMap['session_id'] != null &&
                pqMap['session_id'].toString().isNotEmpty) {
              pqMap['session_info'] = {
                'id': pqMap['session_id'].toString(),
                'name': 'Session ${pqMap['session_id']}',
                'is_active': true,
              };
              print('   ✅ Reconstructed session_info from session_id');
            }
          }

          if (courseData.containsKey('downloaded_images')) {
            final downloadedImages = courseData['downloaded_images'];
            if (downloadedImages is Map) {
              final imagesMap = <String, Map<String, dynamic>>{};
              downloadedImages.forEach((key, value) {
                if (key is String && value is Map) {
                  final imageInfo = <String, dynamic>{};
                  value.forEach((k, v) {
                    if (k is String) {
                      imageInfo[k] = v;
                    } else if (k is int || k is double) {
                      imageInfo[k.toString()] = v;
                    }
                  });
                  imagesMap[key] = imageInfo;
                }
              });

              final questionImageKey = 'past_question_${pqMap['id']}';
              if (imagesMap.containsKey(questionImageKey)) {
                final imageInfo = imagesMap[questionImageKey];
                final localPath = imageInfo?['path'] as String?;

                if (localPath != null && localPath.isNotEmpty) {
                  pqMap['original_question_image_url'] =
                      pqMap['question_image_url'];
                  pqMap['question_image_url'] = localPath;
                  pqMap['local_question_image_path'] = localPath;
                  print('   ✅ Found local question image: $localPath');
                }
              }

              final solutionImageKey = 'past_question_solution_${pqMap['id']}';
              if (imagesMap.containsKey(solutionImageKey)) {
                final imageInfo = imagesMap[solutionImageKey];
                final localPath = imageInfo?['path'] as String?;

                if (localPath != null && localPath.isNotEmpty) {
                  pqMap['original_solution_image_url'] =
                      pqMap['solution_image_url'];
                  pqMap['solution_image_url'] = localPath;
                  pqMap['local_solution_image_path'] = localPath;
                  print('   ✅ Found local solution image: $localPath');
                }
              }
            }
          }

          final pastQuestion = PastQuestion.fromJson(pqMap);

          print('   ✅ Parsed question:');
          print('      - ID: ${pastQuestion.id}');
          print('      - Course ID: ${pastQuestion.courseId}');
          print('      - Topic ID: ${pastQuestion.topicId}');

          pastQuestions.add(pastQuestion);
        } catch (e) {
          print('⚠️ Error parsing offline past question: $e');
          continue;
        }
      }

      print(
        '✅ Successfully loaded ${pastQuestions.length} offline past questions',
      );
      return pastQuestions;
    } catch (e) {
      print('❌ Error loading offline questions: $e');
      return [];
    }
  }

  List<PastQuestion> _filterOfflineQuestions(List<PastQuestion> questions) {
    if (questions.isEmpty) return [];

    print('🔍 Filtering ${questions.length} offline related questions');
    print('   - Topic filter: ${widget.topicId}');
    print('   - Topic Title: ${widget.topicTitle}');

    List<PastQuestion> filtered = List.from(questions);

    if (widget.topicId != null && widget.topicId!.isNotEmpty) {
      print('   Applying topic filter: ${widget.topicId}');

      filtered = filtered.where((question) {
        String? questionTopicId;

        if (question.topicInfo != null &&
            question.topicInfo is Map &&
            question.topicInfo!.isNotEmpty) {
          final topicInfo = question.topicInfo!;
          if (topicInfo['id'] != null) {
            questionTopicId = topicInfo['id']?.toString();
          }
        }

        if ((questionTopicId == null || questionTopicId.isEmpty) &&
            question.topicId != null) {
          questionTopicId = question.topicId;
        }

        if (questionTopicId == null || questionTopicId.isEmpty) {
          if (widget.topicId!.isEmpty) {
            return true;
          }
          return false;
        }

        final matches = questionTopicId == widget.topicId;
        print(
          '   Question ${question.id} -> topic: $questionTopicId, filter: ${widget.topicId}, match: $matches',
        );
        return matches;
      }).toList();

      print('   - After topic filter: ${filtered.length} questions');
    }

    return filtered;
  }

  void _showQuestions(List<PastQuestion> questions, {required bool isOffline}) {
    if (!mounted) return;

    List<PastQuestion> displayQuestions = List.from(questions);

    if (!_isUserActivated &&
        displayQuestions.length > _maxQuestionsForNonActivated) {
      print(
        '🔒 User not activated - limiting to $_maxQuestionsForNonActivated questions',
      );
      displayQuestions = displayQuestions.sublist(
        0,
        _maxQuestionsForNonActivated,
      );
    }

    setState(() {
      _questions = displayQuestions;
      _isOffline = isOffline;
      _isLoading = false;
      _isEmptyTopic = false;
    });

    _initializeUIArrays();

    print(
      '✅ Showing ${displayQuestions.length} related questions (${isOffline ? 'offline' : 'online'}) - Activated: $_isUserActivated',
    );
  }

  void _initializeUIArrays() {
    _showSolution.clear();
    _isBookmarked.clear();
    _isFlagged.clear();
    _flagCounts.clear();

    _showSolution.addAll(List.generate(_questions.length, (index) => false));
    _isBookmarked.addAll(List.generate(_questions.length, (index) => false));
    _isFlagged.addAll(List.generate(_questions.length, (index) => false));
    _flagCounts.addAll(List.generate(_questions.length, (index) => 0));

    print('📊 UI Arrays initialized for ${_questions.length} questions');
  }

  void _showNoQuestions({
    required bool isOffline,
    bool isEmptyTopic = false,
    required String message,
  }) {
    if (!mounted) return;

    setState(() {
      _questions = [];
      _isOffline = isOffline;
      _isLoading = false;
      _isEmptyTopic = isEmptyTopic;
      _errorMessage = message;
    });

    print('📭 No related questions: $message');
  }

  Future<void> _cacheQuestionsForOffline(List<PastQuestion> questions) async {
    try {
      final box = await Hive.openBox('past_questions_cache');
      final cacheKey = 'related_${widget.courseId}_${widget.topicId}';
      final questionData = questions.map((q) => q.toJson()).toList();

      await box.put(cacheKey, questionData);
      await box.put('${cacheKey}_timestamp', DateTime.now().toIso8601String());

      print('✅ Cached ${questions.length} related questions for offline use');
    } catch (e) {
      print('⚠️ Error caching related questions: $e');
    }
  }

  // ========== ACTIVATION BANNER ==========

  Widget _buildActivationBanner() {
    return GestureDetector(
      onTap: () async {
        final result = await Navigator.pushNamed(context, '/activation');
        if (mounted) {
          await _checkActivationStatus(forceRefresh: true);
          await _loadQuestions();
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
                    'Only $_maxQuestionsForNonActivated questions are available. Tap to activate and unlock all past questions.',
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

  // ========== FLAG FUNCTIONALITY ==========

  Future<void> _loadFlagStatus(List<PastQuestion> questions) async {
    try {
      print('🚩 Loading flag status for ${questions.length} questions');

      for (int i = 0; i < questions.length; i++) {
        final question = questions[i];
        print('🚩 Getting flag status for question: ${question.id}');

        try {
          final flagStatus = await _apiService.getQuestionFlagStatus(
            questionId: question.id,
          );

          print('📥 Flag status for ${question.id}: $flagStatus');

          if (mounted) {
            setState(() {
              if (i < _isFlagged.length) {
                _isFlagged[i] = flagStatus['is_flagged'] == true;
              }
              if (i < _flagCounts.length) {
                _flagCounts[i] = (flagStatus['total_flags'] as int?) ?? 0;
              }
            });
          }

          print(
            '   Question ${question.id}: flagged=${_isFlagged[i]}, flags=${_flagCounts[i]}',
          );
        } catch (e) {
          print('⚠️ Error loading flag status for question ${question.id}: $e');

          if (mounted) {
            setState(() {
              if (i < _isFlagged.length) {
                _isFlagged[i] = false;
              }
              if (i < _flagCounts.length) {
                _flagCounts[i] = 0;
              }
            });
          }
        }
      }

      print('✅ Flag status loaded for all questions');
    } catch (e) {
      print('❌ Error in _loadFlagStatus: $e');
    }
  }

  Future<void> _toggleFlagQuestion(int index) async {
    try {
      final question = _questions[index];

      if (_isFlagged[index]) {
        await _unflagQuestion(index);
      } else {
        await _flagQuestion(index, 'other', description: 'Flagged by user');
      }
    } catch (e) {
      print('❌ Error toggling flag: $e');
    }
  }

  Future<void> _flagQuestion(
    int index,
    String reason, {
    String? description,
  }) async {
    try {
      final question = _questions[index];

      setState(() {
        _isFlagged[index] = true;
      });

      final response = await _apiService.flagPastQuestion(
        questionId: question.id,
        reason: reason,
        description: description,
      );

      if (mounted) {
        setState(() {
          _flagCounts[index] =
              response['flag_count'] ?? (_flagCounts[index] + 1);
        });
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Question flagged'),
          backgroundColor: Color(0xFF8B5CF6),
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      print('❌ Error flagging question: $e');

      if (mounted) {
        setState(() {
          _isFlagged[index] = false;
        });
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to flag question'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _unflagQuestion(int index) async {
    try {
      final question = _questions[index];

      setState(() {
        _isFlagged[index] = false;
      });

      final response = await _apiService.unflagPastQuestion(
        questionId: question.id,
      );

      if (mounted) {
        setState(() {
          _flagCounts[index] = max(0, (_flagCounts[index] - 1));
        });
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Flag removed'),
          backgroundColor: Color(0xFF10B981),
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      print('❌ Error unflagging question: $e');

      if (mounted) {
        setState(() {
          _isFlagged[index] = true;
        });
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to remove flag'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _showFlagDialog(int index) {
    String? selectedReason;
    final descriptionController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return Dialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.flag_rounded,
                    size: 40,
                    color: _isFlagged[index]
                        ? Colors.orange
                        : const Color(0xFF8B5CF6),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _isFlagged[index] ? 'Update Flag' : 'Flag Question',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A1A2E),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _isFlagged[index]
                        ? 'You have already flagged this question. You can update your reason.'
                        : 'Why are you flagging this question?',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFF6B7280),
                      fontSize: 14,
                    ),
                  ),

                  const SizedBox(height: 20),

                  if (_flagCounts[index] > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.orange.shade200),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.flag, size: 14, color: Colors.orange),
                          const SizedBox(width: 6),
                          Text(
                            '${_flagCounts[index]} other user${_flagCounts[index] > 1 ? 's' : ''} also flagged this',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.orange.shade800,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),

                  const SizedBox(height: 20),

                  Column(
                    children: [
                      _buildFlagOption('Incorrect question', selectedReason, (
                        reason,
                      ) {
                        setDialogState(() => selectedReason = reason);
                      }),
                      _buildFlagOption('Wrong answer', selectedReason, (
                        reason,
                      ) {
                        setDialogState(() => selectedReason = reason);
                      }),
                      _buildFlagOption('Poor formatting', selectedReason, (
                        reason,
                      ) {
                        setDialogState(() => selectedReason = reason);
                      }),
                      _buildFlagOption('Other issue', selectedReason, (reason) {
                        setDialogState(() => selectedReason = reason);
                      }),
                    ],
                  ),

                  const SizedBox(height: 16),

                  TextField(
                    controller: descriptionController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: 'Additional details (optional)',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  Row(
                    children: [
                      if (_isFlagged[index])
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              Navigator.pop(context);
                              _unflagQuestion(index);
                            },
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.red,
                              side: const BorderSide(color: Colors.red),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: const Text('Remove Flag'),
                          ),
                        ),
                      if (_isFlagged[index]) const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF6B7280),
                            side: const BorderSide(color: Color(0xFFD1D5DB)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: selectedReason != null
                              ? () async {
                                  Navigator.pop(context);
                                  await _flagQuestion(
                                    index,
                                    selectedReason!,
                                    description:
                                        descriptionController.text.isNotEmpty
                                        ? descriptionController.text
                                        : null,
                                  );
                                }
                              : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _isFlagged[index]
                                ? Colors.orange
                                : const Color(0xFF8B5CF6),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: Text(
                            _isFlagged[index] ? 'Update' : 'Flag Question',
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildFlagOption(
    String reason,
    String? selectedReason,
    Function(String) onSelect,
  ) {
    final isSelected = selectedReason == reason;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      child: OutlinedButton(
        onPressed: () => onSelect(reason),
        style: OutlinedButton.styleFrom(
          foregroundColor: isSelected
              ? const Color(0xFF8B5CF6)
              : const Color(0xFF6B7280),
          side: BorderSide(
            color: isSelected
                ? const Color(0xFF8B5CF6)
                : const Color(0xFFD1D5DB),
            width: isSelected ? 2 : 1,
          ),
          backgroundColor: isSelected
              ? const Color(0xFF8B5CF6).withOpacity(0.1)
              : Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        child: Text(
          reason,
          style: TextStyle(
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  void _showFlagOptions(int index) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Flag Reason',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 16),

              if (_flagCounts[index] > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.flag, size: 14, color: Colors.orange),
                      const SizedBox(width: 6),
                      Text(
                        '${_flagCounts[index]} flag${_flagCounts[index] > 1 ? 's' : ''}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.orange.shade800,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),

              ...[
                'Incorrect question',
                'Wrong answer',
                'Poor formatting',
                'Other issue',
              ].map((reason) {
                return ListTile(
                  leading: const Icon(Icons.flag, color: Color(0xFF8B5CF6)),
                  title: Text(reason),
                  onTap: () {
                    Navigator.pop(context);
                    _flagQuestion(
                      index,
                      reason.toLowerCase().replaceAll(' ', '_'),
                      description: 'Flagged: $reason',
                    );
                  },
                );
              }).toList(),

              ListTile(
                leading: const Icon(Icons.close, color: Colors.grey),
                title: const Text(
                  'Cancel',
                  style: TextStyle(color: Colors.grey),
                ),
                onTap: () => Navigator.pop(context),
              ),
            ],
          ),
        );
      },
    );
  }

  // ========== QUESTION CARD ==========

  Widget _buildQuestionCard(int index) {
    final question = _questions[index];
    final optionsMap = question.getOptionsMap();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
              border: Border.all(color: Colors.grey.shade100),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366F1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Q${index + 1}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 11,
                    ),
                  ),
                ),

                if (_flagCounts[index] > 0) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.flag,
                          size: 10,
                          color: Colors.orange.shade700,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          '${_flagCounts[index]}',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.orange.shade700,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const Spacer(),

                IconButton(
                  icon: Icon(
                    _isBookmarked[index]
                        ? Icons.bookmark_rounded
                        : Icons.bookmark_border_rounded,
                    color: _isBookmarked[index]
                        ? const Color(0xFFF59E0B)
                        : Colors.grey.shade400,
                    size: 20,
                  ),
                  onPressed: () => _toggleBookmark(index),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  iconSize: 20,
                ),
                const SizedBox(width: 8),

                GestureDetector(
                  onTap: () => _toggleFlagQuestion(index),
                  onLongPress: () => _showFlagOptions(index),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: _isFlagged[index]
                          ? const Color(0xFF8B5CF6).withOpacity(0.1)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _isFlagged[index]
                            ? const Color(0xFF8B5CF6)
                            : Colors.grey.shade300,
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _isFlagged[index]
                              ? Icons.flag_rounded
                              : Icons.outlined_flag_rounded,
                          color: _isFlagged[index]
                              ? const Color(0xFF8B5CF6)
                              : Colors.grey.shade600,
                          size: 16,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (question.isImageOnlyQuestion)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.blue.shade200),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.image,
                              size: 14,
                              color: Colors.blue.shade700,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Image Question',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.blue.shade700,
                              ),
                            ),
                          ],
                        ),
                      ),

                      if (question.questionImageUrl != null &&
                          question.questionImageUrl!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _buildQuestionImage(question),
                        ),
                    ],
                  )
                else
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (question.questionText != null &&
                          question.questionText!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _buildFormattedContent(
                            question.questionText!,
                            isAnswer: false,
                          ),
                        ),

                      if (question.questionImageUrl != null &&
                          question.questionImageUrl!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _buildQuestionImage(question),
                        ),
                    ],
                  ),

                if (question.hasOptions && optionsMap.isNotEmpty)
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: optionsMap.entries.map((option) {
                      return Container(
                        width: (MediaQuery.of(context).size.width - 56) / 2,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 20,
                                height: 20,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.grey.shade300,
                                  ),
                                ),
                                child: Center(
                                  child: Text(
                                    option.key,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 10,
                                      color: Color(0xFF1A1A2E),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _buildFormattedContent(
                                  option.value,
                                  isAnswer: false,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),

                if (!question.hasOptions)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: const Row(
                      children: [
                        Icon(
                          Icons.short_text_rounded,
                          size: 16,
                          color: Color(0xFF6B7280),
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Short answer question',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: 12),

                Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _showAnswer(index),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF6366F1),
                              side: const BorderSide(color: Color(0xFF6366F1)),
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            icon: const Icon(
                              Icons.visibility_rounded,
                              size: 14,
                            ),
                            label: const Text(
                              'Show Answer',
                              style: TextStyle(fontSize: 12),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _toggleSolution(index),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF8B5CF6),
                              side: const BorderSide(color: Color(0xFF8B5CF6)),
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            icon: Icon(
                              _showSolution[index]
                                  ? Icons.visibility_off_rounded
                                  : Icons.lightbulb_rounded,
                              size: 14,
                            ),
                            label: Text(
                              _showSolution[index]
                                  ? 'Hide Solution'
                                  : 'Solution',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => _askAI(index),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF10B981),
                          side: const BorderSide(color: Color(0xFF10B981)),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        icon: const Icon(Icons.auto_awesome_rounded, size: 14),
                        label: const Text(
                          'Ask AI for Explanation',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                    ),
                  ],
                ),

                if (_showSolution[index]) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF59E0B).withOpacity(0.05),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: const Color(0xFFF59E0B).withOpacity(0.2),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(
                              Icons.lightbulb_rounded,
                              color: Color(0xFFF59E0B),
                              size: 16,
                            ),
                            SizedBox(width: 6),
                            Text(
                              'Solution',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                                color: Color(0xFF1A1A2E),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),

                        if (question.solutionText != null &&
                            question.solutionText!.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: _buildFormattedContent(
                              question.solutionText!,
                              isAnswer: false,
                            ),
                          ),

                        if (question.solutionImageUrl != null &&
                            question.solutionImageUrl!.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: CachedNetworkImage(
                                imageUrl: question.solutionImageUrl!,
                                placeholder: (context, url) => Container(
                                  height: 150,
                                  color: Colors.grey.shade100,
                                  child: const Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                ),
                                errorWidget: (context, url, error) => Container(
                                  height: 150,
                                  color: Colors.grey.shade100,
                                  child: const Center(
                                    child: Icon(Icons.error, color: Colors.red),
                                  ),
                                ),
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionImage(PastQuestion question) {
    final imageUrl = question.questionImageUrl!;

    final isLocalPath =
        imageUrl.startsWith('/') ||
        imageUrl.startsWith('hive://') ||
        (imageUrl.contains(
              RegExp(r'\.(jpg|jpeg|png|gif|bmp|webp)$', caseSensitive: false),
            ) &&
            !imageUrl.startsWith('http'));

    if (isLocalPath) {
      if (imageUrl.startsWith('hive://')) {
        final imageKey = imageUrl.replaceFirst('hive://', '');
        return FutureBuilder<Uint8List?>(
          future: _loadHiveImage(imageKey),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Container(
                height: 200,
                color: Colors.grey.shade100,
                child: const Center(child: CircularProgressIndicator()),
              );
            } else if (snapshot.hasError || snapshot.data == null) {
              return _buildErrorImage('Failed to load offline image');
            } else {
              return ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.memory(snapshot.data!, fit: BoxFit.contain),
              );
            }
          },
        );
      } else {
        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.file(
            File(imageUrl),
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) {
              return _buildErrorImage('Failed to load local image');
            },
          ),
        );
      }
    } else {
      String cleanUrl = imageUrl.replaceAll(RegExp(r'(?<!:)/{2,}'), '/');

      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: CachedNetworkImage(
          imageUrl: cleanUrl,
          placeholder: (context, url) => Container(
            height: 200,
            color: Colors.grey.shade100,
            child: const Center(child: CircularProgressIndicator()),
          ),
          errorWidget: (context, url, error) {
            return _buildErrorImage('Failed to load image');
          },
          fit: BoxFit.contain,
        ),
      );
    }
  }

  Future<Uint8List?> _loadHiveImage(String imageKey) async {
    try {
      print('🔍 Loading Hive image with key: $imageKey');
      final imageBox = await Hive.openBox('offline_images');
      final imageData = imageBox.get(imageKey);

      if (imageData == null) {
        print('❌ No image found in Hive for key: $imageKey');
        return null;
      }

      if (imageData['data'] == null) {
        print('❌ Image data is null for key: $imageKey');
        return null;
      }

      try {
        final bytes = Uint8List.fromList(List<int>.from(imageData['data']));
        print('✅ Successfully loaded Hive image (${bytes.length} bytes)');
        return bytes;
      } catch (e) {
        print('❌ Error converting Hive image data: $e');
        return null;
      }
    } catch (e) {
      print('❌ Error loading Hive image: $e');
      return null;
    }
  }

  Widget _buildErrorImage(String message) {
    return Container(
      height: 200,
      color: Colors.grey.shade100,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.broken_image, size: 40, color: Colors.grey),
          const SizedBox(height: 8),
          Text(
            message,
            style: const TextStyle(fontSize: 12, color: Colors.grey),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // ========== CONTENT FORMATTING (FROM MAIN SCREEN) ==========

  Widget _buildFormattedContent(String content, {bool isAnswer = false}) {
    if (content.isEmpty) return Container();

    if (_shouldRenderAsHtml(content)) {
      return _buildHtmlFormattedContent(content, isAnswer: isAnswer);
    }

    // Convert CKEditor HTML to clean markdown
    final cleanContent = _convertCkEditorToMarkdown(content);

    return Container(
      constraints: BoxConstraints(
        minHeight: 50, // Minimum height to avoid unconstrained errors
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: _parseContentForDisplay(cleanContent, isAnswer: isAnswer),
        ),
      ),
    );
  }

  bool _shouldRenderAsHtml(String content) {
    final trimmed = content.trim();
    return (trimmed.contains('<') && trimmed.contains('>')) ||
        _looksLikeTabularPlainText(trimmed) ||
        RegExp(r'!\[.*?\]\(.*?\)').hasMatch(trimmed);
  }

  bool _looksLikeTabularPlainText(String content) {
    final lines = content
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();

    if (lines.length < 2) return false;

    final tabRows = lines.where((line) => line.contains('\t')).toList();
    if (tabRows.length < 2) return false;

    final firstColumnCount = tabRows.first.split(RegExp(r'\t+')).length;
    if (firstColumnCount < 2) return false;

    return tabRows.take(4).every(
      (row) => row.split(RegExp(r'\t+')).length == firstColumnCount,
    );
  }

  Widget _buildHtmlFormattedContent(String content, {bool isAnswer = false}) {
    final processedContent = _prepareHtmlContentForRendering(content);
    final textColor =
        isAnswer ? const Color(0xFF10B981) : const Color(0xFF333333);

    return Html(
      data: processedContent,
      shrinkWrap: true,
      extensions: [
        TagExtension(
          tagsToExtend: {'pre'},
          builder: (context) {
            final rawHtml = context.innerHtml;
            final language = _extractCodeLanguageFromHtml(rawHtml);
            final codeContent = _extractCodeTextFromHtml(rawHtml);
            if (codeContent.trim().isEmpty) {
              return const SizedBox.shrink();
            }
            return _buildCodeBlock(codeContent, language);
          },
        ),
        TagExtension(
          tagsToExtend: {'code'},
          builder: (context) {
            final rawHtml = context.innerHtml;
            if (rawHtml.contains('\n')) {
              final language = _extractCodeLanguageFromHtml(rawHtml);
              final codeContent = _extractCodeTextFromHtml(rawHtml);
              if (codeContent.trim().isEmpty) {
                return const SizedBox.shrink();
              }
              return _buildCodeBlock(codeContent, language);
            }

            final inlineCode = _decodeHtmlEntities(
              rawHtml.replaceAll(RegExp(r'<[^>]*>'), '').trim(),
            );
            if (inlineCode.isEmpty) {
              return const SizedBox.shrink();
            }
            return _buildInlineCode('`$inlineCode`');
          },
        ),
        TagExtension(
          tagsToExtend: {'img'},
          builder: (context) {
            final src = context.attributes['src'] ?? '';
            final alt = context.attributes['alt'] ?? '';
            return _buildImageFromSource(src, altText: alt);
          },
        ),
        TagExtension(
          tagsToExtend: {'flutter-table'},
          builder: (context) {
            final encodedData = context.attributes['data'];
            if (encodedData == null || encodedData.isEmpty) {
              return const SizedBox.shrink();
            }

            try {
              final tableData =
                  jsonDecode(Uri.decodeComponent(encodedData))
                      as Map<String, dynamic>;
              final hasHeader = tableData['hasHeader'] == true;
              final rows = (tableData['rows'] as List<dynamic>)
                  .map(
                    (row) => (row as List<dynamic>)
                        .map((cell) => cell.toString())
                        .toList(),
                  )
                  .toList();
              return _buildHtmlTable(rows, hasHeader: hasHeader);
            } catch (e) {
              return Container(
                padding: const EdgeInsets.all(12),
                color: Colors.red.shade50,
                child: Text('Table render error: $e'),
              );
            }
          },
        ),
        TagExtension(
          tagsToExtend: {'tex-inline'},
          builder: (context) {
            final expression = _decodeHtmlEntities(context.innerHtml.trim());
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: _buildMathWidget(expression, isInline: true),
            );
          },
        ),
        TagExtension(
          tagsToExtend: {'tex-block'},
          builder: (context) {
            final expression = _decodeHtmlEntities(context.innerHtml.trim());
            return _buildMathBlock(expression);
          },
        ),
      ],
      style: {
        'html': Style(
          margin: Margins.zero,
          padding: HtmlPaddings.zero,
        ),
        'body': Style(
          margin: Margins.zero,
          padding: HtmlPaddings.zero,
          color: textColor,
          fontSize: FontSize(isAnswer ? 16 : 14),
          lineHeight: LineHeight(1.6),
        ),
        'p': Style(
          margin: Margins.only(bottom: 14),
          color: textColor,
          fontSize: FontSize(isAnswer ? 16 : 14),
          lineHeight: LineHeight(1.6),
        ),
        'div': Style(
          margin: Margins.only(bottom: 8),
          color: textColor,
          fontSize: FontSize(isAnswer ? 16 : 14),
          lineHeight: LineHeight(1.6),
        ),
        'span': Style(
          color: textColor,
          fontSize: FontSize(isAnswer ? 16 : 14),
          lineHeight: LineHeight(1.6),
        ),
        'strong': Style(fontWeight: FontWeight.w700, color: textColor),
        'b': Style(fontWeight: FontWeight.w700, color: textColor),
        'em': Style(fontStyle: FontStyle.italic, color: textColor),
        'i': Style(fontStyle: FontStyle.italic, color: textColor),
        'u': Style(textDecoration: TextDecoration.underline, color: textColor),
        'h1': Style(
          fontSize: FontSize(22),
          fontWeight: FontWeight.bold,
          margin: Margins.only(top: 16, bottom: 12),
          color: const Color(0xFF1A1A2E),
        ),
        'h2': Style(
          fontSize: FontSize(20),
          fontWeight: FontWeight.bold,
          margin: Margins.only(top: 14, bottom: 10),
          color: const Color(0xFF1A1A2E),
        ),
        'h3': Style(
          fontSize: FontSize(18),
          fontWeight: FontWeight.w700,
          margin: Margins.only(top: 12, bottom: 8),
          color: const Color(0xFF1A1A2E),
        ),
        'ul': Style(
          margin: Margins.only(bottom: 12, left: 18),
          padding: HtmlPaddings.zero,
        ),
        'ol': Style(
          margin: Margins.only(bottom: 12, left: 18),
          padding: HtmlPaddings.zero,
        ),
        'li': Style(
          color: textColor,
          fontSize: FontSize(isAnswer ? 16 : 14),
          lineHeight: LineHeight(1.6),
          margin: Margins.only(bottom: 6),
        ),
        'img': Style(
          margin: Margins.only(top: 10, bottom: 10),
        ),
        'blockquote': Style(
          padding: HtmlPaddings.only(left: 12, top: 8, bottom: 8),
          margin: Margins.only(top: 8, bottom: 8),
          border: Border(
            left: BorderSide(color: Colors.blue.shade200, width: 4),
          ),
          backgroundColor: Colors.blue.shade50,
        ),
      },
    );
  }

  String _prepareHtmlContentForRendering(String content) {
    String processed = content.trim();

    if (!_looksLikeHtml(processed) && _looksLikeTabularPlainText(processed)) {
      processed = _convertPlainTextTableToHtml(processed);
    } else if (!_looksLikeHtml(processed)) {
      processed = processed
          .split('\n\n')
          .map((block) => '<p>${_escapeHtmlText(block).replaceAll('\n', '<br>')}</p>')
          .join();
    }

    processed = _convertMarkdownImagesToHtml(processed);
    processed = _normalizeCkEditorImageUrls(processed);
    processed = _replaceCkEditorMathWithCustomTags(processed);
    processed = _replaceDollarMathWithCustomTags(processed);
    processed = _replaceHtmlTablesWithCustomTags(processed);

    return '''
<style>
  img { max-width: 100%; height: auto; display: block; margin: 0 auto; }
</style>
$processed
''';
  }

  bool _looksLikeHtml(String content) {
    return RegExp(r'<[a-zA-Z][^>]*>').hasMatch(content);
  }

  String _extractCodeLanguageFromHtml(String rawHtml) {
    final classMatch = RegExp(
      r'class="([^"]+)"',
      caseSensitive: false,
    ).firstMatch(rawHtml);
    if (classMatch == null) return '';

    final classes = classMatch.group(1)?.split(RegExp(r'\s+')) ?? const [];
    for (final cls in classes) {
      if (cls.startsWith('language-')) {
        return cls.replaceFirst('language-', '').trim();
      }
    }

    return '';
  }

  String _extractCodeTextFromHtml(String rawHtml) {
    final stripped = rawHtml
        .replaceAll(RegExp(r'</?(pre|code)[^>]*>', caseSensitive: false), '')
        .replaceAll('<br>', '\n')
        .replaceAll('<br/>', '\n')
        .replaceAll('<br />', '\n')
        .replaceAll(RegExp(r'</p\s*>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'<[^>]*>'), '');

    return _decodeHtmlEntities(stripped).trimRight();
  }

  String _convertPlainTextTableToHtml(String content) {
    final lines = content
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();

    if (lines.isEmpty) return content;

    final rows = lines
        .map((line) => line.split(RegExp(r'\t+')).map((cell) => cell.trim()).toList())
        .toList();

    final buffer = StringBuffer('<table><tbody>');
    for (final row in rows) {
      buffer.write('<tr>');
      for (final cell in row) {
        buffer.write('<td>${_escapeHtmlText(cell)}</td>');
      }
      buffer.write('</tr>');
    }
    buffer.write('</tbody></table>');
    return buffer.toString();
  }

  String _normalizeCkEditorImageUrls(String htmlContent) {
    return htmlContent.replaceAllMapped(
      RegExp(r'<img([^>]*?)src="([^"]*)"([^>]*)>', caseSensitive: false),
      (match) {
        final before = match.group(1) ?? '';
        final src = match.group(2) ?? '';
        final after = match.group(3) ?? '';
        final normalizedUrl = _normalizeImageUrl(src);
        return '<img$before src="$normalizedUrl"$after>';
      },
    );
  }

  String _convertMarkdownImagesToHtml(String content) {
    return content.replaceAllMapped(RegExp(r'!\[(.*?)\]\((.*?)\)'), (match) {
      final alt = _escapeHtmlText(match.group(1) ?? '');
      final src = _normalizeImageUrl(match.group(2) ?? '');
      return '<img src="$src" alt="$alt" />';
    });
  }

  String _normalizeImageUrl(String src) {
    if (src.isEmpty) return src;
    if (_offlineDownloadedImageMap.containsKey(src)) {
      return _offlineDownloadedImageMap[src]!;
    }
    if (src.startsWith('http://') || src.startsWith('https://')) {
      return _offlineDownloadedImageMap[src] ?? src;
    }

    final baseUrl = ApiEndpoints.baseUrl;
    String imageUrl;

    if (src.startsWith('/')) {
      imageUrl = '$baseUrl$src';
    } else if (src.startsWith('media/') || src.startsWith('/media/')) {
      imageUrl = src.startsWith('media/') ? '$baseUrl/$src' : '$baseUrl$src';
    } else if (src.startsWith('uploads/')) {
      imageUrl = '$baseUrl/media/$src';
    } else {
      imageUrl = '$baseUrl/media/$src';
    }

    imageUrl = imageUrl.replaceAll('//media/', '/media/');
    imageUrl = imageUrl.replaceAll(':/', '://');
    return _offlineDownloadedImageMap[imageUrl] ?? imageUrl;
  }

  String _replaceCkEditorMathWithCustomTags(String htmlContent) {
    String result = htmlContent;

    result = result.replaceAllMapped(
      RegExp(
        r'<span[^>]*class="[^"]*math-tex[^"]*"[^>]*>(.*?)</span>',
        caseSensitive: false,
        dotAll: true,
      ),
      (match) => '<tex-inline>${match.group(1) ?? ''}</tex-inline>',
    );

    result = result.replaceAllMapped(
      RegExp(
        r'<script[^>]*type="math/tex; mode=display"[^>]*>(.*?)</script>',
        caseSensitive: false,
        dotAll: true,
      ),
      (match) => '<tex-block>${_escapeHtmlText(match.group(1) ?? '')}</tex-block>',
    );

    result = result.replaceAllMapped(
      RegExp(
        r'<script[^>]*type="math/tex"[^>]*>(.*?)</script>',
        caseSensitive: false,
        dotAll: true,
      ),
      (match) => '<tex-inline>${_escapeHtmlText(match.group(1) ?? '')}</tex-inline>',
    );

    return result;
  }

  String _replaceDollarMathWithCustomTags(String content) {
    String result = content;

    result = result.replaceAllMapped(
      RegExp(r'\$\$(.+?)\$\$', dotAll: true),
      (match) => '<tex-block>${_escapeHtmlText(match.group(1) ?? '')}</tex-block>',
    );

    result = result.replaceAllMapped(
      RegExp(r'(?<!\$)\$([^\$]+?)\$(?!\$)', dotAll: true),
      (match) => '<tex-inline>${_escapeHtmlText(match.group(1) ?? '')}</tex-inline>',
    );

    return result;
  }

  String _replaceHtmlTablesWithCustomTags(String htmlContent) {
    return htmlContent.replaceAllMapped(
      RegExp(
        r'<table[^>]*>(.*?)</table>',
        caseSensitive: false,
        dotAll: true,
      ),
      (tableMatch) {
        final tableInnerHtml = tableMatch.group(1) ?? '';
        final rows = <List<String>>[];
        bool hasHeader = false;

        final rowMatches = RegExp(
          r'<tr[^>]*>(.*?)</tr>',
          caseSensitive: false,
          dotAll: true,
        ).allMatches(tableInnerHtml);

        for (final rowMatch in rowMatches) {
          final rowHtml = rowMatch.group(1) ?? '';
          final cells = <String>[];

          final cellMatches = RegExp(
            r'<(th|td)[^>]*>(.*?)</\1>',
            caseSensitive: false,
            dotAll: true,
          ).allMatches(rowHtml);

          for (final cellMatch in cellMatches) {
            final tag = (cellMatch.group(1) ?? '').toLowerCase();
            if (tag == 'th') hasHeader = true;
            cells.add((cellMatch.group(2) ?? '').trim());
          }

          if (cells.isNotEmpty) {
            rows.add(cells);
          }
        }

        if (rows.isEmpty) return '';

        final encoded = Uri.encodeComponent(
          jsonEncode({'hasHeader': hasHeader, 'rows': rows}),
        );
        return '<flutter-table data="$encoded"></flutter-table>';
      },
    );
  }

  String _escapeHtmlText(String text) {
    return text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#39;');
  }

  String _convertCkEditorToMarkdown(String htmlContent) {
    if (htmlContent.isEmpty) return '';

    String result = htmlContent;

    // Debug: Print raw HTML
    print(
      '📝 Raw HTML: ${htmlContent.substring(0, min(200, htmlContent.length))}...',
    );

    // 1. CRITICAL: First check if it's plain text (no HTML tags)
    if (!result.contains('<') && !result.contains('>')) {
      // It's already plain text, just decode entities
      return _decodeHtmlEntities(result);
    }

    // 1. Handle tables FIRST (important to do this before removing other tags)
    result = _convertHtmlTablesToMarkdown(result);

    // 2. Convert math equations
    result = result.replaceAllMapped(
      RegExp(
        r'<span[^>]*class="math-tex"[^>]*>(.*?)</span>',
        caseSensitive: false,
        dotAll: true,
      ),
      (match) {
        final mathContent = match.group(1) ?? '';
        // Clean math content
        final cleanMath = mathContent
            .replaceAll('&lt;', '<')
            .replaceAll('&gt;', '>')
            .replaceAll('&amp;', '&');
        return '\$$cleanMath\$';
      },
    );

    // 3. Handle MathJax/LaTeX blocks
    result = result.replaceAllMapped(
      RegExp(
        r'<script[^>]*type="math/tex"[^>]*>(.*?)</script>',
        caseSensitive: false,
        dotAll: true,
      ),
      (match) {
        final mathContent = match.group(1) ?? '';
        return '\$\$$mathContent\$\$';
      },
    );

    result = result.replaceAllMapped(
      RegExp(
        r'<script[^>]*type="math/tex; mode=display"[^>]*>(.*?)</script>',
        caseSensitive: false,
        dotAll: true,
      ),
      (match) {
        final mathContent = match.group(1) ?? '';
        return '\$\$$mathContent\$\$';
      },
    );

    // 4. Convert code blocks
    result = result.replaceAllMapped(
      RegExp(r'<pre[^>]*>(.*?)</pre>', caseSensitive: false, dotAll: true),
      (match) {
        final preContent = match.group(1) ?? '';
        String codeContent = preContent;

        // Extract language from class
        String language = '';
        final classMatch = RegExp(
          r'class="([^"]*)"',
        ).firstMatch(match.group(0) ?? '');
        if (classMatch != null) {
          final classes = classMatch.group(1)!.split(' ');
          for (final cls in classes) {
            if (cls.startsWith('language-')) {
              language = cls.replaceFirst('language-', '');
              break;
            }
          }
        }

        // Clean code content
        codeContent = codeContent
            .replaceAll('<code>', '')
            .replaceAll('</code>', '')
            .replaceAll('&lt;', '<')
            .replaceAll('&gt;', '>')
            .replaceAll('&amp;', '&')
            .trim();

        return '```$language\n$codeContent\n```';
      },
    );

    // 5. Convert inline code
    result = result.replaceAllMapped(
      RegExp(r'<code[^>]*>(.*?)</code>', caseSensitive: false),
      (match) {
        final codeContent = match.group(1) ?? '';
        final cleanCode = codeContent
            .replaceAll('&lt;', '<')
            .replaceAll('&gt;', '>')
            .replaceAll('&amp;', '&');
        return '`$cleanCode`';
      },
    );

    // 6. Convert images with proper handling
    result = result.replaceAllMapped(
      RegExp(r'<img[^>]*>', caseSensitive: false),
      (match) {
        final imgTag = match.group(0)!;
        String? src, alt;

        // Extract src
        final srcMatch = RegExp(r'src="([^"]*)"').firstMatch(imgTag);
        if (srcMatch != null) src = srcMatch.group(1);

        // Extract alt
        final altMatch = RegExp(r'alt="([^"]*)"').firstMatch(imgTag);
        if (altMatch != null) alt = altMatch.group(1);

        // Extract title
        final titleMatch = RegExp(r'title="([^"]*)"').firstMatch(imgTag);
        final title = titleMatch?.group(1);

        // if (src == null) return '';

        // If no src, return empty
        if (src == null || src.isEmpty) return '';

        // Handle relative URLs
        String imageUrl = src;

        // Check if it's already a full URL
        if (!src.startsWith('http://') && !src.startsWith('https://')) {
          // It's a relative URL
          if (src.startsWith('/')) {
            // Path starts with /, append to base URL
            final baseUrl = ApiEndpoints.baseUrl;
            imageUrl = '$baseUrl$src';
          } else if (src.startsWith('media/') || src.startsWith('/media/')) {
            // Django media path
            final baseUrl = ApiEndpoints.baseUrl;
            if (src.startsWith('media/')) {
              imageUrl = '$baseUrl/$src';
            } else {
              imageUrl = '$baseUrl$src';
            }
          } else if (src.startsWith('uploads/')) {
            // CKEditor uploads path
            final baseUrl = ApiEndpoints.baseUrl;
            imageUrl = '$baseUrl/media/$src';
          } else {
            // Assume it's a relative path from media
            final baseUrl = ApiEndpoints.baseUrl;
            imageUrl = '$baseUrl/media/$src';
          }
        }

        // Clean up any double slashes
        imageUrl = imageUrl.replaceAll('//media/', '/media/');
        imageUrl = imageUrl.replaceAll(':/', '://');

        // Use title as alt text if alt is empty
        final displayAlt = alt?.isNotEmpty == true ? alt : title ?? '';

        print('🖼️ Image URL: $imageUrl');
        print('🖼️ Alt text: $displayAlt');

        return '![${displayAlt}]($imageUrl)';

        // Handle relative URLs
        // if (!src.startsWith('http') && !src.startsWith('/')) {
        //   src = '/media/$src';
        // }

        // return '![${alt ?? title ?? ''}]($src)';
      },
    );

    // 7. Convert headings
    for (int i = 6; i >= 1; i--) {
      result = result.replaceAllMapped(
        RegExp(r'<h$i[^>]*>(.*?)</h$i>', caseSensitive: false, dotAll: true),
        (match) {
          final headingText = match.group(1) ?? '';
          final cleanText = _cleanHtmlText(headingText);
          final hashes = '#' * i;
          return '$hashes $cleanText';
        },
      );
    }

    // 8. Convert lists
    result = result.replaceAllMapped(
      RegExp(r'<ul[^>]*>(.*?)</ul>', caseSensitive: false, dotAll: true),
      (match) {
        String ulContent = match.group(1) ?? '';
        ulContent = ulContent.replaceAllMapped(
          RegExp(r'<li[^>]*>(.*?)</li>', caseSensitive: false, dotAll: true),
          (liMatch) {
            String liContent = liMatch.group(1) ?? '';
            liContent = _cleanHtmlText(liContent);
            return '- $liContent';
          },
        );
        return ulContent;
      },
    );

    result = result.replaceAllMapped(
      RegExp(r'<ol[^>]*>(.*?)</ol>', caseSensitive: false, dotAll: true),
      (match) {
        String olContent = match.group(1) ?? '';
        int counter = 1;
        olContent = olContent.replaceAllMapped(
          RegExp(r'<li[^>]*>(.*?)</li>', caseSensitive: false, dotAll: true),
          (liMatch) {
            String liContent = liMatch.group(1) ?? '';
            liContent = _cleanHtmlText(liContent);
            final result = '$counter. $liContent';
            counter++;
            return result;
          },
        );
        return olContent;
      },
    );

    // 9. Convert paragraphs with proper spacing
    result = result.replaceAllMapped(
      RegExp(r'<p[^>]*>(.*?)</p>', caseSensitive: false, dotAll: true),
      (match) {
        final pContent = match.group(1) ?? '';
        final cleanText = _cleanHtmlText(pContent);
        return '$cleanText\n\n';
      },
    );

    // 10. Convert formatting
    result = result.replaceAllMapped(
      RegExp(
        r'<strong[^>]*>(.*?)</strong>',
        caseSensitive: false,
        dotAll: true,
      ),
      (match) {
        final content = match.group(1) ?? '';
        return '**${_cleanHtmlText(content)}**';
      },
    );

    result = result.replaceAllMapped(
      RegExp(r'<b[^>]*>(.*?)</b>', caseSensitive: false, dotAll: true),
      (match) {
        final content = match.group(1) ?? '';
        return '**${_cleanHtmlText(content)}**';
      },
    );

    result = result.replaceAllMapped(
      RegExp(r'<em[^>]*>(.*?)</em>', caseSensitive: false, dotAll: true),
      (match) {
        final content = match.group(1) ?? '';
        return '*${_cleanHtmlText(content)}*';
      },
    );

    result = result.replaceAllMapped(
      RegExp(r'<i[^>]*>(.*?)</i>', caseSensitive: false, dotAll: true),
      (match) {
        final content = match.group(1) ?? '';
        return '*${_cleanHtmlText(content)}*';
      },
    );

    // 11. Convert links
    result = result.replaceAllMapped(
      RegExp(
        r'<a[^>]*href="([^"]*)"[^>]*>(.*?)</a>',
        caseSensitive: false,
        dotAll: true,
      ),
      (match) {
        final href = match.group(1) ?? '';
        final text = match.group(2) ?? '';
        final cleanText = _cleanHtmlText(text);
        return '[$cleanText]($href)';
      },
    );

    // 12. Convert blockquotes
    result = result.replaceAllMapped(
      RegExp(
        r'<blockquote[^>]*>(.*?)</blockquote>',
        caseSensitive: false,
        dotAll: true,
      ),
      (match) {
        String quoteContent = match.group(1) ?? '';
        quoteContent = _cleanHtmlText(quoteContent);
        final lines = quoteContent.split('\n');
        return lines.map((line) => '> $line').join('\n');
      },
    );

    // 13. Remove remaining HTML tags but keep their content
    result = result.replaceAll(RegExp(r'<[^>]*>'), '');

    // 14. Decode HTML entities
    result = _decodeHtmlEntities(result);

    // 15. Clean up whitespace
    result = result
        .replaceAll(RegExp(r'\n\s*\n\s*\n'), '\n\n')
        .replaceAll(RegExp(r'[ \t]+'), ' ')
        .trim();

    print(
      '📝 Converted Markdown: ${result.substring(0, min(200, result.length))}...',
    );
    return result;
  }

  List<Widget> _parseContentForDisplay(
    String content, {
    bool isAnswer = false,
  }) {
    final List<Widget> widgets = [];
    final lines = content.split('\n');
    bool inCodeBlock = false;
    bool inMathBlock = false;
    List<String> currentCodeBlock = [];
    String? currentLanguage;
    List<String> currentMathBlock = [];

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      final trimmedLine = line.trim();

      // Skip if inside code or math block
      if (inCodeBlock || inMathBlock) {
        if (inCodeBlock) {
          if (trimmedLine.startsWith('```')) {
            inCodeBlock = false;
            final codeContent = currentCodeBlock.join('\n');
            widgets.add(_buildCodeBlock(codeContent, currentLanguage ?? ''));
          } else {
            currentCodeBlock.add(line);
          }
        }
        if (inMathBlock) {
          if (trimmedLine.startsWith(r'$$')) {
            inMathBlock = false;
            if (currentMathBlock.isNotEmpty) {
              widgets.add(_buildMathBlock(currentMathBlock.join('\n')));
            }
          } else {
            currentMathBlock.add(line);
          }
        }
        continue;
      }

      // Handle tables
      if (_isTableStart(lines, i)) {
        final tableLines = _extractTableLines(lines, i);
        if (tableLines.isNotEmpty) {
          widgets.add(_buildMarkdownTable(tableLines.join('\n')));
          i += tableLines.length - 1;
        }
        continue;
      }

      // Handle plain text tables where cells are separated with tabs
      if (_isTabSeparatedTableStart(lines, i)) {
        final tableLines = _extractTabSeparatedTableLines(lines, i);
        if (tableLines.isNotEmpty) {
          widgets.add(_buildPlainTextTable(tableLines));
          i += tableLines.length - 1;
        }
        continue;
      }

      // Handle math blocks with $$
      if (trimmedLine.startsWith(r'$$')) {
        if (!inMathBlock) {
          inMathBlock = true;
          currentMathBlock = [];
        } else {
          inMathBlock = false;
          if (currentMathBlock.isNotEmpty) {
            widgets.add(_buildMathBlock(currentMathBlock.join('\n')));
          }
        }
        continue;
      }

      if (inMathBlock) {
        currentMathBlock.add(line);
        continue;
      }

      // Handle LaTeX math blocks with \[ \]
      if (trimmedLine.contains(r'\[') && trimmedLine.contains(r'\]')) {
        final startIndex = trimmedLine.indexOf(r'\[');
        final endIndex = trimmedLine.indexOf(r'\]');
        if (startIndex != -1 && endIndex != -1 && endIndex > startIndex) {
          final mathContent = trimmedLine.substring(startIndex + 2, endIndex);
          widgets.add(_buildMathBlock(mathContent));

          final beforeMath = trimmedLine.substring(0, startIndex);
          if (beforeMath.isNotEmpty) {
            widgets.add(_buildText(beforeMath, isAnswer: isAnswer));
          }

          final afterMath = trimmedLine.substring(endIndex + 2);
          if (afterMath.isNotEmpty) {
            widgets.add(_buildText(afterMath, isAnswer: isAnswer));
          }
          continue;
        }
      }

      // Handle inline math with $ or \( \)
      if (_containsInlineMath(line)) {
        widgets.add(_buildInlineMathText(line, isAnswer: isAnswer));
        continue;
      }

      // Handle code blocks
      if (trimmedLine.startsWith('```')) {
        if (!inCodeBlock) {
          inCodeBlock = true;
          currentCodeBlock = [];
          currentLanguage = trimmedLine.replaceAll('```', '').trim();
        } else {
          inCodeBlock = false;
          final codeContent = currentCodeBlock.join('\n');
          widgets.add(_buildCodeBlock(codeContent, currentLanguage ?? ''));
        }
        continue;
      }

      if (inCodeBlock) {
        currentCodeBlock.add(line);
        continue;
      }

      // Handle inline code
      if (_containsInlineCode(line)) {
        widgets.add(_buildInlineCode(line));
        continue;
      }

      // Handle mixed text/image lines without dropping surrounding text
      if (_containsImageMarkup(line)) {
        if (_isStandaloneImageLine(line)) {
          widgets.add(_buildImage(line.trim()));
        } else {
          widgets.addAll(_buildMixedContentLine(line, isAnswer: isAnswer));
        }
        continue;
      }

      // Handle headings
      if (trimmedLine.startsWith('#')) {
        widgets.add(_buildHeading(line));
        continue;
      }

      // Handle lists
      if (_isListItem(line)) {
        final listItems = _extractListItems(lines, i);
        widgets.add(_buildList(listItems));
        i += listItems.length - 1;
        continue;
      }

      // Regular paragraphs
      if (trimmedLine.isNotEmpty) {
        if (i == 0 || lines[i - 1].trim().isEmpty) {
          final paragraph = _extractParagraph(lines, i);
          if (_containsInlineMath(paragraph)) {
            widgets.add(_buildInlineMathText(paragraph, isAnswer: isAnswer));
          } else {
            widgets.add(_buildParagraph(paragraph, isAnswer: isAnswer));
          }
          i += paragraph.split('\n').length - 1;
        }
      } else {
        if (i > 0 && lines[i - 1].trim().isNotEmpty) {
          widgets.add(const SizedBox(height: 8));
        }
      }
    }

    // Handle any remaining blocks
    if (inCodeBlock && currentCodeBlock.isNotEmpty) {
      final codeContent = currentCodeBlock.join('\n');
      widgets.add(_buildCodeBlock(codeContent, currentLanguage ?? ''));
    }

    if (inMathBlock && currentMathBlock.isNotEmpty) {
      widgets.add(_buildMathBlock(currentMathBlock.join('\n')));
    }

    return widgets;
  }

  // ========== CONTENT PARSING HELPER METHODS ==========

  bool _isTableStart(List<String> lines, int index) {
    if (index >= lines.length) return false;
    final line = lines[index].trim();
    if (!line.startsWith('|')) return false;
    if (index + 1 >= lines.length) return false;

    final nextLine = lines[index + 1].trim();
    if (!nextLine.startsWith('|')) return false;

    final pipeCount = '|'.allMatches(nextLine).length;
    if (pipeCount < 2) return false;

    final parts = nextLine.split('|');
    for (int i = 1; i < parts.length - 1; i++) {
      final part = parts[i].trim();
      if (part.isNotEmpty && !RegExp(r'^:?-+:?$').hasMatch(part)) {
        return false;
      }
    }

    return true;
  }

  List<String> _extractTableLines(List<String> lines, int startIndex) {
    final tableLines = <String>[];

    for (int i = startIndex; i < lines.length; i++) {
      final line = lines[i].trim();
      if (!line.startsWith('|')) break;

      if (i > startIndex && line.contains('---')) {
        final parts = line.split('|');
        bool isValidSeparator = true;
        for (int j = 1; j < parts.length - 1; j++) {
          final part = parts[j].trim();
          if (part.isNotEmpty && !RegExp(r'^:?-+:?$').hasMatch(part)) {
            isValidSeparator = false;
            break;
          }
        }
        if (!isValidSeparator) break;
      }

      tableLines.add(line);
      if (tableLines.length > 50) break;
    }

    return tableLines;
  }

  bool _isTabSeparatedTableStart(List<String> lines, int index) {
    if (index >= lines.length) return false;
    final current = lines[index].trim();
    if (!current.contains('\t')) return false;
    if (index + 1 >= lines.length) return false;

    final next = lines[index + 1].trim();
    if (!next.contains('\t')) return false;

    final currentColumns = current.split(RegExp(r'\t+')).length;
    final nextColumns = next.split(RegExp(r'\t+')).length;
    return currentColumns >= 2 && currentColumns == nextColumns;
  }

  List<String> _extractTabSeparatedTableLines(List<String> lines, int startIndex) {
    final tableLines = <String>[];
    int? expectedColumns;

    for (int i = startIndex; i < lines.length; i++) {
      final line = lines[i].trim();
      if (!line.contains('\t')) break;

      final columns = line.split(RegExp(r'\t+')).length;
      expectedColumns ??= columns;

      if (columns != expectedColumns || columns < 2) break;
      tableLines.add(line);
    }

    return tableLines;
  }

  bool _containsInlineMath(String text) {
    final hasDollarMath =
        RegExp(r'[^\\]\$[^\$].*?[^\\]\$').hasMatch(text) ||
        RegExp(r'^\$[^\$].*?[^\\]\$').hasMatch(text);
    final hasLatexInline = text.contains(r'\(') && text.contains(r'\)');
    return hasDollarMath || hasLatexInline;
  }

  bool _containsInlineCode(String line) {
    final regex = RegExp(r'`[^`\n]+`');
    return regex.hasMatch(line);
  }

  bool _containsImageMarkup(String line) {
    final markdownImageRegex = RegExp(r'!\[.*?\]\(.*?\)');
    final htmlImageRegex = RegExp(
      r'<img[^>]*src="[^"]+"[^>]*>',
      caseSensitive: false,
    );

    return markdownImageRegex.hasMatch(line) || htmlImageRegex.hasMatch(line);
  }

  bool _isStandaloneImageLine(String line) {
    final trimmed = line.trim();
    final markdownImageRegex = RegExp(r'^!\[.*?\]\(.*?\)$');
    final htmlImageRegex = RegExp(
      r'^<img[^>]*src="[^"]+"[^>]*>$',
      caseSensitive: false,
    );
    final urlRegex = RegExp(
      r'^https?://[^\s]+\.(jpg|jpeg|png|gif|bmp|webp|svg)(\?.*)?$',
      caseSensitive: false,
    );

    return markdownImageRegex.hasMatch(trimmed) ||
        htmlImageRegex.hasMatch(trimmed) ||
        urlRegex.hasMatch(trimmed);
  }

  bool _isListItem(String line) {
    final trimmed = line.trim();
    return trimmed.startsWith('- ') ||
        trimmed.startsWith('* ') ||
        trimmed.startsWith('+ ') ||
        RegExp(r'^\d+\.\s').hasMatch(trimmed) ||
        RegExp(r'^[-*+]\s').hasMatch(trimmed);
  }

  List<String> _extractListItems(List<String> lines, int startIndex) {
    final items = <String>[];

    for (int i = startIndex; i < lines.length; i++) {
      if (_isListItem(lines[i])) {
        items.add(lines[i]);
      } else {
        break;
      }
    }

    return items;
  }

  String _extractParagraph(List<String> lines, int startIndex) {
    final paragraphLines = <String>[];
    for (int i = startIndex; i < lines.length; i++) {
      final line = lines[i];
      final trimmed = line.trim();
      if (trimmed.isEmpty) break;

      if (_isListItem(line) ||
          _isTableLine(line) ||
          _containsInlineMath(line) ||
          trimmed.startsWith('#') ||
          trimmed.startsWith(r'$$') ||
          (trimmed.contains(r'\[') && trimmed.contains(r'\]'))) {
        break;
      }
      paragraphLines.add(line);
    }
    return paragraphLines.join('\n');
  }

  List<Widget> _buildMixedContentLine(String line, {bool isAnswer = false}) {
    final widgets = <Widget>[];
    final markdownImageRegex = RegExp(r'!\[.*?\]\(.*?\)');
    final matches = markdownImageRegex.allMatches(line).toList();

    if (matches.isEmpty) {
      widgets.add(_buildText(line, isAnswer: isAnswer));
      return widgets;
    }

    int lastIndex = 0;

    for (final match in matches) {
      final beforeImage = line.substring(lastIndex, match.start).trim();
      if (beforeImage.isNotEmpty) {
        if (_containsInlineMath(beforeImage)) {
          widgets.add(_buildInlineMathText(beforeImage, isAnswer: isAnswer));
        } else {
          widgets.add(_buildText(beforeImage, isAnswer: isAnswer));
        }
      }

      widgets.add(_buildImage(match.group(0)!));
      lastIndex = match.end;
    }

    final afterLastImage = line.substring(lastIndex).trim();
    if (afterLastImage.isNotEmpty) {
      if (_containsInlineMath(afterLastImage)) {
        widgets.add(_buildInlineMathText(afterLastImage, isAnswer: isAnswer));
      } else {
        widgets.add(_buildText(afterLastImage, isAnswer: isAnswer));
      }
    }

    return widgets;
  }

  bool _isTableLine(String line) {
    return line.contains('|') &&
        line.split('|').where((p) => p.trim().isNotEmpty).length >= 2;
  }

  bool _isMarkdownSeparatorLine(String line) {
    final trimmed = line.trim();
    if (!trimmed.startsWith('|')) return false;

    final parts = trimmed.split('|');
    for (int i = 1; i < parts.length - 1; i++) {
      final part = parts[i].trim();
      if (part.isNotEmpty && !RegExp(r'^:?-+:?$').hasMatch(part)) {
        return false;
      }
    }

    return true;
  }

  // ========== WIDGET BUILDERS ==========

  Widget _buildText(String text, {bool isAnswer = false}) {
    return _buildRichTextBlock(
      text,
      isAnswer: isAnswer,
      padding: const EdgeInsets.symmetric(vertical: 4),
    );
  }

  Widget _buildRichTextBlock(
    String text, {
    bool isAnswer = false,
    bool isHeader = false,
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
    EdgeInsetsGeometry padding = EdgeInsets.zero,
  }) {
    final resolvedStyle = TextStyle(
      fontSize: fontSize ?? (isAnswer ? 16 : 14),
      fontWeight: fontWeight ?? FontWeight.normal,
      color:
          color ??
          (isAnswer ? const Color(0xFF10B981) : const Color(0xFF666666)),
      height: 1.6,
    );

    return Padding(
      padding: padding,
      child: RichText(
        text: TextSpan(
          style: resolvedStyle,
          children: _buildInlineSpans(
            text,
            baseStyle: resolvedStyle,
            isAnswer: isAnswer,
            isHeader: isHeader,
          ),
        ),
      ),
    );
  }

  List<InlineSpan> _buildInlineSpans(
    String text, {
    required TextStyle baseStyle,
    bool isAnswer = false,
    bool isHeader = false,
  }) {
    final spans = <InlineSpan>[];
    int index = 0;

    while (index < text.length) {
      if (text.startsWith(r'\(', index)) {
        final end = text.indexOf(r'\)', index + 2);
        if (end != -1) {
          final mathContent = text.substring(index + 2, end);
          spans.add(
            WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: _buildMathWidget(mathContent, isInline: true),
              ),
            ),
          );
          index = end + 2;
          continue;
        }
      }

      if (text[index] == r'$') {
        final end = _findClosingDollar(text, index + 1);
        if (end != -1) {
          final mathContent = text.substring(index + 1, end);
          spans.add(
            WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: _buildMathWidget(mathContent, isInline: true),
              ),
            ),
          );
          index = end + 1;
          continue;
        }
      }

      if (text.startsWith('**', index) || text.startsWith('__', index)) {
        final marker = text.substring(index, index + 2);
        final end = text.indexOf(marker, index + 2);
        if (end != -1) {
          final content = text.substring(index + 2, end);
          spans.add(
            TextSpan(
              text: content,
              style: baseStyle.copyWith(fontWeight: FontWeight.bold),
            ),
          );
          index = end + 2;
          continue;
        }
      }

      if (text.startsWith('~~', index)) {
        final end = text.indexOf('~~', index + 2);
        if (end != -1) {
          final content = text.substring(index + 2, end);
          spans.add(
            TextSpan(
              text: content,
              style: baseStyle.copyWith(
                decoration: TextDecoration.lineThrough,
              ),
            ),
          );
          index = end + 2;
          continue;
        }
      }

      if (text[index] == '`') {
        final end = text.indexOf('`', index + 1);
        if (end != -1) {
          final content = text.substring(index + 1, end);
          spans.add(
            TextSpan(
              text: content,
              style: baseStyle.copyWith(
                backgroundColor: Colors.grey.shade200,
                color: Colors.red.shade700,
                fontFamily: 'RobotoMono',
                fontSize: (baseStyle.fontSize ?? 14) - 1,
                fontWeight: FontWeight.w500,
              ),
            ),
          );
          index = end + 1;
          continue;
        }
      }

      if (text[index] == '[') {
        final labelEnd = text.indexOf(']', index + 1);
        if (labelEnd != -1 &&
            labelEnd + 1 < text.length &&
            text[labelEnd + 1] == '(') {
          final urlEnd = text.indexOf(')', labelEnd + 2);
          if (urlEnd != -1) {
            final label = text.substring(index + 1, labelEnd);
            spans.add(
              TextSpan(
                text: label,
                style: baseStyle.copyWith(
                  color: Colors.blue.shade700,
                  decoration: TextDecoration.underline,
                ),
              ),
            );
            index = urlEnd + 1;
            continue;
          }
        }
      }

      if (text[index] == '*' || text[index] == '_') {
        final marker = text[index];
        final end = text.indexOf(marker, index + 1);
        if (end != -1) {
          final content = text.substring(index + 1, end);
          spans.add(
            TextSpan(
              text: content,
              style: baseStyle.copyWith(fontStyle: FontStyle.italic),
            ),
          );
          index = end + 1;
          continue;
        }
      }

      final nextToken = _findNextInlineTokenIndex(text, index + 1);
      spans.add(
        TextSpan(
          text: text.substring(index, nextToken),
          style: baseStyle,
        ),
      );
      index = nextToken;
    }

    return spans;
  }

  int _findNextInlineTokenIndex(String text, int start) {
    final tokenStarts = <int>[];
    final tokens = [r'\(', r'$', '**', '__', '~~', '`', '[', '*', '_'];

    for (final token in tokens) {
      final tokenIndex = text.indexOf(token, start);
      if (tokenIndex != -1) {
        tokenStarts.add(tokenIndex);
      }
    }

    if (tokenStarts.isEmpty) return text.length;
    tokenStarts.sort();
    return tokenStarts.first;
  }

  int _findClosingDollar(String text, int start) {
    for (int i = start; i < text.length; i++) {
      if (text[i] == r'$' && text[i - 1] != r'\') {
        return i;
      }
    }
    return -1;
  }

  Widget _buildInlineContent(
    String text, {
    bool isAnswer = false,
    bool isHeader = false,
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
  }) {
    final resolvedStyle = TextStyle(
      fontSize: fontSize ?? (isAnswer ? 16 : 14),
      fontWeight: fontWeight ?? FontWeight.normal,
      color:
          color ??
          (isAnswer ? const Color(0xFF10B981) : const Color(0xFF666666)),
      height: 1.5,
    );

    return RichText(
      text: TextSpan(
        style: resolvedStyle,
        children: _buildInlineSpans(
          text,
          baseStyle: resolvedStyle,
          isAnswer: isAnswer,
          isHeader: isHeader,
        ),
      ),
    );
  }

  Widget _buildParagraph(String text, {bool isAnswer = false}) {
    return _buildRichTextBlock(
      text,
      isAnswer: isAnswer,
      padding: const EdgeInsets.symmetric(vertical: 8),
    );
  }

  Widget _buildInlineMathText(String text, {bool isAnswer = false}) {
    return _buildRichTextBlock(
      text,
      isAnswer: isAnswer,
      padding: const EdgeInsets.symmetric(vertical: 4),
    );
  }

  Widget _buildMathBlock(String mathContent) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade200, width: 1),
      ),
      child: Center(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: _buildMathWidget(mathContent.trim(), isInline: false),
        ),
      ),
    );
  }

  Widget _buildMathWidget(String mathContent, {bool isInline = true}) {
    String cleanMath = mathContent;
    cleanMath = cleanMath.replaceAll(r'\over', r'\frac');
    cleanMath = cleanMath.replaceAll(r'\pm', r'\pm');

    return Container(
      padding: EdgeInsets.all(isInline ? 4 : 0),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Math.tex(
          cleanMath,
          textStyle: TextStyle(
            fontSize: isInline ? 14 : 16,
            color: Colors.blue.shade900,
          ),
          onErrorFallback: (FlutterMathException e) {
            print('Math rendering error: $e for expression: $cleanMath');
            String simplifiedMath = mathContent
                .replaceAll(r'\over', '/')
                .replaceAll(r'\pm', '±')
                .replaceAll(r'\sqrt', '√');

            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: SelectableText(
                  simplifiedMath,
                  style: TextStyle(
                    fontFamily: 'RobotoMono',
                    color: Colors.orange.shade800,
                    fontSize: isInline ? 12 : 14,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildCodeBlock(String code, String language) {
    final langMap = {
      'python': 'Python',
      'javascript': 'JavaScript',
      'java': 'Java',
      'cpp': 'C++',
      'c': 'C',
      'html': 'HTML',
      'css': 'CSS',
      'dart': 'Dart',
      'sql': 'SQL',
      'bash': 'Bash',
      'json': 'JSON',
      'yaml': 'YAML',
    };

    final displayLang = langMap[language] ?? language.toUpperCase();

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade700),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey.shade900,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(8),
                topRight: Radius.circular(8),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.code_rounded,
                      size: 18,
                      color: Colors.blue.shade300,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      displayLang,
                      style: TextStyle(
                        color: Colors.blue.shade300,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade800,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '${code.split('\n').length} lines',
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 11,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    GestureDetector(
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: code));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Code copied to clipboard'),
                            backgroundColor: Colors.green,
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade800,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Row(
                          children: [
                            Icon(
                              Icons.content_copy,
                              size: 14,
                              color: Colors.white,
                            ),
                            SizedBox(width: 6),
                            Text(
                              'Copy',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Container(
                constraints: BoxConstraints(
                  minWidth: MediaQuery.of(context).size.width - 32,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: code.split('\n').asMap().entries.map((entry) {
                    final lineNumber = entry.key + 1;
                    final lineContent = entry.value;

                    return Container(
                      constraints: BoxConstraints(
                        minWidth: MediaQuery.of(context).size.width - 32,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 40,
                            child: Text(
                              lineNumber.toString().padLeft(3, ' '),
                              style: const TextStyle(
                                fontFamily: 'RobotoMono',
                                fontSize: 13,
                                color: Colors.grey,
                              ),
                              textAlign: TextAlign.right,
                            ),
                          ),
                          const SizedBox(width: 16),
                          ConstrainedBox(
                            constraints: BoxConstraints(
                              minWidth: MediaQuery.of(context).size.width - 120,
                            ),
                            child: SelectableText(
                              lineContent,
                              style: const TextStyle(
                                fontFamily: 'RobotoMono',
                                fontSize: 14,
                                color: Color(0xFFD4D4D4),
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInlineCode(String text) {
    return _buildRichTextBlock(
      text,
      padding: const EdgeInsets.symmetric(vertical: 4),
    );
  }

  Widget _buildImage(String line) {
    try {
      String imageUrl = '';
      String altText = '';

      final markdownRegex = RegExp(r'!\[(.*?)\]\((.*?)\)');
      final markdownMatch = markdownRegex.firstMatch(line);

      if (markdownMatch != null) {
        altText = markdownMatch.group(1) ?? '';
        imageUrl = markdownMatch.group(2) ?? '';
        print('🖼️ Parsed markdown image: URL=$imageUrl, Alt=$altText');
      } else {
        final urlRegex = RegExp(r'https?://[^\s]+');
        final urlMatch = urlRegex.firstMatch(line);
        if (urlMatch != null) {
          imageUrl = urlMatch.group(0) ?? '';
          print('🖼️ Parsed direct URL image: $imageUrl');
        }
      }

      if (imageUrl.isNotEmpty) {
        return _buildImageFromSource(imageUrl, altText: altText);
      }
    } catch (e) {
      print('❌ Error in _buildImage: $e');
      print('   Line: $line');
    }

    return const SizedBox.shrink();
  }

  Widget _buildImageFromSource(String src, {String altText = ''}) {
    if (src.isEmpty) return const SizedBox.shrink();

    final imageUrl = _normalizeImageUrl(src);

    if (imageUrl.startsWith('hive://')) {
      final imageKey = imageUrl.replaceFirst('hive://', '');
      print('🖼️ Loading Hive image with key: $imageKey');

      return FutureBuilder<Uint8List?>(
        future: _loadHiveImage(imageKey),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Container(
              height: 200,
              color: Colors.grey.shade100,
              child: const Center(child: CircularProgressIndicator()),
            );
          } else if (snapshot.hasError || snapshot.data == null) {
            print('❌ Failed to load Hive image: ${snapshot.error}');
            return _buildErrorImage('Hive image load failed');
          }

          return _buildImageContainer(
            image: Image.memory(snapshot.data!, fit: BoxFit.contain),
            altText: altText,
          );
        },
      );
    }

    if (imageUrl.startsWith('/') && !imageUrl.startsWith('http')) {
      print('🖼️ Loading local file image: $imageUrl');
      return _buildImageContainer(
        image: Image.file(
          File(imageUrl),
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            print('❌ Error loading local image: $error');
            return _buildErrorImage('Local image load failed');
          },
        ),
        altText: altText,
      );
    }

    final cleanUrl = imageUrl.replaceAll(RegExp(r'(?<!:)/{2,}'), '/');
    print('🖼️ Loading network image: $cleanUrl');

    return _buildImageContainer(
      image: CachedNetworkImage(
        imageUrl: cleanUrl,
        placeholder: (context, url) => Container(
          height: 200,
          color: Colors.grey.shade100,
          child: const Center(child: CircularProgressIndicator()),
        ),
        errorWidget: (context, url, error) {
          print('❌ Error loading network image: $error, URL: $url');
          return _buildErrorImage('Network image load failed');
        },
        fit: BoxFit.contain,
      ),
      altText: altText,
    );
  }

  Widget _buildImageContainer({required Widget image, String altText = ''}) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: image,
          ),
          if (altText.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                altText,
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF666666),
                  fontStyle: FontStyle.italic,
                ),
                textAlign: TextAlign.center,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHeading(String line) {
    final trimmed = line.trim();
    int level = 0;

    for (int i = 0; i < trimmed.length && i < 6; i++) {
      if (trimmed[i] == '#') {
        level++;
      } else {
        break;
      }
    }

    final text = trimmed.substring(level).trim();

    double fontSize;
    FontWeight fontWeight;
    Color color;
    EdgeInsets padding;

    switch (level) {
      case 1:
        fontSize = 20;
        fontWeight = FontWeight.bold;
        color = const Color(0xFF333333);
        padding = const EdgeInsets.only(top: 16, bottom: 8);
        break;
      case 2:
        fontSize = 18;
        fontWeight = FontWeight.bold;
        color = const Color(0xFF333333);
        padding = const EdgeInsets.only(top: 14, bottom: 6);
        break;
      case 3:
        fontSize = 16;
        fontWeight = FontWeight.w600;
        color = const Color(0xFF444444);
        padding = const EdgeInsets.only(top: 12, bottom: 4);
        break;
      default:
        fontSize = 14;
        fontWeight = FontWeight.w600;
        color = const Color(0xFF666666);
        padding = const EdgeInsets.only(top: 8, bottom: 2);
    }

    return Padding(
      padding: padding,
      child: _buildInlineContent(
        text,
        isHeader: true,
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
      ),
    );
  }

  Widget _buildList(List<String> items) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: items.map((item) {
          final trimmed = item.trim();
          bool isNumbered = RegExp(r'^\d+\.\s').hasMatch(trimmed);
          final text = isNumbered
              ? trimmed.replaceFirst(RegExp(r'^\d+\.\s'), '')
              : trimmed.substring(2);

          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 5, right: 12),
                  child: isNumbered
                      ? Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            color: Colors.blue.shade100,
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              trimmed.split('.')[0],
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue,
                              ),
                            ),
                          ),
                        )
                      : Container(
                          width: 6,
                          height: 6,
                          margin: const EdgeInsets.only(top: 8),
                          decoration: const BoxDecoration(
                            color: Color(0xFF666666),
                            shape: BoxShape.circle,
                          ),
                        ),
                ),
                Expanded(child: _buildText(text)),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildMarkdownTable(String tableMarkdown) {
    try {
      final lines = tableMarkdown.trim().split('\n');
      if (lines.length < 2) return Container();

      final hasHeader =
          lines.length > 1 && _isMarkdownSeparatorLine(lines[1]);
      final rows = <List<String>>[];

      for (int i = 0; i < lines.length; i++) {
        if (hasHeader && i == 1) continue;
        if (lines[i].trim().isEmpty) continue;
        rows.add(_parseTableRow(lines[i]));
      }

      return _buildTable(rows, hasHeader: hasHeader);
    } catch (e) {
      print('Error rendering table: $e');
      return Container(
        padding: const EdgeInsets.all(16),
        color: Colors.red.shade50,
        child: Text('Error rendering table: $e'),
      );
    }
  }

  List<String> _parseTableRow(String row) {
    final cleanRow = row.trim().replaceAll(RegExp(r'^\||\|$'), '');
    return cleanRow.split('|').map((cell) => cell.trim()).toList();
  }

  Widget _buildPlainTextTable(List<String> tableLines) {
    final rows = tableLines
        .map((line) => line.split(RegExp(r'\t+')).map((cell) => cell.trim()).toList())
        .toList();

    return _buildTable(rows, hasHeader: false);
  }

  Widget _buildHtmlTable(List<List<String>> rows, {bool hasHeader = false}) {
    if (rows.isEmpty) return const SizedBox.shrink();

    final normalizedRows = rows.map((row) => List<String>.from(row)).toList();
    final columnCount = normalizedRows
        .map((row) => row.length)
        .fold<int>(0, (maxColumns, rowLength) => max(maxColumns, rowLength));

    for (final row in normalizedRows) {
      while (row.length < columnCount) {
        row.add('');
      }
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
        color: Colors.white,
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: BoxConstraints(minWidth: columnCount * 200),
          child: Table(
            defaultVerticalAlignment: TableCellVerticalAlignment.middle,
            border: TableBorder.symmetric(
              inside: BorderSide(color: Colors.grey.shade300),
            ),
            columnWidths: {
              for (int i = 0; i < columnCount; i++) i: const IntrinsicColumnWidth(),
            },
            children: normalizedRows.asMap().entries.map((entry) {
              final rowIndex = entry.key;
              final row = entry.value;
              final isHeaderRow = hasHeader && rowIndex == 0;

              return TableRow(
                decoration: BoxDecoration(
                  color: isHeaderRow ? Colors.blue.shade50 : Colors.white,
                ),
                children: row.map((cellHtml) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    child: _buildHtmlTableCell(
                      cellHtml,
                      isHeader: isHeaderRow,
                    ),
                  );
                }).toList(),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildHtmlTableCell(String cellHtml, {bool isHeader = false}) {
    final processedCellHtml = _replaceDollarMathWithCustomTags(
      _replaceCkEditorMathWithCustomTags(
        _normalizeCkEditorImageUrls(_convertMarkdownImagesToHtml(cellHtml)),
      ),
    );

    return Html(
      data: processedCellHtml,
      shrinkWrap: true,
      extensions: [
        TagExtension(
          tagsToExtend: {'tex-inline'},
          builder: (context) => _buildMathWidget(
            _decodeHtmlEntities(context.innerHtml.trim()),
            isInline: true,
          ),
        ),
        TagExtension(
          tagsToExtend: {'tex-block'},
          builder: (context) => _buildMathBlock(
            _decodeHtmlEntities(context.innerHtml.trim()),
          ),
        ),
      ],
      style: {
        'html': Style(margin: Margins.zero, padding: HtmlPaddings.zero),
        'body': Style(
          margin: Margins.zero,
          padding: HtmlPaddings.zero,
          color: Colors.black87,
          fontSize: FontSize(isHeader ? 14 : 13),
          fontWeight: isHeader ? FontWeight.bold : FontWeight.normal,
          lineHeight: LineHeight(1.5),
        ),
        'p': Style(margin: Margins.zero, padding: HtmlPaddings.zero),
        'div': Style(margin: Margins.zero, padding: HtmlPaddings.zero),
        'strong': Style(fontWeight: FontWeight.bold),
        'b': Style(fontWeight: FontWeight.bold),
        'em': Style(fontStyle: FontStyle.italic),
        'i': Style(fontStyle: FontStyle.italic),
        'img': Style(margin: Margins.only(top: 6, bottom: 6)),
      },
    );
  }

  Widget _buildTable(List<List<String>> rows, {bool hasHeader = false}) {
    if (rows.isEmpty) return const SizedBox.shrink();

    final normalizedRows = rows.map((row) => List<String>.from(row)).toList();
    final columnCount = normalizedRows
        .map((row) => row.length)
        .fold<int>(0, (maxColumns, rowLength) => max(maxColumns, rowLength));

    for (final row in normalizedRows) {
      while (row.length < columnCount) {
        row.add('');
      }
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: BoxConstraints(minWidth: columnCount * 180),
          child: Table(
            defaultVerticalAlignment: TableCellVerticalAlignment.middle,
            border: TableBorder.symmetric(
              inside: BorderSide(color: Colors.grey.shade300),
            ),
            columnWidths: {
              for (int i = 0; i < columnCount; i++) i: const IntrinsicColumnWidth(),
            },
            children: normalizedRows.asMap().entries.map((entry) {
              final rowIndex = entry.key;
              final row = entry.value;
              final isHeaderRow = hasHeader && rowIndex == 0;

              return TableRow(
                decoration: BoxDecoration(
                  color: isHeaderRow ? Colors.blue.shade50 : Colors.white,
                ),
                children: row.map((cell) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    child: _buildTableCellContent(
                      cell,
                      isHeader: isHeaderRow,
                    ),
                  );
                }).toList(),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  String _convertHtmlTablesToMarkdown(String html) {
    String result = html;

    final tableRegex = RegExp(
      r'<table[^>]*>(.*?)</table>',
      caseSensitive: false,
      dotAll: true,
    );

    result = result.replaceAllMapped(tableRegex, (tableMatch) {
      String tableHtml = tableMatch.group(1) ?? '';
      List<List<String>> rows = [];

      final rowRegex = RegExp(
        r'<tr[^>]*>(.*?)</tr>',
        caseSensitive: false,
        dotAll: true,
      );
      final rowMatches = rowRegex.allMatches(tableHtml);

      for (final rowMatch in rowMatches) {
        String rowHtml = rowMatch.group(1) ?? '';
        List<String> cells = [];

        final cellRegex = RegExp(
          r'<(th|td)[^>]*>(.*?)</\1>',
          caseSensitive: false,
          dotAll: true,
        );
        final cellMatches = cellRegex.allMatches(rowHtml);

        for (final cellMatch in cellMatches) {
          String cellContent = cellMatch.group(2) ?? '';
          cellContent = _preserveMathInCell(cellContent);
          cellContent = _cleanHtmlText(cellContent);
          cells.add(cellContent);
        }

        if (cells.isNotEmpty) {
          rows.add(cells);
        }
      }

      if (rows.isEmpty) return '';

      final markdownTable = _rowsToMarkdownTable(rows);
      return '\n\n$markdownTable\n\n';
    });

    return result;
  }

  String _preserveMathInCell(String cellContent) {
    String result = cellContent;

    result = result.replaceAllMapped(RegExp(r'\\\((.*?)\\\)', dotAll: true), (
      match,
    ) {
      final mathContent = match.group(1) ?? '';
      return '\$$mathContent\$';
    });

    result = result.replaceAllMapped(RegExp(r'\\\[(.*?)\\\]', dotAll: true), (
      match,
    ) {
      final mathContent = match.group(1) ?? '';
      return '\$\$$mathContent\$\$';
    });

    result = result
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>');

    return result;
  }

  String _rowsToMarkdownTable(List<List<String>> rows) {
    if (rows.isEmpty) return '';

    final List<String> markdownRows = [];
    final int columnCount = rows[0].length;

    markdownRows.add('| ${rows[0].join(' | ')} |');

    final separator =
        '|' + List<String>.generate(columnCount, (_) => '---').join('|') + '|';
    markdownRows.add(separator);

    for (int i = 1; i < rows.length; i++) {
      final row = rows[i];
      final paddedRow = List<String>.from(row);
      while (paddedRow.length < columnCount) {
        paddedRow.add('');
      }
      while (paddedRow.length > columnCount) {
        paddedRow.removeLast();
      }
      markdownRows.add('| ${paddedRow.join(' | ')} |');
    }

    return markdownRows.join('\n');
  }

  Widget _buildTableCellContent(String cellContent, {bool isHeader = false}) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 240),
      child: _buildInlineContent(
        cellContent,
        isHeader: isHeader,
        fontSize: isHeader ? 14 : 13,
        fontWeight: isHeader ? FontWeight.bold : FontWeight.normal,
        color: Colors.black87,
      ),
    );
  }

  bool _containsMath(String line) {
    return line.contains(r'$') ||
        line.contains(r'\(') ||
        line.contains(r'\[') ||
        line.contains(r'$$');
  }

  String _cleanHtmlText(String text) {
    return text.replaceAll(RegExp(r'<[^>]*>'), '').replaceAll('\n', ' ').trim();
  }

  // String _decodeHtmlEntities(String text) {
  //   return text
  //       .replaceAll('&nbsp;', ' ')
  //       .replaceAll('&amp;', '&')
  //       .replaceAll('&lt;', '<')
  //       .replaceAll('&gt;', '>')
  //       .replaceAll('&quot;', '"')
  //       .replaceAll('&#39;', "'")
  //       .replaceAll('&ldquo;', '"')
  //       .replaceAll('&rdquo;', '"')
  //       .replaceAll('&lsquo;', "'")
  //       .replaceAll('&rsquo;', "'")
  //       .replaceAll('&hellip;', '...')
  //       .replaceAll('&mdash;', '—')
  //       .replaceAll('&ndash;', '–')
  //       .replaceAll('&copy;', '©')
  //       .replaceAll('&reg;', '®')
  //       .replaceAll('&trade;', '™')
  //       .replaceAll('&times;', '×')
  //       .replaceAll('&divide;', '÷')
  //       .replaceAll('&plusmn;', '±');
  // }

  String _decodeHtmlEntities(String text) {
    return text
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&apos;', "'")
        .replaceAll('&ldquo;', '"')
        .replaceAll('&rdquo;', '"')
        .replaceAll('&lsquo;', "'")
        .replaceAll('&rsquo;', "'")
        .replaceAll('&hellip;', '...')
        .replaceAll('&mdash;', '—')
        .replaceAll('&ndash;', '–')
        .replaceAll('&copy;', '©')
        .replaceAll('&reg;', '®')
        .replaceAll('&trade;', '™')
        .replaceAll('&times;', '×')
        .replaceAll('&divide;', '÷')
        .replaceAll('&plusmn;', '±')
        .replaceAll('&frac12;', '½')
        .replaceAll('&frac14;', '¼')
        .replaceAll('&frac34;', '¾')
        .replaceAll('&deg;', '°')
        .replaceAll('&micro;', 'µ')
        .replaceAll('&para;', '¶')
        .replaceAll('&middot;', '·');
  }

  // ========== QUESTION ACTIONS ==========

  void _toggleBookmark(int index) {
    setState(() {
      _isBookmarked[index] = !_isBookmarked[index];
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _isBookmarked[index] ? 'Question bookmarked!' : 'Bookmark removed',
        ),
        backgroundColor: const Color(0xFFF59E0B),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showAnswer(int questionIndex) {
    final correctAnswer = _questions[questionIndex].correctAnswer;
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_rounded,
                  color: Color(0xFF10B981),
                  size: 32,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Correct Answer',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1A2E),
                ),
              ),
              const SizedBox(height: 8),
              _buildFormattedContent(correctAnswer, isAnswer: true),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Continue'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _toggleSolution(int index) {
    setState(() {
      _showSolution[index] = !_showSolution[index];
    });
  }

  void _askAI(int questionIndex) {
    final question = _questions[questionIndex];

    Navigator.pushNamed(
      context,
      '/question-gpt',
      arguments: {
        'question': question,
        'courseName': widget.courseName,
        'topicName': widget.topicTitle,
        'showAnswer': false,
      },
    );
  }

  // ========== UI STATES ==========

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          const Text(
            'Loading related questions...',
            style: TextStyle(color: Color(0xFF6B7280), fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _isOffline ? Icons.wifi_off_rounded : Icons.error_outline_rounded,
              size: 64,
              color: const Color(0xFF6B7280),
            ),
            const SizedBox(height: 16),
            Text(
              _isOffline ? 'You are offline' : 'Error loading questions',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A1A2E),
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                _errorMessage,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFF6B7280), fontSize: 14),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _loadQuestions,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6366F1),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _isEmptyTopic
                  ? Icons.folder_off_rounded
                  : _isOffline
                  ? Icons.wifi_off_rounded
                  : Icons.quiz_outlined,
              size: 64,
              color: const Color(0xFF6B7280).withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              _isOffline
                  ? 'No Offline Questions'
                  : _isEmptyTopic
                  ? 'No Related Questions'
                  : 'No Questions Found',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A1A2E),
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                _isOffline
                    ? 'You are offline and no downloaded questions found. Please download questions when online.'
                    : _isEmptyTopic
                    ? 'No related past questions found for "${widget.topicTitle}".\n\nTry viewing questions from other topics.'
                    : 'No related questions found for the selected topic.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF6B7280),
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
            ),

            if (!_isUserActivated && _questions.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(top: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.lock_outline_rounded,
                      size: 16,
                      color: Colors.orange.shade700,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Only $_maxQuestionsForNonActivated questions shown. Activate account to see all questions.',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.orange.shade800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text('Go Back'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Related Past Questions',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            Text(
              '${widget.courseName} • ${widget.topicTitle}',
              style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        backgroundColor: Colors.white,
        elevation: 1,
        foregroundColor: const Color(0xFF1A1A2E),
        actions: [
          if (_checkingActivation)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: _isUserActivated ? Colors.green : Colors.orange,
                ),
              ),
            ),
          if (!_checkingActivation && !_isUserActivated)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
            ),
          if (_isOffline)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              margin: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                children: [
                  Icon(Icons.wifi_off_rounded, size: 14, color: Colors.orange),
                  SizedBox(width: 4),
                  Text(
                    'Offline',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.orange,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          IconButton(
            onPressed: _isLoading ? null : _loadQuestions,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: _isLoading
          ? _buildLoadingState()
          : _questions.isEmpty
          ? _buildEmptyState()
          : Column(
              children: [
                if (!_isUserActivated && !_checkingActivation)
                  _buildActivationBanner(),

                if (!_isUserActivated &&
                    _questions.length <= _maxQuestionsForNonActivated)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    color: Colors.orange.shade50,
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline_rounded,
                          size: 16,
                          color: Colors.orange.shade700,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Showing $_maxQuestionsForNonActivated of ${_questions.length} questions. Activate account to see more.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.orange.shade800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _questions.length,
                    itemBuilder: (context, index) => _buildQuestionCard(index),
                  ),
                ),
              ],
            ),
    );
  }
}
