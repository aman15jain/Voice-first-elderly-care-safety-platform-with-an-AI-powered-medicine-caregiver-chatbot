import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/widgets/care/care_states.dart';
import '../../../shared/widgets/care/care_pill.dart';
import '../../../core/theme/care_tokens.dart';
import '../../../core/errors/app_failure.dart';
import '../../../shared/widgets/big_button.dart';
import '../../../shared/widgets/confirm_dialog.dart';
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
          padding: const EdgeInsets.fromLTRB(CareSpacing.screenH - 4, CareSpacing.sm, CareSpacing.screenH - 4, CareSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(CareSpacing.lg + 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const CareIconTile(icon: Icons.medication, color: CareColors.accentWarm, background: CareColors.accentWarmSoft),
                          const SizedBox(width: CareSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Dosage', style: Theme.of(context).textTheme.bodyMedium),
                                Text(widget.medicine.dosage, style: Theme.of(context).textTheme.titleLarge),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (widget.medicine.instructions?.isNotEmpty == true) ...[
                        const Divider(height: CareSpacing.xxl),
                        Text('Instructions', style: Theme.of(context).textTheme.bodyMedium),
                        Text(widget.medicine.instructions!, style: Theme.of(context).textTheme.titleMedium),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text('Schedule', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              schedules.when(
                loading: () => const CareInlineLoading(),
                error: (e, _) => CareInlineError(message: AppFailure.fromError(e).message),
                data: (list) => list.isEmpty
                    ? Text('No schedule set up.', style: Theme.of(context).textTheme.bodyMedium)
                    : Column(children: list.map((s) => _ScheduleCard(schedule: s)).toList()),
              ),
              const SizedBox(height: 32),
              BigButton(label: 'Delete Medicine', icon: Icons.delete_outline, color: CareColors.danger, isLoading: _isDeleting, onPressed: _delete),
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
        padding: const EdgeInsets.all(CareSpacing.lg + 2),
        child: Row(
          children: [
            const CareIconTile(icon: Icons.schedule),
            const SizedBox(width: CareSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(schedule.timesOfDay.map(localTimeLabelFromUtc).join(' • '), style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 2),
                  Text(days, style: Theme.of(context).textTheme.bodyMedium),
                ],
              ),
            ),
            if (!schedule.isActive) const CareStatusPill(label: 'Inactive', foreground: CareColors.neutral, background: CareColors.neutralSoft),
          ],
        ),
      ),
    );
  }
}
