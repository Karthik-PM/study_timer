import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/subject_tag.dart';
import '../models/study_session.dart';

class DatabaseService {
  static Database? _db;

  static Future<Database> get database async {
    _db ??= await _initDb();
    return _db!;
  }

  static Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    return openDatabase(
      join(dbPath, 'study_timer.db'),
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE tags(
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            colorValue INTEGER NOT NULL,
            emoji TEXT NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE sessions(
            id TEXT PRIMARY KEY,
            tagId TEXT NOT NULL,
            tagName TEXT NOT NULL,
            tagColor INTEGER NOT NULL,
            tagEmoji TEXT NOT NULL,
            startTime INTEGER NOT NULL,
            endTime INTEGER NOT NULL,
            durationSeconds INTEGER NOT NULL,
            notes TEXT
          )
        ''');
        // Insert default tags
        for (final tag in SubjectTag.defaults) {
          await db.insert('tags', tag.toMap());
        }
      },
    );
  }

  // Tags
  static Future<List<SubjectTag>> getTags() async {
    final db = await database;
    final maps = await db.query('tags', orderBy: 'name ASC');
    return maps.map(SubjectTag.fromMap).toList();
  }

  static Future<void> insertTag(SubjectTag tag) async {
    final db = await database;
    await db.insert('tags', tag.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  static Future<void> updateTag(SubjectTag tag) async {
    final db = await database;
    await db.update('tags', tag.toMap(), where: 'id = ?', whereArgs: [tag.id]);
  }

  static Future<void> deleteTag(String id) async {
    final db = await database;
    await db.delete('tags', where: 'id = ?', whereArgs: [id]);
  }

  // Sessions
  static Future<List<StudySession>> getSessions({String? tagId, DateTime? from, DateTime? to}) async {
    final db = await database;
    String? where;
    List<dynamic> whereArgs = [];

    final conditions = <String>[];
    if (tagId != null) {
      conditions.add('tagId = ?');
      whereArgs.add(tagId);
    }
    if (from != null) {
      conditions.add('startTime >= ?');
      whereArgs.add(from.millisecondsSinceEpoch);
    }
    if (to != null) {
      conditions.add('startTime <= ?');
      whereArgs.add(to.millisecondsSinceEpoch);
    }
    if (conditions.isNotEmpty) where = conditions.join(' AND ');

    final maps = await db.query(
      'sessions',
      where: where,
      whereArgs: whereArgs.isEmpty ? null : whereArgs,
      orderBy: 'startTime DESC',
    );
    return maps.map(StudySession.fromMap).toList();
  }

  static Future<void> insertSession(StudySession session) async {
    final db = await database;
    await db.insert('sessions', session.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  static Future<void> deleteSession(String id) async {
    final db = await database;
    await db.delete('sessions', where: 'id = ?', whereArgs: [id]);
  }

  static Future<void> deleteAllSessions() async {
    final db = await database;
    await db.delete('sessions');
  }

  static Future<void> deleteAllTags() async {
    final db = await database;
    await db.delete('tags');
  }

  static Future<Map<String, int>> getDailySeconds(DateTime from, DateTime to) async {
    final db = await database;
    final maps = await db.query(
      'sessions',
      where: 'startTime >= ? AND startTime <= ?',
      whereArgs: [from.millisecondsSinceEpoch, to.millisecondsSinceEpoch],
    );
    final result = <String, int>{};
    for (final map in maps) {
      final dt = DateTime.fromMillisecondsSinceEpoch(map['startTime'] as int);
      final key = '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
      result[key] = (result[key] ?? 0) + (map['durationSeconds'] as int);
    }
    return result;
  }

  static Future<Map<String, int>> getSecondsByTag(DateTime from, DateTime to) async {
    final db = await database;
    final maps = await db.query(
      'sessions',
      where: 'startTime >= ? AND startTime <= ?',
      whereArgs: [from.millisecondsSinceEpoch, to.millisecondsSinceEpoch],
    );
    final result = <String, int>{};
    for (final map in maps) {
      final key = map['tagName'] as String;
      result[key] = (result[key] ?? 0) + (map['durationSeconds'] as int);
    }
    return result;
  }
}
