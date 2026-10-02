import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/services/location_service.dart';
import '../../../core/services/phone_service.dart';
import '../../../shared/widgets/big_button.dart';
import '../../../shared/widgets/confirm_dialog.dart';
import '../../../shared/widgets/error_view.dart';
import '../../../shared/widgets/loading_view.dart';
import '../data/emergency_repository.dart';
import '../domain/emergency_contact.dart';
import '../domain/emergency_event.dart';

/// The Emergency/SOS screen (spec section 15/33). Triggering, notifying caregivers and
/// tracking status are all deterministic backend calls — nothing here is AI-driven.
class SosScreen extends ConsumerStatefulWidget {
  const SosScreen({super.key});

  @override
  ConsumerState<SosScreen> createState() => _SosScreenState();
}

class _SosScreenState extends ConsumerState<SosScreen> {
  bool _isTriggering = false;
  bool _isResolving = false;

  Future<void> _confirmAndTrigger() async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Emergency SOS',
      message: 'This will alert your caregivers right away and let you call your emergency contacts. Continue?',
      confirmLabel: 'Yes, I need help',
      isDestructive: true,
    );
    if (!confirmed) return;

    setState(() => _isTriggering = true);
    try {
      final location = await ref.read(locationServiceProvider).getCurrentLocationOrNull();
      await ref.read(emergencyRepositoryProvider).triggerSOS(latitude: location?.latitude, longitude: location?.longitude);
      ref.invalidate(emergencyEventsProvider);
      ref.invalidate(activeEmergencyEventProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Your caregivers have been alerted.')));
      }
    } catch (e) {
      if (mounted) await _showTriggerFailure(e);
    } finally {
      if (mounted) setState(() => _isTriggering = false);
    }
  }

  /// SOS is the one place a network failure must never be a quiet toast: if the server was
  /// never reached, the caregiver notification almost certainly did not go out either, so this
  /// says so plainly and sends the elder straight to their contacts to call manually instead.
  Future<void> _showTriggerFailure(Object error) async {
    if (!AppFailure.isNetworkError(error)) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppFailure.fromError(error).message)));
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Could Not Send Alert'),
        content: const Text(
          "We could not reach the server, so your caregivers have NOT been notified. "
          'Please call one of your emergency contacts directly right now.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('Close')),
          FilledButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              context.push('/emergency/contacts');
            },
            child: const Text('Call a Contact'),
          ),
        ],
      ),
    );
  }

  Future<void> _resolve(String eventId) async {
    final confirmed = await showConfirmDialog(
      context,
      title: "I'm OK Now",
      message: 'This lets your caregivers know the emergency is over.',
      confirmLabel: "I'm OK",
    );
    if (!confirmed) return;

    setState(() => _isResolving = true);
    try {
      await ref.read(emergencyRepositoryProvider).resolve(eventId);
      ref.invalidate(emergencyEventsProvider);
      ref.invalidate(activeEmergencyEventProvider);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppFailure.fromError(e).message)));
    } finally {
      if (mounted) setState(() => _isResolving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeEvent = ref.watch(activeEmergencyEventProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Emergency'),
        actions: [
          IconButton(
            icon: const Icon(Icons.contacts),
            tooltip: 'Emergency Contacts',
            onPressed: () => context.push('/emergency/contacts'),
          ),
        ],
      ),
      body: SafeArea(
        child: activeEvent.when(
          loading: () => const LoadingView(),
          error: (e, _) => ErrorView(message: AppFailure.fromError(e).message, onRetry: () => ref.invalidate(activeEmergencyEventProvider)),
          data: (event) => event == null
              ? _IdleView(isTriggering: _isTriggering, onTrigger: _confirmAndTrigger)
              : _ActiveEmergencyView(event: event, isResolving: _isResolving, onResolve: () => _resolve(event.id)),
        ),
      ),
    );
  }
}

class _IdleView extends StatelessWidget {
  const _IdleView({required this.isTriggering, required this.onTrigger});
  final bool isTriggering;
  final VoidCallback onTrigger;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('If you need help right now, press the button below.', style: TextStyle(fontSize: 20), textAlign: TextAlign.center),
            const SizedBox(height: 32),
            SizedBox(
              width: 220,
              height: 220,
              child: ElevatedButton(
                onPressed: isTriggering ? null : onTrigger,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error,
                  foregroundColor: Colors.white,
                  shape: const CircleBorder(),
                  elevation: 6,
                ),
                child: isTriggering
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.warning_amber, size: 56),
                          SizedBox(height: 8),
                          Text('SOS', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800)),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActiveEmergencyView extends ConsumerWidget {
  const _ActiveEmergencyView({required this.event, required this.isResolving, required this.onResolve});
  final EmergencyEvent event;
  final bool isResolving;
  final VoidCallback onResolve;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contacts = ref.watch(emergencyContactsProvider);
    final statusText = event.status == EmergencyEventStatus.acknowledged
        ? 'A caregiver has seen this and is responding.'
        : 'Your caregivers have been notified.';

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Card(
          color: Colors.red.shade50,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Icon(Icons.warning_amber, color: Theme.of(context).colorScheme.error, size: 40),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Emergency Active', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
                      Text(statusText, style: const TextStyle(fontSize: 16)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        Text('Call for Help', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        contacts.when(
          loading: () => const LoadingView(),
          error: (e, _) => Text(AppFailure.fromError(e).message),
          data: (list) => list.isEmpty
              ? const Text('No emergency contacts added yet.', style: TextStyle(fontSize: 18))
              : Column(children: list.map((c) => _ContactCallCard(contact: c)).toList()),
        ),
        const SizedBox(height: 28),
        BigButton(label: "I'm OK Now", icon: Icons.check_circle, isLoading: isResolving, onPressed: onResolve),
      ],
    );
  }
}

class _ContactCallCard extends ConsumerWidget {
  const _ContactCallCard({required this.contact});
  final EmergencyContact contact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // A Column (name/phone above, a full-width Call button below) rather than a
    // ListTile with a trailing button: at phone width, "Call" alongside a leading
    // icon and title/subtitle doesn't reliably fit a ListTile's trailing slot.
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.person, size: 32),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(contact.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
                      Text(contact.relationship ?? contact.phone, style: const TextStyle(fontSize: 16)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () => ref.read(phoneServiceProvider).call(contact.phone),
              icon: const Icon(Icons.call),
              label: const Text('Call'),
            ),
          ],
        ),
      ),
    );
  }
}
