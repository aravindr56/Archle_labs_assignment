import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/sources/native_health_connect_source.dart';
import '../../domain/sources/health_data_source.dart';
import '../providers/app_providers.dart';

class PermissionsScreen extends ConsumerWidget {
  const PermissionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final permState = ref.watch(permissionProvider);
    final permNotifier = ref.read(permissionProvider.notifier);

    final isGranted = permState.status == HealthPermissionStatus.granted;
    final isDenied = permState.status == HealthPermissionStatus.denied;
    final isNotSupported =
        permState.status == HealthPermissionStatus.notSupported;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Health Connect Permissions'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            // Informational / Fallback Banner on Denial or Not Supported
            if (isDenied || isNotSupported)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.amber.shade900.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.amber.shade600, width: 1.5),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.warning_amber_rounded,
                            color: Colors.amber.shade400, size: 24),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            isNotSupported
                                ? 'Health Connect Not Installed / Available'
                                : 'Permissions Required',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: Colors.amber.shade200,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      isNotSupported
                          ? 'Health Connect is not installed on this device. On Android 9–13, the "Health Connect by Google" app must be installed from Play Store. Alternatively, activate Simulation Mode below.'
                          : 'Live dashboard updates require Health Connect permissions. If Health Connect is not installed, install it from the Play Store or enable Simulation Mode.',
                      style: const TextStyle(fontSize: 13, height: 1.4),
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF00E676),
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 10),
                          ),
                          icon: const Icon(Icons.bolt, size: 18),
                          label: const Text(
                            'Activate Simulation Mode (SimSource)',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          onPressed: () async {
                            await ref
                                .read(dashboardProvider.notifier)
                                .toggleSimSource(true);
                            await permNotifier.checkPermissions();
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                      'SimSource Mode Activated! Live data running.'),
                                  backgroundColor: Color(0xFF00E676),
                                ),
                              );
                              Navigator.of(context).pop();
                            }
                          },
                        ),
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.amber.shade300,
                            side: BorderSide(color: Colors.amber.shade600),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 10),
                          ),
                          icon: const Icon(Icons.shop_rounded, size: 18),
                          label: const Text('Install from Play Store'),
                          onPressed: () =>
                              NativeHealthConnectSource.openPlayStore(),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

            const Text(
              'Permission Ledger',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            _PermissionItemCard(
              title: 'Steps Record (Read)',
              description: 'Reads daily and hourly step count accumulation',
              icon: Icons.directions_walk_rounded,
              status: permState.status,
            ),
            const SizedBox(height: 12),

            _PermissionItemCard(
              title: 'Heart Rate Record (Read)',
              description:
                  'Reads real-time BPM streams and historical samples',
              icon: Icons.favorite_rounded,
              status: permState.status,
            ),

            const SizedBox(height: 24),

            if (permState.isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: CircularProgressIndicator(),
                ),
              )
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () => permNotifier.requestPermissions(),
                    icon: const Icon(Icons.security_rounded),
                    label: Text(
                      isGranted
                          ? 'Permissions Granted'
                          : 'Request Permissions',
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Back to Dashboard'),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _PermissionItemCard extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final HealthPermissionStatus status;

  const _PermissionItemCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    final bool isGranted = status == HealthPermissionStatus.granted;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: isGranted ? Colors.green.withOpacity(0.4) : Colors.white12,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: isGranted
                  ? Colors.green.withOpacity(0.2)
                  : Colors.blueGrey.withOpacity(0.2),
              child: Icon(
                icon,
                color: isGranted ? Colors.greenAccent : Colors.white70,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: const TextStyle(color: Colors.white60, fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Chip(
              avatar: Icon(
                isGranted ? Icons.check_circle : Icons.cancel,
                size: 16,
                color: isGranted ? Colors.greenAccent : Colors.redAccent,
              ),
              label: Text(
                isGranted ? 'GRANTED' : 'DENIED',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: isGranted ? Colors.greenAccent : Colors.redAccent,
                ),
              ),
              backgroundColor: isGranted
                  ? Colors.green.withOpacity(0.12)
                  : Colors.red.withOpacity(0.12),
              padding: EdgeInsets.zero,
            ),
          ],
        ),
      ),
    );
  }
}
