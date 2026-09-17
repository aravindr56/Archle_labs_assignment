import 'dart:ui';
import 'package:flutter/material.dart';

/// Lightweight Performance HUD capturing Flutter engine FrameTimings.
/// Displays rolling average build time (target <= 8ms), raster time, and FPS.
class PerformanceHud extends StatefulWidget {
  final bool isVisible;

  const PerformanceHud({
    super.key,
    this.isVisible = true,
  });

  @override
  State<PerformanceHud> createState() => _PerformanceHudState();
}

class _PerformanceHudState extends State<PerformanceHud> {
  final List<double> _buildTimes = [];
  final List<double> _rasterTimes = [];
  double _avgBuildTime = 0.0;
  double _lastRasterTime = 0.0;
  double _fps = 60.0;
  int _jankCount = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addTimingsCallback(_onTimings);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeTimingsCallback(_onTimings);
    super.dispose();
  }

  void _onTimings(List<FrameTiming> timings) {
    if (!mounted || !widget.isVisible) return;

    for (final timing in timings) {
      final buildMs = timing.buildDuration.inMicroseconds / 1000.0;
      final rasterMs = timing.rasterDuration.inMicroseconds / 1000.0;
      final totalMs = timing.totalSpan.inMicroseconds / 1000.0;

      if (totalMs > 16.67) {
        _jankCount++;
      }

      _buildTimes.add(buildMs);
      _rasterTimes.add(rasterMs);

      if (_buildTimes.length > 60) {
        _buildTimes.removeAt(0);
        _rasterTimes.removeAt(0);
      }
    }

    if (_buildTimes.isNotEmpty) {
      final sum = _buildTimes.reduce((a, b) => a + b);
      final avg = sum / _buildTimes.length;
      final lastRaster = _rasterTimes.last;

      // Estimate FPS based on frame interval or total span
      final lastTotal = timings.last.totalSpan.inMilliseconds;
      final estFps =
          lastTotal > 0 ? (1000.0 / lastTotal).clamp(10.0, 60.0) : 60.0;

      setState(() {
        _avgBuildTime = avg;
        _lastRasterTime = lastRaster;
        _fps = estFps;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isVisible) return const SizedBox.shrink();

    final isBuildUnderTarget = _avgBuildTime <= 8.0;

    return Container(
      key: const Key('performance_hud_container'),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xDD12121E),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isBuildUnderTarget
              ? const Color(0xFF00E676)
              : const Color(0xFFFF5252),
          width: 1.2,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.speed_rounded,
            size: 16,
            color: isBuildUnderTarget
                ? const Color(0xFF00E676)
                : const Color(0xFFFF5252),
          ),
          const SizedBox(width: 8),
          Text(
            'Build: ${_avgBuildTime.toStringAsFixed(1)}ms',
            key: const Key('perf_hud_build_time'),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: isBuildUnderTarget ? Colors.greenAccent : Colors.redAccent,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            'Raster: ${_lastRasterTime.toStringAsFixed(1)}ms',
            style: const TextStyle(fontSize: 11, color: Colors.white70),
          ),
          const SizedBox(width: 10),
          Text(
            'FPS: ${_fps.toStringAsFixed(0)}',
            key: const Key('perf_hud_fps'),
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Colors.cyanAccent,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            'Jank: $_jankCount',
            key: const Key('perf_hud_jank'),
            style: TextStyle(
              fontSize: 11,
              color: _jankCount == 0 ? Colors.greenAccent : Colors.orangeAccent,
            ),
          ),
        ],
      ),
    );
  }
}
