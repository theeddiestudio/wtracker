import 'package:flutter/material.dart';
import 'database_helper.dart';
import 'wkdb_helper.dart';
import 'weight_entry.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  List<WeightEntry> _entries = [];

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final dbHelper = DatabaseHelper.instance;
    final entries = await dbHelper.getWeightHistory();
    setState(() {
      _entries = entries;
    });
  }

  Future<void> _deleteEntry(String entryDate, int id) async {
    final dbHelper = DatabaseHelper.instance;
    final wkdbHelper = WeekDatabaseHelper.instance;

    await dbHelper.deleteEntry(id);
    await wkdbHelper.insertOrUpdateWeekAverage(entryDate);
    _loadHistory();
  }

  Future<void> _resetDatabase() async {
    final dbHelper = DatabaseHelper.instance;

    // Confirmation dialog before deleting all entries
    bool? confirmDelete = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Reset History"),
        content: const Text("Are you sure you want to delete all entries?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmDelete == true) {
      await dbHelper.resetDatabase();
      _loadHistory();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _entries.isEmpty
          ? const Center(child: Text("No history available."))
          : ListView.builder(
              itemCount: _entries.length,
              itemBuilder: (context, index) {
                final entry = _entries[index];
                return ListTile(
                  title: Text('${entry.bwday?.toStringAsFixed(2) ?? 'N/A'} kg'),
                  subtitle: Text(entry.date),
                  onTap: () async {
                    // Navigate to the detailed entry view
                    final bool? isDeleted = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => DetailPage(entry: entry),
                      ),
                    );

                    if (isDeleted == true) {
                      _loadHistory(); // Refresh the history list after deletion
                    }
                  },
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => _deleteEntry(entry.date, entry.id!),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _resetDatabase,
        icon: const Icon(Icons.delete_forever),
        label: const Text("Reset History"),
        backgroundColor: Colors.red,
      ),
    );
  }
}

class DetailPage extends StatefulWidget {
  final WeightEntry entry;
  const DetailPage({super.key, required this.entry});

  @override
  _DetailPageState createState() => _DetailPageState();
}

class _DetailPageState extends State<DetailPage> {
  double? bwwk;
  int? df, dt; // Store week range for recalculation

  @override
  void initState() {
    super.initState();
    _fetchBwwk();
  }

  Future<void> _fetchBwwk() async {
    final weekDbHelper = WeekDatabaseHelper.instance;
    String entryDate = widget.entry.date; // Use the entry's date

    double? bwwk = await weekDbHelper.getWeekAverage(entryDate);

    setState(() {
      this.bwwk = bwwk ?? 0.0;
    });
  }

  Future<void> _deleteEntryAndUpdateWeek() async {
    final dbHelper = WeekDatabaseHelper.instance;
    String entryDate = widget.entry.date;

    await dbHelper.deleteEntry(widget.entry.id!);
    await dbHelper.insertOrUpdateWeekAverage(entryDate);

    Navigator.pop(context, true);
  }

  String _getValueOrX(double? value, bool isIgnored) {
    if (isIgnored) {
      return 'X';
    }
    return value?.toStringAsFixed(2) ?? 'N/A';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Entry Details")),
      body: Padding(
        padding: const EdgeInsets.all(6.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Date: ${widget.entry.date}',
                style: const TextStyle(fontSize: 18)),
            const Divider(thickness: 2), // Horizontal line
            const SizedBox(height: 8),
            Text(
              'Morning: ${_getValueOrX(widget.entry.bwmrg, widget.entry.bwmrg == null)} kg',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              'Afternoon: ${_getValueOrX(widget.entry.bwbg, widget.entry.bwbg == null)} kg',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              'Evening: ${_getValueOrX(widget.entry.bwag, widget.entry.bwag == null)} kg',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              'Night: ${_getValueOrX(widget.entry.bwslp, widget.entry.bwslp == null)} kg',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 8),
            const Divider(thickness: 2), // Horizontal line
            const SizedBox(height: 8),
            Text(
              'Bodyweight: ${_getValueOrX(widget.entry.bwday, widget.entry.bwday == null)} kg',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Week Average: ${bwwk != null ? bwwk!.toStringAsFixed(2) : "N/A"} kg',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            FloatingActionButton.extended(
              onPressed: _deleteEntryAndUpdateWeek,
              icon: const Icon(Icons.delete_forever),
              label: const Text("Delete this entry"),
              backgroundColor: Colors.red,
            ),
          ],
        ),
      ),
    );
  }
}
