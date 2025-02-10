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

    final dbPath = await getDatabasePath();

    _database = await openDatabase(dbPath, version: 1, onCreate: _onCreate);
    return _database!;
  }

  Future<void> _onCreate(Database db, int version) async {
    await createTables(db);
  }

  Future<void> createTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS weight_entries (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date TEXT UNIQUE,
        bwmrg REAL,
        bwbg REAL,
        bwag REAL,
        bwslp REAL,
        bwday REAL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS week_entries (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        df TEXT UNIQUE,  -- First past Sunday
        dt TEXT UNIQUE,  -- First future Saturday
        bwwk REAL
      )
    ''');
  }

  Future<int> insertWeightEntry(WeightEntry entry) async {
    final db = await database;
    return await db.insert(
      'weight_entries',
      entry.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<String> getDatabasePath() async {
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

    return dbPath;
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
    await db.delete('week_entries');
  }
}
