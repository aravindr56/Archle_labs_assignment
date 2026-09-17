/// Represents a single discrete heart rate reading in beats per minute (BPM).
class HeartRateRecord {
  final int timestamp; // epoch milliseconds
  final int bpm;

  const HeartRateRecord({
    required this.timestamp,
    required this.bpm,
  });

  Map<String, dynamic> toMap() => {
        'ts': timestamp,
        'bpm': bpm,
      };

  factory HeartRateRecord.fromMap(Map<String, dynamic> map) => HeartRateRecord(
        timestamp: map['ts'] as int,
        bpm: map['bpm'] as int,
      );

  DateTime get dateTime => DateTime.fromMillisecondsSinceEpoch(timestamp);
}
