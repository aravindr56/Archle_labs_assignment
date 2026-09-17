import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/sources/health_data_source.dart';
import '../charts/heart_rate_chart.dart';
import '../charts/steps_chart.dart';
import '../providers/app_providers.dart';
import '../widgets/kpi_card.dart';
import '../widgets/performance_hud.dart';
import 'debug_screen.dart';
import 'permissions_screen.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboard = ref.watch(dashboardProvider);
    final notifier = ref.read(dashboardProvider.notifier);
    final permState = ref.watch(permissionProvider);

    final bool isDenied = permState.status == HealthPermissionStatus.denied;

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.monitor_heart_rounded, color: Color(0xFF00E676)),
            SizedBox(width: 10),
            Text('Health Connect Live'),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Permissions',
            icon: Icon(
              Icons.security_rounded,
              color: permState.isGranted
                  ? const Color(0xFF00E676)
                  : Colors.orangeAccent,
            ),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const PermissionsScreen()),
              );
            },
          ),
          if (!kReleaseMode)
            IconButton(
              key: const Key('debug_menu_button'),
              tooltip: 'Debug & Simulation',
              icon: const Icon(Icons.bug_report_rounded),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const DebugScreen()),
                );
              },
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Floating Performance HUD
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
              child: Wrap(
                spacing: 8,
                runSpacing: 6,
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (dashboard.isSimSourceActive)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade900.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(6),
                        border:
                            Border.all(color: Colors.amber.shade600, width: 1),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.bolt, size: 14, color: Colors.amberAccent),
                          SizedBox(width: 4),
                          Text(
                            'SIMULATED STREAM',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.amberAccent,
                            ),
                          ),
                        ],
                      ),
                    ),
                  const FittedBox(
                    fit: BoxFit.scaleDown,
                    child: PerformanceHud(),
                  ),
                ],
              ),
            ),

            // Non-blocking banner if permissions are denied
            if (isDenied && !dashboard.isSimSourceActive)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.amber.shade900.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.amber.shade700, width: 1),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline,
                        color: Colors.amberAccent, size: 20),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Health Connect permissions missing. Live updates paused.',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                              builder: (_) => const PermissionsScreen()),
                        );
                      },
                      child: const Text('GRANT'),
                    ),
                  ],
                ),
              ),

            // Main Content Scrollable
            Expanded(
              child: RefreshIndicator(
                onRefresh: () => notifier.refreshData(),
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    // Top Cards
                    Row(
                      children: [
                        Expanded(
                          child: StepKpiCard(totalSteps: dashboard.todaySteps),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: HeartRateKpiCard(
                            bpm: dashboard.latestHeartRate?.bpm,
                            timestamp: dashboard.latestHeartRate?.timestamp,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Steps Chart Section
                    Card(
                      elevation: 0,
                      color: const Color(0xFF1B1D2C),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: const BorderSide(color: Color(0x1FFFFFFF)),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Expanded(
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.bar_chart_rounded,
                                          color: Color(0xFF00E676), size: 20),
                                      SizedBox(width: 8),
                                      Flexible(
                                        child: Text(
                                          'Steps Cadence',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                // Live Follow-Up: 60m vs 30m sampling window toggle!
                                Container(
                                  decoration: BoxDecoration(
                                    color: Colors.white10,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  padding: const EdgeInsets.all(2),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      _WindowTogglePill(
                                        label: '60m',
                                        isSelected:
                                            dashboard.stepsWindowMinutes == 60,
                                        onTap: () => notifier
                                            .setStepsWindowMinutes(60),
                                      ),
                                      _WindowTogglePill(
                                        label: '30m',
                                        isSelected:
                                            dashboard.stepsWindowMinutes == 30,
                                        onTap: () => notifier
                                            .setStepsWindowMinutes(30),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Bucketed sums over the last ${dashboard.stepsWindowMinutes} minutes',
                              style: const TextStyle(
                                  fontSize: 12, color: Colors.white54),
                            ),
                            const SizedBox(height: 12),
                            StepsChart(
                              records: dashboard.recentSteps,
                              windowMinutes: dashboard.stepsWindowMinutes,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Heart Rate Chart Section
                    Card(
                      elevation: 0,
                      color: const Color(0xFF1B1D2C),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: const BorderSide(color: Color(0x1FFFFFFF)),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Expanded(
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.show_chart_rounded,
                                          color: Color(0xFFFF5252), size: 20),
                                      SizedBox(width: 8),
                                      Flexible(
                                        child: Text(
                                          'Heart Rate vs. Time',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                // Live Follow-Up: Moving Average Smoothing Toggle!
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Text('SMA',
                                        style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.white70)),
                                    const SizedBox(width: 4),
                                    SizedBox(
                                      height: 28,
                                      child: Switch(
                                        value: dashboard.isSmoothingEnabled,
                                        activeColor: const Color(0xFFFF5252),
                                        materialTapTargetSize:
                                            MaterialTapTargetSize.shrinkWrap,
                                        onChanged: (_) =>
                                            notifier.toggleSmoothing(),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Wrap(
                              alignment: WrapAlignment.spaceBetween,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: 8,
                              runSpacing: 2,
                              children: [
                                const Text(
                                  'Rolling window (LTTB decimation, pan & zoom)',
                                  style: TextStyle(
                                      fontSize: 12, color: Colors.white54),
                                ),
                                if (dashboard.isSmoothingEnabled)
                                  const Text(
                                    '5-period SMA Active',
                                    style: TextStyle(
                                        fontSize: 11, color: Color(0xFFFF5252)),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            HeartRateChart(
                              records: dashboard.recentHeartRates,
                              isSmoothingEnabled: dashboard.isSmoothingEnabled,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WindowTogglePill extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _WindowTogglePill({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF00E676) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: isSelected ? Colors.black : Colors.white70,
          ),
        ),
      ),
    );
  }
}
