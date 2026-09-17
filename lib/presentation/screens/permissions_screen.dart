import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/sources/health_data_source.dart';
import '../providers/app_providers.dart';
import '../providers/permissions_provider.dart';

class PermissionsScreen extends ConsumerWidget {
  const PermissionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final permState = ref.watch(permissionProvider);
    final permNotifier = ref.read(permissionProvider.notifier);

    final isGranted = permState.status == HealthPermissionStatus.granted;
    final isDenied = permState.status == HealthPermissionStatus.denied;
    final isNotSupported = permState.status == HealthPermissionStatus.notSupported;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Health Connect Permissions'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Non-blocking Banner on Denial
              if (isDenied)
                Container(
                  margin: const EdgeInsets.only(bottom: 20),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade900.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.amber.shade700, width: 1.5),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning_amber_rounded, color: Colors.amber.shade700, size: 28),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Permissions Required',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.amber.shade200,
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Live dashboard updates require read access to Health Connect.',
                              style: TextStyle(fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: permState.isLoading
                            ? null
                            : () => permNotifier.requestPermissions(),
                        child: const Text('RETRY'),
                      ),
                    ],
                  ),
                ),

              if (isNotSupported)
                Container(
                  margin: const EdgeInsets.only(bottom: 20),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blueGrey.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blueGrey.shade400, width: 1.5),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.cyanAccent),
                      SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          'Health Connect is not installed or running in simulation mode. SimSource can be enabled for tests.',
                          style: TextStyle(fontSize: 13),
                        ),
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
                description: 'Reads real-time BPM streams and historical samples',
                icon: Icons.favorite_rounded,
                status: permState.status,
              ),

              const Spacer(),

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
                        isGranted ? 'Permissions Granted' : 'Request Permissions',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
