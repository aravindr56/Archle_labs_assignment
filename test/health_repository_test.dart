import 'package:flutter_test/flutter_test.dart';
import 'package:healthconnect_dashboard/data/local/database_service.dart';
import 'package:healthconnect_dashboard/data/repositories/health_repository_impl.dart';
import 'package:healthconnect_dashboard/data/sources/sim_health_source.dart';
import 'package:healthconnect_dashboard/domain/models/heart_rate_record.dart';
import 'package:healthconnect_dashboard/domain/models/step_record.dart';
import 'package:healthconnect_dashboard/domain/sources/health_data_source.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class MockRealDataSource implements HealthDataSource {
  @override
  Stream<StepRecord> get stepsStream => const Stream.empty();

  @override
  Stream<HeartRateRecord> get heartRateStream => const Stream.empty();

  @override
  Future<HealthPermissionStatus> checkPermissions() async =>
      HealthPermissionStatus.granted;

  @override
  Future<HealthPermissionStatus> requestPermissions() async =>
      HealthPermissionStatus.granted;

  @override
  Future<void> startListening() async {}

  @override
  Future<void> stopListening() async {}

  @override
  void dispose() {}
}

void main() {
  late DatabaseService dbService;
  late HealthRepositoryImpl repository;
  late SimHealthSource simSource;

  setUpAll(() {
    sqfliteFfiInit();
  });

  setUp(() async {
    dbService = await DatabaseService.init(
      path: inMemoryDatabasePath,
      factory: databaseFactoryFfi,
    );
    simSource = SimHealthSource();
    repository = HealthRepositoryImpl(
      realSource: MockRealDataSource(),
      dbService: dbService,
      simSource: simSource,
    );
  });

  tearDown(() async {
    repository.dispose();
    await dbService.close();
  });

  group('HealthRepository and SimSource Tests', () {
    test('SimSource emits deterministic step and heart rate updates', () async {
      final now = DateTime.now().millisecondsSinceEpoch;
      final stepFuture = simSource.stepsStream.first;
      final hrFuture = simSource.heartRateStream.first;

      simSource.emitDeterministicPoint(timestamp: now, steps: 45, bpm: 88);

      final step = await stepFuture;
      final hr = await hrFuture;

      expect(step.count, equals(45));
      expect(hr.bpm, equals(88));
      expect(step.timestamp, equals(now));
    });

    test('Toggling SimSource routes stream and persists to SQLite', () async {
      await repository.setSimSourceActive(true);
      expect(repository.isSimSourceActive, isTrue);

      final now = DateTime.now().millisecondsSinceEpoch;
      final repoStepFuture = repository.stepsStream.first;

      simSource.emitDeterministicPoint(timestamp: now, steps: 120, bpm: 95);

      final receivedStep = await repoStepFuture;
      expect(receivedStep.count, equals(120));

      // Verify persisted to local SQLite
      final todayTotal = await repository.getTodayStepTotal();
      expect(todayTotal, equals(120));

      final latestHr = await repository.getLatestHeartRate();
      expect(latestHr?.bpm, equals(95));
    });

    test('Seeding synthetic data populates database without network', () async {
      await repository.seedSyntheticData();
      final total = await repository.getTodayStepTotal();
      final latestHr = await repository.getLatestHeartRate();

      expect(total, greaterThan(0));
      expect(latestHr, isNotNull);
      expect(latestHr!.bpm, inInclusiveRange(50, 180));
    });
  });
}
