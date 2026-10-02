import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/storage/local_cache.dart';
import '../data/medicines_repository.dart';
import '../domain/medicine_models.dart';

final medicinesListProvider = FutureProvider.autoDispose<List<Medicine>>((ref) {
  return ref.watch(medicinesRepositoryProvider).listMedicines();
});

final todayDosesProvider = FutureProvider.autoDispose<List<MedicineDose>>((ref) {
  return ref.watch(medicinesRepositoryProvider).listDoses();
});

final adherenceSummaryProvider = FutureProvider.autoDispose<AdherenceSummary>((ref) {
  return ref.watch(medicinesRepositoryProvider).adherenceSummary();
});

final medicineSchedulesProvider = FutureProvider.family.autoDispose<List<MedicineSchedule>, String>((ref, medicineId) {
  return ref.watch(medicinesRepositoryProvider).listSchedules(medicineId: medicineId);
});

/// Whether `todayScheduleProvider`'s current value came from the network or from the local
/// cache (and if cached, when it was fetched) — a side channel rather than changing that
/// provider's type, so every existing consumer (`nextDoseProvider`, the schedule screen) keeps
/// working unchanged, and only screens that want to show "showing saved data from..." read this.
class ScheduleFreshness {
  const ScheduleFreshness({required this.fromCache, this.cachedAt});
  final bool fromCache;
  final DateTime? cachedAt;
  static const fresh = ScheduleFreshness(fromCache: false);
}

class ScheduleFreshnessNotifier extends Notifier<ScheduleFreshness> {
  @override
  ScheduleFreshness build() => ScheduleFreshness.fresh;
  void update(ScheduleFreshness value) => state = value;
}

final scheduleFreshnessProvider = NotifierProvider<ScheduleFreshnessNotifier, ScheduleFreshness>(ScheduleFreshnessNotifier.new);

Map<String, dynamic> _doseViewToCacheJson(DoseView v) => {
  'doseId': v.dose.id,
  'medicineId': v.dose.medicineId,
  'scheduledFor': v.dose.scheduledFor.toIso8601String(),
  'status': v.dose.status.name,
  'medicineName': v.medicine?.name,
  'dosage': v.medicine?.dosage,
};

DoseStatus _statusFromCacheName(String name) => DoseStatus.values.firstWhere((s) => s.name == name, orElse: () => DoseStatus.scheduled);

DoseView _doseViewFromCacheJson(Map<String, dynamic> json) {
  final medicineName = json['medicineName'] as String?;
  return DoseView(
    dose: MedicineDose(
      id: json['doseId'] as String,
      medicineId: json['medicineId'] as String,
      scheduledFor: DateTime.parse(json['scheduledFor'] as String),
      status: _statusFromCacheName(json['status'] as String),
    ),
    medicine: medicineName == null ? null : Medicine(id: json['medicineId'] as String, name: medicineName, dosage: json['dosage'] as String? ?? '', isActive: true),
  );
}

/// Joins today's doses to their medicine (name/dosage) for display, with an offline fallback:
/// a genuine network failure (no response at all — see `AppFailure.isNetworkError`) falls back
/// to the last successfully-fetched schedule instead of an error screen. A real 4xx/5xx is not
/// swallowed this way — only "we couldn't reach the server at all" is.
final todayScheduleProvider = FutureProvider.autoDispose<List<DoseView>>((ref) async {
  final cache = ref.watch(localCacheProvider);
  try {
    final medicines = await ref.watch(medicinesListProvider.future);
    final doses = await ref.watch(todayDosesProvider.future);
    final byId = {for (final m in medicines) m.id: m};
    final views = doses.map((d) => DoseView(dose: d, medicine: byId[d.medicineId])).toList()
      ..sort((a, b) => a.dose.scheduledFor.compareTo(b.dose.scheduledFor));

    ref.read(scheduleFreshnessProvider.notifier).update(ScheduleFreshness.fresh);
    unawaited(cache.saveTodaysSchedule(views.map(_doseViewToCacheJson).toList()));
    return views;
  } catch (e) {
    if (!AppFailure.isNetworkError(e)) rethrow;
    final cached = await cache.readTodaysSchedule();
    if (cached == null) rethrow;

    ref.read(scheduleFreshnessProvider.notifier).update(ScheduleFreshness(fromCache: true, cachedAt: cached.cachedAt));
    return cached.doses.map(_doseViewFromCacheJson).toList();
  }
});

/// The next dose that's still pending today (scheduled or reminded), for the Home screen.
final nextDoseProvider = FutureProvider.autoDispose<DoseView?>((ref) async {
  final views = await ref.watch(todayScheduleProvider.future);
  for (final v in views) {
    if (v.dose.status == DoseStatus.scheduled || v.dose.status == DoseStatus.reminded) return v;
  }
  return null;
});
