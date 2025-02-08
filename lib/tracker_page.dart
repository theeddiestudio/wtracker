import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'database_helper.dart';
import 'weight_entry.dart';

// Placeholder pages for now
class TrackerPage extends StatefulWidget {
  const TrackerPage({super.key});

  @override
  State<TrackerPage> createState() => _TrackerPageState();
}

class _TrackerPageState extends State<TrackerPage> {
  final TextEditingController _bwmrgController = TextEditingController();
  final TextEditingController _bwbgController = TextEditingController();
  final TextEditingController _bwagController = TextEditingController();
  final TextEditingController _bwslpController = TextEditingController();

  bool _ignoreBwmrg = true;
  bool _ignoreBwbg = true;
  bool _ignoreBwag = true;
  bool _ignoreBwslp = true;

  DateTime _currentDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadSavedData();
  }

  // Load saved data from the database
  Future<void> _loadSavedData() async {
    final dbHelper = DatabaseHelper.instance;
    final entry = await dbHelper
        .getWeightEntry(_currentDate.toLocal().toString().split(' ')[0]);

    setState(() {
      if (entry != null) {
        _bwmrgController.text = entry.bwmrg?.toStringAsFixed(2) ?? '';
        _bwbgController.text = entry.bwbg?.toStringAsFixed(2) ?? '';
        _bwagController.text = entry.bwag?.toStringAsFixed(2) ?? '';
        _bwslpController.text = entry.bwslp?.toStringAsFixed(2) ?? '';

        _ignoreBwmrg = entry.bwmrg == null;
        _ignoreBwbg = entry.bwbg == null;
        _ignoreBwag = entry.bwag == null;
        _ignoreBwslp = entry.bwslp == null;
      } else {
        // If no data exists for this date, reset fields to empty and set checkmarks to false
        _bwmrgController.clear();
        _bwbgController.clear();
        _bwagController.clear();
        _bwslpController.clear();

        _ignoreBwmrg = true;
        _ignoreBwbg = true;
        _ignoreBwag = true;
        _ignoreBwslp = true;
      }
    });
  }

  // Calculate bwday (average of non-ignored values)
  double? _calculateBwDay() {
    double total = 0;
    int count = 0;

    if (!_ignoreBwmrg && _bwmrgController.text.isNotEmpty) {
      total += double.tryParse(_bwmrgController.text) ?? 0;
      count++;
    }
    if (!_ignoreBwbg && _bwbgController.text.isNotEmpty) {
      total += double.tryParse(_bwbgController.text) ?? 0;
      count++;
    }
    if (!_ignoreBwag && _bwagController.text.isNotEmpty) {
      total += double.tryParse(_bwagController.text) ?? 0;
      count++;
    }
    if (!_ignoreBwslp && _bwslpController.text.isNotEmpty) {
      total += double.tryParse(_bwslpController.text) ?? 0;
      count++;
    }

    return count > 0 ? total / count : null;
  }

  // Save data to the database
  Future<void> _saveData() async {
    final dbHelper = DatabaseHelper.instance;
    final entry = WeightEntry(
      date: _currentDate.toLocal().toString().split(' ')[0],
      bwmrg: double.tryParse(_bwmrgController.text),
      bwbg: double.tryParse(_bwbgController.text),
      bwag: double.tryParse(_bwagController.text),
      bwslp: double.tryParse(_bwslpController.text),
      bwday: _calculateBwDay(),
    );
    await dbHelper.insertWeightEntry(entry);
    setState(() {
      // After saving data, ensure the ignored flag is updated
      _ignoreBwmrg = _bwmrgController.text.isEmpty;
      _ignoreBwbg = _bwbgController.text.isEmpty;
      _ignoreBwag = _bwagController.text.isEmpty;
      _ignoreBwslp = _bwslpController.text.isEmpty;
    });
  }

  void _increment(TextEditingController controller, bool isIgnored) async {
    double value = double.tryParse(controller.text) ?? 0;
    value += 0.1;
    controller.text = value.toStringAsFixed(2);

    if (isIgnored) {
      setState(() {
        // Remove the ignored flag when data is entered
        isIgnored = false;
      });
    }

    await _saveData(); // Save data after increment
  }

  void _decrement(TextEditingController controller, bool isIgnored) async {
    double value = double.tryParse(controller.text) ?? 0;
    value -= 0.1;
    controller.text = value.toStringAsFixed(2);

    if (isIgnored) {
      setState(() {
        // Remove the ignored flag when data is entered
        isIgnored = false;
      });
    }
    await _saveData(); // Save data after decrement
  }

  // Function to handle toggling the ignored flag
  void _onIgnoredChanged(bool value, String field) {
    setState(() {
      if (field == 'bwmrg') {
        _ignoreBwmrg = value;
      } else if (field == 'bwbg') {
        _ignoreBwbg = value;
      } else if (field == 'bwag') {
        _ignoreBwag = value;
      } else if (field == 'bwslp') {
        _ignoreBwslp = value;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Get today's date without the time
    DateTime today = DateTime.now();
    DateTime todayWithoutTime = DateTime(today.year, today.month, today.day);

    // Get the day of the week for the current date
    String dayOfWeek =
        DateFormat('EEEE').format(_currentDate); // Day of week (e.g., "Monday")

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          // Add arrows to change date
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () {
                  setState(() {
                    _currentDate =
                        _currentDate.subtract(const Duration(days: 1));
                  });
                  _loadSavedData();
                },
              ),
              Column(
                children: [
                  Text(
                    'Date: ${_currentDate.toLocal().toString().split(' ')[0]}',
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '($dayOfWeek)', // Display the day of the week
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.normal),
                  ),
                ],
              ),
              // Show right arrow only if current date is not selected
              if (_currentDate.isBefore(todayWithoutTime))
                IconButton(
                  icon: const Icon(Icons.arrow_forward),
                  onPressed: () {
                    setState(() {
                      _currentDate = _currentDate.add(const Duration(days: 1));
                    });
                    _loadSavedData();
                  },
                ),
            ],
          ),
          const SizedBox(height: 20),

          // Weight inputs and ignore cross buttons
          _buildWeightInput(
              'Morning Weight', _bwmrgController, _ignoreBwmrg, 'bwmrg'),
          _buildWeightInput('Before Gym', _bwbgController, _ignoreBwbg, 'bwbg'),
          _buildWeightInput('After Gym', _bwagController, _ignoreBwag, 'bwag'),
          _buildWeightInput(
              'Before Sleep', _bwslpController, _ignoreBwslp, 'bwslp'),

          const SizedBox(height: 20),

          // Today's weight
          Text(
            'Today\'s Weight: ${_calculateBwDay()?.toStringAsFixed(2) ?? "X"}',
            style: const TextStyle(fontSize: 16),
          ),

          const SizedBox(height: 20),

          ElevatedButton(
            onPressed: () async {
              await _saveData();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Data saved successfully!')),
              );
            },
            child: const Text('Upload'),
          ),
        ],
      ),
    );
  }

  Widget _buildWeightInput(String label, TextEditingController controller,
      bool isIgnored, String field) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          // Checkmark icon with colored icon
          IconButton(
            icon: isIgnored
                ? const Icon(Icons.cancel, color: Colors.red)
                : const Icon(Icons.check_circle, color: Colors.green),
            onPressed: () =>
                _onIgnoredChanged(!isIgnored, field), // Toggle ignored state
          ),
          Expanded(
            child: TextField(
              controller: controller,
              decoration: InputDecoration(
                labelText: label,
                border: const OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              onChanged: (value) async {
                setState(() {
                  if (value.isNotEmpty) {
                    // Only update ignore flag if the field now has data
                    if (field == 'bwmrg') _ignoreBwmrg = false;
                    if (field == 'bwbg') _ignoreBwbg = false;
                    if (field == 'bwag') _ignoreBwag = false;
                    if (field == 'bwslp') _ignoreBwslp = false;
                  }
                });
                await _saveData(); // Save data when text changes
              },
            ),
          ),
          IconButton(
            icon: const Icon(Icons.remove),
            onPressed: () => _decrement(controller, isIgnored),
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _increment(controller, isIgnored),
          ),
        ],
      ),
    );
  }
}
