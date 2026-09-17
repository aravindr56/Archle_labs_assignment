import 'package:flutter_test/flutter_test.dart';
import 'package:healthconnect_dashboard/data/local/database_service.dart';
import 'package:healthconnect_dashboard/domain/models/heart_rate_record.dart';
import 'package:healthconnect_dashboard/domain/models/step_record.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late DatabaseService dbService;

  setUpAll(() {
    // Initialize FFI for headless desktop/unit testing
    sqfliteFfiInit();
  });

  setUp(() async {
    final factory = databaseFactoryFfi;
    dbService = await DatabaseService.init(
      path: inMemoryDatabasePath,
      factory: factory,
    );
  });

  tearDown(() async {
    await dbService.close();
  });

  group('DatabaseService Tests', () {
    test('inserts and queries raw steps and raw HR records', () async {
      final now = DateTime.now();
      final ts = now.millisecondsSinceEpoch;

      await dbService.insertStep(StepRecord(timestamp: ts, count: 120));
      await dbService.insertHeartRate(HeartRateRecord(timestamp: ts, bpm: 75));

      final steps = await dbService.getRawStepsSince(ts - 1000);
      final hr = await dbService.getRawHeartRateSince(ts - 1000);

      expect(steps.length, equals(1));
      expect(steps.first.count, equals(120));

      expect(hr.length, equals(1));
      expect(hr.first.bpm, equals(75));
    });

    test('computes today step total and latest heart rate correctly', () async {
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day, 1);

      await dbService.insertStepsBatch([
        StepRecord(timestamp: startOfDay.millisecondsSinceEpoch, count: 500),
        StepRecord(
            timestamp: startOfDay.add(const Duration(hours: 2)).millisecondsSinceEpoch,
            count: 750),
      ]);

      await dbService.insertHeartRateBatch([
        HeartRateRecord(timestamp: startOfDay.millisecondsSinceEpoch, bpm: 68),
        HeartRateRecord(
            timestamp: startOfDay.add(const Duration(minutes: 30)).millisecondsSinceEpoch,
            bpm: 82),
      ]);

      final total = await dbService.getTodayStepTotal(now: now);
      final latestHr = await dbService.getLatestHeartRate();

      expect(total, equals(1250));
      expect(latestHr?.bpm, equals(82));
    });

    test('computes and saves hourly rollup with p95 and average', () async {
      final testHour = DateTime(2026, 9, 17, 10, 0, 0);

      // Insert 10 HR records in this hour: 60, 65, 70, 75, 80, 85, 90, 95, 100, 110
      final List<HeartRateRecord> hrList = [];
      final bpms = [60, 65, 70, 75, 80, 85, 90, 95, 100, 110];
      for (int i = 0; i < bpms.length; i++) {
        hrList.add(HeartRateRecord(
          timestamp: testHour.add(Duration(minutes: i * 5)).millisecondsSinceEpoch,
          bpm: bpms[i],
        ));
      }
      await dbService.insertHeartRateBatch(hrList);

      await dbService.insertStep(StepRecord(
        timestamp: testHour.add(const Duration(minutes: 15)).millisecondsSinceEpoch,
        count: 340,
      ));

      await dbService.computeAndSaveHourlyRollup(testHour);

      final query = await dbService.database.query('agg_hourly');
      expect(query.length, equals(1));
      expect(query.first['steps'], equals(340));
      expect(query.first['hr_avg'], equals(83)); // sum=830 / 10 = 83
      expect(query.first['hr_p95'], equals(110));
    });

    test('retention compaction purges raw > 7 days and aggregates > 30 days',
        () async {
      final now = DateTime(2026, 9, 17, 12, 0, 0);

      // Raw record 8 days old (should be purged)
      final oldRawTs = now.subtract(const Duration(days: 8)).millisecondsSinceEpoch;
      await dbService.insertStep(StepRecord(timestamp: oldRawTs, count: 50));
      await dbService.insertHeartRate(HeartRateRecord(timestamp: oldRawTs, bpm: 70));

      // Raw record 2 days old (should be kept)
      final recentRawTs = now.subtract(const Duration(days: 2)).millisecondsSinceEpoch;
      await dbService.insertStep(StepRecord(timestamp: recentRawTs, count: 100));
      await dbService.insertHeartRate(HeartRateRecord(timestamp: recentRawTs, bpm: 72));

      // Aggregate 35 days old (should be purged)
      await dbService.database.insert('agg_daily', {
        'date': '2026-08-01',
        'steps': 5000,
        'zone2_mins': 20,
        'active_mins': 40,
        'hit_target': 0,
      });

      // Aggregate 10 days old (should be kept)
      await dbService.database.insert('agg_daily', {
        'date': '2026-09-07',
        'steps': 9000,
        'zone2_mins': 45,
        'active_mins': 60,
        'hit_target': 1,
      });

      final result = await dbService.runRetentionCompaction(now: now);

      expect(result['deleted_steps_raw'], equals(1));
      expect(result['deleted_hr_raw'], equals(1));
      expect(result['deleted_agg_daily'], equals(1));

      // Verify remaining records
      final remainingSteps = await dbService.getRawStepsSince(0);
      expect(remainingSteps.length, equals(1));
      expect(remainingSteps.first.count, equals(100));

      final remainingAgg = await dbService.database.query('agg_daily');
      expect(remainingAgg.length, equals(1));
      expect(remainingAgg.first['date'], equals('2026-09-07'));
    });

    test('key-value store writes and reads data', () async {
      await dbService.setKV('health_connect_changes_token', 'token_xyz_123');
      final value = await dbService.getKV('health_connect_changes_token');
      expect(value, equals('token_xyz_123'));
    });
  });
}
