import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:io';
import 'dart:convert';
import 'graph_page.dart';
import 'wkdb_helper.dart';
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
    if (!await dir.exists()) await dir.create(recursive: true);
    return '${dir.path}/settings.json';
  }

  Future<void> _loadMWGraphData() async {
    final dbHelper = WeekDatabaseHelper.instance;

    // Load settings and MW graph data in parallel
    final settingsFuture = _loadSettings();
    final entriesFuture = dbHelper.getMWGraphData(4);

    final results = await Future.wait([settingsFuture, entriesFuture]);

    setState(() {
      _showDots = results[0] as bool;
      _entries = _fillMissingWeeks(results[1] as List<Map<String, dynamic>>);
    });
  }

  Future<bool> _loadSettings() async {
    try {
      final path = await _getSettingsPath();
      final settingsFile = File(path);
      if (await settingsFile.exists()) {
        final settings = jsonDecode(await settingsFile.readAsString());
        return settings['enable_dots'] ?? true;
      }
    } catch (e) {
      print("Error loading settings: $e");
    }
    return true;
  }

  List<WeekEntry> _fillMissingWeeks(List<Map<String, dynamic>> weeks) {
    DateTime today = DateTime.now();
    int daysToSubtract = 21 + today.weekday;
    DateTime df = today.subtract(Duration(days: daysToSubtract));

    List<WeekEntry> filledEntries = [];
    Map<String, double> weekMap = {
      for (var week in weeks) week['df']: week['bwwk']
    };

    for (int i = 0; i < 4; i++) {
      String dfStr = df.toIso8601String().substring(0, 10);
      double? bwwk = weekMap[dfStr];

      // Find closest valid week in-memory (no extra DB calls)
      if (bwwk == null) {
        bwwk = _findClosestBwwk(weekMap, df);
      }

      if (bwwk != null) {
        filledEntries.add(WeekEntry(
            df: dfStr,
            dt: df.add(Duration(days: 6)).toIso8601String().substring(0, 10),
            bwwk: bwwk));
      }

      df = df.add(Duration(days: 7));
    }

    return filledEntries;
  }

  double? _findClosestBwwk(Map<String, double> weekMap, DateTime df) {
    DateTime pastDf = df;
    DateTime futureDf = df;

    while (true) {
      pastDf = pastDf.subtract(Duration(days: 7));
      futureDf = futureDf.add(Duration(days: 7));

      if (weekMap.containsKey(pastDf.toIso8601String().substring(0, 10))) {
        return weekMap[pastDf.toIso8601String().substring(0, 10)];
      }
      if (weekMap.containsKey(futureDf.toIso8601String().substring(0, 10))) {
        return weekMap[futureDf.toIso8601String().substring(0, 10)];
      }
      if (pastDf.isBefore(DateTime(2000)) && futureDf.isAfter(DateTime.now())) {
        break;
      }
    }
    return null;
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
      final double yValue = _entries[i].bwwk;
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
          color: Colors.teal,
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
        rightTitles:
            const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            interval: 1,
            getTitlesWidget: (value, _) {
              int index = value.toInt();
              if (index < 0 || index >= _entries.length) return Container();
              return Text('${4 - index}');
            },
          ),
        ),
      ),
      borderData: FlBorderData(show: true),
      gridData: FlGridData(show: true),
    );
  }
}
