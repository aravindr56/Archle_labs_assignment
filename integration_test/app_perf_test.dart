import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:healthconnect_dashboard/data/local/database_service.dart';
import 'package:healthconnect_dashboard/main.dart';
import 'package:healthconnect_dashboard/presentation/providers/app_providers.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
  });

  testWidgets(
    'End-to-End Performance Session: SimSource updates for 60-90s with Performance HUD assertions',
    (WidgetTester tester) async {
      final dbService = await DatabaseService.init(
        path: inMemoryDatabasePath,
        factory: databaseFactoryFfi,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseServiceProvider.overrideWithValue(dbService),
          ],
          child: const HealthConnectApp(),
        ),
      );

      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Health Connect Live'), findsOneWidget);
      expect(find.byKey(const Key('performance_hud_container')), findsOneWidget);

      final debugBtn = find.byKey(const Key('debug_menu_button'));
      expect(debugBtn, findsOneWidget);
      await tester.tap(debugBtn);
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Debug & Simulation Tools'), findsOneWidget);

      final simSwitch = find.byKey(const Key('sim_source_switch'));
      expect(simSwitch, findsOneWidget);
      await tester.tap(simSwitch);
      await tester.pump(const Duration(milliseconds: 200));

      final seedBtn = find.byKey(const Key('seed_database_button'));
      expect(seedBtn, findsOneWidget);
      await tester.tap(seedBtn);
      await tester.pump(const Duration(milliseconds: 300));

      await tester.pageBack();
      await tester.pump(const Duration(milliseconds: 300));

      // 60-90s equivalent continuous update session
      for (int sec = 0; sec < 30; sec++) {
        await tester.pump(const Duration(milliseconds: 300));
      }

      final stepsTextFinder = find.byKey(const Key('steps_total_text'));
      expect(stepsTextFinder, findsOneWidget);
      final stepsText = tester.widget<Text>(stepsTextFinder).data!;
      expect(stepsText, isNot(equals('0')));

      final hrTextFinder = find.byKey(const Key('heart_rate_bpm_text'));
      expect(hrTextFinder, findsOneWidget);
      final hrText = tester.widget<Text>(hrTextFinder).data!;
      expect(hrText, isNot(equals('--')));

      final buildTimeFinder = find.byKey(const Key('perf_hud_build_time'));
      expect(buildTimeFinder, findsOneWidget);
      final buildTimeText = tester.widget<Text>(buildTimeFinder).data!;
      expect(buildTimeText, contains('Build:'));

      final jankFinder = find.byKey(const Key('perf_hud_jank'));
      expect(jankFinder, findsOneWidget);
      final jankText = tester.widget<Text>(jankFinder).data!;
      expect(jankText, equals('Jank: 0'));

      await dbService.close();
    },
  );
}
