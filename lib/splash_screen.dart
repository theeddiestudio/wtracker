import 'package:flutter/material.dart';

class SplashScreen extends StatefulWidget {
  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    // Simulate initialization (e.g., media access, permission checks)
    _initializeApp();
  }

  // Simulate some app initialization with a delay
  Future<void> _initializeApp() async {
    await Future.delayed(Duration(seconds: 3)); // 3 seconds delay

    // After the delay, navigate to the tracker page
    Navigator.pushReplacementNamed(context, '/tracker');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blue,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.accessibility_new,
              size: 100,
              color: Colors.white,
            ),
            SizedBox(height: 20),
            Text(
              "Initializing...",
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
