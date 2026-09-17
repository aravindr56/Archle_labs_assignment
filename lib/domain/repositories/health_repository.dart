import '../models/aggregates.dart';
import '../models/heart_rate_record.dart';
import '../models/step_record.dart';
import '../sources/health_data_source.dart';

abstract class HealthRepository {
  /// Stream of step updates (real or simulated)
  Stream<StepRecord> get stepsStream;

  /// Stream of heart rate updates (real or simulated)
  Stream<HeartRateRecord> get heartRateStream;

  /// Check Health Connect permission state
  Future<HealthPermissionStatus> checkPermissions();

  /// Request Health Connect permissions
  Future<HealthPermissionStatus> requestPermissions();

  /// Start monitoring
  Future<void> startListening();

  /// Stop monitoring
  Future<void> stopListening();

  /// Query total steps recorded today
  Future<int> getTodayStepTotal();

  /// Query most recently received heart rate
  Future<HeartRateRecord?> getLatestHeartRate();

  /// Fetch steps within a specific recent duration window (e.g. 60m or 30m)
  Future<List<StepRecord>> getRecentSteps({Duration window});

  /// Fetch heart rate records within a specific recent duration window
  Future<List<HeartRateRecord>> getRecentHeartRates({Duration window});

  /// Switch between real Health Connect source and SimSource (debug only)
  Future<void> setSimSourceActive(bool active);

  /// Whether SimSource is currently generating synthetic data
  bool get isSimSourceActive;

  /// Seed local SQLite database with deterministic synthetic data (Appendix B)
  Future<void> seedSyntheticData();

  /// Run nightly retention compaction task
  Future<Map<String, int>> runCompaction();

  /// Dispose resources
  void dispose();
}
