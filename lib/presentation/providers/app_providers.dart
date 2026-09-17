import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/local/database_service.dart';
import '../../data/repositories/health_repository_impl.dart';
import '../../data/sources/native_health_connect_source.dart';
import '../../data/sources/sim_health_source.dart';
import '../../domain/repositories/health_repository.dart';
import 'live_health_notifier.dart';
import 'permissions_provider.dart';

final databaseServiceProvider = Provider<DatabaseService>((ref) {
  throw UnimplementedError('databaseServiceProvider must be overridden in main()');
});

final healthRepositoryProvider = Provider<HealthRepository>((ref) {
  final dbService = ref.watch(databaseServiceProvider);
  final realSource = NativeHealthConnectSource();
  final simSource = SimHealthSource();

  final repo = HealthRepositoryImpl(
    realSource: realSource,
    dbService: dbService,
    simSource: simSource,
  );

  ref.onDispose(() {
    repo.dispose();
  });

  return repo;
});

final permissionProvider =
    StateNotifierProvider<PermissionNotifier, PermissionState>((ref) {
  final repo = ref.watch(healthRepositoryProvider);
  return PermissionNotifier(repo);
});

final dashboardProvider =
    StateNotifierProvider<LiveHealthNotifier, DashboardState>((ref) {
  final repo = ref.watch(healthRepositoryProvider);
  return LiveHealthNotifier(repo);
});
