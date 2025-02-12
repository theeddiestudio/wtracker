import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math';
import 'dart:io';
import 'dart:convert';
import 'bfdb_helper.dart'; // Import new helper
import 'fat_entry.dart';

class BodyFatTrackerPage extends StatefulWidget {
  const BodyFatTrackerPage({super.key});

  @override
  State<BodyFatTrackerPage> createState() => _BodyFatTrackerPageState();
}

class _BodyFatTrackerPageState extends State<BodyFatTrackerPage> {
  bool _isMetricSystem = true;
  double _lengthModifier = 1.0; // cm to inches
  double _weightModifier = 1.0; // kg to lbs

  double? _fatMass;
  double? _leanMass;

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

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadSavedData();
  }

  Future<void> _loadSavedData() async {
    final fatDbHelper = FatEntryDatabaseHelper.instance;

    final entry = await fatDbHelper
        .getFatEntry(_currentDate.toLocal().toString().split(' ')[0]);

    final prefs = await SharedPreferences.getInstance();
    double? sharedPrefHeight = prefs.getDouble('height');
    double? sharedPrefWeight = prefs.getDouble('weight');
    String? sharedPrefGender = prefs.getString('gender');
    bool? sharedPrefMS = prefs.getBool('measurement_system') ?? true;

    setState(() {
      _isMetricSystem = sharedPrefMS;
      _lengthModifier =
          sharedPrefMS ? 1.0 : 0.393701; // Set modifier based on system
      _weightModifier = sharedPrefMS ? 1.0 : 2.20462;

      _gender = sharedPrefGender ??
          'male'; // Default to 'male' if sharedPrefGender is null
      _height = sharedPrefHeight; // Only height from shared preferences
      _weight = sharedPrefWeight; // Weight from sharedPrefWeight if available

      _heightController.text = _height != null
          ? (_isMetricSystem
              ? _height!.toStringAsFixed(2)
              : (_height! * _lengthModifier).toStringAsFixed(2))
          : '';

      _weightController.text = _weight != null
          ? (_isMetricSystem
              ? _weight!.toStringAsFixed(2)
              : (_weight! * _weightModifier).toStringAsFixed(2))
          : '';

      if (entry != null) {
        _neck = entry.neck;
        _waist = entry.waist;
        _hip = entry.hip;
        _bodyFat = entry.bodyFat;
        _fatMass = entry.fatMass;
        _leanMass = entry.leanMass;

        _neckController.text = _neck != null
            ? (_isMetricSystem
                ? _neck!.toStringAsFixed(0)
                : (_neck! * _lengthModifier).toStringAsFixed(0))
            : '';

        _waistController.text = _waist != null
            ? (_isMetricSystem
                ? _waist!.toStringAsFixed(0)
                : (_waist! * _lengthModifier).toStringAsFixed(0))
            : '';

        _hipController.text = _hip != null
            ? (_isMetricSystem
                ? _hip!.toStringAsFixed(0)
                : (_hip! * _lengthModifier).toStringAsFixed(0))
            : '';
      } else {
        _neckController.clear();
        _waistController.clear();
        _hipController.clear();
        _bodyFat = null;
        _fatMass = null;
        _leanMass = null;
      }
    });
  }

  void _calculateFatAndLeanMass() {
    if (_bodyFat != null && _weight != null) {
      _fatMass = (_bodyFat! * _weight!) / 100;
      _leanMass = (_weight! - _fatMass!);
    } else {
      _fatMass = null;
      _leanMass = null;
    }
  }

  Future<void> _saveHeight(double height) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('height', height);
    setState(() {
      _height = height;
    });
  }

  Future<void> _saveGender(String gender) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('gender', gender);
    setState(() {
      _gender = gender;
    });
  }

  Future<void> _saveWeight(double weight) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('weight', weight);
    setState(() {
      _weight = weight;
    });
  }

  // ... (US Navy calculation methods remain the same)

  Future<void> _saveFatEntry() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      _bodyFat = _calculateBodyFat();
      _calculateFatAndLeanMass();

      // Convert to metric if necessary
      double neckInMetric = _neck!;
      double waistInMetric = _waist!;
      double? hipInMetric = _hip!;
      double fatMassInMetric = _fatMass!;
      double leanMassInMetric = _leanMass!;

      final fatDbHelper = FatEntryDatabaseHelper.instance;
      final entry = FatEntry(
        date: _currentDate.toLocal().toString().split(' ')[0],
        neck: neckInMetric,
        waist: waistInMetric,
        hip: hipInMetric,
        bodyFat: _bodyFat,
        fatMass: fatMassInMetric,
        leanMass: leanMassInMetric,
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

    /* double heightInInches =
        _isMetricSystem ? _height! * _lengthModifier : _height!;
    double neckInInches = _isMetricSystem ? _neck! * _lengthModifier : _neck!;
    double waistInInches =
        _isMetricSystem ? _waist! * _lengthModifier : _waist!; */

    double heightInInches = _height! * 0.393701;
    ; // use raw value cause the modifier is changing while value is always metric.
    double waistInInches = _waist! * 0.393701;
    ;
    double neckInInches = _neck! * 0.393701;
    ;

    if (_gender == 'male') {
      _bodyFat = (86.010 * log10(waistInInches - neckInInches)) -
          (70.041 * log10(heightInInches)) +
          36.76;
    } else {
      if (_hip == null) return null; // Hip measurement required for women
      // double hipInInches = _isMetricSystem ? _hip! * _lengthModifier : _hip!;
      double hipInInches = _hip! * 0.393701;

      _bodyFat = (163.205 * log10(waistInInches + hipInInches - neckInInches)) -
          (97.684 * log10(heightInInches)) -
          78.387;
    }

    // Ensure body fat percentage is within a reasonable range
    if (_bodyFat != null && (_bodyFat! < 0 || _bodyFat! > 100)) {
      return 0; // Invalid body fat percentage
    }

    return _bodyFat;
  }

  Color _getBodyFatColor(double bodyFat) {
    if (bodyFat > 20) {
      return Colors.red; // Red for body fat over 20%
    } else if (bodyFat > 15) {
      return Colors.yellow; // Yellow for body fat between 15% and 20%
    } else {
      return Colors.green; // Green for body fat under 15%
    }
  }

  // Update the input fields' labels based on the measurement system
  String _getHeightLabel() =>
      _isMetricSystem ? 'Height (cm)' : 'Height (inches)';
  String _getWeightLabel() => _isMetricSystem ? 'Weight (kg)' : 'Weight (lbs)';
  String _getNeckLabel() => _isMetricSystem ? 'Neck (cm)' : 'Neck (inches)';
  String _getWaistLabel() => _isMetricSystem ? 'Waist (cm)' : 'Waist (inches)';
  String _getHipLabel() => _isMetricSystem ? 'Hip (cm)' : 'Hip (inches)';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(6.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              const SizedBox(height: 25),
              Row(
                children: [
                  Radio<String>(
                    value: 'male',
                    groupValue: _gender,
                    onChanged: (value) {
                      setState(() {
                        _saveGender(value!); // Use null assertion operator
                      });
                    },
                  ),
                  const Text('Male'),
                  const SizedBox(width: 20),
                  Radio<String>(
                    value: 'female',
                    groupValue: _gender,
                    onChanged: (value) {
                      setState(() {
                        _saveGender(value!); // Use null assertion operator
                      });
                    },
                  ),
                  const Text('Female'),
                ],
              ),
              const SizedBox(height: 5),
              const Divider(thickness: 3),
              const SizedBox(height: 5),
              // Height input
              TextFormField(
                controller: _heightController,
                decoration: InputDecoration(labelText: _getHeightLabel()),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter height';
                  }
                  return null;
                },
                onSaved: (value) {
                  _height = double.tryParse(value!)! / _lengthModifier;
                  if (_height != null) {
                    _saveHeight(_height!);
                  }
                },
              ),

              // Weight input
              TextFormField(
                controller: _weightController,
                decoration: InputDecoration(labelText: _getWeightLabel()),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter weight';
                  }
                  return null;
                },
                onSaved: (value) {
                  _weight = double.tryParse(value!)! / _weightModifier;
                  if (_weight != null) {
                    _saveWeight(_weight!);
                  }
                },
              ),

              // Neck circumference input
              TextFormField(
                controller: _neckController,
                decoration: InputDecoration(labelText: _getNeckLabel()),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter neck circumference';
                  }
                  return null;
                },
                onSaved: (value) {
                  _neck = double.tryParse(value!)! / _lengthModifier;
                },
              ),

              // Waist circumference input
              TextFormField(
                controller: _waistController,
                decoration: InputDecoration(labelText: _getWaistLabel()),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter waist circumference';
                  }
                  return null;
                },
                onSaved: (value) {
                  _waist = double.tryParse(value!)! / _lengthModifier;
                },
              ),

              // Hip circumference input - only for women
              if (_gender == 'female')
                TextFormField(
                  controller: _hipController,
                  decoration: InputDecoration(labelText: _getHipLabel()),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter hip circumference';
                    }
                    return null;
                  },
                  onSaved: (value) {
                    _hip = double.tryParse(value!)! / _lengthModifier;
                  },
                ),

              const SizedBox(height: 10),

              if (_fatMass != null && _leanMass != null)
                Column(
                  children: [
                    Text(
                      'Body Fat Mass: ${_isMetricSystem ? _fatMass!.toStringAsFixed(2) + ' kg' : (_fatMass! * _weightModifier).toStringAsFixed(2) + ' lbs'}',
                      style: const TextStyle(fontSize: 16),
                    ),
                    Text(
                      'Lean Body Mass: ${_isMetricSystem ? _leanMass!.toStringAsFixed(2) + ' kg' : (_leanMass! * _weightModifier).toStringAsFixed(2) + ' lbs'}',
                      style: const TextStyle(fontSize: 16),
                    ),
                  ],
                ),

              const SizedBox(height: 12),

              // Display calculated body fat
              _calculateBodyFat() != null
                  ? Text(
                      'Body Fat: ${_calculateBodyFat()?.toStringAsFixed(2)}%',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: _getBodyFatColor(
                            _calculateBodyFat()!), // Apply color based on body fat value
                      ),
                    )
                  : (_height != null
                      ? const Text(
                          'Body Fat: 0.0',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        )
                      : Container()),
              const SizedBox(height: 4),
              const Divider(thickness: 2),
              const SizedBox(height: 4),
              ElevatedButton(
                onPressed: _saveFatEntry,
                child: const Text('Upload'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
