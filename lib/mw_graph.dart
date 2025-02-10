import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'dart:convert';
import 'graph_page.dart';
import 'database_helper.dart';
import 'weight_entry.dart';

/* class MWGraphPage extends StatefulWidget {
  const MWGraphPage({super.key});

  @override
  State<MWGraphPage> createState() => _MWGraphPageState();
}

class _MWGraphPageState extends State<MWGraphPage> {
  List<WeightEntry> _entries = [];

  bool _showDots = true;

  @override
  void initState() {
    super.initState();
    _loadMWGraphData();
  }

  Future<String> _getSettingsPath() async {
    final dir = Directory('/storage/emulated/0/.wtracker/settings');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
      await _saveSettings('enable_dots', true);
    }
    return '${dir.path}/settings.json';
  }

  Future<void> _saveSettings(String key, dynamic value) async {
    final path = await _getSettingsPath();
    final settingsFile = File(path);

    Map<String, dynamic> settings = {};
    if (await settingsFile.exists()) {
      settings = jsonDecode(await settingsFile.readAsString());
    }

    settings[key] = value;
    await settingsFile.writeAsString(jsonEncode(settings));
  }

  Future<void> _loadMWGraphData() async {
    final path = await _getSettingsPath();
    final prefs = await SharedPreferences.getInstance();
    if (prefs.containsKey('enable_dots')) {
      setState(() {
        _showDots = prefs.getBool('enable_dots') ?? true;
      });
      return;
    }
    final settingsFile = File(path);
    if (await settingsFile.exists()) {
      final jsonString = await settingsFile.readAsString();
      final settings = jsonDecode(jsonString);
      setState(() {
        _showDots = settings['enable_dots'] ?? true;
      });
    }

    final dbHelper = DatabaseHelper.instance;
    final entries = await dbHelper.getMWGraphData(4); // Get up to 8 weeks
    setState(() {
      _entries = entries.reversed.toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('MW Graph')),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 5),
            const Divider(thickness: 3),
            const SizedBox(height: 10),
            _buildGraphCard('Monthly Week Graph', _buildMWChart()),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildGraphCard(String title, LineChartData chartData) {
    return Column(
      children: [
        Text(title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        GestureDetector(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) => FullScreenGraph(chartData: chartData)),
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10), // Add margin
            child: SizedBox(height: 300, child: LineChart(chartData)),
          ),
        ),
        ElevatedButton(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) => FullScreenGraph(chartData: chartData)),
          ),
          child: const Text("View"),
        ),
      ],
    );
  }

  LineChartData _buildMWChart() {
    if (_entries.isEmpty) return LineChartData();

    final spots = <FlSpot>[];
    double? lastValidY;

    for (int i = 0; i < _entries.length; i++) {
      final double yValue = _entries[i].bwwk ?? 0.0;
      if (yValue > 0) {
        spots.add(FlSpot(i.toDouble(), yValue));
        lastValidY = yValue;
      } else if (lastValidY != null) {
        spots.add(FlSpot(i.toDouble(), lastValidY));
      }
    }

    return LineChartData(
      lineBarsData: [
        LineChartBarData(
          spots: spots,
          isCurved: false,
          color: Colors.red,
          dotData: FlDotData(show: _showDots),
          belowBarData: BarAreaData(show: false),
        ),
      ],
      titlesData: FlTitlesData(
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 40,
            getTitlesWidget: (value, _) => Text(value.toStringAsFixed(1)),
          ),
        ),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            interval: 1,
            getTitlesWidget: (value, _) {
              int index = value.toInt();
              if (index < 0 || index >= _entries.length) return Container();

              int weekNumber = 4 - index; // Since we reversed the data
              return Text('$weekNumber');
            },
          ),
        ),
        rightTitles:
            const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      ),
      borderData: FlBorderData(show: true),
      gridData: FlGridData(show: true),
    );
  }
} */
