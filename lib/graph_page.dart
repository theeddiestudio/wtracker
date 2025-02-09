import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'dart:convert';
import 'database_helper.dart';
import 'weight_entry.dart';

class GraphPage extends StatefulWidget {
  const GraphPage({super.key});

  @override
  State<GraphPage> createState() => _GraphPageState();
}

class _GraphPageState extends State<GraphPage> {
  List<WeightEntry> _entries = [];
  bool _showDots = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _loadHistory();
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

  /* Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _showDots = prefs.getBool('enable_dots') ?? true;
    });
  } */

  Future<void> _loadSettings() async {
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
  }

  Future<void> _loadHistory() async {
    final dbHelper = DatabaseHelper.instance;
    final entries = await dbHelper.getWeightHistoryWithMissingDates(30);
    setState(() {
      _entries = entries;
    });
  }

  List<WeightEntry> _getWeeklyData() {
    if (_entries.length <= 7) return _entries;
    return _entries.sublist(_entries.length - 7);
  }

  List<WeightEntry> _getMonthlyData() {
    if (_entries.length <= 30) return _entries;
    return _entries.sublist(_entries.length - 30);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Weight Graphs')),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 5),
            const Divider(thickness: 3),
            const SizedBox(height: 10),
            _buildGraphCard('Weekly Weight Graph', _buildWeeklyChart()),
            const SizedBox(height: 20),
            const Divider(thickness: 2),
            const SizedBox(height: 20),
            _buildGraphCard('Monthly Weight Graph', _buildMonthlyChart()),
            const SizedBox(height: 20), // Add bottom padding
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

  LineChartData _buildWeeklyChart() {
    final weeklyData = _getWeeklyData();
    return _buildChartData(weeklyData, Colors.blue, 7, 0.5, 1);
  }

  LineChartData _buildMonthlyChart() {
    final monthlyData = _getMonthlyData();
    return _buildChartData(monthlyData, Colors.green, 30, 1, 5);
  }

  LineChartData _buildChartData(List<WeightEntry> data, Color lineColor,
      int length, double leastCount, double passedInterval) {
    if (data.isEmpty) return LineChartData();

    final spots = <FlSpot>[];
    double? lastValidY;

    for (int i = 0; i < data.length; i++) {
      final double yValue = data[i].bwday ?? 0.0;
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
          color: lineColor,
          dotData: FlDotData(show: _showDots),
          belowBarData: BarAreaData(show: false),
        ),
      ],
      titlesData: FlTitlesData(
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 40,
            // interval: 1,
            getTitlesWidget: (value, _) {
              // if (value % leastCount != 0) return Container();
              return Text(value.toStringAsFixed(leastCount == 1 ? 0 : 1));
            },
          ),
        ),
        rightTitles:
            const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            interval: passedInterval,
            getTitlesWidget: (value, _) {
              int reversedLabel = length - value.toInt();
              return reversedLabel < 1 || reversedLabel > length
                  ? Container()
                  : Text('$reversedLabel');
            },
          ),
        ),
      ),
      borderData: FlBorderData(show: true),
      gridData: FlGridData(show: true),
    );
  }
}

class FullScreenGraph extends StatefulWidget {
  final LineChartData chartData;
  const FullScreenGraph({super.key, required this.chartData});

  @override
  _FullScreenGraphState createState() => _FullScreenGraphState();
}

class _FullScreenGraphState extends State<FullScreenGraph> {
  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Force interval = 1 in fullscreen mode
    LineChartData modifiedChartData = widget.chartData.copyWith(
      titlesData: widget.chartData.titlesData.copyWith(
        bottomTitles: widget.chartData.titlesData.bottomTitles!.copyWith(
          sideTitles:
              widget.chartData.titlesData.bottomTitles!.sideTitles.copyWith(
            interval: 1, // Force 1 for both weekly & monthly in fullscreen
          ),
        ),
      ),
    );

    return Scaffold(
      body: Stack(
        children: [
          Center(
            child: InteractiveViewer(
              panEnabled: true,
              scaleEnabled: true,
              boundaryMargin: const EdgeInsets.all(20),
              minScale: 0.5,
              maxScale: 5.0,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: MediaQuery.of(context).size.width, // Increase width
                  // child: LineChart(widget.chartData),
                  child: LineChart(modifiedChartData),
                ),
              ),
            ),
          ),
          Positioned(
            top: 10,
            left: 10,
            child: FloatingActionButton.extended(
              backgroundColor: (Theme.of(context).brightness == Brightness.dark
                      ? Colors.white
                      : const Color(0xff0f0024))
                  .withOpacity(0.45),
              onPressed: () {
                Navigator.pop(context);
              },
              icon: Icon(
                Icons.arrow_back,
                /* color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.black
                    : Colors.white, */
                color: (Theme.of(context).brightness == Brightness.dark
                        ? Colors.black
                        : Colors.white)
                    .withOpacity(0.6),
              ),
              label: const Text(""),
            ),
          ),
        ],
      ),
    );
  }
}
