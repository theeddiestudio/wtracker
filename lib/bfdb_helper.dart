import 'package:sqflite/sqflite.dart';
import 'database_helper.dart'; // Import the existing DatabaseHelper
import 'fat_entry.dart';

class FatEntryDatabaseHelper {
  static final FatEntryDatabaseHelper instance = FatEntryDatabaseHelper._init();
  static Database? _database;

  FatEntryDatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;

    // Use the same database path as DatabaseHelper
    final dbPath = await DatabaseHelper.instance.getDatabasePath();

    _database = await openDatabase(dbPath, version: 1, onCreate: _onCreate);
    return _database!;
  }

  Future<void> _onCreate(Database db, int version) async {
    await DatabaseHelper.instance.createTables(db);
  }

  Future<int> insertFatEntry(FatEntry entry) async {
    final db = await database;
    return await db.insert(
      'fat_entries',
      entry.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<FatEntry?> getFatEntry(String date) async {
    final db = await database;
    final maps = await db.query(
      'fat_entries',
      where: 'date = ?',
      whereArgs: [date],
    );
    if (maps.isNotEmpty) {
      return FatEntry.fromMap(maps.first);
    }
    return null;
  }

  Future<double?> getBwday(String date) async {
    final db = await database;
    final maps = await db.query(
      'weight_entries',
      columns: ['bwday'],
      where: 'date = ?',
      whereArgs: [date],
    );
    if (maps.isNotEmpty) {
      return maps.first['bwday'] as double?;
    }
    return null;
  }
}
