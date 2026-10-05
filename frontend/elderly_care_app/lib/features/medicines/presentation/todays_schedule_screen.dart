import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../shared/widgets/care/care_states.dart';
import '../../../shared/widgets/care/care_pill.dart';
import '../../../core/theme/care_tokens.dart';
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
                    ? const CareEmptyState(
                        icon: Icons.event_available,
                        title: 'No medicines scheduled for today.',
                        message: 'Medicines you add with a schedule will show up here each day.',
                      )
                    : RefreshIndicator(
                        onRefresh: () async => ref.invalidate(todayScheduleProvider),
                        child: ListView.separated(
                          padding: const EdgeInsets.fromLTRB(CareSpacing.screenH - 4, CareSpacing.sm, CareSpacing.screenH - 4, CareSpacing.xl),
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
    return CareInfoBanner(
      icon: Icons.cloud_off,
      message: "Showing saved schedule from before you went offline$when. Pull down to refresh once you're back online.",
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

    final text = Theme.of(context).textTheme;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(CareSpacing.lg + 2),
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
                      Text(widget.view.medicineName, style: text.titleMedium),
                      Text('${widget.view.dosage} • $time', style: text.bodyMedium),
                    ],
                  ),
                ),
                const SizedBox(width: CareSpacing.sm),
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
    final (label, fg, bg, icon) = switch (status) {
      DoseStatus.taken => ('Taken', CareColors.success, CareColors.successSoft, Icons.check_circle),
      DoseStatus.skipped => ('Skipped', CareColors.warning, CareColors.warningSoft, Icons.remove_circle),
      DoseStatus.missed => ('Missed', CareColors.danger, CareColors.dangerSoft, Icons.cancel),
      DoseStatus.reminded => ('Due', CareColors.info, CareColors.infoSoft, Icons.notifications_active),
      DoseStatus.scheduled => ('Upcoming', CareColors.neutral, CareColors.neutralSoft, Icons.schedule),
    };
    return CareStatusPill(label: label, foreground: fg, background: bg, icon: icon);
  }
}
