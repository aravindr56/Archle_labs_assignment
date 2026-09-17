import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'core/config/app_config.dart';
import 'data/local/database_service.dart';
import 'presentation/providers/app_providers.dart';
import 'presentation/screens/dashboard_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize SQLite database
  final dbFolder = await getDatabasesPath();
  final dbPath = p.join(dbFolder, 'healthconnect_metrics.db');
  final dbService = await DatabaseService.init(path: dbPath);

  // Run initial retention compaction
  await dbService.runRetentionCompaction();

  runApp(
    ProviderScope(
      overrides: [
        databaseServiceProvider.overrideWithValue(dbService),
      ],
      child: const HealthConnectApp(),
    ),
  );
}

class HealthConnectApp extends StatelessWidget {
  const HealthConnectApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFF0F101A),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF00E676),
          secondary: Color(0xFFFF5252),
          surface: Color(0xFF1B1D2C),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF0F101A),
          elevation: 0,
          scrolledUnderElevation: 0,
        ),
        cardTheme: const CardTheme(
          color: Color(0xFF1B1D2C),
        ),
      ),
      home: const DashboardScreen(),
    );
  }
}
