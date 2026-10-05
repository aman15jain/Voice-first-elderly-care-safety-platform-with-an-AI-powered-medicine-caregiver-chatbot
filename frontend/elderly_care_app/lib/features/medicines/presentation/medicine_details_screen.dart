import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/app_failure.dart';
import '../../../shared/widgets/big_button.dart';
import '../../../shared/widgets/confirm_dialog.dart';
import '../../../shared/widgets/error_view.dart';
import '../../../shared/widgets/loading_view.dart';
import '../application/medicines_providers.dart';
import '../data/medicines_repository.dart';
import 'schedule_time_format.dart';
import '../domain/medicine_models.dart';

class MedicineDetailsScreen extends ConsumerStatefulWidget {
  const MedicineDetailsScreen({required this.medicine, super.key});
  final Medicine medicine;

  @override
  ConsumerState<MedicineDetailsScreen> createState() => _MedicineDetailsScreenState();
}

class _MedicineDetailsScreenState extends ConsumerState<MedicineDetailsScreen> {
  bool _isDeleting = false;

  Future<void> _delete() async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Delete Medicine?',
      message: 'Remove "${widget.medicine.name}" from your medicine list? Past history is kept.',
      confirmLabel: 'Delete',
      isDestructive: true,
    );
    if (!confirmed) return;

    setState(() => _isDeleting = true);
    try {
      await ref.read(medicinesRepositoryProvider).deleteMedicine(widget.medicine.id);
      ref.invalidate(medicinesListProvider);
      ref.invalidate(todayDosesProvider);
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppFailure.fromError(e).message)));
      }
    } finally {
      if (mounted) setState(() => _isDeleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final schedules = ref.watch(medicineSchedulesProvider(widget.medicine.id));

    return Scaffold(
      appBar: AppBar(title: Text(widget.medicine.name)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Dosage', style: Theme.of(context).textTheme.titleMedium),
                      Text(widget.medicine.dosage, style: const TextStyle(fontSize: 22)),
                      if (widget.medicine.instructions?.isNotEmpty == true) ...[
                        const SizedBox(height: 16),
                        Text('Instructions', style: Theme.of(context).textTheme.titleMedium),
                        Text(widget.medicine.instructions!, style: const TextStyle(fontSize: 22)),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text('Schedule', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              schedules.when(
                loading: () => const LoadingView(),
                error: (e, _) => ErrorView(message: AppFailure.fromError(e).message),
                data: (list) => list.isEmpty
                    ? const Text('No schedule set up.', style: TextStyle(fontSize: 18))
                    : Column(children: list.map((s) => _ScheduleCard(schedule: s)).toList()),
              ),
              const SizedBox(height: 32),
              BigButton(
                label: 'Delete Medicine',
                icon: Icons.delete_outline,
                color: Theme.of(context).colorScheme.error,
                isLoading: _isDeleting,
                onPressed: _delete,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

const _weekdayLabels = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

class _ScheduleCard extends StatelessWidget {
  const _ScheduleCard({required this.schedule});
  final MedicineSchedule schedule;

  @override
  Widget build(BuildContext context) {
    final days = schedule.daysOfWeek.isEmpty ? 'Every day' : schedule.daysOfWeek.map((d) => _weekdayLabels[d]).join(', ');
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(schedule.timesOfDay.map(localTimeLabelFromUtc).join(' • '), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(days, style: const TextStyle(fontSize: 16)),
            if (!schedule.isActive) const Padding(padding: EdgeInsets.only(top: 4), child: Text('Inactive', style: TextStyle(color: Colors.grey))),
          ],
        ),
      ),
    );
  }
}
