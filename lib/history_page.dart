import 'package:flutter/material.dart';
import 'database_helper.dart';
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

  Future<void> _deleteEntry(int id) async {
    final dbHelper = DatabaseHelper.instance;
    await dbHelper.deleteEntry(id);
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
                    onPressed: () => _deleteEntry(entry.id!),
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

class DetailPage extends StatelessWidget {
  final WeightEntry entry;
  const DetailPage({super.key, required this.entry});

  @override
  Widget build(BuildContext context) {
    // Function to get value or show "X" if ignored
    String _getValueOrX(double? value, bool isIgnored) {
      if (isIgnored) {
        return 'X'; // Return "X" for ignored values
      }
      return value?.toStringAsFixed(2) ??
          'N/A'; // Return formatted value or "N/A" if null
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Entry Details"),
        actions: [
          /* IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              Navigator.pop(context); // Go back to the history page
            },
          ), */
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Date: ${entry.date}', style: const TextStyle(fontSize: 18)),
            const SizedBox(height: 8),
            Text(
              'Bodyweight: ${_getValueOrX(entry.bwday, entry.bwday == null)} kg',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              'Morning Weight: ${_getValueOrX(entry.bwmrg, entry.bwmrg == null)} kg',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              'Before Gym: ${_getValueOrX(entry.bwbg, entry.bwbg == null)} kg',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              'After Gym: ${_getValueOrX(entry.bwag, entry.bwag == null)} kg',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              'Before Sleep: ${_getValueOrX(entry.bwslp, entry.bwslp == null)} kg',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 20),
            FloatingActionButton.extended(
              onPressed: () async {
                final dbHelper = DatabaseHelper.instance;
                await dbHelper.deleteEntry(entry.id!);
                Navigator.pop(
                    context, true); // Pass 'true' to indicate deletion
              },
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
