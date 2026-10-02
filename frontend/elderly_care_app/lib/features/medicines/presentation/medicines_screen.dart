import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
                    padding: const EdgeInsets.all(16),
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
        label: const Text('Add Medicine', style: TextStyle(fontSize: 18)),
      ),
    );
  }
}

class _EmptyMedicines extends StatelessWidget {
  const _EmptyMedicines();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.medication_outlined, size: 64, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 16),
            Text('No medicines yet', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            const Text('Tap "Add Medicine" to get started.', textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _MedicineCard extends StatelessWidget {
  const _MedicineCard({required this.medicine});
  final Medicine medicine;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        leading: const Icon(Icons.medication, size: 36),
        title: Text(medicine.name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600)),
        subtitle: Text(medicine.dosage, style: const TextStyle(fontSize: 18)),
        trailing: const Icon(Icons.chevron_right, size: 32),
        onTap: () => context.push('/medicines/${medicine.id}', extra: medicine),
      ),
    );
  }
}
