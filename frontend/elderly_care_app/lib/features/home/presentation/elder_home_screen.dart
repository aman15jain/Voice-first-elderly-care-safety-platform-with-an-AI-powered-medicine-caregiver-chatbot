import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/services/connectivity_service.dart';
import '../../../core/services/sync_queue_service.dart';
import '../../../shared/widgets/big_button.dart';
import '../../auth/application/auth_controller.dart';
import '../../medicines/application/medicines_providers.dart';
import '../../medicines/data/medicines_repository.dart';
import '../../medicines/domain/medicine_models.dart';

/// The elder's landing screen — see spec section 34. Talk, Play Game, This Week and
/// Emergency are all real, working buttons (Phases 5-7).
class ElderHomeScreen extends ConsumerStatefulWidget {
  const ElderHomeScreen({super.key});

  @override
  ConsumerState<ElderHomeScreen> createState() => _ElderHomeScreenState();
}

class _ElderHomeScreenState extends ConsumerState<ElderHomeScreen> {
  @override
  void initState() {
    super.initState();
    // Best-effort, once per app open — see ActivityRepository.recordAppOpened. Not part
    // of build() so it fires once, not on every rebuild.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(ref.read(syncQueueServiceProvider).recordAppOpenedWithQueue());
    });
  }

  @override
  Widget build(BuildContext context) {
    // Flush any queued offline "app opened" ping as soon as connectivity returns, rather than
    // waiting for the next app launch.
    ref.listen(isOnlineProvider, (previous, next) {
      final wasOffline = previous?.value == false;
      final isNowOnline = next.value == true;
      if (wasOffline && isNowOnline) unawaited(ref.read(syncQueueServiceProvider).flushPending());
    });

    final authState = ref.watch(authControllerProvider);
    final name = authState is AuthAuthenticated ? authState.user.displayName : '';
    final nextDose = ref.watch(nextDoseProvider);
    final schedule = ref.watch(todayScheduleProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
        actions: [IconButton(icon: const Icon(Icons.person), onPressed: () => context.push('/profile'))],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(nextDoseProvider);
            ref.invalidate(todayScheduleProvider);
          },
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text('Good day, $name', style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 20),
              BigButton(
                label: 'Talk',
                icon: Icons.mic,
                onPressed: () => context.push('/voice'),
              ),
              const SizedBox(height: 24),
              nextDose.when(
                loading: () => const SizedBox(height: 80, child: Center(child: CircularProgressIndicator())),
                error: (e, _) => Text(AppFailure.fromError(e).message),
                data: (view) => view == null ? const _AllCaughtUpCard() : _NextMedicineCard(view: view),
              ),
              const SizedBox(height: 12),
              schedule.maybeWhen(
                data: (views) {
                  if (views.isEmpty) return const SizedBox.shrink();
                  final taken = views.where((v) => v.dose.status == DoseStatus.taken).length;
                  return Center(
                    child: TextButton(
                      onPressed: () => context.push('/medicines/today'),
                      child: Text("See today's full schedule ($taken/${views.length} taken)", style: const TextStyle(fontSize: 16)),
                    ),
                  );
                },
                orElse: () => const SizedBox.shrink(),
              ),
              const SizedBox(height: 20),
              Center(
                child: TextButton(
                  onPressed: () => context.push('/activity'),
                  child: const Text('See this week’s activity', style: TextStyle(fontSize: 16)),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: BigButton(label: 'Play Game', icon: Icons.extension, onPressed: () => context.push('/games')),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              BigButton(
                label: 'Emergency',
                icon: Icons.warning_amber,
                color: Theme.of(context).colorScheme.error,
                onPressed: () => context.push('/emergency'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AllCaughtUpCard extends StatelessWidget {
  const _AllCaughtUpCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.green.shade50,
      child: const Padding(
        padding: EdgeInsets.all(24),
        child: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 36),
            SizedBox(width: 16),
            Expanded(child: Text('All caught up! No medicines due right now.', style: TextStyle(fontSize: 20))),
          ],
        ),
      ),
    );
  }
}

class _NextMedicineCard extends ConsumerStatefulWidget {
  const _NextMedicineCard({required this.view});
  final DoseView view;

  @override
  ConsumerState<_NextMedicineCard> createState() => _NextMedicineCardState();
}

class _NextMedicineCardState extends ConsumerState<_NextMedicineCard> {
  bool _isSubmitting = false;

  Future<void> _markTaken() async {
    setState(() => _isSubmitting = true);
    try {
      await ref.read(medicinesRepositoryProvider).markTaken(widget.view.dose.id);
      ref.invalidate(nextDoseProvider);
      ref.invalidate(todayDosesProvider);
      ref.invalidate(todayScheduleProvider);
      ref.invalidate(adherenceSummaryProvider);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppFailure.fromError(e).message)));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final time = DateFormat.jm().format(widget.view.dose.scheduledFor);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Next Medicine', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(widget.view.medicineName, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700)),
            Text('${widget.view.dosage} • $time', style: const TextStyle(fontSize: 20)),
            const SizedBox(height: 16),
            BigButton(label: 'Take Medicine', icon: Icons.check, isLoading: _isSubmitting, onPressed: _markTaken),
          ],
        ),
      ),
    );
  }
}
