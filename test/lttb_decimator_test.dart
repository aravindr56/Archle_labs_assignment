import 'package:flutter_test/flutter_test.dart';
import 'package:healthconnect_dashboard/domain/models/heart_rate_record.dart';
import 'package:healthconnect_dashboard/presentation/charts/lttb_decimator.dart';

void main() {
  group('LttbDecimator & MovingAverageFilter Tests', () {
    test('LTTB downsamples large dataset (1,000 points) to exact threshold', () {
      final List<HeartRateRecord> largeData = [];
      const start = 1700000000000;
      for (int i = 0; i < 1000; i++) {
        final bpm = 60 + (i % 80);
        largeData.add(HeartRateRecord(timestamp: start + (i * 1000), bpm: bpm));
      }

      const threshold = 150;
      final decimated = LttbDecimator.decimate(largeData, threshold);

      expect(decimated.length, equals(threshold));
      expect(decimated.first.timestamp, equals(largeData.first.timestamp));
      expect(decimated.last.timestamp, equals(largeData.last.timestamp));
    });

    test('LTTB returns original list when count is less than threshold', () {
      const smallData = [
        HeartRateRecord(timestamp: 1000, bpm: 70),
        HeartRateRecord(timestamp: 2000, bpm: 75),
      ];

      final result = LttbDecimator.decimate(smallData, 100);
      expect(result.length, equals(2));
    });

    test('MovingAverageFilter smooths heart rate numbers properly', () {
      const data = [
        HeartRateRecord(timestamp: 1000, bpm: 60),
        HeartRateRecord(timestamp: 2000, bpm: 80),
        HeartRateRecord(timestamp: 3000, bpm: 100),
        HeartRateRecord(timestamp: 4000, bpm: 80),
        HeartRateRecord(timestamp: 5000, bpm: 60),
      ];

      final smoothed = MovingAverageFilter.smooth(data, windowSize: 3);
      expect(smoothed.length, equals(5));
      // At index 2: (60 + 80 + 100) / 3 = 80
      expect(smoothed[2].bpm, equals(80));
    });
  });
}
