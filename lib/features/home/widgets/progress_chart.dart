// lib/features/home/widgets/progress_chart.dart
import 'package:flutter/material.dart';

class ProgressChart extends StatelessWidget {
  const ProgressChart({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 180,
      child: Stack(
        children: [
          Center(
            child: SizedBox(
              width: 140,
              height: 140,
              child: CircularProgressIndicator(
                value: 0.72,
                strokeWidth: 12,
                backgroundColor: const Color(0xFFE5E7EB),
                valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF0077B6)),
              ),
            ),
          ),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Text('72%', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Color(0xFF0077B6))),
                Text('Learning Progress', style: TextStyle(fontSize: 14, color: Color(0xFF6B7280))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}