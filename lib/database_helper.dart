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
    DateTime sunday =
        targetDate.subtract(Duration(days: targetDate.weekday % 7));

    // Fetch all entries for the week (from Sunday to targetDate)
    List<Map<String, dynamic>> result = await db.query(
      'weight_entries',
      where: 'date BETWEEN ? AND ?',
      whereArgs: [sunday.toIso8601String().substring(0, 10), date],
      orderBy: 'date ASC',
    );

    // Calculate the average bwday for the week, ignoring days with bwday = 0
    List<double> validWeights = [];
    for (var row in result) {
      double weight = row['bwday'] ?? 0.0;
      if (weight > 0) {
        validWeights.add(weight);
      }
    }

    double bwwk = validWeights.isNotEmpty
        ? validWeights.reduce((a, b) => a + b) / validWeights.length
        : 0.0;

    // Update bwwk for all days in the week
    for (var row in result) {
      await db.update(
        'weight_entries',
        {'bwwk': bwwk},
        where: 'date = ?',
        whereArgs: [row['date']],
      );
    }

    // Return the calculated bwwk value
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

  /* Future<List<WeightEntry>> getWeightHistory(int days) async {
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

    return maps.map((map) => WeightEntry.fromMap(map)).toList();
  } */

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
