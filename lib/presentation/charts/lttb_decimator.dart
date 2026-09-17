import 'dart:math';
import '../../domain/models/heart_rate_record.dart';

/// Implements Largest-Triangle-Three-Buckets (LTTB) downsampling algorithm
/// to reduce 5,000-10,000 points down to a visual resolution while
/// preserving visual shape, local extrema, peaks, and troughs.
class LttbDecimator {
  static List<HeartRateRecord> decimate(
    List<HeartRateRecord> data,
    int threshold,
  ) {
    final dataLen = data.length;
    if (threshold >= dataLen || threshold <= 2) {
      return data;
    }

    final List<HeartRateRecord> sampled = List<HeartRateRecord>.filled(
      threshold,
      data.first,
    );

    // Bucket size. Leave room for start and end data points
    final double every = (dataLen - 2) / (threshold - 2);

    int a = 0; // Initially the first point in the triangle
    int sampledIndex = 0;
    sampled[sampledIndex++] = data[a];

    for (int i = 0; i < threshold - 2; i++) {
      // Calculate point average for next bucket (c)
      double avgX = 0;
      double avgY = 0;
      final int avgRangeStart =
          (((i + 1) * every).floor() + 1).clamp(0, dataLen - 1);
      final int avgRangeEnd = (((i + 2) * every).floor() + 1).clamp(0, dataLen);
      final int avgRangeLength = max(1, avgRangeEnd - avgRangeStart);

      for (int k = avgRangeStart; k < avgRangeEnd; k++) {
        avgX += data[k].timestamp;
        avgY += data[k].bpm;
      }
      avgX /= avgRangeLength;
      avgY /= avgRangeLength;

      // Get the range for this bucket
      final int rangeOffs = ((i * every).floor() + 1).clamp(0, dataLen - 1);
      final int rangeTo = (((i + 1) * every).floor() + 1).clamp(0, dataLen);

      // Point a
      final double pointAx = data[a].timestamp.toDouble();
      final double pointAy = data[a].bpm.toDouble();

      double maxArea = -1;
      int nextA = rangeOffs;

      for (int k = rangeOffs; k < rangeTo; k++) {
        // Calculate triangle area over points a, this point, and the average point of the next bucket
        final double area = ((pointAx - avgX) * (data[k].bpm - pointAy) -
                (pointAx - data[k].timestamp) * (avgY - pointAy))
            .abs();

        if (area > maxArea) {
          maxArea = area;
          nextA = k;
        }
      }

      sampled[sampledIndex++] = data[nextA];
      a = nextA;
    }

    // Always include the last point
    sampled[sampledIndex] = data.last;

    return sampled;
  }
}

/// Simple Moving Average (SMA) smoothing filter used for the Live Follow-Up requirement.
class MovingAverageFilter {
  static List<HeartRateRecord> smooth(
    List<HeartRateRecord> data, {
    int windowSize = 5,
  }) {
    if (data.length <= windowSize || windowSize <= 1) return data;

    final List<HeartRateRecord> smoothed = [];
    int runningSum = 0;

    for (int i = 0; i < data.length; i++) {
      runningSum += data[i].bpm;
      if (i >= windowSize) {
        runningSum -= data[i - windowSize].bpm;
        final avg = (runningSum / windowSize).round();
        smoothed.add(HeartRateRecord(timestamp: data[i].timestamp, bpm: avg));
      } else {
        final avg = (runningSum / (i + 1)).round();
        smoothed.add(HeartRateRecord(timestamp: data[i].timestamp, bpm: avg));
      }
    }
    return smoothed;
  }
}
