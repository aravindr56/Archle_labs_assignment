import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import '../../domain/models/heart_rate_record.dart';
import '../../domain/models/step_record.dart';
import '../../domain/sources/health_data_source.dart';

/// SimSource emits synthetic step and HR updates through the exact same
/// Stream interface used by the real Health Connect listener.
///
/// Strictly disabled in release builds per assessment requirements.
class SimHealthSource implements HealthDataSource {
  final _stepsController = StreamController<StepRecord>.broadcast();
  final _hrController = StreamController<HeartRateRecord>.broadcast();
  Timer? _timer;
  final Random _rnd = Random(42); // Seeded for deterministic test reproducibility
  int _tickCount = 0;
  bool _isRunning = false;

  SimHealthSource() {
    if (kReleaseMode) {
      throw UnsupportedError('SimSource is strictly disabled in release builds.');
    }
  }

  @override
  Stream<StepRecord> get stepsStream => _stepsController.stream;

  @override
  Stream<HeartRateRecord> get heartRateStream => _hrController.stream;

  @override
  Future<HealthPermissionStatus> checkPermissions() async {
    return HealthPermissionStatus.granted;
  }

  @override
  Future<HealthPermissionStatus> requestPermissions() async {
    return HealthPermissionStatus.granted;
  }

  @override
  Future<void> startListening({Duration cadence = const Duration(seconds: 1)}) async {
    if (kReleaseMode) return;
    if (_isRunning) return;
    _isRunning = true;

    _timer = Timer.periodic(cadence, (timer) {
      _tickCount++;
      final nowMs = DateTime.now().millisecondsSinceEpoch;

      // Synthetic Heart Rate: Biological waveform ~72 bpm base + sine variation (55 - 135 bpm)
      final sineVal = sin(_tickCount * 0.2);
      final noise = (_rnd.nextDouble() * 6) - 3;
      final bpm = (76 + (sineVal * 24) + noise).round().clamp(50, 180);
      _hrController.add(HeartRateRecord(timestamp: nowMs, bpm: bpm));

      // Synthetic Steps: Emit a step burst every 2 seconds
      if (_tickCount % 2 == 0) {
        final stepInc = 10 + _rnd.nextInt(25);
        _stepsController.add(StepRecord(timestamp: nowMs, count: stepInc));
      }
    });
  }

  /// Helper for unit/integration tests to emit specific deterministic values
  void emitDeterministicPoint({
    required int timestamp,
    required int steps,
    required int bpm,
  }) {
    if (kReleaseMode) return;
    _stepsController.add(StepRecord(timestamp: timestamp, count: steps));
    _hrController.add(HeartRateRecord(timestamp: timestamp, bpm: bpm));
  }

  @override
  Future<void> stopListening() async {
    _timer?.cancel();
    _timer = null;
    _isRunning = false;
  }

  @override
  void dispose() {
    stopListening();
    _stepsController.close();
    _hrController.close();
  }
}
