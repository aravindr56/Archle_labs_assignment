import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthconnect_dashboard/domain/models/heart_rate_record.dart';
import 'package:healthconnect_dashboard/domain/models/step_record.dart';
import 'package:healthconnect_dashboard/presentation/charts/heart_rate_chart.dart';
import 'package:healthconnect_dashboard/presentation/charts/steps_chart.dart';

void main() {
  group('Chart Rendering & Golden Tests', () {
    testWidgets('renders HeartRateChart with fixed synthetic dataset',
        (WidgetTester tester) async {
      final now = 1700000000000;
      final fixedHrRecords = List.generate(
        60,
        (i) => HeartRateRecord(
          timestamp: now + (i * 10000),
          bpm: 65 + (i % 35),
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 380,
                height: 220,
                child: HeartRateChart(
                  records: fixedHrRecords,
                  isSmoothingEnabled: false,
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify custom painter widget is in the tree
      expect(find.byType(CustomPaint), findsWidgets);
      expect(find.byType(HeartRateChart), findsOneWidget);

      // Verify golden file (creates baseline or compares)
      await expectLater(
        find.byType(HeartRateChart),
        matchesGoldenFile('goldens/heart_rate_chart_golden.png'),
      );
    });

    testWidgets('renders StepsChart with fixed synthetic dataset',
        (WidgetTester tester) async {
      final now = DateTime.now().millisecondsSinceEpoch;
      final fixedStepRecords = List.generate(
        30,
        (i) => StepRecord(
          timestamp: now - (i * 60000),
          count: 20 + (i * 5),
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 380,
                height: 200,
                child: StepsChart(
                  records: fixedStepRecords,
                  windowMinutes: 60,
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byType(CustomPaint), findsWidgets);
      expect(find.byType(StepsChart), findsOneWidget);

      await expectLater(
        find.byType(StepsChart),
        matchesGoldenFile('goldens/steps_chart_golden.png'),
      );
    });
  });
}
