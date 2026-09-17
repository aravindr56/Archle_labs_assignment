import 'dart:math';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;
import '../../domain/models/step_record.dart';
import 'chart_viewport.dart';

class StepsChart extends StatefulWidget {
  final List<StepRecord> records;
  final int windowMinutes; // 60 default, or 30 for follow-up

  const StepsChart({
    super.key,
    required this.records,
    this.windowMinutes = 60,
  });

  @override
  State<StepsChart> createState() => _StepsChartState();
}

class _StepsChartState extends State<StepsChart> {
  ChartViewport _viewport = const ChartViewport();
  double _baseScale = 1.0;
  double _baseOffset = 0.0;

  @override
  Widget build(BuildContext context) {
    if (widget.records.isEmpty) {
      return Container(
        height: 200,
        alignment: Alignment.center,
        child: const Text(
          'Awaiting steps stream...',
          style: TextStyle(color: Colors.white38),
        ),
      );
    }

    // Decimation/Bucketing Strategy:
    // Partition the window into N discrete 1-minute buckets (e.g. 60 buckets for 60m, 30 buckets for 30m)
    final buckets = _aggregateIntoBuckets(widget.records, widget.windowMinutes);

    return LayoutBuilder(
      builder: (context, constraints) {
        return GestureDetector(
          onScaleStart: (details) {
            _baseScale = _viewport.scaleX;
            _baseOffset = _viewport.panOffsetX;
          },
          onScaleUpdate: (details) {
            final newScale = (_baseScale * details.horizontalScale).clamp(1.0, 4.0);
            final maxPan = (newScale - 1.0) * constraints.maxWidth;
            final newPan = (_baseOffset + details.focalPointDelta.dx).clamp(-maxPan, 0.0);

            setState(() {
              _viewport = _viewport.copyWith(
                scaleX: newScale,
                panOffsetX: newPan,
              );
            });
          },
          onTapDown: (details) {
            final touchX = details.localPosition.dx;
            final nearest = _findNearestBucket(
              buckets,
              touchX,
              constraints.maxWidth,
              _viewport,
            );
            setState(() {
              _viewport = _viewport.copyWith(selectedTimestamp: nearest?.timestamp);
            });
          },
          onTapUp: (_) {
            Future.delayed(const Duration(seconds: 3), () {
              if (mounted) {
                setState(() {
                  _viewport = _viewport.copyWith(clearSelection: true);
                });
              }
            });
          },
          child: RepaintBoundary(
            child: CustomPaint(
              size: Size(constraints.maxWidth, 200),
              painter: StepsCustomPainter(
                buckets: buckets,
                viewport: _viewport,
              ),
            ),
          ),
        );
      },
    );
  }

  List<StepRecord> _aggregateIntoBuckets(List<StepRecord> rawRecords, int windowMins) {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    const bucketDurationMs = 60 * 1000; // 1-minute buckets
    final totalBuckets = windowMins;

    final startMs = nowMs - (totalBuckets * bucketDurationMs);
    final Map<int, int> bucketSums = {};

    for (int i = 0; i < totalBuckets; i++) {
      bucketSums[startMs + (i * bucketDurationMs)] = 0;
    }

    for (final r in rawRecords) {
      if (r.timestamp < startMs) continue;
      // Find bucket index
      final idx = ((r.timestamp - startMs) / bucketDurationMs).floor();
      if (idx >= 0 && idx < totalBuckets) {
        final bucketTs = startMs + (idx * bucketDurationMs);
        bucketSums[bucketTs] = (bucketSums[bucketTs] ?? 0) + r.count;
      }
    }

    final List<StepRecord> result = [];
    final sortedKeys = bucketSums.keys.toList()..sort();
    for (final ts in sortedKeys) {
      result.add(StepRecord(timestamp: ts, count: bucketSums[ts] ?? 0));
    }
    return result;
  }

  StepRecord? _findNearestBucket(
    List<StepRecord> data,
    double touchX,
    double width,
    ChartViewport vp,
  ) {
    if (data.isEmpty) return null;
    final contentWidth = width * vp.scaleX;
    final chartX = touchX - vp.panOffsetX;
    final bucketWidth = contentWidth / data.length;
    final index = (chartX / bucketWidth).floor().clamp(0, data.length - 1);
    return data[index];
  }
}

/// Zero per-frame allocation CustomPainter for Steps.
class StepsCustomPainter extends CustomPainter {
  final List<StepRecord> buckets;
  final ChartViewport viewport;

  static final Paint _barPaint = Paint()
    ..style = PaintingStyle.fill;

  static final Paint _gridPaint = Paint()
    ..color = const Color(0x1FFFFFFF)
    ..strokeWidth = 1.0
    ..style = PaintingStyle.stroke;

  static final Paint _tooltipBgPaint = Paint()
    ..color = const Color(0xEE1E1E2C)
    ..style = PaintingStyle.fill;

  static final Paint _tooltipBorderPaint = Paint()
    ..color = const Color(0xFF00E676)
    ..strokeWidth = 1.2
    ..style = PaintingStyle.stroke;

  StepsCustomPainter({
    required this.buckets,
    required this.viewport,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (buckets.isEmpty) return;

    final double width = size.width;
    final double height = size.height;
    const double bottomPadding = 24.0;
    const double topPadding = 16.0;
    final double chartHeight = height - bottomPadding - topPadding;

    int maxCount = 10;
    for (final b in buckets) {
      if (b.count > maxCount) maxCount = b.count;
    }
    maxCount = (maxCount * 1.15).ceil();

    // Draw grid lines
    for (int i = 0; i <= 3; i++) {
      final y = topPadding + (chartHeight * (i / 3));
      canvas.drawLine(Offset(0, y), Offset(width, y), _gridPaint);
    }

    final double contentWidth = width * viewport.scaleX;
    final double barSlotWidth = contentWidth / buckets.length;
    final double barWidth = max(2.0, barSlotWidth * 0.7);

    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, 0, width, height));

    StepRecord? selectedBucket;
    double selectedX = 0;
    double selectedY = 0;

    for (int i = 0; i < buckets.length; i++) {
      final b = buckets[i];
      final double x = (i * barSlotWidth) + viewport.panOffsetX + (barSlotWidth - barWidth) / 2;
      final double barH = (b.count / maxCount) * chartHeight;
      final double y = topPadding + (chartHeight - barH);

      final isSelected = viewport.selectedTimestamp == b.timestamp;

      _barPaint.shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: isSelected
            ? [const Color(0xFFB9F6CA), const Color(0xFF00E676)]
            : [const Color(0xFF00E676), const Color(0xFF00B0FF)],
      ).createShader(Rect.fromLTWH(x, y, barWidth, barH));

      final rrect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, y, barWidth, max(2.0, barH)),
        const Radius.circular(3.0),
      );

      canvas.drawRRect(rrect, _barPaint);

      if (isSelected) {
        selectedBucket = b;
        selectedX = x + (barWidth / 2);
        selectedY = y;
      }
    }

    // Draw Tooltip
    if (selectedBucket != null && selectedX >= 0 && selectedX <= width) {
      final timeStr = DateFormat('HH:mm')
          .format(DateTime.fromMillisecondsSinceEpoch(selectedBucket.timestamp));
      final textSpan = TextSpan(
        text: '${selectedBucket.count} steps\nat $timeStr',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.bold,
          height: 1.3,
        ),
      );
      final textPainter = TextPainter(
        text: textSpan,
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      )..layout();

      const double pad = 8.0;
      final tooltipWidth = textPainter.width + pad * 2;
      final tooltipHeight = textPainter.height + pad * 2;

      double boxX = (selectedX - tooltipWidth / 2).clamp(4.0, width - tooltipWidth - 4.0);
      double boxY = max(4.0, selectedY - tooltipHeight - 8.0);

      final rrect = RRect.fromRectAndRadius(
        Rect.fromLTWH(boxX, boxY, tooltipWidth, tooltipHeight),
        const Radius.circular(8.0),
      );

      canvas.drawRRect(rrect, _tooltipBgPaint);
      canvas.drawRRect(rrect, _tooltipBorderPaint);
      textPainter.paint(canvas, Offset(boxX + pad, boxY + pad));
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant StepsCustomPainter oldDelegate) {
    return oldDelegate.buckets != buckets || oldDelegate.viewport != viewport;
  }
}
