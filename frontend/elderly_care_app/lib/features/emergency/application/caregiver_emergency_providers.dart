import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../family/application/family_providers.dart';
import '../../family/domain/family_link.dart';
import '../data/emergency_repository.dart';
import '../domain/emergency_event.dart';

class ElderEmergencyEvent {
  const ElderEmergencyEvent({required this.event, required this.elderLink});
  final EmergencyEvent event;
  final FamilyLink elderLink;
}

/// Combines every accepted elder link with that elder's emergency events, for the
/// caregiver's Alerts tab. A caregiver typically has one linked elder, but this handles
/// several correctly too.
final caregiverEmergencyEventsProvider = FutureProvider.autoDispose<List<ElderEmergencyEvent>>((ref) async {
  final links = await ref.watch(familyLinksProvider.future);
  final acceptedElderLinks = links.where((l) => l.status == FamilyLinkStatus.accepted).toList();

  final repo = ref.watch(emergencyRepositoryProvider);
  final perElder = await Future.wait(acceptedElderLinks.map((link) => repo.listEvents(elderId: link.elderId)));

  final combined = <ElderEmergencyEvent>[
    for (var i = 0; i < acceptedElderLinks.length; i++)
      for (final event in perElder[i]) ElderEmergencyEvent(event: event, elderLink: acceptedElderLinks[i]),
  ];
  combined.sort((a, b) => b.event.triggeredAt.compareTo(a.event.triggeredAt));
  return combined;
});
