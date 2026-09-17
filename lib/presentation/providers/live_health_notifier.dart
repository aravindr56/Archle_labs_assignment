import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/heart_rate_record.dart';
import '../../domain/models/step_record.dart';
import '../../domain/repositories/health_repository.dart';

class DashboardState {
  final int todaySteps;
  final HeartRateRecord? latestHeartRate;
  final List<StepRecord> recentSteps;
  final List<HeartRateRecord> recentHeartRates;
  final int stepsWindowMinutes; // 60 default, togglable to 30
  final bool isSmoothingEnabled; // Moving average toggle for live follow-up
  final bool isSimSourceActive;
  final bool isLoading;

  const DashboardState({
    this.todaySteps = 0,
    this.latestHeartRate,
    this.recentSteps = const [],
    this.recentHeartRates = const [],
    this.stepsWindowMinutes = 60,
    this.isSmoothingEnabled = false,
    this.isSimSourceActive = false,
    this.isLoading = false,
  });

  DashboardState copyWith({
    int? todaySteps,
    HeartRateRecord? latestHeartRate,
    List<StepRecord>? recentSteps,
    List<HeartRateRecord>? recentHeartRates,
    int? stepsWindowMinutes,
    bool? isSmoothingEnabled,
    bool? isSimSourceActive,
    bool? isLoading,
  }) {
    return DashboardState(
      todaySteps: todaySteps ?? this.todaySteps,
      latestHeartRate: latestHeartRate ?? this.latestHeartRate,
      recentSteps: recentSteps ?? this.recentSteps,
      recentHeartRates: recentHeartRates ?? this.recentHeartRates,
      stepsWindowMinutes: stepsWindowMinutes ?? this.stepsWindowMinutes,
      isSmoothingEnabled: isSmoothingEnabled ?? this.isSmoothingEnabled,
      isSimSourceActive: isSimSourceActive ?? this.isSimSourceActive,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class LiveHealthNotifier extends StateNotifier<DashboardState> {
  final HealthRepository _repository;

  StreamSubscription<StepRecord>? _stepsSub;
  StreamSubscription<HeartRateRecord>? _hrSub;

  // Deduplication cache
  final Set<String> _processedKeys = {};

  // Coalescing buffer & timer to avoid UI thrashing
  final List<StepRecord> _pendingSteps = [];
  final List<HeartRateRecord> _pendingHr = [];
  Timer? _coalesceTimer;
  final bool enablePeriodicRefresh;

  LiveHealthNotifier(
    this._repository, {
    this.enablePeriodicRefresh = true,
  }) : super(const DashboardState(isLoading: true)) {
    _init();
  }

  Future<void> _init() async {
    await refreshData();
    _subscribe();
    if (enablePeriodicRefresh) {
      _startPeriodicRefresh();
    }
  }

  void _subscribe() {
    _stepsSub?.cancel();
    _hrSub?.cancel();

    _stepsSub = _repository.stepsStream.listen((step) {
      final key = 'step_${step.timestamp}_${step.count}';
      if (_processedKeys.add(key)) {
        _pendingSteps.add(step);
        _scheduleCoalesceFlush();
      }
    });

    _hrSub = _repository.heartRateStream.listen((hr) {
      final key = 'hr_${hr.timestamp}_${hr.bpm}';
      if (_processedKeys.add(key)) {
        _pendingHr.add(hr);
        _scheduleCoalesceFlush();
      }
    });
  }

  void _scheduleCoalesceFlush() {
    if (_coalesceTimer?.isActive ?? false) return;
    _coalesceTimer = Timer(const Duration(milliseconds: 250), () {
      _flushPendingUpdates();
    });
  }

  void _flushPendingUpdates() {
    if (_pendingSteps.isEmpty && _pendingHr.isEmpty) return;

    final cutoff = DateTime.now()
        .subtract(Duration(minutes: state.stepsWindowMinutes))
        .millisecondsSinceEpoch;

    // Merge steps
    int newTodaySteps = state.todaySteps;
    final updatedSteps = List<StepRecord>.from(state.recentSteps);
    for (final s in _pendingSteps) {
      newTodaySteps += s.count;
      updatedSteps.add(s);
    }
    _pendingSteps.clear();

    // Filter to window
    final windowedSteps =
        updatedSteps.where((s) => s.timestamp >= cutoff).toList();

    // Merge heart rates
    HeartRateRecord? latestHr = state.latestHeartRate;
    final updatedHr = List<HeartRateRecord>.from(state.recentHeartRates);
    for (final h in _pendingHr) {
      updatedHr.add(h);
      if (latestHr == null || h.timestamp >= latestHr.timestamp) {
        latestHr = h;
      }
    }
    _pendingHr.clear();

    final windowedHr = updatedHr.where((h) => h.timestamp >= cutoff).toList();

    // Prune deduplication cache if large
    if (_processedKeys.length > 5000) {
      _processedKeys.clear();
    }

    if (!mounted) return;
    state = state.copyWith(
      todaySteps: newTodaySteps,
      latestHeartRate: latestHr,
      recentSteps: windowedSteps,
      recentHeartRates: windowedHr,
    );
  }

  Future<void> refreshData() async {
    if (!mounted) return;
    state = state.copyWith(isLoading: true);
    final todayTotal = await _repository.getTodayStepTotal();
    final latestHr = await _repository.getLatestHeartRate();
    if (!mounted) return;
    final window = Duration(minutes: state.stepsWindowMinutes);
    final steps = await _repository.getRecentSteps(window: window);
    final hrs = await _repository.getRecentHeartRates(window: window);

    if (!mounted) return;
    state = state.copyWith(
      todaySteps: todayTotal,
      latestHeartRate: latestHr,
      recentSteps: steps,
      recentHeartRates: hrs,
      isSimSourceActive: _repository.isSimSourceActive,
      isLoading: false,
    );
  }

  void setStepsWindowMinutes(int minutes) {
    if (state.stepsWindowMinutes == minutes) return;
    state = state.copyWith(stepsWindowMinutes: minutes);
    refreshData();
  }

  void toggleSmoothing() {
    state = state.copyWith(isSmoothingEnabled: !state.isSmoothingEnabled);
  }

  Future<void> toggleSimSource(bool active) async {
    await _repository.setSimSourceActive(active);
    _subscribe();
    state = state.copyWith(isSimSourceActive: active);
    await refreshData();
  }

  Future<void> seedSyntheticData() async {
    await _repository.seedSyntheticData();
    await refreshData();
  }

  Timer? _periodicRefreshTimer;
  void _startPeriodicRefresh() {
    _periodicRefreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      refreshData();
    });
  }

  @override
  void dispose() {
    _coalesceTimer?.cancel();
    _periodicRefreshTimer?.cancel();
    _stepsSub?.cancel();
    _hrSub?.cancel();
    super.dispose();
  }
}
