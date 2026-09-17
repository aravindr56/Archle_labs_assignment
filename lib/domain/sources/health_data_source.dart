import '../models/heart_rate_record.dart';
import '../models/step_record.dart';

enum HealthPermissionStatus {
  granted,
  denied,
  notDetermined,
  notSupported,
}

abstract class HealthDataSource {
  /// Stream of discrete step count events
  Stream<StepRecord> get stepsStream;

  /// Stream of discrete heart rate events (bpm)
  Stream<HeartRateRecord> get heartRateStream;

  /// Check current Health Connect read permissions status
  Future<HealthPermissionStatus> checkPermissions();

  /// Request read permissions for StepsRecord & HeartRateRecord
  Future<HealthPermissionStatus> requestPermissions();

  /// Start foreground listening or token polling
  Future<void> startListening();

  /// Stop listening or polling
  Future<void> stopListening();

  /// Clean up resources
  void dispose();
}
