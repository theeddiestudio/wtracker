import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';
import 'dart:convert';
import 'tracker_page.dart';
import 'history_page.dart';
import 'graph_page.dart';
import 'settings_page.dart';

class ThemeProvider with ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;

  ThemeMode get themeMode => _themeMode;

  // Load the theme from SharedPreferences
  Future<void> loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final isDark = prefs.getBool('isDarkMode') ?? false;
    _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
  }

  // Toggle the theme and save the setting
  void toggleTheme(bool isDark) async {
    _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDarkMode', isDark); // Save the theme preference
    notifyListeners();
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  // Pages for navigation
  static const List<Widget> _pages = [
    TrackerPage(),
    HistoryPage(),
    GraphPage(),
    SettingsPage(),
  ];

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  // Initialize the app, request permissions, and then load settings
  Future<void> _initializeApp() async {
    await _requestPermissions(); // Wait for permissions first
    await _initializeSettings(); // Then initialize settings
    await _checkAndRequestNotificationPermission();
  }

  Future<void> _checkAndRequestNotificationPermission() async {
    PermissionStatus status = await Permission.notification.status;
    if (!status.isGranted) {
      // Request permission only once
      status = await Permission.notification.request();
      if (!status.isGranted) {
        _requestNotificationPermission();
      } else {
        // do nothing
      }
    }
  }

  Future<void> _requestNotificationPermission() async {
    final status = await Permission.notification.request();

    if (status.isGranted) {
      await _saveNotificationSetting(false);
    } else {}
  }

  Future<void> _saveNotificationSetting(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notifications_enabled', value);
  }

  Future<void> _initializeSettings() async {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final settings = await _loadSettings();

    bool isDarkMode = settings['dark_mode'] ?? false;
    themeProvider
        .toggleTheme(isDarkMode); // Set the theme based on saved settings
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  Future<void> _requestPermissions() async {
    if (!await Permission.storage.isGranted) {
      await Permission.storage.request();
    }
    if (!await Permission.manageExternalStorage.isGranted) {
      await Permission.manageExternalStorage.request();
    }
  }

  Future<Map<String, dynamic>> _loadSettings() async {
    final dir = Directory('/storage/emulated/0/.wtracker/settings');
    final path = '${dir.path}/settings.json';
    final settingsFile = File(path);

    if (await settingsFile.exists()) {
      final jsonString = await settingsFile.readAsString();
      return jsonDecode(jsonString);
    }
    return {}; // Return empty if file doesn't exist
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Weight Tracker'),
        actions: [
          IconButton(
            icon: const Icon(Icons.account_circle),
            onPressed: () {
              // TODO: Implement Google Sign-In
            },
          ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(
                color: Color(0xff0f0024),
              ),
              child: Text(
                'Weight Tracker',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.home),
              title: const Text('Tracker'),
              selected: _selectedIndex == 0,
              onTap: () {
                Navigator.pop(context); // Close the drawer
                _onItemTapped(0);
              },
            ),
            ListTile(
              leading: const Icon(Icons.history),
              title: const Text('History'),
              selected: _selectedIndex == 1,
              onTap: () {
                Navigator.pop(context); // Close the drawer
                _onItemTapped(1);
              },
            ),
            ListTile(
              leading: const Icon(Icons.show_chart),
              title: const Text('Graph'),
              selected: _selectedIndex == 2,
              onTap: () {
                Navigator.pop(context); // Close the drawer
                _onItemTapped(2);
              },
            ),
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('Settings'),
              selected: _selectedIndex == 3,
              onTap: () {
                Navigator.pop(context); // Close the drawer
                _onItemTapped(3);
              },
            ),
          ],
        ),
      ),
      body: _pages[_selectedIndex],
    );
  }
}
