import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class LocalDatabase {
  static final LocalDatabase instance = LocalDatabase._internal();

  static Database? _database;

  LocalDatabase._internal();

  Future<Database> get database async {
    if (_database != null) {
      return _database!;
    }

    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'hydro_surveyor.db');

    return openDatabase(
      path,
      version: 1,
      onCreate: _createDatabase,
    );
  }

  Future<void> _createDatabase(
    Database db,
    int version,
  ) async {
    await db.execute('''
      CREATE TABLE expeditions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        local_id TEXT NOT NULL UNIQUE,
        server_id TEXT,
        name TEXT NOT NULL,
        date_start TEXT NOT NULL,
        date_end TEXT,
        team TEXT,
        location TEXT,
        sync_status TEXT NOT NULL DEFAULT 'LOCAL',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE surveys (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        expedition_id INTEGER NOT NULL,
        local_id TEXT NOT NULL UNIQUE,
        server_id TEXT,
        survey_mode TEXT NOT NULL,
        nama_upt TEXT,
        bidang_seksi TEXT,
        waktu_survey TEXT NOT NULL,
        nama_sungai TEXT,
        latitude REAL NOT NULL,
        longitude REAL NOT NULL,
        altitude_gps REAL NOT NULL,
        nama_penanggung_jawab TEXT,
        nip_penanggung_jawab TEXT,
        river_width_m REAL,
        depth_estimate_m REAL,
        surface_velocity_mps REAL,
        mean_velocity_mps REAL,
        cross_section_area_sqm REAL,
        discharge_cms REAL,
        gross_head_m REAL,
        net_head_m REAL,
        power_output_kw REAL,
        recommended_turbine TEXT,
        sync_status TEXT NOT NULL DEFAULT 'PENDING',
        sync_attempts INTEGER NOT NULL DEFAULT 0,
        last_sync_error TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (expedition_id)
          REFERENCES expeditions(id)
          ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE survey_photos (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        survey_id INTEGER NOT NULL,
        local_path TEXT NOT NULL,
        server_url TEXT,
        photo_type TEXT,
        sync_status TEXT NOT NULL DEFAULT 'PENDING',
        created_at TEXT NOT NULL,
        FOREIGN KEY (survey_id)
          REFERENCES surveys(id)
          ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE survey_videos (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        survey_id INTEGER NOT NULL,
        local_path TEXT NOT NULL,
        server_url TEXT,
        sync_status TEXT NOT NULL DEFAULT 'PENDING',
        created_at TEXT NOT NULL,
        FOREIGN KEY (survey_id)
          REFERENCES surveys(id)
          ON DELETE CASCADE
      )
    ''');
  }

  Future<int> insertExpedition(
    Map<String, Object?> data,
  ) async {
    final db = await database;

    return db.insert(
      'expeditions',
      data,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<int> insertSurvey(
    Map<String, Object?> data,
  ) async {
    final db = await database;

    return db.insert(
      'surveys',
      data,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, Object?>>> getExpeditions() async {
    final db = await database;

    return db.query(
      'expeditions',
      orderBy: 'created_at DESC',
    );
  }

  Future<List<Map<String, Object?>>> getSurveys(
    int expeditionId,
  ) async {
    final db = await database;

    return db.query(
      'surveys',
      where: 'expedition_id = ?',
      whereArgs: [expeditionId],
      orderBy: 'waktu_survey DESC',
    );
  }

  Future<int> updateSurvey(
    int id,
    Map<String, Object?> data,
  ) async {
    final db = await database;

    return db.update(
      'surveys',
      data,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteSurvey(int id) async {
    final db = await database;

    return db.delete(
      'surveys',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<Map<String, Object?>>> getPendingSurveys() async {
    final db = await database;

    return db.query(
      'surveys',
      where: 'sync_status IN (?, ?, ?)',
      whereArgs: [
        'LOCAL',
        'PENDING',
        'FAILED',
      ],
      orderBy: 'created_at ASC',
    );
  }

  Future<void> close() async {
    final db = _database;

    if (db != null) {
      await db.close();
      _database = null;
    }
  }
}
