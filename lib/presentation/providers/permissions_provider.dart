import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/repositories/health_repository.dart';
import '../../domain/sources/health_data_source.dart';

class PermissionState {
  final HealthPermissionStatus status;
  final bool isLoading;
  final String? errorMessage;

  const PermissionState({
    this.status = HealthPermissionStatus.notDetermined,
    this.isLoading = false,
    this.errorMessage,
  });

  bool get isGranted => status == HealthPermissionStatus.granted;

  PermissionState copyWith({
    HealthPermissionStatus? status,
    bool? isLoading,
    String? errorMessage,
  }) {
    return PermissionState(
      status: status ?? this.status,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }
}

class PermissionNotifier extends StateNotifier<PermissionState> {
  final HealthRepository _repository;

  PermissionNotifier(this._repository) : super(const PermissionState()) {
    checkPermissions();
  }

  Future<void> checkPermissions() async {
    state = state.copyWith(isLoading: true);
    try {
      final status = await _repository.checkPermissions();
      state = state.copyWith(status: status, isLoading: false);
    } catch (e) {
      state = state.copyWith(
        status: HealthPermissionStatus.denied,
        isLoading: false,
        errorMessage: e.toString(),
      );
    }
  }

  Future<void> requestPermissions() async {
    state = state.copyWith(isLoading: true);
    try {
      final status = await _repository.requestPermissions();
      state = state.copyWith(status: status, isLoading: false);
    } catch (e) {
      state = state.copyWith(
        status: HealthPermissionStatus.denied,
        isLoading: false,
        errorMessage: e.toString(),
      );
    }
  }
}
