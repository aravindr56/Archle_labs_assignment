import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthconnect_dashboard/domain/models/heart_rate_record.dart';
import 'package:healthconnect_dashboard/domain/models/step_record.dart';
import 'package:healthconnect_dashboard/domain/repositories/health_repository.dart';
import 'package:healthconnect_dashboard/domain/sources/health_data_source.dart';
import 'package:healthconnect_dashboard/presentation/providers/app_providers.dart';
import 'package:healthconnect_dashboard/presentation/screens/dashboard_screen.dart';

class TestMockRepository implements HealthRepository {
  int _steps = 0;
  HeartRateRecord? _hr;
  bool _simActive = false;

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
  Future<int> getTodayStepTotal() async => _steps;

  @override
  Future<HeartRateRecord?> getLatestHeartRate() async => _hr;

  @override
  Future<List<StepRecord>> getRecentSteps({Duration window = const Duration(minutes: 60)}) async => [];

  @override
  Future<List<HeartRateRecord>> getRecentHeartRates({Duration window = const Duration(minutes: 60)}) async => [];

  @override
  Future<void> setSimSourceActive(bool active) async {
    _simActive = active;
  }

  @override
  bool get isSimSourceActive => _simActive;

  @override
  Future<void> seedSyntheticData() async {
    _steps = 550;
    _hr = HeartRateRecord(
      timestamp: DateTime.now().millisecondsSinceEpoch,
      bpm: 82,
    );
  }

  @override
  Future<Map<String, int>> runCompaction() async => {};

  @override
  void dispose() {}
}

void main() {
  testWidgets('Dashboard UI renders and updates with seeded data',
      (WidgetTester tester) async {
    final repo = TestMockRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          healthRepositoryProvider.overrideWithValue(repo),
        ],
        child: const MaterialApp(
          home: DashboardScreen(),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Health Connect Live'), findsOneWidget);
    expect(find.byKey(const Key('performance_hud_container')), findsOneWidget);

    // Seed data
    await repo.seedSyntheticData();

    // Trigger refresh
    final container = ProviderScope.containerOf(
      tester.element(find.byType(DashboardScreen)),
    );
    await container.read(dashboardProvider.notifier).refreshData();

    await tester.pump(const Duration(milliseconds: 100));

    // Assert steps updated
    expect(find.text('550'), findsOneWidget);
    // Assert HR updated
    expect(find.text('82'), findsOneWidget);

    // Clean unmount
    await tester.pumpWidget(const SizedBox());
  });
}
