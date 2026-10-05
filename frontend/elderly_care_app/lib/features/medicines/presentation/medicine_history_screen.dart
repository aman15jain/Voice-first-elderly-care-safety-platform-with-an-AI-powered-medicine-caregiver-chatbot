import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/care/care_pill.dart';
import '../../../core/theme/care_tokens.dart';
import '../../../core/errors/app_failure.dart';
import '../../../shared/widgets/error_view.dart';
import '../../../shared/widgets/loading_view.dart';
import '../application/medicines_providers.dart';
import '../domain/medicine_models.dart';

class MedicineHistoryScreen extends ConsumerWidget {
  const MedicineHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(adherenceSummaryProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Medicine History')),
      body: SafeArea(
        child: summary.when(
          loading: () => const LoadingView(),
          error: (e, _) => ErrorView(message: AppFailure.fromError(e).message, onRetry: () => ref.invalidate(adherenceSummaryProvider)),
          data: (s) => _SummaryView(summary: s),
        ),
      ),
    );
  }
}

class _SummaryView extends StatelessWidget {
  const _SummaryView({required this.summary});
  final AdherenceSummary summary;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(CareSpacing.screenH - 4, CareSpacing.sm, CareSpacing.screenH - 4, CareSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Last 30 days', style: Theme.of(context).textTheme.titleLarge, textAlign: TextAlign.center),
          const SizedBox(height: 20),
          if (summary.takenRate != null)
            Container(
              padding: const EdgeInsets.symmetric(vertical: CareSpacing.xl),
              decoration: BoxDecoration(color: CareColors.primarySoft, borderRadius: BorderRadius.circular(CareRadius.card)),
              child: Column(
                children: [
                  Text('${summary.takenRate}%', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontSize: 52, color: CareColors.primaryDark)),
                  Text('Taken on Time', style: Theme.of(context).textTheme.titleMedium),
                ],
              ),
            )
          else
            Center(child: Text('No medicine history yet.', style: Theme.of(context).textTheme.titleMedium)),
          const SizedBox(height: 28),
          _StatRow(label: 'Taken', value: summary.taken, color: CareColors.success, background: CareColors.successSoft, icon: Icons.check_circle),
          _StatRow(label: 'Skipped', value: summary.skipped, color: CareColors.warning, background: CareColors.warningSoft, icon: Icons.remove_circle),
          _StatRow(label: 'Missed', value: summary.missed, color: CareColors.danger, background: CareColors.dangerSoft, icon: Icons.cancel),
          _StatRow(
            label: 'Still upcoming',
            value: summary.scheduled + summary.reminded,
            color: CareColors.neutral,
            background: CareColors.neutralSoft,
            icon: Icons.schedule,
          ),
        ],
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({required this.label, required this.value, required this.color, required this.background, required this.icon});
  final String label;
  final int value;
  final Color color;
  final Color background;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: CareIconTile(icon: icon, color: color, background: background, size: 44),
        title: Text(label),
        trailing: Text('$value', style: Theme.of(context).textTheme.titleLarge),
      ),
    );
  }
}
