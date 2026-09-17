import 'dart:async';
import 'package:flutter/services.dart';
import '../../domain/models/heart_rate_record.dart';
import '../../domain/models/step_record.dart';
import '../../domain/sources/health_data_source.dart';

class NativeHealthConnectSource implements HealthDataSource {
  static const _methodChannel =
      MethodChannel('com.archlelabs.healthconnect/methods');
  static const _eventChannel =
      EventChannel('com.archlelabs.healthconnect/events');

  final _stepsController = StreamController<StepRecord>.broadcast();
  final _hrController = StreamController<HeartRateRecord>.broadcast();

  StreamSubscription? _eventSub;
  bool _isListening = false;

  @override
  Stream<StepRecord> get stepsStream => _stepsController.stream;

  @override
  Stream<HeartRateRecord> get heartRateStream => _hrController.stream;

  @override
  Future<HealthPermissionStatus> checkPermissions() async {
    try {
      final status = await _methodChannel.invokeMethod<String>('getSdkStatus');
      if (status != 'available') {
        return HealthPermissionStatus.notSupported;
      }

      final res = await _methodChannel
          .invokeMapMethod<String, dynamic>('checkPermissions');
      final allGranted = res?['allGranted'] as bool? ?? false;
      return allGranted
          ? HealthPermissionStatus.granted
          : HealthPermissionStatus.denied;
    } catch (_) {
      // Running on emulator or test environment without Health Connect
      return HealthPermissionStatus.notSupported;
    }
  }

  @override
  Future<HealthPermissionStatus> requestPermissions() async {
    try {
      final res = await _methodChannel
          .invokeMapMethod<String, dynamic>('requestPermissions');
      final allGranted = res?['allGranted'] as bool? ?? false;
      return allGranted
          ? HealthPermissionStatus.granted
          : HealthPermissionStatus.denied;
    } catch (_) {
      return HealthPermissionStatus.denied;
    }
  }

  @override
  Future<void> startListening() async {
    if (_isListening) return;
    _isListening = true;

    try {
      _eventSub = _eventChannel.receiveBroadcastStream().listen(
        (dynamic event) {
          if (event is Map) {
            final type = event['type'] as String?;
            final ts = (event['ts'] as num?)?.toInt() ??
                DateTime.now().millisecondsSinceEpoch;

            if (type == 'steps') {
              final count = (event['count'] as num?)?.toInt() ?? 0;
              _stepsController.add(StepRecord(timestamp: ts, count: count));
            } else if (type == 'heartRate') {
              final bpm = (event['bpm'] as num?)?.toInt() ?? 0;
              _hrController.add(HeartRateRecord(timestamp: ts, bpm: bpm));
            }
          }
        },
        onError: (err) {
          // Handle stream error gracefully
        },
      );
    } catch (_) {
      // Native event channel might not be supported in non-Android environments
    }
  }

  @override
  Future<void> stopListening() async {
    await _eventSub?.cancel();
    _eventSub = null;
    _isListening = false;
  }

  @override
  void dispose() {
    stopListening();
    _stepsController.close();
    _hrController.close();
  }
}
