// lib/features/debug/debug_screen.dart
import 'package:flutter/material.dart';
import '../../../core/network/api_service.dart';
import '../splash/screens/splash_screen.dart';

class DebugScreen extends StatelessWidget {
  const DebugScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Debug Hive Storage')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Debug Button
            ElevatedButton(
              onPressed: () async {
                await ApiService().debugHiveStorage();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Check console for Hive data')),
                );
              },
              child: Text('Debug Hive Storage'),
            ),
            SizedBox(height: 20),
            
            // Clear Data Button
            ElevatedButton(
              onPressed: () async {
                await ApiService().clearAllUserData();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('All user data cleared! Restart app.')),
                );
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: Text('Clear All User Data', style: TextStyle(color: Colors.white)),
            ),
            SizedBox(height: 20),
            
            // Go to Splash Screen - FIXED
            ElevatedButton(
              onPressed: () {
                // Use Navigator.pushReplacement with MaterialPageRoute instead of named route
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => SplashScreen()),
                );
              },
              child: Text('Go to Splash Screen'),
            ),
            
            SizedBox(height: 20),
            
            // Alternative: Restart App Completely
            ElevatedButton(
              onPressed: () async {
                await ApiService().clearAllUserData();
                // This will completely restart the app
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => SplashScreen()),
                  (route) => false,
                );
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
              child: Text('Clear Data & Restart App', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}