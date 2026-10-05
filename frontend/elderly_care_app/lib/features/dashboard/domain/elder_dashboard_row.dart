import '../../medicines/domain/medicine_models.dart';

class ElderActivitySummary {
  const ElderActivitySummary({required this.daysInRange, required this.activeDays, required this.medicineInteractionDays, required this.gameSessionDays});

  final int daysInRange;
  final int activeDays;
  final int medicineInteractionDays;
  final int gameSessionDays;

  factory ElderActivitySummary.fromJson(Map<String, dynamic> json) => ElderActivitySummary(
    daysInRange: json['daysInRange'] as int,
    activeDays: json['activeDays'] as int,
    medicineInteractionDays: json['medicineInteractionDays'] as int,
    gameSessionDays: json['gameSessionDays'] as int,
  );
}

/// One row of the caregiver dashboard: everything already known about one linked elder,
/// fetched in a single call to GET /api/family/dashboard.
class ElderDashboardRow {
  const ElderDashboardRow({
    required this.elderId,
    required this.elderName,
    required this.elderEmail,
    required this.adherence,
    required this.activity,
    required this.activeEmergency,
  });

  final String elderId;
  final String? elderName;
  final String elderEmail;
  final AdherenceSummary adherence;
  final ElderActivitySummary activity;
  final bool activeEmergency;

  String get displayName => (elderName?.trim().isNotEmpty == true) ? elderName! : elderEmail;

  factory ElderDashboardRow.fromJson(Map<String, dynamic> json) => ElderDashboardRow(
    elderId: json['elderId'] as String,
    elderName: json['elderName'] as String?,
    elderEmail: json['elderEmail'] as String,
    adherence: AdherenceSummary.fromJson(json['adherence'] as Map<String, dynamic>),
    activity: ElderActivitySummary.fromJson(json['activity'] as Map<String, dynamic>),
    activeEmergency: json['activeEmergency'] as bool,
  );
}

/// One day of a per-elder adherence trend (GET /api/adherence/trend).
class DailyAdherencePoint {
  const DailyAdherencePoint({required this.date, required this.taken, required this.totalDue, this.takenRate});

  final String date;
  final int taken;
  final int totalDue;
  final int? takenRate;

  factory DailyAdherencePoint.fromJson(Map<String, dynamic> json) =>
      DailyAdherencePoint(date: json['date'] as String, taken: json['taken'] as int, totalDue: json['totalDue'] as int, takenRate: json['takenRate'] as int?);
}
