import 'package:intl/intl.dart';
import 'package:sqflite/sqflite.dart';
import '../../domain/models/aggregates.dart';
import '../../domain/models/heart_rate_record.dart';
import '../../domain/models/step_record.dart';

class DatabaseService {
  final Database _db;

  DatabaseService(this._db);

  static Future<DatabaseService> init({
    required String path,
    DatabaseFactory? factory,
  }) async {
    final dbFactory = factory ?? databaseFactory;
    final db = await dbFactory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, version) async {
          await createTables(db);
        },
      ),
    );
    return DatabaseService(db);
  }

  static Future<void> createTables(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS steps_raw (
        ts INTEGER PRIMARY KEY,
        count INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS hr_raw (
        ts INTEGER PRIMARY KEY,
        bpm INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS agg_hourly (
        date TEXT NOT NULL,
        hour INTEGER NOT NULL,
        steps INTEGER NOT NULL,
        hr_avg INTEGER NOT NULL,
        hr_p95 INTEGER NOT NULL,
        PRIMARY KEY (date, hour)
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS agg_daily (
        date TEXT PRIMARY KEY,
        steps INTEGER NOT NULL,
        zone2_mins INTEGER NOT NULL,
        active_mins INTEGER NOT NULL,
        hit_target INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS kv (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');
  }

  Database get database => _db;

  // --- RAW INSERTS & QUERIES ---

  Future<void> insertStep(StepRecord record) async {
    await _db.insert(
      'steps_raw',
      record.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> insertStepsBatch(List<StepRecord> records) async {
    if (records.isEmpty) return;
    final batch = _db.batch();
    for (final rec in records) {
      batch.insert(
        'steps_raw',
        rec.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<void> insertHeartRate(HeartRateRecord record) async {
    await _db.insert(
      'hr_raw',
      record.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> insertHeartRateBatch(List<HeartRateRecord> records) async {
    if (records.isEmpty) return;
    final batch = _db.batch();
    for (final rec in records) {
      batch.insert(
        'hr_raw',
        rec.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<List<StepRecord>> getRawStepsSince(int startEpochMs) async {
    final res = await _db.query(
      'steps_raw',
      where: 'ts >= ?',
      whereArgs: [startEpochMs],
      orderBy: 'ts ASC',
    );
    return res.map((m) => StepRecord.fromMap(m)).toList();
  }

  Future<List<HeartRateRecord>> getRawHeartRateSince(int startEpochMs) async {
    final res = await _db.query(
      'hr_raw',
      where: 'ts >= ?',
      whereArgs: [startEpochMs],
      orderBy: 'ts ASC',
    );
    return res.map((m) => HeartRateRecord.fromMap(m)).toList();
  }

  Future<int> getTodayStepTotal({DateTime? now}) async {
    final targetDate = now ?? DateTime.now();
    final startOfDay = DateTime(targetDate.year, targetDate.month, targetDate.day);
    final res = await _db.rawQuery(
      'SELECT SUM(count) as total FROM steps_raw WHERE ts >= ?',
      [startOfDay.millisecondsSinceEpoch],
    );
    if (res.isNotEmpty && res.first['total'] != null) {
      return (res.first['total'] as num).toInt();
    }
    return 0;
  }

  Future<HeartRateRecord?> getLatestHeartRate() async {
    final res = await _db.query(
      'hr_raw',
      orderBy: 'ts DESC',
      limit: 1,
    );
    if (res.isNotEmpty) {
      return HeartRateRecord.fromMap(res.first);
    }
    return null;
  }

  // --- AGGREGATIONS (HOURLY & DAILY) ---

  Future<void> computeAndSaveHourlyRollup(DateTime dt) async {
    final dateStr = DateFormat('yyyy-MM-dd').format(dt);
    final hour = dt.hour;
    final startOfHour = DateTime(dt.year, dt.month, dt.day, hour).millisecondsSinceEpoch;
    final endOfHour = startOfHour + (3600 * 1000) - 1;

    // Steps sum
    final stepsRes = await _db.rawQuery(
      'SELECT SUM(count) as total FROM steps_raw WHERE ts >= ? AND ts <= ?',
      [startOfHour, endOfHour],
    );
    final steps = stepsRes.isNotEmpty && stepsRes.first['total'] != null
        ? (stepsRes.first['total'] as num).toInt()
        : 0;

    // HR avg and p95
    final hrRes = await _db.query(
      'hr_raw',
      columns: ['bpm'],
      where: 'ts >= ? AND ts <= ?',
      whereArgs: [startOfHour, endOfHour],
      orderBy: 'bpm ASC',
    );

    int hrAvg = 0;
    int hrP95 = 0;
    if (hrRes.isNotEmpty) {
      final bpms = hrRes.map((r) => r['bpm'] as int).toList();
      final sum = bpms.reduce((a, b) => a + b);
      hrAvg = (sum / bpms.length).round();
      final p95Idx = ((bpms.length - 1) * 0.95).round();
      hrP95 = bpms[p95Idx];
    }

    final agg = HourlyAggregate(
      date: dateStr,
      hour: hour,
      steps: steps,
      hrAvg: hrAvg,
      hrP95: hrP95,
    );

    await _db.insert(
      'agg_hourly',
      agg.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> computeAndSaveDailyRollup(DateTime dt, {int stepTarget = 8000}) async {
    final dateStr = DateFormat('yyyy-MM-dd').format(dt);
    final startOfDay = DateTime(dt.year, dt.month, dt.day).millisecondsSinceEpoch;
    final endOfDay = startOfDay + (86400 * 1000) - 1;

    final stepsRes = await _db.rawQuery(
      'SELECT SUM(count) as total FROM steps_raw WHERE ts >= ? AND ts <= ?',
      [startOfDay, endOfDay],
    );
    final totalSteps = stepsRes.isNotEmpty && stepsRes.first['total'] != null
        ? (stepsRes.first['total'] as num).toInt()
        : 0;

    // Heart rate zone2 (100 - 140 bpm) approximate active time in minutes
    final zone2Res = await _db.rawQuery(
      'SELECT COUNT(DISTINCT ts / 60000) as zone2_mins FROM hr_raw WHERE ts >= ? AND ts <= ? AND bpm >= 100 AND bpm <= 140',
      [startOfDay, endOfDay],
    );
    final zone2Mins = zone2Res.isNotEmpty && zone2Res.first['zone2_mins'] != null
        ? (zone2Res.first['zone2_mins'] as num).toInt()
        : 0;

    final activeRes = await _db.rawQuery(
      'SELECT COUNT(DISTINCT ts / 60000) as active_mins FROM steps_raw WHERE ts >= ? AND ts <= ? AND count >= 30',
      [startOfDay, endOfDay],
    );
    final activeMins = activeRes.isNotEmpty && activeRes.first['active_mins'] != null
        ? (activeRes.first['active_mins'] as num).toInt()
        : 0;

    final agg = DailyAggregate(
      date: dateStr,
      steps: totalSteps,
      zone2Mins: zone2Mins,
      activeMins: activeMins,
      hitTarget: totalSteps >= stepTarget,
    );

    await _db.insert(
      'agg_daily',
      agg.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // --- RETENTION & COMPACTION (7 days raw, 30 days aggregates) ---

  Future<Map<String, int>> runRetentionCompaction({DateTime? now}) async {
    final refTime = now ?? DateTime.now();

    // 7 days raw retention
    final sevenDaysAgoMs = refTime
        .subtract(const Duration(days: 7))
        .millisecondsSinceEpoch;

    final deletedSteps = await _db.delete(
      'steps_raw',
      where: 'ts < ?',
      whereArgs: [sevenDaysAgoMs],
    );

    final deletedHr = await _db.delete(
      'hr_raw',
      where: 'ts < ?',
      whereArgs: [sevenDaysAgoMs],
    );

    // 30 days aggregate retention
    final thirtyDaysAgoDate = DateFormat('yyyy-MM-dd').format(
      refTime.subtract(const Duration(days: 30)),
    );

    final deletedAggHourly = await _db.delete(
      'agg_hourly',
      where: 'date < ?',
      whereArgs: [thirtyDaysAgoDate],
    );

    final deletedAggDaily = await _db.delete(
      'agg_daily',
      where: 'date < ?',
      whereArgs: [thirtyDaysAgoDate],
    );

    await setKV('last_compaction_ts', refTime.millisecondsSinceEpoch.toString());

    return {
      'deleted_steps_raw': deletedSteps,
      'deleted_hr_raw': deletedHr,
      'deleted_agg_hourly': deletedAggHourly,
      'deleted_agg_daily': deletedAggDaily,
    };
  }

  // --- KEY-VALUE STORE ---

  Future<void> setKV(String key, String value) async {
    await _db.insert(
      'kv',
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<String?> getKV(String key) async {
    final res = await _db.query(
      'kv',
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );
    if (res.isNotEmpty) {
      return res.first['value'] as String?;
    }
    return null;
  }

  Future<void> clearAll() async {
    await _db.delete('steps_raw');
    await _db.delete('hr_raw');
    await _db.delete('agg_hourly');
    await _db.delete('agg_daily');
    await _db.delete('kv');
  }

  Future<void> close() async {
    await _db.close();
  }
}
