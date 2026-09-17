import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../domain/models/heart_rate_record.dart';
import '../../domain/models/step_record.dart';
import '../../domain/repositories/health_repository.dart';
import '../../domain/sources/health_data_source.dart';
import '../local/database_service.dart';
import '../sources/sim_health_source.dart';

class HealthRepositoryImpl implements HealthRepository {
  final HealthDataSource _realSource;
  final DatabaseService _dbService;
  SimHealthSource? _simSource;

  bool _isSimActive = false;
  final _stepsController = StreamController<StepRecord>.broadcast();
  final _hrController = StreamController<HeartRateRecord>.broadcast();

  StreamSubscription<StepRecord>? _stepsSub;
  StreamSubscription<HeartRateRecord>? _hrSub;

  HealthRepositoryImpl({
    required HealthDataSource realSource,
    required DatabaseService dbService,
    SimHealthSource? simSource,
  })  : _realSource = realSource,
        _dbService = dbService,
        _simSource = simSource {
    _subscribeCurrentSource();
  }

  void _subscribeCurrentSource() {
    _stepsSub?.cancel();
    _hrSub?.cancel();

    final activeSource = (_isSimActive && !kReleaseMode && _simSource != null)
        ? _simSource!
        : _realSource;

    _stepsSub = activeSource.stepsStream.listen((record) async {
      await _dbService.insertStep(record);
      if (!_stepsController.isClosed) {
        _stepsController.add(record);
      }
    });

    _hrSub = activeSource.heartRateStream.listen((record) async {
      await _dbService.insertHeartRate(record);
      if (!_hrController.isClosed) {
        _hrController.add(record);
      }
    });
  }

  @override
  Stream<StepRecord> get stepsStream => _stepsController.stream;

  @override
  Stream<HeartRateRecord> get heartRateStream => _hrController.stream;

  @override
  bool get isSimSourceActive => _isSimActive;

  @override
  Future<void> setSimSourceActive(bool active) async {
    if (kReleaseMode && active) {
      throw UnsupportedError('Cannot activate SimSource in release mode.');
    }
    if (_isSimActive == active) return;
    _isSimActive = active;

    if (_isSimActive) {
      _simSource ??= SimHealthSource();
      await _realSource.stopListening();
      await _simSource!.startListening();
    } else {
      await _simSource?.stopListening();
      await _realSource.startListening();
    }
    _subscribeCurrentSource();
  }

  @override
  Future<HealthPermissionStatus> checkPermissions() {
    if (_isSimActive) return Future.value(HealthPermissionStatus.granted);
    return _realSource.checkPermissions();
  }

  @override
  Future<HealthPermissionStatus> requestPermissions() {
    if (_isSimActive) return Future.value(HealthPermissionStatus.granted);
    return _realSource.requestPermissions();
  }

  @override
  Future<void> startListening() async {
    if (_isSimActive && !kReleaseMode && _simSource != null) {
      await _simSource!.startListening();
    } else {
      await _realSource.startListening();
    }
  }

  @override
  Future<void> stopListening() async {
    await _realSource.stopListening();
    await _simSource?.stopListening();
  }

  @override
  Future<int> getTodayStepTotal() => _dbService.getTodayStepTotal();

  @override
  Future<HeartRateRecord?> getLatestHeartRate() => _dbService.getLatestHeartRate();

  @override
  Future<List<StepRecord>> getRecentSteps({Duration window = const Duration(minutes: 60)}) {
    final cutoff = DateTime.now().subtract(window).millisecondsSinceEpoch;
    return _dbService.getRawStepsSince(cutoff);
  }

  @override
  Future<List<HeartRateRecord>> getRecentHeartRates({Duration window = const Duration(minutes: 60)}) {
    final cutoff = DateTime.now().subtract(window).millisecondsSinceEpoch;
    return _dbService.getRawHeartRateSince(cutoff);
  }

  @override
  Future<void> seedSyntheticData() async {
    if (kReleaseMode) return;
    final now = DateTime.now();

    // Generate 60 minutes of high-density data (one point every 10 seconds = 360 points)
    final List<StepRecord> steps = [];
    final List<HeartRateRecord> hrs = [];

    for (int i = 360; i >= 0; i--) {
      final ts = now.subtract(Duration(seconds: i * 10)).millisecondsSinceEpoch;
      // Heart rate follows a realistic curve with some exercise peaks (70 to 145 bpm)
      final bpm = (75 + 30 * (1 + (i % 60) / 60)).round().clamp(60, 160);
      hrs.add(HeartRateRecord(timestamp: ts, bpm: bpm));

      // Steps increment every 30 seconds
      if (i % 3 == 0) {
        steps.add(StepRecord(timestamp: ts, count: 25 + (i % 15)));
      }
    }

    await _dbService.insertStepsBatch(steps);
    await _dbService.insertHeartRateBatch(hrs);
  }

  @override
  Future<Map<String, int>> runCompaction() => _dbService.runRetentionCompaction();

  @override
  void dispose() {
    _stepsSub?.cancel();
    _hrSub?.cancel();
    _stepsController.close();
    _hrController.close();
    _realSource.dispose();
    _simSource?.dispose();
  }
}
