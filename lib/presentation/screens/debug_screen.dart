import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/config/app_config.dart';
import '../providers/app_providers.dart';

class DebugScreen extends ConsumerWidget {
  const DebugScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (kReleaseMode) {
      return Scaffold(
        appBar: AppBar(title: const Text('Access Denied')),
        body: const Center(
          child: Text('Debug tools are strictly disabled in release builds.'),
        ),
      );
    }

    final dashboard = ref.watch(dashboardProvider);
    final notifier = ref.read(dashboardProvider.notifier);
    final repo = ref.read(healthRepositoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Debug & Simulation Tools'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Anti-Plagiarism & Integrity Card
          Card(
            color: const Color(0xFF1B1D2C),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: const BorderSide(color: Color(0xFF00E676)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.verified_user_rounded, color: Color(0xFF00E676)),
                      SizedBox(width: 8),
                      Text(
                        'Anti-Plagiarism SALT Ledger',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Package: ${AppConfig.packageName}',
                    style: TextStyle(fontSize: 12, color: Colors.white70),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Commit: ${AppConfig.firstGitCommitHash.substring(0, 10)}...',
                    style: const TextStyle(fontSize: 12, color: Colors.white70),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.black38,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const SelectableText(
                      AppConfig.salt,
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 11,
                        color: Color(0xFF00E676),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.check_circle, size: 14, color: Color(0xFF00E676)),
                      const SizedBox(width: 6),
                      Text(
                        'Integrity Verified: ${AppConfig.verifyIntegrity()}',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF00E676)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // SimSource Realtime Toggle
          Card(
            color: const Color(0xFF1B1D2C),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            child: SwitchListTile(
              key: const Key('sim_source_switch'),
              title: const Text(
                'SimSource Stream Generator',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: const Text(
                'Emits synthetic step & HR updates through the exact same stream interface used by Health Connect',
                style: TextStyle(fontSize: 12, color: Colors.white60),
              ),
              value: dashboard.isSimSourceActive,
              activeColor: const Color(0xFF00E676),
              onChanged: (bool value) async {
                await notifier.toggleSimSource(value);
              },
            ),
          ),
          const SizedBox(height: 16),

          // Appendix B: Local DB Seeding Menu
          Card(
            color: const Color(0xFF1B1D2C),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Appendix B: Offline DB Seeding',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Injects deterministic synthetic datasets into the local SQLite database for golden and integration tests without network or Health Connect writes.',
                    style: TextStyle(fontSize: 12, color: Colors.white60),
                  ),
                  const SizedBox(height: 14),
                  ElevatedButton.icon(
                    key: const Key('seed_database_button'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2E3249),
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () async {
                      await notifier.seedSyntheticData();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Synthetic dataset injected into SQLite!')),
                        );
                      }
                    },
                    icon: const Icon(Icons.storage_rounded),
                    label: const Text('Seed Synthetic Dataset'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Retention Compaction Trigger
          Card(
            color: const Color(0xFF1B1D2C),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Nightly Compaction Task',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Enforces 7-day raw data retention and 30-day aggregate retention policies.',
                    style: TextStyle(fontSize: 12, color: Colors.white60),
                  ),
                  const SizedBox(height: 14),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final stats = await repo.runCompaction();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Compacted: $stats')),
                        );
                      }
                    },
                    icon: const Icon(Icons.cleaning_services_rounded),
                    label: const Text('Run Compaction Now'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
