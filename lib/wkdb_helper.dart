import 'package:sqflite/sqflite.dart';
import 'database_helper.dart'; // Import the existing DatabaseHelper
import 'week_entry.dart';

class WeekDatabaseHelper {
  static final WeekDatabaseHelper instance = WeekDatabaseHelper._init();
  static Database? _database;

  WeekDatabaseHelper._init();

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

  // Insert or update week average (calculates `bwwk` inside)
  Future<void> insertOrUpdateWeekAverage(String date) async {
    final db = await database;

    // Calculate df (past Sunday) and dt (future Saturday)
    DateTime targetDate = DateTime.parse(date);
    DateTime df = targetDate.subtract(Duration(days: targetDate.weekday % 7));
    DateTime dt = df.add(Duration(days: 6));

    String dfStr = df.toIso8601String().substring(0, 10);
    String dtStr = dt.toIso8601String().substring(0, 10);

    // Calculate weekly average (`bwwk`) using entries in this week
    double? weekAverage = await _calculateWeekAverage(dfStr, dtStr);

    if (weekAverage == null) return; // Skip if no valid data

    // Check if this week already exists
    final List<Map<String, dynamic>> existingWeek = await db.query(
      'week_entries',
      where: 'df = ? AND dt = ?',
      whereArgs: [dfStr, dtStr],
    );

    if (existingWeek.isNotEmpty) {
      // Update existing week average
      await db.update(
        'week_entries',
        {'bwwk': weekAverage},
        where: 'df = ? AND dt = ?',
        whereArgs: [dfStr, dtStr],
      );
    } else {
      // Insert new week entry
      await db.insert(
        'week_entries',
        {'df': dfStr, 'dt': dtStr, 'bwwk': weekAverage},
      );
    }
  }

  // Calculate weekly average weight for a given week range
  Future<double?> _calculateWeekAverage(String df, String dt) async {
    final db = await database;

    final List<Map<String, dynamic>> weightEntries = await db.query(
      'weight_entries',
      where: 'date >= ? AND date <= ? AND bwday > 0',
      whereArgs: [df, dt],
    );

    if (weightEntries.isEmpty) return null;

    double sum =
        weightEntries.fold(0, (prev, element) => prev + element['bwday']);
    return sum / weightEntries.length;
  }

  // Retrieve week average for a given date
  Future<double?> getWeekAverage(String date) async {
    final db = await database;
    DateTime targetDate = DateTime.parse(date);

    // Find the week range containing this date
    final List<Map<String, dynamic>> result = await db.query(
      'week_entries',
      where: 'df <= ? AND dt >= ?',
      whereArgs: [date, date],
    );

    if (result.isNotEmpty) {
      return result.first['bwwk'];
    }
    return null;
  }

  // Get MWGraph Data (latest 4-8 weeks)
  Future<List<Map<String, dynamic>>> getMWGraphData(int maxWeeks) async {
    final db = await database;

    // Find today's date
    DateTime today = DateTime.now();
    int daysToSubtract = 21 + today.weekday; // Adjust to get the past 3-4 weeks

    // Get the latest df available in the database
    final List<Map<String, dynamic>> latestEntry = await db.query(
      'week_entries',
      orderBy: 'dt DESC',
      limit: 1,
    );

    String? latestDf;
    if (latestEntry.isNotEmpty) {
      latestDf = latestEntry.first['df'];
    }

    // If we don’t have the latest week, estimate it
    DateTime trackingDate = latestDf != null ? DateTime.parse(latestDf) : today;
    DateTime startDf = trackingDate.subtract(Duration(days: daysToSubtract));

    // Get up to maxWeeks of data from week_entries
    final List<Map<String, dynamic>> weeks = await db.query(
      'week_entries',
      where: 'df >= ?',
      whereArgs: [startDf.toIso8601String().substring(0, 10)],
      orderBy: 'df ASC',
      limit: maxWeeks,
    );

    return weeks;
  }

  // Delete all week entries
  Future<void> deleteEntry(int id) async {
    await DatabaseHelper.instance.deleteEntry(id);
  }
}
