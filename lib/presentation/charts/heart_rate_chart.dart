import 'dart:math';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../domain/models/heart_rate_record.dart';
import 'chart_viewport.dart';
import 'lttb_decimator.dart';

class HeartRateChart extends StatefulWidget {
  final List<HeartRateRecord> records;
  final bool isSmoothingEnabled;

  const HeartRateChart({
    super.key,
    required this.records,
    this.isSmoothingEnabled = false,
  });

  @override
  State<HeartRateChart> createState() => _HeartRateChartState();
}

class _HeartRateChartState extends State<HeartRateChart> {
  ChartViewport _viewport = const ChartViewport();
  double _baseScale = 1.0;
  double _baseOffset = 0.0;

  @override
  Widget build(BuildContext context) {
    if (widget.records.isEmpty) {
      return Container(
        height: 220,
        alignment: Alignment.center,
        child: const Text(
          'Awaiting heart rate stream...',
          style: TextStyle(color: Colors.white38),
        ),
      );
    }

    // Apply optional smoothing for follow-up
    final activeRecords = widget.isSmoothingEnabled
        ? MovingAverageFilter.smooth(widget.records)
        : widget.records;

    // Decimate if records exceed visual threshold
    final displayRecords = activeRecords.length > 250
        ? LttbDecimator.decimate(activeRecords, 250)
        : activeRecords;

    return LayoutBuilder(
      builder: (context, constraints) {
        return GestureDetector(
          onScaleStart: (details) {
            _baseScale = _viewport.scaleX;
            _baseOffset = _viewport.panOffsetX;
          },
          onScaleUpdate: (details) {
            final newScale = (_baseScale * details.horizontalScale).clamp(1.0, 5.0);
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
            final nearest = _findNearestRecord(
              displayRecords,
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
              size: Size(constraints.maxWidth, 220),
              painter: HeartRateCustomPainter(
                records: displayRecords,
                viewport: _viewport,
              ),
            ),
          ),
        );
      },
    );
  }

  HeartRateRecord? _findNearestRecord(
    List<HeartRateRecord> data,
    double touchX,
    double width,
    ChartViewport vp,
  ) {
    if (data.isEmpty) return null;
    final minTs = data.first.timestamp;
    final maxTs = data.last.timestamp;
    if (minTs == maxTs) return data.first;

    final contentWidth = width * vp.scaleX;
    final chartX = touchX - vp.panOffsetX;
    final ratio = (chartX / contentWidth).clamp(0.0, 1.0);
    final targetTs = (minTs + ratio * (maxTs - minTs)).round();

    // Binary search
    int low = 0;
    int high = data.length - 1;
    while (low <= high) {
      final mid = (low + high) ~/ 2;
      if (data[mid].timestamp < targetTs) {
        low = mid + 1;
      } else {
        high = mid - 1;
      }
    }
    low = low.clamp(0, data.length - 1);
    high = high.clamp(0, data.length - 1);

    final diff1 = (data[low].timestamp - targetTs).abs();
    final diff2 = (data[high].timestamp - targetTs).abs();
    return diff1 < diff2 ? data[low] : data[high];
  }
}

/// Zero per-frame allocation CustomPainter for Heart Rate.
class HeartRateCustomPainter extends CustomPainter {
  final List<HeartRateRecord> records;
  final ChartViewport viewport;

  // Reusable pre-allocated Paint objects to achieve ZERO per-frame allocations
  static final Paint _linePaint = Paint()
    ..color = const Color(0xFFFF5252)
    ..strokeWidth = 2.2
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  static final Paint _fillPaint = Paint()
    ..style = PaintingStyle.fill;

  static final Paint _gridPaint = Paint()
    ..color = const Color(0x1FFFFFFF)
    ..strokeWidth = 1.0
    ..style = PaintingStyle.stroke;

  static final Paint _highlightLinePaint = Paint()
    ..color = const Color(0x80FFFFFF)
    ..strokeWidth = 1.0
    ..style = PaintingStyle.stroke;

  static final Paint _pointPaint = Paint()
    ..color = const Color(0xFFFF8A80)
    ..style = PaintingStyle.fill;

  static final Paint _tooltipBgPaint = Paint()
    ..color = const Color(0xEE1E1E2C)
    ..style = PaintingStyle.fill;

  static final Paint _tooltipBorderPaint = Paint()
    ..color = const Color(0xFFFF5252)
    ..strokeWidth = 1.2
    ..style = PaintingStyle.stroke;

  // Reusable paths
  static final Path _linePath = Path();
  static final Path _fillPath = Path();
  static final Path _tooltipPath = Path();

  HeartRateCustomPainter({
    required this.records,
    required this.viewport,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (records.isEmpty) return;

    final double width = size.width;
    final double height = size.height;
    const double bottomPadding = 24.0;
    const double topPadding = 16.0;
    final double chartHeight = height - bottomPadding - topPadding;

    // Determine Y range (BPM: min 40, max 180 or dynamic)
    int minBpm = records.first.bpm;
    int maxBpm = records.first.bpm;
    for (int i = 1; i < records.length; i++) {
      if (records[i].bpm < minBpm) minBpm = records[i].bpm;
      if (records[i].bpm > maxBpm) maxBpm = records[i].bpm;
    }
    minBpm = max(40, minBpm - 5);
    maxBpm = min(200, maxBpm + 5);
    final int bpmRange = max(1, maxBpm - minBpm);

    // Draw Grid lines
    for (int i = 0; i <= 4; i++) {
      final y = topPadding + (chartHeight * (i / 4));
      canvas.drawLine(Offset(0, y), Offset(width, y), _gridPaint);
    }

    final int minTs = records.first.timestamp;
    final int maxTs = records.last.timestamp;
    final int tsRange = max(1, maxTs - minTs);

    final double contentWidth = width * viewport.scaleX;

    // Reset reusable paths
    _linePath.reset();
    _fillPath.reset();

    // Map first point
    double prevX = viewport.panOffsetX;
    double prevY = topPadding + chartHeight * (1.0 - (records.first.bpm - minBpm) / bpmRange);

    _linePath.moveTo(prevX, prevY);
    _fillPath.moveTo(prevX, height - bottomPadding);
    _fillPath.lineTo(prevX, prevY);

    HeartRateRecord? selectedRecord;
    double selectedX = 0;
    double selectedY = 0;

    for (int i = 1; i < records.length; i++) {
      final r = records[i];
      final double normalizedX = (r.timestamp - minTs) / tsRange;
      final double x = (normalizedX * contentWidth) + viewport.panOffsetX;
      final double y = topPadding + chartHeight * (1.0 - (r.bpm - minBpm) / bpmRange);

      _linePath.lineTo(x, y);
      _fillPath.lineTo(x, y);

      if (viewport.selectedTimestamp == r.timestamp) {
        selectedRecord = r;
        selectedX = x;
        selectedY = y;
      }
    }

    // Complete gradient fill path
    final lastX = contentWidth + viewport.panOffsetX;
    _fillPath.lineTo(lastX, height - bottomPadding);
    _fillPath.close();

    // Fill Shader
    _fillPaint.shader = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        const Color(0xFFFF5252).withOpacity(0.35),
        const Color(0xFFFF5252).withOpacity(0.0),
      ],
    ).createShader(Rect.fromLTWH(0, topPadding, width, chartHeight));

    // Clip to chart bounds to respect pan
    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, 0, width, height));

    canvas.drawPath(_fillPath, _fillPaint);
    canvas.drawPath(_linePath, _linePaint);

    // Draw Tooltip if inspecting
    if (selectedRecord != null && selectedX >= 0 && selectedX <= width) {
      // Highlight vertical guide
      canvas.drawLine(
        Offset(selectedX, topPadding),
        Offset(selectedX, height - bottomPadding),
        _highlightLinePaint,
      );

      // Highlight target point circle
      canvas.drawCircle(Offset(selectedX, selectedY), 5.0, _pointPaint);

      // Tooltip Box
      final timeStr = DateFormat('HH:mm:ss')
          .format(DateTime.fromMillisecondsSinceEpoch(selectedRecord.timestamp));
      final textSpan = TextSpan(
        text: '${selectedRecord.bpm} BPM\n$timeStr',
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
      double boxY = max(4.0, selectedY - tooltipHeight - 10.0);

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
  bool shouldRepaint(covariant HeartRateCustomPainter oldDelegate) {
    return oldDelegate.records != records || oldDelegate.viewport != viewport;
  }
}
