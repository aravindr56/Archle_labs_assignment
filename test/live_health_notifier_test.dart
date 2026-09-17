import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthconnect_dashboard/domain/models/heart_rate_record.dart';
import 'package:healthconnect_dashboard/domain/models/step_record.dart';
import 'package:healthconnect_dashboard/domain/repositories/health_repository.dart';
import 'package:healthconnect_dashboard/domain/sources/health_data_source.dart';
import 'package:healthconnect_dashboard/presentation/providers/live_health_notifier.dart';

class MockHealthRepositoryForNotifier implements HealthRepository {
  final _stepsCtrl = StreamController<StepRecord>.broadcast();
  final _hrCtrl = StreamController<HeartRateRecord>.broadcast();
  int initialSteps = 1000;
  HeartRateRecord? initialHr = HeartRateRecord(timestamp: 1700000000000, bpm: 72);

  @override
  Stream<StepRecord> get stepsStream => _stepsCtrl.stream;

  @override
  Stream<HeartRateRecord> get heartRateStream => _hrCtrl.stream;

  @override
  Future<int> getTodayStepTotal() async => initialSteps;

  @override
  Future<HeartRateRecord?> getLatestHeartRate() async => initialHr;

  @override
  Future<List<StepRecord>> getRecentSteps({Duration window = const Duration(minutes: 60)}) async => [];

  @override
  Future<List<HeartRateRecord>> getRecentHeartRates({Duration window = const Duration(minutes: 60)}) async => [];

  @override
  Future<HealthPermissionStatus> checkPermissions() async => HealthPermissionStatus.granted;

  @override
  Future<HealthPermissionStatus> requestPermissions() async => HealthPermissionStatus.granted;

  @override
  Future<void> startListening() async {}

  @override
  Future<void> stopListening() async {}

  @override
  Future<void> setSimSourceActive(bool active) async {}

  @override
  bool get isSimSourceActive => false;

  @override
  Future<void> seedSyntheticData() async {}

  @override
  Future<Map<String, int>> runCompaction() async => {};

  @override
  void dispose() {
    _stepsCtrl.close();
    _hrCtrl.close();
  }
}

void main() {
  group('LiveHealthNotifier & Realtime Coalescing Tests', () {
    late MockHealthRepositoryForNotifier repo;
    late LiveHealthNotifier notifier;

    setUp(() {
      repo = MockHealthRepositoryForNotifier();
      notifier = LiveHealthNotifier(repo);
    });

    tearDown(() {
      notifier.dispose();
      repo.dispose();
    });

    test('initializes with repository data', () async {
      await Future.delayed(const Duration(milliseconds: 50));
      expect(notifier.state.todaySteps, equals(1000));
      expect(notifier.state.latestHeartRate?.bpm, equals(72));
    });

    test('coalesces rapid stream updates and updates state after flush', () async {
      await Future.delayed(const Duration(milliseconds: 50));

      final now = DateTime.now().millisecondsSinceEpoch;

      // Emit multiple bursts rapidly
      repo._stepsCtrl.add(StepRecord(timestamp: now, count: 20));
      repo._stepsCtrl.add(StepRecord(timestamp: now + 10, count: 30));
      repo._hrCtrl.add(HeartRateRecord(timestamp: now + 10, bpm: 85));

      // Before coalesce timer fires (250ms), state shouldn't thrash immediately
      expect(notifier.state.todaySteps, equals(1000));

      // Wait for coalesce flush
      await Future.delayed(const Duration(milliseconds: 300));

      expect(notifier.state.todaySteps, equals(1050));
      expect(notifier.state.latestHeartRate?.bpm, equals(85));
      expect(notifier.state.recentSteps.length, equals(2));
    });

    test('deduplicates identical records arriving twice', () async {
      await Future.delayed(const Duration(milliseconds: 50));

      final now = DateTime.now().millisecondsSinceEpoch;

      // Duplicate step record
      final dupRecord = StepRecord(timestamp: now, count: 50);
      repo._stepsCtrl.add(dupRecord);
      repo._stepsCtrl.add(dupRecord); // Identical duplicate event

      await Future.delayed(const Duration(milliseconds: 300));

      // Should only add 50 once, total = 1050, not 1100
      expect(notifier.state.todaySteps, equals(1050));
      expect(notifier.state.recentSteps.length, equals(1));
    });

    test('toggles steps window between 60 and 30 minutes', () {
      expect(notifier.state.stepsWindowMinutes, equals(60));
      notifier.setStepsWindowMinutes(30);
      expect(notifier.state.stepsWindowMinutes, equals(30));
    });

    test('toggles heart rate smoothing flag', () {
      expect(notifier.state.isSmoothingEnabled, isFalse);
      notifier.toggleSmoothing();
      expect(notifier.state.isSmoothingEnabled, isTrue);
    });
  });
}
