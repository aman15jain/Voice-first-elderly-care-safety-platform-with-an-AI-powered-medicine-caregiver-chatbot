import 'package:elderly_care_app/features/medicines/domain/medicine_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('doseStatusFromString maps every backend status', () {
    expect(doseStatusFromString('SCHEDULED'), DoseStatus.scheduled);
    expect(doseStatusFromString('REMINDED'), DoseStatus.reminded);
    expect(doseStatusFromString('TAKEN'), DoseStatus.taken);
    expect(doseStatusFromString('SKIPPED'), DoseStatus.skipped);
    expect(doseStatusFromString('MISSED'), DoseStatus.missed);
  });

  test('MedicineDose.fromJson converts scheduledFor to local time', () {
    final dose = MedicineDose.fromJson({'id': 'd1', 'medicineId': 'm1', 'scheduledFor': '2026-01-01T08:00:00.000Z', 'status': 'SCHEDULED'});
    expect(dose.scheduledFor.isUtc, isFalse);
    expect(dose.scheduledFor.toUtc().toIso8601String(), '2026-01-01T08:00:00.000Z');
  });

  test('DoseView falls back to a generic label when the medicine is missing', () {
    final view = DoseView(
      dose: MedicineDose(id: 'd1', medicineId: 'm1', scheduledFor: DateTime(2026, 1, 1), status: DoseStatus.scheduled),
    );
    expect(view.medicineName, 'Medicine');
    expect(view.dosage, '');
  });
}
