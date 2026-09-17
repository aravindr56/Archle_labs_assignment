import 'package:flutter/foundation.dart';

/// Manages horizontal pan, pinch-zoom scale, and touch inspection.
class ChartViewport {
  final double scaleX;
  final double panOffsetX;
  final int? selectedTimestamp;

  const ChartViewport({
    this.scaleX = 1.0,
    this.panOffsetX = 0.0,
    this.selectedTimestamp,
  });

  ChartViewport copyWith({
    double? scaleX,
    double? panOffsetX,
    int? selectedTimestamp,
    bool clearSelection = false,
  }) {
    return ChartViewport(
      scaleX: scaleX ?? this.scaleX,
      panOffsetX: panOffsetX ?? this.panOffsetX,
      selectedTimestamp:
          clearSelection ? null : (selectedTimestamp ?? this.selectedTimestamp),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChartViewport &&
          runtimeType == other.runtimeType &&
          scaleX == other.scaleX &&
          panOffsetX == other.panOffsetX &&
          selectedTimestamp == other.selectedTimestamp;

  @override
  int get hashCode =>
      scaleX.hashCode ^ panOffsetX.hashCode ^ selectedTimestamp.hashCode;
}
