enum DoseStatus { scheduled, reminded, taken, skipped, missed }

DoseStatus doseStatusFromString(String value) {
  switch (value) {
    case 'SCHEDULED':
      return DoseStatus.scheduled;
    case 'REMINDED':
      return DoseStatus.reminded;
    case 'TAKEN':
      return DoseStatus.taken;
    case 'SKIPPED':
      return DoseStatus.skipped;
    case 'MISSED':
      return DoseStatus.missed;
    default:
      return DoseStatus.scheduled;
  }
}

class Medicine {
  const Medicine({required this.id, required this.name, required this.dosage, required this.isActive, this.instructions});

  final String id;
  final String name;
  final String dosage;
  final String? instructions;
  final bool isActive;

  factory Medicine.fromJson(Map<String, dynamic> json) => Medicine(
    id: json['id'] as String,
    name: json['name'] as String,
    dosage: json['dosage'] as String,
    instructions: json['instructions'] as String?,
    isActive: json['isActive'] as bool,
  );
}

class MedicineSchedule {
  const MedicineSchedule({
    required this.id,
    required this.medicineId,
    required this.timesOfDay,
    required this.daysOfWeek,
    required this.startDate,
    required this.isActive,
    this.endDate,
  });

  final String id;
  final String medicineId;
  final List<String> timesOfDay;
  final List<int> daysOfWeek;
  final DateTime startDate;
  final DateTime? endDate;
  final bool isActive;

  factory MedicineSchedule.fromJson(Map<String, dynamic> json) => MedicineSchedule(
    id: json['id'] as String,
    medicineId: json['medicineId'] as String,
    timesOfDay: (json['timesOfDay'] as List).cast<String>(),
    daysOfWeek: (json['daysOfWeek'] as List).cast<int>(),
    startDate: DateTime.parse(json['startDate'] as String),
    endDate: json['endDate'] == null ? null : DateTime.parse(json['endDate'] as String),
    isActive: json['isActive'] as bool,
  );
}

class MedicineDose {
  const MedicineDose({required this.id, required this.medicineId, required this.scheduledFor, required this.status});

  final String id;
  final String medicineId;
  final DateTime scheduledFor;
  final DoseStatus status;

  factory MedicineDose.fromJson(Map<String, dynamic> json) => MedicineDose(
    id: json['id'] as String,
    medicineId: json['medicineId'] as String,
    scheduledFor: DateTime.parse(json['scheduledFor'] as String).toLocal(),
    status: doseStatusFromString(json['status'] as String),
  );
}

/// A dose joined with its medicine, assembled client-side for display
/// (see features/medicines/application/dose_view.dart).
class DoseView {
  const DoseView({required this.dose, this.medicine});
  final MedicineDose dose;
  final Medicine? medicine;

  String get medicineName => medicine?.name ?? 'Medicine';
  String get dosage => medicine?.dosage ?? '';
}

class AdherenceSummary {
  const AdherenceSummary({
    required this.from,
    required this.to,
    required this.scheduled,
    required this.reminded,
    required this.taken,
    required this.skipped,
    required this.missed,
    required this.totalDue,
    this.takenRate,
  });

  final String from;
  final String to;
  final int scheduled;
  final int reminded;
  final int taken;
  final int skipped;
  final int missed;
  final int totalDue;
  final int? takenRate;

  factory AdherenceSummary.fromJson(Map<String, dynamic> json) => AdherenceSummary(
    from: json['from'] as String,
    to: json['to'] as String,
    scheduled: json['scheduled'] as int,
    reminded: json['reminded'] as int,
    taken: json['taken'] as int,
    skipped: json['skipped'] as int,
    missed: json['missed'] as int,
    totalDue: json['totalDue'] as int,
    takenRate: json['takenRate'] as int?,
  );
}
