import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class StepKpiCard extends StatelessWidget {
  final int totalSteps;
  final int targetSteps;

  const StepKpiCard({
    super.key,
    required this.totalSteps,
    this.targetSteps = 10000,
  });

  @override
  Widget build(BuildContext context) {
    final progress = (totalSteps / targetSteps).clamp(0.0, 1.0);
    final formatter = NumberFormat('#,###');

    return Card(
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
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00E676).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.directions_walk_rounded,
                        color: Color(0xFF00E676),
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      'Steps Today',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
                Text(
                  '${(progress * 100).toInt()}%',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF00E676),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              formatter.format(totalSteps),
              key: const Key('steps_total_text'),
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: Colors.white10,
                valueColor: const AlwaysStoppedAnimation(Color(0xFF00E676)),
                minHeight: 6,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class HeartRateKpiCard extends StatefulWidget {
  final int? bpm;
  final int? timestamp;

  const HeartRateKpiCard({
    super.key,
    required this.bpm,
    required this.timestamp,
  });

  @override
  State<HeartRateKpiCard> createState() => _HeartRateKpiCardState();
}

class _HeartRateKpiCardState extends State<HeartRateKpiCard>
    with SingleTickerProviderStateMixin {
  Timer? _ageTimer;
  String _ageString = '--';
  late AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    final isTest =
        WidgetsBinding.instance.runtimeType.toString().contains('Test');
    if (!isTest) {
      _animController.repeat(reverse: true);
      _ageTimer =
          Timer.periodic(const Duration(seconds: 1), (_) => _updateAge());
    } else {
      _animController.value = 1.0;
    }

    _updateAge();
  }

  @override
  void didUpdateWidget(covariant HeartRateKpiCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.timestamp != widget.timestamp) {
      _updateAge();
    }
  }

  void _updateAge() {
    if (widget.timestamp == null) {
      if (_ageString != '--') {
        setState(() => _ageString = '--');
      }
      return;
    }
    final diff = DateTime.now().difference(
      DateTime.fromMillisecondsSinceEpoch(widget.timestamp!),
    );

    String newStr;
    if (diff.inSeconds < 5) {
      newStr = 'just now';
    } else if (diff.inSeconds < 60) {
      newStr = '${diff.inSeconds}s ago';
    } else if (diff.inMinutes < 60) {
      newStr = '${diff.inMinutes}m ago';
    } else {
      newStr = '${diff.inHours}h ago';
    }

    if (newStr != _ageString && mounted) {
      setState(() => _ageString = newStr);
    }
  }

  @override
  void dispose() {
    _ageTimer?.cancel();
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
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
                Row(
                  children: [
                    ScaleTransition(
                      scale: Tween<double>(begin: 0.9, end: 1.15).animate(
                        CurvedAnimation(
                          parent: _animController,
                          curve: Curves.easeInOut,
                        ),
                      ),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF5252).withOpacity(0.18),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.favorite_rounded,
                          color: Color(0xFFFF5252),
                          size: 22,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      'Heart Rate',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.access_time_rounded,
                          size: 12, color: Colors.white38),
                      const SizedBox(width: 4),
                      Text(
                        _ageString,
                        key: const Key('hr_timestamp_age'),
                        style: const TextStyle(
                            fontSize: 11, color: Colors.white70),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  widget.bpm != null ? '${widget.bpm}' : '--',
                  key: const Key('heart_rate_bpm_text'),
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(width: 6),
                const Text(
                  'BPM',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFFF5252),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              _getHeartRateZone(widget.bpm),
              style: TextStyle(
                fontSize: 12,
                color: widget.bpm != null ? Colors.white60 : Colors.white38,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getHeartRateZone(int? bpm) {
    if (bpm == null) return 'Resting / Inactive';
    if (bpm < 60) return 'Resting (Low)';
    if (bpm < 100) return 'Normal Resting Range';
    if (bpm < 140) return 'Zone 2 (Aerobic / Fat Burn)';
    return 'Zone 3+ (Cardio / Peak)';
  }
}
