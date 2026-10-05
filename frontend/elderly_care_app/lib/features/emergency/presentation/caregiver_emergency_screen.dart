import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/theme/care_tokens.dart';
import '../../../shared/widgets/big_button.dart';
import '../../../shared/widgets/care/care_states.dart';
import '../../../shared/widgets/error_view.dart';
import '../../../shared/widgets/loading_view.dart';
import '../../family/domain/family_link.dart';
import '../application/caregiver_emergency_providers.dart';
import '../data/emergency_repository.dart';
import '../domain/emergency_event.dart';

String _elderName(FamilyLink link) => link.elderName?.trim().isNotEmpty == true ? link.elderName! : link.elderEmail;

const _danger = Color(0xFFC62828);
const _dangerSoft = Color(0xFFFDECEA);

/// A caregiver's view of every linked elder's emergency events (spec section 19).
/// Acknowledge / resolve go through the existing emergency API — the screen only displays
/// state and calls it; no safety logic lives here.
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
              ? CareEmptyState(
                  icon: Icons.verified_user_outlined,
                  title: 'No emergency alerts.',
                  message: 'When a loved one presses SOS, it appears here so you can respond right away.',
                  onAction: () => ref.invalidate(caregiverEmergencyEventsProvider),
                  actionLabel: 'Check Again',
                  actionIcon: Icons.refresh,
                )
              : RefreshIndicator(
                  onRefresh: () async => ref.invalidate(caregiverEmergencyEventsProvider),
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(CareSpacing.screenH - 4, CareSpacing.sm, CareSpacing.screenH - 4, CareSpacing.xl),
                    itemCount: list.length,
                    separatorBuilder: (_, _) => const SizedBox(height: CareSpacing.md),
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
    final name = _elderName(widget.item.elderLink);

    final (label, fg, bg, icon) = switch (event.status) {
      EmergencyEventStatus.active => ('Active', _danger, _dangerSoft, Icons.sos),
      EmergencyEventStatus.acknowledged => ('Acknowledged', const Color(0xFFB4441C), CareColors.accentWarmSoft, Icons.visibility_outlined),
      EmergencyEventStatus.resolved => ('Resolved', CareColors.primary, CareColors.primarySoft, Icons.check_circle_outline),
    };

    return DecoratedBox(
      decoration: BoxDecoration(
        color: event.isActive ? _dangerSoft : CareColors.surface,
        borderRadius: BorderRadius.circular(CareRadius.card),
        border: Border.all(color: event.isActive ? const Color(0xFFF5C2BF) : const Color(0x1A0F5C45)),
        boxShadow: CareShadows.tile,
      ),
      child: Padding(
        padding: const EdgeInsets.all(CareSpacing.lg + 2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(
              container: true,
              label: '$name, $label emergency, $time',
              excludeSemantics: true,
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(color: event.isActive ? _danger : bg, shape: BoxShape.circle),
                    child: Icon(icon, size: 26, color: event.isActive ? Colors.white : fg),
                  ),
                  const SizedBox(width: CareSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name, style: CareText.cardTitle.copyWith(fontSize: 19), maxLines: 1, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 2),
                        Text(time, style: CareText.cardBody.copyWith(fontSize: 14.5)),
                      ],
                    ),
                  ),
                  const SizedBox(width: CareSpacing.sm),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(color: event.isActive ? Colors.white : bg, borderRadius: BorderRadius.circular(CareRadius.pill)),
                    child: Text(
                      label,
                      style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: fg),
                    ),
                  ),
                ],
              ),
            ),
            if (event.latitude != null && event.longitude != null) ...[
              const SizedBox(height: CareSpacing.md),
              Row(
                children: [
                  const Icon(Icons.place_outlined, size: 20, color: CareColors.textMuted),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Location: ${event.latitude!.toStringAsFixed(4)}, ${event.longitude!.toStringAsFixed(4)}',
                      style: CareText.cardBody.copyWith(fontSize: 15),
                    ),
                  ),
                ],
              ),
            ],
            if (event.status == EmergencyEventStatus.active) ...[
              const SizedBox(height: CareSpacing.lg),
              BigButton(label: 'Acknowledge', icon: Icons.visibility, isLoading: _isSubmitting, color: _danger, onPressed: () => _act(repo.acknowledge)),
            ] else if (event.status == EmergencyEventStatus.acknowledged) ...[
              const SizedBox(height: CareSpacing.lg),
              BigButton(label: 'Mark Resolved', icon: Icons.check_circle, isLoading: _isSubmitting, onPressed: () => _act(repo.resolve)),
            ],
          ],
        ),
      ),
    );
  }
}
