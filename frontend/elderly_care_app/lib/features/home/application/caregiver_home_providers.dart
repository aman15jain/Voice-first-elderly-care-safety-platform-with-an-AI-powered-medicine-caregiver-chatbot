import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ai/data/ai_repository.dart';
import '../../medicines/data/medicines_repository.dart';
import '../../medicines/domain/medicine_models.dart';

/// Which linked elder the caregiver home is focused on. `null` means "the first one".
class SelectedElderNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void select(String elderId) => state = elderId;
}

final selectedElderIdProvider = NotifierProvider<SelectedElderNotifier, String?>(SelectedElderNotifier.new);

/// Today's doses for one elder, joined with their medicine names, as the backend reports
/// them. The counts below only tally the statuses the backend assigned — no adherence or
/// health logic is re-derived in the app.
class TodayCare {
  TodayCare(List<DoseView> doses) : doses = [...doses]..sort((a, b) => a.dose.scheduledFor.compareTo(b.dose.scheduledFor));

  final List<DoseView> doses;

  int get total => doses.length;
  int count(DoseStatus status) => doses.where((d) => d.dose.status == status).length;
  int get taken => count(DoseStatus.taken);
  int get missed => count(DoseStatus.missed);

  /// The earliest dose today still awaiting action (scheduled or reminded), if any.
  DoseView? get next {
    for (final d in doses) {
      if (d.dose.status == DoseStatus.scheduled || d.dose.status == DoseStatus.reminded) return d;
    }
    return null;
  }
}

/// Two calls, in parallel: today's doses and the medicine list (for names), both scoped to
/// [elderId] — the backend verifies the caregiver's accepted family link.
final elderTodayCareProvider = FutureProvider.autoDispose.family<TodayCare, String>((ref, elderId) async {
  final repo = ref.watch(medicinesRepositoryProvider);
  final List<MedicineDose> doses;
  final List<Medicine> medicines;
  try {
    (doses, medicines) = await (repo.listDoses(elderId: elderId), repo.listMedicines(elderId: elderId)).wait;
  } on ParallelWaitError<(List<MedicineDose>?, List<Medicine>?), (AsyncError?, AsyncError?)> catch (e) {
    // Surface the original failure (not the wrapper) so AppFailure can map it to a friendly message.
    final first = (e.errors.$1 ?? e.errors.$2)!;
    Error.throwWithStackTrace(first.error, first.stackTrace);
  }
  final byId = {for (final m in medicines) m.id: m};
  return TodayCare([for (final d in doses) DoseView(dose: d, medicine: byId[d.medicineId])]);
});

/// Elders the caregiver has asked Sathi AI about this session. Both AI entry points on the
/// home screen (the assistant card and the insight card) read this, so one request serves both.
class InsightRequestsNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() => const {};

  void request(String elderId) => state = {...state, elderId};
}

final insightRequestsProvider = NotifierProvider<InsightRequestsNotifier, Set<String>>(InsightRequestsNotifier.new);

/// The AI care insight for one elder. Only watched after the caregiver asks for it: each
/// call runs the LLM pipeline, so it is never fetched just because the home screen opened.
final caregiverInsightProvider = FutureProvider.autoDispose.family<CaregiverInsight, String>((ref, elderId) {
  return ref.watch(aiRepositoryProvider).getCaregiverInsight(elderId);
});
