/// Hourly rollup aggregate entity as specified in Appendix A.
class HourlyAggregate {
  final String date; // YYYY-MM-DD
  final int hour; // 0-23
  final int steps;
  final int hrAvg;
  final int hrP95;

  const HourlyAggregate({
    required this.date,
    required this.hour,
    required this.steps,
    required this.hrAvg,
    required this.hrP95,
  });

  Map<String, dynamic> toMap() => {
        'date': date,
        'hour': hour,
        'steps': steps,
        'hr_avg': hrAvg,
        'hr_p95': hrP95,
      };

  factory HourlyAggregate.fromMap(Map<String, dynamic> map) => HourlyAggregate(
        date: map['date'] as String,
        hour: map['hour'] as int,
        steps: map['steps'] as int,
        hrAvg: map['hr_avg'] as int,
        hrP95: map['hr_p95'] as int,
      );
}

/// Daily rollup aggregate entity as specified in Appendix A.
class DailyAggregate {
  final String date; // YYYY-MM-DD
  final int steps;
  final int zone2Mins; // Minutes spent in Heart Rate Zone 2 (e.g. 100-140 bpm)
  final int activeMins; // Minutes with > 60 steps/min or elevated HR
  final bool hitTarget; // e.g. steps >= 8000 or custom goal

  const DailyAggregate({
    required this.date,
    required this.steps,
    required this.zone2Mins,
    required this.activeMins,
    required this.hitTarget,
  });

  Map<String, dynamic> toMap() => {
        'date': date,
        'steps': steps,
        'zone2_mins': zone2Mins,
        'active_mins': activeMins,
        'hit_target': hitTarget ? 1 : 0,
      };

  factory DailyAggregate.fromMap(Map<String, dynamic> map) => DailyAggregate(
        date: map['date'] as String,
        steps: map['steps'] as int,
        zone2Mins: map['zone2_mins'] as int,
        activeMins: map['active_mins'] as int,
        hitTarget: (map['hit_target'] as int) == 1,
      );
}
