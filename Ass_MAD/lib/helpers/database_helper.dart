import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import '../models/activity.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('extracurricular.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, filePath);
    return await openDatabase(
      path,
      version: 2,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE activities (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        category TEXT NOT NULL,
        date TEXT NOT NULL,
        hours INTEGER NOT NULL,
        description TEXT NOT NULL,
        isCompleted INTEGER NOT NULL DEFAULT 0,
        imagePath TEXT,
        sourceUrl TEXT,
        steps INTEGER
      )
    ''');

    await db.execute(
        'CREATE INDEX idx_category ON activities(category)');
    await db.execute(
        'CREATE INDEX idx_date ON activities(date)');
    await db.execute(
        'CREATE INDEX idx_isCompleted ON activities(isCompleted)');

    await _seedData(db);
  }

  Future<void> _seedData(Database db) async {
    final samples = [
      {
        'title': 'Football Training',
        'category': 'Sports',
        'date': DateTime(2026, 1, 15).toIso8601String(),
        'hours': 2,
        'description': 'Team practice session at college field',
        'isCompleted': 1,
        'imagePath': null,
        'sourceUrl': null,
        'steps': null,
      },
      {
        'title': 'Math Club Meeting',
        'category': 'Academic',
        'date': DateTime(2026, 1, 16).toIso8601String(),
        'hours': 1,
        'description': 'Problem solving session with club members',
        'isCompleted': 1,
        'imagePath': null,
        'sourceUrl': null,
        'steps': null,
      },
      {
        'title': 'Art Exhibition',
        'category': 'Arts',
        'date': DateTime(2026, 1, 17).toIso8601String(),
        'hours': 3,
        'description': 'Annual college art exhibition visit',
        'isCompleted': 0,
        'imagePath': null,
        'sourceUrl': null,
        'steps': null,
      },
      {
        'title': 'Community Clean-Up',
        'category': 'Volunteer',
        'date': DateTime(2026, 1, 18).toIso8601String(),
        'hours': 4,
        'description': 'Neighbourhood clean-up drive',
        'isCompleted': 1,
        'imagePath': null,
        'sourceUrl': null,
        'steps': null,
      },
      {
        'title': 'Student Council Meeting',
        'category': 'Leadership',
        'date': DateTime(2026, 1, 19).toIso8601String(),
        'hours': 2,
        'description': 'Monthly student council discussion',
        'isCompleted': 0,
        'imagePath': null,
        'sourceUrl': null,
        'steps': null,
      },
    ];

    for (final s in samples) {
      await db.insert('activities', s);
    }
  }

  Future<void> _upgradeDB(
      Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      try {
        await db.execute(
            'ALTER TABLE activities ADD COLUMN imagePath TEXT');
      } catch (_) {}
      try {
        await db.execute(
            'ALTER TABLE activities ADD COLUMN sourceUrl TEXT');
      } catch (_) {}
      try {
        await db.execute(
            'ALTER TABLE activities ADD COLUMN steps INTEGER');
      } catch (_) {}
    }
  }

  // ─── CREATE ───────────────────────────────────────────────
  Future<int> insertActivity(Activity activity) async {
    final db = await database;
    final map = activity.toMap();
    map.remove('id');
    return await db.insert(
      'activities',
      map,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // ─── READ ALL ─────────────────────────────────────────────
  Future<List<Activity>> getAllActivities({
    String? category,
    bool? isCompleted,
    String sortBy = 'date',
    bool descending = true,
  }) async {
    final db = await database;

    final List<String> conditions = [];
    final List<dynamic> args = [];

    if (category != null && category != 'All') {
      conditions.add('category = ?');
      args.add(category);
    }
    if (isCompleted != null) {
      conditions.add('isCompleted = ?');
      args.add(isCompleted ? 1 : 0);
    }

    final where =
    conditions.isNotEmpty ? conditions.join(' AND ') : null;
    final orderBy = '$sortBy ${descending ? 'DESC' : 'ASC'}';

    final maps = await db.query(
      'activities',
      where: where,
      whereArgs: args.isNotEmpty ? args : null,
      orderBy: orderBy,
    );

    return maps.map((m) => Activity.fromMap(m)).toList();
  }

  // ─── READ SINGLE ──────────────────────────────────────────
  Future<Activity?> getActivityById(int id) async {
    final db = await database;
    final maps = await db.query(
      'activities',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return Activity.fromMap(maps.first);
  }

  // ─── SEARCH ───────────────────────────────────────────────
  Future<List<Activity>> searchActivities(String query) async {
    final db = await database;
    final q = '%${query.toLowerCase()}%';
    final maps = await db.rawQuery('''
      SELECT * FROM activities
      WHERE LOWER(title) LIKE ?
         OR LOWER(category) LIKE ?
         OR LOWER(description) LIKE ?
      ORDER BY date DESC
    ''', [q, q, q]);
    return maps.map((m) => Activity.fromMap(m)).toList();
  }

  // ─── UPDATE ───────────────────────────────────────────────
  Future<int> updateActivity(Activity activity) async {
    final db = await database;
    return await db.update(
      'activities',
      activity.toMap(),
      where: 'id = ?',
      whereArgs: [activity.id],
    );
  }

  Future<int> toggleComplete(int id, bool isCompleted) async {
    final db = await database;
    return await db.update(
      'activities',
      {'isCompleted': isCompleted ? 1 : 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> updateSteps(int id, int steps) async {
    final db = await database;
    return await db.update(
      'activities',
      {'steps': steps},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ─── DELETE ───────────────────────────────────────────────
  Future<int> deleteActivity(int id) async {
    final db = await database;
    return await db.delete(
      'activities',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteAllActivities() async {
    final db = await database;
    return await db.delete('activities');
  }

  // ─── STATISTICS ───────────────────────────────────────────
  Future<int> getTotalActivities() async {
    final db = await database;
    final result = await db
        .rawQuery('SELECT COUNT(*) as count FROM activities');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<int> getTotalHours() async {
    final db = await database;
    final result = await db
        .rawQuery('SELECT SUM(hours) as total FROM activities');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<double> getCompletionRate() async {
    final db = await database;
    final total = await db
        .rawQuery('SELECT COUNT(*) as c FROM activities');
    final completed = await db.rawQuery(
        'SELECT COUNT(*) as c FROM activities WHERE isCompleted = 1');
    final t = Sqflite.firstIntValue(total) ?? 0;
    final c = Sqflite.firstIntValue(completed) ?? 0;
    if (t == 0) return 0.0;
    return c / t;
  }

  Future<Map<String, int>> getHoursByCategory() async {
    final db = await database;
    final result = await db.rawQuery('''
      SELECT category, SUM(hours) as total
      FROM activities
      GROUP BY category
      ORDER BY total DESC
    ''');
    final map = <String, int>{};
    for (final row in result) {
      map[row['category'] as String] =
          (row['total'] as int?) ?? 0;
    }
    return map;
  }

  Future<Map<String, int>> getActivitiesPerMonth() async {
    final db = await database;
    final result = await db.rawQuery('''
      SELECT SUBSTR(date, 1, 7) as month, COUNT(*) as count
      FROM activities
      GROUP BY month
      ORDER BY month DESC
      LIMIT 6
    ''');
    final map = <String, int>{};
    for (final row in result) {
      map[row['month'] as String] =
          (row['count'] as int?) ?? 0;
    }
    return map;
  }

  Future<int> getTotalSteps() async {
    final db = await database;
    final result = await db
        .rawQuery('SELECT SUM(steps) as total FROM activities');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<List<Activity>> getRecentActivities(
      {int limit = 5}) async {
    final db = await database;
    final maps = await db.query(
      'activities',
      orderBy: 'date DESC',
      limit: limit,
    );
    return maps.map((m) => Activity.fromMap(m)).toList();
  }

  Future<void> close() async {
    final db = await database;
    db.close();
    _database = null;
  }
}
