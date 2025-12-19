
// // lib/features/cgpa/screens/cgpa_calculator_screen.dart
// import 'package:flutter/material.dart';
// import 'package:hive_flutter/hive_flutter.dart';
// import '../models/cgpa_models.dart';
// import '../services/cgpa_service.dart';

// class CGPACalculatorScreen extends StatefulWidget {
//   const CGPACalculatorScreen({super.key});

//   @override
//   State<CGPACalculatorScreen> createState() => _CGPACalculatorScreenState();
// }

// class _CGPACalculatorScreenState extends State<CGPACalculatorScreen> {
//   List<CGPALevel> _levels = [];
//   bool _showLevelForm = false;
//   String? _currentUserId;
//   bool _isLoading = true;

//   @override
//   void initState() {
//     super.initState();
//     _loadUserData();
//   }

//   Future<void> _loadUserData() async {
//     try {
//       final userBox = await Hive.openBox('user_box');
//       final userData = userBox.get('current_user');
      
//       if (userData != null && userData['id'] != null) {
//         setState(() {
//           _currentUserId = userData['id'].toString();
//         });
//         await _loadCGPAData();
//       } else {
//         // No user logged in
//         WidgetsBinding.instance.addPostFrameCallback((_) {
//           Navigator.pushReplacementNamed(context, '/signin');
//         });
//       }
//     } catch (e) {
//       print('Error loading user data: $e');
//     } finally {
//       if (mounted) {
//         setState(() {
//           _isLoading = false;
//         });
//       }
//     }
//   }

//   Future<void> _loadCGPAData() async {
//     if (_currentUserId == null) return;

//     try {
//       final loadedLevels = await CGPAService.getCGPAData(_currentUserId!);
//       if (mounted) {
//         setState(() {
//           _levels = loadedLevels;
//         });
//       }
//     } catch (e) {
//       print('Error loading CGPA data: $e');
//       if (mounted) {
//         setState(() {
//           _levels = [];
//         });
//       }
//     }
//   }

//   Future<void> _saveCGPAData() async {
//     if (_currentUserId == null) return;

//     try {
//       await CGPAService.saveCGPAData(_currentUserId!, _levels);
//     } catch (e) {
//       print('Error saving CGPA data: $e');
//       if (mounted) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//             content: Text('Failed to save CGPA: ${e.toString()}'),
//             backgroundColor: Colors.red,
//           ),
//         );
//       }
//     }
//   }

//   void _openLevelForm() {
//     setState(() {
//       _showLevelForm = true;
//     });
//   }

//   void _saveLevel(String level) {
//     if (level.isNotEmpty) {
//       Navigator.push(
//         context,
//         MaterialPageRoute(
//           builder: (context) => SemesterScreen(
//             level: level,
//             existingLevel: _levels.firstWhere(
//               (l) => l.level == level,
//               orElse: () => CGPALevel(
//                 level: '',
//                 firstSemester: [],
//                 secondSemester: [],
//               ),
//             ),
//             onSave: (data) async {
//               final newLevel = CGPALevel(
//                 level: level,
//                 firstSemester: data['firstSemester'] ?? [],
//                 secondSemester: data['secondSemester'] ?? [],
//               );

//               setState(() {
//                 _levels.removeWhere((l) => l.level == level);
//                 _levels.add(newLevel);
//               });

//               // Save to Hive after update
//               await _saveCGPAData();
//             },
//           ),
//         ),
//       ).then((_) {
//         if (mounted) {
//           setState(() {
//             _showLevelForm = false;
//           });
//         }
//       });
//     }
//   }

//   void _editLevel(int index) {
//     final level = _levels[index];
//     Navigator.push(
//       context,
//       MaterialPageRoute(
//         builder: (context) => SemesterScreen(
//           level: level.level,
//           existingLevel: level,
//           onSave: (data) async {
//             final updatedLevel = CGPALevel(
//               level: level.level,
//               firstSemester: data['firstSemester'] ?? [],
//               secondSemester: data['secondSemester'] ?? [],
//             );

//             setState(() {
//               _levels[index] = updatedLevel;
//             });

//             // Save to Hive after update
//             await _saveCGPAData();
//           },
//         ),
//       ),
//     );
//   }

//   void _deleteLevel(int index) async {
//     showDialog(
//       context: context,
//       builder: (context) => AlertDialog(
//         title: const Text('Delete Level'),
//         content: const Text('Are you sure you want to delete this level record?'),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.pop(context),
//             child: const Text('Cancel'),
//           ),
//           TextButton(
//             onPressed: () async {
//               setState(() {
//                 _levels.removeAt(index);
//               });
              
//               // Save to Hive after deletion
//               await _saveCGPAData();
              
//               Navigator.pop(context);
//               if (mounted) {
//                 ScaffoldMessenger.of(context).showSnackBar(
//                   const SnackBar(content: Text('Level deleted successfully')),
//                 );
//               }
//             },
//             child: const Text('Delete', style: TextStyle(color: Colors.red)),
//           ),
//         ],
//       ),
//     );
//   }

//   double _calculateSemesterGPA(List<CGPACourse> courses) {
//     if (courses.isEmpty) return 0.0;
    
//     double totalPoints = 0;
//     int totalUnits = 0;

//     for (var course in courses) {
//       final gradePoint = _getGradePoint(course.grade);
//       totalPoints += gradePoint * course.unit;
//       totalUnits += course.unit;
//     }

//     return totalUnits > 0 ? totalPoints / totalUnits : 0.0;
//   }

//   double _calculateLevelGPA(CGPALevel level) {
//     final firstSemesterGPA = _calculateSemesterGPA(level.firstSemester);
//     final secondSemesterGPA = _calculateSemesterGPA(level.secondSemester);
    
//     if (level.firstSemester.isEmpty && level.secondSemester.isEmpty) return 0.0;
//     if (level.firstSemester.isEmpty) return secondSemesterGPA;
//     if (level.secondSemester.isEmpty) return firstSemesterGPA;
    
//     return (firstSemesterGPA + secondSemesterGPA) / 2;
//   }

//   double get _overallCGPA {
//     if (_levels.isEmpty) return 0.0;
    
//     double totalGPA = 0;
//     for (var level in _levels) {
//       totalGPA += _calculateLevelGPA(level);
//     }
    
//     return totalGPA / _levels.length;
//   }

//   double _getGradePoint(String grade) {
//     switch (grade.toUpperCase()) {
//       case 'A': return 5.0;
//       case 'B': return 4.0;
//       case 'C': return 3.0;
//       case 'D': return 2.0;
//       case 'E': return 1.0;
//       case 'F': return 0.0;
//       default: return 0.0;
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     if (_isLoading) {
//       return const Scaffold(
//         backgroundColor: Colors.white,
//         body: Center(
//           child: CircularProgressIndicator(),
//         ),
//       );
//     }

//     if (_currentUserId == null) {
//       return Scaffold(
//         backgroundColor: Colors.white,
//         body: Center(
//           child: Column(
//             mainAxisAlignment: MainAxisAlignment.center,
//             children: [
//               const Icon(Icons.error_outline, size: 60, color: Colors.grey),
//               const SizedBox(height: 20),
//               const Text(
//                 'Please sign in to use CGPA Calculator',
//                 style: TextStyle(fontSize: 16, color: Colors.black54),
//               ),
//               const SizedBox(height: 20),
//               ElevatedButton(
//                 onPressed: () => Navigator.pushReplacementNamed(context, '/signin'),
//                 child: const Text('Sign In'),
//               ),
//             ],
//           ),
//         ),
//       );
//     }

//     return Scaffold(
//       backgroundColor: Colors.white,
//       appBar: AppBar(
//         backgroundColor: Colors.white,
//         elevation: 0,
//         title: const Text(
//           'CGPA Calculator',
//           style: TextStyle(
//             color: Colors.black,
//             fontWeight: FontWeight.w700,
//             fontSize: 20,
//           ),
//         ),
//         centerTitle: true,
//         actions: [
//           if (_levels.isNotEmpty)
//             IconButton(
//               icon: const Icon(Icons.add, color: Colors.blue, size: 24),
//               onPressed: _openLevelForm,
//             ),
//         ],
//       ),
//       body: Stack(
//         children: [
//           // Main Content
//           SingleChildScrollView(
//             child: Column(
//               children: [
//                 // CGPA Display
//                 Container(
//                   margin: const EdgeInsets.only(top: 20, bottom: 10),
//                   child: Column(
//                     children: [
//                       const Text(
//                         'Your CGPA',
//                         style: TextStyle(
//                           fontSize: 16,
//                           color: Colors.black54,
//                           fontWeight: FontWeight.w500,
//                         ),
//                       ),
//                       const SizedBox(height: 8),
//                       Text(
//                         _overallCGPA.toStringAsFixed(2),
//                         style: const TextStyle(
//                           fontSize: 48,
//                           fontWeight: FontWeight.w800,
//                           color: Colors.black87,
//                         ),
//                       ),
//                       const SizedBox(height: 4),
//                       const Text(
//                         '/ 5.00',
//                         style: TextStyle(
//                           color: Colors.black45,
//                           fontSize: 14,
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),

//                 // Brief Info
//                 Container(
//                   padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
//                   child: const Text(
//                     'Add your courses and grades to calculate your CGPA automatically.',
//                     textAlign: TextAlign.center,
//                     style: TextStyle(
//                       color: Colors.black54,
//                       fontSize: 14,
//                       height: 1.5,
//                     ),
//                   ),
//                 ),

//                 const SizedBox(height: 10),

//                 // Levels List or Empty State
//                 _levels.isEmpty
//                     ? _buildEmptyState()
//                     : _buildLevelsList(),

//                 // Add New Level Button
//                 if (_levels.isNotEmpty && !_showLevelForm)
//                   Container(
//                     margin: const EdgeInsets.all(20),
//                     child: ElevatedButton.icon(
//                       onPressed: _openLevelForm,
//                       style: ElevatedButton.styleFrom(
//                         backgroundColor: Colors.blue,
//                         foregroundColor: Colors.white,
//                         padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
//                         shape: RoundedRectangleBorder(
//                           borderRadius: BorderRadius.circular(12),
//                         ),
//                       ),
//                       icon: const Icon(Icons.add, size: 20),
//                       label: const Text('Add New Level'),
//                     ),
//                   ),
//               ],
//             ),
//           ),

//           // Level Input Overlay
//           if (_showLevelForm) _buildLevelFormOverlay(),
//         ],
//       ),
//     );
//   }

//   Widget _buildEmptyState() {
//     return Container(
//       height: MediaQuery.of(context).size.height * 0.6,
//       child: Column(
//         mainAxisAlignment: MainAxisAlignment.center,
//         children: [
//           Icon(
//             Icons.school_outlined,
//             size: 70,
//             color: Colors.grey.shade400,
//           ),
//           const SizedBox(height: 20),
//           const Text(
//             'No CGPA Records Yet',
//             style: TextStyle(
//               fontSize: 18,
//               fontWeight: FontWeight.w600,
//               color: Colors.black54,
//             ),
//           ),
//           const SizedBox(height: 8),
//           const Padding(
//             padding: EdgeInsets.symmetric(horizontal: 40),
//             child: Text(
//               'Add your first level to start calculating your CGPA',
//               textAlign: TextAlign.center,
//               style: TextStyle(
//                 color: Colors.black45,
//                 fontSize: 14,
//               ),
//             ),
//           ),
//           const SizedBox(height: 30),
//           ElevatedButton.icon(
//             onPressed: _openLevelForm,
//             style: ElevatedButton.styleFrom(
//               backgroundColor: Colors.blue,
//               foregroundColor: Colors.white,
//               padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
//             ),
//             icon: const Icon(Icons.add, size: 20),
//             label: const Text('Add First Level'),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildLevelsList() {
//     return ListView.builder(
//       shrinkWrap: true,
//       physics: const NeverScrollableScrollPhysics(),
//       padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
//       itemCount: _levels.length,
//       itemBuilder: (context, index) {
//         final level = _levels[index];
//         final levelGPA = _calculateLevelGPA(level);
//         final firstSemesterGPA = _calculateSemesterGPA(level.firstSemester);
//         final secondSemesterGPA = _calculateSemesterGPA(level.secondSemester);

//         return Container(
//           margin: const EdgeInsets.only(bottom: 12),
//           decoration: BoxDecoration(
//             color: Colors.white,
//             borderRadius: BorderRadius.circular(12),
//             border: Border.all(color: Colors.grey.shade200),
//           ),
//           child: Padding(
//             padding: const EdgeInsets.all(16),
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Row(
//                   mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                   children: [
//                     Text(
//                       'Level ${level.level}',
//                       style: const TextStyle(
//                         fontSize: 18,
//                         fontWeight: FontWeight.w700,
//                         color: Colors.black87,
//                       ),
//                     ),
//                     Row(
//                       children: [
//                         Container(
//                           padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
//                           decoration: BoxDecoration(
//                             color: Colors.blue.shade50,
//                             borderRadius: BorderRadius.circular(20),
//                           ),
//                           child: Text(
//                             'GPA: ${levelGPA.toStringAsFixed(2)}',
//                             style: TextStyle(
//                               fontWeight: FontWeight.w600,
//                               color: Colors.blue.shade700,
//                               fontSize: 14,
//                             ),
//                           ),
//                         ),
//                         const SizedBox(width: 8),
//                         PopupMenuButton(
//                           icon: const Icon(Icons.more_vert, color: Colors.grey, size: 20),
//                           itemBuilder: (context) => [
//                             const PopupMenuItem(
//                               value: 'edit',
//                               child: Row(
//                                 children: [
//                                   Icon(Icons.edit, size: 18),
//                                   SizedBox(width: 8),
//                                   Text('Edit'),
//                                 ],
//                               ),
//                             ),
//                             const PopupMenuItem(
//                               value: 'delete',
//                               child: Row(
//                                 children: [
//                                   Icon(Icons.delete, size: 18, color: Colors.red),
//                                   SizedBox(width: 8),
//                                   Text('Delete', style: TextStyle(color: Colors.red)),
//                                 ],
//                               ),
//                             ),
//                           ],
//                           onSelected: (value) {
//                             if (value == 'edit') {
//                               _editLevel(index);
//                             } else if (value == 'delete') {
//                               _deleteLevel(index);
//                             }
//                           },
//                         ),
//                       ],
//                     ),
//                   ],
//                 ),
//                 const SizedBox(height: 12),
//                 Row(
//                   mainAxisAlignment: MainAxisAlignment.spaceAround,
//                   children: [
//                     _buildSemesterInfo('1st Sem', firstSemesterGPA),
//                     _buildSemesterInfo('2nd Sem', secondSemesterGPA),
//                   ],
//                 ),
//               ],
//             ),
//           ),
//         );
//       },
//     );
//   }

//   Widget _buildSemesterInfo(String title, double gpa) {
//     return Column(
//       children: [
//         Text(
//           title,
//           style: const TextStyle(
//             fontSize: 14,
//             color: Colors.black54,
//           ),
//         ),
//         const SizedBox(height: 4),
//         Text(
//           gpa.toStringAsFixed(2),
//           style: TextStyle(
//             fontSize: 16,
//             fontWeight: FontWeight.w600,
//             color: gpa > 0 ? Colors.green : Colors.grey,
//           ),
//         ),
//       ],
//     );
//   }

//   Widget _buildLevelFormOverlay() {
//     final TextEditingController levelController = TextEditingController();

//     return GestureDetector(
//       onTap: () {
//         FocusScope.of(context).unfocus();
//         setState(() {
//           _showLevelForm = false;
//         });
//       },
//       child: Container(
//         color: Colors.black54,
//         child: Center(
//           child: SingleChildScrollView(
//             child: GestureDetector(
//               onTap: () {},
//               child: Container(
//                 width: MediaQuery.of(context).size.width * 0.85,
//                 padding: const EdgeInsets.all(24),
//                 margin: EdgeInsets.only(
//                   bottom: MediaQuery.of(context).viewInsets.bottom + 20,
//                 ),
//                 decoration: BoxDecoration(
//                   color: Colors.white,
//                   borderRadius: BorderRadius.circular(16),
//                 ),
//                 child: Column(
//                   mainAxisSize: MainAxisSize.min,
//                   children: [
//                     const Text(
//                       'Add Academic Level',
//                       style: TextStyle(
//                         fontSize: 20,
//                         fontWeight: FontWeight.w700,
//                       ),
//                     ),
//                     const SizedBox(height: 16),
//                     TextFormField(
//                       controller: levelController,
//                       decoration: const InputDecoration(
//                         labelText: 'Level (e.g., 100, 200)',
//                         border: OutlineInputBorder(),
//                       ),
//                       style: const TextStyle(fontSize: 16),
//                     ),
//                     const SizedBox(height: 24),
//                     Row(
//                       children: [
//                         Expanded(
//                           child: OutlinedButton(
//                             onPressed: () {
//                               FocusScope.of(context).unfocus();
//                               setState(() {
//                                 _showLevelForm = false;
//                               });
//                             },
//                             child: const Text('Cancel'),
//                           ),
//                         ),
//                         const SizedBox(width: 12),
//                         Expanded(
//                           child: ElevatedButton(
//                             onPressed: () {
//                               if (levelController.text.isNotEmpty) {
//                                 FocusScope.of(context).unfocus();
//                                 _saveLevel(levelController.text);
//                               }
//                             },
//                             style: ElevatedButton.styleFrom(
//                               backgroundColor: Colors.blue,
//                               foregroundColor: Colors.white,
//                             ),
//                             child: const Text('Continue'),
//                           ),
//                         ),
//                       ],
//                     ),
//                   ],
//                 ),
//               ),
//             ),
//           ),
//         ),
//       ),
//     );
//   }
// }

// // Separate Semester Screen
// class SemesterScreen extends StatefulWidget {
//   final String level;
//   final CGPALevel existingLevel;
//   final Function(Map<String, dynamic>) onSave;

//   const SemesterScreen({
//     super.key,
//     required this.level,
//     required this.existingLevel,
//     required this.onSave,
//   });

//   @override
//   State<SemesterScreen> createState() => _SemesterScreenState();
// }

// class _SemesterScreenState extends State<SemesterScreen> {
//   bool _isFirstSemester = true;
//   List<CGPACourse> _firstSemesterCourses = [];
//   List<CGPACourse> _secondSemesterCourses = [];

//   final List<String> _grades = ['A', 'B', 'C', 'D', 'E', 'F'];

//   @override
//   void initState() {
//     super.initState();
//     _firstSemesterCourses = List.from(widget.existingLevel.firstSemester);
//     _secondSemesterCourses = List.from(widget.existingLevel.secondSemester);
//   }

//   double _calculateSemesterGPA(List<CGPACourse> courses) {
//     if (courses.isEmpty) return 0.0;
    
//     double totalPoints = 0;
//     int totalUnits = 0;

//     for (var course in courses) {
//       final gradePoint = _getGradePoint(course.grade);
//       totalPoints += gradePoint * course.unit;
//       totalUnits += course.unit;
//     }

//     return totalUnits > 0 ? totalPoints / totalUnits : 0.0;
//   }

//   double _getGradePoint(String grade) {
//     switch (grade.toUpperCase()) {
//       case 'A': return 5.0;
//       case 'B': return 4.0;
//       case 'C': return 3.0;
//       case 'D': return 2.0;
//       case 'E': return 1.0;
//       case 'F': return 0.0;
//       default: return 0.0;
//     }
//   }

//   void _addCourse() {
//     setState(() {
//       if (_isFirstSemester) {
//         _firstSemesterCourses.add(CGPACourse(code: '', unit: 0, grade: 'A'));
//       } else {
//         _secondSemesterCourses.add(CGPACourse(code: '', unit: 0, grade: 'A'));
//       }
//     });
//   }

//   void _updateCourse(int index, CGPACourse course) {
//     setState(() {
//       if (_isFirstSemester) {
//         _firstSemesterCourses[index] = course;
//       } else {
//         _secondSemesterCourses[index] = course;
//       }
//     });
//   }

//   void _removeCourse(int index) {
//     setState(() {
//       if (_isFirstSemester) {
//         _firstSemesterCourses.removeAt(index);
//       } else {
//         _secondSemesterCourses.removeAt(index);
//       }
//     });
//   }

//   void _saveData() {
//     // Filter out empty courses
//     final validFirstSemester = _firstSemesterCourses.where((course) => course.code.isNotEmpty && course.unit > 0).toList();
//     final validSecondSemester = _secondSemesterCourses.where((course) => course.code.isNotEmpty && course.unit > 0).toList();
    
//     widget.onSave({
//       'firstSemester': validFirstSemester,
//       'secondSemester': validSecondSemester,
//     });
//     Navigator.pop(context);
//   }

//   bool _canAddMoreCourses() {
//     final currentCourses = _isFirstSemester ? _firstSemesterCourses : _secondSemesterCourses;
    
//     // Check if all existing courses are properly filled
//     for (var course in currentCourses) {
//       if (course.code.isEmpty || course.unit <= 0) {
//         return false;
//       }
//     }
//     return true;
//   }

//   @override
//   Widget build(BuildContext context) {
//     final currentCourses = _isFirstSemester ? _firstSemesterCourses : _secondSemesterCourses;
//     final validCourses = currentCourses.where((course) => course.code.isNotEmpty && course.unit > 0).toList();
//     final currentGPA = _calculateSemesterGPA(validCourses);

//     return Scaffold(
//       backgroundColor: Colors.white,
//       appBar: AppBar(
//         backgroundColor: Colors.white,
//         elevation: 0,
//         leading: IconButton(
//           icon: const Icon(Icons.arrow_back, color: Colors.black),
//           onPressed: () => Navigator.pop(context),
//         ),
//         title: Text(
//           'Level ${widget.level}',
//           style: const TextStyle(
//             color: Colors.black,
//             fontWeight: FontWeight.w700,
//           ),
//         ),
//         actions: [
//           IconButton(
//             icon: const Icon(Icons.save, color: Colors.blue),
//             onPressed: _saveData,
//           ),
//         ],
//       ),
//       body: GestureDetector(
//         onTap: () {
//           // Unfocus when tapping anywhere on the screen
//           FocusScope.of(context).unfocus();
//         },
//         child: SingleChildScrollView(
//           padding: const EdgeInsets.all(16),
//           child: Column(
//             children: [
//               // GPA Display
//               Container(
//                 padding: const EdgeInsets.all(20),
//                 decoration: BoxDecoration(
//                   color: Colors.grey.shade50,
//                   borderRadius: BorderRadius.circular(12),
//                 ),
//                 child: Column(
//                   children: [
//                     Text(
//                       '${_isFirstSemester ? 'First' : 'Second'} Semester GPA',
//                       style: const TextStyle(
//                         fontSize: 16,
//                         color: Colors.black54,
//                       ),
//                     ),
//                     const SizedBox(height: 8),
//                     Text(
//                       currentGPA.toStringAsFixed(2),
//                       style: const TextStyle(
//                         fontSize: 36,
//                         fontWeight: FontWeight.w800,
//                         color: Colors.black87,
//                       ),
//                     ),
//                     const SizedBox(height: 4),
//                     Text(
//                       '${validCourses.length} ${validCourses.length == 1 ? 'course' : 'courses'}',
//                       style: const TextStyle(
//                         color: Colors.black45,
//                         fontSize: 14,
//                       ),
//                     ),
//                   ],
//                 ),
//               ),

//               const SizedBox(height: 20),

//               // Semester Toggle
//               Container(
//                 decoration: BoxDecoration(
//                   color: Colors.grey.shade100,
//                   borderRadius: BorderRadius.circular(12),
//                 ),
//                 child: Row(
//                   children: [
//                     Expanded(
//                       child: GestureDetector(
//                         onTap: () {
//                           FocusScope.of(context).unfocus();
//                           setState(() => _isFirstSemester = true);
//                         },
//                         child: Container(
//                           padding: const EdgeInsets.symmetric(vertical: 14),
//                           decoration: BoxDecoration(
//                             color: _isFirstSemester ? Colors.blue : Colors.transparent,
//                             borderRadius: BorderRadius.circular(12),
//                           ),
//                           child: Center(
//                             child: Text(
//                               '1st Semester',
//                               style: TextStyle(
//                                 color: _isFirstSemester ? Colors.white : Colors.black54,
//                                 fontWeight: FontWeight.w600,
//                               ),
//                             ),
//                           ),
//                         ),
//                       ),
//                     ),
//                     Expanded(
//                       child: GestureDetector(
//                         onTap: () {
//                           FocusScope.of(context).unfocus();
//                           setState(() => _isFirstSemester = false);
//                         },
//                         child: Container(
//                           padding: const EdgeInsets.symmetric(vertical: 14),
//                           decoration: BoxDecoration(
//                             color: !_isFirstSemester ? Colors.blue : Colors.transparent,
//                             borderRadius: BorderRadius.circular(12),
//                           ),
//                           child: Center(
//                             child: Text(
//                               '2nd Semester',
//                               style: TextStyle(
//                                 color: !_isFirstSemester ? Colors.white : Colors.black54,
//                                 fontWeight: FontWeight.w600,
//                               ),
//                             ),
//                           ),
//                         ),
//                       ),
//                     ),
//                   ],
//                 ),
//               ),

//               const SizedBox(height: 20),

//               // Add Course Button - Moved here to appear at top
//               if (currentCourses.isEmpty)
//                 ElevatedButton.icon(
//                   onPressed: _canAddMoreCourses() ? _addCourse : null,
//                   style: ElevatedButton.styleFrom(
//                     backgroundColor: Colors.green,
//                     foregroundColor: Colors.white,
//                     minimumSize: const Size(double.infinity, 50),
//                   ),
//                   icon: const Icon(Icons.add, size: 20),
//                   label: const Text('Add New Course'),
//                 ),

//               const SizedBox(height: 20),

//               // Courses List
//               if (currentCourses.isEmpty)
//                 Container(
//                   padding: const EdgeInsets.all(40),
//                   child: const Column(
//                     children: [
//                       Icon(Icons.class_outlined, size: 60, color: Colors.grey),
//                       SizedBox(height: 16),
//                       Text(
//                         'No courses added',
//                         style: TextStyle(
//                           color: Colors.black54,
//                           fontSize: 16,
//                         ),
//                       ),
//                       SizedBox(height: 8),
//                       Text(
//                         'Tap "Add New Course" to start',
//                         style: TextStyle(
//                           color: Colors.grey,
//                           fontSize: 14,
//                         ),
//                       ),
//                     ],
//                   ),
//                 )
//               else
//                 ...currentCourses.asMap().entries.map((entry) {
//                   final index = entry.key;
//                   final course = entry.value;
//                   return _buildCourseItem(course, index);
//                 }).toList(),

//               // Add Another Course Button - Added at the bottom after all courses
//               if (currentCourses.isNotEmpty)
//                 Column(
//                   children: [
//                     const SizedBox(height: 16),
//                     ElevatedButton.icon(
//                       onPressed: _canAddMoreCourses() ? _addCourse : null,
//                       style: ElevatedButton.styleFrom(
//                         backgroundColor: Colors.green,
//                         foregroundColor: Colors.white,
//                         minimumSize: const Size(double.infinity, 50),
//                       ),
//                       icon: const Icon(Icons.add, size: 20),
//                       label: const Text('Add Another Course'),
//                     ),
//                   ],
//                 ),

//               const SizedBox(height: 20),
//             ],
//           ),
//         ),
//       ),
//     );
//   }

//   Widget _buildCourseItem(CGPACourse course, int index) {
//     final codeController = TextEditingController(text: course.code);
//     final unitController = TextEditingController(text: course.unit > 0 ? course.unit.toString() : '');
//     String selectedGrade = course.grade;

//     return Container(
//       margin: const EdgeInsets.only(bottom: 16),
//       padding: const EdgeInsets.all(16),
//       decoration: BoxDecoration(
//         color: Colors.white,
//         borderRadius: BorderRadius.circular(12),
//         border: Border.all(color: Colors.grey.shade300),
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           // DELETE BUTTON - MOVED TO TOP
//           SizedBox(
//             width: double.infinity,
//             child: OutlinedButton.icon(
//               onPressed: () => _removeCourse(index),
//               style: OutlinedButton.styleFrom(
//                 foregroundColor: Colors.red,
//                 side: BorderSide(color: Colors.red.shade300),
//                 padding: const EdgeInsets.symmetric(vertical: 12),
//               ),
//               icon: const Icon(Icons.delete, size: 18),
//               label: const Text(
//                 'Remove Course',
//                 style: TextStyle(fontSize: 14),
//               ),
//             ),
//           ),
//           const SizedBox(height: 12),
          
//           // Course Code
//           TextFormField(
//             controller: codeController,
//             decoration: const InputDecoration(
//               labelText: 'Course Code',
//               border: OutlineInputBorder(),
//               contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
//             ),
//             style: const TextStyle(fontSize: 16),
//             onChanged: (value) {
//               _updateCourse(
//                 index,
//                 CGPACourse(code: value, unit: course.unit, grade: course.grade),
//               );
//             },
//           ),
//           const SizedBox(height: 12),
          
//           Row(
//             children: [
//               // Course Units
//               Expanded(
//                 child: TextFormField(
//                   controller: unitController,
//                   decoration: const InputDecoration(
//                     labelText: 'Course Units',
//                     border: OutlineInputBorder(),
//                     contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
//                   ),
//                   style: const TextStyle(fontSize: 16),
//                   keyboardType: TextInputType.number,
//                   onChanged: (value) {
//                     final unit = int.tryParse(value) ?? 0;
//                     _updateCourse(
//                       index,
//                       CGPACourse(code: course.code, unit: unit, grade: course.grade),
//                     );
//                   },
//                 ),
//               ),
//               const SizedBox(width: 12),
              
//               // Grade Dropdown
//               Expanded(
//                 child: DropdownButtonFormField<String>(
//                   value: selectedGrade,
//                   items: _grades.map((grade) {
//                     return DropdownMenuItem(
//                       value: grade,
//                       child: Text(
//                         grade,
//                         style: const TextStyle(fontSize: 16),
//                       ),
//                     );
//                   }).toList(),
//                   onChanged: (value) {
//                     if (value != null) {
//                       setState(() {
//                         selectedGrade = value;
//                       });
//                       _updateCourse(
//                         index,
//                         CGPACourse(code: course.code, unit: course.unit, grade: value),
//                       );
//                     }
//                   },
//                   decoration: const InputDecoration(
//                     labelText: 'Grade',
//                     border: OutlineInputBorder(),
//                     contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
//                   ),
//                 ),
//               ),
//             ],
//           ),
//         ],
//       ),
//     );
//   }
// }


// lib/features/cgpa/screens/cgpa_calculator_screen.dart
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import '../models/cgpa_models.dart';
import '../services/cgpa_service.dart';

class CGPACalculatorScreen extends StatefulWidget {
  const CGPACalculatorScreen({super.key});

  @override
  State<CGPACalculatorScreen> createState() => _CGPACalculatorScreenState();
}

class _CGPACalculatorScreenState extends State<CGPACalculatorScreen> {
  List<CGPALevel> _levels = [];
  bool _showLevelForm = false;
  String? _currentUserId;
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';

  late Box userBox;

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Check if we need to reload data after hot restart
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_levels.isEmpty && _currentUserId != null && !_isLoading) {
        _loadCGPAData();
      }
    });
  }

  Future<void> _initializeData() async {
    try {
      print('🔄 Initializing CGPA data...');
      userBox = Hive.box('user_box');
      final userData = userBox.get('current_user');

      if (userData != null && userData['id'] != null) {
        setState(() {
          _currentUserId = userData['id'].toString();
        });
        
        // Debug current state
        // await CGPAService.debugPrintAll();
        
        await _loadCGPAData();
      } else {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          Navigator.pushReplacementNamed(context, '/signin');
        });
      }
    } catch (e) {
      print('❌ Error loading user data: $e');
      setState(() {
        _hasError = true;
        _errorMessage = 'Failed to load user data: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadCGPAData() async {
    if (_currentUserId == null) return;

    try {
      print('📥 Loading CGPA data for user: $_currentUserId');
      final loadedLevels = await CGPAService.getCGPAData(_currentUserId!);
      
      if (mounted) {
        setState(() {
          _levels = loadedLevels;
          _hasError = false;
        });
      }
      print('✅ Loaded ${loadedLevels.length} level(s)');
    } catch (e) {
      print('❌ Error loading CGPA data: $e');
      if (mounted) {
        setState(() {
          _levels = [];
          _hasError = true;
          _errorMessage = 'Failed to load CGPA data: $e';
        });
      }
    }
  }

  Future<void> _saveCGPAData() async {
    if (_currentUserId == null) return;

    try {
      print('💾 Saving CGPA data for user: $_currentUserId');
      await CGPAService.saveCGPAData(_currentUserId!, _levels);
      
      // Verify save worked
      final verifyLevels = await CGPAService.getCGPAData(_currentUserId!);
      print('✅ Save verified: ${verifyLevels.length} level(s) retrieved');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('CGPA saved successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('❌ Error saving CGPA data: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save CGPA: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _openLevelForm() {
    setState(() {
      _showLevelForm = true;
    });
  }

  Future<void> _saveLevel(String levelName) async {
    if (levelName.isEmpty) return;

    final emptyLevel = CGPALevel(
      level: levelName,
      firstSemester: [],
      secondSemester: [],
    );

    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => SemesterScreen(
          level: levelName,
          existingLevel: emptyLevel,
          onSave: (data) async {
            final newLevel = CGPALevel(
              level: levelName,
              firstSemester: data['firstSemester'] as List<CGPACourse>,
              secondSemester: data['secondSemester'] as List<CGPACourse>,
            );

            setState(() {
              // Remove if exists, then add new
              _levels.removeWhere((l) => l.level == levelName);
              _levels.add(newLevel);
            });

            await _saveCGPAData();
          },
        ),
      ),
    );

    if (mounted) {
      setState(() {
        _showLevelForm = false;
      });
    }

    // Refresh if user saved
    if (saved == true) {
      await _loadCGPAData();
    }
  }

  Future<void> _editLevel(int index) async {
    final level = _levels[index];

    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => SemesterScreen(
          level: level.level,
          existingLevel: level,
          onSave: (data) async {
            final updatedLevel = CGPALevel(
              level: level.level,
              firstSemester: data['firstSemester'] as List<CGPACourse>,
              secondSemester: data['secondSemester'] as List<CGPACourse>,
            );

            setState(() {
              _levels[index] = updatedLevel;
            });

            await _saveCGPAData();
          },
        ),
      ),
    );

    if (saved == true) {
      await _loadCGPAData();
    }
  }

  Future<void> _deleteLevel(int index) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Level'),
        content: const Text('Are you sure you want to delete this level record? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false), 
            child: const Text('Cancel')
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() {
        _levels.removeAt(index);
      });
      await _saveCGPAData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Level deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  double _calculateSemesterGPA(List<CGPACourse> courses) {
    if (courses.isEmpty) return 0.0;

    double totalPoints = 0;
    int totalUnits = 0;

    for (var course in courses) {
      final gradePoint = _getGradePoint(course.grade);
      totalPoints += gradePoint * course.unit;
      totalUnits += course.unit;
    }

    return totalUnits > 0 ? totalPoints / totalUnits : 0.0;
  }

  double _calculateLevelGPA(CGPALevel level) {
    final firstGPA = _calculateSemesterGPA(level.firstSemester);
    final secondGPA = _calculateSemesterGPA(level.secondSemester);

    final firstUnits = level.firstSemester.fold(0, (sum, course) => sum + course.unit);
    final secondUnits = level.secondSemester.fold(0, (sum, course) => sum + course.unit);
    final totalUnits = firstUnits + secondUnits;

    if (totalUnits == 0) return 0.0;
    
    final totalPoints = (firstGPA * firstUnits) + (secondGPA * secondUnits);
    return totalPoints / totalUnits;
  }

  double get _overallCGPA {
    if (_levels.isEmpty) return 0.0;
    
    double totalWeightedGPA = 0;
    int totalAllUnits = 0;
    
    for (var level in _levels) {
      final firstUnits = level.firstSemester.fold(0, (sum, course) => sum + course.unit);
      final secondUnits = level.secondSemester.fold(0, (sum, course) => sum + course.unit);
      final levelUnits = firstUnits + secondUnits;
      
      if (levelUnits > 0) {
        final levelGPA = _calculateLevelGPA(level);
        totalWeightedGPA += levelGPA * levelUnits;
        totalAllUnits += levelUnits;
      }
    }
    
    return totalAllUnits > 0 ? totalWeightedGPA / totalAllUnits : 0.0;
  }

  double _getGradePoint(String grade) {
    switch (grade.toUpperCase()) {
      case 'A': return 5.0;
      case 'B': return 4.0;
      case 'C': return 3.0;
      case 'D': return 2.0;
      case 'E': return 1.0;
      case 'F': return 0.0;
      default: return 0.0;
    }
  }

  Future<void> _refreshData() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });
    await _loadCGPAData();
    setState(() {
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text(
                'Loading CGPA data...',
                style: TextStyle(color: Colors.black54),
              ),
            ],
          ),
        ),
      );
    }

    if (_currentUserId == null) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 60, color: Colors.grey),
              const SizedBox(height: 20),
              const Text(
                'Please sign in to use CGPA Calculator',
                style: TextStyle(fontSize: 16, color: Colors.black54),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => Navigator.pushReplacementNamed(context, '/signin'),
                child: const Text('Sign In'),
              ),
            ],
          ),
        ),
      );
    }

    if (_hasError) {
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          title: const Text(
            'CGPA Calculator',
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.w700, fontSize: 20),
          ),
          centerTitle: true,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 60, color: Colors.red),
              const SizedBox(height: 20),
              const Text(
                'Failed to load CGPA data',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.black87),
              ),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Text(
                  _errorMessage,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.black54, fontSize: 14),
                ),
              ),
              const SizedBox(height: 30),
              ElevatedButton.icon(
                onPressed: _refreshData,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: () => CGPAService.debugPrintAll(),
                child: const Text('Debug Storage'),
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
        title: const Text(
          'CGPA Calculator',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.w700, fontSize: 20),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.blue, size: 24),
            onPressed: _refreshData,
            tooltip: 'Refresh',
          ),
          if (_levels.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.add, color: Colors.blue, size: 24),
              onPressed: _openLevelForm,
              tooltip: 'Add Level',
            ),
        ],
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            child: Column(
              children: [
                // CGPA Display Card
                Container(
                  margin: const EdgeInsets.only(top: 20, bottom: 10),
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(16),
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
                      Text(
                        'Your CGPA',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.blue.shade800,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _overallCGPA.toStringAsFixed(2),
                        style: const TextStyle(
                          fontSize: 48,
                          fontWeight: FontWeight.w800,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '/ 5.00',
                        style: TextStyle(
                          color: Colors.blue.shade700,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (_levels.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Text(
                            '${_levels.length} level${_levels.length > 1 ? 's' : ''} calculated',
                            style: const TextStyle(
                              color: Colors.black54,
                              fontSize: 12,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: Text(
                    'Add your courses and grades to calculate your CGPA automatically.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.black54, fontSize: 14, height: 1.5),
                  ),
                ),

                const SizedBox(height: 10),

                _levels.isEmpty ? _buildEmptyState() : _buildLevelsList(),

                if (_levels.isNotEmpty && !_showLevelForm)
                  Container(
                    margin: const EdgeInsets.all(20),
                    child: ElevatedButton.icon(
                      onPressed: _openLevelForm,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 2,
                      ),
                      icon: const Icon(Icons.add, size: 20),
                      label: const Text('Add New Level'),
                    ),
                  ),
              ],
            ),
          ),

          if (_showLevelForm) _buildLevelFormOverlay(),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      height: MediaQuery.of(context).size.height * 0.6,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.school_outlined, size: 70, color: Colors.grey.shade400),
          const SizedBox(height: 20),
          const Text(
            'No CGPA Records Yet',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.black54),
          ),
          const SizedBox(height: 8),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'Add your first level to start calculating your CGPA',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.black45, fontSize: 14),
            ),
          ),
          const SizedBox(height: 30),
          ElevatedButton.icon(
            onPressed: _openLevelForm,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            icon: const Icon(Icons.add, size: 20),
            label: const Text('Add First Level'),
          ),
        ],
      ),
    );
  }

  Widget _buildLevelsList() {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: _levels.length,
      itemBuilder: (context, index) {
        final level = _levels[index];
        final levelGPA = _calculateLevelGPA(level);
        final firstSemesterGPA = _calculateSemesterGPA(level.firstSemester);
        final secondSemesterGPA = _calculateSemesterGPA(level.secondSemester);
        final firstSemesterCourses = level.firstSemester.length;
        final secondSemesterCourses = level.secondSemester.length;
        final totalCourses = firstSemesterCourses + secondSemesterCourses;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Level ${level.level}',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.black87),
                    ),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: _getGPAColor(levelGPA),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            'GPA: ${levelGPA.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        PopupMenuButton(
                          icon: const Icon(Icons.more_vert, color: Colors.grey, size: 20),
                          itemBuilder: (context) => [
                            const PopupMenuItem(
                              value: 'edit',
                              child: Row(
                                children: [
                                  Icon(Icons.edit, size: 18),
                                  SizedBox(width: 8),
                                  Text('Edit'),
                                ],
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'delete',
                              child: Row(
                                children: [
                                  Icon(Icons.delete, size: 18, color: Colors.red),
                                  SizedBox(width: 8),
                                  Text('Delete', style: TextStyle(color: Colors.red)),
                                ],
                              ),
                            ),
                          ],
                          onSelected: (value) {
                            if (value == 'edit') _editLevel(index);
                            if (value == 'delete') _deleteLevel(index);
                          },
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  '$totalCourses course${totalCourses != 1 ? 's' : ''} total',
                  style: const TextStyle(color: Colors.black54, fontSize: 14),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildSemesterInfo('1st Sem', firstSemesterGPA, firstSemesterCourses),
                    _buildSemesterInfo('2nd Sem', secondSemesterGPA, secondSemesterCourses),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSemesterInfo(String title, double gpa, int courseCount) {
    return Column(
      children: [
        Text(title, style: const TextStyle(fontSize: 14, color: Colors.black54)),
        const SizedBox(height: 4),
        Text(
          gpa.toStringAsFixed(2),
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: _getGPATextColor(gpa),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          '$courseCount course${courseCount != 1 ? 's' : ''}',
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
      ],
    );
  }

  Color _getGPAColor(double gpa) {
    if (gpa >= 4.5) return Colors.green;
    if (gpa >= 3.5) return Colors.blue;
    if (gpa >= 2.5) return Colors.orange;
    if (gpa >= 1.5) return Colors.amber;
    return Colors.red;
  }

  Color _getGPATextColor(double gpa) {
    if (gpa >= 4.5) return Colors.green.shade700;
    if (gpa >= 3.5) return Colors.blue.shade700;
    if (gpa >= 2.5) return Colors.orange.shade700;
    if (gpa >= 1.5) return Colors.amber.shade700;
    return Colors.red.shade700;
  }

  Widget _buildLevelFormOverlay() {
    final TextEditingController levelController = TextEditingController();

    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
        setState(() => _showLevelForm = false);
      },
      child: Container(
        color: Colors.black54,
        child: Center(
          child: SingleChildScrollView(
            child: GestureDetector(
              onTap: () {}, // Prevent tap from closing
              child: Container(
                width: MediaQuery.of(context).size.width * 0.85,
                padding: const EdgeInsets.all(24),
                margin: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom + 20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Add Academic Level',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: levelController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Level (e.g., 100, 200)',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.school),
                      ),
                      style: const TextStyle(fontSize: 16),
                      autofocus: true,
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              FocusScope.of(context).unfocus();
                              setState(() => _showLevelForm = false);
                            },
                            child: const Text('Cancel'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              final text = levelController.text.trim();
                              if (text.isNotEmpty) {
                                FocusScope.of(context).unfocus();
                                setState(() => _showLevelForm = false);
                                _saveLevel(text);
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                            ),
                            child: const Text('Continue'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// SemesterScreen - Updated with better state management
class SemesterScreen extends StatefulWidget {
  final String level;
  final CGPALevel existingLevel;
  final Function(Map<String, dynamic>) onSave;

  const SemesterScreen({
    super.key,
    required this.level,
    required this.existingLevel,
    required this.onSave,
  });

  @override
  State<SemesterScreen> createState() => _SemesterScreenState();
}

class _SemesterScreenState extends State<SemesterScreen> {
  bool _isFirstSemester = true;
  List<CGPACourse> _firstSemesterCourses = [];
  List<CGPACourse> _secondSemesterCourses = [];
  final List<String> _grades = ['A', 'B', 'C', 'D', 'E', 'F'];

  @override
  void initState() {
    super.initState();
    _firstSemesterCourses = List.from(widget.existingLevel.firstSemester);
    _secondSemesterCourses = List.from(widget.existingLevel.secondSemester);
  }

  double _calculateSemesterGPA(List<CGPACourse> courses) {
    if (courses.isEmpty) return 0.0;
    
    double totalPoints = 0;
    int totalUnits = 0;

    for (var course in courses) {
      final gradePoint = _getGradePoint(course.grade);
      totalPoints += gradePoint * course.unit;
      totalUnits += course.unit;
    }

    return totalUnits > 0 ? totalPoints / totalUnits : 0.0;
  }

  double _getGradePoint(String grade) {
    switch (grade.toUpperCase()) {
      case 'A': return 5.0;
      case 'B': return 4.0;
      case 'C': return 3.0;
      case 'D': return 2.0;
      case 'E': return 1.0;
      case 'F': return 0.0;
      default: return 0.0;
    }
  }

  void _addCourse() {
    setState(() {
      if (_isFirstSemester) {
        _firstSemesterCourses.add(CGPACourse(code: '', unit: 0, grade: 'A'));
      } else {
        _secondSemesterCourses.add(CGPACourse(code: '', unit: 0, grade: 'A'));
      }
    });
  }

  void _updateCourse(int index, CGPACourse course) {
    setState(() {
      if (_isFirstSemester) {
        _firstSemesterCourses[index] = course;
      } else {
        _secondSemesterCourses[index] = course;
      }
    });
  }

  void _removeCourse(int index) {
    setState(() {
      if (_isFirstSemester) {
        _firstSemesterCourses.removeAt(index);
      } else {
        _secondSemesterCourses.removeAt(index);
      }
    });
  }

  void _saveData() {
    final validFirstSemester = _firstSemesterCourses
        .where((course) => course.code.trim().isNotEmpty && course.unit > 0)
        .toList();
    
    final validSecondSemester = _secondSemesterCourses
        .where((course) => course.code.trim().isNotEmpty && course.unit > 0)
        .toList();
    
    widget.onSave({
      'firstSemester': validFirstSemester,
      'secondSemester': validSecondSemester,
    });
    
    // Show success message
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Level saved successfully'),
        backgroundColor: Colors.green,
      ),
    );
    
    Navigator.pop(context, true);
  }

  bool _canAddMoreCourses() {
    final currentCourses = _isFirstSemester ? _firstSemesterCourses : _secondSemesterCourses;
    for (var course in currentCourses) {
      if (course.code.trim().isEmpty || course.unit <= 0) {
        return false;
      }
    }
    return true;
  }

  bool _hasValidCourses() {
    final validFirst = _firstSemesterCourses.any((course) => course.code.trim().isNotEmpty && course.unit > 0);
    final validSecond = _secondSemesterCourses.any((course) => course.code.trim().isNotEmpty && course.unit > 0);
    return validFirst || validSecond;
  }

  @override
  Widget build(BuildContext context) {
    final currentCourses = _isFirstSemester ? _firstSemesterCourses : _secondSemesterCourses;
    final validCourses = currentCourses.where((course) => course.code.trim().isNotEmpty && course.unit > 0).toList();
    final currentGPA = _calculateSemesterGPA(validCourses);
    final totalUnits = validCourses.fold(0, (sum, course) => sum + course.unit);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Level ${widget.level}',
          style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.save, color: _hasValidCourses() ? Colors.blue : Colors.grey),
            onPressed: _hasValidCourses() ? _saveData : null,
            tooltip: 'Save',
          ),
        ],
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // GPA Display Card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  children: [
                    Text(
                      '${_isFirstSemester ? 'First' : 'Second'} Semester',
                      style: const TextStyle(fontSize: 16, color: Colors.black54),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      currentGPA.toStringAsFixed(2),
                      style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w800, color: Colors.black87),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$totalUnits unit${totalUnits != 1 ? 's' : ''} • ${validCourses.length} course${validCourses.length != 1 ? 's' : ''}',
                      style: const TextStyle(color: Colors.black45, fontSize: 14),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Semester Toggle
              Container(
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          FocusScope.of(context).unfocus();
                          setState(() => _isFirstSemester = true);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            color: _isFirstSemester ? Colors.blue : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Center(
                            child: Text(
                              '1st Semester',
                              style: TextStyle(
                                color: _isFirstSemester ? Colors.white : Colors.black54,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          FocusScope.of(context).unfocus();
                          setState(() => _isFirstSemester = false);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            color: !_isFirstSemester ? Colors.blue : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Center(
                            child: Text(
                              '2nd Semester',
                              style: TextStyle(
                                color: !_isFirstSemester ? Colors.white : Colors.black54,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Add Course Button (when no courses)
              if (currentCourses.isEmpty)
                ElevatedButton.icon(
                  onPressed: _canAddMoreCourses() ? _addCourse : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.add, size: 20),
                  label: const Text('Add New Course'),
                ),

              const SizedBox(height: 20),

              // Empty State
              if (currentCourses.isEmpty)
                Container(
                  padding: const EdgeInsets.all(40),
                  child: const Column(
                    children: [
                      Icon(Icons.class_outlined, size: 60, color: Colors.grey),
                      SizedBox(height: 16),
                      Text(
                        'No courses added',
                        style: TextStyle(color: Colors.black54, fontSize: 16),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Tap "Add New Course" to start',
                        style: TextStyle(color: Colors.grey, fontSize: 14),
                      ),
                    ],
                  ),
                )
              else
                ...currentCourses.asMap().entries.map((entry) => _buildCourseItem(entry.value, entry.key)).toList(),

              // Add Another Course Button
              if (currentCourses.isNotEmpty)
                Column(
                  children: [
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _canAddMoreCourses() ? _addCourse : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 50),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: const Icon(Icons.add, size: 20),
                      label: const Text('Add Another Course'),
                    ),
                  ],
                ),

              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCourseItem(CGPACourse course, int index) {
    final codeController = TextEditingController(text: course.code);
    final unitController = TextEditingController(text: course.unit > 0 ? course.unit.toString() : '');
    String selectedGrade = course.grade;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Remove Button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _removeCourse(index),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
                side: BorderSide(color: Colors.red.shade300),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              icon: const Icon(Icons.delete, size: 18),
              label: const Text('Remove Course', style: TextStyle(fontSize: 14)),
            ),
          ),
          const SizedBox(height: 12),
          
          // Course Code
          TextFormField(
            controller: codeController,
            decoration: const InputDecoration(
              labelText: 'Course Code',
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              prefixIcon: Icon(Icons.menu_book),
            ),
            style: const TextStyle(fontSize: 16),
            onChanged: (value) {
              _updateCourse(index, CGPACourse(
                code: value.trim().toUpperCase(),
                unit: course.unit,
                grade: course.grade,
              ));
            },
          ),
          const SizedBox(height: 12),
          
          // Unit and Grade Row
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: unitController,
                  decoration: const InputDecoration(
                    labelText: 'Course Units',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    prefixIcon: Icon(Icons.numbers),
                  ),
                  style: const TextStyle(fontSize: 16),
                  keyboardType: TextInputType.number,
                  onChanged: (value) {
                    final unit = int.tryParse(value) ?? 0;
                    _updateCourse(index, CGPACourse(
                      code: course.code,
                      unit: unit,
                      grade: course.grade,
                    ));
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: selectedGrade,
                  items: _grades.map((grade) => DropdownMenuItem(
                    value: grade,
                    child: Text(
                      grade,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: _getGradeColor(grade),
                      ),
                    ),
                  )).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => selectedGrade = value);
                      _updateCourse(index, CGPACourse(
                        code: course.code,
                        unit: course.unit,
                        grade: value,
                      ));
                    }
                  },
                  decoration: const InputDecoration(
                    labelText: 'Grade',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    prefixIcon: Icon(Icons.grade),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _getGradeColor(String grade) {
    switch (grade.toUpperCase()) {
      case 'A': return Colors.green;
      case 'B': return Colors.blue;
      case 'C': return Colors.orange;
      case 'D': return Colors.amber;
      case 'E': return Colors.red.shade400;
      case 'F': return Colors.red;
      default: return Colors.black;
    }
  }
}