import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'dart:convert';
import 'graph_page.dart';
import 'wkdb_helper.dart'; // Use WeekDatabaseHelper
import 'week_entry.dart';

class MWGraphPage extends StatefulWidget {
  const MWGraphPage({super.key});

  @override
  State<MWGraphPage> createState() => _MWGraphPageState();
}

class _MWGraphPageState extends State<MWGraphPage> {
  List<WeekEntry> _entries = [];
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

    final dbHelper = WeekDatabaseHelper.instance;
    final entries = await _fetchMWGraphData();
    setState(() {
      _entries = entries;
    });
  }

  Future<List<WeekEntry>> _fetchMWGraphData() async {
    final dbHelper = WeekDatabaseHelper.instance;
    DateTime today = DateTime.now();

    // Subtracting days to reach fourth week's Sunday (df)
    int daysToSubtract = 21 + today.weekday;
    DateTime df = today.subtract(Duration(days: daysToSubtract));
    DateTime dt = df.add(Duration(days: 6));

    List<WeekEntry> entries = [];

    for (int i = 0; i < 4; i++) {
      double? bwwk = await _getValidBwwk(df);

      if (bwwk != null) {
        entries.add(WeekEntry(
            df: df.toIso8601String().substring(0, 10),
            dt: dt.toIso8601String().substring(0, 10),
            bwwk: bwwk));
      }

      df = df.add(const Duration(days: 7)); // Move to the next week
    }

    return entries.toList(); // Reverse to plot from oldest to newest
  }

  Future<double?> _getValidBwwk(DateTime df) async {
    final dbHelper = WeekDatabaseHelper.instance;
    double? bwwk;

    // Try getting data for this df
    bwwk = await dbHelper.getBwwkByDf(df.toIso8601String().substring(0, 10));

    // If missing, find closest past week
    if (bwwk == null) {
      DateTime pastDf = df;
      while (bwwk == null) {
        pastDf = pastDf.subtract(const Duration(days: 7));
        bwwk = await dbHelper
            .getBwwkByDf(pastDf.toIso8601String().substring(0, 10));

        if (pastDf.isBefore(DateTime(2000))) {
          break; // Stop if it goes too far back
        }
      }
    }

    // If still missing, find closest future week
    if (bwwk == null) {
      DateTime futureDf = df;
      while (bwwk == null) {
        futureDf = futureDf.add(const Duration(days: 7));
        bwwk = await dbHelper
            .getBwwkByDf(futureDf.toIso8601String().substring(0, 10));

        if (futureDf.isAfter(DateTime.now())) {
          break; // Stop if it goes beyond today
        }
      }
    }

    return bwwk;
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
            padding: const EdgeInsets.symmetric(horizontal: 10),
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
              int weekNumber = 4 - index; // Since reversed
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
}
