import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class LocalDatabase {
  LocalDatabase._();
  static final LocalDatabase instance = LocalDatabase._();

  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;

    final dbPath = await getDatabasesPath();

    _db = await openDatabase(
      join(dbPath, 'hydro_surveyor.db'),
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE expeditions (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            local_id TEXT NOT NULL UNIQUE,
            name TEXT NOT NULL,
            date_start TEXT NOT NULL,
            date_end TEXT,
            team TEXT NOT NULL,
            location TEXT,
            notes TEXT,
            sync_status TEXT NOT NULL DEFAULT 'PENDING',
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL
          )
        ''');

        await db.execute('''
          CREATE TABLE surveys (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            expedition_id INTEGER NOT NULL,
            local_id TEXT NOT NULL UNIQUE,
            survey_mode TEXT NOT NULL,
            nama_upt TEXT NOT NULL,
            bidang_seksi TEXT NOT NULL,
            waktu_survey TEXT NOT NULL,
            nama_sungai TEXT NOT NULL,
            latitude REAL NOT NULL,
            longitude REAL NOT NULL,
            altitude_gps REAL NOT NULL,
            nama_penanggung_jawab TEXT NOT NULL,
            nip_penanggung_jawab TEXT NOT NULL,
            river_width_m REAL NOT NULL,
            depth_estimate_m REAL NOT NULL,
            surface_velocity_mps REAL NOT NULL,
            mean_velocity_mps REAL NOT NULL,
            cross_section_area_sqm REAL NOT NULL,
            discharge_cms REAL NOT NULL,
            gross_head_m REAL,
            net_head_m REAL,
            power_output_kw REAL,
            recommended_turbine TEXT,
            sync_status TEXT NOT NULL DEFAULT 'PENDING',
            sync_attempts INTEGER NOT NULL DEFAULT 0,
            last_sync_error TEXT,
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL,
            FOREIGN KEY(expedition_id) REFERENCES expeditions(id)
          )
        ''');

        await db.execute(
          'CREATE INDEX idx_surveys_expedition '
          'ON surveys(expedition_id)',
        );

        await db.execute(
          'CREATE INDEX idx_surveys_sync '
          'ON surveys(sync_status)',
        );

        await db.execute('''
          CREATE TABLE survey_media (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            survey_id INTEGER NOT NULL,
            media_type TEXT NOT NULL,
            local_path TEXT NOT NULL,
            sync_status TEXT NOT NULL DEFAULT 'PENDING',
            created_at TEXT NOT NULL,
            FOREIGN KEY(survey_id) REFERENCES surveys(id)
          )
        ''');
      },
    );

    return _db!;
  }

  Future<int> createExpedition({
    required String localId,
    required String name,
    required DateTime dateStart,
    String? dateEnd,
    required String team,
    String? location,
    String? notes,
  }) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();

    return db.insert('expeditions', {
      'local_id': localId,
      'name': name,
      'date_start': dateStart.toIso8601String(),
      'date_end': dateEnd,
      'team': team,
      'location': location,
      'notes': notes,
      'sync_status': 'PENDING',
      'created_at': now,
      'updated_at': now,
    });
  }

  Future<List<Map<String, Object?>>> getExpeditions() async {
    final db = await database;

    return db.query(
      'expeditions',
      orderBy: 'date_start DESC, id DESC',
    );
  }

  Future<Map<String, Object?>?> getExpedition(int id) async {
    final db = await database;

    final rows = await db.query(
      'expeditions',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    return rows.isEmpty ? null : rows.first;
  }

  Future<int> insertSurvey(
    Map<String, Object?> values,
  ) async {
    final db = await database;

    return db.insert('surveys', values);
  }

  Future<List<Map<String, Object?>>> getSurveysForExpedition(
    int expeditionId,
  ) async {
    final db = await database;

    return db.query(
      'surveys',
      where: 'expedition_id = ?',
      whereArgs: [expeditionId],
      orderBy: 'waktu_survey ASC, id ASC',
    );
  }

  Future<Map<String, Object?>?> getSurvey(int id) async {
    final db = await database;

    final rows = await db.query(
      'surveys',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    return rows.isEmpty ? null : rows.first;
  }

  Future<int> insertMedia({
    required int surveyId,
    required String mediaType,
    required String localPath,
  }) async {
    final db = await database;

    return db.insert('survey_media', {
      'survey_id': surveyId,
      'media_type': mediaType,
      'local_path': localPath,
      'sync_status': 'PENDING',
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<int> countPending() async {
    final db = await database;

    final result = await db.rawQuery(
      "SELECT COUNT(*) AS c FROM surveys "
      "WHERE sync_status != 'SYNCED'",
    );

    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<int> countSurveys() async {
    final db = await database;

    final result = await db.rawQuery(
      'SELECT COUNT(*) AS c FROM surveys',
    );

    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}
