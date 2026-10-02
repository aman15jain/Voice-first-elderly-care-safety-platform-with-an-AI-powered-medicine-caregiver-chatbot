import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/errors/app_failure.dart';
import '../../../shared/widgets/error_view.dart';
import '../../../shared/widgets/loading_view.dart';
import '../data/activity_repository.dart';
import '../domain/daily_activity.dart';

class ActivityScreen extends ConsumerWidget {
  const ActivityScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final weekly = ref.watch(weeklyActivityProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('This Week')),
      body: SafeArea(
        child: weekly.when(
          loading: () => const LoadingView(),
          error: (e, _) => ErrorView(message: AppFailure.fromError(e).message, onRetry: () => ref.invalidate(weeklyActivityProvider)),
          data: (days) {
            final activeDays = days.where((d) => d.active).length;
            return ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Center(
                  child: Column(
                    children: [
                      Text('$activeDays of ${days.length}', style: Theme.of(context).textTheme.headlineMedium),
                      const Text('active days this week', style: TextStyle(fontSize: 18)),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                for (final day in days) _DayRow(day: day),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _DayRow extends StatelessWidget {
  const _DayRow({required this.day});
  final DailyActivity day;

  @override
  Widget build(BuildContext context) {
    final label = DateFormat.E().add_MMMd().format(DateTime.parse(day.date));
    return Card(
      color: day.active ? Colors.green.shade50 : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Icon(day.active ? Icons.check_circle : Icons.circle_outlined, color: day.active ? Colors.green : Colors.grey, size: 28),
            const SizedBox(width: 12),
            Expanded(child: Text(label, style: const TextStyle(fontSize: 18))),
            if (day.medicineInteractions > 0) _Pill(icon: Icons.medication, count: day.medicineInteractions),
            if (day.gameSessions > 0) ...[const SizedBox(width: 8), _Pill(icon: Icons.extension, count: day.gameSessions)],
          ],
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.icon, required this.count});
  final IconData icon;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [Icon(icon, size: 18), const SizedBox(width: 4), Text('$count', style: const TextStyle(fontSize: 16))],
    );
  }
}
