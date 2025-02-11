import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:android_intent/android_intent.dart';
import 'dart:io';
import 'dart:convert';
import 'database_helper.dart';
import 'bfdb_helper.dart';
import 'fat_entry.dart';
import 'home.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _showDots = true;
  bool _isMetricSystem = true;
  bool _notificationsEnabled = false;
  bool _encryptionEnabled = false;

  @override
  void initState() {
    super.initState();

    // Load other settings from the settings file
    _loadSettings().then((fileSettings) {
      setState(() {
        // Set the rest of the settings from the settings file
        _showDots = fileSettings['enable_dots'] ?? true;
        _isMetricSystem = fileSettings['measurement_system'] ?? true;
        _encryptionEnabled = fileSettings['encryption_enabled'] ?? false;

        // Load dark mode setting and apply it
        bool isDarkMode = fileSettings['dark_mode'] ?? false;
        Provider.of<ThemeProvider>(context, listen: false)
            .toggleTheme(isDarkMode);
      });

      // Check the current notification permission status
      _checkNotificationPermission();
    });
  }

  // Add a method to save the measurement system setting
  Future<void> _saveMeasurementSystem(bool value) async {
    await _saveSettings('measurement_system', value);
    setState(() {
      _isMetricSystem = value;
    });
  }

  Future<void> _checkNotificationPermission() async {
    // Check the current notification permission status
    PermissionStatus status = await Permission.notification.status;

    // Set the notification toggle to true if permission is granted, false otherwise
    setState(() {
      _notificationsEnabled = status.isGranted;
    });
  }

  Future<Map<String, dynamic>> _loadSettings() async {
    final path = await _getSettingsPath();
    final settingsFile = File(path);

    if (await settingsFile.exists()) {
      final jsonString = await settingsFile.readAsString();
      return jsonDecode(jsonString);
    }
    return {}; // Return empty if no settings exist
  }

  Future<String> _getSettingsPath() async {
    final dir = Directory('/storage/emulated/0/.wtracker/settings');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return '${dir.path}/settings.json';
  }

  Future<void> updateFatDataOnToggle(bool isMetric) async {
    final prefs = await SharedPreferences.getInstance();
    final fatDbHelper = FatEntryDatabaseHelper.instance;

    // Modifiers for unit conversion
    double _lengthModifier = 0.393701; // cm to inches
    double _weightModifier = 2.20462; // kg to lbs

    // Retrieve height and weight from SharedPreferences
    double? height = prefs.getDouble('height');
    double? weight = prefs.getDouble('weight');

    // Convert height and weight based on the selected measurement system
    if (height != null) {
      height = isMetric ? height / _lengthModifier : height * _lengthModifier;
      await prefs.setDouble('height', height);
    }

    if (weight != null) {
      weight = isMetric ? weight / _weightModifier : weight * _weightModifier;
      await prefs.setDouble('weight', weight);
    }

    // Retrieve the latest fat entry from the database
    final entry = await fatDbHelper
        .getFatEntry(DateTime.now().toLocal().toString().split(' ')[0]);

    if (entry != null) {
      // Convert neck, waist, hip, fat mass, and lean mass based on the selected measurement system
      double neck = isMetric
          ? entry.neck / _lengthModifier
          : entry.neck * _lengthModifier;
      double waist = isMetric
          ? entry.waist / _lengthModifier
          : entry.waist * _lengthModifier;
      double? hip = entry.hip == null
          ? null
          : (isMetric
              ? entry.hip! / _lengthModifier
              : entry.hip! * _lengthModifier);
      double fatMass = isMetric
          ? entry.fatMass! / _weightModifier
          : entry.fatMass! * _weightModifier;
      double leanMass = isMetric
          ? entry.leanMass! / _weightModifier
          : entry.leanMass! * _weightModifier;

      // Update the database with the converted values
      final updatedEntry = FatEntry(
        date: entry.date,
        neck: neck,
        waist: waist,
        hip: hip,
        bodyFat: entry.bodyFat, // Body fat percentage remains unchanged
        fatMass: fatMass,
        leanMass: leanMass,
      );

      await fatDbHelper.insertFatEntry(updatedEntry);
    }
  }

  Future<void> toggleNotifications(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notifications_enabled', value);
  }

  Future<void> _saveSettings(String key, dynamic value) async {
    final path = await _getSettingsPath();
    final settingsFile = File(path);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);

    Map<String, dynamic> settings = {};
    if (await settingsFile.exists()) {
      settings = jsonDecode(await settingsFile.readAsString());
    }

    settings[key] = value;
    await settingsFile.writeAsString(jsonEncode(settings));
  }

  // Open app settings to grant permissions
  Future<void> _openAppSettings() async {
    final AndroidIntent intent = AndroidIntent(
      action: 'android.settings.APPLICATION_DETAILS_SETTINGS',
      data: 'package:com.tes.wtracker',
    );
    await intent.launch();
  }

  Future<void> _handleNotificationToggle(bool value) async {
    if (value) {
      // User wants to enable notifications
      PermissionStatus status = await Permission.notification.status;
      if (!status.isGranted) {
        status = await Permission.notification.request();
      }
      if (status.isGranted) {
        await toggleNotifications(value);
        setState(() {
          _notificationsEnabled = value;
        });
      }
    } else {
      // User wants to disable notifications
      await _openAppSettings(); // Open app settings so the user can disable notification permission manually

      // Recheck the permission status after the settings are opened
      PermissionStatus status = await Permission.notification.status;

      // If the permission is still not granted, set both the shared prefs and UI state to false
      if (!status.isGranted) {
        await toggleNotifications(false); // Set shared prefs to false
        setState(() {
          _notificationsEnabled =
              false; // Update UI to reflect the disabled state
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(6),
        children: [
          const Divider(thickness: 3),
          const SizedBox(height: 8),
          SwitchListTile(
            title: const Text('Enable Dots'),
            value: _showDots,
            onChanged: (value) async {
              await _saveSettings('enable_dots', value);
              setState(() {
                _showDots = value;
              });
            },
          ),
          SwitchListTile(
            title: const Text('Enable Dark Mode'),
            value: themeProvider.themeMode == ThemeMode.dark,
            onChanged: (value) async {
              await _saveSettings('dark_mode', value);
              themeProvider.toggleTheme(value);
            },
          ),
          SwitchListTile(
            title: const Text('Enable Metric System'),
            value: _isMetricSystem,
            onChanged: (value) async {
              await updateFatDataOnToggle(value);
              await _saveMeasurementSystem(value);
            },
          ),
          /* SwitchListTile(
            title: const Text('Enable Encryption'),
            value: _encryptionEnabled,
            onChanged: (value) async {
              await _saveSettings('encryption_enabled', value);
              setState(() {
                _encryptionEnabled = value;
              });
            },
          ), */
          SwitchListTile(
            title: const Text('Enable Notifications'),
            value: _notificationsEnabled,
            onChanged: (value) async {
              await _handleNotificationToggle(value);
            },
          ),
          const SizedBox(height: 5),
          const Divider(thickness: 2),
          const SizedBox(height: 5),
          ListTile(
            title: const Text('Launch App Settings'),
            trailing: const Icon(Icons.settings),
            onTap: _openAppSettings,
          ),
          ListTile(
            title: const Text('Reset All Data'),
            trailing: const Icon(Icons.delete_forever, color: Colors.red),
            onTap: () async {
              final dbHelper = DatabaseHelper.instance;
              await dbHelper.resetDatabase();

              // Reset settings.json to default values
              final settingsFile = File(await _getSettingsPath());
              final defaultSettings = {
                "enable_dots": true,
                "measurement_system": true,
                // "notifications_enabled": false,
                "encryption_enabled": false,
                "dark_mode": false
              };
              await settingsFile.writeAsString(jsonEncode(defaultSettings));

              // Apply default settings immediately
              Provider.of<ThemeProvider>(context, listen: false)
                  .toggleTheme(false);

              setState(() {
                _showDots = true;
                _isMetricSystem = true;
                _encryptionEnabled = false;
              });

              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text('All data and settings have been reset')),
              );
            },
          ),
        ],
      ),
    );
  }
}
