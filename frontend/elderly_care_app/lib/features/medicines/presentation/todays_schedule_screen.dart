import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/errors/app_failure.dart';
import '../../../shared/widgets/error_view.dart';
import '../../../shared/widgets/loading_view.dart';
import '../application/medicines_providers.dart';
import '../data/medicines_repository.dart';
import '../domain/medicine_models.dart';

class TodaysScheduleScreen extends ConsumerWidget {
  const TodaysScheduleScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final schedule = ref.watch(todayScheduleProvider);
    final freshness = ref.watch(scheduleFreshnessProvider);

    return Scaffold(
      appBar: AppBar(title: const Text("Today's Schedule")),
      body: SafeArea(
        child: schedule.when(
          loading: () => const LoadingView(),
          error: (e, _) => ErrorView(message: AppFailure.fromError(e).message, onRetry: () => ref.invalidate(todayScheduleProvider)),
          data: (views) => Column(
            children: [
              if (freshness.fromCache) _CachedDataNotice(cachedAt: freshness.cachedAt),
              Expanded(
                child: views.isEmpty
                    ? const Center(child: Text('No medicines scheduled for today.', style: TextStyle(fontSize: 20)))
                    : RefreshIndicator(
                        onRefresh: () async => ref.invalidate(todayScheduleProvider),
                        child: ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: views.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 12),
                          itemBuilder: (context, i) => _DoseCard(view: views[i]),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CachedDataNotice extends StatelessWidget {
  const _CachedDataNotice({this.cachedAt});
  final DateTime? cachedAt;

  @override
  Widget build(BuildContext context) {
    final when = cachedAt == null ? '' : ' (saved ${DateFormat.jm().format(cachedAt!)})';
    return Container(
      width: double.infinity,
      color: Colors.blue.shade50,
      padding: const EdgeInsets.all(12),
      child: Text(
        "Showing saved schedule from before you went offline$when. Pull down to refresh once you're back online.",
        style: const TextStyle(fontSize: 14),
      ),
    );
  }
}

class _DoseCard extends ConsumerStatefulWidget {
  const _DoseCard({required this.view});
  final DoseView view;

  @override
  ConsumerState<_DoseCard> createState() => _DoseCardState();
}

class _DoseCardState extends ConsumerState<_DoseCard> {
  bool _isSubmitting = false;

  Future<void> _respond(Future<void> Function(String) action) async {
    setState(() => _isSubmitting = true);
    try {
      await action(widget.view.dose.id);
      ref.invalidate(todayDosesProvider);
      ref.invalidate(adherenceSummaryProvider);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppFailure.fromError(e).message)));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dose = widget.view.dose;
    final time = DateFormat.jm().format(dose.scheduledFor);
    final repo = ref.read(medicinesRepositoryProvider);
    final isPending = dose.status == DoseStatus.scheduled || dose.status == DoseStatus.reminded;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.view.medicineName, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600)),
                      Text('${widget.view.dosage} • $time', style: const TextStyle(fontSize: 18)),
                    ],
                  ),
                ),
                _StatusBadge(status: dose.status),
              ],
            ),
            if (isPending) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _isSubmitting ? null : () => _respond(repo.markTaken),
                      icon: const Icon(Icons.check),
                      label: const Text('Take'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _isSubmitting ? null : () => _respond(repo.markSkipped),
                      icon: const Icon(Icons.close),
                      label: const Text('Skip'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});
  final DoseStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, color, icon) = switch (status) {
      DoseStatus.taken => ('Taken', Colors.green, Icons.check_circle),
      DoseStatus.skipped => ('Skipped', Colors.orange, Icons.remove_circle),
      DoseStatus.missed => ('Missed', Colors.red, Icons.cancel),
      DoseStatus.reminded => ('Due', Colors.blue, Icons.notifications_active),
      DoseStatus.scheduled => ('Upcoming', Colors.grey, Icons.schedule),
    };
    return Chip(
      avatar: Icon(icon, color: color, size: 20),
      label: Text(label),
      backgroundColor: color.withValues(alpha: 0.12),
    );
  }
}
