// lib/features/cgpa/screens/cgpa_calculator_screen.dart
import 'package:flutter/material.dart';

class CGPACalculatorScreen extends StatefulWidget {
  const CGPACalculatorScreen({super.key});
  @override State<CGPACalculatorScreen> createState() => _CGPACalculatorScreenState();
}

class _CGPACalculatorScreenState extends State<CGPACalculatorScreen> {
  final List<Map<String, dynamic>> _courses = [
    {'code': 'PHY 101', 'unit': 3, 'grade': 'A'},
    {'code': 'MTH 112', 'unit': 4, 'grade': 'B'},
  ];

  double _cgpa = 0.0;

  @override
  void initState() {
    super.initState();
    _calculateCGPA();
  }

  void _calculateCGPA() {
    double totalPoints = 0;
    int totalUnits = 0;
    for (var c in _courses) {
      totalPoints += c['unit'] * _gradeToPoint(c['grade']);
      totalUnits += c['unit'];
    }
    setState(() => _cgpa = totalUnits > 0 ? totalPoints / totalUnits : 0.0);
  }

  double _gradeToPoint(String grade) {
    switch (grade) { case 'A': return 5.0; case 'B': return 4.0; case 'C': return 3.0; case 'D': return 2.0; case 'F': return 0.0; default: return 0.0; }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('CGPA Calculator')),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            color: const Color(0xFFF8FAFC),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Your CGPA', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                Text(_cgpa.toStringAsFixed(2), style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Color(0xFF0077B6))),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _courses.length,
              itemBuilder: (_, i) {
                final c = _courses[i];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    title: Text(c['code']),
                    subtitle: Text('Unit: ${c['unit']} • Grade: ${c['grade']}'),
                    trailing: IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => setState(() => _courses.removeAt(i).then((_) => _calculateCGPA()))),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: ElevatedButton.icon(
              onPressed: () => _addCourse(),
              icon: const Icon(Icons.add),
              label: const Text('Add Course'),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF6B35)),
            ),
          ),
        ],
      ),
    );
  }

  void _addCourse() {
    // Simple add for now
    setState(() {
      _courses.add({'code': 'NEW 101', 'unit': 3, 'grade': 'A'});
      _calculateCGPA();
    });
  }
}