import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/widgets/care/care_states.dart';
import '../../../shared/widgets/care/care_pill.dart';
import '../../../core/theme/care_tokens.dart';
import '../../../core/errors/app_failure.dart';
import '../../../shared/widgets/error_view.dart';
import '../../../shared/widgets/loading_view.dart';
import '../application/medicines_providers.dart';
import '../domain/medicine_models.dart';

/// The elder's medicine cabinet: every active medicine, with a big button to add one.
class MedicinesScreen extends ConsumerWidget {
  const MedicinesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final medicines = ref.watch(medicinesListProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('My Medicines')),
      body: SafeArea(
        child: medicines.when(
          loading: () => const LoadingView(),
          error: (e, _) => ErrorView(message: AppFailure.fromError(e).message, onRetry: () => ref.invalidate(medicinesListProvider)),
          data: (list) => list.isEmpty
              ? const _EmptyMedicines()
              : RefreshIndicator(
                  onRefresh: () async => ref.invalidate(medicinesListProvider),
                  child: ListView.separated(
                    // Bottom padding keeps the last card clear of the floating Add button.
                    padding: const EdgeInsets.fromLTRB(CareSpacing.screenH - 4, CareSpacing.sm, CareSpacing.screenH - 4, 104),
                    itemCount: list.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, i) => _MedicineCard(medicine: list[i]),
                  ),
                ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/medicines/add'),
        icon: const Icon(Icons.add),
        label: const Text('Add Medicine'),
      ),
    );
  }
}

class _EmptyMedicines extends StatelessWidget {
  const _EmptyMedicines();

  @override
  Widget build(BuildContext context) {
    return const CareEmptyState(
      icon: Icons.medication_outlined,
      iconColor: CareColors.accentWarm,
      iconBackground: CareColors.accentWarmSoft,
      title: 'No medicines yet',
      message: 'Tap "Add Medicine" to get started.',
    );
  }
}

class _MedicineCard extends StatelessWidget {
  const _MedicineCard({required this.medicine});
  final Medicine medicine;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: CareSpacing.lg, vertical: CareSpacing.sm),
        leading: const CareIconTile(icon: Icons.medication, color: CareColors.accentWarm, background: CareColors.accentWarmSoft),
        title: Text(medicine.name),
        subtitle: Text(medicine.dosage),
        trailing: const Icon(Icons.chevron_right, size: 30, color: CareColors.textMuted),
        onTap: () => context.push('/medicines/${medicine.id}', extra: medicine),
      ),
    );
  }
}
