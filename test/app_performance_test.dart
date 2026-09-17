import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthconnect_dashboard/domain/models/heart_rate_record.dart';
import 'package:healthconnect_dashboard/domain/models/step_record.dart';
import 'package:healthconnect_dashboard/domain/repositories/health_repository.dart';
import 'package:healthconnect_dashboard/domain/sources/health_data_source.dart';
import 'package:healthconnect_dashboard/main.dart';
import 'package:healthconnect_dashboard/presentation/providers/app_providers.dart';
import 'package:healthconnect_dashboard/presentation/screens/dashboard_screen.dart';

class MockPerfRepository implements HealthRepository {
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
  Future<List<StepRecord>> getRecentSteps(
      {Duration window = const Duration(minutes: 60)}) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    return List.generate(
      20,
      (i) => StepRecord(timestamp: now - (i * 60000), count: 25 + i),
    );
  }

  @override
  Future<List<HeartRateRecord>> getRecentHeartRates(
      {Duration window = const Duration(minutes: 60)}) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    return List.generate(
      40,
      (i) => HeartRateRecord(timestamp: now - (i * 30000), bpm: 70 + (i % 25)),
    );
  }

  @override
  Future<void> setSimSourceActive(bool active) async {
    _simActive = active;
  }

  @override
  bool get isSimSourceActive => _simActive;

  @override
  Future<void> seedSyntheticData() async {
    _steps = 4250;
    _hr = HeartRateRecord(
      timestamp: DateTime.now().millisecondsSinceEpoch,
      bpm: 88,
    );
  }

  @override
  Future<Map<String, int>> runCompaction() async => {
        'deleted_steps_raw': 0,
        'deleted_hr_raw': 0,
      };

  @override
  void dispose() {}
}

void main() {
  testWidgets(
    'Headless End-to-End Performance Session: SimSource updates for 60-90s with Performance HUD assertions',
    (WidgetTester tester) async {
      final repo = MockPerfRepository();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            healthRepositoryProvider.overrideWithValue(repo),
          ],
          child: const HealthConnectApp(),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // 1. Verify dashboard elements
      expect(find.text('Health Connect Live'), findsOneWidget);
      expect(
          find.byKey(const Key('performance_hud_container')), findsOneWidget);

      // 2. Navigate to Debug Screen
      final debugBtn = find.byKey(const Key('debug_menu_button'));
      expect(debugBtn, findsOneWidget);
      await tester.tap(debugBtn);
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Debug & Simulation Tools'), findsOneWidget);

      // 3. Enable SimSource toggle
      final simSwitch = find.byKey(const Key('sim_source_switch'));
      expect(simSwitch, findsOneWidget);
      await tester.tap(simSwitch);
      await tester.pump(const Duration(milliseconds: 200));

      // 4. Seed synthetic dataset
      final seedBtn = find.byKey(const Key('seed_database_button'));
      expect(seedBtn, findsOneWidget);
      await tester.tap(seedBtn);
      await tester.pump(const Duration(milliseconds: 200));

      // 5. Return to Dashboard
      final NavigatorState navigator = tester.state(find.byType(Navigator));
      navigator.pop();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));

      // Refresh data
      final container = ProviderScope.containerOf(
        tester.element(find.byType(DashboardScreen)),
      );
      await container.read(dashboardProvider.notifier).refreshData();
      await tester.pump(const Duration(milliseconds: 100));

      // 6. Simulate session updates (driving frames smoothly)
      for (int i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      // 7. Assertions on UI updates & Performance HUD
      final stepsFinder = find.byKey(const Key('steps_total_text'));
      expect(stepsFinder, findsOneWidget);
      final stepsText = tester.widget<Text>(stepsFinder).data!;
      expect(stepsText, equals('4,250'));

      final hrFinder = find.byKey(const Key('heart_rate_bpm_text'));
      expect(hrFinder, findsOneWidget);
      final hrText = tester.widget<Text>(hrFinder).data!;
      expect(hrText, equals('88'));

      // Assert Performance HUD
      final buildTimeFinder = find.byKey(const Key('perf_hud_build_time'));
      expect(buildTimeFinder, findsOneWidget);
      final buildTimeText = tester.widget<Text>(buildTimeFinder).data!;
      expect(buildTimeText, contains('Build:'));

      final jankFinder = find.byKey(const Key('perf_hud_jank'));
      expect(jankFinder, findsOneWidget);
      final jankText = tester.widget<Text>(jankFinder).data!;
      expect(jankText, equals('Jank: 0'));

      // Clean unmount
      await tester.pumpWidget(const SizedBox());
    },
  );
}
