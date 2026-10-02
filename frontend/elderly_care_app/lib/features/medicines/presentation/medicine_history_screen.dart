import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Last 30 days', style: Theme.of(context).textTheme.titleLarge, textAlign: TextAlign.center),
          const SizedBox(height: 20),
          if (summary.takenRate != null)
            Center(
              child: Column(
                children: [
                  Text('${summary.takenRate}%', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontSize: 48)),
                  const Text('Taken on Time', style: TextStyle(fontSize: 20)),
                ],
              ),
            )
          else
            const Center(child: Text('No medicine history yet.', style: TextStyle(fontSize: 20))),
          const SizedBox(height: 28),
          _StatRow(label: 'Taken', value: summary.taken, color: Colors.green, icon: Icons.check_circle),
          _StatRow(label: 'Skipped', value: summary.skipped, color: Colors.orange, icon: Icons.remove_circle),
          _StatRow(label: 'Missed', value: summary.missed, color: Colors.red, icon: Icons.cancel),
          _StatRow(label: 'Still upcoming', value: summary.scheduled + summary.reminded, color: Colors.blueGrey, icon: Icons.schedule),
        ],
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({required this.label, required this.value, required this.color, required this.icon});
  final String label;
  final int value;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(icon, color: color, size: 32),
        title: Text(label, style: const TextStyle(fontSize: 20)),
        trailing: Text('$value', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
      ),
    );
  }
}
