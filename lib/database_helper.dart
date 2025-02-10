import 'package:sqflite/sqflite.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'weight_entry.dart'; // Import model

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;

    final prefs = await SharedPreferences.getInstance();
    String? saveLocation = prefs.getString('save_location');

    // Default to .wtracker if no location is set
    String directoryPath = saveLocation ?? '/storage/emulated/0/.wtracker';
    final directory = Directory('$directoryPath/database');

    // Create the 'database' directory if it doesn't exist
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }

    final dbPath = '${directory.path}/weight_tracker.db';

    _database = await openDatabase(dbPath, version: 1, onCreate: _onCreate);
    return _database!;
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE weight_entries (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date TEXT UNIQUE,
        bwmrg REAL,
        bwbg REAL,
        bwag REAL,
        bwslp REAL,
        bwday REAL,
        bwwk REAL
      )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute(
          'ALTER TABLE weight_entries ADD COLUMN bwwk REAL DEFAULT 0.0');
    }
  }

  Future<int> insertWeightEntry(WeightEntry entry) async {
    final db = await database;
    await updateWeekAverages(entry.date); // Update bwwk for the week
    return await db.insert(
      'weight_entries',
      entry.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<WeightEntry>> getMWGraphData(int maxWeeks) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'weight_entries',
      columns: ['bwwk', 'date'],
      orderBy: 'date DESC',
      limit: maxWeeks * 7, // To check up to 7 days per week
    );

    List<WeightEntry> weeks = [];
    Set<int> seenWeeks = {};

    for (var map in maps) {
      int weekNumber = DateTime.parse(map['date']).weekday;
      if (!seenWeeks.contains(weekNumber)) {
        seenWeeks.add(weekNumber);
        weeks.add(WeightEntry.fromMap(map));
      }
      if (weeks.length >= maxWeeks) break;
    }

    return weeks;
  }

  Future<WeightEntry?> getWeightEntry(String date) async {
    final db = await database;
    final maps = await db.query(
      'weight_entries',
      where: 'date = ?',
      whereArgs: [date],
    );
    if (maps.isNotEmpty) {
      return WeightEntry.fromMap(maps.first);
    }
    return null;
  }

  Future<List<WeightEntry>> getWeightHistoryWithMissingDates(int days) async {
    final db = await database;
    final today = DateTime.now();
    final startDate = today.subtract(Duration(days: days - 1));

    final maps = await db.query(
      'weight_entries',
      where: 'date BETWEEN ? AND ?',
      whereArgs: [
        startDate.toIso8601String().substring(0, 10),
        today.toIso8601String().substring(0, 10)
      ],
      orderBy: 'date ASC',
    );

    final List<WeightEntry> entries = List.generate(maps.length, (i) {
      return WeightEntry.fromMap(maps[i]);
    });

    // Map existing entries by date for faster lookup
    Map<String, WeightEntry> entryMap = {
      for (var entry in entries) entry.date: entry
    };

    List<WeightEntry> completeEntries = [];
    double? lastKnownWeight;

    for (int i = 0; i < days; i++) {
      final date = startDate.add(Duration(days: i));
      final dateString = date.toIso8601String().substring(0, 10);

      if (entryMap.containsKey(dateString)) {
        lastKnownWeight = entryMap[dateString]?.bwday ?? lastKnownWeight;
        completeEntries.add(entryMap[dateString]!);
      } else {
        completeEntries
            .add(WeightEntry(date: dateString, bwday: lastKnownWeight ?? 0.0));
      }
    }

    return completeEntries;
  }

  Future<void> deleteAllData() async {
    final db = await database;
    await db.delete('weight_entries');
  }

  Future<double> updateWeekAverages(String date) async {
    final db = await database;
    DateTime targetDate = DateTime.parse(date);

    // Find the full week range (Sunday to Saturday)
    DateTime sunday = targetDate.subtract(
        Duration(days: targetDate.weekday == 7 ? 0 : targetDate.weekday));
    DateTime saturday = sunday.add(Duration(days: 6));

    // Fetch all weight entries within the full week range
    List<Map<String, dynamic>> result = await db.query(
      'weight_entries',
      where: 'date BETWEEN ? AND ?',
      whereArgs: [
        sunday.toIso8601String().substring(0, 10),
        saturday.toIso8601String().substring(0, 10)
      ],
      orderBy: 'date ASC',
    );

    // Calculate bwwk using all days in the week, ignoring bwday = 0
    List<double> validWeights = result
        .map((row) => row['bwday'] as double? ?? 0.0)
        .where((bw) => bw > 0)
        .toList();

    double bwwk = validWeights.isNotEmpty
        ? double.parse(
            (validWeights.reduce((a, b) => a + b) / validWeights.length)
                .toStringAsFixed(2))
        : 0.0;

    // Ensure bwwk is updated for all days in the week (even missing ones)
    for (int i = 0; i < 7; i++) {
      String currentDate =
          sunday.add(Duration(days: i)).toIso8601String().substring(0, 10);
      await db.update(
        'weight_entries',
        {'bwwk': bwwk},
        where: 'date = ?',
        whereArgs: [currentDate],
      );
    }

    return bwwk;
  }

  // Fetch all weight entries sorted by date (newest first)
  Future<List<WeightEntry>> getWeightHistory() async {
    final db = await database;
    final maps = await db.query('weight_entries', orderBy: 'date DESC');

    return List.generate(maps.length, (i) {
      return WeightEntry(
        id: (maps[i]['id'] as int?) ?? 0,
        date: (maps[i]['date'] as String?) ?? '',
        bwmrg: (maps[i]['bwmrg'] as double?) ?? 0.0,
        bwbg: (maps[i]['bwbg'] as double?) ?? 0.0,
        bwag: (maps[i]['bwag'] as double?) ?? 0.0,
        bwslp: (maps[i]['bwslp'] as double?) ?? 0.0,
        bwday: (maps[i]['bwday'] as double?) ?? 0.0,
      );
    });
  }

  // Delete a specific weight entry by ID
  Future<void> deleteEntry(int id) async {
    final db = await database;
    await db.delete('weight_entries', where: 'id = ?', whereArgs: [id]);
  }

  // Reset the entire database (deletes all weight entries)
  Future<void> resetDatabase() async {
    final db = await database;
    await db.delete(
        'weight_entries'); // Deletes all rows from the weight_entries table
  }
}
