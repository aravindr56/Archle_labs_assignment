import 'package:flutter_test/flutter_test.dart';
import 'package:healthconnect_dashboard/domain/models/heart_rate_record.dart';
import 'package:healthconnect_dashboard/domain/models/step_record.dart';
import 'package:healthconnect_dashboard/domain/repositories/health_repository.dart';
import 'package:healthconnect_dashboard/domain/sources/health_data_source.dart';
import 'package:healthconnect_dashboard/presentation/providers/permissions_provider.dart';

class FakeHealthRepository implements HealthRepository {
  HealthPermissionStatus mockStatus = HealthPermissionStatus.denied;

  @override
  Future<HealthPermissionStatus> checkPermissions() async => mockStatus;

  @override
  Future<HealthPermissionStatus> requestPermissions() async {
    mockStatus = HealthPermissionStatus.granted;
    return mockStatus;
  }

  @override
  Stream<StepRecord> get stepsStream => const Stream.empty();

  @override
  Stream<HeartRateRecord> get heartRateStream => const Stream.empty();

  @override
  Future<void> startListening() async {}

  @override
  Future<void> stopListening() async {}

  @override
  Future<int> getTodayStepTotal() async => 0;

  @override
  Future<HeartRateRecord?> getLatestHeartRate() async => null;

  @override
  Future<List<StepRecord>> getRecentSteps({Duration window = const Duration(minutes: 60)}) async => [];

  @override
  Future<List<HeartRateRecord>> getRecentHeartRates({Duration window = const Duration(minutes: 60)}) async => [];

  @override
  Future<void> setSimSourceActive(bool active) async {}

  @override
  bool get isSimSourceActive => false;

  @override
  Future<void> seedSyntheticData() async {}

  @override
  Future<Map<String, int>> runCompaction() async => {};

  @override
  void dispose() {}
}

void main() {
  group('PermissionsProvider Tests', () {
    test('initializes with checked permission status', () async {
      final fakeRepo = FakeHealthRepository();
      fakeRepo.mockStatus = HealthPermissionStatus.denied;

      final notifier = PermissionNotifier(fakeRepo);
      await Future.delayed(const Duration(milliseconds: 50));

      expect(notifier.state.status, equals(HealthPermissionStatus.denied));
      expect(notifier.state.isGranted, isFalse);
    });

    test('requesting permission transitions state to granted', () async {
      final fakeRepo = FakeHealthRepository();
      fakeRepo.mockStatus = HealthPermissionStatus.denied;

      final notifier = PermissionNotifier(fakeRepo);
      await Future.delayed(const Duration(milliseconds: 50));

      expect(notifier.state.status, equals(HealthPermissionStatus.denied));

      await notifier.requestPermissions();

      expect(notifier.state.status, equals(HealthPermissionStatus.granted));
      expect(notifier.state.isGranted, isTrue);
    });
  });
}
