import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/errors/app_failure.dart';
import '../../../shared/widgets/big_button.dart';
import '../../../shared/widgets/error_view.dart';
import '../../../shared/widgets/loading_view.dart';
import '../../family/domain/family_link.dart';
import '../application/caregiver_emergency_providers.dart';
import '../data/emergency_repository.dart';
import '../domain/emergency_event.dart';

String _elderName(FamilyLink link) => link.elderName?.trim().isNotEmpty == true ? link.elderName! : link.elderEmail;

/// A caregiver's view of every linked elder's emergency events (spec section 19).
class CaregiverEmergencyScreen extends ConsumerWidget {
  const CaregiverEmergencyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final events = ref.watch(caregiverEmergencyEventsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Alerts')),
      body: SafeArea(
        child: events.when(
          loading: () => const LoadingView(),
          error: (e, _) => ErrorView(message: AppFailure.fromError(e).message, onRetry: () => ref.invalidate(caregiverEmergencyEventsProvider)),
          data: (list) => list.isEmpty
              ? const Center(child: Text('No emergency alerts.', style: TextStyle(fontSize: 20)))
              : RefreshIndicator(
                  onRefresh: () async => ref.invalidate(caregiverEmergencyEventsProvider),
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: list.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, i) => _EventCard(item: list[i]),
                  ),
                ),
        ),
      ),
    );
  }
}

class _EventCard extends ConsumerStatefulWidget {
  const _EventCard({required this.item});
  final ElderEmergencyEvent item;

  @override
  ConsumerState<_EventCard> createState() => _EventCardState();
}

class _EventCardState extends ConsumerState<_EventCard> {
  bool _isSubmitting = false;

  Future<void> _act(Future<void> Function(String) action) async {
    setState(() => _isSubmitting = true);
    try {
      await action(widget.item.event.id);
      ref.invalidate(caregiverEmergencyEventsProvider);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppFailure.fromError(e).message)));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final event = widget.item.event;
    final repo = ref.read(emergencyRepositoryProvider);
    final time = DateFormat.yMMMd().add_jm().format(event.triggeredAt);

    final (label, color) = switch (event.status) {
      EmergencyEventStatus.active => ('Active', Colors.red),
      EmergencyEventStatus.acknowledged => ('Acknowledged', Colors.orange),
      EmergencyEventStatus.resolved => ('Resolved', Colors.green),
    };

    return Card(
      color: event.isActive ? Colors.red.shade50 : null,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(_elderName(widget.item.elderLink), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                ),
                Chip(label: Text(label), backgroundColor: color.withValues(alpha: 0.15)),
              ],
            ),
            const SizedBox(height: 4),
            Text(time, style: const TextStyle(fontSize: 15, color: Colors.grey)),
            if (event.latitude != null && event.longitude != null) ...[
              const SizedBox(height: 4),
              Text('Location: ${event.latitude!.toStringAsFixed(4)}, ${event.longitude!.toStringAsFixed(4)}', style: const TextStyle(fontSize: 14)),
            ],
            if (event.status == EmergencyEventStatus.active) ...[
              const SizedBox(height: 12),
              BigButton(label: 'Acknowledge', icon: Icons.visibility, isLoading: _isSubmitting, onPressed: () => _act(repo.acknowledge)),
            ] else if (event.status == EmergencyEventStatus.acknowledged) ...[
              const SizedBox(height: 12),
              BigButton(label: 'Mark Resolved', icon: Icons.check_circle, isLoading: _isSubmitting, onPressed: () => _act(repo.resolve)),
            ],
          ],
        ),
      ),
    );
  }
}
