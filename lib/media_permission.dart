import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'home.dart';

class MediaPermissionScreen extends StatefulWidget {
  @override
  _MediaPermissionScreenState createState() => _MediaPermissionScreenState();
}

class _MediaPermissionScreenState extends State<MediaPermissionScreen> {
  @override
  void initState() {
    super.initState();
    _checkPermission();
  }

  Future<void> _checkPermission() async {
    if (!await Permission.storage.isGranted) {
      await Permission.storage.request();
    }
    if (!await Permission.manageExternalStorage.isGranted) {
      await Permission.manageExternalStorage.request();
    }

    _goToHomePage();
  }

  void _goToHomePage() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const HomeScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF2E2E2E), // Match splash background color
      body: Center(
        child: SizedBox(
          width: 160, // Force image size
          height: 160, // Force image size
          child: Image.asset(
            'assets/logo.png',
            fit: BoxFit.contain, // Ensures it fits correctly
            errorBuilder: (context, error, stackTrace) {
              return const SizedBox(); // Hide if loading fails
            },
          ),
        ),
      ),
    );
  }
}
