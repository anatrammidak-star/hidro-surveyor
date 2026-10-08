import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class LocalDatabase {
  LocalDatabase._();

  static final LocalDatabase instance = LocalDatabase._();

  static const int _databaseVersion = 3;
  static const String _databaseName = 'hydro_surveyor.db';

  Database? _db;

  Future<Database> get database async {
    if (_db != null) {
      return _db!;
    }

    final dbPath = await getDatabasesPath();

    _db = await openDatabase(
      join(dbPath, _databaseName),
      version: _databaseVersion,

      // =========================================================
      // DATABASE BARU
      // =========================================================
      onCreate: (db, version) async {
        await _createDatabase(db);
      },

      // =========================================================
      // MIGRATION DATABASE LAMA
      // =========================================================
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await _migrateV1ToV2(db);
        }

        if (oldVersion < 3) {
          await _migrateV2ToV3(db);
        }
      },
    );

    return _db!;
  }

  // =============================================================
  // CREATE DATABASE V3
  // =============================================================

  Future<void> _createDatabase(Database db) async {
    await db.execute('''
      CREATE TABLE expeditions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        local_id TEXT NOT NULL UNIQUE,
        server_id TEXT,

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
        server_id TEXT,

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

        -- =====================================================
        -- FIELD CORRECTION INPUT
        -- =====================================================

        river_width_m REAL,
        depth_estimate_m REAL,
        surface_velocity_mps REAL,

        -- =====================================================
        -- DERIVED / LEGACY CALCULATION
        -- =====================================================

        mean_velocity_mps REAL,
        cross_section_area_sqm REAL,
        discharge_cms REAL,

        gross_head_m REAL,
        net_head_m REAL,
        power_output_kw REAL,

        recommended_turbine TEXT,

        -- =====================================================
        -- AI / VISUAL PREDICTION
        -- =====================================================

        visual_discharge_min_cms REAL,
        visual_discharge_cms REAL,
        visual_discharge_max_cms REAL,

        visual_head_min_m REAL,
        visual_head_m REAL,
        visual_head_max_m REAL,

        visual_power_min_kw REAL,
        visual_power_kw REAL,
        visual_power_max_kw REAL,

        -- =====================================================
        -- FIELD CORRECTED / PRECISION ESTIMATION
        -- =====================================================

        corrected_discharge_min_cms REAL,
        corrected_discharge_cms REAL,
        corrected_discharge_max_cms REAL,

        corrected_head_min_m REAL,
        corrected_head_m REAL,
        corrected_head_max_m REAL,

        corrected_power_min_kw REAL,
        corrected_power_kw REAL,
        corrected_power_max_kw REAL,

        -- =====================================================
        -- AI METADATA
        -- =====================================================

        ai_status TEXT,
        ai_model_version TEXT,
        ai_quality_score REAL,
        ai_processed_at TEXT,
        ai_notes TEXT,
        ai_evidence_count INTEGER,

        -- =====================================================
        -- REFERENCE / PRECISION
        -- =====================================================

        reference_used TEXT,
        precision_level TEXT,

        -- =====================================================
        -- CORRECTION FACTORS
        -- =====================================================

        surface_velocity_factor REAL,
        head_loss_factor REAL,
        turbine_efficiency REAL,

        correction_profile TEXT,

        -- =====================================================
        -- GENERAL ESTIMATION STATUS
        -- =====================================================

        estimation_method TEXT,
        confidence_level TEXT,
        documentation_status TEXT,

        -- =====================================================
        -- SYNCHRONIZATION
        -- =====================================================

        sync_status TEXT NOT NULL DEFAULT 'PENDING',
        sync_attempts INTEGER NOT NULL DEFAULT 0,
        last_sync_error TEXT,

        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,

        FOREIGN KEY(expedition_id)
          REFERENCES expeditions(id)
      )
    ''');

    await db.execute('''
      CREATE INDEX idx_surveys_expedition
      ON surveys(expedition_id)
    ''');

    await db.execute('''
      CREATE INDEX idx_surveys_sync
      ON surveys(sync_status)
    ''');

    await db.execute('''
      CREATE INDEX idx_surveys_ai_status
      ON surveys(ai_status)
    ''');

    await db.execute('''
      CREATE TABLE survey_media (
        id INTEGER PRIMARY KEY AUTOINCREMENT,

        survey_id INTEGER NOT NULL,

        media_type TEXT NOT NULL,
        local_path TEXT NOT NULL,
        server_url TEXT,

        sync_status TEXT NOT NULL DEFAULT 'PENDING',

        created_at TEXT NOT NULL,

        FOREIGN KEY(survey_id)
          REFERENCES surveys(id)
      )
    ''');

    await db.execute('''
      CREATE INDEX idx_survey_media_survey
      ON survey_media(survey_id)
    ''');

    await db.execute('''
      CREATE INDEX idx_survey_media_sync
      ON survey_media(sync_status)
    ''');
  }

  // =============================================================
  // MIGRATION V1 -> V2
  // =============================================================

  Future<void> _migrateV1ToV2(Database db) async {
    await db.transaction((txn) async {
      await txn.execute('''
        CREATE TABLE surveys_v2 (
          id INTEGER PRIMARY KEY AUTOINCREMENT,

          expedition_id INTEGER NOT NULL,
          local_id TEXT NOT NULL UNIQUE,
          server_id TEXT,

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

          visual_discharge_cms REAL,
          visual_head_m REAL,
          visual_power_kw REAL,

          corrected_discharge_cms REAL,
          corrected_head_m REAL,
          corrected_power_kw REAL,

          estimation_method TEXT,
          confidence_level TEXT,

          documentation_status TEXT,

          sync_status TEXT NOT NULL DEFAULT 'PENDING',
          sync_attempts INTEGER NOT NULL DEFAULT 0,
          last_sync_error TEXT,

          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL,

          FOREIGN KEY(expedition_id)
            REFERENCES expeditions(id)
        )
      ''');

      await txn.execute('''
        INSERT INTO surveys_v2 (
          id,
          expedition_id,
          local_id,
          server_id,

          survey_mode,

          nama_upt,
          bidang_seksi,
          waktu_survey,
          nama_sungai,

          latitude,
          longitude,
          altitude_gps,

          nama_penanggung_jawab,
          nip_penanggung_jawab,

          river_width_m,
          depth_estimate_m,
          surface_velocity_mps,

          mean_velocity_mps,
          cross_section_area_sqm,
          discharge_cms,

          gross_head_m,
          net_head_m,
          power_output_kw,
          recommended_turbine,

          visual_discharge_cms,
          visual_head_m,
          visual_power_kw,

          corrected_discharge_cms,
          corrected_head_m,
          corrected_power_kw,

          estimation_method,
          confidence_level,
          documentation_status,

          sync_status,
          sync_attempts,
          last_sync_error,

          created_at,
          updated_at
        )
        SELECT
          id,
          expedition_id,
          local_id,
          NULL,

          survey_mode,

          nama_upt,
          bidang_seksi,
          waktu_survey,
          nama_sungai,

          latitude,
          longitude,
          altitude_gps,

          nama_penanggung_jawab,
          nip_penanggung_jawab,

          river_width_m,
          depth_estimate_m,
          surface_velocity_mps,

          mean_velocity_mps,
          cross_section_area_sqm,
          discharge_cms,

          gross_head_m,
          net_head_m,
          power_output_kw,
          recommended_turbine,

          NULL,
          NULL,
          NULL,

          discharge_cms,
          gross_head_m,
          power_output_kw,

          'MANUAL_LEGACY',
          'LEGACY',
          'LEGACY',

          sync_status,
          sync_attempts,
          last_sync_error,

          created_at,
          updated_at
        FROM surveys
      ''');

      await txn.execute('DROP TABLE surveys');

      await txn.execute(
        'ALTER TABLE surveys_v2 RENAME TO surveys',
      );

      await txn.execute('''
        CREATE INDEX idx_surveys_expedition
        ON surveys(expedition_id)
      ''');

      await txn.execute('''
        CREATE INDEX idx_surveys_sync
        ON surveys(sync_status)
      ''');

      await txn.execute(
        'ALTER TABLE expeditions ADD COLUMN server_id TEXT',
      );

      await txn.execute(
        'ALTER TABLE survey_media ADD COLUMN server_url TEXT',
      );

      await txn.execute('''
        CREATE INDEX IF NOT EXISTS idx_survey_media_survey
        ON survey_media(survey_id)
      ''');

      await txn.execute('''
        CREATE INDEX IF NOT EXISTS idx_survey_media_sync
        ON survey_media(sync_status)
      ''');
    });
  }

  // =============================================================
  // MIGRATION V2 -> V3
  // =============================================================

  Future<void> _migrateV2ToV3(Database db) async {
    await db.transaction((txn) async {
      await txn.execute(
        'ALTER TABLE surveys '
        'ADD COLUMN visual_discharge_min_cms REAL',
      );

      await txn.execute(
        'ALTER TABLE surveys '
        'ADD COLUMN visual_discharge_max_cms REAL',
      );

      await txn.execute(
        'ALTER TABLE surveys '
        'ADD COLUMN visual_head_min_m REAL',
      );

      await txn.execute(
        'ALTER TABLE surveys '
        'ADD COLUMN visual_head_max_m REAL',
      );

      await txn.execute(
        'ALTER TABLE surveys '
        'ADD COLUMN visual_power_min_kw REAL',
      );

      await txn.execute(
        'ALTER TABLE surveys '
        'ADD COLUMN visual_power_max_kw REAL',
      );

      await txn.execute(
        'ALTER TABLE surveys '
        'ADD COLUMN corrected_discharge_min_cms REAL',
      );

      await txn.execute(
        'ALTER TABLE surveys '
        'ADD COLUMN corrected_discharge_max_cms REAL',
      );

      await txn.execute(
        'ALTER TABLE surveys '
        'ADD COLUMN corrected_head_min_m REAL',
      );

      await txn.execute(
        'ALTER TABLE surveys '
        'ADD COLUMN corrected_head_max_m REAL',
      );

      await txn.execute(
        'ALTER TABLE surveys '
        'ADD COLUMN corrected_power_min_kw REAL',
      );

      await txn.execute(
        'ALTER TABLE surveys '
        'ADD COLUMN corrected_power_max_kw REAL',
      );

      await txn.execute(
        'ALTER TABLE surveys '
        'ADD COLUMN ai_status TEXT',
      );

      await txn.execute(
        'ALTER TABLE surveys '
        'ADD COLUMN ai_model_version TEXT',
      );

      await txn.execute(
        'ALTER TABLE surveys '
        'ADD COLUMN ai_quality_score REAL',
      );

      await txn.execute(
        'ALTER TABLE surveys '
        'ADD COLUMN ai_processed_at TEXT',
      );

      await txn.execute(
        'ALTER TABLE surveys '
        'ADD COLUMN ai_notes TEXT',
      );

      await txn.execute(
        'ALTER TABLE surveys '
        'ADD COLUMN ai_evidence_count INTEGER',
      );

      await txn.execute(
        'ALTER TABLE surveys '
        'ADD COLUMN reference_used TEXT',
      );

      await txn.execute(
        'ALTER TABLE surveys '
        'ADD COLUMN precision_level TEXT',
      );

      await txn.execute(
        'ALTER TABLE surveys '
        'ADD COLUMN surface_velocity_factor REAL',
      );

      await txn.execute(
        'ALTER TABLE surveys '
        'ADD COLUMN head_loss_factor REAL',
      );

      await txn.execute(
        'ALTER TABLE surveys '
        'ADD COLUMN turbine_efficiency REAL',
      );

      await txn.execute(
        'ALTER TABLE surveys '
        'ADD COLUMN correction_profile TEXT',
      );

      await txn.execute('''
        CREATE INDEX IF NOT EXISTS idx_surveys_ai_status
        ON surveys(ai_status)
      ''');
    });
  }

  // =============================================================
  // EXPEDITION
  // =============================================================

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

    final now =
        DateTime.now().toIso8601String();

    return db.insert(
      'expeditions',
      {
        'local_id': localId,
        'name': name,
        'date_start':
            dateStart.toIso8601String(),
        'date_end': dateEnd,
        'team': team,
        'location': location,
        'notes': notes,
        'sync_status': 'PENDING',
        'created_at': now,
        'updated_at': now,
      },
    );
  }

  Future<List<Map<String, Object?>>>
      getExpeditions() async {
    final db = await database;

    return db.query(
      'expeditions',
      orderBy:
          'date_start DESC, id DESC',
    );
  }

  Future<Map<String, Object?>?>
      getExpedition(int id) async {
    final db = await database;

    final rows = await db.query(
      'expeditions',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    return rows.isEmpty
        ? null
        : rows.first;
  }

  // =============================================================
  // SURVEY
  // =============================================================

  Future<int> insertSurvey(
    Map<String, Object?> values,
  ) async {
    final db = await database;

    return db.insert(
      'surveys',
      values,
    );
  }

  Future<List<Map<String, Object?>>>
      getSurveysForExpedition(
    int expeditionId,
  ) async {
    final db = await database;

    return db.query(
      'surveys',
      where: 'expedition_id = ?',
      whereArgs: [expeditionId],
      orderBy:
          'waktu_survey ASC, id ASC',
    );
  }

  Future<Map<String, Object?>?>
      getSurvey(int id) async {
    final db = await database;

    final rows = await db.query(
      'surveys',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    return rows.isEmpty
        ? null
        : rows.first;
  }

  // =============================================================
  // MEDIA
  // =============================================================

  Future<int> insertMedia({
    required int surveyId,
    required String mediaType,
    required String localPath,
  }) async {
    final db = await database;

    return db.insert(
      'survey_media',
      {
        'survey_id': surveyId,
        'media_type': mediaType,
        'local_path': localPath,
        'sync_status': 'PENDING',
        'created_at':
            DateTime.now().toIso8601String(),
      },
    );
  }

  Future<List<Map<String, Object?>>>
      getMediaForSurvey(
    int surveyId,
  ) async {
    final db = await database;

    return db.query(
      'survey_media',
      where: 'survey_id = ?',
      whereArgs: [surveyId],
      orderBy: 'id ASC',
    );
  }

  // =============================================================
  // STATISTICS
  // =============================================================

  Future<int> countPending() async {
    final db = await database;

    final result = await db.rawQuery(
      "SELECT COUNT(*) AS c "
      "FROM surveys "
      "WHERE sync_status != 'SYNCED'",
    );

    return Sqflite.firstIntValue(
          result,
        ) ??
        0;
  }

    Future<int> countSurveys() async {
    final db = await database;

    final result = await db.rawQuery(
      'SELECT COUNT(*) AS c '
      'FROM surveys',
    );

    return Sqflite.firstIntValue(
          result,
        ) ??
        0;
  }

  Future<int> countSurveysForExpedition(int expeditionId) async {
    final db = await database;

    final result = await db.rawQuery(
      'SELECT COUNT(*) AS c '
      'FROM surveys '
      'WHERE expedition_id = ?',
      [expeditionId],
    );

    return Sqflite.firstIntValue(
          result,
        ) ??
        0;
  }

  Future<int> countPendingMedia() async {
    final db = await database;

    final result = await db.rawQuery(
      "SELECT COUNT(*) AS c "
      "FROM survey_media "
      "WHERE sync_status != 'SYNCED'",
    );

    return Sqflite.firstIntValue(
          result,
        ) ??
        0;
  }

  // =============================================================
  // CLOSE
  // =============================================================

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}
