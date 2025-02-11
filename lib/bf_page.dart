import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math';
import 'bfdb_helper.dart'; // Import new helper
import 'fat_entry.dart';

class BodyFatTrackerPage extends StatefulWidget {
  const BodyFatTrackerPage({super.key});

  @override
  State<BodyFatTrackerPage> createState() => _BodyFatTrackerPageState();
}

class _BodyFatTrackerPageState extends State<BodyFatTrackerPage> {
  final _formKey = GlobalKey<FormState>();
  String _gender = 'male';
  double? _height;
  double? _weight;
  double? _neck;
  double? _waist;
  double? _hip;
  double? _bodyFat;
  DateTime _currentDate = DateTime.now();
  final TextEditingController _heightController = TextEditingController();
  final TextEditingController _weightController = TextEditingController();
  final TextEditingController _neckController = TextEditingController();
  final TextEditingController _waistController = TextEditingController();
  final TextEditingController _hipController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadSavedData();
  }

  Future<void> _loadSavedData() async {
    final fatDbHelper = FatEntryDatabaseHelper.instance;
    final entry = await fatDbHelper
        .getFatEntry(_currentDate.toLocal().toString().split(' ')[0]);

    final prefs = await SharedPreferences.getInstance();
    double? sharedPrefHeight = prefs.getDouble('height');

    double? bwday = await fatDbHelper
        .getBwday(_currentDate.toLocal().toString().split(' ')[0]);

    setState(() {
      if (entry != null) {
        _gender = entry.gender;
        _height = entry.height;
        _weight = entry.weight;
        _neck = entry.neck;
        _waist = entry.waist;
        _hip = entry.hip;
        _bodyFat = entry.bodyFat;

        _heightController.text =
            _height?.toString() ?? sharedPrefHeight?.toString() ?? '';
        _weightController.text = _weight?.toString() ?? bwday?.toString() ?? '';
        _neckController.text = _neck?.toString() ?? '';
        _waistController.text = _waist?.toString() ?? '';
        _hipController.text = _hip?.toString() ?? '';
      } else {
        _height = sharedPrefHeight;
        _weight = bwday; // Set weight from bwday if available
        _heightController.text = _height?.toString() ?? '';
        _weightController.text = _weight?.toString() ?? '';
        _neckController.clear();
        _waistController.clear();
        _hipController.clear();
        _bodyFat = null;
      }
    });
  }

  Future<void> _saveHeight(double height) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('height', height);
    setState(() {
      _height = height;
    });
  }

  // ... (US Navy calculation methods remain the same)

  Future<void> _saveFatEntry() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      _bodyFat = _calculateBodyFat();

      final fatDbHelper = FatEntryDatabaseHelper.instance;
      final entry = FatEntry(
        date: _currentDate.toLocal().toString().split(' ')[0],
        gender: _gender,
        height: _height!,
        weight: _weight!,
        neck: _neck!,
        waist: _waist!,
        hip: _hip,
        bodyFat: _bodyFat,
      );

      await fatDbHelper.insertFatEntry(entry);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Body fat data saved!')),
      );
    }
  }

  double? _calculateBodyFat() {
    if (_height == null || _weight == null || _neck == null || _waist == null) {
      return null; // Not enough data
    }

    // Define log10 function
    double log10(double x) => log(x) / log(10);

    double heightInInches = _height! * 0.393701;
    double neckInInches = _neck! * 0.393701;
    double waistInInches = _waist! * 0.393701;

    if (_gender == 'male') {
      _bodyFat = (86.010 * log10(waistInInches - neckInInches)) -
          (70.041 * log10(heightInInches)) +
          36.76;
    } else {
      if (_hip == null) return null; // Hip measurement required for women
      double hipInInches = _hip! * 0.393701;

      _bodyFat = (163.205 * log10(waistInInches + hipInInches - neckInInches)) -
          (97.684 * log(heightInInches)) -
          78.387;
    }

    return _bodyFat;
  }

  void _increment(TextEditingController controller, String field) {
    double value = double.tryParse(controller.text) ?? 0;
    value += 0.1;
    controller.text = value.toStringAsFixed(2);

    if (field == 'height') {
      _height = value;
      _saveHeight(value); // Save height to SharedPreferences
    } else if (field == 'weight') {
      _weight = value;
    } else if (field == 'neck') {
      _neck = value;
    } else if (field == 'waist') {
      _waist = value;
    } else if (field == 'hip') {
      _hip = value;
    }
  }

  void _decrement(TextEditingController controller, String field) {
    double value = double.tryParse(controller.text) ?? 0;
    value -= 0.1;
    controller.text = value.toStringAsFixed(2);

    if (field == 'height') {
      _height = value;
      _saveHeight(value); // Save height to SharedPreferences
    } else if (field == 'weight') {
      _weight = value;
    } else if (field == 'neck') {
      _neck = value;
    } else if (field == 'waist') {
      _waist = value;
    } else if (field == 'hip') {
      _hip = value;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Body Fat Tracker')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // Gender selection
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: 'Gender'),
                value: _gender,
                items: ['male', 'female']
                    .map((gender) => DropdownMenuItem<String>(
                          value: gender,
                          child: Text(gender),
                        ))
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    _gender = value!;
                  });
                },
              ),

              // Height input (cm)
              TextFormField(
                decoration: const InputDecoration(labelText: 'Height (cm)'),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter height';
                  }
                  return null;
                },
                onSaved: (value) {
                  _height = double.tryParse(value!);
                  if (_height != null) {
                    _saveHeight(_height!);
                  }
                },
              ),

              // Weight input (kg)
              TextFormField(
                decoration: const InputDecoration(labelText: 'Weight (kg)'),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter weight';
                  }
                  return null;
                },
                onSaved: (value) {
                  _weight = double.tryParse(value!);
                },
              ),

              // Neck circumference input (cm)
              TextFormField(
                decoration: const InputDecoration(labelText: 'Neck (cm)'),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter neck circumference';
                  }
                  return null;
                },
                onSaved: (value) {
                  _neck = double.tryParse(value!);
                },
              ),

              // Waist circumference input (cm)
              TextFormField(
                decoration: const InputDecoration(labelText: 'Waist (cm)'),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter waist circumference';
                  }
                  return null;
                },
                onSaved: (value) {
                  _waist = double.tryParse(value!);
                },
              ),

              // Hip circumference input (cm) - only for women
              if (_gender == 'female')
                TextFormField(
                  decoration: const InputDecoration(labelText: 'Hip (cm)'),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter hip circumference';
                    }
                    return null;
                  },
                  onSaved: (value) {
                    _hip = double.tryParse(value!);
                  },
                ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _saveFatEntry,
                child: const Text('Save'),
              ),

              // Conditionally display either the calculated body fat or the "Calculating..." message
              _calculateBodyFat() != null
                  ? Text(
                      'Body Fat: ${_calculateBodyFat()?.toStringAsFixed(2)}%',
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold),
                    )
                  : (_height != null // Check if height has been entered
                      ? const Text(
                          'Body Fat: 0.0',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
                        )
                      : Container()),
            ],
          ),
        ),
      ),
    );
  }
}
