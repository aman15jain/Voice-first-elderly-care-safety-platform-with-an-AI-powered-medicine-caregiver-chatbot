class DailyActivity {
  const DailyActivity({required this.date, required this.medicineInteractions, required this.gameSessions, required this.active});

  final String date;
  final int medicineInteractions;
  final int gameSessions;
  final bool active;

  factory DailyActivity.fromJson(Map<String, dynamic> json) => DailyActivity(
    date: json['date'] as String,
    medicineInteractions: json['medicineInteractions'] as int,
    gameSessions: json['gameSessions'] as int,
    active: json['active'] as bool,
  );
}
