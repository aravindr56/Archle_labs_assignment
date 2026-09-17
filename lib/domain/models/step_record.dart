/// Represents a single discrete steps reading.
class StepRecord {
  final int timestamp; // epoch milliseconds
  final int count;

  const StepRecord({
    required this.timestamp,
    required this.count,
  });

  Map<String, dynamic> toMap() => {
        'ts': timestamp,
        'count': count,
      };

  factory StepRecord.fromMap(Map<String, dynamic> map) => StepRecord(
        timestamp: map['ts'] as int,
        count: map['count'] as int,
      );

  DateTime get dateTime => DateTime.fromMillisecondsSinceEpoch(timestamp);
}
