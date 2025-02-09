import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'home.dart'; // Import the tracker page

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

  Future<void> _requestPermission() async {
    var result = await Permission.photos.request();
    if (result.isGranted) {
      _goToHomePage();
    } else {
      // If denied, show a message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Media permission is required to continue.")),
      );
    }
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
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(), // Loading while checking permissions
            SizedBox(height: 20),
            Text("You need access to all files."),
          ],
        ),
      ),
    );
  }
}
